extends SceneTree
## Pruebas de física del kart con casos concretos. Sin ventana:
##   godot --headless --path . --fixed-fps 60 -s res://tests/physics_tests.gd
## Sale con código 0 si todo pasa, 1 si algo falla.

const InputSetup := preload("res://scripts/core/input_setup.gd")
const TrackScene := preload("res://scenes/track_el_prat.tscn")
const KartScene := preload("res://scenes/kart.tscn")

const ACTIONS := ["accelerate", "brake", "steer_left", "steer_right", "drift", "turbo", "look_back", "reset"]

var world: Node3D
var track
var kart
var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	InputSetup.setup()
	await process_frame
	world = Node3D.new()
	get_root().add_child(world)
	track = TrackScene.instantiate()
	world.add_child(track)
	track.build()
	kart = KartScene.instantiate()
	world.add_child(kart)
	kart.controls_enabled = true
	await physics_frame

	await _test_no_auto_steer()
	await _test_turns_left_right()
	await _test_steer_release()
	await _test_progressive_drift()
	await _test_countersteer()
	await _test_reverse()
	await _test_turbo_top_speed()
	await _test_drift_levels()
	await _test_wall_blocks()
	await _test_cone_knock()
	await _test_offroad_slows()

	print("[tests] ", "TODO OK" if failures == 0 else "%d FALLO(S)" % failures)
	quit(0 if failures == 0 else 1)


# --- utilidades ---------------------------------------------------------------

func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("[tests] %s %s — %s" % ["OK   " if ok else "FALLO", test_name, detail])


## Coloca el kart en campo abierto (lejos del circuito, sin muros ni "fuera de pista").
func _open_field(yaw: float = 0.0) -> void:
	_release_all()
	kart.track = null
	kart.on_road = true
	kart.place(Transform3D(Basis(Vector3.UP, yaw), Vector3(900, 0.05, 900)))
	await _frames(5)


func _yaw() -> float:
	return kart.global_rotation.y


# --- pruebas -------------------------------------------------------------------

func _test_no_auto_steer() -> void:
	# En plena recta del circuito, apuntando 25° hacia el muro y sin tocar la dirección:
	# el rumbo no debe cambiar (nada "endereza" el kart hacia la carretera).
	_release_all()
	kart.track = track
	var i := 30
	var dir: Vector3 = track.dirs[i]
	var b := Basis.looking_at(dir, Vector3.UP).rotated(Vector3.UP, deg_to_rad(25))
	kart.place(Transform3D(b, track.points[i] + Vector3(0, 0.05, 0)))
	await _frames(3)
	var y0 := _yaw()
	Input.action_press("accelerate")
	await _frames(40)
	var dy := absf(angle_difference(y0, _yaw()))
	_check("sin autocorrección de dirección", dy < 0.001, "giro sin tocar el volante: %.5f rad" % dy)
	_release_all()


func _test_reverse() -> void:
	await _open_field()
	Input.action_press("brake")
	await _frames(150)
	var f: float = kart.forward_speed
	_check("marcha atrás", f < -8.0, "velocidad hacia delante %.1f m/s" % f)
	_release_all()


func _test_turbo_top_speed() -> void:
	await _open_field()
	Input.action_press("accelerate")
	await _frames(400)
	var normal: float = kart.get_speed_kmh()
	_check("velocidad punta", normal > 95.0 and normal < 110.0, "%.0f km/h" % normal)
	Input.action_press("turbo")
	await _frames(2)
	Input.action_release("turbo")
	await _frames(50)
	var boosted: float = kart.get_speed_kmh()
	_check("turbo supera la punta", boosted > normal + 15.0, "%.0f km/h con turbo" % boosted)
	_release_all()


func _test_drift_levels() -> void:
	await _open_field()
	Input.action_press("accelerate")
	await _frames(150)
	Input.action_press("steer_right")
	Input.action_press("drift")
	var max_level := 0
	var started := false
	for k in 240:
		await physics_frame
		started = started or kart.drifting
		max_level = maxi(max_level, kart.drift_level)
	_check("entra en derrape", started, "derrape activo")
	_check("mini-turbo morado (nivel 3)", max_level == 3, "nivel máximo %d" % max_level)
	var boosts: Array = []
	kart.boost_started.connect(func(kind): boosts.append(kind))
	Input.action_release("drift")
	await _frames(3)
	_check("al soltar sale el mini-turbo", "mini3" in boosts, str(boosts))
	_release_all()
	await _frames(60)


