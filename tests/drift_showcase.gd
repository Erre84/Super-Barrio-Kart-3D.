extends SceneTree
## Capturas de la mecánica de derrape en la recta de salida (necesita render):
##   godot --path . --fixed-fps 60 -s res://tests/drift_showcase.gd -- --out=<carpeta>
## Secuencia con entrada inyectada: acelerar, volantazo, derrape, contravolante,
## "¡suelta y pisa!", mini-turbo, y vista cenital de las marcas de goma.

const TrackScene := preload("res://scenes/track_el_prat.tscn")
const KartScene := preload("res://scenes/kart.tscn")
const ChaseCamera := preload("res://scripts/kart/chase_camera.gd")
const HudScene := preload("res://scenes/hud.tscn")

var _out := "user://drift_showcase"
var kart
var cam: Camera3D
var hud
var root3d: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		_hud_tick()


func _hud_tick() -> void:
	hud.update_kart(kart.get_speed_kmh(), kart.turbo_meter, kart.drift_level, kart.boost_time > 0.0,
			kart.global_position, -kart.global_transform.basis.z)
	hud.update_drift(int(kart.drift_state), kart.drift_time, kart.drift_level, kart.window_left,
			kart.boost_window, rad_to_deg(absf(kart.slip_angle)), kart.drift_level_times)


func _snap(shot_name: String, free_cam: Array = []) -> void:
	var tmp: Camera3D = null
	kart.process_mode = Node.PROCESS_MODE_DISABLED
	if not free_cam.is_empty():
		tmp = Camera3D.new()
		tmp.fov = free_cam[2]
		tmp.far = 1500.0
		root3d.add_child(tmp)
		tmp.global_position = free_cam[0]
		tmp.look_at(free_cam[1], Vector3.UP)
		tmp.make_current()
		hud.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(_out.path_join(shot_name + ".png"))
	print("[drift_showcase] ", shot_name)
	if tmp != null:
		tmp.queue_free()
		cam.make_current()
		hud.visible = true
	kart.process_mode = Node.PROCESS_MODE_INHERIT


func _run() -> void:
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	root3d = Node3D.new()
	get_root().add_child(root3d)
	preload("res://scripts/game/lighting.gd").build(root3d)
	var track = TrackScene.instantiate()
	root3d.add_child(track)
	track.build()
	kart = KartScene.instantiate()
	kart.track = track
	root3d.add_child(kart)
	kart.place(track.start_transform(1))
	kart.controls_enabled = true
	cam = ChaseCamera.new()
	cam.target = kart
	root3d.add_child(cam)
	cam.make_current()
	hud = HudScene.instantiate()
	root3d.add_child(hud)
	hud.set_track(track.minimap_points())
	var events := []
	kart.drift_event.connect(func(k, l): events.append(k))

	kart.input_override = {"accelerate": 1.0}
	await _frames(130)
	var start_pos: Vector3 = kart.global_position
	# Volantazo a la izquierda (hacia el centro de la calle)
	kart.input_override = {"accelerate": 1.0, "steer_left": 1.0}
	var shot_slide := false
	for i in 70:
		await _frames(1)
		if not shot_slide and kart.drift_time > 0.35:
			shot_slide = true
			await _snap("derrape_detras")
			var k: Vector3 = kart.global_position
			var v: Vector3 = Vector3(kart.velocity.x, 0, kart.velocity.z).normalized()
			var side: Vector3 = Vector3.UP.cross(v)
			await _snap("derrape_frente", [k + v * 6.5 + side * 2.2 + Vector3.UP * 1.3, k + Vector3.UP * 0.6, 50.0])
	# Contravolante hasta enderezar
	kart.input_override = {"accelerate": 1.0, "steer_right": 1.0}
	for i in 120:
		await _frames(1)
		if rad_to_deg(absf(kart.slip_angle)) < 4.0:
			kart.input_override = {"accelerate": 1.0}
		if kart.drift_state == 2:
			break
	await _frames(4)
	await _snap("suelta_y_pisa")
	kart.input_override = {}
	await _frames(6)
	kart.input_override = {"accelerate": 1.0}
	await _frames(5)
	await _snap("mini_turbo")
	await _frames(40)
	# Vista cenital de las marcas de goma
	var mid: Vector3 = (start_pos + kart.global_position) * 0.5
	await _snap("marcas_goma", [mid + Vector3(10, 34, 8), mid + Vector3(0, 0, -6), 55.0])
	print("[drift_showcase] eventos ", events)
	quit(0)
