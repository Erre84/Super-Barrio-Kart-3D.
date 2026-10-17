extends Node3D
## Circuito urbano "El Prat — Avinguda del Riu" (primer tramo, ~970 m).
##
## El trazado se define con unos pocos puntos de control (CONTROL_POINTS) que se
## interpolan con Catmull-Rom y se remuestrean cada 2 m. A partir de esa línea
## central se genera todo: asfalto, bordillos, arcén, muros con colisión, aceras,
## edificios, mobiliario urbano y obstáculos. Para retocar el circuito basta con
## mover los puntos de control.

const MB := preload("res://scripts/core/mesh_builder.gd")
const Props := preload("res://scripts/track/props.gd")
const Landmarks := preload("res://scripts/track/landmarks.gd")

## Sentido de carrera: horario visto desde arriba. La recta de salida va hacia -Z.
const CONTROL_POINTS := [
	Vector2(0, 60), Vector2(0, -150), Vector2(8, -182), Vector2(36, -194),       # recta de salida y curva de 90°
	Vector2(130, -194), Vector2(164, -184), Vector2(174, -156), Vector2(172, -114), # calle norte (obras)
	Vector2(162, -96), Vector2(144, -88), Vector2(140, -68), Vector2(154, -54),     # chicane
	Vector2(190, -44), Vector2(206, -14), Vector2(206, 72), Vector2(196, 98),       # Avinguda (isletas)
	Vector2(172, 104), Vector2(150, 94), Vector2(128, 86), Vector2(110, 96),        # "ese" del mercado
	Vector2(100, 118), Vector2(70, 130), Vector2(26, 128), Vector2(6, 108),         # vuelta a meta
]
const STEP := 2.0
const ROAD_HALF := 8.0
const CURB_OUT := 9.2
const WALL := 12.0
const WALL_TOP := 12.6
const WALK_OUT := 17.0
const PLAZA := Vector3(80, 0, -62)

var points := PackedVector3Array()
var dirs := PackedVector3Array()
var lefts := PackedVector3Array()
var curv := PackedFloat32Array()
var cum := PackedFloat32Array()
var length := 0.0
var boost_pads: Array = []    # [{pos, dir, left}]
## Tramos con obstáculos: [índice inicial, índice final, lado libre (+izq/-der)].
## Lo usa el piloto automático de pruebas; también sirve de documentación.
var avoid_zones: Array = []
var _last_idx := 0
var _rng := RandomNumberGenerator.new()
var _occupied: Array = []     # [Vector3 centro, radio] para no solapar escenario


func build() -> void:
	_rng.seed = 20261017
	_sample_centerline()
	_build_ground()
	_build_road()
	_build_walls()
	_build_start()
	_build_boost_pads()
	_build_obstacles()
	_build_landmarks()
	_build_city()
	_build_skyline()


# =============================================================================
# Línea central
# =============================================================================

func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _sample_centerline() -> void:
	var dense: Array[Vector2] = []
	var n := CONTROL_POINTS.size()
	for i in n:
		var p0: Vector2 = CONTROL_POINTS[(i - 1 + n) % n]
		var p1: Vector2 = CONTROL_POINTS[i]
		var p2: Vector2 = CONTROL_POINTS[(i + 1) % n]
		var p3: Vector2 = CONTROL_POINTS[(i + 2) % n]
		for k in 60:
			dense.append(_catmull(p0, p1, p2, p3, k / 60.0))
	# Remuestreo por longitud de arco
	var total := 0.0
	for i in dense.size():
		total += dense[i].distance_to(dense[(i + 1) % dense.size()])
	var count := int(round(total / STEP))
	var step := total / count
	var out: Array[Vector2] = [dense[0]]
	var acc := 0.0
	var next := step
	for i in dense.size():
		var a := dense[i]
		var b := dense[(i + 1) % dense.size()]
		var seg := a.distance_to(b)
		while acc + seg >= next and out.size() < count:
			out.append(a.lerp(b, (next - acc) / seg))
			next += step
		acc += seg
	length = total
	points.resize(count)
	dirs.resize(count)
	lefts.resize(count)
	cum.resize(count)
	curv.resize(count)
	for i in count:
		points[i] = Vector3(out[i].x, 0.0, out[i].y)
		cum[i] = i * step
	for i in count:
		var d := (points[(i + 1) % count] - points[(i - 1 + count) % count]).normalized()
		dirs[i] = d
		lefts[i] = Vector3.UP.cross(d)
	# Curvatura con signo (+ = gira a la izquierda), suavizada
	for i in count:
		var a := dirs[(i - 3 + count) % count]
		var b := dirs[(i + 3) % count]
		var ang := a.signed_angle_to(b, Vector3.UP)
		curv[i] = ang / (6.0 * step)


## Punto desplazado lateralmente (+ izquierda). En el interior de curvas cerradas
## se recorta para que las tiras no se crucen.
func edge(i: int, offset: float, y: float = 0.0) -> Vector3:
	var o := offset
	var k := curv[i]
	if absf(k) > 1e-4 and k * o > 0.0:
		var lim := 0.85 / absf(k)
		o = clampf(o, -lim, lim)
	return points[i] + lefts[i] * o + Vector3(0, y, 0)


