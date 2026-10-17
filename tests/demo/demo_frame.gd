extends SceneTree
## PRUEBA visual: Dami actual frente a Dami con cara texturizada y contorno de dibujo.
##   xvfb-run godot --path . --resolution 1280x720 -s res://tests/demo/demo_frame.gd -- --out=<carpeta>

const TrackScene := preload("res://scenes/track_el_prat.tscn")
const KartScene := preload("res://scenes/kart.tscn")
const Textured := preload("res://tests/demo/dami_textured.gd")

var _out := "user://demo"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _outline(n: Node, mat: Material) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and c.name != "Lights":
			(c as MeshInstance3D).material_overlay = mat
		_outline(c, mat)


func _run() -> void:
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	preload("res://scripts/game/lighting.gd").build(root3d)
	var track = TrackScene.instantiate()
	root3d.add_child(track)
	track.build()
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.current = true
	var outline := ShaderMaterial.new()
	outline.shader = load("res://tests/demo/contorno.gdshader")
	for variant in ["actual", "mejorado"]:
		var kart = KartScene.instantiate()
		kart.racer_id = "dami"
		kart.track = track
		root3d.add_child(kart)
		kart.place(track.start_transform(0))
		kart.set_physics_process(false)
		if variant == "mejorado":
			kart.model.queue_free()
			var m = Textured.new()
			m.name = "Model2"
			kart.add_child(m)
			m.build()
			kart.model = m
			_outline(m, outline)
		for i in 3:
			await process_frame
		var k: Vector3 = kart.global_position
		var fwd: Vector3 = -kart.global_transform.basis.z
		var right: Vector3 = kart.global_transform.basis.x
		var shots := [
			["heroe", k + fwd * 2.9 + right * 1.3 + Vector3.UP * 1.45, k + Vector3.UP * 1.0, 40.0],
			["cara", k + fwd * 1.45 + right * 0.3 + Vector3.UP * 1.6, k + Vector3.UP * 1.36 - fwd * 0.2, 38.0],
			["carrera", k - fwd * 4.4 - right * 0.8 + Vector3.UP * 1.8, k + fwd * 3.0 + Vector3.UP * 0.7, 62.0],
		]
		for s in shots:
			cam.global_position = s[1]
			cam.look_at(s[2], Vector3.UP)
			cam.fov = s[3]
			kart.model.update_visual({"speed": 0.0, "speed_ratio": 0.0, "steer": 0.2, "drifting": false,
				"drift_dir": 0, "yaw_rate": 0.0, "boost": false, "distance": 0.0, "grounded": true,
				"braking": false, "look_back": false}, 0.5)
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [variant, s[0]]))
		kart.queue_free()
		await process_frame
	print("[demo] listo")
	quit(0)
