extends Node3D
## Modelo low-poly del kart + piloto chibi, construido por código. Es el ESQUELETO COMÚN
## de los corredores: cada corredor (scripts/racers/<id>.gd) hereda de aquí y redefine
## _setup_style() y los ganchos de construcción (_build_chassis, _build_torso, _build_hair,
## _build_head_extras, _wheel_mesh...), conservando la jerarquía y las animaciones.
## Sin redefinir nada, es el piloto provisional de la v0.2-v0.6.
## Delante es -Z (convención de Godot). El origen está a ras de suelo.
##
## Jerarquía animada:
##   Model
##   ├─ Body (suspensión: rebote, balanceo, cabeceo)
##   │   ├─ Chassis (carrocería, motor, alerón...)
##   │   ├─ SteeringWheel (gira con el volante)
##   │   └─ Driver (inclinación por la fuerza G, respiración)
##   │       ├─ DriverBody, brazos (siguen al volante), bufanda
##   │       └─ Head (mira a la curva / hacia atrás; ojos que parpadean; expresiones)
##   └─ 4 ruedas: SteerPivot (dirección) > Spin (rodadura) > malla

const MB := preload("res://scripts/core/mesh_builder.gd")

## Estilo del kart y del piloto. Cambiar estos colores crea variantes.
var style := {
	"body": Color("e63946"),
	"body_dark": Color("b0202c"),
	"accent": Color("ffd23f"),
	"stripe": Color("ffffff"),
	"trim": Color("23263a"),
	"seat": Color("2b2d42"),
	"metal": Color("9aa5b1"),
	"chrome": Color("dfe6ee"),
	"tire": Color("45454f"),
	"tire_tread": Color("2a2a31"),
	"rim": Color("ffd23f"),
	"rim_dish": Color("3a3d4a"),
	"suit": Color("2b6fe0"),
	"suit_dark": Color("1d4fa8"),
	"pants": Color("2f3e66"),
	"skin": Color("f6cfa6"),
	"hair": Color("4a2c1a"),
	"cap": Color("ffd23f"),
	"cap_brim": Color("e63946"),
	"scarf": Color("ff7b2e"),
	"glove": Color("fafafa"),
	"shoe": Color("f4f4f4"),
	"shoe_sole": Color("e63946"),
	"eye": Color("5a3a22"),
	"number": "7",
	# --- Piloto (ganchos comunes) ---
	"sleeve": null,        # color de las mangas (null = "suit")
	"forearm": null,       # antebrazo (null = manga larga; piel = manga corta)
	"arm_scale": 1.0,      # grosor de los brazos (complexión)
	"head_scale": 1.0,     # tamaño de la cabeza
	"cuff": null,          # puño de la manga junto a la mano (null = "suit_dark")
	"scarf_tail": true,    # bufanda que ondea
	"eye_size": 1.0,       # escala de los ojos
	"eye_lid": 0.0,        # 0 = ojos abiertos; 0.3-0.5 = párpado caído (mirada seria)
	"brow_tilt": 8.0,      # grados; negativo = ceño (extremo interior abajo)
	"brow_size": Vector3(0.12, 0.028, 0.03),
	"brow_y": 0.115,
	"mouth": "smile",      # smile | flat | smirk | shout
	"mouth_excited": "grin",
	"beard": null,         # color de barba (null = sin barba)
	"beard_style": "full", # full | stubble | goatee
	"earring": null,       # color de pendientes (null = sin)
	"blush": true,         # coloretes (estilo cartoon); false = cara más realista
	"eye_shine": true,     # brillos grandes en los ojos
	# --- Ruedas ---
	"rim_style": "spokes", # spokes | dish
	"tire_band": true,     # franja de color en el flanco
	"hub": null,           # color del tapacubos (null = "body")
}

# Nodos animados
var body_pivot: Node3D
var driver_pivot: Node3D
var head_pivot: Node3D
var steering_wheel: Node3D
var steer_pivots: Array[Node3D] = []
var wheel_spin: Array[Node3D] = []
var wheel_radius: Array[float] = []
var _eyes: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _mouth_smile: Node3D
var _mouth_grin: Node3D
var _scarf_tail: Array[Node3D] = []
var _arm_parts := {}      # "l_upper", "l_fore", "l_hand", ...

# Puntos de referencia para efectos (en coordenadas del modelo)
var exhaust_points: Array[Vector3] = [Vector3(-0.42, 0.5, 1.5), Vector3(0.42, 0.5, 1.5)]
var rear_wheel_points: Array[Vector3] = [Vector3(-0.8, 0.02, 0.85), Vector3(0.8, 0.02, 0.85)]

# Ruedas: posición (x = semivía) y tamaño (radio, anchura)
var front_wheel := Vector3(0.76, 0.28, -0.88)
var front_size := Vector2(0.28, 0.26)
var rear_wheel := Vector3(0.8, 0.35, 0.85)
var rear_size := Vector2(0.35, 0.36)

const HEAD_CENTER := Vector3(0, 0.36, 0)
var _brow_base_y := 0.475

# Geometría del volante (en coordenadas del Body)
var WHEEL_CENTER := Vector3(0, 0.88, -0.38)
const WHEEL_TILT := -58.0
const WHEEL_R := 0.19
var DRIVER_ORIGIN := Vector3(0, 0.52, 0.28)


## Sube o baja al piloto y el volante juntos (karts con el asiento más alto).
func _raise_driver(dy: float) -> void:
	WHEEL_CENTER.y += dy
	DRIVER_ORIGIN.y += dy

# Estado de animación
var _t := 0.0
var _susp_y := 0.0
var _susp_v := 0.0
var _roll := 0.0
var _pitch := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _wheel_angle := 0.0


## Gancho: cada corredor ajusta aquí `style` y las medidas (ruedas, escapes...).
func _setup_style() -> void:
	pass


func build(custom_style: Dictionary = {}) -> void:
	_setup_style()
	for k in custom_style:
		style[k] = custom_style[k]
	body_pivot = Node3D.new()
	body_pivot.name = "Body"
	add_child(body_pivot)
	_build_chassis()
	_build_steering_wheel()
	_build_driver()
	_build_wheels()
	_optimize()


# =============================================================================
# Optimización para móvil
# =============================================================================