func _edge_line(offset: float, y: float) -> PackedVector3Array:
	var arr := PackedVector3Array()
	arr.resize(points.size())
	for i in points.size():
		arr[i] = edge(i, offset, y)
	return arr


# =============================================================================
# Consultas para el juego
# =============================================================================

## Devuelve índice más cercano, desplazamiento lateral y si está sobre asfalto.
func query(pos: Vector3) -> Dictionary:
	var n := points.size()
	var best := _last_idx
	var best_d := INF
	for k in range(-30, 31):
		var i := (_last_idx + k + n) % n
		var d := Vector2(pos.x - points[i].x, pos.z - points[i].z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	if best_d > 900.0:  # nos hemos perdido: búsqueda completa
		for i in n:
			var d := Vector2(pos.x - points[i].x, pos.z - points[i].z).length_squared()
			if d < best_d:
				best_d = d
				best = i
	_last_idx = best
	var lateral := (pos - points[best]).dot(lefts[best])
	return {
		"index": best,
		"lateral": lateral,
		"on_road": absf(lateral) < ROAD_HALF + 0.6,
		"progress": cum[best] / length,
		"dir": dirs[best],
	}


func query_stateless(pos: Vector3) -> Dictionary:
	var saved := _last_idx
	var r := query(pos)
	_last_idx = saved
	return r


func start_transform(slot: int = 0) -> Transform3D:
	var i := 4 + slot * 3
	var t := Transform3D(Basis.looking_at(dirs[i], Vector3.UP), points[i] + Vector3(0, 0.05, 0))
	t.origin += lefts[i] * (2.5 if slot % 2 == 0 else -2.5)
	return t


func respawn_transform(pos: Vector3) -> Transform3D:
	var info := query_stateless(pos)
	var i: int = info["index"]
	var lat := clampf(info["lateral"], -ROAD_HALF + 2.0, ROAD_HALF - 2.0)
	# Nunca reaparecer encima de una isleta o de las obras: usar el carril libre
	var n := points.size()
	for z in avoid_zones:
		if posmod(i - int(z[0]), n) <= int(z[1]) - int(z[0]):
			lat = float(z[2])
	return Transform3D(Basis.looking_at(dirs[i], Vector3.UP), points[i] + lefts[i] * lat + Vector3(0, 0.4, 0))


func is_on_boost_pad(pos: Vector3) -> bool:
	for pad in boost_pads:
		var local: Vector3 = pos - pad["pos"]
		if absf(local.dot(pad["dir"])) < 2.4 and absf(local.dot(pad["left"])) < 2.0:
			return true
	return false


func minimap_points() -> PackedVector2Array:
	var arr := PackedVector2Array()
	for i in range(0, points.size(), 3):
		arr.append(Vector2(points[i].x, points[i].z))
	return arr


# =============================================================================
# Geometría
# =============================================================================

func _add_mesh(mb, node_name: String, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mb.commit(MB.glow_material() if glow else null)
	add_child(mi)
	return mi


func _build_ground() -> void:
	var mb := MB.new()
	var s := 1400.0
	mb.quad(Vector3(-s, -0.03, -s), Vector3(s, -0.03, -s), Vector3(s, -0.03, s), Vector3(-s, -0.03, s),
			Color("a7a978"), Vector3.UP)
	# Parque del interior (césped) alrededor de la plaza
	mb.cylinder(PLAZA + Vector3(0, -0.03, 0), 46.0, 0.04, 16, Color("7fb069"), Color("7fb069"), -1.0)
	# Plaza enlosada
	mb.cylinder(PLAZA + Vector3(0, -0.03, 0), 15.0, 0.08, 16, Color("e3d5b8"), Color("e3d5b8"), -1.0)
	var mi := _add_mesh(mb, "Ground")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)


func _build_road() -> void:
	var n := points.size()
	var mb := MB.new()
	# Asfalto con parches de tono para dar textura sin texturas
	var asphalt_a := Color("474b55")
	var asphalt_b := Color("4e525c")
	var road_cols: Array = []
	for i in n:
		road_cols.append(asphalt_a if (i / 6) % 2 == 0 else asphalt_b)
	mb.strip(_edge_line(ROAD_HALF, 0.03), _edge_line(-ROAD_HALF, 0.03), road_cols)
	# Arcén de tierra (fuera de pista: frena)
	var dirt := [Color("b89d6c"), Color("b0956a")]
	mb.strip(_edge_line(WALL, 0.02), _edge_line(CURB_OUT, 0.02), dirt)
	mb.strip(_edge_line(-CURB_OUT, 0.02), _edge_line(-WALL, 0.02), dirt)
	# Bordillos rojo/blanco
	var curb := [Color("e63946"), Color("f5f5f5")]
	mb.strip(_edge_line(CURB_OUT, 0.06), _edge_line(ROAD_HALF, 0.06), curb)
	mb.strip(_edge_line(-ROAD_HALF, 0.06), _edge_line(-CURB_OUT, 0.06), curb)
	# Aceras de baldosa más allá del muro
	var tiles := [Color("dccdab"), Color("d2c29f")]
	mb.strip(_edge_line(WALK_OUT, 0.14), _edge_line(WALL_TOP, 0.14), tiles)
	mb.strip(_edge_line(-WALL_TOP, 0.14), _edge_line(-WALK_OUT, 0.14), tiles)
	for side: float in [1.0, -1.0]:
		for i in n:
			var j := (i + 1) % n
			var a := edge(i, side * WALK_OUT, 0.14)
			var b := edge(j, side * WALK_OUT, 0.14)
			mb.quad(a, b, b - Vector3(0, 0.17, 0), a - Vector3(0, 0.17, 0), Color("a4a4a4"), lefts[i] * side)
	# Líneas pintadas: bordes continuos y eje discontinuo
	var white := [Color("f2f2f2")]
	mb.strip(_edge_line(ROAD_HALF - 0.35, 0.045), _edge_line(ROAD_HALF - 0.6, 0.045), white)
	mb.strip(_edge_line(-ROAD_HALF + 0.6, 0.045), _edge_line(-ROAD_HALF + 0.35, 0.045), white)
	for i in range(0, n, 4):
		var j := (i + 2) % n
		mb.quad(edge(i, 0.13, 0.045), edge(j, 0.13, 0.045), edge(j, -0.13, 0.045), edge(i, -0.13, 0.045),
				Color("f2f2f2"), Vector3.UP)
	# Pasos de cebra en dos puntos del barrio
	for p in [Vector2(118, -194), Vector2(56, 129)]:
		_zebra(mb, _find_index(p))
	var mi := _add_mesh(mb, "Road")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _zebra(mb, idx: int) -> void:
	var d := dirs[idx]
	var l := lefts[idx]
	var c := points[idx] + Vector3(0, 0.05, 0)
	var x := -ROAD_HALF + 1.2
	while x < ROAD_HALF - 1.0:
		var p := c + l * x
		mb.quad(p - d * 1.6, p - d * 1.6 + l * 0.55, p + d * 1.6 + l * 0.55, p + d * 1.6, Color.WHITE, Vector3.UP)
		x += 1.1


func _build_walls() -> void:
	var n := points.size()
	var mb := MB.new()
	var concrete := Color("ddd8cc")
	var graffiti := [Color("ff5d8f"), Color("3ec1d3"), Color("ffd23f"), Color("8e7dff"), Color("54d17a")]
	var faces := PackedVector3Array()
	for side: float in [1.0, -1.0]:
		for i in n:
			var j := (i + 1) % n
			# Perfil tipo New Jersey: cara interior inclinada, techo, cara exterior
			var a0 := edge(i, side * WALL, 0.0)
			var b0 := edge(j, side * WALL, 0.0)
			var a1 := edge(i, side * (WALL + 0.25), 0.9)
			var b1 := edge(j, side * (WALL + 0.25), 0.9)
			var a2 := edge(i, side * WALL_TOP, 0.9)
			var b2 := edge(j, side * WALL_TOP, 0.9)
			var a3 := edge(i, side * WALL_TOP, 0.0)
			var b3 := edge(j, side * WALL_TOP, 0.0)
			var inward := -lefts[i] * side
			var block := i / 4
			var col := concrete
			if (block + (1 if side > 0 else 3)) % 7 == 0:
				col = graffiti[(block / 7 + (0 if side > 0 else 2)) % graffiti.size()]
			mb.quad(a0, b0, b1, a1, col, inward + Vector3(0, 0.3, 0))
			mb.quad(a1, b1, b2, a2, col.darkened(0.08) if col == concrete else Color("f4f4f4"), Vector3.UP)
			mb.quad(a2, b2, b3, a3, concrete.darkened(0.12), -inward)
			# Colisión: muro vertical algo más alto que el visual para que nadie salte por encima
			var c0 := edge(i, side * WALL, -1.0)
			var c1 := edge(j, side * WALL, -1.0)
			var c2 := edge(j, side * WALL, 3.0)
			var c3 := edge(i, side * WALL, 3.0)
			faces.append_array([c0, c1, c2, c0, c2, c3])
	_add_mesh(mb, "Barriers")
	var body := StaticBody3D.new()
	body.name = "WallsBody"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _build_start() -> void:
	var mb := MB.new()
	var i := 0
	var d := dirs[i]
	var l := lefts[i]
	var c := points[i] + Vector3(0, 0.05, 0)
	# Línea de meta a cuadros
	var cols := 16
	var cell := (ROAD_HALF * 2.0) / cols
	for row in 2:
		for k in cols:
			var p := c + l * (-ROAD_HALF + k * cell) + d * (row * cell - cell)
			var col := Color("111111") if (k + row) % 2 == 0 else Color("f5f5f5")
			mb.quad(p, p + l * cell, p + l * cell + d * cell, p + d * cell, col, Vector3.UP)
	# Casillas de salida
	for slot in 4:
		var t := start_transform(slot)
		var o := t.origin + Vector3(0, 0.05, 0)
		var f := -t.basis.z
		var r := t.basis.x
		mb.quad(o - f * 1.6 - r * 1.1, o - f * 1.6 + r * 1.1, o - f * 1.45 + r * 1.1, o - f * 1.45 - r * 1.1,
				Color.WHITE, Vector3.UP)
	# Arco de salida
	var red := Color("e63946")
	var yellow := Color("ffd23f")
	for s: float in [-1.0, 1.0]:
		var base := points[i] + l * s * (WALL_TOP + 0.9)
		mb.box(base + Vector3(0, 3.6, 0), Vector3(1.3, 7.2, 1.3), red, yellow)
		mb.box(base + Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 1.8), Color("2d3436"))
	var span := (WALL_TOP + 0.9) * 2.0 + 1.3
	mb.push(Transform3D(Basis.looking_at(d, Vector3.UP), points[i] + Vector3(0, 7.9, 0)))
	mb.box(Vector3.ZERO, Vector3(span, 1.8, 0.7), yellow, red)
	mb.box(Vector3(0, -1.0, 0), Vector3(span, 0.25, 0.75), red)
	mb.pop()
	_add_mesh(mb, "StartArch")
	for flip: float in [0.0, PI]:
		var lbl := Label3D.new()
		lbl.text = "EL PRAT  ·  SUPER BARRIO KART"
		lbl.font_size = 96
		lbl.pixel_size = 0.012
		lbl.outline_size = 18
		lbl.modulate = Color("e63946")
		lbl.outline_modulate = Color("ffffff")
		lbl.double_sided = false
		var basis := Basis.looking_at(d if flip == 0.0 else -d, Vector3.UP)
		lbl.transform = Transform3D(basis, points[i] + Vector3(0, 7.95, 0) + (-d if flip == 0.0 else d) * 0.38)
		add_child(lbl)


