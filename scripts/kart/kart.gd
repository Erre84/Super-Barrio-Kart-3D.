extends CharacterBody3D
## Kart del jugador: conducción arcade con DERRAPE NATURAL (v0.3).
##
## No hay botón de derrape. El kart derrapa cuando los neumáticos no pueden dar la
## fuerza lateral que pide el giro:
##
##  1. El volante marca una velocidad de giro objetivo. La carrocería la sigue con
##     inercia (`yaw_response`), más lenta cuando desliza (`yaw_response_slide`).
##  2. Al girar, la velocidad conserva su dirección (inercia) y aparece velocidad
##     LATERAL en coordenadas locales del kart. Los neumáticos la anulan, pero con
##     un límite: `grip_peak` (m/s²). Si el giro pide más (velocidad × giro alto: un
##     volantazo en recta a fondo, una curva cerrada a demasiada velocidad, frenar
##     girando...), la deriva lateral crece de forma progresiva.
##  3. El agarre depende del ángulo de deriva: máximo hasta `slip_peak_deg` y baja
##     al agarre dinámico `grip_slide` a partir de `slip_full_deg`. Una vez cruzado,
##     el kart conserva inercia lateral y tiende a cruzarse más (`oversteer`).
##  4. Para recuperar, hay que CONTRAVOLANTEAR (o abrir dirección y dar gas): el
##     morro vuelve hacia la trayectoria, la deriva baja y el agarre vuelve.
##
## Mini-turbo por maniobra (sin botón):
##  - Derrape válido: deriva > `drift_enter_deg` durante al menos `drift_min_time`,
##    sin trompo (> `drift_spin_deg`), sin choque fuerte y sin quedarse lento.
##  - Enderezar: deriva < `drift_recover_deg` durante `drift_recover_hold` s.
##  - Después hay una ventana de `boost_window` s para SOLTAR el acelerador y
##    VOLVER A PISARLO. Si sale bien, mini-turbo (más largo cuanto más duró el
##    derrape). Si no, nada. Pisar repetidamente sin derrape válido no da nada:
##    cada derrape válido abre UNA ventana con UN intento.
##
## Nada gira, endereza ni frena el kart por el jugador. Todo es @export.

signal wall_hit(strength: float)
signal boost_started(kind: String)
signal drift_level_changed(level: int)
signal landed(impact: float)
## "slide" (empieza), "window" (enderezado: suelta y pisa), "success",
## y fallos: "fail_short", "fail_spin", "fail_wall", "fail_slow", "fail_late", "fail_lift", "fail_new_slide"
signal drift_event(kind: String, level: int)

const KartModel := preload("res://scripts/kart/kart_model.gd")
const KartEffects := preload("res://scripts/kart/kart_effects.gd")
const KartAudio := preload("res://scripts/kart/kart_audio.gd")

enum DriftState { NONE, SLIDING, WINDOW }

@export_group("Motor")
@export var max_speed := 29.0          ## m/s (≈105 km/h)
@export var acceleration := 17.0       ## m/s² arrancando; se reduce cerca de la punta
@export var accel_falloff := 0.72      ## cuánto cae la aceleración al acercarse a la punta (0-1)
@export var brake_decel := 34.0        ## m/s² frenando
@export var reverse_accel := 12.0      ## m/s² en marcha atrás
@export var reverse_max := 9.0         ## m/s máximos marcha atrás
@export var coast_decel := 4.0         ## m/s² sin acelerar ni frenar (rozamiento, NO freno automático)

@export_group("Dirección")
@export var turn_speed := 2.15         ## rad/s de giro con el volante a fondo
@export var full_steer_speed := 5.0    ## m/s a partir de los que el giro es completo
@export var high_speed_steer := 0.62   ## fracción de giro a velocidad punta
@export var steer_press_rate := 8.5    ## volante digital: rapidez al girar (1/s)
@export var steer_release_rate := 14.0 ## rapidez al soltar (vuelve al centro)
@export var steer_reverse_rate := 18.0 ## rapidez al cambiar de lado (contravolante)
@export var yaw_response := 16.0       ## rapidez con la que el giro sigue al volante con agarre (1/s)
@export var yaw_response_slide := 4.5  ## ... mientras desliza (la carrocería tiene inercia)

