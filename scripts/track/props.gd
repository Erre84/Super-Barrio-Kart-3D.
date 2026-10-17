extends RefCounted
## Biblioteca de elementos low-poly del barrio. Cada función añade geometría a un
## MeshBuilder (mb) en coordenadas locales; quien llama coloca con mb.push_at().

const WALL_COLORS := [
	"f2d0a4", "e9b384", "d98e6a", "f4e3c1", "c97b63", "e8c07d",
	"b8c4c9", "f0a8a0", "9fc5c0", "f6e7a1", "d7b9e8", "e7a977",
]
const SHUTTER_COLORS := ["4f7d4a", "8a5a3a", "3f6f8f", "a8432f", "e0d4b8"]
const AWNING_COLORS := ["e63946", "2b6fe0", "2a9d8f", "f4a261", "8e44ad", "ffd23f"]


static func _c(hex: String) -> Color:
	return Color(hex)


## Bloque de pisos típico (fachada principal mirando a -Z local).
## Devuelve la altura total.
static func apartment(mb, glow, rng: RandomNumberGenerator, w: float, d: float, floors: int) -> float:
	var wall := _c(WALL_COLORS[rng.randi() % WALL_COLORS.size()])
	var shutter := _c(SHUTTER_COLORS[rng.randi() % SHUTTER_COLORS.size()])
	var ground_h := 3.8
	var floor_h := 3.0
	var h := ground_h + floors * floor_h
	# Cuerpo
	mb.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall, wall.darkened(0.25), false)
	# Planta baja: zócalo de tienda
	var shop := wall.darkened(0.35) if rng.randf() < 0.5 else _c("3b3f4a")
	mb.box(Vector3(0, ground_h * 0.5, 0), Vector3(w + 0.12, ground_h, d + 0.12), shop, null, false)
	# Escaparates y toldo en la fachada principal
	var n_shop := maxi(1, int(w / 5.0))
	var seg := w / n_shop
	var awn_a := _c(AWNING_COLORS[rng.randi() % AWNING_COLORS.size()])
	var awn_b := Color.WHITE
	for i in n_shop:
		var cx := -w * 0.5 + seg * (i + 0.5)
		var lit := rng.randf() < 0.45
		var glass := _c("ffe3a3") if lit else _c("2c3e50")
		var target = glow if lit else mb
		target.quad(Vector3(cx - seg * 0.38, 0.5, -d * 0.5 - 0.08), Vector3(cx + seg * 0.38, 0.5, -d * 0.5 - 0.08),
				Vector3(cx + seg * 0.38, 2.7, -d * 0.5 - 0.08), Vector3(cx - seg * 0.38, 2.7, -d * 0.5 - 0.08),
				glass, Vector3.FORWARD)
		# Toldo a rayas, inclinado
		var stripes := 4
		for s in stripes:
			var x0 := cx - seg * 0.42 + seg * 0.84 * s / stripes
			var x1 := cx - seg * 0.42 + seg * 0.84 * (s + 1) / stripes
			mb.quad(Vector3(x0, 3.3, -d * 0.5 - 0.1), Vector3(x1, 3.3, -d * 0.5 - 0.1),
					Vector3(x1, 2.75, -d * 0.5 - 1.3), Vector3(x0, 2.75, -d * 0.5 - 1.3),
					awn_a if s % 2 == 0 else awn_b, Vector3(0, 1, -0.4))
	# Ventanas con persiana en las cuatro fachadas
	var faces := [
		[Vector3(0, 0, -d * 0.5), Vector3.RIGHT, w, Vector3.FORWARD],
		[Vector3(0, 0, d * 0.5), Vector3.LEFT, w, Vector3.BACK],
		[Vector3(-w * 0.5, 0, 0), Vector3.FORWARD, d, Vector3.LEFT],
		[Vector3(w * 0.5, 0, 0), Vector3.BACK, d, Vector3.RIGHT],
	]
	var glass_dark := _c("34495e")
	for fi in faces.size():
		var f: Array = faces[fi]
		var origin: Vector3 = f[0]
		var along: Vector3 = f[1]
		var flen: float = f[2]
		var normal: Vector3 = f[3]
		var cols := maxi(1, int(flen / 3.4))
		var step := flen / cols
		for fl in floors:
			var y0 := ground_h + fl * floor_h + 0.7
			var balcony := fi == 0 and rng.randf() < 0.55
			for c in cols:
				var center := origin + along * (-flen * 0.5 + step * (c + 0.5)) + normal * 0.05
				var a := center - along * 0.62 + Vector3(0, y0, 0)
				var b := center + along * 0.62 + Vector3(0, y0, 0)
				var lit := rng.randf() < 0.12
				var glass := _c("ffe7a3") if lit else glass_dark
				var target = glow if lit else mb
				target.quad(a, b, b + Vector3(0, 1.7, 0), a + Vector3(0, 1.7, 0), glass, normal)
				# Persiana medio bajada (muy mediterráneo)
				var blind := rng.randf_range(0.25, 0.9)
				mb.quad(a + Vector3(0, 1.7 - blind * 1.7, 0) + normal * 0.02, b + Vector3(0, 1.7 - blind * 1.7, 0) + normal * 0.02,
						b + Vector3(0, 1.7, 0) + normal * 0.02, a + Vector3(0, 1.7, 0) + normal * 0.02, shutter, normal)
			if balcony:
				var bc := origin + normal * 0.55 + Vector3(0, y0 - 0.75, 0)
				mb.box(bc, Vector3(flen * 0.9, 0.18, 1.0) if absf(normal.z) > 0.5 else Vector3(1.0, 0.18, flen * 0.9), wall.lightened(0.15))
				mb.box(bc + normal * 0.47 + Vector3(0, 0.55, 0),
						Vector3(flen * 0.9, 0.9, 0.06) if absf(normal.z) > 0.5 else Vector3(0.06, 0.9, flen * 0.9),
						_c("2d3436"))
	# Azotea: pretil, depósito de agua, antenas y aire acondicionado
	var par := wall.lightened(0.1)
	mb.box(Vector3(0, h + 0.3, -d * 0.5 + 0.15), Vector3(w, 0.6, 0.3), par)
	mb.box(Vector3(0, h + 0.3, d * 0.5 - 0.15), Vector3(w, 0.6, 0.3), par)
	mb.box(Vector3(-w * 0.5 + 0.15, h + 0.3, 0), Vector3(0.3, 0.6, d), par)
	mb.box(Vector3(w * 0.5 - 0.15, h + 0.3, 0), Vector3(0.3, 0.6, d), par)
	if rng.randf() < 0.7:
		var tx := rng.randf_range(-w * 0.3, w * 0.3)
		mb.cylinder(Vector3(tx, h, d * 0.15), 0.9, 1.6, 8, _c("dfe6e9"), _c("b2bec3"))
	for i in rng.randi_range(1, 3):
		var ax := rng.randf_range(-w * 0.4, w * 0.4)
		var az := rng.randf_range(-d * 0.35, d * 0.35)
		mb.beam(Vector3(ax, h, az), Vector3(ax, h + rng.randf_range(2.0, 3.5), az), 0.08, _c("636e72"))
		mb.beam(Vector3(ax - 0.6, h + 1.8, az), Vector3(ax + 0.6, h + 1.8, az), 0.06, _c("636e72"))
	for i in rng.randi_range(0, 3):
		mb.box(Vector3(rng.randf_range(-w * 0.35, w * 0.35), h + 0.4, rng.randf_range(-d * 0.3, d * 0.3)),
				Vector3(1.0, 0.8, 0.7), _c("ced6e0"))
	return h