func _build_boost_pads() -> void:
	var n := points.size()
	var mb := MB.new()
	for spec in [[int(n * 0.07), 0.0], [_find_index(Vector2(150, -194)), 0.0], [_find_index(Vector2(206, 62)), 3.5]]:
		var i: int = spec[0]
		var c := points[i] + lefts[i] * float(spec[1]) + Vector3(0, 0.055, 0)
		var d := dirs[i]
		var l := lefts[i]
		boost_pads.append({"pos": c, "dir": d, "left": l})
		mb.quad(c - d * 2.4 - l * 2.0, c - d * 2.4 + l * 2.0, c + d * 2.4 + l * 2.0, c + d * 2.4 - l * 2.0,
				Color("ff7b00"), Vector3.UP)
		for k in 3:
			var tip := c + d * (-1.0 + k * 1.3) + Vector3(0, 0.01, 0)
			mb.quad(tip + d * 0.9, tip - l * 1.5, tip - l * 1.5 - d * 0.6, tip + d * 0.3, Color("ffe14d"), Vector3.UP)
			mb.quad(tip + d * 0.9, tip + d * 0.3, tip + l * 1.5 - d * 0.6, tip + l * 1.5, Color("ffe14d"), Vector3.UP)
	_add_mesh(mb, "BoostPads", true)


