extends Node
## Piloto automático SOLO PARA PRUEBAS (se activa con `-- --autopilot`).
## Conduce usando las mismas acciones de entrada que un jugador (Input.action_press),
## así se prueba el camino real teclado/mando -> kart. Al acabar imprime un
## resumen JSON y cierra el juego con código 0 (OK) o 1 (fallo).
##
## Argumentos de usuario opcionales:
##   --shots=<carpeta>   guarda capturas PNG en momentos clave (requiere render, no --headless)
##   --timeout=<seg>     tiempo máximo de carrera (por defecto 150)

var race: Node
var _t := 0.0
var _shots_dir := ""
var _shots_done := {}
var _timeout := 150.0
var _phase := "lap"          # lap -> reverse -> done
var _phase_t := 0.0
var _stats := {
	"max_kmh": 0.0, "wall_hits": 0, "max_drift_level": 0, "max_slip_deg": 0.0, "boosts": [], "offroad_time": 0.0,
	"lap_time": -1.0, "min_forward_speed": 0.0, "respawns": 0, "cones_hit": 0, "frames": 0,
}
var _stuck_time := 0.0
var _quit_after := ""
var _look_back_frames := 0
var _stunt := ""
var _steer_smooth := 0.0
var _stunt_t := 0.0
var _stunt_done := false
var _after_stunt := 0.0
var _no_stunt := "--no-stunt" in OS.get_cmdline_user_args()
var _off_log := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
			DirAccess.make_dir_recursive_absolute(_shots_dir)
		elif a.begins_with("--quit-after="):
			_quit_after = a.substr(13)
		elif a.begins_with("--timeout="):
			_timeout = float(a.substr(10))
	process_physics_priority = -10  # antes que el kart
	await get_tree().process_frame
	race.kart.wall_hit.connect(func(_s): _stats["wall_hits"] += 1)
	race.kart.boost_started.connect(func(k): _stats["boosts"].append(k))


