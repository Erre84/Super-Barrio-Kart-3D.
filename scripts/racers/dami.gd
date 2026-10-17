extends "res://scripts/kart/kart_model.gd"
## DAMI · Batería roja. Referencias: hoja de poses de Dami y su kart (v16.3) y sus
## sprites de juego (new_racers_v163: rear0/rear1/rear2/front).
##
## Kart: una batería sobre ruedas. Bombo delantero con parche negro, aro rojo, tensores
## cromados y la corona blanca; toms rojos a los lados; dos platillos dorados en sus
## soportes; tom grande atravesado detrás del asiento; dos escapes dorados redondos;
## chasis tubular cromado y ruedas negras con llanta roja y aro dorado.
## Piloto: complexión muy delgada, camiseta de tirantes negra, vaqueros anchos oscuros,
## zapatillas negras y blancas, gafas de sol negras, rastas rubias recogidas en lo alto
## con los lados rapados, perilla y bigote finos.

const RED := Color("d61f2c")
const RED_HI := Color("f04450")
const GOLD := Color("f2b32a")
const CHROME := Color("dfe4ea")
const SKIN := Color("efc4a0")
const DREAD := Color("b07a3a")
const DREAD_HI := Color("d39a52")
const DREAD_LO := Color("7e5326")


func _setup_style() -> void:
	style.merge({
		"body": RED, "body_dark": Color("9e1520"), "accent": GOLD, "trim": Color("1a1a1f"),
		"seat": Color("8e1019"), "metal": Color("9aa5b1"), "chrome": CHROME,
		"tire": Color("2b2b31"), "tire_tread": Color("1b1b20"),
		"rim": RED, "rim_dish": Color("7a0f18"), "hub": GOLD,
		"rim_style": "dish", "tire_band": true,
		"suit": Color("17171b"), "suit_dark": Color("0f0f12"), "pants": Color("262c3d"),
		"skin": SKIN, "hair": Color("6b4a2c"), "eye": Color("3a2a1a"),
		"sleeve": SKIN, "glove": SKIN, "cuff": SKIN, "arm_scale": 0.72, "head_scale": 0.9,
		"shoe": Color("1c1c22"), "shoe_sole": Color("f4f4f4"),
		"scarf_tail": false,
		"eye_size": 0.8, "brow_tilt": -3.0, "brow_size": Vector3(0.12, 0.026, 0.03), "brow_y": 0.13,
		"mouth": "flat", "mouth_excited": "smirk",
		"beard": Color("8a6440"), "beard_style": "goatee",
		"blush": false, "eye_shine": false,
		"number": "",
	}, true)
	front_wheel = Vector3(0.8, 0.3, -0.86)
	front_size = Vector2(0.3, 0.32)
	rear_wheel = Vector3(0.84, 0.36, 0.86)
	rear_size = Vector2(0.36, 0.4)
	exhaust_points = [Vector3(-0.3, 0.42, 1.48), Vector3(0.3, 0.42, 1.48)]
	rear_wheel_points = [Vector3(-0.84, 0.02, 0.86), Vector3(0.84, 0.02, 0.86)]


# =============================================================================
# Kart: batería
# =============================================================================

## Tambor: cilindro de eje `axis_rot` (grados de push_at) con dos aros cromados y tensores.
func _drum(mb: MB, center: Vector3, rot: Vector3, r: float, depth: float, shell: Color, head: Color,
		lugs: int = 8) -> void:
	mb.push_at(center, rot)
	mb.use("paint")
	mb.cylinder(Vector3(0, -depth * 0.5, 0), r, depth, 16, shell, head)
	# Franja brillante en el casco
	mb.cylinder(Vector3(0, -depth * 0.12, 0), r + 0.004, depth * 0.08, 16, shell.lightened(0.25), null, -1.0, false)
	mb.use("chrome")
	for y: float in [-depth * 0.5, depth * 0.5 - 0.03]:
		mb.cylinder(Vector3(0, y, 0), r + 0.018, 0.035, 16, CHROME, CHROME, -1.0, false)
	for i in lugs:
		var a := TAU * i / lugs
		var d := Vector3(cos(a), 0, sin(a)) * (r + 0.02)
		mb.box(d, Vector3(0.03, depth * 0.55, 0.03), CHROME.darkened(0.1))
	mb.pop()