# =============================================================================
# Obstáculos con colisión
# =============================================================================

func _static_body(node_name: String, pos: Vector3, shape: Shape3D, shape_offset: Vector3, mesh: Mesh, rot_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = shape_offset
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
	return body


func _build_obstacles() -> void:
	var n := points.size()
	var holder := Node3D.new()
	holder.name = "Obstacles"
	add_child(holder)

	# 1) Isletas con palmera en la recta de la Avinguda (dividen la calzada)
	var isle_a := _find_index(Vector2(206, 12))
	var isle_b := _find_index(Vector2(206, 42))
	avoid_zones.append([isle_a - 4, isle_b + 4, 4.5])
	for i in [isle_a, isle_b]:
		var mb := MB.new()
		Props.planter(mb, _rng, 1.5)
		var cyl := CylinderShape3D.new()
		cyl.radius = 1.5
		cyl.height = 3.0
		_static_body("Planter", points[i], cyl, Vector3(0, 1.5, 0), mb.commit())
		_occupied.append([points[i], 2.0])

	# 2) Zona de obras en el carril izquierdo: barreras de plástico + conos sueltos
	var works := _find_index(Vector2(66, -194))
	avoid_zones.append([works - 10, works + 26, -4.0])
	var barrier_mb := MB.new()
	Props.plastic_barrier(barrier_mb, 2.0)
	var barrier_mesh := barrier_mb.commit()
	for k in 6:
		var i := (works + k * 2) % n
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 0.9, 0.6)
		var yaw := atan2(-dirs[i].x, -dirs[i].z) + PI * 0.5
		_static_body("Barrier", points[i] + lefts[i] * 5.0, box, Vector3(0, 0.45, 0), barrier_mesh, yaw)
	var cone_mb := MB.new()
	Props.traffic_cone(cone_mb)
	var cone_mesh := cone_mb.commit()
	var cone_spots: Array = []
	for k in 7:
		cone_spots.append([(works - 8 + k) % n, 1.5 + k * 0.5])     # embudo antes de las obras
	for k in 6:
		cone_spots.append([(works + 13 + k * 2) % n, 3.0])
	# Conos en el vértice de la chicane
	var chicane := _find_index(Vector2(146, -88))
	for k in 5:
		cone_spots.append([(chicane - 2 + k) % n, signf(curv[chicane]) * 8.6])
	for spot in cone_spots:
		var i: int = spot[0]
		_spawn_cone(holder, points[i] + lefts[i] * float(spot[1]), cone_mesh)

	# 3) Bolardos en el arcén de las curvas rápidas
	var bol_mb := MB.new()
	Props.bollard(bol_mb)
	var bol_mesh := bol_mb.commit()
	for idx in [_find_index(Vector2(8, -182)), _find_index(Vector2(196, 98))]:
		for k in range(-6, 7, 2):
			var i: int = (idx + k + n) % n
			var side := signf(curv[i]) if absf(curv[i]) > 1e-3 else 1.0
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.16
			cyl.height = 0.9
			_static_body("Bollard", edge(i, side * 10.8), cyl, Vector3(0, 0.45, 0), bol_mesh)