func _press(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func _physics_process(delta: float) -> void:
	_t += delta
	_stats["frames"] += 1
	var kart = race.kart
	var track = race.track
	# Salida perfecta: acelerar en el último medio segundo de la cuenta atrás
	if race.state == "countdown":
		_press("accelerate", 1.0 if race.countdown < 0.45 else 0.0)
		_shot("01_countdown", race.countdown < 2.2)
		return
	var kmh: float = kart.get_speed_kmh()
	if "--trace" in OS.get_cmdline_user_args() and _stats["frames"] % 10 == 0:
		var pr := float(kart.track_info.get("progress", 0.0))
		if pr > 0.74 and pr < 0.88:
			print("[trace] p=%.3f kmh=%.0f slip=%.0f steer=%.2f lat=%.1f road=%s st=%d thr=%.1f" % [pr, kmh,
					rad_to_deg(kart.slip_angle), kart.steer_value, float(kart.track_info.get("lateral", 0.0)),
					kart.on_road, kart.drift_state, kart.throttle_input])
	if _stats["frames"] % 300 == 0:
		print("[autopilot] t=%.1f vuelta=%d prog=%.3f km/h=%.0f pista=%s derrape=%d" % [_t, race.lap,
				float(kart.track_info.get("progress", 0.0)), kmh, kart.on_road, kart.drift_level])
	_stats["max_kmh"] = maxf(_stats["max_kmh"], kmh)
	_stats["max_drift_level"] = maxi(_stats["max_drift_level"], kart.drift_level)
	_stats["max_slip_deg"] = maxf(_stats["max_slip_deg"], rad_to_deg(absf(kart.slip_angle)))
	if not kart.on_road:
		_stats["offroad_time"] += delta
		var pk := "%.2f" % snappedf(float(kart.track_info.get("progress", 0.0)), 0.02)
		_off_log[pk] = _off_log.get(pk, 0.0) + delta
		_stats["offroad_where"] = _off_log
	_stats["min_forward_speed"] = minf(_stats["min_forward_speed"], kart.forward_speed)

	match _phase:
		"lap":
			_drive(kart, track)
			if race.lap >= 2 or race.state == "finished":
				_stats["lap_time"] = race.lap_times[0] if race.lap_times.size() > 0 else -1.0
				_phase = "reverse"
				_phase_t = 0.0
		"reverse":
			_phase_t += delta
			_press("accelerate", 0.0)
			_press("steer_left", 0.0)
			_press("steer_right", 0.0)
			_press("brake", 1.0)
			if _phase_t > 4.5:
				_finish()
				return
	if _t > _timeout:
		_finish()


func _drive(kart, track) -> void:
	var info: Dictionary = kart.track_info
	if info.is_empty():
		return
	var n: int = track.points.size()
	var i: int = info["index"]
	var speed: float = kart.get_speed_kmh() / 3.6
	var look := 6 + int(speed * 0.35)
	var target: Vector3 = track.points[(i + look) % n]
	# Esquiva las isletas/obras apuntando un poco hacia el lado libre
	var lateral_goal := 0.0
	for z in track.avoid_zones:
		# Esquivar mientras el kart o el punto que persigue estén dentro de la zona
		for j in [i, i + look / 2, i + look]:
			if posmod(j - int(z[0]), n) <= int(z[1]) - int(z[0]):
				lateral_goal = float(z[2])
	target += track.lefts[(i + look) % n] * lateral_goal
	var to: Vector3 = target - kart.global_position
	to.y = 0
	var fwd: Vector3 = -kart.global_transform.basis.z
	var ang := fwd.signed_angle_to(to.normalized(), Vector3.UP)  # + = objetivo a la izquierda
	var steer := clampf(-ang * 2.6, -1.0, 1.0)
	# Velocidad máxima ahora para poder frenar a tiempo ante cada curva de los
	# próximos ~90 m: v² ≤ v_curva² + 2·a·d (v_curva² = agarre / curvatura)
	var k_ahead := 0.0
	var v_allowed := 99.0
	for k in range(2, 46, 2):
		var kk: float = track.curv[(i + k) % n]
		if absf(kk) > absf(k_ahead) and k < 30:
			k_ahead = kk
		var vc: float = sqrt(kart.grip_peak * 0.7 / maxf(absf(kk), 0.001))
		v_allowed = minf(v_allowed, sqrt(vc * vc + 2.0 * 14.0 * k * 2.0))
	var throttle := 1.0
	var brake := 0.0
	if speed > v_allowed:
		throttle = 0.0
		if speed > v_allowed * 1.05:
			brake = 0.7
	# Si se cruza, contravolante proporcional a la deriva (lo que haría un jugador)
	# (slip_angle > 0: el morro apunta a la izquierda de la trayectoria → volante a la derecha)
	if kart.slide_amount > 0.2 and _stunt == "":
		steer = clampf(steer + kart.slip_angle * 2.5, -1.0, 1.0)
		brake = 0.0
	# Maniobra de mini-turbo en la recta de salida: volantazo, contravolante, suelta y pisa
	var prog := float(info["progress"])
	if _no_stunt:
		_stunt_done = true
	if _stunt == "" and not _stunt_done and prog > 0.035 and prog < 0.06 and speed > 25.0:
		_stunt = "flick"
		_stunt_t = 0.0
	if _stunt != "":
		_stunt_t += get_physics_process_delta_time()
		throttle = 1.0
		brake = 0.0
		match _stunt:
			"flick":
				steer = 1.0
				if _stunt_t > 0.7:
					_stunt = "counter"
			"counter":
				steer = -1.0 if rad_to_deg(absf(kart.slip_angle)) > 4.0 else 0.0
				if kart.drift_state == 2:
					_stunt = "lift"
					_stunt_t = 0.0
				elif _stunt_t > 3.0:
					_stunt = ""
					_stunt_done = true
			"lift":
				steer = clampf(-ang * 2.6, -1.0, 1.0)
				throttle = 0.0 if _stunt_t < 0.1 else 1.0
				if _stunt_t > 0.15:
					_stunt = ""
					_stunt_done = true
	# Volante con velocidad limitada (como una persona: no corrige 60 veces por segundo)
	var rate := 12.0 if _stunt != "" else 4.0
	_steer_smooth = move_toward(_steer_smooth, steer, rate * get_physics_process_delta_time())
	_press("steer_right", maxf(_steer_smooth, 0.0))
	_press("steer_left", maxf(-_steer_smooth, 0.0))
	_press("accelerate", throttle)
	_press("brake", brake)
	# Turbo en la recta de meta
	if kart.turbo_meter >= 1.0 and absf(steer) < 0.15 and speed > 18.0 and _t > 6.0 and v_allowed > 40.0:
		Input.action_press("turbo")
	else:
		Input.action_release("turbo")
	# Anti-atascos (no debería hacer falta)
	if speed < 3.0:
		_stuck_time += get_physics_process_delta_time()
		if _stuck_time > 3.0:
			kart.respawn()
			_stats["respawns"] += 1
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0
	# Capturas
	_shot("02_salida", _t > 5.0)
	_shot("03_derrape", kart.drifting and kart.drift_time > 0.6)
	_shot_front("07_derrape_frente", kart.drifting and kart.drift_time > 0.75)
	_shot("09_suelta_y_pisa", kart.drift_state == 2)
	if _stunt_done and _after_stunt >= 0.0:
		_after_stunt += get_physics_process_delta_time()
		if _after_stunt > 0.6:
			_after_stunt = -1.0
			_shot_cam("10_marcas_goma", Vector3.UP * 16.0 + kart.global_transform.basis.z * 6.0,
					-kart.global_transform.basis.z * -16.0)
	_shot_front("08_turbo_frente", kart.boost_time > 0.3 and float(info["progress"]) > 0.3)
	_shot("04_avenida", float(info["progress"]) > 0.55)
	# Mirar atrás: mantener el botón ~0,5 s, capturar y soltar
	if float(info["progress"]) > 0.36 and _look_back_frames >= 0:
		Input.action_press("look_back")
		_look_back_frames += 1
		if _look_back_frames > 30:
			_look_back_frames = -1
			_shot("05_mirar_atras", true)

	_shot("06_plaza", float(info["progress"]) > 0.8)


func _shot(shot_name: String, condition: bool) -> void:
	if _shots_dir == "" and condition and shot_name == "05_mirar_atras":
		Input.action_release("look_back")
	if _shots_dir == "" or not condition or _shots_done.has(shot_name):
		return
	_shots_done[shot_name] = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shots_dir.path_join(shot_name + ".png"))
	print("[autopilot] captura ", shot_name)
	if shot_name == "05_mirar_atras":
		Input.action_release("look_back")
	if shot_name == _quit_after:
		get_tree().quit(0)