@export_group("Adherencia")
@export var grip_peak := 13.0          ## aceleración lateral máxima con agarre (m/s²)
@export var grip_slide := 11.5         ## agarre dinámico al deslizar (m/s²): inercia lateral
@export var slip_peak_deg := 4.0       ## deriva hasta la que el agarre es máximo
@export var slip_full_deg := 14.0      ## deriva a partir de la que el agarre es el dinámico
@export var slide_min_speed := 15.0   ## por debajo de esta velocidad (m/s, ≈54 km/h) no se pierde adherencia
@export var slide_full_speed := 18.0  ## desde esta velocidad (m/s, ≈65 km/h) derrapa igual de fácil que a tope
@export var slide_low_speed_grip := 20.0 ## agarre extra (m/s²) justo por encima de slide_min_speed; se desvanece hasta slide_full_speed
@export var slide_steer := 0.45        ## autoridad del volante mientras desliza (contravolante incluido)
@export var oversteer := 2.5           ## tendencia a cruzarse mientras desliza (rad/s²)
@export var drift_angle_target := 30.0 ## deriva de equilibrio con el volante a fondo (°): por encima, se frena el cruce
@export var flick_grip_loss := 0.75    ## agarre perdido como máximo por un volantazo (transferencia de peso)
@export var flick_sensitivity := 0.25 ## cuánto agarre quita cada rad/s² de aceleración de giro
@export var brake_grip_loss := 0.35    ## agarre perdido frenando a fondo (0-1): frenar girando cruza el kart
@export var slide_drag := 2.5          ## m/s² de velocidad perdida a deriva completa
@export var offroad_grip := 0.7        ## multiplicador de agarre en tierra
@export var air_grip := 0.1            ## multiplicador de agarre en el aire

@export_group("Mini-turbo por derrape")
@export var drift_enter_deg := 6.0    ## deriva que cuenta como derrape
@export var drift_recover_deg := 5.0   ## deriva por debajo de la cual el kart está enderezado
@export var drift_recover_hold := 0.08 ## s que hay que mantenerlo enderezado
@export var drift_spin_deg := 85.0     ## deriva que se considera trompo (derrape inválido)
@export var drift_min_time := 0.15     ## s mínimos de derrape para que sea válido
@export var drift_level_times: Array[float] = [0.15, 0.6, 1.2]  ## s de derrape por nivel
@export var mini_turbo_time: Array[float] = [1.0, 1.3, 1.6]    ## s de impulso por nivel
@export var mini_turbo_kick: Array[float] = [1.0, 1.4, 1.8]    ## m/s de empujón instantáneo por nivel (pequeño: empuje, no tirón)
@export var mini_turbo_speed: Array[float] = [1.12, 1.17, 1.22]  ## punta durante el mini-turbo por nivel (× max_speed)
@export var mini_turbo_accel := 11.0   ## m/s² de empuje constante durante el mini-turbo
@export var boost_fade := 5.0          ## m/s² con los que se vuelve a la punta normal al acabar un impulso
@export var boost_fire_deg := 16.0     ## al pisar, sale el impulso si la deriva ya es menor que esto
@export var boost_window := 1.2        ## s tras enderezar para soltar y volver a pisar (si no lo hiciste ya)
@export var lift_min := 0.04           ## s mínimos con el acelerador suelto

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
var audio: KartAudio
var track: Node = null
var controls_enabled := false
## Entrada inyectable (pruebas): si no está vacía sustituye a Input.
var input_override := {}

# --- Estado público (cámara, HUD, efectos, audio y pruebas) ---
var steer_value := 0.0
var forward_speed := 0.0
var lateral_speed := 0.0      ## m/s de velocidad lateral local (+ hacia la derecha del kart)
var yaw_rate := 0.0           ## rad/s (+ = izquierda)
var slip_angle := 0.0         ## rad, con signo: + = el morro apunta a la izquierda de la trayectoria
var slide_amount := 0.0       ## 0 = agarre total, 1 = deslizando del todo
var throttle_input := 0.0
var braking_input := 0.0
var drift_state := DriftState.NONE
var drift_time := 0.0
var drift_level := 0
var drift_peak_deg := 0.0
var window_left := 0.0
var boost_time := 0.0
var turbo_meter := 1.0
var on_road := true
var track_info := {}
var last_impact := 0.0
var airborne_time := 0.0
var mini_turbos := 0          ## contador (estadísticas y pruebas)