## Platillo dorado en su soporte cromado.
func _cymbal(mb: MB, base: Vector3, top: Vector3, r: float) -> void:
	mb.use("chrome")
	mb.tube(base, top, 0.022, 0.016, 6, CHROME)
	mb.use("metal")
	mb.cylinder(top + Vector3(0, -0.01, 0), r, 0.025, 16, GOLD, GOLD.lightened(0.2), r * 0.25)
	mb.cylinder(top + Vector3(0, 0.012, 0), r * 0.22, 0.03, 10, GOLD.darkened(0.15), GOLD, 0.02)


func _build_chassis() -> void:
	var mb := MB.new()
	# --- Chasis: bandeja roja baja y bastidor tubular cromado ---
	mb.use("paint")
	mb.chamfer_box(Vector3(0, 0.24, 0.0), Vector3(1.16, 0.12, 2.5), 0.04, Color("1d1d22"))
	mb.chamfer_box(Vector3(0, 0.33, 0.25), Vector3(0.9, 0.08, 1.3), 0.03, RED, RED_HI)
	mb.use("chrome")
	for s: float in [-1.0, 1.0]:
		mb.tube(Vector3(s * 0.55, 0.32, -1.2), Vector3(s * 0.55, 0.32, 1.3), 0.035, 0.035, 8, CHROME)
		mb.tube(Vector3(s * 0.55, 0.32, 1.3), Vector3(s * 0.35, 0.3, 1.5), 0.035, 0.035, 8, CHROME)
	mb.tube(Vector3(-0.38, 0.3, 1.5), Vector3(0.38, 0.3, 1.5), 0.04, 0.04, 8, CHROME)
	mb.tube(Vector3(-0.6, 0.3, -1.28), Vector3(0.6, 0.3, -1.28), 0.035, 0.035, 8, CHROME)
	# --- Bombo delantero (eje hacia delante) ---
	_drum(mb, Vector3(0, 0.6, -0.98), Vector3(90, 0, 0), 0.4, 0.34, RED, Color("1a1a1f"), 10)
	# Aro rojo del parche frontal y tornillos
	mb.use("paint")
	mb.push_at(Vector3(0, 0.6, -1.155), Vector3(90, 0, 0))
	mb.cylinder(Vector3.ZERO, 0.4, 0.012, 20, RED_HI, RED_HI, 0.33, false)
	mb.cylinder(Vector3(0, -0.04, 0), 0.075, 0.03, 10, Color("101014"))
	mb.pop()
	# --- Toms delanteros a los lados del bombo ---
	for s: float in [-1.0, 1.0]:
		_drum(mb, Vector3(s * 0.48, 0.92, -0.62), Vector3(0, 0, s * -18), 0.17, 0.2, RED, Color("f1ede4"), 6)
		_cymbal(mb, Vector3(s * 0.62, 0.36, -0.52), Vector3(s * 0.74, 1.36, -0.62), 0.24)
	# --- Asiento rojo con respaldo bajo ---
	mb.use("cloth")
	mb.chamfer_box(Vector3(0, 0.47, 0.28), Vector3(0.62, 0.1, 0.52), 0.04, Color("9c121d"))
	mb.push_at(Vector3(0, 0.76, 0.58), Vector3(-12, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.62, 0.4, 0.1), 0.05, Color("9c121d"))
	mb.pop()
	# --- Tom grande atravesado detrás del asiento y toms traseros verticales ---
	_drum(mb, Vector3(0, 0.74, 0.98), Vector3(0, 0, 90), 0.27, 0.86, RED, Color("f1ede4"), 10)
	for s: float in [-1.0, 1.0]:
		_drum(mb, Vector3(s * 0.62, 0.66, 0.6), Vector3.ZERO, 0.17, 0.24, RED, Color("f1ede4"), 6)
	# --- Escapes dorados redondos ---
	for s: float in [-1.0, 1.0]:
		mb.use("metal")
		mb.push_at(Vector3(s * 0.3, 0.42, 1.3), Vector3(90, 0, 0))
		mb.cylinder(Vector3(0, -0.18, 0), 0.11, 0.18, 12, GOLD, Color("2a1c08"))
		mb.cylinder(Vector3(0, -0.2, 0), 0.13, 0.04, 12, GOLD.lightened(0.15), Color("1a1206"))
		mb.pop()
		mb.chamfer_box(Vector3(s * 0.3, 0.28, 1.42), Vector3(0.16, 0.05, 0.14), 0.02, GOLD)
	# Columna de dirección
	mb.use("chrome")
	mb.tube(Vector3(0, 0.5, -0.78), WHEEL_CENTER + Vector3(0, -0.03, 0.04), 0.03, 0.03, 6, CHROME)
	_mi(mb.commit(), "Chassis", body_pivot)

	# --- Corona blanca pintada en el parche del bombo ---
	var crown := MB.new()
	crown.use("default")
	var cz := -1.172
	var cw := Color("f6f6f2")
	crown.box(Vector3(0, 0.55, cz), Vector3(0.3, 0.05, 0.01), cw)
	for i in 5:
		var x := lerpf(-0.14, 0.14, i / 4.0)
		var h := 0.16 if i % 2 == 0 else 0.11
		crown.box(Vector3(x, 0.58 + h * 0.5, cz), Vector3(0.035, h, 0.01), cw)
		if i % 2 == 0:
			crown.box(Vector3(x, 0.6 + h, cz), Vector3(0.05, 0.035, 0.01), cw)
	_mi(crown.commit(), "Crown", body_pivot)

	# --- Luces ---
	var glow := MB.new()
	for s: float in [-1.0, 1.0]:
		glow.box(Vector3(s * 0.48, 0.3, 1.51), Vector3(0.16, 0.05, 0.02), Color("ff2d2d"))
	_mi(glow.commit(MB.glow_material()), "Lights", body_pivot)


