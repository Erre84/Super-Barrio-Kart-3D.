extends RefCounted
## Generador de mallas low-poly con normales planas (facetado) y color por vértice.
## Todo el arte 3D de esta primera versión se construye con estas primitivas,
## así no hay sprites ni texturas: polígonos reales con colores planos.
##
## Uso:
##   var mb := MeshBuilder.new()
##   mb.box(Vector3(0, 1, 0), Vector3(2, 2, 2), Color.RED)
##   mesh_instance.mesh = mb.commit()

## Godot considera cara frontal la que se ve en sentido horario.
const FLIP_WINDING := false

static var _mat_lit: StandardMaterial3D
static var _mat_glow: StandardMaterial3D

var _st := SurfaceTool.new()
var _xform := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []
var tri_count := 0


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


# --- Materiales compartidos -------------------------------------------------

static func lit_material() -> StandardMaterial3D:
	if _mat_lit == null:
		_mat_lit = load("res://materials/lowpoly_vertex.tres")
	return _mat_lit


static func glow_material() -> StandardMaterial3D:
	if _mat_glow == null:
		_mat_glow = load("res://materials/lowpoly_glow.tres")
	return _mat_glow


# --- Pila de transformaciones ----------------------------------------------

func push(t: Transform3D) -> void:
	_stack.push_back(_xform)
	_xform = _xform * t


func push_at(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl)
	push(Transform3D(b, pos))


func pop() -> void:
	_xform = _stack.pop_back()


# --- Primitivas básicas -----------------------------------------------------

## Triángulo. `outward` indica hacia dónde mira la cara (en espacio local).
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, outward: Vector3) -> void:
	var wa := _xform * a
	var wb := _xform * b
	var wc := _xform * c
	var n := (wb - wa).cross(wc - wa)
	if n.length_squared() < 1e-14:
		return
	if n.dot(_xform.basis * outward) < 0.0:
		var t := wb
		wb = wc
		wc = t
		n = -n
	n = n.normalized()
	# Los colores se escriben en espacio lineal: así se ven igual en Compatibility,
	# Mobile y Forward+ (el material no hace conversión sRGB por vértice).
	_st.set_color(col.srgb_to_linear())
	_st.set_normal(n)
	# (wa, wb, wc) es antihorario visto desde fuera: lo emitimos en horario.
	if FLIP_WINDING:
		_st.add_vertex(wa)
		_st.add_vertex(wb)
		_st.add_vertex(wc)
	else:
		_st.add_vertex(wa)
		_st.add_vertex(wc)
		_st.add_vertex(wb)
	tri_count += 1


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, outward: Vector3) -> void:
	tri(a, b, c, col, outward)
	tri(a, c, d, col, outward)


## Hexaedro convexo a partir de 8 puntos: 0-3 abajo, 4-7 arriba, mismo orden.
func hexa(p: Array, col: Color, top_col: Variant = null, bottom: bool = true) -> void:
	var center := Vector3.ZERO
	for v in p:
		center += v
	center /= 8.0
	var tc: Color = col if top_col == null else top_col
	# Lados
	for i in 4:
		var j := (i + 1) % 4
		var fc: Vector3 = (p[i] + p[j] + p[i + 4] + p[j + 4]) * 0.25
		quad(p[i], p[j], p[j + 4], p[i + 4], col, fc - center)
	# Tapa superior
	var top_c: Vector3 = (p[4] + p[5] + p[6] + p[7]) * 0.25
	quad(p[4], p[5], p[6], p[7], tc, top_c - center)
	if bottom:
		var bot_c: Vector3 = (p[0] + p[1] + p[2] + p[3]) * 0.25
		quad(p[0], p[1], p[2], p[3], col.darkened(0.3), bot_c - center)


## Prisma que va de un rectángulo inferior a otro superior (sirve para cajas y troncos de pirámide).
## `base` es el centro de la cara inferior.
func frustum(base: Vector3, bottom: Vector2, top: Vector2, h: float, col: Color,
		top_shift: Vector2 = Vector2.ZERO, top_col: Variant = null, with_bottom: bool = true) -> void:
	var bx := bottom.x * 0.5
	var bz := bottom.y * 0.5
	var tx := top.x * 0.5
	var tz := top.y * 0.5
	var ts := Vector3(top_shift.x, h, top_shift.y)
	var p := [
		base + Vector3(-bx, 0, -bz), base + Vector3(bx, 0, -bz),
		base + Vector3(bx, 0, bz), base + Vector3(-bx, 0, bz),
		base + ts + Vector3(-tx, 0, -tz), base + ts + Vector3(tx, 0, -tz),
		base + ts + Vector3(tx, 0, tz), base + ts + Vector3(-tx, 0, tz),
	]
	hexa(p, col, top_col, with_bottom)


