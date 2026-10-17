extends SceneTree
## Pruebas de física del kart con casos concretos. Sin ventana:
##   godot --headless --path . --fixed-fps 60 -s res://tests/physics_tests.gd
## Sale con código 0 si todo pasa, 1 si algo falla.

const InputSetup := preload("res://scripts/core/input_setup.gd")
const TrackScene := preload("res://scenes/track_el_prat.tscn")
const KartScene := preload("res://scenes/kart.tscn")

const ACTIONS := ["accelerate", "brake", "steer_left", "steer_right", "turbo", "look_back", "reset"]

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
	kart.drift_event.connect(func(kind: String, lvl: int):
		events.append("%s:%d" % [kind, lvl])
		if kind != "slide":
			_last_drift_time = kart.drift_time)
	await physics_frame

	await _test_no_auto_steer()
	await _test_turns_left_right()
	await _test_steer_release()
	# --- Derrape natural (v0.3) ---
	await _test_grip_moderate_turn()
	await _test_flick_slides_on_straight()
	await _test_progressive_grip_loss()
	await _test_low_speed_grips()
	await _test_slide_symmetry()
	await _test_lateral_inertia()
	await _test_countersteer_recovers()
	await _test_hold_keeps_drifting()
	await _test_brake_spin_invalid()
	# --- Mini-turbo por maniobra ---
	await _test_mini_turbo_success()
	await _test_natural_exit("suelta el gas en el derrape y pisa al enderezar", "drift", "straight")
	await _test_natural_exit("suelta en el derrape y pisa mientras sale", "drift", "recovering")
	await _test_natural_exit("suelta al contravolantear y pisa al salir", "counter", "straight")
	await _test_mini_turbo_late()
	await _test_mini_turbo_no_release()
	await _test_mini_turbo_short_drift()
	await _test_throttle_spam_no_boost()
	await _test_window_spam_single_boost()
	await _test_chain_on_straight()
	await _test_zigzag_chain()
	await _test_boost_smooth()
	# --- Generales ---
	await _test_reverse()
	await _test_turbo_top_speed()
	await _test_wall_blocks()
	await _test_cone_knock()
	await _test_offroad_slows()

	print("[tests] ", "TODO OK" if failures == 0 else "%d FALLO(S)" % failures)
	quit(0 if failures == 0 else 1)


# --- utilidades ---------------------------------------------------------------

func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)
	if kart != null:
		kart.input_override = {}


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
	var cones := get_nodes_in_group("knockable")
	if cones.is_empty():
		_check("conos", false, "no hay conos en el circuito")
		return
	# Atropella 6 conos distintos de frente y de refilón, a 100 km/h. Antes de la v0.4
	# el kart se subía encima del cono como a una rampa y salía volando (hasta 246 m).
	kart.track = track
	var moved := 0.0
	for k in 6:
		var cone: RigidBody3D = cones[(k * 3) % cones.size()]
		var start: Vector3 = cone.global_position * Vector3(1, 0, 1)
		var info: Dictionary = track.query_stateless(start)
		var dir: Vector3 = info["dir"]
		var side: Vector3 = Vector3.UP.cross(dir) * [0.0, 0.5, -0.6][k % 3]
		kart.place(Transform3D(Basis.looking_at(dir, Vector3.UP), start - dir * 15.0 + side + Vector3(0, 0.05, 0)))
		kart.velocity = dir * 28.0
		_inp({"accelerate": 1.0})
		var c0: Vector3 = cone.global_position
		for i in 50:
			await physics_frame
			_cone_max_y = maxf(_cone_max_y, kart.global_position.y)
		moved = maxf(moved, cone.global_position.distance_to(c0))
	_check("los conos salen volando", moved > 2.0 and moved < 80.0, "el cono se movió %.1f m" % moved)
	_check("atropellar un cono no levanta el kart", _cone_max_y < 0.2, "altura máx. del kart %.2f m" % _cone_max_y)
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


