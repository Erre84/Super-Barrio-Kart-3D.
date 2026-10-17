extends Node3D
## Modelo low-poly del kart + piloto chibi, construido por código.
## Delante del kart es -Z (convención de Godot). El origen está a ras de suelo.
##
## Partes animables:
##   body_pivot  -> balanceo/cabeceo de carrocería
##   head_pivot  -> la cabeza del piloto mira hacia la curva
##   steer_pivots -> giro de ruedas delanteras
##   wheel_spin   -> rotación de las cuatro ruedas

const MB := preload("res://scripts/core/mesh_builder.gd")

## Estilo por defecto: piloto provisional del barrio (gorra hacia atrás, sudadera).
## Cambiar estos colores permite crear variantes hasta tener los diseños definitivos.
var style := {
	"body": Color("e63946"),
	"body_dark": Color("a4161a"),
	"accent": Color("ffd23f"),
	"trim": Color("1d2135"),
	"metal": Color("9aa5b1"),
	"tire": Color("23232a"),
	"rim": Color("ffd23f"),
	"suit": Color("2b6fe0"),
	"suit_dark": Color("1d4fa8"),
	"skin": Color("f6cfa6"),
	"hair": Color("3a2314"),
	"cap": Color("ffd23f"),
	"cap_brim": Color("e63946"),
	"glove": Color("fafafa"),
	"shoe": Color("f4f4f4"),
	"number": "7",
}

var body_pivot: Node3D
var driver_pivot: Node3D
var head_pivot: Node3D
var steer_pivots: Array[Node3D] = []
var wheel_spin: Array[Node3D] = []
var wheel_radius: Array[float] = []
var exhaust_points: Array[Vector3] = [Vector3(-0.26, 0.62, 1.38), Vector3(0.26, 0.62, 1.38)]
var rear_wheel_points: Array[Vector3] = [Vector3(-0.78, 0.05, 0.85), Vector3(0.78, 0.05, 0.85)]


func build(custom_style: Dictionary = {}) -> void:
	for k in custom_style:
		style[k] = custom_style[k]
	body_pivot = Node3D.new()
	body_pivot.name = "Body"
	add_child(body_pivot)
	_build_chassis()
	_build_driver()
	_build_wheels()


func _col(key: String) -> Color:
	return style[key]


# --- Chasis ----------------------------------------------------------------