func _spawn_cone(parent: Node, pos: Vector3, mesh: Mesh) -> void:
	var rb := RigidBody3D.new()
	rb.name = "Cone"
	rb.mass = 2.0
	rb.position = pos + Vector3(0, 0.02, 0)
	rb.add_to_group("knockable")
	rb.set_meta("start", rb.position)
	# Capa propia (3): el kart NO choca físicamente con los conos (si no, se sube
	# encima como a una rampa y sale volando). El kart los detecta por cercanía y
	# los lanza él. Los conos sí chocan con el suelo, los muros y entre sí.
	rb.collision_layer = 4
	rb.collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.22
	shape.height = 0.68
	cs.shape = shape
	cs.position = Vector3(0, 0.34, 0)
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	rb.add_child(mi)
	rb.can_sleep = true
	rb.sleeping = true
	parent.add_child(rb)


func _find_index(p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in points.size():
		var d := Vector2(points[i].x, points[i].z).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


# =============================================================================
# Ciudad
# =============================================================================

func _clear_of_track(c: Vector3, radius: float, margin: float) -> bool:
	# Río Llobregat (franja oeste) y recinto del aeropuerto (sur)
	if absf(c.x - (-84.0)) < 13.0 + 11.0 + radius:
		return false
	if c.z + radius > FENCE_Z - 2.0:
		return false
	var lim := WALK_OUT + margin + radius
	var lim2 := lim * lim
	for i in range(0, points.size(), 2):
		if Vector2(c.x - points[i].x, c.z - points[i].z).length_squared() < lim2:
			return false
	for o in _occupied:
		var oc: Vector3 = o[0]
		var orad: float = o[1]
		if Vector2(c.x - oc.x, c.z - oc.z).length() < radius + orad + 1.5:
			return false
	return true


func _build_city() -> void:
	var n := points.size()
	var mb := MB.new()
	var glow := MB.new()
	var signs: Array = []

	# Plaza de la Carxofa en el infield
	mb.push_at(PLAZA, Vector3.ZERO, Vector3(1.6, 1.6, 1.6))
	Props.artichoke(mb)
	mb.pop()
	_occupied.append([PLAZA, 16.0])
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		var p := PLAZA + Vector3(cos(a), 0, sin(a)) * 12.5
		mb.push_at(p, Vector3(0, -rad_to_deg(a) + 90, 0))
		Props.bench(mb)
		mb.pop()
	signs.append([PLAZA + Vector3(0, 14.0, 0), "PLAÇA DE LA CARXOFA", Color("7d4f9e"), 0.0, true])

	# Mobiliario en las aceras: farolas y palmeras alternas
	for i in range(0, n, 13):
		for side: float in [1.0, -1.0]:
			if absf(curv[i]) > 0.035 and curv[i] * side > 0:
				continue
			var p := edge(i, side * (WALL_TOP + 1.6))
			var face := -lefts[i] * side   # hacia la carretera
			var yaw := rad_to_deg(atan2(-face.z, face.x))
			if (i / 13) % 2 == 0:
				mb.push_at(p, Vector3(0, yaw, 0))
				glow.push_at(p, Vector3(0, yaw, 0))
				Props.streetlamp(mb, glow)
				glow.pop()
				mb.pop()
			else:
				var pp := edge(i, side * (WALL_TOP + 2.8))
				mb.push_at(pp)
				Props.palm(mb, _rng, _rng.randf_range(7.0, 10.0))
				mb.pop()
				_occupied.append([pp, 2.0])

	# Marquesinas y vallas publicitarias
	var ads := [
		["BAR CAN PEP · ESMORZARS", Color("ffd23f")],
		["CARXOFA DEL PRAT", Color("7bb35a")],
		["POLLASTRE POTA BLAVA", Color("3d7be0")],
		["DELTA DEL LLOBREGAT", Color("3ec1d3")],
		["SUPER BARRIO KART 3D", Color("e63946")],
	]
	var ad_idx := [int(n * 0.12), int(n * 0.31), int(n * 0.5), int(n * 0.72), int(n * 0.9)]
	for k in ad_idx.size():
		var i: int = ad_idx[k]
		var side := 1.0 if curv[i] < 0 else -1.0  # en el exterior de la curva
		var p := edge(i, side * (WALL_TOP + 3.5))
		var face := -lefts[i] * side
		var b := Basis.looking_at(-face, Vector3.UP)
		mb.push(Transform3D(b, p))
		Props.billboard(mb, ads[k][1])
		mb.pop()
		_occupied.append([p, 4.0])
		signs.append([p + Vector3(0, 4.6, 0) + face * 0.2, ads[k][0], Color("1d2135"), atan2(face.x, face.z), false])
	for i in [int(n * 0.2), int(n * 0.78)]:
		var side := 1.0 if curv[i] <= 0 else -1.0
		var p := edge(i, side * (WALL_TOP + 2.2))
		mb.push(Transform3D(Basis.looking_at(-lefts[i] * side, Vector3.UP), p))
		Props.bus_stop(mb)
		mb.pop()
		_occupied.append([p, 2.5])

	# Bloques de pisos a ambos lados del trazado, mirando a la calle
	var placed := 0
	for i in range(0, n, 5):
		for side: float in [1.0, -1.0]:
			var w := _rng.randf_range(12.0, 20.0)
			var dd := _rng.randf_range(10.0, 14.0)
			var floors := _rng.randi_range(2, 6)
			var radius := Vector2(w, dd).length() * 0.5
			var c := points[i] + lefts[i] * side * (WALK_OUT + 1.5 + radius)
			if not _clear_of_track(c, radius, 0.5) or c.distance_to(PLAZA) < 52.0 + radius:
				continue
			var face := -lefts[i] * side
			_place_apartment(mb, glow, c, face, w, dd, floors)
			placed += 1
	# Manzanas de relleno (interior y alrededores) para que el barrio se vea denso
	for gx in range(-90, 300, 24):
		for gz in range(-300, 230, 24):
			var c := Vector3(gx + _rng.randf_range(-5, 5), 0, gz + _rng.randf_range(-5, 5))
			var w := _rng.randf_range(12.0, 20.0)
			var dd := _rng.randf_range(10.0, 16.0)
			var radius := Vector2(w, dd).length() * 0.5
			if c.distance_to(PLAZA) < 52.0 + radius or c.distance_to(Vector3(103, 0, -33)) > 235.0:
				continue
			if not _clear_of_track(c, radius, 2.0):
				continue
			var face := Vector3.FORWARD.rotated(Vector3.UP, _rng.randi_range(0, 3) * PI * 0.5)
			_place_apartment(mb, glow, c, face, w, dd, _rng.randi_range(2, 7))
			placed += 1

	# Pinos piñoneros en el parque interior
	for k in 26:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(18.0, 44.0)
		var p := PLAZA + Vector3(cos(a) * r, 0, sin(a) * r)
		if not _clear_of_track(p, 3.0, 0.0):
			continue
		mb.push_at(p)
		Props.umbrella_pine(mb, _rng)
		mb.pop()
		_occupied.append([p, 3.0])

	var city := _add_mesh(mb, "City")
	city.set_meta("buildings", placed)
	_add_mesh(glow, "CityLights", true)
	for s in signs:
		var lbl := Label3D.new()
		lbl.text = s[1]
		lbl.font_size = 72 if not s[4] else 96
		lbl.pixel_size = 0.0105 if not s[4] else 0.02
		lbl.outline_size = 0 if not s[4] else 16
		lbl.modulate = s[2]
		lbl.outline_modulate = Color.WHITE
		lbl.position = s[0]
		if s[4]:
			lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		else:
			lbl.rotation.y = s[3]
			lbl.double_sided = false
		add_child(lbl)


## Constantes del aeropuerto (al sur del barrio, como en la realidad).
const RUNWAY_Z := 250.0
const RUNWAY_X := 120.0
const RUNWAY_LEN := 900.0
const RUNWAY_W := 45.0
const FENCE_Z := 168.0


## Orientación para que la fachada (−Z local) mire hacia el punto más cercano del circuito.
func _face_track(c: Vector3) -> Basis:
	var i := _find_index(Vector2(c.x, c.z))
	var to := points[i] - c
	to.y = 0.0
	return Basis.looking_at(to.normalized(), Vector3.UP)


func _build_landmarks() -> void:
	var n := points.size()
	var mb := MB.new()
	var glow := MB.new()
	var labels: Array = []   # [posición, texto, color, yaw, tamaño, fijo_y]
	mb.ao_strength = 0.25
	mb.ao_height = 6.0

	# --- Gallina Pota Blava junto a la primera curva (se ve al frenar) ---
	var pb := Vector3(-26, 0, -206)
	var b := _face_track(pb)
	const PB_SCALE := 1.7
	mb.push(Transform3D(b * Basis.from_scale(Vector3.ONE * PB_SCALE), pb))
	Landmarks.pota_blava(mb)
	mb.pop()
	_occupied.append([pb, 7.0 * PB_SCALE])
	labels.append([pb + b * Vector3(0, 1.6, -2.56) * PB_SCALE, "POTA BLAVA", Color("1d4fa8"), b.get_euler().y + PI, 96, false])

	# --- La Telegrafia, al norte de la calle de las obras ---
	var tg := Vector3(92, 0, -229)
	b = _face_track(tg)
	mb.push(Transform3D(b, tg))
	glow.push(Transform3D(b, tg))
	Landmarks.telegrafia(mb, glow)
	glow.pop()
	mb.pop()
	_occupied.append([tg, 12.0])
	labels.append([tg + b * Vector3(0, 0.95, -6.6), "LA TELEGRAFIA", Color("efe2c6"), b.get_euler().y + PI, 64, false])

	# --- Plaça de la Vila: Casa de la Vila + parroquia (en el interior del trazado) ---
	var cv := Vector3(44, 0, 66)
	b = _face_track(cv)
	mb.push(Transform3D(b, cv))
	glow.push(Transform3D(b, cv))
	Landmarks.casa_de_la_vila(mb, glow)
	glow.pop()
	mb.pop()
	_occupied.append([cv, 14.0])
	labels.append([cv + b * Vector3(0, 11.2, -6.35), "CASA DE LA VILA", Color("5a3b2a"), b.get_euler().y + PI, 72, false])
	var ch := Vector3(40, 0, 22)
	b = _face_track(ch)
	mb.push(Transform3D(b, ch))
	glow.push(Transform3D(b, ch))
	Landmarks.church(mb, glow)
	glow.pop()
	mb.pop()
	_occupied.append([ch, 14.0])
	# Suelo de la plaza (despejada: sin bloques de relleno delante de los monumentos)
	_occupied.append([Vector3(30, 0, 44), 30.0])
	mb.use("default")
	mb.cylinder(Vector3(46, -0.02, 44), 20.0, 0.06, 14, Color("d9c7a3"), Color("d9c7a3"))
	for k in 6:
		var a := TAU * k / 6.0
		mb.push_at(Vector3(46, 0, 44) + Vector3(cos(a), 0, sin(a)) * 9.0, Vector3(0, -rad_to_deg(a) + 90, 0))
		Props.bench(mb)
		mb.pop()

	# --- Mercat municipal, en la acera exterior de la Avinguda ---
	var me := Vector3(244, 0, 30)
	b = _face_track(me)
	mb.push(Transform3D(b, me))
	glow.push(Transform3D(b, me))
	Landmarks.mercat(mb, glow)
	glow.pop()
	mb.pop()
	_occupied.append([me, 17.0])
	labels.append([me + b * Vector3(0, 10.6, -9.25), "MERCAT", Color("c26a3d"), b.get_euler().y + PI, 96, false])

	# --- Parc del Riu: río Llobregat, chimenea de Torras Hostench y mirador ---
	mb.push_at(Vector3(-84, 0, -30))
	Landmarks.river(mb, _rng, 560.0, 26.0)
	mb.pop()
	_occupied.append([Vector3(-84, 0, -30), 0.0])  # el río se protege con _river_x
	var chim := Vector3(-44, 0, -60)
	mb.push_at(chim)
	Landmarks.factory_chimney(mb)
	mb.pop()
	_occupied.append([chim, 5.0])
	var look := Vector3(-48, 0, 34)
	mb.push_at(look, Vector3(0, 30, 0))
	Landmarks.lookout(mb)
	mb.pop()
	_occupied.append([look, 6.0])
	labels.append([chim + Vector3(0, 6.5, 0), "PARC DEL RIU", Color("2f6b3a"), 0.0, 72, true])

	# --- Aeropuerto: valla, pista, hangar, avión estacionado, manga y torre ---
	mb.push_at(Vector3(RUNWAY_X, 0, FENCE_Z))
	Landmarks.airport_fence(mb, 700.0)
	mb.pop()
	mb.push_at(Vector3(RUNWAY_X, 0, RUNWAY_Z))
	glow.push_at(Vector3(RUNWAY_X, 0, RUNWAY_Z))
	Landmarks.runway(mb, glow, RUNWAY_LEN, RUNWAY_W)
	glow.pop()
	mb.pop()
	var hg := Vector3(190, 0, 198)
	mb.push_at(hg, Vector3(0, 180, 0))
	glow.push_at(hg, Vector3(0, 180, 0))
	Landmarks.hangar(mb, glow)
	glow.pop()
	mb.pop()
	mb.push_at(Vector3(110, 3.4, 200), Vector3(0, 155, 0))
	Props.airliner(mb)
	mb.pop()
	mb.push_at(Vector3(30, 0, 188))
	Landmarks.windsock(mb)
	mb.pop()
	var tw := Vector3(-30, 0, 206)
	mb.push_at(tw)
	glow.push_at(tw)
	Landmarks.control_tower(mb, glow)
	glow.pop()
	mb.pop()
	labels.append([Vector3(RUNWAY_X - 100, 4.2, FENCE_Z - 0.4), "AEROPORT  ✈  ZONA RESTRINGIDA", Color("1f4fa0"), PI, 64, false])

	# --- Pórtico de señales tras la salida (como en las carreteras catalanas) ---
	var gi := 22
	var gb := Basis.looking_at(-dirs[gi], Vector3.UP)   # el panel mira a los karts que llegan
	mb.push(Transform3D(gb, points[gi]))
	var panel: Vector3 = Landmarks.sign_gantry(mb, (WALL_TOP + 0.8) * 2.0)
	mb.pop()
	var gpos := points[gi] + gb * panel
	var gyaw := gb.get_euler().y
	labels.append([gpos + Vector3(0, 0.45, 0) + gb.z * -0.02, "✈ Aeroport   ↑ Barcelona", Color.WHITE, gyaw + PI, 72, false])
	labels.append([gpos + Vector3(0, -0.45, 0) + gb.z * -0.02, "C-31   Castelldefels →", Color.WHITE, gyaw + PI, 64, false])

	# --- Placas azules de calle sobre el muro, en puntos clave ---
	for spec in [[Vector2(0, -60), "Av. del Remolar"], [Vector2(100, -194), "Carrer de la Telegrafia"],
			[Vector2(206, 30), "Av. Verge de Montserrat"], [Vector2(80, 129), "Carrer Major"],
			[Vector2(150, -88), "Passeig del Riu"]]:
		var i := _find_index(spec[0])
		var side := -1.0 if curv[i] >= 0.0 else 1.0
		var p := edge(i, side * (WALL_TOP + 0.4), 2.2)
		var pb2 := Basis.looking_at(lefts[i] * side, Vector3.UP)  # mira a la carretera
		mb.push(Transform3D(pb2, p))
		Landmarks.street_plaque(mb)
		mb.use("metal")
		mb.box(Vector3(0, -1.1, 0.05), Vector3(0.1, 2.2, 0.1), Color("6b737b"))
		mb.pop()
		labels.append([p + pb2 * Vector3(0, 0, -0.07), spec[1], Color.WHITE, pb2.get_euler().y + PI, 48, false])

	_add_mesh(mb, "Landmarks")
	var gl := _add_mesh(glow, "LandmarkLights", true)
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for l in labels:
		var lbl := Label3D.new()
		lbl.text = l[1]
		lbl.font_size = l[4]
		lbl.pixel_size = 0.012 if l[4] >= 64 else 0.008
		lbl.outline_size = 0
		lbl.modulate = l[2]
		lbl.position = l[0]
		if l[5]:
			lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			lbl.outline_size = 14
			lbl.outline_modulate = Color.WHITE
		else:
			lbl.rotation.y = l[3]
			lbl.double_sided = false
		add_child(lbl)


func _place_apartment(mb, glow, c: Vector3, face: Vector3, w: float, dd: float, floors: int) -> void:
	var t := Transform3D(Basis.looking_at(face, Vector3.UP), c)
	mb.push(t)
	glow.push(t)
	Props.apartment(mb, glow, _rng, w, dd, floors)
	glow.pop()
	mb.pop()
	_occupied.append([c, Vector2(w, dd).length() * 0.5])


func _build_skyline() -> void:
	var mb := MB.new()
	var glow := MB.new()
	var center := Vector3(103, 0, -33)
	# Anillo de bloques lejanos
	for k in 70:
		var a := TAU * k / 70.0 + _rng.randf_range(-0.03, 0.03)
		var r := _rng.randf_range(250.0, 340.0)
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		if p.z > FENCE_Z - 20.0 or absf(p.x + 84.0) < 40.0:
			continue  # ni sobre el aeropuerto ni sobre el río
		mb.push_at(p, Vector3(0, rad_to_deg(-a), 0))
		Props.far_block(mb, _rng, _rng.randf_range(18, 34), _rng.randf_range(14, 22), _rng.randf_range(14, 40))
		mb.pop()
	# Colinas en el horizonte
	for k in 14:
		var a := PI * 1.05 + k * 0.11
		var r := 720.0 + _rng.randf_range(-40, 60)
		var p := center + Vector3(cos(a) * r, -2, sin(a) * r)
		mb.push_at(p)
		Props.hill(mb, _rng.randf_range(90, 160), _rng.randf_range(60, 130), Color("7d9a86").lerp(Color("9db4c0"), _rng.randf()))
		mb.pop()
	var mi := _add_mesh(mb, "Skyline")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_mesh(glow, "SkylineLights", true)