## Edificio lejano barato (franjas de ventanas en vez de ventanas sueltas).
static func far_block(mb, rng: RandomNumberGenerator, w: float, d: float, h: float) -> void:
	var wall := _c(WALL_COLORS[rng.randi() % WALL_COLORS.size()]).lerp(_c("c9d6df"), 0.25)
	mb.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall, wall.darkened(0.2), false)
	var band := wall.darkened(0.45)
	var y := 4.5
	while y < h - 1.5:
		mb.box(Vector3(0, y, 0), Vector3(w + 0.1, 1.1, d + 0.1), band, band, false)
		y += 3.0


## Palmera (tronco anillado algo curvo + hojas caídas).
static func palm(mb, rng: RandomNumberGenerator, height: float = 8.0) -> void:
	var trunk := _c("8b6b47")
	var trunk_b := _c("a07e55")
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.6, 1.6)
	var segs := 7
	var prev := Vector3.ZERO
	var r := 0.32
	for i in segs:
		var t := float(i + 1) / segs
		var p := lean * t * t + Vector3(0, height * t, 0)
		var r2 := r * 0.93
		var seg_dir := (p - prev).normalized()
		mb.push(Transform3D(Basis(Quaternion(Vector3.UP, seg_dir)), prev))
		mb.cylinder(Vector3.ZERO, r, (p - prev).length() + 0.05, 6, trunk if i % 2 == 0 else trunk_b, null, r2)
		mb.pop()
		prev = p
		r = r2
	var top := prev
	var leaf := _c("3fa34d")
	var leaf_d := _c("2a7a3a")
	var n := 8
	for i in n:
		var ang := TAU * i / n + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var p0 := top
		var p1 := top + dir * 1.6 + Vector3(0, 0.55, 0)
		var p2 := top + dir * 3.0 + Vector3(0, 0.1, 0)
		var p3 := top + dir * 3.9 + Vector3(0, -0.9, 0)
		var col := leaf if i % 2 == 0 else leaf_d
		mb.slab(p0, p1, 0.25, 0.95, 0.06, col)
		mb.slab(p1, p2, 0.95, 0.7, 0.06, col)
		mb.slab(p2, p3, 0.7, 0.08, 0.06, col)
	# Dátiles
	for i in 3:
		var a := TAU * i / 3.0
		mb.sphere(top + Vector3(cos(a) * 0.35, -0.25, sin(a) * 0.35), Vector3(0.2, 0.2, 0.2), 5, 3, _c("e09f3e"))