## Caja centrada en `center`.
func box(center: Vector3, size: Vector3, col: Color, top_col: Variant = null, with_bottom: bool = true) -> void:
	frustum(center - Vector3(0, size.y * 0.5, 0), Vector2(size.x, size.z), Vector2(size.x, size.z),
			size.y, col, Vector2.ZERO, top_col, with_bottom)


## Barra de sección cuadrada entre dos puntos (brazos, postes inclinados...).
func beam(p1: Vector3, p2: Vector3, thick: float, col: Color) -> void:
	var axis := p2 - p1
	if axis.length_squared() < 1e-8:
		return
	var z := axis.normalized()
	var helper := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := helper.cross(z).normalized() * thick * 0.5
	var y := z.cross(x).normalized() * thick * 0.5
	var p := [
		p1 - x - y, p1 + x - y, p1 + x + y, p1 - x + y,
		p2 - x - y, p2 + x - y, p2 + x + y, p2 - x + y,
	]
	hexa(p, col)


## Lámina con grosor entre dos puntos (hojas de palmera, carteles finos).
## `up_hint` orienta la cara ancha; w1/w2 son las anchuras en cada extremo.
func slab(p1: Vector3, p2: Vector3, w1: float, w2: float, thick: float, col: Color,
		up_hint: Vector3 = Vector3.UP) -> void:
	var axis := p2 - p1
	if axis.length_squared() < 1e-8:
		return
	var z := axis.normalized()
	var side := up_hint.cross(z)
	if side.length_squared() < 1e-6:
		side = Vector3.RIGHT.cross(z)
	side = side.normalized()
	var up := z.cross(side).normalized() * thick * 0.5
	var s1 := side * w1 * 0.5
	var s2 := side * w2 * 0.5
	hexa([
		p1 - s1 - up, p1 + s1 - up, p2 + s2 - up, p2 - s2 - up,
		p1 - s1 + up, p1 + s1 + up, p2 + s2 + up, p2 - s2 + up,
	], col)


## Cilindro (o cono si r_top = 0) sobre el eje Y. `base` es el centro de la base.
func cylinder(base: Vector3, r: float, h: float, segs: int, col: Color,
		cap_col: Variant = null, r_top: float = -1.0, caps: bool = true) -> void:
	var rt := r if r_top < 0.0 else r_top
	var cc: Color = col if cap_col == null else cap_col
	var top := base + Vector3(0, h, 0)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var mid := (d0 + d1).normalized()
		var b0 := base + d0 * r
		var b1 := base + d1 * r
		var t0 := top + d0 * rt
		var t1 := top + d1 * rt
		var out := mid + Vector3(0, (r - rt) / maxf(h, 0.001), 0)
		quad(b0, b1, t1, t0, col, out)
		if caps:
			if rt > 0.0:
				tri(top, t0, t1, cc, Vector3.UP)
			tri(base, b1, b0, cc.darkened(0.25), Vector3.DOWN)


## Esfera / elipsoide facetado. lat_from/lat_to en radianes desde el polo norte (0) al sur (PI).
func sphere(center: Vector3, radius: Vector3, lon: int, lat: int, col: Color,
		lat_from: float = 0.0, lat_to: float = PI) -> void:
	for j in lat:
		var th0 := lerpf(lat_from, lat_to, float(j) / lat)
		var th1 := lerpf(lat_from, lat_to, float(j + 1) / lat)
		for i in lon:
			var ph0 := TAU * float(i) / lon
			var ph1 := TAU * float(i + 1) / lon
			var a := center + _sph(th0, ph0) * radius
			var b := center + _sph(th0, ph1) * radius
			var c := center + _sph(th1, ph1) * radius
			var d := center + _sph(th1, ph0) * radius
			var fc := (a + b + c + d) * 0.25
			quad(a, b, c, d, col, fc - center)
	# Cierra la semiesfera si se corta antes del polo sur
	if lat_to < PI - 0.01:
		var y := cos(lat_to) * radius.y
		var cap_c := center + Vector3(0, y, 0)
		for i in lon:
			var ph0 := TAU * float(i) / lon
			var ph1 := TAU * float(i + 1) / lon
			tri(cap_c, center + _sph(lat_to, ph0) * radius, center + _sph(lat_to, ph1) * radius,
					col.darkened(0.2), Vector3.DOWN)


func _sph(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


## Tira plana horizontal a lo largo de dos polilíneas (carreteras, aceras, líneas pintadas).
func strip(left: PackedVector3Array, right: PackedVector3Array, cols: Array, closed: bool = true) -> void:
	var n := left.size()
	var count := n if closed else n - 1
	for i in count:
		var j := (i + 1) % n
		var col: Color = cols[i % cols.size()]
		quad(left[i], left[j], right[j], right[i], col, Vector3.UP)


func commit(material: Material = null) -> ArrayMesh:
	var mesh := _st.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material if material != null else lit_material())
	return mesh


func is_empty() -> bool:
	return tri_count == 0