func _test_wall_blocks() -> void:
	# Directo contra el muro exterior a máxima velocidad con turbo
	_release_all()
	kart.track = track
	var i := 40
	var left: Vector3 = track.lefts[i]
	kart.place(Transform3D(Basis.looking_at(left, Vector3.UP), track.points[i] + Vector3(0, 0.05, 0)))
	kart.velocity = left * 30.0
	Input.action_press("accelerate")
	kart.apply_boost(2.0, "test")
	var hits := [0]  # array: las lambdas capturan las variables locales por copia
	kart.wall_hit.connect(func(_s): hits[0] += 1)
	await _frames(120)
	var lateral: float = (kart.global_position - track.points[i]).dot(left)
	_check("el muro no se atraviesa", lateral < track.WALL and lateral > 0.0, "desplazamiento lateral %.2f m (muro a %.1f m)" % [lateral, track.WALL])
	_check("se detecta el choque", hits[0] > 0, "%d choques" % hits[0])
	_release_all()


func _test_cone_knock() -> void:
	_release_all()
	var cone: RigidBody3D = null
	for c in get_nodes_in_group("knockable"):
		cone = c
		break
	if cone == null:
		_check("conos", false, "no hay conos en el circuito")
		return
	var start: Vector3 = cone.global_position
	kart.track = track
	# Acercarse por el carril, desde atrás y en línea recta hacia el cono
	var info: Dictionary = track.query_stateless(start)
	var dir: Vector3 = info["dir"]
	kart.place(Transform3D(Basis.looking_at(dir, Vector3.UP), start - dir * 12.0 + Vector3(0, 0.05, 0)))
	kart.velocity = dir * 20.0
	Input.action_press("accelerate")
	await _frames(90)
	var moved := cone.global_position.distance_to(start)
	_check("los conos salen volando", moved > 2.0 and moved < 60.0, "el cono se movió %.1f m" % moved)
	_release_all()


func _test_offroad_slows() -> void:
	_release_all()
	kart.track = track
	# En el arcén de tierra (entre el bordillo y el muro), en paralelo a la pista
	var i := 20
	var p: Vector3 = track.points[i] + track.lefts[i] * 10.6
	kart.place(Transform3D(Basis.looking_at(track.dirs[i], Vector3.UP), p + Vector3(0, 0.05, 0)))
	Input.action_press("accelerate")
	await _frames(240)
	var kmh: float = kart.get_speed_kmh()
	_check("la tierra frena", kmh < 65.0 and not kart.on_road, "%.0f km/h fuera de pista" % kmh)
	_release_all()


# --- Pruebas de dirección (v0.2) ---------------------------------------------------

## Acelera en campo abierto hasta ~`frames` y gira con `action` durante `turn_frames`.
## Devuelve giro (rad, + = izquierda), desplazamiento lateral (+ = derecha) y velocidad conservada.
func _turn(action: String, turn_frames: int) -> Dictionary:
	await _open_field()
	Input.action_press("accelerate")
	await _frames(150)
	var p0: Vector3 = kart.global_position
	var y0 := _yaw()
	var right0: Vector3 = kart.global_transform.basis.x
	var v0: float = kart.get_speed_kmh()
	Input.action_press(action)
	await _frames(turn_frames)
	var res := {
		"dyaw": angle_difference(y0, _yaw()),
		"lateral": (kart.global_position - p0).dot(right0),
		"keep": kart.get_speed_kmh() / v0,
	}
	_release_all()
	return res


func _test_turns_left_right() -> void:
	var l := await _turn("steer_left", 60)
	var r := await _turn("steer_right", 60)
	_check("giro a la izquierda", l["dyaw"] > 0.5 and l["lateral"] < -2.0,
			"%.2f rad, %.1f m a la izquierda" % [l["dyaw"], -l["lateral"]])
	_check("giro a la derecha", r["dyaw"] < -0.5 and r["lateral"] > 2.0,
			"%.2f rad, %.1f m a la derecha" % [-r["dyaw"], r["lateral"]])
	var sym_yaw := absf(l["dyaw"] + r["dyaw"])
	var sym_lat := absf(l["lateral"] + r["lateral"])
	_check("izquierda y derecha simétricas", sym_yaw < 0.005 and sym_lat < 0.05,
			"diferencia %.4f rad / %.3f m" % [sym_yaw, sym_lat])
	_check("sin freno automático en curva", l["keep"] > 0.85 and r["keep"] > 0.85,
			"conserva %.0f%% / %.0f%% de la velocidad con gas a fondo" % [l["keep"] * 100.0, r["keep"] * 100.0])