# =============================================================================
# Utilidades con entrada inyectada (kart.input_override): control exacto por fotograma
# =============================================================================

var events: Array = []
var _last_drift_time := 0.0
var _cone_max_y := 0.0


func _inp(d: Dictionary) -> void:
	kart.input_override = d.duplicate()
	if kart.input_override.is_empty():
		kart.input_override = {"_": 0.0}   # no vacío: ignora Input real


func _slip() -> float:
	return rad_to_deg(absf(kart.slip_angle))


## Campo abierto a velocidad punta, recto.
func _at_speed(frames: int = 240) -> void:
	_release_all()
	kart.track = null
	kart.on_road = true
	kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
	_inp({"accelerate": 1.0})
	await _frames(frames)
	events.clear()


## Volantazo a la derecha `hold` fotogramas y contravolante hasta abrir la ventana.
## Devuelve true si el derrape fue válido y la ventana se abrió.
func _drift_and_recover(hold: int, side := "steer_right") -> bool:
	var counter := "steer_left" if side == "steer_right" else "steer_right"
	_inp({"accelerate": 1.0, side: 1.0})
	await _frames(hold)
	_inp({"accelerate": 1.0, counter: 1.0})
	for i in 150:
		await physics_frame
		if _slip() < 4.0:
			_inp({"accelerate": 1.0})
		if kart.drift_state == 2:
			return true
		if kart.drift_state == 0 and i > 10:
			return false
	return false


func _boosts(kind_prefix: String) -> int:
	var n := 0
	for e in events:
		if String(e).begins_with(kind_prefix):
			n += 1
	return n


# =============================================================================
# Dirección con agarre
# =============================================================================

func _turn(side: String, steer: float, frames: int) -> Dictionary:
	await _at_speed(150)
	var p0: Vector3 = kart.global_position
	var y0 := _yaw()
	var right0: Vector3 = kart.global_transform.basis.x
	var v0: float = kart.get_speed_kmh()
	_inp({"accelerate": 1.0, side: steer})
	var mx := 0.0
	for i in frames:
		await physics_frame
		mx = maxf(mx, _slip())
	return {"dyaw": angle_difference(y0, _yaw()), "lateral": (kart.global_position - p0).dot(right0),
			"keep": kart.get_speed_kmh() / v0, "slip": mx}


func _test_turns_left_right() -> void:
	var l := await _turn("steer_left", 0.45, 60)
	var r := await _turn("steer_right", 0.45, 60)
	_check("giro a la izquierda (45 % de volante)", l["dyaw"] > 0.4 and l["lateral"] < -2.0,
			"%.2f rad, %.1f m a la izquierda" % [l["dyaw"], -l["lateral"]])
	_check("giro a la derecha (45 % de volante)", r["dyaw"] < -0.4 and r["lateral"] > 2.0,
			"%.2f rad, %.1f m a la derecha" % [-r["dyaw"], r["lateral"]])
	var sym_yaw := absf(l["dyaw"] + r["dyaw"])
	var sym_lat := absf(l["lateral"] + r["lateral"])
	_check("izquierda y derecha simétricas", sym_yaw < 0.005 and sym_lat < 0.05,
			"diferencia %.4f rad / %.3f m" % [sym_yaw, sym_lat])
	_check("sin freno automático en curva", l["keep"] > 0.97 and r["keep"] > 0.97,
			"conserva %.0f%% / %.0f%% de la velocidad" % [l["keep"] * 100.0, r["keep"] * 100.0])


func _test_steer_release() -> void:
	await _at_speed(150)
	_inp({"accelerate": 1.0, "steer_right": 0.45})
	await _frames(30)
	_inp({"accelerate": 1.0})
	await _frames(18)
	var rate_after: float = kart.yaw_rate
	await _frames(11)
	var y0 := _yaw()
	await _frames(60)
	var drift := absf(angle_difference(y0, _yaw()))
	_check("al soltar, el giro se detiene en <0,3 s (inercia de la carrocería)", absf(rate_after) < 0.05, "giro residual %.3f rad/s" % rate_after)
	_check("después sigue recto (sin autocorrección)", drift < 0.0005, "%.5f rad en 1 s" % drift)


