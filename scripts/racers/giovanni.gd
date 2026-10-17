extends "res://scripts/kart/kart_model.gd"
## GIOVANNI · Kart morado y oro con el 24. Referencias: sprites de juego de la v16
## (racers-v3) y lámina 02_GIOVANNI_lakers_referencia.
##
## Kart: kart de carreras clásico con librea morada y amarilla: morro amarillo con
## franja morada y emblema de balón de baloncesto, pontones morados con el 24 en blanco,
## zaga morada con placa negra "24" y tira de pilotos rojos, llantas amarillas.
## Piloto: gorra blanca con visera y botón morados y emblema dorado, polo amarillo con
## ribetes morados, vaqueros, zapatillas blancas y moradas; grita con la boca abierta y
## el ceño fruncido (su gesto de la lámina); perilla y barba corta clara, pendiente.
## (El logotipo del equipo no se reproduce: va un balón y el 24.)

const PURPLE := Color("5a2a9c")
const PURPLE_HI := Color("7a46c4")
const PURPLE_LO := Color("3c1a6e")
const GOLD := Color("f7c325")
const GOLD_LO := Color("d39b12")
const SKIN := Color("f2c8a4")
const BALL := Color("f08a24")


func _setup_style() -> void:
	style.merge({
		"body": PURPLE, "body_dark": PURPLE_LO, "accent": GOLD, "stripe": GOLD, "trim": Color("1c1530"),
		"seat": PURPLE_LO, "metal": Color("8f96a3"), "chrome": Color("e3e8ee"),
		"tire": Color("2c2c33"), "tire_tread": Color("1b1b20"),
		"rim": GOLD, "rim_dish": PURPLE_LO, "hub": PURPLE,
		"rim_style": "spokes", "tire_band": false,
		"suit": GOLD, "suit_dark": GOLD_LO, "pants": Color("2f4f8f"),
		"sleeve": GOLD, "forearm": SKIN, "cuff": SKIN, "glove": SKIN,
		"skin": SKIN, "hair": Color("4a3020"), "eye": Color("4a3524"),
		"shoe": Color("f6f6f8"), "shoe_sole": PURPLE,
		"scarf_tail": false,
		"eye_size": 0.9, "eye_lid": 0.12, "brow_tilt": -16.0, "brow_size": Vector3(0.13, 0.034, 0.03), "brow_y": 0.11,
		"mouth": "shout", "mouth_excited": "shout",
		"beard": Color("c09070"), "beard_style": "stubble",
		"earring": Color("eef2ff"),
		"blush": false, "eye_shine": true,
		"number": "24",
	}, true)
	exhaust_points = [Vector3(-0.42, 0.5, 1.47), Vector3(0.42, 0.5, 1.47)]


# =============================================================================
# Kart
# =============================================================================

