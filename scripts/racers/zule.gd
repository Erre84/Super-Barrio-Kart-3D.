extends "res://scripts/kart/kart_model.gd"
## ZULE · Oxygen Kart (teclado MIDI). Referencias: sprites de juego de la v16
## (racers-v3: rear0/rear1/rear2/front) y lámina 01_ZULE_oxygen_kart_referencia.
##
## Kart: carrocería compacta negra brillante; en el morro, un teclado MIDI con teclas
## blancas y negras, ruedas de control, faders y pantalla roja "127"; pads naranjas
## 2×2; pilotos rojos rectangulares; ruedas negras anchas con buje rojo.
## Piloto: chaqueta negra acolchada sobre sudadera blanca-azulada con la capucha
## asomando, pelo castaño oscuro peinado hacia atrás con degradado en los lados,
## barba recortada, pendientes brillantes y mirada seria de párpado caído.
## (Las marcas del teclado real no se reproducen: en su lugar va el nombre ZULE.)

const BLACK := Color("1b1c22")
const BLACK_HI := Color("2c2e37")
const EDGE := Color("454856")
const RED := Color("ff2b2b")
const PAD := Color("ff8a3d")
const SKIN := Color("e6b48f")


func _setup_style() -> void:
	style.merge({
		"body": BLACK, "body_dark": Color("111217"), "accent": RED, "trim": Color("0e0f13"),
		"seat": Color("23252d"), "metal": Color("6d7480"), "chrome": Color("c9d0d9"),
		"tire": Color("2e2f36"), "tire_tread": Color("1c1d22"),
		"rim": Color("4a4d58"), "rim_dish": Color("26272e"), "hub": Color("e02424"),
		"rim_style": "dish", "tire_band": false,
		"suit": Color("1f2027"), "suit_dark": Color("15161b"), "pants": Color("23242b"),
		"skin": SKIN, "hair": Color("3a2418"), "eye": Color("2e1c12"),
		"glove": SKIN, "cuff": Color("15161b"),
		"shoe": Color("1f2027"), "shoe_sole": Color("f2f2f2"),
		"scarf_tail": false,
		"eye_lid": 0.42, "eye_size": 0.8, "brow_tilt": -5.0, "brow_size": Vector3(0.15, 0.042, 0.035), "brow_y": 0.085,
		"mouth": "flat", "mouth_excited": "smirk",
		"beard": Color("2b1b12"), "beard_style": "full",
		"earring": Color("eef6ff"),
		"blush": false, "eye_shine": false,
		"number": "",
	}, true)
	front_wheel = Vector3(0.8, 0.33, -0.84)
	front_size = Vector2(0.33, 0.36)
	rear_wheel = Vector3(0.84, 0.38, 0.86)
	rear_size = Vector2(0.38, 0.44)
	exhaust_points = [Vector3(-0.3, 0.4, 1.42), Vector3(0.3, 0.4, 1.42)]
	rear_wheel_points = [Vector3(-0.84, 0.02, 0.86), Vector3(0.84, 0.02, 0.86)]


# =============================================================================
# Kart: Oxygen
# =============================================================================