# =============================================================================
# Derrape natural
# =============================================================================

func _test_grip_moderate_turn() -> void:
	var r := await _turn("steer_right", 0.35, 60)
	_check("giro normal (35 %) a 104 km/h: agarra", r["slip"] < 4.0, "deriva máxima %.1f°" % r["slip"])
	# Pasarse de giro (75 %) en recta ya provoca el derrape
	var o := await _turn("steer_right", 0.75, 40)
	_check("pasarse de giro (75 %) en recta: derrapa", o["slip"] > 10.0 and events.size() > 0 and String(events[0]).begins_with("slide"),
			"deriva máxima %.1f°, eventos %s" % [o["slip"], str(events)])


func _test_flick_slides_on_straight() -> void:
	await _at_speed()
	_inp({"accelerate": 1.0, "steer_right": 1.0})
	var mx := 0.0
	var t_enter := -1.0
	for i in 48:
		await physics_frame
		mx = maxf(mx, _slip())
		if t_enter < 0.0 and kart.drift_state == 1:
			t_enter = (i + 1) / 60.0
	_check("volantazo en recta: pierde agarre y derrapa", mx > 15.0 and t_enter > 0.0,
			"deriva %.1f°, derrape desde %.2f s, %.1f m/s laterales (campo abierto, sin curva)" % [mx, t_enter, absf(kart.lateral_speed)])


func _test_progressive_grip_loss() -> void:
	await _at_speed()
	_inp({"accelerate": 1.0, "steer_right": 1.0})
	var series: Array[float] = []
	var max_step := 0.0
	var prev := 0.0
	for i in 60:
		await physics_frame
		series.append(_slip())
		max_step = maxf(max_step, absf(_slip() - prev))
		prev = _slip()
	var grows: bool = series[15] < series[30] and series[30] < series[45] and series[15] < 12.0
	_check("pérdida de agarre progresiva", grows and max_step < 2.5,
			"deriva %.1f° → %.1f° → %.1f° (0,25 / 0,5 / 0,75 s), salto máx. %.2f°/fotograma" % [series[15], series[30], series[45], max_step])


## Acelera hasta `kmh` y luego hace zigzag `changes` veces (volante `amount`, cambio cada 0,5 s)
## manteniendo esa velocidad con el gas. Devuelve [deriva máx., derrapes].
func _zigzag_at(kmh: float, amount: float, changes := 4) -> Array:
	_release_all()
	kart.track = null
	kart.on_road = true
	kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
	_inp({"accelerate": 1.0})
	var guard := 0
	while kart.get_speed_kmh() < kmh and guard < 600:
		await physics_frame
		guard += 1
	events.clear()
	var mx := 0.0
	var side := 1.0
	for c in changes:
		for i in 30:
			var o := {"accelerate": 1.0 if kart.get_speed_kmh() < kmh else 0.0}
			o["steer_right" if side > 0 else "steer_left"] = amount
			_inp(o)
			await physics_frame
			mx = maxf(mx, _slip())
		side = -side
	return [mx, _boosts("slide")]


func _test_low_speed_grips() -> void:
	await _at_speed(22)   # ~25 km/h
	var v: float = kart.get_speed_kmh()
	_inp({"accelerate": 0.0, "steer_right": 1.0})
	var mx := 0.0
	for i in 60:
		await physics_frame
		mx = maxf(mx, _slip())
	_check("a baja velocidad no derrapa", mx < 3.0, "%.0f km/h, volante a fondo: deriva %.1f°" % [v, mx])
	# Velocidad media (50 km/h): ni con el volante a fondo en zigzag
	var r50: Array = await _zigzag_at(50.0, 1.0)
	_check("a velocidad media (50 km/h) no derrapa ni con el volante a fondo", r50[1] == 0 and r50[0] < 4.0,
			"zigzag a fondo: deriva máx. %.1f°, %d derrapes" % [r50[0], r50[1]])
	# Un poco por encima de la media (70 km/h, punta 104): pasarse de giro ya derrapa
	var r70: Array = await _zigzag_at(70.0, 0.75)
	_check("algo por encima de la media (70 km/h) pasarse de giro derrapa", r70[1] >= 1 and r70[0] > 10.0,
			"zigzag al 75 %%: deriva máx. %.1f°, %d derrapes" % [r70[0], r70[1]])