# Compatibilidad con el modelo/efectos: "drifting" = derrape en curso
var drifting: bool:
	get: return drift_state == DriftState.SLIDING
var drift_dir: int:
	get: return 0 if absf(slip_angle) < 0.01 else (-1 if slip_angle > 0.0 else 1)
var drift_slip: float:
	get: return absf(slip_angle)

var _boost_mult := 1.0
var _boost_accel := 34.0
var _pad_cooldown := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _time := 0.0
var _recover_t := 0.0
var _lifted := false
var _lift_start := -10.0
var _press_t := -10.0
## true = turbo cargado: has soltado el gas durante el derrape; al volver a pisar saldrá.
var boost_armed := false
var _window_open_t := 0.0
var _spun := false
var _flick := 0.0


func _ready() -> void:
	# Capa 2 = karts. Choca con el escenario (capa 1) pero no con los conos (capa 3).
	collision_layer = 2
	collision_mask = 1
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
	audio = KartAudio.new()
	audio.name = "Audio"
	add_child(audio)
	audio.setup(self)
	landed.connect(func(impact: float): model.bump(impact))
	wall_hit.connect(func(strength: float): model.bump(clampf(strength / 30.0, 0.0, 0.6)))


# --- Entrada --------------------------------------------------------------------

func _in_strength(action: String) -> float:
	if not input_override.is_empty():
		return float(input_override.get(action, 0.0))
	return Input.get_action_strength(action)


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


## 0 por debajo de slide_min_speed, 1 desde slide_full_speed: cuánto puede derrapar a esta velocidad.
func _slide_speed_factor(speed: float) -> float:
	return smoothstep(slide_min_speed, maxf(slide_full_speed, slide_min_speed + 0.1), speed)


## Agarre lateral disponible (m/s²) según el ángulo de deriva.
func grip_at(slip_deg: float) -> float:
	var t := smoothstep(slip_peak_deg, slip_full_deg, slip_deg)
	return lerpf(grip_peak, grip_slide, t)