## Piezas que proyectan sombra (el resto son detalles pequeños: no merece la pena
## pagar otra llamada de dibujo por pieza en la pasada de sombras).
const SHADOW_PARTS := ["Static", "DriverBody", "HeadMesh", "WheelMesh"]
## Detalles que dejan de dibujarse a distancia (no se distinguen a más de 45 m).
const NEAR_ONLY := ["EyeMesh", "Brow", "MouthMesh", "Caliper"]


## Une todas las piezas fijas de la carrocería en una malla (una superficie por material)
## y ajusta sombras y distancia de dibujado.
func _optimize() -> void:
	var items := []
	var to_free: Array[Node] = []
	for c in body_pivot.get_children():
		if c is MeshInstance3D and c.mesh != null:
			items.append([c.mesh, c.transform])
			to_free.append(c)
	if items.size() > 1:
		var merged := MB.merge_surfaces(items)
		for c in to_free:
			body_pivot.remove_child(c)
			c.queue_free()
		_mi(merged, "Static", body_pivot)
	_tune_instances(self)


func _tune_instances(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if mi.name in SHADOW_PARTS \
					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if mi.name in NEAR_ONLY:
				mi.visibility_range_end = 45.0
		elif c is Label3D:
			(c as Label3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(c as Label3D).visibility_range_end = 45.0
		_tune_instances(c)


func _col(key: String) -> Color:
	return style[key]


## Color con alternativa: si style[key] es null usa style[fallback].
func _colf(key: String, fallback: String) -> Color:
	var v = style.get(key)
	return style[fallback] if v == null else v


func _mi(mesh: Mesh, node_name: String, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


## Rótulo 3D pegado a la carrocería (nombres, números).
func _text(t: String, pos: Vector3, rot_deg: Vector3, px: float, col: Color, size: int = 64,
		outline: Color = Color(0, 0, 0, 0)) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0 if outline.a == 0.0 else 10
	l.outline_modulate = outline
	l.position = pos
	l.rotation_degrees = rot_deg
	l.double_sided = false
	body_pivot.add_child(l)
	return l


## Atajo para secciones de loft (ver MeshBuilder.section).
func _sec(z: float, w: float, h: float, yc: float, c: float, x: float = 0.0) -> PackedVector3Array:
	return MB.section(z, w, h, yc, c, x)


# =============================================================================
# Chasis
# =============================================================================

func _build_chassis() -> void:
	var mb := MB.new()
	var body := _col("body")
	var dark := _col("body_dark")
	var acc := _col("accent")
	var trim := _col("trim")
	var metal := _col("metal")
	var chrome := _col("chrome")

	# --- Carrocería principal: loft de morro a cola con chaflanes ---
	mb.use("paint")
	var shell := [
		_sec(-1.46, 0.5, 0.16, 0.34, 0.06),
		_sec(-1.2, 0.92, 0.28, 0.4, 0.09),
		_sec(-0.78, 1.04, 0.42, 0.48, 0.12),
		_sec(-0.5, 1.02, 0.3, 0.42, 0.1),
		_sec(-0.3, 1.0, 0.2, 0.37, 0.07),
		_sec(0.3, 1.12, 0.2, 0.37, 0.07),
		_sec(0.62, 1.16, 0.46, 0.5, 0.12),
		_sec(1.05, 1.02, 0.5, 0.56, 0.14),
		_sec(1.32, 0.78, 0.32, 0.56, 0.1),
	]
	mb.loft(shell, [body, body.lightened(0.06), body, dark, trim, dark, body, body.lightened(0.06)])
	# Franjas de carreras sobre el morro
	for x: float in [-0.13, 0.13]:
		mb.loft([
			_sec(-1.44, 0.07, 0.02, 0.425, 0.0, x * 0.4),
			_sec(-1.18, 0.09, 0.02, 0.545, 0.0, x * 0.85),
			_sec(-0.8, 0.1, 0.02, 0.705, 0.0, x),
		], [_col("stripe")])
	# --- Pontones laterales con toma de aire y dorsal ---
	for s: float in [-1.0, 1.0]:
		var x := s * 0.7
		mb.use("paint")
		mb.loft([
			_sec(-0.62, 0.2, 0.18, 0.33, 0.05, x),
			_sec(-0.46, 0.34, 0.3, 0.37, 0.08, x),
			_sec(0.55, 0.4, 0.34, 0.4, 0.09, x),
			_sec(0.82, 0.3, 0.26, 0.4, 0.07, x),
		], [acc, body, body, dark, trim, dark, body, body])
		mb.use("default")
		mb.box(Vector3(x, 0.38, -0.47), Vector3(0.24, 0.16, 0.03), Color("15161f"))
		mb.use("paint")
		mb.push_at(Vector3(s * 0.905, 0.42, 0.12), Vector3(0, 0, 90))
		mb.cylinder(Vector3(0, -0.01, 0), 0.14, 0.02, 10, Color.WHITE)
		mb.pop()
	# --- Alerón delantero / parachoques ---
	mb.use("paint")
	mb.chamfer_box(Vector3(0, 0.25, -1.43), Vector3(1.66, 0.09, 0.32), 0.03, acc)
	for s: float in [-1.0, 1.0]:
		mb.chamfer_box(Vector3(s * 0.84, 0.31, -1.42), Vector3(0.05, 0.22, 0.36), 0.015, dark)
	mb.use("metal")
	mb.tube(Vector3(0, 0.3, -1.4), Vector3(0, 0.36, -1.2), 0.04, 0.04, 6, trim)
	# --- Bandeja inferior y tubos laterales ---
	mb.chamfer_box(Vector3(0, 0.2, 0.05), Vector3(1.2, 0.08, 2.4), 0.03, trim)
	for s: float in [-1.0, 1.0]:
		mb.tube(Vector3(s * 0.48, 0.24, -1.15), Vector3(s * 0.48, 0.24, 1.25), 0.03, 0.03, 6, metal.darkened(0.3))
	# --- Parachoques trasero tubular ---
	mb.use("chrome")
	mb.tube(Vector3(-0.78, 0.33, 1.5), Vector3(0.78, 0.33, 1.5), 0.045, 0.045, 8, chrome)
	for s: float in [-1.0, 1.0]:
		mb.tube(Vector3(s * 0.55, 0.33, 1.5), Vector3(s * 0.45, 0.28, 1.2), 0.035, 0.035, 6, chrome)
	# --- Asiento baquet ---
	mb.use("cloth")
	mb.chamfer_box(Vector3(0, 0.47, 0.28), Vector3(0.62, 0.1, 0.52), 0.04, _col("seat"))
	mb.push_at(Vector3(0, 0.76, 0.6), Vector3(-14, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.66, 0.6, 0.11), 0.05, _col("seat"))
	mb.chamfer_box(Vector3(0, 0.36, -0.01), Vector3(0.4, 0.16, 0.13), 0.05, _col("seat").lightened(0.1))
	for s: float in [-1.0, 1.0]:
		mb.chamfer_box(Vector3(s * 0.33, -0.08, -0.12), Vector3(0.07, 0.42, 0.26), 0.03, _col("seat"))
	mb.pop()
	# --- Motor ---
	mb.use("metal")
	mb.chamfer_box(Vector3(0.0, 0.66, 1.05), Vector3(0.6, 0.34, 0.44), 0.06, metal, metal.lightened(0.15))
	for i in 4:
		mb.box(Vector3(0, 0.86, 0.9 + i * 0.1), Vector3(0.5, 0.06, 0.04), metal.darkened(0.25))
	# Admisión con filtro rojo
	mb.use("chrome")
	mb.cylinder(Vector3(-0.16, 0.83, 1.1), 0.06, 0.12, 8, chrome)
	mb.use("paint")
	mb.cylinder(Vector3(-0.16, 0.95, 1.1), 0.1, 0.1, 10, Color("d62828"), Color("2b2d42"))
	# Doble escape cromado
	for s: float in [-1.0, 1.0]:
		mb.use("chrome")
		mb.tube(Vector3(s * 0.22, 0.62, 1.12), Vector3(s * 0.38, 0.54, 1.28), 0.05, 0.05, 8, chrome, false)
		mb.tube(Vector3(s * 0.38, 0.54, 1.28), Vector3(s * 0.42, 0.5, 1.46), 0.05, 0.06, 8, chrome, false)
		mb.use("default")
		mb.tube(Vector3(s * 0.42, 0.5, 1.46), Vector3(s * 0.42, 0.5, 1.47), 0.045, 0.045, 8, Color("101014"))
	# --- Alerón trasero con perfil de ala ---
	mb.use("metal")
	for s: float in [-1.0, 1.0]:
		mb.tube(Vector3(s * 0.32, 0.8, 1.12), Vector3(s * 0.32, 1.08, 1.3), 0.03, 0.03, 6, trim)
	mb.use("paint")
	var wing := []
	for x: float in [-0.82, 0.82]:
		wing.append(PackedVector3Array([
			Vector3(x, 1.1, 1.12), Vector3(x, 1.15, 1.2), Vector3(x, 1.17, 1.42),
			Vector3(x, 1.15, 1.52), Vector3(x, 1.11, 1.45), Vector3(x, 1.07, 1.2),
		]))
	mb.loft(wing, [acc, acc, acc.lightened(0.1), acc.darkened(0.15), acc.darkened(0.2), acc.darkened(0.1)])
	for s: float in [-1.0, 1.0]:
		mb.chamfer_box(Vector3(s * 0.84, 1.08, 1.32), Vector3(0.04, 0.3, 0.5), 0.02, body)
	# --- Columna de dirección ---
	mb.use("metal")
	mb.tube(Vector3(0, 0.46, -0.85), WHEEL_CENTER + Vector3(0, -0.03, 0.04), 0.03, 0.03, 6, trim)
	# --- Placa frontal para el dorsal ---
	mb.use("paint")
	mb.push_at(Vector3(0, 0.66, -0.95), Vector3(-62, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.42, 0.3, 0.03), 0.04, Color.WHITE)
	mb.pop()
	_mi(mb.commit(), "Chassis", body_pivot)

	# Faros y pilotos (luminosos)
	var glow := MB.new()
	for s: float in [-1.0, 1.0]:
		glow.push_at(Vector3(s * 0.3, 0.52, -1.16), Vector3(-25, s * 12, 0))
		glow.chamfer_box(Vector3.ZERO, Vector3(0.16, 0.07, 0.03), 0.015, Color("fff3c4"))
		glow.pop()
		glow.box(Vector3(s * 0.62, 0.33, 1.53), Vector3(0.14, 0.06, 0.03), Color("ff2d2d"))
	_mi(glow.commit(MB.glow_material()), "Lights", body_pivot)

	# Números del dorsal (frontal y laterales)
	var plates := [
		[Vector3(0, 0.672, -0.975), Vector3(-62, 0, 0), 0.0045, Vector3(0, 0, 0)],
		[Vector3(-0.918, 0.42, 0.12), Vector3(0, -90, 0), 0.0035, Vector3.ZERO],
		[Vector3(0.918, 0.42, 0.12), Vector3(0, 90, 0), 0.0035, Vector3.ZERO],
	]
	for p in plates:
		var num := Label3D.new()
		num.text = String(style["number"])
		num.font_size = 72
		num.pixel_size = p[2]
		num.modulate = _col("trim")
		num.outline_size = 0
		num.position = p[0]
		num.rotation_degrees = p[1]
		num.double_sided = false
		body_pivot.add_child(num)


func _build_steering_wheel() -> void:
	steering_wheel = Node3D.new()
	steering_wheel.name = "SteeringWheel"
	steering_wheel.position = WHEEL_CENTER
	steering_wheel.rotation_degrees = Vector3(WHEEL_TILT, 0, 0)
	body_pivot.add_child(steering_wheel)
	var mb := MB.new()
	mb.use("rubber")
	var n := 14
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		mb.tube(Vector3(sin(a0), cos(a0), 0) * WHEEL_R, Vector3(sin(a1), cos(a1), 0) * WHEEL_R,
				0.024, 0.024, 6, Color("1b1c24"), false)
	mb.use("metal")
	for a: float in [PI * 0.5, PI * 1.5, PI]:
		mb.beam(Vector3.ZERO, Vector3(sin(a), cos(a), 0) * WHEEL_R, 0.03, _col("metal"))
	mb.use("paint")
	mb.push_at(Vector3.ZERO, Vector3(90, 0, 0))
	mb.cylinder(Vector3(0, -0.02, 0), 0.06, 0.05, 8, _col("accent"), _col("body"))
	mb.pop()
	mb.box(Vector3(0, WHEEL_R, 0), Vector3(0.03, 0.03, 0.055), _col("accent"))
	_mi(mb.commit_single("rubber"), "SteeringMesh", steering_wheel)


# =============================================================================
# Piloto chibi
# =============================================================================

## Sección horizontal (plano XZ) achaflanada a la altura y.
func _hsec(y: float, w: float, d: float, c: float, z: float = 0.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in MB.chamfer_rect(w, d, c):
		out.append(Vector3(p.x, y, p.y + z))
	return out


func _build_driver() -> void:
	driver_pivot = Node3D.new()
	driver_pivot.name = "Driver"
	driver_pivot.position = DRIVER_ORIGIN
	body_pivot.add_child(driver_pivot)

	var mb := MB.new()
	_build_legs(mb)
	_build_torso(mb)
	# Hombros (parte del cuerpo: no se mueven respecto al torso)
	var sleeve := _colf("sleeve", "suit")
	for x: float in [-0.28, 0.28]:
		mb.sphere(Vector3(x, 0.45, -0.02), Vector3(0.09, 0.09, 0.09) * float(style["arm_scale"]), 8, 5, sleeve)
	_mi(mb.commit_single("cloth"), "DriverBody", driver_pivot)
	if style["scarf_tail"]:
		_build_scarf_tail()
	_build_arms()

	head_pivot = Node3D.new()
	head_pivot.name = "Head"
	head_pivot.position = Vector3(0, 0.6, 0.0)
	head_pivot.scale = Vector3.ONE * float(style["head_scale"])
	driver_pivot.add_child(head_pivot)
	_build_head()


## Gancho: piernas y calzado (coordenadas del piloto: cadera en el origen, delante -Z).
func _build_legs(mb: MB) -> void:
	for s: float in [-1.0, 1.0]:
		var hip := Vector3(s * 0.13, 0.06, -0.05)
		var knee := Vector3(s * 0.17, 0.2, -0.46)
		var foot := Vector3(s * 0.16, 0.04, -0.82)
		mb.use("cloth")
		mb.tube(hip, knee, 0.1, 0.085, 7, _col("pants"))
		mb.tube(knee, foot, 0.085, 0.075, 7, _col("pants"))
		mb.sphere(knee, Vector3(0.088, 0.088, 0.088), 7, 4, _col("pants"))
		_build_shoe(mb, foot, s)


## Gancho: zapatilla en `foot`.
func _build_shoe(mb: MB, foot: Vector3, _s: float) -> void:
	mb.use("rubber")
	mb.chamfer_box(foot + Vector3(0, 0.03, -0.06), Vector3(0.17, 0.13, 0.27), 0.05, _col("shoe"))
	mb.chamfer_box(foot + Vector3(0, -0.035, -0.06), Vector3(0.18, 0.04, 0.29), 0.015, _col("shoe_sole"))


## Torso estándar (cintura y=0, hombros y≈0.45, cuello y≈0.55). Útil para los ganchos.
func _torso_shell(mb: MB, col: Color, scale_w: float = 1.0) -> void:
	mb.use("cloth")
	mb.loft([
		_hsec(0.0, 0.5 * scale_w, 0.36, 0.1),
		_hsec(0.22, 0.58 * scale_w, 0.4, 0.12, -0.01),
		_hsec(0.42, 0.56 * scale_w, 0.36, 0.12, -0.01),
		_hsec(0.52, 0.36 * scale_w, 0.26, 0.08),
	], [col, col, col, col.darkened(0.08), col, col, col, col.darkened(0.08)])


## Gancho: torso y ropa. Por defecto, sudadera con capucha y pañuelo.
func _build_torso(mb: MB) -> void:
	var suit := _col("suit")
	var suit_d := _col("suit_dark")
	_torso_shell(mb, suit)
	mb.loft([_hsec(-0.02, 0.52, 0.38, 0.1), _hsec(0.06, 0.53, 0.39, 0.1)], [suit_d], false, false)
	mb.push_at(Vector3(0, 0.5, 0.15), Vector3(-20, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.42, 0.16, 0.16), 0.06, suit_d)
	mb.pop()
	mb.box(Vector3(0, 0.14, -0.2), Vector3(0.32, 0.12, 0.025), suit_d)
	mb.box(Vector3(0, 0.3, -0.2), Vector3(0.025, 0.36, 0.02), Color("d9dde6"))
	for x: float in [-0.07, 0.07]:
		mb.box(Vector3(x, 0.44, -0.18), Vector3(0.022, 0.13, 0.022), Color.WHITE)
	mb.use("paint")
	mb.push_at(Vector3(0.15, 0.34, -0.205), Vector3(0, 0, 12))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.12, 0.12, 0.02), 0.03, _col("accent"))
	mb.pop()
	# Bufanda / pañuelo al cuello
	mb.use("cloth")
	mb.loft([_hsec(0.5, 0.34, 0.28, 0.1), _hsec(0.6, 0.3, 0.25, 0.1)], [_col("scarf")])


func _build_scarf_tail() -> void:
	var tail_root := Node3D.new()
	tail_root.name = "ScarfTail"
	tail_root.position = Vector3(0.06, 0.56, 0.14)
	driver_pivot.add_child(tail_root)
	var parent: Node3D = tail_root
	for i in 2:
		var seg := Node3D.new()
		parent.add_child(seg)
		if i > 0:
			seg.position = Vector3(0, 0, 0.22)
		var smb := MB.new()
		smb.use("cloth")
		smb.slab(Vector3.ZERO, Vector3(0, 0, 0.24), 0.13 - i * 0.03, 0.11 - i * 0.04, 0.025, _col("scarf"))
		_mi(smb.commit(), "Seg%d" % i, seg)
		_scarf_tail.append(seg)
		parent = seg


func _build_arms() -> void:
	var sleeve := _colf("sleeve", "suit")
	var fore: Color = sleeve if style["forearm"] == null else style["forearm"]
	var k: float = style["arm_scale"]
	var unit_upper := _unit_limb(0.075 * k, 0.065 * k, sleeve, "skin" if sleeve == _col("skin") else "cloth")
	var unit_fore := _unit_limb(0.065 * k, 0.058 * k, fore, "skin" if fore == _col("skin") else "cloth")
	var hand_mb := MB.new()
	hand_mb.use("skin" if style["glove"] == style["skin"] else "cloth")
	hand_mb.sphere(Vector3.ZERO, Vector3(0.08, 0.075, 0.09), 7, 5, _col("glove"))
	hand_mb.sphere(Vector3(0, 0.05, -0.03), Vector3(0.035, 0.03, 0.04), 5, 3, _col("glove"))
	hand_mb.use("cloth")
	hand_mb.chamfer_box(Vector3(0, 0, 0.075), Vector3(0.13, 0.12, 0.05), 0.03, _colf("cuff", "suit_dark"))
	var hand_mesh := hand_mb.commit_single("skin" if style["glove"] == style["skin"] else "cloth")
	for side: String in ["l", "r"]:
		_arm_parts[side + "_upper"] = _mi(unit_upper, side + "_upper", driver_pivot)
		_arm_parts[side + "_fore"] = _mi(unit_fore, side + "_fore", driver_pivot)
		_arm_parts[side + "_hand"] = _mi(hand_mesh, side + "_hand", driver_pivot)


## Malla de extremidad de 1 m a lo largo de -Z (se escala en Z para cada longitud).
func _unit_limb(r1: float, r2: float, col: Color, mat: String = "cloth") -> ArrayMesh:
	var mb := MB.new()
	mb.use(mat)
	mb.tube(Vector3.ZERO, Vector3(0, 0, -1.0), r1, r2, 7, col, true)
	return mb.commit()


func _build_head() -> void:
	var mb := MB.new()
	var hc := HEAD_CENTER   # centro de la cabeza (grande: proporción chibi)
	_build_head_shape(mb, hc)
	_build_hair(mb, hc)
	_build_head_extras(mb, hc)
	if style["beard"] != null:
		_build_beard(mb, hc, style["beard"], String(style["beard_style"]))
	if style["earring"] != null:
		mb.use("chrome")
		for s: float in [-1.0, 1.0]:
			mb.sphere(hc + Vector3(s * 0.4, -0.11, 0.02), Vector3(0.028, 0.028, 0.028), 6, 3, style["earring"])
	_mi(mb.commit_single("skin"), "HeadMesh", head_pivot)
	_build_face(hc)


## Gancho: cráneo, cuello, orejas, mofletes y nariz.
func _build_head_shape(mb: MB, hc: Vector3) -> void:
	var skin := _col("skin")
	mb.use("skin")
	mb.cylinder(Vector3(0, -0.04, 0), 0.09, 0.14, 7, skin)
	mb.sphere(hc, Vector3(0.4, 0.37, 0.38), 12, 8, skin)
	for s: float in [-1.0, 1.0]:
		mb.sphere(hc + Vector3(s * 0.39, -0.02, 0.03), Vector3(0.07, 0.1, 0.06), 6, 4, skin.darkened(0.06))
		if style["blush"]:
			mb.sphere(hc + Vector3(s * 0.24, -0.13, -0.27), Vector3(0.06, 0.034, 0.03), 6, 3, Color("f29a8f"))
	mb.sphere(hc + Vector3(0, -0.085, -0.365), Vector3(0.032, 0.026, 0.022), 6, 3, skin.darkened(0.12))


## Gancho: pelo y gorra. Por defecto, pelo de punta y gorra hacia atrás.
func _build_hair(mb: MB, hc: Vector3) -> void:
	var hair := _col("hair")
	var cap := _col("cap")
	var brim := _col("cap_brim")
	mb.use("cloth")
	mb.sphere(hc + Vector3(0, 0.04, 0.1), Vector3(0.4, 0.34, 0.34), 10, 5, hair, PI * 0.3, PI * 0.72)
	for i in 7:
		var a := lerpf(-1.25, 1.25, i / 6.0)
		var root := hc + Vector3(sin(a) * 0.33, -0.02 - absf(a) * 0.05, cos(a) * 0.3)
		var tip := root + Vector3(sin(a) * 0.12, -0.12, cos(a) * 0.14)
		mb.slab(root, tip, 0.13, 0.02, 0.06, hair, Vector3(sin(a), 0, cos(a)))
	for s: float in [-1.0, 1.0]:
		mb.slab(hc + Vector3(s * 0.37, 0.12, 0.0), hc + Vector3(s * 0.4, -0.06, -0.06), 0.12, 0.03, 0.05, hair, Vector3(s, 0, 0))
	for p: Vector3 in [Vector3(-0.19, 0.235, -0.31), Vector3(-0.07, 0.245, -0.33), Vector3(0.06, 0.235, -0.32)]:
		mb.slab(hc + p, hc + p + Vector3(-0.045, -0.065, -0.025), 0.11, 0.02, 0.05, hair, Vector3(0, 0, -1))
	# Gorra hacia atrás con ribete
	mb.sphere(hc + Vector3(0, 0.08, 0.0), Vector3(0.43, 0.42, 0.41), 12, 4, cap, 0.0, PI * 0.42)
	mb.sphere(hc + Vector3(0, 0.08, 0.0), Vector3(0.435, 0.425, 0.415), 12, 1, brim, PI * 0.38, PI * 0.42)
	mb.sphere(hc + Vector3(0, 0.5, 0.0), Vector3(0.04, 0.025, 0.04), 6, 2, brim)
	mb.push_at(hc + Vector3(0, 0.17, 0.4), Vector3(-10, 0, 0))
	mb.frustum(Vector3.ZERO, Vector2(0.44, 0.06), Vector2(0.52, 0.3), 0.04, brim, Vector2(0, 0.15))
	mb.pop()


## Gancho: lo que cada corredor añada a la cabeza (accesorios, piercings...).
func _build_head_extras(_mb: MB, _hc: Vector3) -> void:
	pass


## Barba facetada que sigue la mandíbula. full = barba recortada, stubble = sombra de
## barba, goatee = perilla y bigote.
func _build_beard(mb: MB, hc: Vector3, col: Color, kind: String) -> void:
	mb.use("cloth")
	var t := 0.02 if kind == "full" else 0.008
	if kind != "goatee":
		# Mandíbula: placas pegadas a la cara de patilla a patilla, POR DEBAJO de la boca
		# (la boca y los mofletes quedan a la vista)
		var n := 10
		for i in n:
			var a0 := lerpf(-1.5, 1.5, float(i) / n)
			var a1 := lerpf(-1.5, 1.5, float(i + 1) / n)
			var p0 := _jaw_point(hc, a0)
			var p1 := _jaw_point(hc, a1)
			var mid := (p0 + p1) * 0.5
			var out := Vector3(mid.x - hc.x, -0.35, mid.z - hc.z).normalized()
			var w := lerpf(0.13, 0.09, absf(a0) / 1.5)
			mb.slab(p0 + out * t, p1 + out * t, w, w, t + 0.012, col, out)
		# Barbilla
		mb.sphere(hc + Vector3(0, -0.3, -0.24), Vector3(0.13, 0.065 + t, 0.09 + t), 8, 4, col)
	# Bigote fino y perilla bajo el labio
	mb.push_at(hc + Vector3(0, -0.128, -0.352), Vector3(8, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.15, 0.022, 0.025), 0.008, col)
	mb.pop()
	mb.sphere(hc + Vector3(0, -0.235, -0.325), Vector3(0.05, 0.035, 0.03), 6, 3, col)


## Punto de la línea de la mandíbula (a = 0 barbilla, ±1.5 junto a las orejas).
func _jaw_point(hc: Vector3, a: float) -> Vector3:
	var y := -0.26 + (1.0 - cos(a)) * 0.2
	var r := 0.33 + (1.0 - cos(a)) * 0.05
	return hc + Vector3(sin(a) * 0.37, y, -cos(a) * r)


## Ojos (con párpado), cejas y bocas según `style`.
func _build_face(hc: Vector3) -> void:
	var es: float = style["eye_size"]
	var lid: float = style["eye_lid"]
	for s: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.name = "Eye"
		eye.position = hc + Vector3(s * 0.15, -0.03, -0.345)
		head_pivot.add_child(eye)
		var emb := MB.new()
		emb.use("skin")
		emb.sphere(Vector3.ZERO, Vector3(0.088, 0.108, 0.04) * es, 9, 5, Color("fbfbf7"))
		emb.sphere(Vector3(0, -0.006, -0.02) * es, Vector3(0.064, 0.082, 0.03) * es, 9, 4, _col("eye"))
		emb.sphere(Vector3(0, -0.012, -0.035) * es, Vector3(0.036, 0.05, 0.02) * es, 7, 3, Color("120d0a"))
		if style["eye_shine"]:
			emb.sphere(Vector3(s * 0.024, 0.036, -0.05) * es, Vector3(0.021, 0.023, 0.015) * es, 5, 2, Color.WHITE)
			emb.sphere(Vector3(-s * 0.02, -0.04, -0.048) * es, Vector3(0.01, 0.01, 0.01) * es, 4, 2, Color.WHITE)
		else:
			emb.sphere(Vector3(s * 0.015, 0.02, -0.05) * es, Vector3(0.01, 0.011, 0.01) * es, 4, 2, Color.WHITE)
		if lid > 0.0:
			# Párpado superior: casquete de piel que tapa la parte alta del ojo
			emb.sphere(Vector3(0, 0, -0.004), Vector3(0.096, 0.116, 0.052) * es, 9, 3, _col("skin").darkened(0.05),
					0.0, PI * lid)
			emb.use("cloth")
			var ly := cos(PI * lid) * 0.116 * es
			emb.box(Vector3(0, ly, -0.045 * es), Vector3(0.17 * es, 0.016, 0.02), Color("2a1a12"))
		_mi(emb.commit_single("skin"), "EyeMesh", eye)
		_eyes.append(eye)
		var brow := Node3D.new()
		brow.position = hc + Vector3(s * 0.15, float(style["brow_y"]), -0.345)
		brow.rotation.z = -s * deg_to_rad(float(style["brow_tilt"]))
		head_pivot.add_child(brow)
		var bmb := MB.new()
		bmb.use("cloth")
		bmb.chamfer_box(Vector3.ZERO, style["brow_size"], 0.01, _col("hair"))
		_mi(bmb.commit_single("cloth"), "Brow", brow)
		_brows.append(brow)
	_brow_base_y = hc.y + float(style["brow_y"])
	_mouth_smile = _make_mouth(String(style["mouth"]), hc)
	_mouth_grin = _make_mouth(String(style["mouth_excited"]), hc)
	_mouth_grin.visible = false


## Bocas: smile, flat (línea), smirk (media sonrisa), grin (sonrisa abierta), shout (grito).
func _make_mouth(kind: String, hc: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Mouth_" + kind
	node.position = hc + Vector3(0, -0.17, -0.338)
	head_pivot.add_child(node)
	var m := MB.new()
	m.use("skin")
	var lip := Color("7a2e2e")
	match kind:
		"flat":
			m.box(Vector3(0, -0.004, 0), Vector3(0.11, 0.018, 0.025), lip.darkened(0.1))
		"smirk":
			m.box(Vector3(-0.01, -0.006, 0), Vector3(0.09, 0.018, 0.025), lip)
			m.push_at(Vector3(0.05, 0.004, 0), Vector3(0, 0, 25.0))
			m.box(Vector3.ZERO, Vector3(0.045, 0.018, 0.025), lip)
			m.pop()
		"grin":
			m.sphere(Vector3(0, 0.005, 0.003), Vector3(0.085, 0.055, 0.03), 9, 4, Color("6b1f2a"), PI * 0.5, PI)
			m.box(Vector3(0, -0.001, -0.011), Vector3(0.15, 0.02, 0.02), Color.WHITE)
			m.sphere(Vector3(0, -0.033, -0.011), Vector3(0.04, 0.012, 0.015), 6, 2, Color("ef6f86"))
		"shout":
			# Boca muy abierta (algo más baja que las demás): hueco oscuro, dientes arriba y lengua
			node.position.y -= 0.035
			node.position.z += 0.012
			m.sphere(Vector3(0, -0.01, -0.006), Vector3(0.09, 0.07, 0.04), 10, 6, Color("4a1420"))
			m.box(Vector3(0, 0.042, -0.036), Vector3(0.13, 0.024, 0.02), Color.WHITE)
			m.sphere(Vector3(0, -0.05, -0.03), Vector3(0.055, 0.024, 0.02), 7, 3, Color("e8697e"))
			m.sphere(Vector3(0, -0.01, 0.0), Vector3(0.1, 0.08, 0.04), 10, 6, lip.darkened(0.15))
		_:
			m.box(Vector3(0, -0.007, 0), Vector3(0.07, 0.02, 0.025), lip)
			for s: float in [-1.0, 1.0]:
				m.push_at(Vector3(s * 0.055, 0.005, 0), Vector3(0, 0, s * 25.0))
				m.box(Vector3.ZERO, Vector3(0.05, 0.02, 0.025), lip)
				m.pop()
	_mi(m.commit_single("skin"), "MouthMesh", node)
	return node


# =============================================================================
# Ruedas
# =============================================================================

func _wheel_mesh(r: float, w: float) -> ArrayMesh:
	var mb := MB.new()
	var tire := _col("tire")
	var tread := _col("tire_tread")
	var hw := w * 0.5
	var ri := r * 0.62
	# Neumático: perfil con hombros redondeados (antihorario en el plano x-r)
	mb.use("rubber")
	var prof := PackedVector2Array([
		Vector2(-hw, ri), Vector2(hw, ri), Vector2(hw, r - 0.06), Vector2(hw - 0.025, r - 0.015),
		Vector2(hw - 0.06, r), Vector2(-hw + 0.06, r), Vector2(-hw + 0.025, r - 0.015), Vector2(-hw, r - 0.06),
	])
	mb.lathe(prof, 16, [tire.darkened(0.3), tire, tire, tread, tread, tread, tire, tire],
			{3: tire, 4: tire.darkened(0.2), 5: tire}, true)
	# Franja de color en el flanco exterior
	if style["tire_band"]:
		mb.use("paint")
		var band0 := lerpf(ri + 0.014, r - 0.06, 0.3)
		var band1 := lerpf(ri + 0.014, r - 0.06, 0.62)
		mb.lathe(PackedVector2Array([Vector2(hw + 0.003, band0), Vector2(hw + 0.003, band1)]), 16, [_col("accent")])
	# Llanta: buje cromado, plato hundido oscuro y labio de color
	var rr := ri + 0.01
	mb.use("chrome")
	mb.lathe(PackedVector2Array([
		Vector2(hw + 0.045, 0.0), Vector2(hw + 0.045, 0.045), Vector2(hw + 0.02, 0.07), Vector2(hw - 0.03, 0.075),
	]), 10, [_col("chrome")])
	mb.use("paint")
	mb.lathe(PackedVector2Array([Vector2(hw - 0.03, 0.075), Vector2(hw - 0.03, rr * 0.86)]), 16, [_col("rim_dish")])
	mb.lathe(PackedVector2Array([Vector2(hw - 0.03, rr * 0.86), Vector2(hw + 0.012, rr), Vector2(hw - 0.01, rr + 0.004)]), 16,
			[_col("rim"), _col("rim").darkened(0.2)])
	if style["rim_style"] == "dish":
		# Llanta de plato: disco liso con tapacubos de color (sin radios)
		mb.use("paint")
		mb.lathe(PackedVector2Array([Vector2(hw - 0.02, rr * 0.86), Vector2(hw + 0.005, rr * 0.5), Vector2(hw + 0.02, 0.09)]), 16,
				[_col("rim").darkened(0.1), _col("rim")])
		mb.push_at(Vector3(hw + 0.02, 0, 0), Vector3(0, 0, -90))
		mb.cylinder(Vector3.ZERO, 0.09, 0.03, 12, _colf("hub", "body"))
		mb.pop()
		return mb.commit_single("rubber")
	# Cinco radios y tuercas
	for i in 5:
		var a := TAU * i / 5.0
		var d := Vector3(0, cos(a), sin(a))
		mb.use("paint")
		mb.slab(Vector3(hw - 0.01, 0, 0) + d * 0.06, Vector3(hw - 0.02, 0, 0) + d * rr * 0.86,
				0.06, 0.035, 0.03, _col("rim"), Vector3(1, 0, 0))
		mb.use("chrome")
		mb.box(Vector3(hw + 0.03, 0, 0) + d * 0.045, Vector3(0.02, 0.018, 0.018), _col("chrome").darkened(0.3))
	mb.use("paint")
	mb.push_at(Vector3(hw + 0.045, 0, 0), Vector3(0, 0, -90))
	mb.cylinder(Vector3.ZERO, 0.03, 0.012, 8, _colf("hub", "body"))
	mb.pop()
	return mb.commit_single("rubber")


func _build_wheels() -> void:
	var front := _wheel_mesh(front_size.x, front_size.y)
	var rear := _wheel_mesh(rear_size.x, rear_size.y)
	var fw := front_wheel
	var rw := rear_wheel
	var defs := [
		[Vector3(-fw.x, fw.y, fw.z), front, true, front_size.x, -1.0],
		[Vector3(fw.x, fw.y, fw.z), front, true, front_size.x, 1.0],
		[Vector3(-rw.x, rw.y, rw.z), rear, false, rear_size.x, -1.0],
		[Vector3(rw.x, rw.y, rw.z), rear, false, rear_size.x, 1.0],
	]
	for d in defs:
		var steer := Node3D.new()
		steer.name = "SteerPivot"
		steer.position = d[0]
		add_child(steer)  # las ruedas no se inclinan con la carrocería
		var spin := Node3D.new()
		spin.name = "Spin"
		steer.add_child(spin)
		var mesh := _mi(d[1], "WheelMesh", spin)
		if d[4] < 0.0:
			mesh.rotation.y = PI  # cara exterior hacia fuera
		if d[2]:
			steer_pivots.append(steer)
		wheel_spin.append(spin)
		wheel_radius.append(d[3])
	var mb := MB.new()
	mb.use("metal")
	mb.tube(Vector3(-fw.x, fw.y, fw.z), Vector3(fw.x, fw.y, fw.z), 0.03, 0.03, 6, _col("metal").darkened(0.3))
	mb.tube(Vector3(-rw.x, rw.y, rw.z), Vector3(rw.x, rw.y, rw.z), 0.04, 0.04, 6, _col("metal").darkened(0.3))
	_mi(mb.commit_single("metal"), "Axles", self)


# =============================================================================
# Animación
# =============================================================================

## Llamado cada fotograma por el kart con su estado físico.
func update_visual(st: Dictionary, delta: float) -> void:
	_t += delta
	var speed: float = st["speed"]
	var speed_ratio: float = st["speed_ratio"]
	var steer: float = st["steer"]
	var drifting: bool = st["drifting"]
	var ddir: int = st["drift_dir"]
	var yaw_rate: float = st["yaw_rate"]
	var boost: bool = st["boost"]
	var k := minf(1.0, delta * 10.0)

	# Ruedas: rodadura y dirección (contravolante visual en derrape)
	for i in wheel_spin.size():
		wheel_spin[i].rotate_x(-float(st["distance"]) / wheel_radius[i])
	var steer_angle := steer * 0.42
	if drifting:
		steer_angle = -ddir * 0.22 + steer * 0.18
	for p in steer_pivots:
		p.rotation.y = lerp_angle(p.rotation.y, -steer_angle, minf(1.0, delta * 16.0))

	# Suspensión: muelle amortiguado (rebota al aterrizar). Se integra en pasos
	# pequeños para que sea estable aunque un fotograma tarde mucho (móviles lentos).
	var remaining := minf(delta, 0.25)
	while remaining > 0.0:
		var h := minf(remaining, 1.0 / 120.0)
		_susp_v += (-_susp_y * 220.0 - _susp_v * 16.0) * h
		_susp_y += _susp_v * h
		remaining -= h
	_susp_y = clampf(_susp_y, -0.12, 0.12)
	if not st["grounded"]:
		_susp_y = lerpf(_susp_y, 0.03, k * 0.5)
	body_pivot.position.y = _susp_y
	# Balanceo por la fuerza lateral y cabeceo al frenar/acelerar
	var lateral := clampf(-yaw_rate * speed * 0.012, -1.0, 1.0)
	_roll = lerpf(_roll, lateral * 0.075, k)
	var target_pitch := 0.0
	if boost:
		target_pitch = 0.045
	elif st["braking"]:
		target_pitch = -0.05
	_pitch = lerpf(_pitch, target_pitch, k * 0.8)
	body_pivot.rotation.z = _roll
	body_pivot.rotation.x = _pitch
	rotation.y = lerp_angle(rotation.y, -ddir * 0.08 if drifting else 0.0, k)

	# Volante y brazos
	_wheel_angle = lerpf(_wheel_angle, steer * 1.25, minf(1.0, delta * 18.0))
	steering_wheel.rotation.z = -_wheel_angle
	_update_arms()

	# Piloto: se inclina hacia fuera de la curva, respira, mira a la curva o atrás
	driver_pivot.rotation.z = lerpf(driver_pivot.rotation.z, lateral * 0.22, k)
	driver_pivot.rotation.x = lerpf(driver_pivot.rotation.x, -_pitch * 2.0 + (0.08 if boost else 0.0), k)
	driver_pivot.position.y = DRIVER_ORIGIN.y + sin(_t * 2.4) * 0.008 * (1.0 - minf(speed_ratio, 1.0))
	var head_yaw := -steer * 0.35
	var twist := 0.0
	if st["look_back"]:
		head_yaw = -1.9
		twist = -0.35
	head_pivot.rotation.y = lerp_angle(head_pivot.rotation.y, head_yaw, minf(1.0, delta * 9.0))
	head_pivot.rotation.z = lerpf(head_pivot.rotation.z, lateral * 0.15, k)
	driver_pivot.rotation.y = lerp_angle(driver_pivot.rotation.y, twist, minf(1.0, delta * 7.0))

	# Parpadeo
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.12
		_blink_timer = randf_range(1.8, 4.5)
	_blink = maxf(_blink - delta, 0.0)
	var eye_scale := 0.12 if _blink > 0.0 else 1.0
	for e in _eyes:
		e.scale.y = lerpf(e.scale.y, eye_scale, minf(1.0, delta * 40.0))
	# Expresión: turbo o derrape = sonrisa abierta y cejas arriba
	var excited := boost or drifting
	_mouth_grin.visible = excited
	_mouth_smile.visible = not excited
	for b in _brows:
		b.position.y = lerpf(b.position.y, _brow_base_y + (0.03 if excited else 0.0), k)

	# Bufanda: se levanta con la velocidad y ondea
	var lift := clampf(speed / 25.0, 0.0, 1.0)
	for i in _scarf_tail.size():
		var flutter := sin(_t * (14.0 + i * 5.0) + i) * (0.1 + 0.25 * lift)
		_scarf_tail[i].rotation.x = lerpf(-1.2, -0.1, lift) * (1.0 if i == 0 else 0.3) + flutter
		_scarf_tail[i].rotation.y = sin(_t * 9.0 + i) * 0.15 * lift


## Impulso a la suspensión (aterrizajes, choques).
func bump(strength: float) -> void:
	_susp_v -= strength * 2.2


## Coloca hombro-codo-mano para que las manos agarren el volante girado.
func _update_arms() -> void:
	var wheel_basis := Basis.from_euler(Vector3(deg_to_rad(WHEEL_TILT), 0, 0))
	var wx := wheel_basis.x
	var wy := wheel_basis.y
	var center := WHEEL_CENTER - DRIVER_ORIGIN
	for side: String in ["l", "r"]:
		var sgn := -1.0 if side == "l" else 1.0
		var phi := sgn * deg_to_rad(78.0) + _wheel_angle
		var hand := center + (wx * sin(phi) + wy * cos(phi)) * WHEEL_R + Vector3(0, 0, 0.03)
		var shoulder := Vector3(sgn * 0.28, 0.45, -0.02)
		var elbow := (shoulder + hand) * 0.5 + Vector3(sgn * 0.11, -0.1, 0.04)
		_place_limb(_arm_parts[side + "_upper"], shoulder, elbow)
		_place_limb(_arm_parts[side + "_fore"], elbow, hand)
		var h: Node3D = _arm_parts[side + "_hand"]
		h.position = hand
		if (hand - elbow).length() > 0.01:
			h.basis = Basis.looking_at(hand - elbow, Vector3.UP)


func _place_limb(node: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	node.position = a
	node.basis = Basis.looking_at(d, Vector3.UP) * Basis.from_scale(Vector3(1, 1, len))