func _slide_series(side: String) -> Array[float]:
	await _at_speed()
	_inp({"accelerate": 1.0, side: 1.0})
	var out: Array[float] = []
	for i in 60:
		await physics_frame
		out.append(rad_to_deg(kart.slip_angle))
	return out


func _test_slide_symmetry() -> void:
	var r := await _slide_series("steer_right")
	var l := await _slide_series("steer_left")
	var diff := 0.0
	for i in r.size():
		diff = maxf(diff, absf(r[i] + l[i]))
	_check("derrape simétrico izquierda/derecha", diff < 0.05 and absf(r[59]) > 15.0,
			"derecha %.1f° / izquierda %.1f°, diferencia máx. %.3f°" % [r[59], l[59], diff])


func _test_lateral_inertia() -> void:
	await _at_speed()
	_inp({"accelerate": 1.0, "steer_right": 1.0})
	await _frames(60)
	_inp({"accelerate": 1.0})
	var t := 0.0
	while _slip() > 5.0 and t < 3.0:
		await physics_frame
		t += 1.0 / 60.0
	_check("conserva inercia lateral al soltar el volante", t > 0.6, "sigue deslizando %.2f s" % t)


func _recovery_time(mode: String) -> float:
	await _at_speed()
	_inp({"accelerate": 1.0, "steer_right": 1.0})
	await _frames(60)
	var d := {"accelerate": 1.0}
	if mode == "contravolante":
		d["steer_left"] = 1.0
	_inp(d)
	var t := 0.0
	while _slip() > 5.0 and t < 4.0:
		await physics_frame
		t += 1.0 / 60.0
		if mode == "contravolante" and _slip() < 8.0:
			_inp({"accelerate": 1.0})
	return t


func _test_countersteer_recovers() -> void:
	var tn := await _recovery_time("neutro")
	var tc := await _recovery_time("contravolante")
	_check("contravolante endereza mucho antes", tc < tn * 0.65 and tc < 1.0,
			"contravolante %.2f s / volante suelto %.2f s" % [tc, tn])


func _test_hold_keeps_drifting() -> void:
	await _at_speed()
	_inp({"accelerate": 1.0, "steer_right": 1.0})
	var mn := 999.0
	var mx := 0.0
	await _frames(60)
	for i in 120:
		await physics_frame
		mn = minf(mn, _slip())
		mx = maxf(mx, _slip())
	_check("volante a fondo: derrape sostenido y controlable (sin trompo)", mn > 18.0 and mx < 60.0,
			"deriva entre %.1f° y %.1f° durante 2 s, %.0f km/h" % [mn, mx, kart.get_speed_kmh()])


func _test_brake_spin_invalid() -> void:
	await _at_speed()
	_inp({"accelerate": 1.0, "steer_right": 1.0})
	await _frames(40)
	_inp({"brake": 1.0, "steer_right": 1.0})
	var mx := 0.0
	for i in 90:
		await physics_frame
		mx = maxf(mx, _slip())
	# recuperar y comprobar que no da turbo
	_inp({"accelerate": 1.0})
	await _frames(120)
	var spin := "fail_spin" in events.map(func(e): return String(e).split(":")[0])
	_check("frenar a fondo derrapando provoca trompo y anula el derrape", mx > 85.0 and spin and _boosts("success") == 0,
			"deriva máx. %.0f°, eventos %s" % [mx, str(events)])


