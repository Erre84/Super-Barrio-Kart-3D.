extends CharacterBody3D
## Kart del jugador: conducción arcade.
##
## Filosofía de manejo (v0.2):
##  - La dirección SOLO cambia por la entrada del jugador. No hay asistencia que
##    enderece el kart, ni lo alinee con la carretera, ni frene antes de las curvas.
##  - Volante con tres velocidades distintas: al girar, al soltar (vuelve rápido al
##    centro) y al cambiar de lado (más rápido aún, para corregir con precisión).
##    Con stick analógico la respuesta es directa.
##  - Derrape progresivo: al entrar, el ángulo de deslizamiento y el giro crecen
##    durante `drift_entry_time` en vez de aparecer de golpe. Durante el derrape:
##      · girar HACIA la curva la cierra y aumenta el ángulo,
##      · CONTRAVOLANTE la abre y reduce el ángulo (sin salir del derrape).
##  - Mini-turbo de tres niveles al soltar el derrape; turbo con barra; pads.
##
## Todos los parámetros son @export: se ajustan desde el inspector del nodo Kart.

signal wall_hit(strength: float)
signal boost_started(kind: String)
signal drift_level_changed(level: int)
signal landed(impact: float)

const KartModel := preload("res://scripts/kart/kart_model.gd")
const KartEffects := preload("res://scripts/kart/kart_effects.gd")

@export_group("Motor")
@export var max_speed := 29.0          ## m/s (≈105 km/h)
@export var acceleration := 17.0       ## m/s² arrancando; se reduce cerca de la punta
@export var accel_falloff := 0.72      ## cuánto cae la aceleración al acercarse a la punta (0-1)
@export var brake_decel := 34.0        ## m/s² frenando
@export var reverse_accel := 12.0      ## m/s² en marcha atrás
@export var reverse_max := 9.0         ## m/s máximos marcha atrás
@export var coast_decel := 4.0         ## m/s² sin acelerar ni frenar (rozamiento, NO freno automático)

@export_group("Dirección")
@export var turn_speed := 2.15         ## rad/s con el volante a fondo
@export var full_steer_speed := 5.0    ## m/s a partir de los que el giro es completo
@export var high_speed_steer := 0.52   ## fracción de giro a velocidad punta
@export var steer_press_rate := 8.5    ## volante (teclado/botón): rapidez al girar (1/s)
@export var steer_release_rate := 14.0 ## rapidez al soltar (vuelve al centro)
@export var steer_reverse_rate := 18.0 ## rapidez al cambiar de lado
@export var grip := 11.0               ## agarre lateral (1/s): más = más preciso
@export var corner_speed_keep := 0.75  ## velocidad que se conserva al girar con gas (0-1)

@export_group("Derrape")
@export var drift_min_speed := 10.0    ## m/s mínimos para entrar en derrape
@export var hop_velocity := 3.4        ## saltito al pulsar derrape
@export var drift_entry_time := 0.3    ## s que tarda el derrape en "asentarse"
@export var drift_turn_base := 0.72    ## giro en derrape sin tocar el volante (× turn_speed)
@export var drift_turn_range := 0.45   ## cuánto cierra (+) o abre (−) el volante en derrape
@export var drift_slip_min := 0.16     ## rad de deslizamiento con contravolante a fondo
@export var drift_slip_max := 0.48     ## rad de deslizamiento cerrando a fondo
@export var drift_slip_rate := 1.6     ## rad/s a los que cambia el ángulo de deslizamiento
@export var drift_align := 7.0         ## rapidez con la que la trayectoria sigue al ángulo objetivo
@export var drift_friction := 1.2      ## m/s² que cuesta derrapar
@export var drift_grip := 2.4          ## agarre lateral si se derrapa en el aire
@export var drift_charge_into := 0.55  ## carga extra del mini-turbo cerrando la curva
@export var mini_turbo_levels: Array[float] = [0.9, 1.9, 3.0]  ## s de carga por nivel
@export var mini_turbo_time: Array[float] = [0.65, 1.1, 1.6]   ## s de turbo por nivel

@export_group("Turbo")
@export var boost_speed_mult := 1.32
@export var boost_accel := 34.0
@export var turbo_time := 1.4
@export var turbo_recharge := 9.0      ## s para llenar la barra

@export_group("Fuera de pista")
@export var offroad_speed_mult := 0.55
@export var offroad_drag := 22.0

@export_group("Choques")
@export var wall_speed_loss := 0.5     ## fracción de velocidad perdida en choque frontal
@export var wall_bounce := 3.5         ## m/s de rebote