# --- Bucle principal ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	var throttle := 0.0
	var braking := 0.0
	var steer_in := 0.0
	if controls_enabled:
		throttle = _in_strength("accelerate")
		braking = _in_strength("brake")
		steer_in = _in_strength("steer_right") - _in_strength("steer_left")
		if input_override.is_empty():
			if Input.is_action_just_pressed("turbo"):
				try_turbo()
			if Input.is_action_just_pressed("reset"):
				respawn()
				return
	throttle_input = throttle
	braking_input = braking
	_update_steering(clampf(steer_in, -1.0, 1.0), delta)

	var grounded := is_on_floor()
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var speed := planar.length()

	# Superficie
	if track != null:
		track_info = track.query(global_position)
		on_road = track_info.get("on_road", true)
	var top := max_speed
	if boost_time > 0.0:
		top *= _boost_mult
	elif not on_road:
		top *= offroad_speed_mult

	# --- 1. Giro: la carrocería sigue al volante con inercia ---
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var f := planar.dot(fwd)
	var speed_ratio := clampf(absf(f) / max_speed, 0.0, 1.0)
	var authority := clampf(absf(f) / full_steer_speed, 0.0, 1.0) * lerpf(1.0, high_speed_steer, speed_ratio)
	var dir_sign := 1.0 if f >= -0.5 else -1.0
	var slip_deg := rad_to_deg(absf(slip_angle))
	# La autoridad del volante baja solo con el derrape ya formado: la entrada es viva
	var slide_scale := lerpf(1.0, slide_steer, smoothstep(slip_full_deg * 0.6, slip_full_deg * 1.6, slip_deg))
	var yaw_target := -steer_value * turn_speed * authority * dir_sign * slide_scale
	var resp := lerpf(yaw_response, yaw_response_slide, slide_amount)
	if not grounded:
		resp *= 0.4
	var prev_yaw_rate := yaw_rate
	yaw_rate = lerpf(yaw_rate, yaw_target, 1.0 - exp(-resp * delta))
	# Volantazo: un cambio brusco de giro carga el peso de golpe y las ruedas pierden agarre
	# Solo cuenta mientras el giro AUMENTA (carga los neumáticos), no al deshacerlo, y
	# crece con el cuadrado de la velocidad: a media velocidad las eses no traicionan.
	var loading := absf(yaw_rate) > absf(prev_yaw_rate)
	_flick = 0.0
	if loading:
		_flick = clampf(absf(yaw_rate - prev_yaw_rate) / delta * flick_sensitivity, 0.0, flick_grip_loss) * _slide_speed_factor(speed)
	# Sobreviraje: deslizando, el kart tiende a cruzarse más (hay que contravolantear)
	if grounded and slide_amount > 0.0 and speed > slide_min_speed:
		var push := clampf(1.0 - slip_deg / maxf(drift_angle_target, 1.0), -1.0, 1.0)
		yaw_rate += signf(slip_angle) * oversteer * slide_amount * push * delta
	rotate_y(yaw_rate * delta)

	# --- 2. Velocidad en ejes locales tras girar: aquí nace la deriva lateral ---
	fwd = -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	f = planar.dot(fwd)
	var l := planar.dot(right)

	# --- 3. Motor y frenos (con ruedas en el suelo). Sin freno automático. ---
	if grounded:
		if throttle > 0.0 and braking < 0.5:
			if f < -0.5:
				f = minf(f + brake_decel * delta, 0.0)
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
			f = minf(f + _boost_accel * delta, top)
		elif f > top:
			f = move_toward(f, top, (offroad_drag if not on_road else boost_fade) * delta)

	# --- 4. Neumáticos: anulan la velocidad lateral hasta su límite de agarre ---
	slip_deg = rad_to_deg(atan2(absf(l), maxf(absf(f), 1.0)))
	var grip := grip_at(slip_deg)
	# La velocidad mínima decide si se puede EMPEZAR a derrapar; un derrape ya formado sigue
	# hasta que el kart va de verdad despacio (y frenar a fondo puede acabar en trompo).
	var sliding_now := slide_amount > 0.05
	var min_v := slide_min_speed * (0.6 if sliding_now else 1.0)
	if speed < min_v:
		grip = 1000.0                       # a baja velocidad el kart siempre agarra
	elif not sliding_now:
		grip += (1.0 - _slide_speed_factor(speed)) * slide_low_speed_grip  # transición suave
	grip *= 1.0 - brake_grip_loss * braking * clampf(speed / max_speed, 0.0, 1.0)
	grip *= 1.0 - _flick
	if not on_road:
		grip *= offroad_grip
	if not grounded:
		grip *= air_grip
	var need := absf(l) / delta
	if need <= grip:
		l = 0.0
	else:
		l -= signf(l) * grip * delta
	# Deriva resultante y cuánto desliza (para física, efectos y sonido)
	slip_deg = rad_to_deg(atan2(absf(l), maxf(absf(f), 1.0)))
	slide_amount = smoothstep(slip_peak_deg * 0.5, slip_full_deg, slip_deg) if l != 0.0 else 0.0
	# Deslizar cuesta velocidad
	if slide_amount > 0.0 and grounded:
		f = move_toward(f, 0.0, slide_drag * slide_amount * delta) if f > 0.0 else f
	var new_planar := fwd * f + right * l
	if boost_time <= 0.0 and new_planar.length() > top * 1.02 and on_road:
		new_planar = new_planar.normalized() * move_toward(new_planar.length(), top, boost_fade * delta)
	forward_speed = new_planar.dot(fwd)
	lateral_speed = new_planar.dot(right)
	slip_angle = 0.0 if new_planar.length() < 0.5 else -fwd.signed_angle_to(new_planar.normalized(), Vector3.UP)
	if forward_speed < -0.5:
		slip_angle = 0.0   # marcha atrás: sin derrapes

	# --- 5. Gravedad y movimiento ---
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
	_knock_cones(pre_move)

	var on_floor_now := is_on_floor()
	if on_floor_now and not _was_on_floor:
		landed.emit(clampf(-_fall_speed / 6.0, 0.0, 1.0))
		_fall_speed = 0.0
	if on_floor_now:
		_fall_speed = 0.0
	_was_on_floor = on_floor_now

	# --- 6. Derrape y mini-turbo ---
	_update_drift(delta, throttle, on_floor_now)

	# --- Temporizadores ---
	boost_time = maxf(boost_time - delta, 0.0)
	turbo_meter = minf(turbo_meter + delta / turbo_recharge, 1.0)
	_pad_cooldown = maxf(_pad_cooldown - delta, 0.0)
	if track != null and _pad_cooldown <= 0.0 and track.is_on_boost_pad(global_position):
		apply_boost(1.0, "pad", boost_speed_mult)
		_pad_cooldown = 0.6
	airborne_time = 0.0 if on_floor_now else airborne_time + delta
	if global_position.y < -6.0:
		respawn()