## Pino piñonero (copa en paraguas, muy de El Prat y el Delta).
static func umbrella_pine(mb, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(6.0, 8.5)
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.5, 1.5)
	var top := lean + Vector3(0, h, 0)
	mb.beam(Vector3.ZERO, top, 0.45, _c("7a5a3c"))
	var green := _c("3d7a3a")
	mb.sphere(top + Vector3(0, 0.6, 0), Vector3(3.6, 1.1, 3.4), 9, 4, green)
	mb.sphere(top + Vector3(0.6, 1.3, -0.3), Vector3(2.4, 0.8, 2.2), 8, 3, green.lightened(0.12))


## Farola urbana. `glow` recibe la parte luminosa. La farola mira a +X local.
static func streetlamp(mb, glow) -> void:
	var pole := _c("3c4b4f")
	mb.cylinder(Vector3.ZERO, 0.22, 0.5, 6, pole)
	mb.cylinder(Vector3(0, 0.5, 0), 0.11, 6.2, 6, pole, null, 0.08)
	mb.beam(Vector3(0, 6.5, 0), Vector3(1.6, 6.8, 0), 0.1, pole)
	mb.box(Vector3(1.75, 6.75, 0), Vector3(0.9, 0.22, 0.45), pole)
	glow.quad(Vector3(1.35, 6.63, -0.18), Vector3(2.15, 6.63, -0.18), Vector3(2.15, 6.63, 0.18),
			Vector3(1.35, 6.63, 0.18), _c("fff2c4"), Vector3.DOWN)