func _test_steer_release() -> void:
	await _open_field()
	Input.action_press("accelerate")
	await _frames(150)
	Input.action_press("steer_right")
	await _frames(30)
	Input.action_release("steer_right")
	await _frames(9)   # 0,15 s para que el volante vuelva al centro
	var rate_after: float = kart.yaw_rate
	var y0 := _yaw()
	await _frames(60)
	var drift := absf(angle_difference(y0, _yaw()))
	_check("al soltar, el volante vuelve en <0,15 s", absf(rate_after) < 0.001, "giro residual %.4f rad/s" % rate_after)
	_check("después sigue recto (sin autocorrección)", drift < 0.0005, "%.5f rad en 1 s" % drift)
	_release_all()


## Entra en derrape a la derecha; devuelve el kart ya derrapando (o null si no entra).
func _enter_drift_right() -> bool:
	await _open_field()
	Input.action_press("accelerate")
	await _frames(150)
	Input.action_press("steer_right")
	Input.action_press("drift")
	for i in 60:
		await physics_frame
		if kart.drifting:
			return true
	return false


func _test_progressive_drift() -> void:
	var ok: bool = await _enter_drift_right()
	if not ok:
		_check("derrape progresivo", false, "no entró en derrape")
		return
	var slips: Array[float] = []
	var yaws: Array[float] = []
	var max_step := 0.0
	var prev: float = kart.drift_slip
	for i in 40:
		await physics_frame
		slips.append(kart.drift_slip)
		yaws.append(absf(kart.yaw_rate))
		max_step = maxf(max_step, absf(kart.drift_slip - prev))
		prev = kart.drift_slip
	var grows: bool = slips[2] < slips[9] and slips[9] < slips[30] and slips[2] < slips[39] * 0.5
	_check("derrape progresivo: el ángulo crece", grows,
			"deslizamiento %.2f → %.2f → %.2f rad (0,05 s / 0,17 s / 0,52 s)" % [slips[2], slips[9], slips[30]])
	_check("derrape progresivo: el giro crece", yaws[2] < yaws[15],
			"giro %.2f → %.2f rad/s" % [yaws[2], yaws[15]])
	var limit: float = kart.drift_slip_rate / 60.0 + 0.0005
	_check("derrape sin saltos bruscos", max_step <= limit, "cambio máximo por fotograma %.4f rad (límite %.4f)" % [max_step, limit])
	_release_all()
	await _frames(30)


func _test_countersteer() -> void:
	var results := {}
	for mode in ["cerrar", "neutro", "contravolante"]:
		var ok: bool = await _enter_drift_right()
		if not ok:
			_check("contravolante", false, "no entró en derrape")
			return
		await _frames(25)   # derrape asentado
		Input.action_release("steer_right")
		if mode == "cerrar":
			Input.action_press("steer_right")
		elif mode == "contravolante":
			Input.action_press("steer_left")
		await _frames(40)
		var yaw := 0.0
		var slip := 0.0
		for i in 20:
			await physics_frame
			yaw += kart.yaw_rate / 20.0
			slip += kart.drift_slip / 20.0
		results[mode] = {"yaw": yaw, "slip": slip, "drifting": kart.drifting}
		_release_all()
		await _frames(30)
	var c: Dictionary = results["cerrar"]
	var n: Dictionary = results["neutro"]
	var cs: Dictionary = results["contravolante"]
	_check("contravolante abre la curva", c["yaw"] < n["yaw"] and n["yaw"] < cs["yaw"] and cs["yaw"] < 0.0,
			"giro cerrar %.2f / neutro %.2f / contravolante %.2f rad/s" % [-c["yaw"], -n["yaw"], -cs["yaw"]])
	_check("contravolante reduce el ángulo", c["slip"] > n["slip"] and n["slip"] > cs["slip"],
			"deslizamiento %.2f / %.2f / %.2f rad" % [c["slip"], n["slip"], cs["slip"]])
	_check("con contravolante se mantiene el derrape", cs["drifting"], "sigue derrapando")