# =============================================================================
# Piloto: Dami
# =============================================================================

func _build_legs(mb: MB) -> void:
	# Vaqueros anchos: tubos gruesos y bajos amplios
	for s: float in [-1.0, 1.0]:
		var hip := Vector3(s * 0.12, 0.06, -0.05)
		var knee := Vector3(s * 0.17, 0.2, -0.46)
		var foot := Vector3(s * 0.16, 0.04, -0.82)
		mb.use("cloth")
		mb.tube(hip, knee, 0.105, 0.1, 7, _col("pants"))
		mb.tube(knee, foot + Vector3(0, 0.05, 0.05), 0.1, 0.11, 7, _col("pants"))
		mb.sphere(knee, Vector3(0.1, 0.1, 0.1), 7, 4, _col("pants"))
		mb.use("rubber")
		mb.chamfer_box(foot + Vector3(0, 0.03, -0.06), Vector3(0.18, 0.14, 0.28), 0.05, Color("1c1c22"))
		mb.chamfer_box(foot + Vector3(0, -0.04, -0.06), Vector3(0.19, 0.05, 0.3), 0.015, Color("f4f4f4"))
		mb.box(foot + Vector3(s * 0.091, 0.04, -0.06), Vector3(0.01, 0.06, 0.16), Color("f4f4f4"))


func _build_torso(mb: MB) -> void:
	var tank := _col("suit")
	# Torso delgado: camiseta de tirantes negra
	mb.use("cloth")
	mb.loft([
		_hsec(0.0, 0.4, 0.3, 0.09),
		_hsec(0.22, 0.44, 0.32, 0.1, -0.01),
		_hsec(0.38, 0.42, 0.3, 0.1, -0.01),
	], [tank, tank, tank, tank.darkened(0.08), tank, tank, tank, tank.darkened(0.08)])
	# Pecho, hombros y cuello al aire
	mb.use("skin")
	mb.loft([
		_hsec(0.38, 0.4, 0.28, 0.1, -0.01),
		_hsec(0.47, 0.5, 0.26, 0.1),
		_hsec(0.53, 0.3, 0.2, 0.08),
	], [SKIN, SKIN, SKIN, SKIN.darkened(0.06), SKIN, SKIN, SKIN, SKIN.darkened(0.06)])
	# Tirantes de la camiseta
	mb.use("cloth")
	for s: float in [-1.0, 1.0]:
		mb.slab(Vector3(s * 0.13, 0.37, -0.16), Vector3(s * 0.14, 0.5, 0.0), 0.07, 0.06, 0.02, tank, Vector3(0, 1, -0.3))
		mb.slab(Vector3(s * 0.14, 0.5, 0.0), Vector3(s * 0.13, 0.37, 0.15), 0.06, 0.07, 0.02, tank, Vector3(0, 1, 0.3))
	# Cinturilla del vaquero
	mb.loft([_hsec(-0.03, 0.44, 0.33, 0.1), _hsec(0.05, 0.44, 0.33, 0.1)], [_col("pants")], false, false)