# =============================================================================
# Mini-turbo por maniobra
# =============================================================================

func _test_mini_turbo_success() -> void:
	await _at_speed()
	var ok := await _drift_and_recover(60)
	var lvl: int = kart.drift_level
	var v0: float = kart.get_speed_kmh()
	_inp({})                       # suelta el acelerador
	await _frames(6)               # 0,1 s
	_inp({"accelerate": 1.0})      # vuelve a pisar
	await _frames(2)
	var got := _boosts("success")
	var boosting: bool = kart.boost_time > 0.0
	await _frames(30)
	_check("enderezar + soltar y pisar = mini-turbo", ok and got == 1 and boosting and kart.get_speed_kmh() > v0,
			"ventana %s, nivel %d, %.0f → %.0f km/h, eventos %s" % [str(ok), lvl, v0, kart.get_speed_kmh(), str(events)])


func _test_mini_turbo_late() -> void:
	await _at_speed()
	var ok := await _drift_and_recover(60)
	await _frames(int(kart.boost_window * 60.0) + 6)   # se pasa la ventana
	_inp({})
	await _frames(6)
	_inp({"accelerate": 1.0})
	await _frames(5)
	_check("pisar fuera de la ventana no da impulso", ok and _boosts("success") == 0 and _boosts("fail_") >= 1,
			"eventos %s" % str(events))


func _test_mini_turbo_no_release() -> void:
	await _at_speed()
	var ok := await _drift_and_recover(60)
	await _frames(int(kart.boost_window * 60.0) + 6)
	_check("sin soltar el acelerador no hay impulso", ok and _boosts("success") == 0 and _boosts("fail_lift") == 1,
			"eventos %s" % str(events))


func _test_mini_turbo_short_drift() -> void:
	# Volantazo de solo 0,25 s y contravolante: el kart se cruza un poco pero no lo
	# bastante tiempo para que cuente como derrape válido.
	await _at_speed()
	_inp({"accelerate": 1.0, "steer_right": 1.0})
	await _frames(8)
	_inp({"accelerate": 1.0, "steer_left": 1.0})
	var mx := 0.0
	for i in 120:
		await physics_frame
		mx = maxf(mx, _slip())
		if _slip() < 4.0:
			_inp({"accelerate": 1.0})
	_inp({})
	await _frames(5)
	_inp({"accelerate": 1.0})
	await _frames(5)
	_check("derrape demasiado corto no cuenta", _boosts("success") == 0 and _boosts("window") == 0,
			"golpe de volante de 0,13 s: deriva máx. %.1f°, eventos %s" % [mx, str(events)])


func _test_throttle_spam_no_boost() -> void:
	await _at_speed()
	var before: int = kart.mini_turbos
	for i in 180:
		_inp({"accelerate": 1.0 if (i / 3) % 2 == 0 else 0.0})
		await physics_frame
	_check("pisar repetidamente sin derrapar no da turbos", kart.mini_turbos == before and _boosts("success") == 0,
			"3 s machacando el acelerador: %d mini-turbos" % _boosts("success"))


func _test_window_spam_single_boost() -> void:
	await _at_speed()
	var ok := await _drift_and_recover(60)
	for i in 40:
		_inp({"accelerate": 1.0 if (i / 4) % 2 == 1 else 0.0})   # toques de 0,067 s
		await physics_frame
	_inp({"accelerate": 1.0})
	await _frames(10)
	_check("machacar en la ventana da un solo mini-turbo", ok and _boosts("success") == 1,
			"eventos %s" % str(events))


func _test_chain_on_straight() -> void:
	await _at_speed()
	var got := 0
	var sides := ["steer_right", "steer_left", "steer_right"]
	for side in sides:
		var ok := await _drift_and_recover(55, side)
		if ok:
			_inp({})
			await _frames(5)
			_inp({"accelerate": 1.0})
			await _frames(20)
	got = _boosts("success")
	_check("encadenar derrapes y mini-turbos en recta", got == 3 and kart.get_speed_kmh() > 85.0,
			"%d mini-turbos seguidos, %.0f km/h al final" % [got, kart.get_speed_kmh()])