func _build_chassis() -> void:
	var mb := MB.new()
	var body := _col("body")
	var dark := _col("body_dark")
	var acc := _col("accent")
	var trim := _col("trim")
	var metal := _col("metal")

	# Bandeja inferior
	mb.box(Vector3(0, 0.26, 0.05), Vector3(1.25, 0.12, 2.3), trim)
	# Pontones laterales (tronco piramidal, más estrechos arriba)
	for s: float in [-1.0, 1.0]:
		mb.frustum(Vector3(s * 0.58, 0.32, 0.15), Vector2(0.42, 1.25), Vector2(0.3, 1.05), 0.3,
				body, Vector2(-s * 0.03, 0.05), body)
		# Franja decorativa
		mb.frustum(Vector3(s * 0.79, 0.36, 0.15), Vector2(0.02, 1.1), Vector2(0.02, 0.9), 0.14, acc)
	# Morro afilado
	mb.frustum(Vector3(0, 0.32, -0.78), Vector2(0.95, 0.75), Vector2(0.55, 0.55), 0.28,
			body, Vector2(0, -0.12), dark)
	mb.frustum(Vector3(0, 0.32, -1.18), Vector2(0.7, 0.3), Vector2(0.45, 0.2), 0.16, dark)
	# Parachoques delantero
	mb.box(Vector3(0, 0.3, -1.4), Vector3(1.55, 0.14, 0.16), acc)
	mb.box(Vector3(0, 0.3, -1.3), Vector3(0.18, 0.1, 0.2), trim)
	# Placa del dorsal
	mb.frustum(Vector3(0, 0.58, -0.62), Vector2(0.5, 0.06), Vector2(0.44, 0.06), 0.3, Color.WHITE,
			Vector2(0, 0.08))
	# Carenado detrás del asiento
	mb.frustum(Vector3(0, 0.32, 0.55), Vector2(0.95, 0.65), Vector2(0.6, 0.45), 0.42, body,
			Vector2(0, 0.05), dark)
	# Asiento
	mb.box(Vector3(0, 0.48, 0.25), Vector3(0.62, 0.12, 0.5), trim)
	mb.frustum(Vector3(0, 0.48, 0.5), Vector2(0.62, 0.14), Vector2(0.55, 0.12), 0.55, trim,
			Vector2(0, 0.06))
	# Motor trasero
	mb.box(Vector3(0, 0.62, 1.0), Vector3(0.7, 0.36, 0.45), metal, metal.lightened(0.2))
	for i in 3:
		mb.box(Vector3(0, 0.84, 0.86 + i * 0.14), Vector3(0.6, 0.06, 0.06), metal.darkened(0.3))
	# Tubos de escape
	for s: float in [-1.0, 1.0]:
		mb.push_at(Vector3(s * 0.26, 0.62, 1.12), Vector3(90, 0, 0))
		mb.cylinder(Vector3.ZERO, 0.07, 0.3, 6, metal.darkened(0.15), Color("111111"))
		mb.pop()
	# Alerón trasero
	for s: float in [-1.0, 1.0]:
		mb.beam(Vector3(s * 0.45, 0.75, 1.05), Vector3(s * 0.45, 1.12, 1.22), 0.07, trim)
		mb.box(Vector3(s * 0.8, 1.12, 1.2), Vector3(0.05, 0.22, 0.42), body)
	mb.frustum(Vector3(0, 1.08, 1.2), Vector2(1.55, 0.42), Vector2(1.55, 0.36), 0.08, acc,
			Vector2(0, 0.03), acc.lightened(0.15))
	# Volante y columna
	mb.beam(Vector3(0, 0.55, -0.6), Vector3(0, 0.86, -0.32), 0.07, trim)
	mb.push_at(Vector3(0, 0.88, -0.3), Vector3(-60, 0, 0))
	mb.cylinder(Vector3(0, -0.03, 0), 0.2, 0.06, 8, trim, Color("2d2d38"))
	mb.pop()
	# Faros delanteros (dos rombos)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 0.32, 0.47, -1.14), Vector3(0.14, 0.08, 0.06), Color("fff6c2"))

	var mi := MeshInstance3D.new()
	mi.name = "Chassis"
	mi.mesh = mb.commit()
	body_pivot.add_child(mi)

	var number := Label3D.new()
	number.text = String(style["number"])
	number.font_size = 64
	number.pixel_size = 0.004
	number.modulate = _col("trim")
	number.outline_size = 0
	number.position = Vector3(0, 0.74, -0.665)
	number.rotation_degrees = Vector3(-108, 0, 180)
	number.double_sided = false
	body_pivot.add_child(number)


# --- Piloto chibi ------------------------------------------------------------

func _build_driver() -> void:
	driver_pivot = Node3D.new()
	driver_pivot.name = "Driver"
	driver_pivot.position = Vector3(0, 0.5, 0.25)
	body_pivot.add_child(driver_pivot)

	var mb := MB.new()
	var suit := _col("suit")
	var suit_d := _col("suit_dark")
	var glove := _col("glove")
	# Piernas hacia los pedales
	for s: float in [-1.0, 1.0]:
		mb.beam(Vector3(s * 0.14, 0.12, 0.0), Vector3(s * 0.16, 0.1, -0.62), 0.2, suit_d)
		mb.box(Vector3(s * 0.16, 0.14, -0.72), Vector3(0.18, 0.2, 0.16), _col("shoe"))
	# Torso (sudadera) — chibi: corto y ancho
	mb.frustum(Vector3(0, 0.05, 0.02), Vector2(0.56, 0.4), Vector2(0.48, 0.32), 0.5, suit,
			Vector2(0, -0.04), suit_d)
	# Bolsillo canguro y cordones de la capucha
	mb.box(Vector3(0, 0.2, -0.18), Vector3(0.32, 0.12, 0.03), suit_d)
	mb.box(Vector3(-0.06, 0.45, -0.17), Vector3(0.025, 0.12, 0.02), Color.WHITE)
	mb.box(Vector3(0.06, 0.45, -0.17), Vector3(0.025, 0.12, 0.02), Color.WHITE)
	# Capucha recogida detrás del cuello
	mb.frustum(Vector3(0, 0.46, 0.14), Vector2(0.4, 0.16), Vector2(0.3, 0.12), 0.14, suit_d)
	# Brazos al volante (posición del volante relativa al piloto)
	var wheel_l := Vector3(-0.17, 0.42, -0.53)
	var wheel_r := Vector3(0.17, 0.42, -0.53)
	for s: float in [-1.0, 1.0]:
		var shoulder := Vector3(s * 0.28, 0.48, -0.02)
		var elbow := Vector3(s * 0.33, 0.3, -0.28)
		var hand := wheel_r if s > 0 else wheel_l
		mb.beam(shoulder, elbow, 0.14, suit)
		mb.beam(elbow, hand, 0.12, suit)
		mb.sphere(hand, Vector3(0.08, 0.08, 0.08), 6, 4, glove)
	var body_mi := MeshInstance3D.new()
	body_mi.name = "DriverBody"
	body_mi.mesh = mb.commit()
	driver_pivot.add_child(body_mi)

	head_pivot = Node3D.new()
	head_pivot.name = "Head"
	head_pivot.position = Vector3(0, 0.6, 0.0)
	driver_pivot.add_child(head_pivot)
	_build_head()


