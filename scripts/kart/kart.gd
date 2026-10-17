extends CharacterBody3D
## Kart del jugador: conducción arcade.
##
## Filosofía de manejo:
##  - La dirección solo cambia por la entrada del jugador: no hay asistencia que
##    "enderece" el kart ni que lo alinee con la carretera.
##  - El giro de la carrocería no arrastra la velocidad al instante: el agarre
##    lateral la va absorbiendo. Con mucho agarre es preciso; en derrape desliza.
##  - Derrape: pulsar derrape da un saltito; manteniéndolo y girando se entra en
##    derrape. Cuanto más dura, más nivel de mini-turbo (azul, naranja, morado).
##  - Turbo: barra que se recarga sola; pads de turbo en la pista.

signal wall_hit(strength: float)
signal boost_started(kind: String)
signal drift_level_changed(level: int)

const KartModel := preload("res://scripts/kart/kart_model.gd")
const PARTICLE_MATERIAL := preload("res://materials/particle.tres")

@export_group("Motor")
@export var max_speed := 29.0          ## m/s (~105 km/h)
@export var acceleration := 17.0       ## m/s² a baja velocidad
@export var brake_decel := 34.0
@export var reverse_max := 9.0
@export var coast_decel := 4.0
@export_group("Dirección")
@export var turn_speed := 2.15         ## rad/s con el stick a fondo
@export var steer_response := 9.0      ## velocidad a la que el volante llega a la entrada (digital)
@export var grip := 11.0               ## absorción de velocidad lateral (1/s)
@export var high_speed_steer := 0.52   ## fracción de giro a velocidad máxima
@export_group("Derrape")
@export var drift_grip := 2.4          ## agarre lateral si se derrapa en el aire
@export var drift_slip := 0.32         ## ángulo (rad) entre el morro y la trayectoria al derrapar
@export var drift_align := 7.0         ## rapidez con la que la trayectoria sigue al morro
@export var drift_friction := 1.2      ## pérdida de velocidad por derrapar (m/s²)
@export var drift_min_speed := 10.0
@export var drift_turn_base := 0.72
@export var drift_turn_range := 0.45
@export var hop_velocity := 3.4
@export var mini_turbo_levels: Array[float] = [0.9, 1.9, 3.0]
@export var mini_turbo_time: Array[float] = [0.65, 1.1, 1.6]
@export_group("Turbo")
@export var boost_speed_mult := 1.32
@export var boost_accel := 34.0
@export var turbo_time := 1.4
@export var turbo_recharge := 9.0      ## segundos para llenar la barra
@export_group("Fuera de pista")
@export var offroad_speed_mult := 0.55
@export var offroad_drag := 22.0

const GRAVITY := 24.0

var model: KartModel
var track: Node = null
var controls_enabled := false

var steer_value := 0.0
var forward_speed := 0.0
var drifting := false
var drift_dir := 0
var drift_charge := 0.0
var drift_level := 0
var boost_time := 0.0
var turbo_meter := 1.0
var on_road := true
var track_info := {}
var last_impact := 0.0