## Salidas "naturales" del derrape (lo que hace un jugador): soltar el gas en algún momento
## del derrape y volver a acelerar al salir. Todas deben dar un mini-turbo que se note.
func _test_natural_exit(label: String, lift_at: String, press_at: String) -> void:
	await _at_speed(200)
	var gas := 1.0
	for i in 40:
		if lift_at == "drift" and i == 15:
			gas = 0.0
		_inp({"accelerate": gas, "steer_right": 1.0})
		await physics_frame
	var counter := true
	var vmin := 999.0
	var vmax := 0.0
	var straight := -1
	for i in 150:
		var s := _slip()
		if s < 4.0:
			counter = false
			if straight < 0:
				straight = i
		if lift_at == "counter" and i == 0:
			gas = 0.0
		if press_at == "recovering" and gas == 0.0 and s < 12.0:
			gas = 1.0
		if press_at == "straight" and gas == 0.0 and straight >= 0 and i >= straight + 8:
			gas = 1.0
		var d := {"accelerate": gas}
		if counter:
			d["steer_left"] = 1.0
		_inp(d)
		await physics_frame
		vmin = minf(vmin, kart.get_speed_kmh())
		if _boosts("success") > 0:
			vmax = maxf(vmax, kart.get_speed_kmh())
	_check("mini-turbo natural: " + label, _boosts("success") == 1 and vmax > 112.0,
			"sale a %.0f km/h → impulso hasta %.0f km/h (punta normal 104)" % [vmin, vmax])


## Zigzag en recta: volante al 75 % cambiando de lado cada 0,5 s, soltando el gas al cambiar
## y pisando enseguida. Debe derrapar y encadenar mini-turbos sin salirse de una calle de 24 m.
func _test_zigzag_chain() -> void:
	await _at_speed(200)
	var x0: float = kart.global_position.x
	var maxdev := 0.0
	var side := 1.0
	for k in 8:
		var steps := 15 if k == 0 else 30
		for i in steps:
			var d := {"accelerate": 0.0 if (i < 9 and k > 0) else 1.0}
			d["steer_right" if side > 0 else "steer_left"] = 0.75
			_inp(d)
			await physics_frame
			maxdev = maxf(maxdev, absf(kart.global_position.x - x0))
		side = -side
	var slides := 0
	for e in events:
		if String(e).begins_with("slide"):
			slides += 1
	# Sin corregir la trayectoria (un jugador sí corrige): v0.5.1 daba 0 turbos aquí.
	_check("zigzag en recta: derrapa y encadena mini-turbos", slides >= 6 and _boosts("success") >= 5 and maxdev < 15.0,
			"%d derrapes, %d mini-turbos, se aparta ±%.1f m de la recta" % [slides, _boosts("success"), maxdev])


## El mini-turbo empuja de forma pareja: nunca más de 16 km/h en 0,1 s (v0.5.1: 38,6, un tirón).
func _test_boost_smooth() -> void:
	await _at_speed(200)
	_inp({"accelerate": 0.0, "steer_right": 1.0})
	await _frames(40)
	_inp({"accelerate": 0.0, "steer_left": 1.0})
	while _slip() > 12.0:
		await physics_frame
	_inp({"accelerate": 1.0})
	var prev: float = kart.get_speed_kmh()
	var max_jump := 0.0
	var vmax := 0.0
	for i in 15:
		await _frames(6)
		var v: float = kart.get_speed_kmh()
		max_jump = maxf(max_jump, v - prev)
		vmax = maxf(vmax, v)
		prev = v
	_check("mini-turbo como empuje parejo (sin tirón)", _boosts("success") == 1 and max_jump < 16.0 and vmax > 110.0 and vmax < 132.0,
			"subida máx. %.1f km/h por 0,1 s, pico %.0f km/h" % [max_jump, vmax])