# --- Máquina de estados del derrape ---------------------------------------------

func _update_drift(delta: float, throttle: float, grounded: bool) -> void:
	var deg := rad_to_deg(absf(slip_angle))
	var speed := Vector2(velocity.x, velocity.z).length()

	# Seguimiento del acelerador (soltar = por debajo del 20 %, pisar = más del 50 %)
	if throttle < 0.2 and not _lifted:
		_lifted = true
		_lift_start = _time
	elif throttle > 0.5 and _lifted:
		_lifted = false
		_press_t = _time

	if _spun and deg < drift_recover_deg:
		_spun = false

	# Turbo cargado: has soltado el gas en algún momento del derrape (o de la ventana).
	# Al volver a pisar mientras el kart ya está saliendo del derrape, sale el impulso.
	var valid := drift_level > 0 and drift_time >= drift_min_time
	if drift_state != DriftState.NONE and _lifted and _time - _lift_start >= lift_min:
		boost_armed = true
	if boost_armed and valid and throttle > 0.5 and deg < boost_fire_deg:
		_mini_turbo()
		return

	match drift_state:
		DriftState.NONE, DriftState.WINDOW:
			if grounded and not _spun and speed > slide_min_speed and deg > drift_enter_deg:
				if drift_state == DriftState.WINDOW:
					_drift_fail("fail_new_slide")
				_start_drift()
			elif drift_state == DriftState.WINDOW:
				window_left -= delta
				if window_left <= 0.0:
					_drift_fail("fail_late" if boost_armed else "fail_lift")
		DriftState.SLIDING:
			if deg > drift_recover_deg:
				drift_time += delta
			drift_peak_deg = maxf(drift_peak_deg, deg)
			var lvl := 0
			for i in drift_level_times.size():
				if drift_time >= drift_level_times[i]:
					lvl = i + 1
			if lvl != drift_level:
				drift_level = lvl
				drift_level_changed.emit(drift_level)
			if deg > drift_spin_deg:
				_spun = true
				_drift_fail("fail_spin")
			elif speed < slide_min_speed * 0.7:
				_drift_fail("fail_slow")
			elif deg < drift_recover_deg:
				_recover_t += delta
				if _recover_t >= drift_recover_hold:
					_on_recovered()
			else:
				_recover_t = 0.0


func _start_drift() -> void:
	drift_state = DriftState.SLIDING
	drift_time = 0.0
	drift_peak_deg = 0.0
	_recover_t = 0.0
	drift_level = 0
	drift_event.emit("slide", 0)


func _on_recovered() -> void:
	if drift_time < drift_min_time or drift_level == 0:
		_drift_fail("fail_short")
		return
	drift_state = DriftState.WINDOW
	window_left = boost_window
	_window_open_t = _time
	drift_event.emit("window", drift_level)


func _mini_turbo() -> void:
	var lvl := clampi(drift_level, 1, mini_turbo_time.size())
	mini_turbos += 1
	var mult: float = mini_turbo_speed[lvl - 1]
	apply_boost(mini_turbo_time[lvl - 1], "mini%d" % lvl, mult)
	# Patada instantánea hacia delante: el impulso se nota aunque salgas lento del derrape
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var along := planar.dot(fwd)
	var lateral := planar - fwd * along
	var new_along := maxf(minf(along + float(mini_turbo_kick[lvl - 1]), max_speed * mult), along)
	var nv := fwd * new_along + lateral * 0.3
	velocity.x = nv.x
	velocity.z = nv.z
	turbo_meter = minf(turbo_meter + 0.06 * lvl, 1.0)
	drift_event.emit("success", lvl)
	_reset_drift()


