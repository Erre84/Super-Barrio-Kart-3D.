extends "res://scripts/kart/kart_model.gd"
## EXITO · Spray Kart. Referencias: sprites de juego de la v16 (racers-v3) y lámina
## 03_EXITO_aerosol_referencia.
##
## Kart: un aerosol gigante tumbado a lo largo, con la boquilla blanca y morada atrás
## (por ahí sale su SPRAY CEGADOR), cuerpo con manchas de grafiti amarillas, moradas,
## rosas y turquesa y el nombre EXITO con corona; bastidor tubular oscuro con barras
## cromadas, ruedas negras anchas con llanta dorada.
## Piloto: gorra crema hacia delante, coleta de rizos oscuros, barba poblada, media
## sonrisa; chaqueta crema con franjas oscuras en hombros y mangas; pantalón cargo
## oscuro y zapatillas blancas y azul marino.

const CAN := Color("c9a227")
const CHROME := Color("d7dde4")
const FRAME := Color("2a2a31")
const CREAM := Color("e9e1cf")
const CREAM_LO := Color("cbbfa6")
const STRIPE := Color("3a3340")
const SKIN := Color("e3b28a")
const CURLS := Color("2e2019")
const PAINT := [Color("ffd23f"), Color("9b3cff"), Color("ff4fa8"), Color("2ec9d6"), Color("ff8a2a"), Color("6a2bd1")]


func _setup_style() -> void:
	style.merge({
		"body": Color("6a2bd1"), "body_dark": Color("3e1784"), "accent": Color("ffd23f"), "trim": FRAME,
		"seat": Color("23232a"), "metal": Color("8f96a3"), "chrome": CHROME,
		"tire": Color("2c2c33"), "tire_tread": Color("1b1b20"),
		"rim": Color("e0b13a"), "rim_dish": Color("3e1784"), "hub": Color("9b3cff"),
		"rim_style": "dish", "tire_band": false,
		"suit": CREAM, "suit_dark": CREAM_LO, "pants": Color("2f2c33"),
		"sleeve": CREAM, "cuff": STRIPE, "glove": SKIN,
		"skin": SKIN, "hair": CURLS, "eye": Color("3a2416"),
		"shoe": Color("f4f4f6"), "shoe_sole": Color("1f2a48"),
		"scarf_tail": false,
		"eye_size": 0.85, "eye_lid": 0.3, "brow_tilt": 4.0, "brow_size": Vector3(0.13, 0.036, 0.03), "brow_y": 0.1,
		"mouth": "smirk", "mouth_excited": "grin",
		"beard": Color("2e2019"), "beard_style": "full",
		"blush": false, "eye_shine": false,
		"number": "",
	}, true)
	front_wheel = Vector3(0.8, 0.31, -0.9)
	front_size = Vector2(0.31, 0.32)
	rear_wheel = Vector3(0.84, 0.37, 0.88)
	rear_size = Vector2(0.37, 0.42)
	exhaust_points = [Vector3(0, 0.55, 1.62), Vector3(0, 0.55, 1.62)]
	rear_wheel_points = [Vector3(-0.84, 0.02, 0.88), Vector3(0.84, 0.02, 0.88)]
	_raise_driver(0.36)   # el asiento va encima del bote