static func bench(mb) -> void:
	var wood := _c("b5733c")
	var iron := _c("2d3436")
	mb.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.08, 0.5), wood)
	mb.box(Vector3(0, 0.8, 0.22), Vector3(1.8, 0.35, 0.06), wood)
	for s: float in [-0.75, 0.75]:
		mb.box(Vector3(s, 0.22, 0), Vector3(0.08, 0.45, 0.45), iron)


## Cono de obra (malla para cuerpo rígido; origen en la base).
static func traffic_cone(mb) -> void:
	mb.box(Vector3(0, 0.03, 0), Vector3(0.5, 0.06, 0.5), _c("2d3436"))
	mb.cylinder(Vector3(0, 0.06, 0), 0.2, 0.62, 7, _c("ff6b1a"), null, 0.04)
	mb.cylinder(Vector3(0, 0.3, 0), 0.135, 0.1, 7, Color.WHITE, null, 0.115, false)


## Barrera de plástico de obra (roja y blanca).
static func plastic_barrier(mb, length: float = 2.0) -> void:
	var red := _c("e63946")
	mb.frustum(Vector3.ZERO, Vector2(length, 0.6), Vector2(length * 0.96, 0.3), 0.9, red, Vector2.ZERO, red.lightened(0.1))
	mb.box(Vector3(0, 0.55, 0), Vector3(length * 0.98, 0.18, 0.45), Color.WHITE)


static func bollard(mb) -> void:
	mb.cylinder(Vector3.ZERO, 0.14, 0.9, 6, _c("2d3436"), _c("ffd23f"))
	mb.cylinder(Vector3(0, 0.65, 0), 0.145, 0.1, 6, _c("ffd23f"), null, -1.0, false)


## Jardinera redonda con palmera (isleta en la calzada).
static func planter(mb, rng: RandomNumberGenerator, radius: float) -> void:
	mb.cylinder(Vector3.ZERO, radius, 0.6, 12, _c("d6cfc4"), _c("6d4c35"))
	mb.cylinder(Vector3(0, 0.6, 0), radius * 0.9, 0.05, 12, _c("4caf50"))
	mb.push_at(Vector3(0, 0.6, 0))
	palm(mb, rng, 7.0)
	mb.pop()


## Escultura de la alcachofa (la carxofa del Prat) sobre pedestal.
static func artichoke(mb) -> void:
	mb.cylinder(Vector3.ZERO, 4.2, 0.5, 12, _c("cfc6b8"))
	mb.cylinder(Vector3(0, 0.5, 0), 3.2, 1.3, 10, _c("e6dfd3"), _c("bfb6a8"))
	var base_y := 1.8
	mb.cylinder(Vector3(0, base_y, 0), 0.45, 1.0, 7, _c("6b8f3a"))  # tallo
	var rings := 6
	for k in rings:
		var t := float(k) / (rings - 1)
		var ring_r := lerpf(1.9, 0.4, t * t) + 0.6 * sin(t * PI)
		var y := base_y + 1.0 + t * 4.2
		var leaves := 9 - k
		var col := _c("7bb35a").lerp(_c("7d4f9e"), clampf(t * 1.1, 0.0, 1.0))
		for i in leaves:
			var a := TAU * (i + 0.5 * (k % 2)) / leaves
			var dir := Vector3(cos(a), 0, sin(a))
			var root := Vector3(0, y - 0.8, 0) + dir * ring_r * 0.35
			var tip := Vector3(0, y + 1.1, 0) + dir * (ring_r + 0.4)
			mb.slab(root, tip, 1.5 - t * 0.6, 0.1, 0.28, col if i % 2 == 0 else col.darkened(0.12), dir)
	mb.cylinder(Vector3(0, base_y + 4.6, 0), 0.6, 1.4, 7, _c("7d4f9e"), null, 0.0)


