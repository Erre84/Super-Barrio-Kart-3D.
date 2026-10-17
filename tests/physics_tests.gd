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
