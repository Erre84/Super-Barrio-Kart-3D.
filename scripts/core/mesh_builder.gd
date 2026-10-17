extends RefCounted
## Generador de mallas low-poly con normales planas (facetado) y color por vértice.
## Todo el arte 3D se construye con estas primitivas: polígonos reales, sin sprites.
##
## Novedades v0.2:
##  - Varios materiales en una misma malla: `use("paint")`, `use("rubber")`...
##    (ver MATERIALS). Cada uno acaba siendo una superficie del ArrayMesh.
##  - `loft()`: une secciones (polígonos) para esculpir carrocerías con chaflanes.
##  - `lathe()`: revoluciona un perfil (neumáticos, llantas, depósitos...).
##  - Oclusión ambiental por vértice (`ao_strength`): oscurece la base de los objetos.
##
## Uso:
##   var mb := MeshBuilder.new()
##   mb.use("paint")
##   mb.box(Vector3(0, 1, 0), Vector3(2, 2, 2), Color.RED)
##   mesh_instance.mesh = mb.commit()

## Godot considera cara frontal la que se ve en sentido horario.
const FLIP_WINDING := false

const MATERIALS := {
	"default": "res://materials/lowpoly_vertex.tres",
	"glow": "res://materials/lowpoly_glow.tres",
	"paint": "res://materials/kart_paint.tres",
	"rubber": "res://materials/kart_rubber.tres",
	"metal": "res://materials/kart_metal.tres",
	"chrome": "res://materials/kart_chrome.tres",
	"skin": "res://materials/character_skin.tres",
	"cloth": "res://materials/character_cloth.tres",
}

static var _cache := {}

## Oclusión ambiental por altura: los vértices cerca del suelo se oscurecen.
var ao_strength := 0.0
var ao_height := 2.5

var _surfaces := {}            # clave de material -> SurfaceTool
var _counts := {}              # clave de material -> triángulos
var _current := "default"
var _st: SurfaceTool
var _xform := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []
var tri_count := 0


func _init() -> void:
	use("default")


# --- Materiales ---------------------------------------------------------------

static func material(key: String) -> Material:
	if not _cache.has(key):
		_cache[key] = load(MATERIALS.get(key, MATERIALS["default"]))
	return _cache[key]


static func lit_material() -> Material:
	return material("default")


static func glow_material() -> Material:
	return material("glow")


## Cambia el material de los triángulos que se añadan a continuación.
func use(key: String) -> void:
	_current = key
	if not _surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = st
		_counts[key] = 0
	_st = _surfaces[key]


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

func _shade(col: Color, p: Vector3) -> Color:
	if ao_strength <= 0.0:
		return col
	var k := 1.0 - clampf(p.y / ao_height, 0.0, 1.0)
	return col.darkened(ao_strength * k * k)


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
	# (wa, wb, wc) es antihorario visto desde fuera: lo emitimos en horario.
	var order := [wa, wb, wc] if FLIP_WINDING else [wa, wc, wb]
	for v: Vector3 in order:
		# Colores en espacio lineal: se ven igual en Compatibility, Mobile y Forward+.
		_st.set_color(_shade(col, v).srgb_to_linear())
		_st.set_normal(n)
		_st.add_vertex(v)
	tri_count += 1
	_counts[_current] += 1


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
	for i in 4:
		var j := (i + 1) % 4
		var fc: Vector3 = (p[i] + p[j] + p[i + 4] + p[j + 4]) * 0.25
		quad(p[i], p[j], p[j + 4], p[i + 4], col, fc - center)
	var top_c: Vector3 = (p[4] + p[5] + p[6] + p[7]) * 0.25
	quad(p[4], p[5], p[6], p[7], tc, top_c - center)
	if bottom:
		var bot_c: Vector3 = (p[0] + p[1] + p[2] + p[3]) * 0.25
		quad(p[0], p[1], p[2], p[3], col.darkened(0.3), bot_c - center)


## Prisma que va de un rectángulo inferior a otro superior. `base` = centro de la cara inferior.
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


