extends SceneTree
## Genera capturas de presentación (kart de frente, perfil, vista aérea del circuito).
## Uso (necesita render, no --headless):
##   godot --path . -s res://tests/showcase.gd -- --out=<carpeta>

const TrackScene := preload("res://scenes/track_el_prat.tscn")
const KartScene := preload("res://scenes/kart.tscn")

var _out := "user://showcase"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _run() -> void:
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8ec5ef")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a9bfd6")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	root3d.add_child(sun)

	var track = TrackScene.instantiate()
	root3d.add_child(track)
	track.build()
	var kart = KartScene.instantiate()
	kart.track = track
	root3d.add_child(kart)
	kart.place(track.start_transform(0))
	kart.set_physics_process(false)

	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.current = true
	cam.far = 2000.0

	var k: Vector3 = kart.global_position
	var fwd: Vector3 = -kart.global_transform.basis.z
	var right: Vector3 = kart.global_transform.basis.x
	var shots := [
		["kart_frente", k + fwd * 3.2 + right * 1.6 + Vector3.UP * 1.3, k + Vector3.UP * 0.8, 45.0],
		["kart_perfil", k + right * 4.0 - fwd * 1.0 + Vector3.UP * 1.0, k + Vector3.UP * 0.6, 45.0],
		["piloto_cara", k + fwd * 1.6 + right * 0.4 + Vector3.UP * 1.55, k + Vector3.UP * 1.3 - fwd * 0.2, 40.0],
		["circuito_aereo", Vector3(103, 330, 170), Vector3(103, 0, -33), 60.0],
		["plaza_carxofa", Vector3(50, 16, -30), Vector3(80, 5, -62), 55.0],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.fov = s[3]
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		img.save_png(_out.path_join(s[0] + ".png"))
		print("[showcase] ", s[0])
	quit(0)