func _build_chassis() -> void:
	var mb := MB.new()
	mb.use("paint")
	var p8 := [PURPLE_HI, PURPLE, PURPLE, PURPLE_LO, Color("241040"), PURPLE_LO, PURPLE, PURPLE_HI]
	var g8 := [GOLD.lightened(0.15), GOLD, GOLD, GOLD_LO, GOLD_LO.darkened(0.3), GOLD_LO, GOLD, GOLD.lightened(0.15)]
	# --- Carrocería: morro amarillo que se ensancha hacia la cabina morada ---
	mb.loft([
		_sec(-1.46, 0.56, 0.18, 0.34, 0.06),
		_sec(-1.2, 0.96, 0.3, 0.41, 0.1),
		_sec(-0.8, 1.06, 0.44, 0.49, 0.13),
		_sec(-0.52, 1.04, 0.32, 0.43, 0.1),
	], g8)
	mb.loft([
		_sec(-0.52, 1.04, 0.32, 0.43, 0.1),
		_sec(-0.3, 1.02, 0.22, 0.38, 0.07),
		_sec(0.3, 1.12, 0.22, 0.38, 0.07),
		_sec(0.6, 1.18, 0.48, 0.5, 0.12),
		_sec(1.05, 1.06, 0.52, 0.55, 0.14),
		_sec(1.36, 0.86, 0.36, 0.55, 0.1),
	], p8)
	# Franja morada central sobre el morro
	mb.loft([
		_sec(-1.45, 0.16, 0.02, 0.43, 0.0),
		_sec(-1.18, 0.22, 0.02, 0.565, 0.0),
		_sec(-0.8, 0.24, 0.02, 0.715, 0.0),
	], [PURPLE])
	# --- Pontones laterales morados con remate amarillo ---
	for s: float in [-1.0, 1.0]:
		var x := s * 0.7
		mb.loft([
			_sec(-0.62, 0.2, 0.18, 0.33, 0.05, x),
			_sec(-0.46, 0.34, 0.3, 0.37, 0.08, x),
			_sec(0.55, 0.4, 0.34, 0.4, 0.09, x),
			_sec(0.82, 0.3, 0.26, 0.4, 0.07, x),
		], [GOLD, PURPLE, PURPLE, PURPLE_LO, Color("241040"), PURPLE_LO, PURPLE, GOLD])
		# Placa amarilla del 24 en el lateral
		mb.push_at(Vector3(s * 0.905, 0.42, 0.12), Vector3(0, 0, 90))
		mb.cylinder(Vector3(0, -0.01, 0), 0.15, 0.02, 12, Color.WHITE)
		mb.pop()
		# Bloques amarillos de la zaga (a los lados de la placa)
		mb.chamfer_box(Vector3(s * 0.4, 0.58, 1.38), Vector3(0.26, 0.24, 0.06), 0.03, GOLD)
	# --- Alerón delantero amarillo con extremos morados ---
	mb.chamfer_box(Vector3(0, 0.26, -1.4), Vector3(1.3, 0.1, 0.26), 0.03, GOLD)
	for s: float in [-1.0, 1.0]:
		mb.chamfer_box(Vector3(s * 0.66, 0.31, -1.39), Vector3(0.05, 0.2, 0.3), 0.015, PURPLE)
	# --- Bandeja y parachoques ---
	mb.chamfer_box(Vector3(0, 0.2, 0.05), Vector3(1.2, 0.08, 2.4), 0.03, Color("1c1530"))
	mb.chamfer_box(Vector3(0, 0.36, 1.45), Vector3(1.4, 0.16, 0.12), 0.05, PURPLE_LO)
	# Placa negra trasera
	mb.chamfer_box(Vector3(0, 0.6, 1.415), Vector3(0.4, 0.22, 0.03), 0.03, Color("101014"))
	# --- Asiento morado con respaldo amarillo ---
	mb.use("cloth")
	mb.chamfer_box(Vector3(0, 0.47, 0.28), Vector3(0.62, 0.1, 0.52), 0.04, PURPLE_LO)
	mb.push_at(Vector3(0, 0.78, 0.6), Vector3(-14, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.66, 0.5, 0.11), 0.05, GOLD)
	mb.chamfer_box(Vector3(0, 0.0, -0.02), Vector3(0.44, 0.3, 0.11), 0.04, PURPLE)
	mb.pop()
	# --- Columna de dirección ---
	mb.use("metal")
	mb.tube(Vector3(0, 0.46, -0.85), WHEEL_CENTER + Vector3(0, -0.03, 0.04), 0.03, 0.03, 6, Color("2a2533"))
	_mi(mb.commit(), "Chassis", body_pivot)

	# --- Emblema: balón de baloncesto sobre fondo morado en el morro ---
	var em := MB.new()
	em.use("paint")
	em.push_at(Vector3(0, 0.665, -0.96), Vector3(-62, 0, 0))
	em.cylinder(Vector3.ZERO, 0.19, 0.03, 16, PURPLE_HI, PURPLE)
	em.cylinder(Vector3(0, 0.02, 0), 0.14, 0.03, 16, BALL, BALL.lightened(0.1))
	em.box(Vector3(0, 0.052, 0), Vector3(0.28, 0.008, 0.016), Color("2a1608"))
	em.box(Vector3(0, 0.052, 0), Vector3(0.016, 0.008, 0.28), Color("2a1608"))
	em.pop()
	# Balones pequeños en los bloques amarillos de la zaga
	for s: float in [-1.0, 1.0]:
		em.push_at(Vector3(s * 0.4, 0.58, 1.415), Vector3(90, 0, 0))
		em.cylinder(Vector3.ZERO, 0.08, 0.02, 12, BALL, BALL)
		em.box(Vector3(0, 0.021, 0), Vector3(0.15, 0.006, 0.012), Color("2a1608"))
		em.box(Vector3(0, 0.021, 0), Vector3(0.012, 0.006, 0.15), Color("2a1608"))
		em.pop()
	_mi(em.commit(), "Emblems", body_pivot)

	# --- Luces ---
	var glow := MB.new()
	for s: float in [-1.0, 1.0]:
		glow.push_at(Vector3(s * 0.32, 0.5, -1.18), Vector3(-25, s * 12, 0))
		glow.chamfer_box(Vector3.ZERO, Vector3(0.18, 0.07, 0.03), 0.015, Color("fff6d8"))
		glow.pop()
	glow.box(Vector3(0, 0.76, 1.42), Vector3(0.62, 0.06, 0.03), Color("ff2d2d"))
	_mi(glow.commit(MB.glow_material()), "Lights", body_pivot)

	# --- Números 24 (frontal, laterales y placa trasera) ---
	var plates := [
		[Vector3(0, 0.44, -1.29), Vector3(-30, 0, 0), 0.0034, PURPLE_LO, 0],
		[Vector3(-0.928, 0.42, 0.12), Vector3(0, -90, 0), 0.0034, PURPLE, 0],
		[Vector3(0.928, 0.42, 0.12), Vector3(0, 90, 0), 0.0034, PURPLE, 0],
		[Vector3(0, 0.6, 1.432), Vector3.ZERO, 0.0036, Color.WHITE, 0],
	]
	for p in plates:
		var num := Label3D.new()
		num.text = "24"
		num.font_size = 72
		num.pixel_size = p[2]
		num.modulate = p[3]
		num.outline_size = 0
		num.position = p[0]
		num.rotation_degrees = p[1]
		num.double_sided = false
		body_pivot.add_child(num)


