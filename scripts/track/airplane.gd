extends Node3D
## Avión que aterriza sobrevolando el barrio (El Prat está junto al aeropuerto).
## Recorre una línea recta descendente en bucle.

const MB := preload("res://scripts/core/mesh_builder.gd")
const Props := preload("res://scripts/track/props.gd")

@export var from := Vector3(520, 150, -520)
@export var to := Vector3(-420, 35, 420)
@export var duration := 30.0
@export var phase := 0.0

var _t := 0.0


func _ready() -> void:
	var mb := MB.new()
	Props.airliner(mb)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_t = phase
	_update()


func _process(delta: float) -> void:
	_t = fmod(_t + delta / duration, 1.0)
	_update()


func _update() -> void:
	global_position = from.lerp(to, _t)
	var dir := (to - from).normalized()
	global_transform.basis = Basis.looking_at(dir, Vector3.UP)