## Caja con aristas achaflanadas (más "acabada" que una caja simple).
func chamfer_box(center: Vector3, size: Vector3, chamfer: float, col: Color, top_col: Variant = null) -> void:
	var c := minf(chamfer, minf(size.x, size.y) * 0.45)
	var prof := chamfer_rect(size.x, size.y, c)
	var tc: Color = col if top_col == null else top_col
	var cols := [tc, col, col, col, col.darkened(0.2), col, col, col]
	loft([_offset_profile(prof, center + Vector3(0, 0, -size.z * 0.5)),
			_offset_profile(prof, center + Vector3(0, 0, size.z * 0.5))], cols, true, true)


func _offset_profile(prof: PackedVector3Array, offset: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in prof:
		out.append(p + offset)
	return out


## Barra de sección cuadrada entre dos puntos.
func beam(p1: Vector3, p2: Vector3, thick: float, col: Color) -> void:
	var axis := p2 - p1
	if axis.length_squared() < 1e-8:
		return
	var z := axis.normalized()
	var helper := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := helper.cross(z).normalized() * thick * 0.5
	var y := z.cross(x).normalized() * thick * 0.5
	hexa([p1 - x - y, p1 + x - y, p1 + x + y, p1 - x + y,
			p2 - x - y, p2 + x - y, p2 + x + y, p2 - x + y], col)


## Tubo de sección poligonal entre dos puntos (barras, escapes, brazos).
func tube(p1: Vector3, p2: Vector3, r1: float, r2: float, segs: int, col: Color, caps: bool = true) -> void:
	var axis := p2 - p1
	if axis.length_squared() < 1e-8:
		return
	var z := axis.normalized()
	var helper := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := helper.cross(z).normalized()
	var y := z.cross(x).normalized()
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for i in segs:
		var ang := TAU * float(i) / segs
		var d := x * cos(ang) + y * sin(ang)
		a.append(p1 + d * r1)
		b.append(p2 + d * r2)
	loft([a, b], [col], caps, caps)


## Lámina con grosor entre dos puntos (hojas, carteles finos).
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


## Cilindro (o cono si r_top = 0) sobre el eje Y. `base` = centro de la base.
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


## Esfera / elipsoide facetado. lat_from/lat_to en radianes desde el polo norte.
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


# --- Herramientas de modelado -------------------------------------------------

## Rectángulo achaflanado (8 puntos) en el plano XY, centrado en el origen.
## Orden de aristas: 0 arriba, 1 chaflán sup-der, 2 derecha, 3 chaflán inf-der,
## 4 abajo, 5 chaflán inf-izq, 6 izquierda, 7 chaflán sup-izq.
static func chamfer_rect(w: float, h: float, c: float, y_center: float = 0.0) -> PackedVector3Array:
	var hw := w * 0.5
	var hh := h * 0.5
	var cc := minf(c, minf(hw, hh) * 0.95)
	return PackedVector3Array([
		Vector3(-hw + cc, y_center + hh, 0), Vector3(hw - cc, y_center + hh, 0),
		Vector3(hw, y_center + hh - cc, 0), Vector3(hw, y_center - hh + cc, 0),
		Vector3(hw - cc, y_center - hh, 0), Vector3(-hw + cc, y_center - hh, 0),
		Vector3(-hw, y_center - hh + cc, 0), Vector3(-hw, y_center + hh - cc, 0),
	])


## Sección para loft: rectángulo achaflanado colocado en z (y opcionalmente desplazado en x).
static func section(z: float, w: float, h: float, y_center: float, chamfer: float, x: float = 0.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in chamfer_rect(w, h, chamfer, y_center):
		out.append(Vector3(p.x + x, p.y, z))
	return out


## Une secciones consecutivas (mismo número de puntos) con quads.
## `cols` da el color por arista (índice % tamaño). Tapas opcionales en los extremos.
func loft(sections: Array, cols: Array, cap_start: bool = true, cap_end: bool = true) -> void:
	var ns := sections.size()
	if ns < 2:
		return
	var m: int = (sections[0] as PackedVector3Array).size()
	var centers: Array[Vector3] = []
	for s in sections:
		var c := Vector3.ZERO
		for p in (s as PackedVector3Array):
			c += p
		centers.append(c / m)
	for k in ns - 1:
		var s0: PackedVector3Array = sections[k]
		var s1: PackedVector3Array = sections[k + 1]
		var mid := (centers[k] + centers[k + 1]) * 0.5
		for i in m:
			var j := (i + 1) % m
			var col: Color = cols[i % cols.size()]
			var fc := (s0[i] + s0[j] + s1[i] + s1[j]) * 0.25
			quad(s0[i], s0[j], s1[j], s1[i], col, fc - mid)
	var axis := (centers[ns - 1] - centers[0]).normalized()
	if cap_start:
		var s0: PackedVector3Array = sections[0]
		var cap_col: Color = cols[0]
		for i in m:
			tri(centers[0], s0[i], s0[(i + 1) % m], cap_col.darkened(0.05), -axis)
	if cap_end:
		var s1: PackedVector3Array = sections[ns - 1]
		var cap_col2: Color = cols[0]
		for i in m:
			tri(centers[ns - 1], s1[i], s1[(i + 1) % m], cap_col2.darkened(0.05), axis)


## Revoluciona un perfil alrededor del eje X (ruedas). El perfil es una lista de
## Vector2(x_axial, radio) y debe ir en orden ANTIHORARIO en el plano (x, r).
## `cols[i]` colorea la banda generada por la arista i; `alt` alterna un segundo
## color por segmentos (dibujo del neumático).
func lathe(profile: PackedVector2Array, segs: int, cols: Array, alt: Dictionary = {}, closed: bool = false) -> void:
	var n := profile.size()
	var count := n if closed else n - 1
	for e in count:
		var p0 := profile[e]
		var p1 := profile[(e + 1) % n]
		var edge := p1 - p0
		var n2 := Vector2(edge.y, -edge.x)   # normal exterior para perfil antihorario
		var col: Color = cols[e % cols.size()]
		for i in segs:
			var a0 := TAU * float(i) / segs
			var a1 := TAU * float(i + 1) / segs
			var d0 := Vector3(0, cos(a0), sin(a0))
			var d1 := Vector3(0, cos(a1), sin(a1))
			var dm := (d0 + d1).normalized()
			var v00 := Vector3(p0.x, 0, 0) + d0 * p0.y
			var v01 := Vector3(p0.x, 0, 0) + d1 * p0.y
			var v10 := Vector3(p1.x, 0, 0) + d0 * p1.y
			var v11 := Vector3(p1.x, 0, 0) + d1 * p1.y
			var out := Vector3(n2.x, 0, 0) + dm * n2.y
			var c := col
			if alt.has(e) and i % 2 == 1:
				c = alt[e]
			quad(v00, v01, v11, v10, c, out)


## Tira plana horizontal a lo largo de dos polilíneas (carreteras, aceras, líneas).
func strip(left: PackedVector3Array, right: PackedVector3Array, cols: Array, closed: bool = true) -> void:
	var n := left.size()
	var count := n if closed else n - 1
	for i in count:
		var j := (i + 1) % n
		var col: Color = cols[i % cols.size()]
		quad(left[i], left[j], right[j], right[i], col, Vector3.UP)


## Construye el ArrayMesh. Si se pasa `override`, todas las superficies lo usan.
func commit(override: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in _surfaces:
		if _counts[key] == 0:
			continue
		var st: SurfaceTool = _surfaces[key]
		var before := mesh.get_surface_count()
		st.commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_material(before, override if override != null else material(key))
	return mesh


## Construye un ArrayMesh de UNA sola superficie con el material `key` (los colores van en
## los vértices). Una superficie = una llamada de dibujo: ideal para piezas pequeñas.
func commit_single(key: String = "paint") -> ArrayMesh:
	var tmp := commit()
	return merge_surfaces([[tmp, Transform3D.IDENTITY]], material(key))


## Une las superficies de varias mallas (cada una con su transformación) agrupándolas por
## material: devuelve una malla con una superficie por material distinto. Con `single`,
## todas van a una única superficie con ese material.
static func merge_surfaces(items: Array, single: Material = null) -> ArrayMesh:
	var groups := {}     # material -> SurfaceTool
	var order := []
	for it in items:
		var m: Mesh = it[0]
		var xf: Transform3D = it[1]
		for i in m.get_surface_count():
			var mat: Material = single if single != null else m.surface_get_material(i)
			if not groups.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[mat] = st
				order.append(mat)
			(groups[mat] as SurfaceTool).append_from(m, i, xf)
	var out := ArrayMesh.new()
	for mat in order:
		var before := out.get_surface_count()
		(groups[mat] as SurfaceTool).commit(out)
		if out.get_surface_count() > before:
			out.surface_set_material(before, mat)
	return out


func is_empty() -> bool:
	return tri_count == 0