var _pad_cooldown := 0.0
var _sparks: Array[CPUParticles3D] = []
var _flames: Array[CPUParticles3D] = []
var _dust: CPUParticles3D
var _smoke: Array[CPUParticles3D] = []
var _airborne_time := 0.0


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
	_build_effects()


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

	# Volante: con stick analógico la respuesta es directa; con teclado/botón
	# se suaviza un poco (0 -> 1 en ~0,1 s) para poder corregir con precisión.
	var digital := absf(steer_in) > 0.99 or absf(steer_in) < 0.01
	if digital:
		steer_value = move_toward(steer_value, steer_in, steer_response * delta)
	else:
		steer_value = steer_in

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

	# --- Motor y frenos (solo con ruedas en el suelo) ---
	var grounded := is_on_floor()
	if grounded:
		if throttle > 0.0 and braking < 0.5:
			if f < 0.0:
				f = minf(f + brake_decel * delta, 0.0) if f < -0.5 else f + acceleration * delta
			elif f < top:
				var ratio := f / top
				f = minf(f + acceleration * throttle * (1.0 - 0.72 * ratio * ratio) * delta, top)
		elif braking > 0.0:
			if f > 0.5:
				f = maxf(f - brake_decel * braking * delta, 0.0)
			else:
				f = maxf(f - acceleration * 0.7 * braking * delta, -reverse_max)
		else:
			f = move_toward(f, 0.0, coast_decel * delta)
		if boost_time > 0.0:
			f = minf(f + boost_accel * delta, top)
		elif f > top:
			f = move_toward(f, top, (offroad_drag if not on_road else 10.0) * delta)

	# --- Derrape ---
	if drift_pressed and grounded and absf(f) > 4.0:
		velocity.y = hop_velocity
		grounded = false
	if not drifting and drift_held and grounded and absf(steer_value) > 0.35 and f > drift_min_speed:
		_start_drift(1 if steer_value > 0.0 else -1)
	if drifting:
		if not drift_held:
			_release_drift()
		elif f < drift_min_speed * 0.6:
			_cancel_drift()
		elif grounded:
			var into := clampf(steer_value * drift_dir, 0.0, 1.0)
			drift_charge += delta * (0.75 + 0.55 * into)
			var lvl := 0
			for i in mini_turbo_levels.size():
				if drift_charge >= mini_turbo_levels[i]:
					lvl = i + 1
			if lvl != drift_level:
				drift_level = lvl
				drift_level_changed.emit(drift_level)

	var new_planar: Vector3
	if drifting and grounded:
		# --- Derrape arcade: se conserva la velocidad y la trayectoria sigue al morro
		# con un ángulo de deslizamiento fijo (el morro apunta hacia dentro de la curva).
		var spd := planar.length()
		if throttle > 0.0:
			var ratio := spd / top
			spd = minf(spd + acceleration * throttle * (1.0 - 0.72 * ratio * ratio) * delta, maxf(top, spd))
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
		# --- Agarre lateral ---
		var g := drift_grip if drifting else grip
		if not grounded:
			g *= 0.15
		elif not on_road:
			g *= 0.7
		l *= exp(-g * delta)
		new_planar = fwd * f + right * l
		# Conservamos parte de la velocidad que el agarre "come" en curva (sensación arcade).
		var target_len := lerpf(new_planar.length(), maxf(absf(f), speed_before), 0.75)
		if new_planar.length() > 0.01 and grounded and throttle > 0.0:
			new_planar = new_planar.normalized() * minf(target_len, maxf(top, absf(f)))
	forward_speed = f

	# --- Giro (solo por la entrada del jugador) ---
	var yaw_rate := 0.0
	if drifting:
		var s := steer_value * drift_dir   # +1 cerrar, -1 abrir
		yaw_rate = -drift_dir * turn_speed * (drift_turn_base + drift_turn_range * s)
	else:
		var speed_ratio := clampf(absf(f) / max_speed, 0.0, 1.0)
		var authority := clampf(absf(f) / 5.0, 0.0, 1.0) * lerpf(1.0, high_speed_steer, speed_ratio)
		yaw_rate = -steer_value * turn_speed * authority * signf(f)
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
	var pre_move := velocity
	move_and_slide()
	_handle_collisions(pre_move)

	# --- Temporizadores ---
	boost_time = maxf(boost_time - delta, 0.0)
	turbo_meter = minf(turbo_meter + delta / turbo_recharge, 1.0)
	_pad_cooldown = maxf(_pad_cooldown - delta, 0.0)
	if track != null and _pad_cooldown <= 0.0 and track.is_on_boost_pad(global_position):
		apply_boost(1.0, "pad")
		_pad_cooldown = 0.6
	_airborne_time = 0.0 if is_on_floor() else _airborne_time + delta
	if global_position.y < -6.0:
		respawn()


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
		# Pierde velocidad según lo frontal del choque y rebota un poco.
		velocity.x *= 1.0 - 0.5 * last_impact
		velocity.z *= 1.0 - 0.5 * last_impact
		velocity += wall_normal * last_impact * 3.5
		if drifting and last_impact > 0.35:
			_cancel_drift()
		wall_hit.emit(last_impact * spd)


# --- Derrape y turbo --------------------------------------------------------------

func _start_drift(dir: int) -> void:
	drifting = true
	drift_dir = dir
	drift_charge = 0.0
	drift_level = 0


func _release_drift() -> void:
	if drift_level > 0:
		apply_boost(mini_turbo_time[drift_level - 1], "mini%d" % drift_level)
		turbo_meter = minf(turbo_meter + 0.08 * drift_level, 1.0)
	_cancel_drift()


func _cancel_drift() -> void:
	drifting = false
	drift_dir = 0
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
	if track != null:
		global_transform = track.respawn_transform(global_position)
	else:
		global_position.y = 1.0


func place(t: Transform3D) -> void:
	global_transform = t
	velocity = Vector3.ZERO
	steer_value = 0.0
	_cancel_drift()
	boost_time = 0.0
	turbo_meter = 1.0


func get_speed_kmh() -> float:
	return Vector3(velocity.x, 0, velocity.z).length() * 3.6


# --- Efectos visuales -------------------------------------------------------------