# =============================================================================
# Piloto: Giovanni
# =============================================================================

func _build_shoe(mb: MB, foot: Vector3, s: float) -> void:
	mb.use("rubber")
	mb.chamfer_box(foot + Vector3(0, 0.03, -0.06), Vector3(0.18, 0.14, 0.28), 0.05, Color("f6f6f8"))
	mb.chamfer_box(foot + Vector3(0, -0.04, -0.06), Vector3(0.19, 0.05, 0.3), 0.015, PURPLE)
	mb.box(foot + Vector3(s * 0.091, 0.04, -0.04), Vector3(0.01, 0.07, 0.14), PURPLE_HI)


func _build_torso(mb: MB) -> void:
	# Polo amarillo con cuello, tapeta y ribetes morados
	_torso_shell(mb, GOLD)
	mb.use("cloth")
	mb.loft([_hsec(-0.02, 0.52, 0.38, 0.1), _hsec(0.04, 0.53, 0.39, 0.1)], [GOLD_LO], false, false)
	# Cuello de polo
	mb.loft([_hsec(0.5, 0.38, 0.3, 0.1), _hsec(0.6, 0.32, 0.26, 0.09)], [GOLD.lightened(0.08)])
	mb.loft([_hsec(0.6, 0.32, 0.26, 0.09), _hsec(0.615, 0.33, 0.27, 0.09)], [PURPLE])
	for s: float in [-1.0, 1.0]:
		mb.push_at(Vector3(s * 0.08, 0.53, -0.15), Vector3(25, 0, s * 30))
		mb.chamfer_box(Vector3.ZERO, Vector3(0.12, 0.02, 0.1), 0.01, GOLD.lightened(0.08))
		mb.pop()
	# Tapeta con botones
	mb.box(Vector3(0, 0.42, -0.2), Vector3(0.06, 0.16, 0.02), GOLD_LO)
	for y: float in [0.38, 0.45]:
		mb.box(Vector3(0, y, -0.212), Vector3(0.022, 0.022, 0.01), Color.WHITE)
	# Emblema morado en el pecho
	mb.use("paint")
	mb.push_at(Vector3(0.15, 0.36, -0.205), Vector3(90, 0, 0))
	mb.cylinder(Vector3.ZERO, 0.05, 0.015, 10, PURPLE, PURPLE_HI)
	mb.pop()