## Marquesina de autobús.
static func bus_stop(mb) -> void:
	var frame := _c("2d3436")
	for x: float in [-1.8, 1.8]:
		mb.box(Vector3(x, 1.2, 0.5), Vector3(0.1, 2.4, 0.1), frame)
		mb.box(Vector3(x, 1.2, -0.5), Vector3(0.1, 2.4, 0.1), frame)
	mb.box(Vector3(0, 2.45, 0), Vector3(4.0, 0.12, 1.4), _c("e63946"))
	mb.box(Vector3(0, 1.3, 0.55), Vector3(3.6, 1.8, 0.04), _c("a8d8ea"))
	mb.box(Vector3(0, 0.5, 0.3), Vector3(3.0, 0.08, 0.4), _c("b2bec3"))


## Torre de control del aeropuerto (referencia visual lejana).
static func control_tower(mb, glow) -> void:
	mb.cylinder(Vector3.ZERO, 6.0, 4.0, 10, _c("e6e6e6"))
	mb.cylinder(Vector3(0, 4, 0), 2.6, 38.0, 10, _c("f5f5f5"), null, 2.2)
	mb.cylinder(Vector3(0, 42, 0), 3.2, 1.2, 10, _c("e63946"), null, 5.2)
	mb.cylinder(Vector3(0, 43.2, 0), 5.2, 4.0, 10, _c("3d5a80"), null, 5.6)
	mb.cylinder(Vector3(0, 47.2, 0), 5.8, 1.0, 10, _c("f5f5f5"), null, 4.4)
	mb.beam(Vector3(0, 48, 0), Vector3(0, 56, 0), 0.25, _c("b2bec3"))
	glow.sphere(Vector3(0, 56.2, 0), Vector3(0.5, 0.5, 0.5), 5, 3, _c("ff4d4d"))


## Avión de pasajeros low-poly (morro hacia -Z).
static func airliner(mb) -> void:
	var white := _c("f7f7f7")
	var blue := _c("2b6fe0")
	mb.push_at(Vector3.ZERO, Vector3(-90, 0, 0))  # eje Y local -> -Z (morro)
	mb.cylinder(Vector3(0, -14, 0), 2.0, 26.0, 10, white)
	mb.cylinder(Vector3(0, 12, 0), 2.0, 5.0, 10, white, null, 0.3)          # morro
	mb.cylinder(Vector3(0, -20, 0), 0.5, 6.0, 10, white, null, 2.0)         # cola
	mb.pop()
	mb.box(Vector3(0, -0.6, -1.0), Vector3(34.0, 0.5, 5.0), _c("dfe6e9"))     # alas
	mb.box(Vector3(0, 0.6, 17.0), Vector3(12.0, 0.4, 2.8), _c("dfe6e9"))      # estabilizador
	mb.slab(Vector3(0, 1.5, 15.0), Vector3(0, 8.0, 19.0), 4.5, 1.8, 0.4, blue, Vector3.RIGHT)
	for x: float in [-7.0, 7.0]:
		mb.push_at(Vector3(x, -1.6, -3.5), Vector3(90, 0, 0))
		mb.cylinder(Vector3(0, -2.0, 0), 1.0, 4.0, 8, _c("b2bec3"), _c("2d3436"))
		mb.pop()
	mb.box(Vector3(0, 0.2, 0), Vector3(0.1, 1.0, 26.0), blue)  # franja


## Colina lejana (horizonte del Delta / Collserola).
static func hill(mb, radius: float, height: float, col: Color) -> void:
	mb.cylinder(Vector3.ZERO, radius, height, 7, col, col.lightened(0.08), radius * 0.35)


## Valla publicitaria sobre dos postes (el texto se añade con Label3D).
static func billboard(mb, color: Color) -> void:
	for x: float in [-2.6, 2.6]:
		mb.box(Vector3(x, 2.2, 0.15), Vector3(0.25, 4.4, 0.25), _c("636e72"))
	mb.box(Vector3(0, 4.6, 0.1), Vector3(6.6, 3.0, 0.25), _c("2d3436"))
	mb.box(Vector3(0, 4.6, 0.0), Vector3(6.2, 2.6, 0.12), color)