func _build_chassis() -> void:
	var mb := MB.new()
	mb.use("paint")
	var dk := Color("101116")
	var lo := Color("0c0d10")
	var shade8 := [BLACK_HI, BLACK, BLACK, dk, lo, dk, BLACK, BLACK_HI]
	# --- Bañera baja ---
	mb.loft([
		_sec(-1.26, 1.2, 0.2, 0.3, 0.07),
		_sec(1.34, 1.24, 0.22, 0.31, 0.07),
	], shade8)
	# --- Morro: teclado MIDI inclinado hacia el piloto, como un atril ---
	mb.loft([
		_sec(-1.32, 1.22, 0.22, 0.36, 0.08),
		_sec(-1.24, 1.34, 0.34, 0.44, 0.1),
		_sec(-0.62, 1.34, 0.52, 0.47, 0.12),
		_sec(-0.5, 1.2, 0.44, 0.45, 0.12),
	], shade8)
	# --- Laterales del habitáculo (pontones con los pads) ---
	for s: float in [-1.0, 1.0]:
		mb.loft([
			_sec(-0.52, 0.3, 0.3, 0.47, 0.1, s * 0.52),
			_sec(0.5, 0.34, 0.36, 0.48, 0.12, s * 0.52),
			_sec(0.7, 0.3, 0.32, 0.48, 0.1, s * 0.52),
		], shade8)
	# --- Zaga compacta (no tapa al piloto) ---
	mb.loft([
		_sec(0.62, 1.16, 0.4, 0.5, 0.12),
		_sec(0.86, 1.28, 0.5, 0.52, 0.15),
		_sec(1.3, 1.28, 0.48, 0.52, 0.15),
		_sec(1.38, 1.18, 0.4, 0.5, 0.12),
	], shade8)
	# Parachoques trasero
	mb.chamfer_box(Vector3(0, 0.3, 1.4), Vector3(1.34, 0.12, 0.1), 0.04, dk)
	# Placa negra del nombre
	mb.chamfer_box(Vector3(0, 0.5, 1.385), Vector3(0.5, 0.15, 0.03), 0.02, Color("08080a"))
	# Respaldo bajo (deja ver la capucha) con reborde
	mb.use("cloth")
	mb.chamfer_box(Vector3(0, 0.47, 0.26), Vector3(0.64, 0.1, 0.52), 0.04, Color("23252d"))
	mb.push_at(Vector3(0, 0.74, 0.6), Vector3(-10, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.7, 0.34, 0.12), 0.07, Color("1d1f26"))
	mb.chamfer_box(Vector3(0, 0.0, -0.02), Vector3(0.5, 0.22, 0.12), 0.05, Color("2c2f39"))
	mb.pop()
	# Columna de dirección
	mb.use("metal")
	mb.tube(Vector3(0, 0.62, -0.7), WHEEL_CENTER + Vector3(0, -0.03, 0.04), 0.03, 0.03, 6, Color("3b3e48"))
	_mi(mb.commit(), "Chassis", body_pivot)

	# --- Teclado: teclas y controles sobre la tapa del morro (material mate) ---
	var kb := MB.new()
	kb.use("default")
	kb.push_at(Vector3(0, 0.672, -0.93), Vector3(-11, 0, 0))
	var n_white := 14
	var kw := 1.2 / n_white
	for i in n_white:
		var x := -0.6 + kw * (i + 0.5)
		kb.chamfer_box(Vector3(x, 0.0, -0.15), Vector3(kw - 0.012, 0.03, 0.3), 0.006, Color("f4f3ee"), Color.WHITE)
	for i in n_white - 1:
		if i % 7 == 2 or i % 7 == 6:
			continue
		var x := -0.6 + kw * (i + 1)
		kb.chamfer_box(Vector3(x, 0.03, -0.2), Vector3(kw * 0.55, 0.04, 0.18), 0.006, Color("121216"))
	for s: float in [-1.0, 1.0]:
		kb.chamfer_box(Vector3(-0.47 + s * 0.035, 0.03, 0.06), Vector3(0.05, 0.05, 0.12), 0.015, Color("2a2b32"))
	for i in 6:
		var x := -0.26 + i * 0.075
		kb.box(Vector3(x, 0.006, 0.06), Vector3(0.015, 0.008, 0.12), Color("0b0b0e"))
		kb.chamfer_box(Vector3(x, 0.02, 0.06 + sin(i * 1.7) * 0.035), Vector3(0.045, 0.03, 0.03), 0.008, Color("c9cdd6"))
	for i in 2:
		for j in 2:
			kb.cylinder(Vector3(0.24 + i * 0.07, 0.0, 0.02 + j * 0.08), 0.025, 0.035, 8, Color("2b2c33"), Color("8a8f9a"))
	kb.pop()
	_mi(kb.commit(), "Keyboard", body_pivot)

	# --- Luces, pantalla y pads (luminosos) ---
	var glow := MB.new()
	for s: float in [-1.0, 1.0]:
		# Pilotos traseros grandes y tira lateral
		glow.box(Vector3(s * 0.43, 0.56, 1.385), Vector3(0.24, 0.1, 0.02), RED)
		glow.box(Vector3(s * 0.645, 0.55, 1.1), Vector3(0.02, 0.06, 0.34), RED)
		# Luces rojas del morro y del pontón
		glow.box(Vector3(s * 0.5, 0.4, -1.325), Vector3(0.18, 0.05, 0.02), Color("ff3b30"))
		glow.box(Vector3(s * 0.686, 0.42, -0.05), Vector3(0.015, 0.04, 0.6), Color("ff3b30"))
		# Pads naranjas 2×2 sobre los pontones
		for i in 2:
			for j in 2:
				glow.box(Vector3(s * 0.52 + (i - 0.5) * 0.12, 0.665, 0.3 + (j - 0.5) * 0.12), Vector3(0.1, 0.02, 0.1), PAD)
	# Emblema rojo del respaldo
	glow.push_at(Vector3(0, 0.82, 0.655), Vector3(-10, 0, 0))
	glow.box(Vector3.ZERO, Vector3(0.24, 0.07, 0.02), Color("ff3030"))
	glow.pop()
	glow.push_at(Vector3(0, 0.672, -0.93), Vector3(-11, 0, 0))
	glow.box(Vector3(-0.36, 0.012, 0.08), Vector3(0.14, 0.01, 0.07), Color("2a0505"))
	for i in 4:
		glow.box(Vector3(-0.47 + (i % 2) * 0.05, 0.012, 0.16 - (i / 2) * 0.0), Vector3(0.035, 0.012, 0.025),
				Color("3fa9ff") if i < 2 else Color("ff4545"))
	for i in 2:
		for j in 2:
			glow.box(Vector3(0.42 + i * 0.085, 0.012, 0.02 + j * 0.085), Vector3(0.075, 0.016, 0.075), PAD)
	glow.pop()
	_mi(glow.commit(MB.glow_material()), "Lights", body_pivot)

	# Pantalla "127", nombre en la zaga y en los laterales
	var deck := Basis.from_euler(Vector3(deg_to_rad(-11), 0, 0))
	_label("127", Vector3(0, 0.672, -0.93) + deck * Vector3(-0.36, 0.02, 0.08), Vector3(-101, 0, 0), 0.0016, Color("ff3b30"), 48)
	_label("ZULE", Vector3(0, 0.5, 1.402), Vector3.ZERO, 0.0026, Color("e8ebf2"), 64)
	for s: float in [-1.0, 1.0]:
		_label("OXYGEN", Vector3(s * 0.686, 0.52, 0.42), Vector3(0, s * 90.0, 0), 0.0026, Color("d9dce4"), 48)


