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
	"max_kmh": 0.0, "wall_hits": 0, "max_drift_level": 0, "boosts": [], "offroad_time": 0.0,
	"lap_time": -1.0, "min_forward_speed": 0.0, "respawns": 0, "cones_hit": 0, "frames": 0,
}
var _stuck_time := 0.0
var _quit_after := ""
var _look_back_frames := 0


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
	if _stats["frames"] % 300 == 0:
		print("[autopilot] t=%.1f vuelta=%d prog=%.3f km/h=%.0f pista=%s derrape=%d" % [_t, race.lap,
				float(kart.track_info.get("progress", 0.0)), kmh, kart.on_road, kart.drift_level])
	_stats["max_kmh"] = maxf(_stats["max_kmh"], kmh)
	_stats["max_drift_level"] = maxi(_stats["max_drift_level"], kart.drift_level)
	if not kart.on_road:
		_stats["offroad_time"] += delta
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
			_press("drift", 0.0)
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
		var ahead := posmod(i + look - int(z[0]), n)
		if ahead <= int(z[1]) - int(z[0]):
			lateral_goal = float(z[2])
	target += track.lefts[(i + look) % n] * lateral_goal
	var to: Vector3 = target - kart.global_position
	to.y = 0
	var fwd: Vector3 = -kart.global_transform.basis.z
	var ang := fwd.signed_angle_to(to.normalized(), Vector3.UP)  # + = objetivo a la izquierda
	var steer := clampf(-ang * 2.6, -1.0, 1.0)
	# Curvatura por delante (+ = curva a la izquierda)
	var k_ahead := 0.0
	for k in range(2, 16, 2):
		var kk: float = track.curv[(i + k) % n]
		if absf(kk) > absf(k_ahead):
			k_ahead = kk
	var drift_on := false
	if kart.drifting:
		# Seguir derrapando mientras la curva continúe y vaya hacia el mismo lado
		drift_on = absf(k_ahead) > 0.012 and signf(-k_ahead) == float(kart.drift_dir)
		steer = clampf(-ang * 3.2, -1.0, 1.0)
	elif absf(k_ahead) > 0.02 and speed > 14.0:
		drift_on = true
		steer = -signf(k_ahead) * 0.85
	_press("steer_right", maxf(steer, 0.0))
	_press("steer_left", maxf(-steer, 0.0))
	_press("drift", 1.0 if drift_on else 0.0)
	var throttle := 1.0
	if absf(k_ahead) > 0.045 and speed > 22.0 and not kart.drifting:
		throttle = 0.0
	_press("accelerate", throttle)
	_press("brake", 0.0)
	# Turbo en la recta de meta
	if kart.turbo_meter >= 1.0 and absf(steer) < 0.15 and speed > 18.0 and _t > 6.0:
		Input.action_press("turbo")
	else:
		Input.action_release("turbo")
	# Anti-atascos (no debería hacer falta)
	if speed < 1.0:
		_stuck_time += get_physics_process_delta_time()
		if _stuck_time > 3.0:
			kart.respawn()
			_stats["respawns"] += 1
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0
	# Capturas
	_shot("02_salida", _t > 5.0)
	_shot("03_derrape", kart.drifting and kart.drift_level >= 1)
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


func _finish() -> void:
	set_physics_process(false)
	for a in ["accelerate", "brake", "steer_left", "steer_right", "drift", "turbo", "look_back"]:
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