const GRAVITY := 24.0

var model: KartModel
var effects: KartEffects
var track: Node = null
var controls_enabled := false

# Estado público (lo leen la cámara, el HUD, los efectos y las pruebas)
var steer_value := 0.0
var forward_speed := 0.0
var yaw_rate := 0.0
var drifting := false
var drift_dir := 0
var drift_time := 0.0
var drift_slip := 0.0        ## ángulo actual (rad) entre morro y trayectoria
var drift_charge := 0.0
var drift_level := 0
var boost_time := 0.0
var turbo_meter := 1.0
var on_road := true
var braking_input := 0.0
var track_info := {}
var last_impact := 0.0
var airborne_time := 0.0

var _pad_cooldown := 0.0
var _was_on_floor := true
var _fall_speed := 0.0


func _ready() -> void:
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(40)
	wall_min_slide_angle = deg_to_rad(5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 0.8, 2.6)
	shape.shape = box
	shape.position = Vector3(0, 0.42, 0.05)
	add_child(shape)

	model = KartModel.new()
	model.name = "Model"
	add_child(model)
	model.build()
	effects = KartEffects.new()
	effects.name = "Effects"
	add_child(effects)
	effects.setup(self)
	landed.connect(func(impact: float): model.bump(impact))
	wall_hit.connect(func(strength: float): model.bump(clampf(strength / 30.0, 0.0, 0.6)))


# --- Entrada --------------------------------------------------------------------

func _update_steering(steer_in: float, delta: float) -> void:
	var digital := absf(steer_in) > 0.99 or absf(steer_in) < 0.01
	if not digital:
		steer_value = steer_in   # stick analógico: directo
		return
	var rate := steer_press_rate
	if absf(steer_in) < 0.01:
		rate = steer_release_rate
	elif steer_value != 0.0 and signf(steer_in) != signf(steer_value):
		rate = steer_reverse_rate
	steer_value = move_toward(steer_value, steer_in, rate * delta)