func _label(text: String, pos: Vector3, rot: Vector3, px: float, col: Color, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees = rot
	l.double_sided = false
	body_pivot.add_child(l)


# =============================================================================
# Piloto: Zule
# =============================================================================

func _build_shoe(mb: MB, foot: Vector3, _s: float) -> void:
	mb.use("rubber")
	mb.chamfer_box(foot + Vector3(0, 0.03, -0.06), Vector3(0.18, 0.14, 0.28), 0.05, Color("1f2027"))
	mb.chamfer_box(foot + Vector3(0, -0.04, -0.06), Vector3(0.19, 0.05, 0.3), 0.015, Color("f2f2f2"))


func _build_torso(mb: MB) -> void:
	var jacket := _col("suit")
	var hood := Color("dfe8f6")
	var hood_d := Color("b9c7dd")
	# Chaqueta acolchada: algo más ancha que el torso estándar, con pespuntes
	_torso_shell(mb, jacket, 1.1)
	mb.use("cloth")
	for y: float in [0.12, 0.26, 0.38]:
		mb.loft([_hsec(y, 0.62 if y > 0.2 else 0.56, 0.42, 0.13, -0.01), _hsec(y + 0.012, 0.62 if y > 0.2 else 0.56, 0.42, 0.13, -0.01)],
				[Color("101116")], false, false)
	mb.loft([_hsec(-0.02, 0.55, 0.38, 0.1), _hsec(0.06, 0.56, 0.39, 0.1)], [Color("15161b")], false, false)
	# Sudadera clara asomando por la chaqueta abierta (pecho y cuello)
	mb.push_at(Vector3(0, 0.33, -0.19), Vector3(-6, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.2, 0.36, 0.04), 0.03, hood)
	mb.pop()
	for x: float in [-0.05, 0.05]:
		mb.box(Vector3(x, 0.38, -0.215), Vector3(0.016, 0.16, 0.016), Color("f6f8fc"))
	mb.box(Vector3(0, 0.26, -0.2), Vector3(0.012, 0.42, 0.012), Color("8a8f9a"))  # cremallera
	# Capucha: cuello alto alrededor y bolsa voluminosa en la espalda
	mb.loft([_hsec(0.5, 0.44, 0.34, 0.12), _hsec(0.6, 0.4, 0.32, 0.12, 0.01), _hsec(0.66, 0.34, 0.28, 0.1, 0.02)],
			[hood, hood, hood, hood_d, hood_d, hood_d, hood, hood])
	mb.sphere(Vector3(0, 0.6, 0.2), Vector3(0.3, 0.2, 0.2), 10, 5, hood)
	mb.sphere(Vector3(0, 0.66, 0.27), Vector3(0.18, 0.11, 0.1), 8, 3, hood_d)


func _build_hair(mb: MB, hc: Vector3) -> void:
	var hair := _col("hair")
	var hair_hi := Color("7a5236")
	var hair_mid := Color("553623")
	var fade := _col("skin").lerp(Color("3a2a22"), 0.78)
	mb.use("cloth")
	# Degradado en los lados y la nuca: casquete pegado, entre piel y pelo
	mb.sphere(hc + Vector3(0, 0.0, 0.025), Vector3(0.408, 0.378, 0.392), 12, 6, fade, PI * 0.2, PI * 0.64)
	# Tupé peinado hacia atrás: base y volumen alto delante
	mb.sphere(hc + Vector3(0, 0.1, 0.03), Vector3(0.36, 0.34, 0.4), 12, 4, hair, 0.0, PI * 0.4)
	# Coronilla y nuca: pelo corto peinado hacia atrás que baja hasta el degradado
	mb.sphere(hc + Vector3(0, 0.02, 0.06), Vector3(0.39, 0.372, 0.375), 12, 4, hair_mid, PI * 0.25, PI * 0.56)
	mb.sphere(hc + Vector3(0, 0.3, -0.12), Vector3(0.27, 0.17, 0.25), 10, 4, hair_mid, 0.0, PI * 0.6)
	# Mechones en surcos, de la frente hacia la nuca, alternando tonos
	for i in 9:
		var x := lerpf(-0.26, 0.26, i / 8.0)
		var col := hair_hi if i % 2 == 0 else hair_mid
		var front := hc + Vector3(x * 0.75, 0.42 - absf(x) * 0.3, -0.3)
		var top := hc + Vector3(x * 0.95, 0.5 - absf(x) * 0.35, 0.0)
		var back := hc + Vector3(x * 1.05, 0.37 - absf(x) * 0.25, 0.3)
		mb.slab(front, top, 0.07, 0.075, 0.035, col, Vector3(x * 2.0, 1, -0.4).normalized())
		mb.slab(top, back, 0.075, 0.06, 0.035, col, Vector3(x * 2.0, 1, 0.5).normalized())
	for s: float in [-1.0, 1.0]:
		# Raya marcada del degradado
		mb.slab(hc + Vector3(s * 0.35, 0.22, -0.22), hc + Vector3(s * 0.37, 0.19, 0.24), 0.035, 0.035, 0.03,
				hair.darkened(0.3), Vector3(s, 0.3, 0))
		# Patillas que enlazan con la barba
		mb.slab(hc + Vector3(s * 0.38, 0.08, -0.07), hc + Vector3(s * 0.385, -0.1, -0.1), 0.06, 0.05, 0.025, hair,
				Vector3(s, 0, 0))
