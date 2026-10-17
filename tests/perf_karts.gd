extends SceneTree
## Coste de render de los corredores en el circuito (calidad de móvil).
## Uso (necesita render; en servidor: xvfb-run):
##   godot --path . --resolution 1280x720 -s res://tests/perf_karts.gd [-- --racers=zule,dami --count=8]
## Mide en la vista de carrera (cámara de persecución en la parrilla): llamadas de dibujo,
## primitivas (triángulos) y objetos por fotograma, con 1 kart y con `count` karts.
## Ojo: en un servidor sin GPU el tiempo de fotograma no es representativo de un móvil;
## las llamadas de dibujo y los triángulos sí lo son (no dependen del hardware).

const TrackScene := preload("res://scenes/track_el_prat.tscn")
const KartScene := preload("res://scenes/kart.tscn")
const ChaseCamera := preload("res://scripts/kart/chase_camera.gd")

var racers: Array = ["zule", "dami"]
var count := 8


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--racers="):
			racers = Array(a.substr(9).split(","))
		elif a.begins_with("--count="):
			count = int(a.substr(8))
	_run()


func _measure(frames: int) -> Dictionary:
	var dc := 0.0
	var prim := 0.0
	var obj := 0.0
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await process_frame
		dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prim += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		obj += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	return {"draw_calls": dc / frames, "primitives": prim / frames, "objects": obj / frames, "ms": ms}


func _run() -> void:
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	preload("res://scripts/game/lighting.gd").build(root3d, true)
	var track = TrackScene.instantiate()
	root3d.add_child(track)
	track.build()
	var cam := ChaseCamera.new()
	root3d.add_child(cam)
	cam.make_current()

	var karts: Array = []
	var results := {}
	# 0 karts: solo el circuito, como referencia
	cam.global_position = track.start_transform(0).origin + Vector3(0, 2.0, 5.0)
	cam.look_at(track.start_transform(0).origin + Vector3(0, 0.6, -6.0))
	cam.set_process(false)
	cam.set_physics_process(false)
	for i in 20:
		await process_frame
	results["circuito solo"] = await _measure(60)
	for n in [1, count]:
		for k in karts:
			k.queue_free()
		karts.clear()
		await process_frame
		for i in n:
			var kart = KartScene.instantiate()
			kart.racer_id = racers[i % racers.size()]
			kart.track = track
			root3d.add_child(kart)
			kart.place(track.start_transform(i))
			karts.append(kart)
		cam.target = karts[0]
		cam.set_process(true)
		cam.set_physics_process(true)
		for i in 30:
			await process_frame
		results["%d karts" % n] = await _measure(90)
	for key in results:
		var r: Dictionary = results[key]
		print("[rendimiento] %-14s llamadas de dibujo %5.0f · triángulos %7.0f · objetos %4.0f · %5.1f ms/fotograma (CPU, sin GPU)"
				% [key, r["draw_calls"], r["primitives"], r["objects"], r["ms"]])
	quit(0)
