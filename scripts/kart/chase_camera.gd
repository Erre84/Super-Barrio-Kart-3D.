extends Camera3D
## Cámara en tercera persona detrás del kart.
## - Sigue la orientación del kart con un pequeño retardo (no la de la velocidad),
##   así en los derrapes se ve el kart cruzado, como en los arcade clásicos.
## - "Mirar atrás" (Q / botón Y / botón táctil) gira la vista 180° al instante.
## - El FOV se abre con la velocidad y el turbo; vibra al chocar.

@export var distance := 5.4
@export var height := 2.25
@export var look_height := 1.05
@export var look_ahead := 3.0
@export var yaw_follow := 6.5
@export var base_fov := 70.0

var target: Node3D
var looking_back := false
var _yaw := 0.0
var _shake := 0.0
var _punch := 0.0
var _fov_base := 70.0
var _was_back := false
var _initialized := false


func _ready() -> void:
	top_level = true
	process_physics_priority = 100  # después del kart: sin tirones
	fov = base_fov
	near = 0.1
	far = 1400.0


func snap() -> void:
	_initialized = false


## Golpe de FOV (mini-turbo): la cámara "se estira" un instante.
func punch(degrees: float) -> void:
	_punch = maxf(_punch, degrees)


func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 0.6)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var kart_yaw: float = target.global_rotation.y
	looking_back = Input.is_action_pressed("look_back")
	if not _initialized:
		_yaw = kart_yaw
		_initialized = true
	_yaw = lerp_angle(_yaw, kart_yaw, 1.0 - exp(-yaw_follow * delta))
	var yaw := _yaw + (PI if looking_back else 0.0)
	var back := Vector3(sin(yaw), 0.0, cos(yaw))  # +Z local = detrás del kart
	var base: Vector3 = target.global_position
	var desired := base + back * distance + Vector3.UP * height
	if looking_back or looking_back != _was_back:
		# Cambio de vista instantáneo al pulsar y al soltar "mirar atrás"
		global_position = desired
	else:
		var follow := 1.0 - exp(-18.0 * delta)
		global_position = global_position.lerp(desired, follow) if _initialized else desired
		# Que nunca se quede demasiado lejos (turbo)
		var off := global_position - desired
		if off.length() > 2.5:
			global_position = desired + off.normalized() * 2.5
	_was_back = looking_back
	var look := base + Vector3.UP * look_height - back * look_ahead
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 1.8, 0.0)
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	look_at(look, Vector3.UP)

	var speed_ratio := 0.0
	var boosting := false
	if "velocity" in target:
		var v: Vector3 = target.velocity
		speed_ratio = clampf(Vector2(v.x, v.z).length() / 30.0, 0.0, 1.3)
	if "boost_time" in target:
		boosting = target.boost_time > 0.0
	var target_fov := base_fov + speed_ratio * 8.0 + (9.0 if boosting else 0.0)
	_punch = move_toward(_punch, 0.0, delta * 14.0)
	_fov_base = lerpf(_fov_base, target_fov, 1.0 - exp(-5.0 * delta))
	fov = _fov_base + _punch