func _build_head_shape(mb: MB, hc: Vector3) -> void:
	# Cara algo más alargada y fina que la estándar
	var skin := _col("skin")
	mb.use("skin")
	mb.cylinder(Vector3(0, -0.04, 0), 0.075, 0.14, 7, skin)
	mb.sphere(hc + Vector3(0, -0.01, 0), Vector3(0.36, 0.39, 0.36), 12, 8, skin)
	for s: float in [-1.0, 1.0]:
		mb.sphere(hc + Vector3(s * 0.35, -0.02, 0.03), Vector3(0.065, 0.1, 0.06), 6, 4, skin.darkened(0.06))
	mb.sphere(hc + Vector3(0, -0.07, -0.35), Vector3(0.035, 0.05, 0.028), 6, 3, skin.darkened(0.1))


func _build_hair(mb: MB, hc: Vector3) -> void:
	mb.use("cloth")
	# Lados y nuca rapados (degradado muy corto)
	var shaved := SKIN.lerp(Color("4a3426"), 0.55)
	mb.sphere(hc + Vector3(0, -0.01, 0.02), Vector3(0.368, 0.398, 0.37), 12, 6, shaved, PI * 0.14, PI * 0.6)
	# Franja superior de pelo de la que nacen las rastas (sin invadir la frente)
	mb.sphere(hc + Vector3(0, 0.05, 0.05), Vector3(0.22, 0.36, 0.33), 10, 4, DREAD_LO, 0.0, PI * 0.36)
	# Coleta alta: haz de rastas que sube desde la coronilla hasta un nudo
	var knot := hc + Vector3(0, 0.56, 0.08)
	for i in 7:
		var a := TAU * i / 7
		var root := hc + Vector3(cos(a) * 0.12, 0.33, sin(a) * 0.1 + 0.04)
		mb.tube(root, knot + Vector3(cos(a) * 0.04, -0.04, sin(a) * 0.04), 0.045, 0.04, 5, [DREAD, DREAD_LO][i % 2], false)
	mb.sphere(knot, Vector3(0.1, 0.07, 0.1), 8, 4, DREAD_LO)
	# Fuente de rastas: suben del nudo y caen hacia fuera, en dos coronas
	var n := 22
	for i in n:
		var ring := i % 2
		var a := TAU * i / n + 0.15 * ring
		var dir := Vector3(cos(a), 0, sin(a) * 0.9)
		var col: Color = [DREAD, DREAD_HI, DREAD_LO][i % 3]
		var lift := 0.1 + 0.05 * ring + 0.03 * ((i * 7) % 3)
		var reach := 0.24 + 0.08 * ring
		var p0 := knot + dir * 0.04 + Vector3(0, 0.03, 0)
		var p1 := knot + dir * (reach * 0.55) + Vector3(0, lift, 0)
		var p2 := knot + dir * reach + Vector3(0, lift * 0.3, 0)
		var p3 := knot + dir * (reach * 1.15) + Vector3(0, -0.12 - 0.04 * ((i * 5) % 3), 0)
		mb.tube(p0, p1, 0.036, 0.034, 5, col, false)
		mb.tube(p1, p2, 0.034, 0.032, 5, col, false)
		mb.tube(p2, p3, 0.032, 0.026, 5, col)


func _build_head_extras(mb: MB, hc: Vector3) -> void:
	# Gafas de sol negras con montura fina
	mb.use("chrome")
	var lens := Color("0b0b10")
	for s: float in [-1.0, 1.0]:
		mb.push_at(hc + Vector3(s * 0.15, -0.02, -0.375), Vector3(0, s * -8.0, 0))
		mb.chamfer_box(Vector3.ZERO, Vector3(0.2, 0.12, 0.03), 0.03, lens)
		mb.box(Vector3(0, 0.055, -0.005), Vector3(0.21, 0.02, 0.035), Color("2a2a30"))
		mb.pop()
		# Patillas hasta las orejas
		mb.beam(hc + Vector3(s * 0.25, 0.02, -0.33), hc + Vector3(s * 0.35, 0.02, -0.05), 0.02, Color("2a2a30"))
	mb.box(hc + Vector3(0, 0.0, -0.385), Vector3(0.1, 0.02, 0.02), Color("2a2a30"))