func _build_head() -> void:
	var mb := MB.new()
	var skin := _col("skin")
	var hair := _col("hair")
	var cap := _col("cap")
	var brim := _col("cap_brim")
	var hc := Vector3(0, 0.36, 0)   # centro de la cabeza (grande: proporción chibi)
	# Cuello
	mb.cylinder(Vector3(0, -0.02, 0), 0.1, 0.12, 6, skin)
	# Cabeza: elipsoide facetado
	mb.sphere(hc, Vector3(0.4, 0.37, 0.38), 9, 6, skin)
	# Orejas
	for s: float in [-1.0, 1.0]:
		mb.sphere(hc + Vector3(s * 0.39, -0.02, 0.02), Vector3(0.07, 0.1, 0.06), 5, 3, skin.darkened(0.06))
	# Pelo: patillas cortas y nuca
	for s: float in [-1.0, 1.0]:
		mb.box(hc + Vector3(s * 0.365, 0.1, 0.07), Vector3(0.07, 0.16, 0.18), hair)
	mb.sphere(hc + Vector3(0, 0.04, 0.1), Vector3(0.39, 0.33, 0.33), 8, 4, hair, PI * 0.35, PI * 0.72)
	# Tupé que asoma bajo la gorra (asimétrico, con actitud)
	for x: float in [-0.2, -0.08, 0.05]:
		mb.frustum(hc + Vector3(x, 0.2, -0.33), Vector2(0.12, 0.07), Vector2(0.02, 0.02), -0.075, hair,
				Vector2(-0.02, -0.01))
	# Gorra hacia atrás (estilo urbano)
	mb.sphere(hc + Vector3(0, 0.08, 0.0), Vector3(0.43, 0.42, 0.41), 9, 3, cap, 0.0, PI * 0.42)
	mb.box(hc + Vector3(0, 0.29, 0.0), Vector3(0.06, 0.03, 0.06), brim)
	mb.push_at(hc + Vector3(0, 0.17, 0.42), Vector3(-8, 0, 0))
	mb.frustum(Vector3.ZERO, Vector2(0.42, 0.06), Vector2(0.5, 0.32), 0.035, brim, Vector2(0, 0.14))
	mb.pop()
	# Ojos grandes estilo chibi: blanco, iris, pupila y brillo
	for s: float in [-1.0, 1.0]:
		var eye := hc + Vector3(s * 0.15, -0.03, 0.0)
		mb.sphere(eye + Vector3(0, 0, -0.345), Vector3(0.085, 0.105, 0.04), 7, 4, Color("fbfbf7"))
		mb.sphere(eye + Vector3(0, -0.005, -0.365), Vector3(0.062, 0.08, 0.03), 7, 3, Color("5a3a22"))
		mb.sphere(eye + Vector3(0, -0.01, -0.38), Vector3(0.035, 0.048, 0.02), 6, 3, Color("120d0a"))
		mb.sphere(eye + Vector3(s * 0.025, 0.035, -0.395), Vector3(0.02, 0.022, 0.015), 4, 2, Color.WHITE)
		# Cejas finas
		mb.push_at(hc + Vector3(s * 0.15, 0.115, -0.345), Vector3(0, 0, -s * 8.0))
		mb.box(Vector3.ZERO, Vector3(0.11, 0.024, 0.03), hair)
		mb.pop()
		# Mofletes
		mb.sphere(hc + Vector3(s * 0.24, -0.13, -0.27), Vector3(0.055, 0.03, 0.03), 5, 2, Color("f29a8f"))
		# Comisuras de la sonrisa
		mb.push_at(hc + Vector3(s * 0.055, -0.165, -0.338), Vector3(0, 0, s * 25.0))
		mb.box(Vector3.ZERO, Vector3(0.05, 0.02, 0.025), Color("7a2e2e"))
		mb.pop()
	# Nariz y boca
	mb.sphere(hc + Vector3(0, -0.085, -0.365), Vector3(0.03, 0.025, 0.02), 5, 2, skin.darkened(0.12))
	mb.box(hc + Vector3(0, -0.177, -0.338), Vector3(0.07, 0.02, 0.025), Color("7a2e2e"))
	var mi := MeshInstance3D.new()
	mi.name = "HeadMesh"
	mi.mesh = mb.commit()
	head_pivot.add_child(mi)