func _drift_fail(kind: String) -> void:
	var lvl := drift_level
	_reset_drift()
	drift_event.emit(kind, lvl)


func _reset_drift() -> void:
	boost_armed = false
	drift_state = DriftState.NONE
	drift_time = 0.0
	window_left = 0.0
	_recover_t = 0.0
	if drift_level != 0:
		drift_level = 0
		drift_level_changed.emit(0)


# --- Conos (sin colisión física con el kart) ---------------------------------------

@export_group("Conos")
@export var cone_hit_radius := 1.2     ## distancia (m) a la que el kart golpea un cono
@export var cone_slowdown := 0.97      ## velocidad que se conserva al atropellar un cono

func _knock_cones(pre_move: Vector3) -> void:
	var planar := Vector3(pre_move.x, 0, pre_move.z)
	if planar.length() < 1.0:
		return
	var here := global_position
	for c in get_tree().get_nodes_in_group("knockable"):
		var rb := c as RigidBody3D
		if rb == null:
			continue
		var d := rb.global_position - here
		d.y = 0.0
		if d.length() > cone_hit_radius or rb.linear_velocity.length() > 3.0:
			continue
		rb.sleeping = false
		var away := d.normalized() if d.length() > 0.05 else planar.normalized()
		rb.apply_central_impulse((planar * 0.8 + away * 3.0) * rb.mass + Vector3.UP * rb.mass * 3.5)
		rb.apply_torque_impulse(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * rb.mass)
		velocity.x *= cone_slowdown
		velocity.z *= cone_slowdown
		model.bump(0.15)


# --- Choques ---------------------------------------------------------------------

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
			if rb.linear_velocity.length() < 4.0:
				rb.sleeping = false
				rb.apply_central_impulse(pre_planar * rb.mass * 0.45 + Vector3.UP * rb.mass * 3.0)
				rb.apply_torque_impulse(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * rb.mass)
			velocity.x = pre_planar.x * 0.93
			velocity.z = pre_planar.z * 0.93
			continue
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
		yaw_rate *= 0.5
		if drift_state == DriftState.SLIDING and last_impact > 0.35:
			_drift_fail("fail_wall")
		wall_hit.emit(last_impact * spd)


# --- Turbo ------------------------------------------------------------------------

func try_turbo() -> bool:
	if turbo_meter < 1.0:
		return false
	turbo_meter = 0.0
	apply_boost(turbo_time, "turbo", boost_speed_mult)
	return true


func apply_boost(seconds: float, kind: String, mult: float = -1.0) -> void:
	var m := boost_speed_mult if mult < 0.0 else mult
	var acc := mini_turbo_accel if kind.begins_with("mini") else boost_accel
	if boost_time <= 0.0 or m >= _boost_mult:
		_boost_mult = m
		_boost_accel = acc
	boost_time = maxf(boost_time, seconds)
	boost_started.emit(kind)


func respawn() -> void:
	velocity = Vector3.ZERO
	boost_time = 0.0
	yaw_rate = 0.0
	slip_angle = 0.0
	slide_amount = 0.0
	_reset_drift()
	if track != null:
		global_transform = track.respawn_transform(global_position)
	else:
		global_position.y = 1.0


func place(t: Transform3D) -> void:
	global_transform = t
	velocity = Vector3.ZERO
	steer_value = 0.0
	yaw_rate = 0.0
	slip_angle = 0.0
	slide_amount = 0.0
	_spun = false
	_lifted = false
	_reset_drift()
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
	var look_back := false
	if controls_enabled and input_override.is_empty():
		look_back = Input.is_action_pressed("look_back")
	var state := {
		"distance": planar.dot(fwd) * delta,
		"speed": planar.length(),
		"speed_ratio": clampf(planar.length() / max_speed, 0.0, 1.3),
		"steer": steer_value,
		"drifting": slide_amount > 0.25,
		"drift_dir": drift_dir,
		"drift_slip": drift_slip,
		"yaw_rate": yaw_rate,
		"boost": boost_time > 0.0,
		"braking": braking_input > 0.1 and forward_speed > 3.0,
		"grounded": is_on_floor(),
		"vertical_speed": velocity.y,
		"look_back": look_back,
	}
	model.update_visual(state, delta)