func _build_arms() -> void:
	super._build_arms()
	# Ribete morado al final de la manga corta (en el brazo superior, cerca del codo)
	for side: String in ["l", "r"]:
		var upper: MeshInstance3D = _arm_parts[side + "_upper"]
		var band := MB.new()
		band.use("cloth")
		band.tube(Vector3(0, 0, -0.55), Vector3(0, 0, -0.75), 0.085, 0.08, 7, PURPLE)
		var bm := _mi(band.commit_single("cloth"), "SleeveBand", upper)
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_hair(mb: MB, hc: Vector3) -> void:
	var hair := _col("hair")
	mb.use("cloth")
	# Pelo corto degradado que asoma bajo la gorra (patillas y nuca)
	mb.sphere(hc + Vector3(0, -0.02, 0.03), Vector3(0.405, 0.375, 0.39), 12, 4, SKIN.lerp(hair, 0.7), PI * 0.32, PI * 0.62)
	# Gorra blanca hacia delante: corona, ribete morado abajo, botón y visera morada
	var white := Color("f5f5f8")
	mb.sphere(hc + Vector3(0, 0.05, 0.02), Vector3(0.43, 0.45, 0.43), 12, 5, white, 0.0, PI * 0.47)
	mb.sphere(hc + Vector3(0, 0.05, 0.02), Vector3(0.436, 0.456, 0.436), 12, 1, PURPLE, PI * 0.44, PI * 0.47)
	mb.sphere(hc + Vector3(0, 0.51, 0.01), Vector3(0.045, 0.028, 0.045), 6, 2, PURPLE)
	# Costuras de los paneles
	for i in 3:
		var a := lerpf(-0.6, 0.6, i / 2.0)
		mb.slab(hc + Vector3(sin(a) * 0.1, 0.5, -cos(a) * 0.06), hc + Vector3(sin(a) * 0.42, 0.2, -cos(a) * 0.36),
				0.012, 0.012, 0.012, Color("dcdce4"), Vector3(sin(a), 0.6, -cos(a)).normalized())
	# Visera morada (hacia delante, algo curvada)
	mb.push_at(hc + Vector3(0, 0.15, -0.4), Vector3(-6, 0, 0))
	mb.frustum(Vector3.ZERO, Vector2(0.46, 0.06), Vector2(0.5, 0.26), 0.035, PURPLE, Vector2(0, -0.12))
	mb.pop()
	# Cierre trasero morado
	mb.chamfer_box(hc + Vector3(0, 0.08, 0.4), Vector3(0.18, 0.06, 0.04), 0.015, PURPLE)
	# Emblema dorado en el frontal de la gorra (balón)
	mb.use("paint")
	mb.push_at(hc + Vector3(0, 0.33, -0.36), Vector3(-62, 0, 0))
	mb.cylinder(Vector3.ZERO, 0.1, 0.02, 12, GOLD, GOLD)
	mb.cylinder(Vector3(0, 0.012, 0), 0.07, 0.02, 12, BALL, BALL)
	mb.box(Vector3(0, 0.033, 0), Vector3(0.13, 0.005, 0.01), Color("2a1608"))
	mb.box(Vector3(0, 0.033, 0), Vector3(0.01, 0.005, 0.13), Color("2a1608"))
	mb.pop()
