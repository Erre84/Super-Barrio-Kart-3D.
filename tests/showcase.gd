extends SceneTree
## Genera capturas de presentación (kart de frente, perfil, vista aérea del circuito).
## Uso (necesita render, no --headless):
##   godot --path . -s res://tests/showcase.gd -- --out=<carpeta>

const TrackScene := preload("res://scenes/track_el_prat.tscn")
const KartScene := preload("res://scenes/kart.tscn")

var _out := "user://showcase"
var _only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _run() -> void:
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	preload("res://scripts/game/lighting.gd").build(root3d)

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
		["kart_frente", k + fwd * 3.4 + right * 1.9 + Vector3.UP * 1.25, k + Vector3.UP * 0.75, 42.0],
		["kart_detras", k - fwd * 3.6 - right * 1.7 + Vector3.UP * 1.35, k + Vector3.UP * 0.7, 42.0],
		["kart_turbo", k - fwd * 3.3 + right * 1.3 + Vector3.UP * 0.95, k + Vector3.UP * 0.6 - fwd * 0.6, 45.0],
		["kart_perfil", k + right * 4.2 - fwd * 0.3 + Vector3.UP * 0.9, k + Vector3.UP * 0.62, 42.0],
		["piloto_cara", k + fwd * 1.55 + right * 0.45 + Vector3.UP * 1.6, k + Vector3.UP * 1.35 - fwd * 0.15, 40.0],
		["rueda", k + right * 1.9 - fwd * 0.2 + Vector3.UP * 0.55 + fwd * 1.3, k + right * 0.8 - fwd * 0.88 + Vector3.UP * 0.3, 32.0],
		["circuito_aereo", Vector3(103, 380, 260), Vector3(103, 0, 0), 60.0],
		["pota_blava", Vector3(5, 7, -186), Vector3(-26, 6, -206), 55.0],
		["aeropuerto", Vector3(120, 14, 150), Vector3(160, 6, 230), 60.0],
		["plaza_vila", Vector3(2, 3, 30), Vector3(44, 8, 46), 60.0],
		["telegrafia", Vector3(60, 5, -193), Vector3(92, 8, -229), 55.0],
		["parc_riu", Vector3(-62, 5, 30), Vector3(-60, 12, -70), 62.0],
		["plaza_carxofa", Vector3(50, 16, -30), Vector3(80, 5, -62), 55.0],
	]
	for s in shots:
		if _only != "" and not (s[0] in _only.split(",")):
			continue
		kart.boost_time = 10.0 if s[0] == "kart_turbo" else 0.0
		var env: Environment = (root3d.get_node("WorldEnvironment") as WorldEnvironment).environment
		env.fog_enabled = s[0] != "circuito_aereo"
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