func _build_chassis() -> void:
	var mb := MB.new()
	# --- Bastidor tubular oscuro y barras cromadas ---
	mb.use("metal")
	for s: float in [-1.0, 1.0]:
		mb.tube(Vector3(s * 0.62, 0.3, -1.3), Vector3(s * 0.62, 0.3, 1.25), 0.04, 0.04, 8, FRAME)
		mb.tube(Vector3(s * 0.62, 0.3, -1.3), Vector3(s * 0.62, 0.62, -0.62), 0.035, 0.035, 8, FRAME)
		mb.tube(Vector3(s * 0.66, 0.4, 0.2), Vector3(s * 0.66, 0.4, 0.95), 0.03, 0.03, 8, CHROME)
	mb.tube(Vector3(-0.62, 0.3, -1.3), Vector3(0.62, 0.3, -1.3), 0.04, 0.04, 8, FRAME)
	mb.tube(Vector3(-0.62, 0.62, -0.62), Vector3(0.62, 0.62, -0.62), 0.035, 0.035, 8, FRAME)
	# Arco antivuelco tras el asiento
	mb.tube(Vector3(-0.42, 0.45, 0.62), Vector3(-0.38, 1.0, 0.7), 0.035, 0.035, 8, CHROME)
	mb.tube(Vector3(0.42, 0.45, 0.62), Vector3(0.38, 1.0, 0.7), 0.035, 0.035, 8, CHROME)
	mb.tube(Vector3(-0.38, 1.0, 0.7), Vector3(0.38, 1.0, 0.7), 0.035, 0.035, 8, CHROME)
	mb.use("paint")
	mb.chamfer_box(Vector3(0, 0.24, 0.0), Vector3(1.1, 0.08, 2.5), 0.03, Color("1d1d22"))
	# --- El aerosol: cilindro tumbado a lo largo (eje Z), con hombro y boquilla atrás ---
	mb.push_at(Vector3(0, 0.55, 0.0), Vector3(90, 0, 0))
	# cuerpo pintado (bandas de colores de grafiti a lo largo)
	var bands := 8
	for i in bands:
		var y0 := lerpf(-1.32, 0.95, float(i) / bands)
		var y1 := lerpf(-1.32, 0.95, float(i + 1) / bands)
		mb.cylinder(Vector3(0, y0, 0), 0.38, y1 - y0, 14, PAINT[i % PAINT.size()], null, -1.0, false)
	mb.pop()
	# Manchas de pintura salpicadas sobre el bote
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var a := rng.randf_range(-PI * 0.95, PI * 0.95)
		var z := rng.randf_range(-1.25, 0.9)
		var dir := Vector3(sin(a), cos(a), 0)
		var c: Color = PAINT[rng.randi_range(0, PAINT.size() - 1)]
		mb.sphere(Vector3(0, 0.55, z) + dir * 0.37, Vector3(0.07, 0.07, 0.1) * rng.randf_range(0.7, 1.4), 6, 3, c)
	# Fondo del bote (delante) y hombro + tapa cromada (detrás)
	mb.use("paint")
	mb.push_at(Vector3(0, 0.55, -1.32), Vector3(-90, 0, 0))
	mb.cylinder(Vector3.ZERO, 0.39, 0.05, 14, Color("6a2bd1"), Color("ffd23f"))
	mb.cylinder(Vector3(0, 0.05, 0), 0.25, 0.012, 12, Color("ff4fa8"), Color("ff4fa8"))
	mb.pop()
	mb.use("chrome")
	mb.push_at(Vector3(0, 0.55, 0.95), Vector3(90, 0, 0))
	mb.cylinder(Vector3.ZERO, 0.39, 0.2, 14, CHROME, null, 0.24)
	mb.cylinder(Vector3(0, 0.2, 0), 0.24, 0.22, 12, CHROME.darkened(0.08), null, 0.2)
	mb.pop()
	# Boquilla blanca con punta morada
	mb.use("paint")
	mb.push_at(Vector3(0, 0.55, 1.37), Vector3(90, 0, 0))
	mb.cylinder(Vector3.ZERO, 0.12, 0.18, 10, Color("f2f2f2"), Color("f2f2f2"))
	mb.cylinder(Vector3(0, 0.18, 0), 0.07, 0.05, 10, Color("9b3cff"), Color("2a0d4a"))
	mb.pop()
	# --- Asiento negro encajado sobre el bote ---
	mb.use("cloth")
	mb.chamfer_box(Vector3(0, 0.84, 0.28), Vector3(0.6, 0.08, 0.5), 0.04, Color("23232a"))
	mb.push_at(Vector3(0, 1.12, 0.6), Vector3(-14, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.6, 0.4, 0.1), 0.05, Color("23232a"))
	mb.pop()
	mb.use("metal")
	mb.tube(Vector3(0, 0.88, -0.75), WHEEL_CENTER + Vector3(0, 0.02, 0.04), 0.03, 0.03, 6, FRAME)
	_mi(mb.commit(), "Chassis", body_pivot)
	# Nombre con corona en los laterales y en el frontal
	for s: float in [-1.0, 1.0]:
		_text("EXITO", Vector3(s * 0.385, 0.6, -0.2), Vector3(0, s * 90.0, 0), 0.0055, Color.WHITE, 72, Color("2a0d4a"))
		_text("♛", Vector3(s * 0.38, 0.86, -0.42), Vector3(0, s * 90.0, -s * 25.0), 0.004, Color("ffd23f"), 64)
	_text("EXITO", Vector3(0, 0.55, -1.385), Vector3(0, 180, 0), 0.0042, Color.WHITE, 72, Color("2a0d4a"))
	_text("♛", Vector3(0, 0.75, -1.37), Vector3(0, 180, 0), 0.004, Color("ffd23f"), 64)
	# Luces
	var glow := MB.new()
	for s: float in [-1.0, 1.0]:
		glow.box(Vector3(s * 0.5, 0.36, 1.27), Vector3(0.14, 0.06, 0.02), Color("ff2d2d"))
		glow.box(Vector3(s * 0.45, 0.35, -1.35), Vector3(0.12, 0.06, 0.02), Color("fff3c4"))
	_mi(glow.commit(MB.glow_material()), "Lights", body_pivot)


