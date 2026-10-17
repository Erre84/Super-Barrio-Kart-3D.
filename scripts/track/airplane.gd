extends Node3D
## Avión del aeropuerto de El Prat (v0.2). Sigue una maniobra en bucle alineada
## con la pista del circuito:
##  - "landing": aproximación descendente desde el este, toma de contacto,
##    frenada por la pista y salida.
##  - "takeoff": carrera de despegue hacia el oeste, rotación y ascenso.
## Faros de aterrizaje y luces de navegación (roja/verde) y estroboscópica.

const MB := preload("res://scripts/core/mesh_builder.gd")
const Props := preload("res://scripts/track/props.gd")

@export var mode := "landing"
@export var runway_center := Vector3(120, 0, 250)
@export var runway_length := 900.0
@export var duration := 34.0
@export var phase := 0.0

var _t := 0.0
var _strobe: Node3D


func _ready() -> void:
	var mb := MB.new()
	Props.airliner(mb)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	add_child(mi)
	var glow := MB.new()
	glow.box(Vector3(0, -1.2, -12.0), Vector3(1.6, 0.5, 0.4), Color("fff7dc"))       # faro de aterrizaje
	glow.box(Vector3(-17.0, -0.6, -1.0), Vector3(0.6, 0.5, 0.6), Color("ff2b2b"))    # navegación izquierda
	glow.box(Vector3(17.0, -0.6, -1.0), Vector3(0.6, 0.5, 0.6), Color("2bff6b"))     # navegación derecha
	var gmi := MeshInstance3D.new()
	gmi.mesh = glow.commit(MB.glow_material())
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmi)
	var sm := MB.new()
	sm.box(Vector3(0, 7.8, 18.0), Vector3(0.6, 0.6, 0.6), Color.WHITE)
	_strobe = MeshInstance3D.new()
	(_strobe as MeshInstance3D).mesh = sm.commit(MB.glow_material())
	add_child(_strobe)
	_t = phase
	_update()


func _process(delta: float) -> void:
	_t = fmod(_t + delta / duration, 1.0)
	_strobe.visible = fmod(_t * duration, 1.2) < 0.08
	_update()


## Devuelve posición en la maniobra para t ∈ [0, 1].
func _path(t: float) -> Vector3:
	var half := runway_length * 0.5
	var y0 := 3.4  # altura del fuselaje sobre el suelo con el tren fuera
	if mode == "landing":
		# 0.00-0.70 aproximación (3°) · 0.70-1.00 rodadura frenando
		var touch_x := runway_center.x + half - 160.0
		var start_x := touch_x + 2600.0
		if t < 0.7:
			var k := t / 0.7
			var x := lerpf(start_x, touch_x, k)
			var h := (x - touch_x) * tan(deg_to_rad(3.2)) * (1.0 - 0.15 * k) + y0
			return Vector3(x, h, runway_center.z)
		var k2 := (t - 0.7) / 0.3
		var roll := 1.0 - pow(1.0 - k2, 2.0)
		return Vector3(touch_x - roll * (runway_length - 200.0), y0, runway_center.z)
	# despegue hacia el oeste
	var start := runway_center.x + half - 40.0
	var lift_x := runway_center.x - half * 0.3
	if t < 0.35:
		var k3 := t / 0.35
		return Vector3(lerpf(start, lift_x, k3 * k3), y0, runway_center.z)
	var k4 := (t - 0.35) / 0.65
	var x2 := lift_x - k4 * 2600.0
	return Vector3(x2, y0 + pow(k4, 1.3) * 380.0, runway_center.z)


func _update() -> void:
	var p := _path(_t)
	var ahead := _path(minf(_t + 0.004, 0.999))
	global_position = p
	var dir := ahead - p
	if dir.length() > 0.05:
		global_transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