## Captura con una cámara delante del kart, mirándolo (sin HUD).
func _shot_front(shot_name: String, condition: bool) -> void:
	if not condition:
		return
	var kart = race.kart
	var fwd: Vector3 = -kart.global_transform.basis.z
	var right: Vector3 = kart.global_transform.basis.x
	_shot_cam(shot_name, fwd * 5.2 + right * 1.6 + Vector3.UP * 1.25, Vector3.UP * 0.75 + fwd * 0.4)


## Captura con una cámara libre (posición y objetivo relativos al kart), sin HUD.
func _shot_cam(shot_name: String, offset: Vector3, look_offset: Vector3) -> void:
	if _shots_dir == "" or _shots_done.has(shot_name):
		return
	_shots_done[shot_name] = true
	var kart = race.kart
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 1500.0
	race.add_child(cam)
	cam.global_position = kart.global_position + offset
	cam.look_at(kart.global_position + look_offset, Vector3.UP)
	cam.make_current()
	race.hud.visible = false
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))
	print("[autopilot] captura ", shot_name)
	get_tree().paused = false
	race.hud.visible = true
	race.camera.make_current()
	cam.queue_free()
	if shot_name == _quit_after:
		get_tree().quit(0)


func _finish() -> void:
	set_physics_process(false)
	for a in ["accelerate", "brake", "steer_left", "steer_right", "turbo", "look_back"]:
		Input.action_release(a)
	var moved := 0
	for c in get_tree().get_nodes_in_group("knockable"):
		if c.has_meta("start") and (c as Node3D).global_position.distance_to(c.get_meta("start")) > 0.5:
			moved += 1
	_stats["cones_hit"] = moved
	_stats["sim_time"] = _t
	var ok: bool = _stats["lap_time"] > 0.0 and _stats["min_forward_speed"] < -3.0 and _stats["max_kmh"] > 80.0
	_stats["result"] = "OK" if ok else "FALLO"
	print("[autopilot] RESUMEN ", JSON.stringify(_stats))
	if _shots_dir != "":
		await RenderingServer.frame_post_draw
	get_tree().quit(0 if ok else 1)