func _build_shoe(mb: MB, foot: Vector3, s: float) -> void:
	mb.use("rubber")
	mb.chamfer_box(foot + Vector3(0, 0.03, -0.06), Vector3(0.18, 0.14, 0.28), 0.05, Color("f4f4f6"))
	mb.chamfer_box(foot + Vector3(0, -0.04, -0.06), Vector3(0.19, 0.05, 0.3), 0.015, Color("1f2a48"))
	mb.box(foot + Vector3(s * 0.091, 0.04, -0.06), Vector3(0.01, 0.07, 0.15), Color("1f2a48"))


func _build_torso(mb: MB) -> void:
	# Chaqueta crema con cremallera, cuello alto y franjas oscuras en los hombros
	_torso_shell(mb, CREAM, 1.06)
	mb.use("cloth")
	mb.loft([_hsec(-0.02, 0.54, 0.38, 0.1), _hsec(0.06, 0.55, 0.39, 0.1)], [CREAM_LO], false, false)
	mb.loft([_hsec(0.5, 0.36, 0.3, 0.1), _hsec(0.62, 0.32, 0.27, 0.09)], [CREAM])
	mb.box(Vector3(0, 0.3, -0.205), Vector3(0.015, 0.46, 0.012), Color("8a8f9a"))
	for s: float in [-1.0, 1.0]:
		mb.slab(Vector3(s * 0.12, 0.53, -0.1), Vector3(s * 0.3, 0.47, 0.0), 0.07, 0.08, 0.03, STRIPE, Vector3(0, 1, 0))
		mb.slab(Vector3(s * 0.12, 0.53, 0.1), Vector3(s * 0.3, 0.47, 0.02), 0.07, 0.08, 0.03, STRIPE, Vector3(0, 1, 0))


func _build_arms() -> void:
	super._build_arms()
	# Franja oscura a lo largo de las mangas
	for side: String in ["l", "r"]:
		for part: String in ["_upper", "_fore"]:
			var limb: MeshInstance3D = _arm_parts[side + part]
			var st := MB.new()
			st.use("cloth")
			st.slab(Vector3(0, 0.07, 0), Vector3(0, 0.062, -1.0), 0.045, 0.04, 0.012, STRIPE, Vector3(0, 1, 0))
			var m := _mi(st.commit_single("cloth"), "SleeveStripe", limb)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_hair(mb: MB, hc: Vector3) -> void:
	mb.use("cloth")
	# Pelo oscuro bajo la gorra y coleta de rizos en la nuca
	mb.sphere(hc + Vector3(0, -0.02, 0.04), Vector3(0.41, 0.38, 0.39), 12, 4, CURLS, PI * 0.3, PI * 0.62)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var tie := hc + Vector3(0, -0.02, 0.42)
	mb.sphere(tie, Vector3(0.05, 0.05, 0.04), 6, 3, Color("4a3fa8"))
	for i in 16:
		var p := tie + Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.3, 0.02), rng.randf_range(0.04, 0.16))
		mb.sphere(p, Vector3.ONE * rng.randf_range(0.055, 0.08), 6, 4, CURLS.lightened(rng.randf_range(0.0, 0.12)))
	# Gorra crema hacia delante con botón y visera
	var cap := Color("e6dcc6")
	mb.sphere(hc + Vector3(0, 0.05, 0.02), Vector3(0.43, 0.45, 0.43), 12, 5, cap, 0.0, PI * 0.46)
	mb.sphere(hc + Vector3(0, 0.51, 0.02), Vector3(0.045, 0.028, 0.045), 6, 2, Color("8a3a2a"))
	mb.push_at(hc + Vector3(0, 0.15, -0.4), Vector3(-8, 0, 0))
	mb.frustum(Vector3.ZERO, Vector2(0.46, 0.06), Vector2(0.5, 0.26), 0.035, cap.darkened(0.05), Vector2(0, -0.12))
	mb.pop()
	# Parche oscuro en el frontal de la gorra
	mb.push_at(hc + Vector3(0, 0.33, -0.36), Vector3(-60, 0, 0))
	mb.chamfer_box(Vector3.ZERO, Vector3(0.18, 0.1, 0.02), 0.02, Color("2c2a3a"))
	mb.pop()