# --- Bucle principal ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var braking := 0.0
	var steer_in := 0.0
	var drift_held := false
	var drift_pressed := false
	if controls_enabled:
		throttle = Input.get_action_strength("accelerate")
		braking = Input.get_action_strength("brake")
		steer_in = Input.get_axis("steer_left", "steer_right")
		drift_held = Input.is_action_pressed("drift")
		drift_pressed = Input.is_action_just_pressed("drift")
		if Input.is_action_just_pressed("turbo"):
			try_turbo()
		if Input.is_action_just_pressed("reset"):
			respawn()
			return
	braking_input = braking
	_update_steering(steer_in, delta)

	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var f := planar.dot(fwd)
	var l := planar.dot(right)
	var speed_before := planar.length()

	# Superficie
	if track != null:
		track_info = track.query(global_position)
		on_road = track_info.get("on_road", true)
	var top := max_speed
	if boost_time > 0.0:
		top *= boost_speed_mult
	elif not on_road:
		top *= offroad_speed_mult

	# --- Motor y frenos (solo con ruedas en el suelo). Sin freno automático. ---
	var grounded := is_on_floor()
	if grounded:
		if throttle > 0.0 and braking < 0.5:
			if f < -0.5:
				f = minf(f + brake_decel * delta, 0.0)       # acelerar estando marcha atrás = frenar
			elif f < top:
				var ratio := maxf(f, 0.0) / top
				f = minf(f + acceleration * throttle * (1.0 - accel_falloff * ratio * ratio) * delta, top)
		elif braking > 0.0:
			if f > 0.5:
				f = maxf(f - brake_decel * braking * delta, 0.0)
			else:
				f = maxf(f - reverse_accel * braking * delta, -reverse_max)
		else:
			f = move_toward(f, 0.0, coast_decel * delta)
		if boost_time > 0.0:
			f = minf(f + boost_accel * delta, top)
		elif f > top:
			f = move_toward(f, top, (offroad_drag if not on_road else 10.0) * delta)

	# --- Derrape: entrada, mantenimiento y salida ---
	if drift_pressed and grounded and absf(f) > 4.0:
		velocity.y = hop_velocity
		grounded = false
	if not drifting and drift_held and grounded and absf(steer_value) > 0.35 and f > drift_min_speed:
		_start_drift(1 if steer_value > 0.0 else -1, planar, fwd)
	if drifting:
		if not drift_held:
			_release_drift()
		elif f < drift_min_speed * 0.6:
			_cancel_drift()
		else:
			drift_time += delta
			if grounded:
				var into := clampf(steer_value * drift_dir, 0.0, 1.0)
				drift_charge += delta * (0.75 + drift_charge_into * into)
				var lvl := 0
				for i in mini_turbo_levels.size():
					if drift_charge >= mini_turbo_levels[i]:
						lvl = i + 1
				if lvl != drift_level:
					drift_level = lvl
					drift_level_changed.emit(drift_level)

	# --- Velocidad resultante ---
	var new_planar: Vector3
	if drifting and grounded:
		# Velocidad conservada; la trayectoria va "por fuera" del morro con un ángulo
		# que crece progresivamente hacia el objetivo marcado por el volante.
		var s := steer_value * drift_dir                       # +1 cerrar, −1 contravolante
		var slip_target := lerpf(drift_slip_min, drift_slip_max, (s + 1.0) * 0.5)
		var entry := _drift_entry()
		drift_slip = move_toward(drift_slip, slip_target * entry, drift_slip_rate * delta)
		var spd := planar.length()
		if throttle > 0.0:
			var ratio := spd / top
			spd = minf(spd + acceleration * throttle * (1.0 - accel_falloff * ratio * ratio) * delta, maxf(top, spd))
		else:
			spd = move_toward(spd, 0.0, coast_decel * delta)
		spd = move_toward(spd, 0.0, drift_friction * delta)
		if boost_time > 0.0:
			spd = minf(spd + boost_accel * delta, top)
		elif spd > top:
			spd = move_toward(spd, top, 10.0 * delta)
		var travel := fwd.rotated(Vector3.UP, drift_dir * drift_slip)
		var cur_dir := planar.normalized() if planar.length() > 0.1 else fwd
		var nd := cur_dir.slerp(travel, 1.0 - exp(-drift_align * delta)).normalized()
		new_planar = nd * spd
		f = new_planar.dot(fwd)
	else:
		if not drifting:
			drift_slip = move_toward(drift_slip, 0.0, drift_slip_rate * 2.0 * delta)
		var g := drift_grip if drifting else grip
		if not grounded:
			g *= 0.15
		elif not on_road:
			g *= 0.7
		l *= exp(-g * delta)
		new_planar = fwd * f + right * l
		# El agarre "come" velocidad lateral; con gas conservamos parte (sensación arcade).
		var target_len := lerpf(new_planar.length(), maxf(absf(f), speed_before), corner_speed_keep)
		if new_planar.length() > 0.01 and grounded and throttle > 0.0:
			new_planar = new_planar.normalized() * minf(target_len, maxf(top, absf(f)))
	forward_speed = f

	# --- Giro: solo por la entrada del jugador ---
	var speed_ratio := clampf(absf(f) / max_speed, 0.0, 1.0)
	var authority := clampf(absf(f) / full_steer_speed, 0.0, 1.0) * lerpf(1.0, high_speed_steer, speed_ratio)
	var normal_yaw := -steer_value * turn_speed * authority * signf(f)
	if drifting:
		var s := steer_value * drift_dir
		var drift_yaw := -drift_dir * turn_speed * (drift_turn_base + drift_turn_range * s)
		yaw_rate = lerpf(normal_yaw, drift_yaw, _drift_entry())
	else:
		yaw_rate = normal_yaw
	if not grounded:
		yaw_rate *= 0.6
	rotate_y(yaw_rate * delta)

	# --- Gravedad y movimiento ---
	velocity.x = new_planar.x
	velocity.z = new_planar.z
	if grounded and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	_fall_speed = minf(_fall_speed, velocity.y)
	var pre_move := velocity
	move_and_slide()
	_handle_collisions(pre_move)

	# --- Aterrizaje (para el rebote visual) ---
	var on_floor_now := is_on_floor()
	if on_floor_now and not _was_on_floor:
		landed.emit(clampf(-_fall_speed / 6.0, 0.0, 1.0))
		_fall_speed = 0.0
	if on_floor_now:
		_fall_speed = 0.0
	_was_on_floor = on_floor_now

	# --- Temporizadores ---
	boost_time = maxf(boost_time - delta, 0.0)
	turbo_meter = minf(turbo_meter + delta / turbo_recharge, 1.0)
	_pad_cooldown = maxf(_pad_cooldown - delta, 0.0)
	if track != null and _pad_cooldown <= 0.0 and track.is_on_boost_pad(global_position):
		apply_boost(1.0, "pad")
		_pad_cooldown = 0.6
	airborne_time = 0.0 if on_floor_now else airborne_time + delta
	if global_position.y < -6.0:
		respawn()


func _drift_entry() -> float:
	return smoothstep(0.0, maxf(drift_entry_time, 0.001), drift_time)