func _process(delta: float) -> void:
	if model == null:
		return
	var planar := Vector3(velocity.x, 0, velocity.z)
	var fwd := -global_transform.basis.z
	var dist := planar.dot(fwd) * delta
	var spd := planar.length()
	var steer_angle := steer_value * 0.42
	var drift_yaw := 0.0
	var roll := -steer_value * clampf(spd / max_speed, 0.0, 1.0) * 0.07
	if drifting:
		drift_yaw = -drift_dir * 0.32
		steer_angle = -drift_dir * 0.25 + steer_value * 0.15  # contravolante
		roll = drift_dir * 0.09
	var pitch := 0.0
	if boost_time > 0.0:
		pitch = 0.05
	elif Input.is_action_pressed("brake") and spd > 3.0 and controls_enabled:
		pitch = -0.04
	model.animate(dist, steer_angle, roll, pitch, -steer_value * 0.35, drift_yaw, delta)

	var spark_col := Color(1, 1, 1, 0.8)
	match drift_level:
		1: spark_col = Color("3fa9ff")
		2: spark_col = Color("ff8c1a")
		3: spark_col = Color("c75cff")
	for p in _sparks:
		p.emitting = drifting and is_on_floor()
		p.color = spark_col
	for p in _flames:
		p.emitting = boost_time > 0.0
	_dust.emitting = (not on_road) and is_on_floor() and spd > 4.0
	# Humo de neumáticos: derrapando, frenando fuerte o patinando de lado
	var slip := absf(planar.dot(global_transform.basis.x))
	var hard_brake := controls_enabled and Input.is_action_pressed("brake") and forward_speed > 8.0
	var smoking := is_on_floor() and on_road and (drifting or hard_brake or slip > 4.5)
	for p in _smoke:
		p.emitting = smoking


func _particle_mesh(size: float) -> BoxMesh:
	# Partículas low-poly: cubitos sin sombreado, coloreados por el sistema de partículas
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	m.material = PARTICLE_MATERIAL
	return m


func _build_effects() -> void:
	for p in model.rear_wheel_points:
		var s := CPUParticles3D.new()
		s.mesh = _particle_mesh(0.09)
		s.amount = 24
		s.lifetime = 0.35
		s.emitting = false
		s.direction = Vector3(0, 1, 1)
		s.spread = 35.0
		s.initial_velocity_min = 2.5
		s.initial_velocity_max = 5.0
		s.gravity = Vector3(0, -12, 0)
		s.scale_amount_min = 0.6
		s.scale_amount_max = 1.3
		s.position = p
		s.local_coords = false
		model.add_child(s)
		_sparks.append(s)
	for p in model.exhaust_points:
		var fl := CPUParticles3D.new()
		fl.mesh = _particle_mesh(0.16)
		fl.amount = 20
		fl.lifetime = 0.22
		fl.emitting = false
		fl.direction = Vector3(0, 0.2, 1)
		fl.spread = 12.0
		fl.initial_velocity_min = 4.0
		fl.initial_velocity_max = 6.0
		fl.gravity = Vector3.ZERO
		fl.scale_amount_min = 0.5
		fl.scale_amount_max = 1.2
		var ramp := Gradient.new()
		ramp.set_color(0, Color("fff3a0"))
		ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
		fl.color_ramp = ramp
		fl.position = p
		fl.local_coords = false
		model.body_pivot.add_child(fl)
		_flames.append(fl)
	for p in model.rear_wheel_points:
		var sm := CPUParticles3D.new()
		sm.mesh = _particle_mesh(0.35)
		sm.amount = 26
		sm.lifetime = 0.9
		sm.emitting = false
		sm.direction = Vector3(0, 1, 0.6)
		sm.spread = 30.0
		sm.initial_velocity_min = 0.6
		sm.initial_velocity_max = 1.6
		sm.gravity = Vector3(0, 1.2, 0)
		sm.scale_amount_min = 0.7
		sm.scale_amount_max = 1.6
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.5))
		curve.add_point(Vector2(1, 1.6))
		sm.scale_amount_curve = curve
		var g := Gradient.new()
		g.set_color(0, Color(0.95, 0.95, 0.95, 0.75))
		g.set_color(1, Color(0.8, 0.8, 0.82, 0.0))
		sm.color_ramp = g
		sm.position = p + Vector3(0, 0.1, 0.1)
		sm.local_coords = false
		model.add_child(sm)
		_smoke.append(sm)
	_dust = CPUParticles3D.new()
	_dust.mesh = _particle_mesh(0.22)
	_dust.amount = 18
	_dust.lifetime = 0.6
	_dust.emitting = false
	_dust.direction = Vector3(0, 1, 1)
	_dust.spread = 40.0
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 2.5
	_dust.gravity = Vector3(0, -2, 0)
	_dust.color = Color(0.62, 0.5, 0.36, 0.7)
	_dust.position = Vector3(0, 0.1, 1.0)
	_dust.local_coords = false
	model.add_child(_dust)