# --- Ruedas -----------------------------------------------------------------

func _wheel_mesh(r: float, w: float) -> ArrayMesh:
	var mb := MB.new()
	var tire := _col("tire")
	var rim := _col("rim")
	mb.push_at(Vector3.ZERO, Vector3(0, 0, 90))
	# Neumático (10 caras) con dibujo
	mb.cylinder(Vector3(0, -w * 0.5, 0), r, w, 10, tire, tire.lightened(0.08))
	# Llanta a ambos lados
	mb.cylinder(Vector3(0, -w * 0.5 - 0.012, 0), r * 0.55, w + 0.024, 6, rim.darkened(0.1), rim)
	# Buje
	mb.cylinder(Vector3(0, -w * 0.5 - 0.03, 0), r * 0.18, w + 0.06, 5, _col("metal"))
	mb.pop()
	return mb.commit()


func _build_wheels() -> void:
	var front := _wheel_mesh(0.27, 0.26)
	var rear := _wheel_mesh(0.34, 0.34)
	var defs := [
		[Vector3(-0.74, 0.27, -0.88), front, true, 0.27],
		[Vector3(0.74, 0.27, -0.88), front, true, 0.27],
		[Vector3(-0.78, 0.34, 0.85), rear, false, 0.34],
		[Vector3(0.78, 0.34, 0.85), rear, false, 0.34],
	]
	for d in defs:
		var steer := Node3D.new()
		steer.position = d[0]
		add_child(steer)  # Las ruedas no se inclinan con la carrocería
		var spin := MeshInstance3D.new()
		spin.mesh = d[1]
		steer.add_child(spin)
		if d[2]:
			steer_pivots.append(steer)
		wheel_spin.append(spin)
		wheel_radius.append(d[3])
	# Ejes visibles
	var mb := MB.new()
	mb.beam(Vector3(-0.74, 0.27, -0.88), Vector3(0.74, 0.27, -0.88), 0.06, _col("metal").darkened(0.3))
	mb.beam(Vector3(-0.78, 0.34, 0.85), Vector3(0.78, 0.34, 0.85), 0.07, _col("metal").darkened(0.3))
	var axles := MeshInstance3D.new()
	axles.mesh = mb.commit()
	add_child(axles)


# --- Animación ----------------------------------------------------------------

## distance: metros recorridos este frame (con signo).
func animate(distance: float, steer_angle: float, roll: float, pitch: float, head_yaw: float,
		drift_yaw: float, delta: float) -> void:
	for i in wheel_spin.size():
		wheel_spin[i].rotate_x(-distance / wheel_radius[i])
	for p in steer_pivots:
		p.rotation.y = lerp_angle(p.rotation.y, steer_angle, minf(1.0, delta * 18.0))
	body_pivot.rotation.z = lerpf(body_pivot.rotation.z, roll, minf(1.0, delta * 8.0))
	body_pivot.rotation.x = lerpf(body_pivot.rotation.x, pitch, minf(1.0, delta * 8.0))
	head_pivot.rotation.y = lerpf(head_pivot.rotation.y, head_yaw, minf(1.0, delta * 6.0))
	rotation.y = lerp_angle(rotation.y, drift_yaw, minf(1.0, delta * 9.0))