func _handle_collisions(pre_move: Vector3) -> void:
	last_impact = 0.0
	var pre_planar := Vector3(pre_move.x, 0, pre_move.z)
	var spd := pre_planar.length()
	if spd < 0.5:
		return
	var wall_normal := Vector3.ZERO
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.6:
			continue
		var other := c.get_collider()
		if other is RigidBody3D:
			# Conos y objetos sueltos: salen volando y apenas nos frenan.
			var rb := other as RigidBody3D
			if rb.linear_velocity.length() < 4.0:  # un solo empujón por golpe
				rb.sleeping = false
				rb.apply_central_impulse(pre_planar * rb.mass * 0.45 + Vector3.UP * rb.mass * 3.0)
				rb.apply_torque_impulse(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * rb.mass)
			velocity.x = pre_planar.x * 0.93
			velocity.z = pre_planar.z * 0.93
			continue
		# Las caras de los muros pueden devolver la normal del lado contrario: la orientamos hacia el kart
		if n.dot(pre_planar) > 0.0:
			n = -n
		var impact := clampf(-pre_planar.normalized().dot(n), 0.0, 1.0)
		if impact < 0.08:
			continue
		if impact > last_impact:
			last_impact = impact
			wall_normal = Vector3(n.x, 0.0, n.z).normalized()
	if last_impact > 0.0:
		velocity.x *= 1.0 - wall_speed_loss * last_impact
		velocity.z *= 1.0 - wall_speed_loss * last_impact
		velocity += wall_normal * last_impact * wall_bounce
		if drifting and last_impact > 0.35:
			_cancel_drift()
		wall_hit.emit(last_impact * spd)


# --- Derrape y turbo --------------------------------------------------------------

func _start_drift(dir: int, planar: Vector3, fwd: Vector3) -> void:
	drifting = true
	drift_dir = dir
	drift_time = 0.0
	drift_charge = 0.0
	drift_level = 0
	# Partimos del ángulo real que ya llevara el kart (sin saltos)
	if planar.length() > 1.0:
		drift_slip = clampf(absf(fwd.signed_angle_to(planar.normalized(), Vector3.UP)), 0.0, drift_slip_max)
	else:
		drift_slip = 0.0


func _release_drift() -> void:
	if drift_level > 0:
		apply_boost(mini_turbo_time[drift_level - 1], "mini%d" % drift_level)
		turbo_meter = minf(turbo_meter + 0.08 * drift_level, 1.0)
	_cancel_drift()


func _cancel_drift() -> void:
	drifting = false
	drift_dir = 0
	drift_time = 0.0
	drift_charge = 0.0
	if drift_level != 0:
		drift_level = 0
		drift_level_changed.emit(0)


func try_turbo() -> bool:
	if turbo_meter < 1.0:
		return false
	turbo_meter = 0.0
	apply_boost(turbo_time, "turbo")
	return true


func apply_boost(seconds: float, kind: String) -> void:
	boost_time = maxf(boost_time, seconds)
	boost_started.emit(kind)


func respawn() -> void:
	_cancel_drift()
	velocity = Vector3.ZERO
	boost_time = 0.0
	drift_slip = 0.0
	if track != null:
		global_transform = track.respawn_transform(global_position)
	else:
		global_position.y = 1.0


func place(t: Transform3D) -> void:
	global_transform = t
	velocity = Vector3.ZERO
	steer_value = 0.0
	yaw_rate = 0.0
	drift_slip = 0.0
	_cancel_drift()
	boost_time = 0.0
	turbo_meter = 1.0


func get_speed_kmh() -> float:
	return Vector3(velocity.x, 0, velocity.z).length() * 3.6


# --- Animación del modelo -------------------------------------------------------

func _process(delta: float) -> void:
	if model == null:
		return
	var planar := Vector3(velocity.x, 0, velocity.z)
	var fwd := -global_transform.basis.z
	var state := {
		"distance": planar.dot(fwd) * delta,
		"speed": planar.length(),
		"speed_ratio": clampf(planar.length() / max_speed, 0.0, 1.3),
		"steer": steer_value,
		"drifting": drifting,
		"drift_dir": drift_dir,
		"drift_slip": drift_slip,
		"yaw_rate": yaw_rate,
		"boost": boost_time > 0.0,
		"braking": braking_input > 0.1 and forward_speed > 3.0,
		"grounded": is_on_floor(),
		"vertical_speed": velocity.y,
		"look_back": controls_enabled and Input.is_action_pressed("look_back"),
	}
	model.update_visual(state, delta)
