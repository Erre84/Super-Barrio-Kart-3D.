extends RefCounted
## Lugares emblemáticos de El Prat de Llobregat (v0.2), en low-poly estilizado.
## Todos miran hacia -Z local (la fachada principal). Inspirados en referencias
## reales, sin pretender ser réplicas exactas:
##  - Escultura de la gallina "Pota Blava" (raza Prat, famosa por sus patas azules).
##  - Torre de control del aeropuerto: 62 m, malla de hormigón hiperboloide y
##    fanal octogonal (descripción de la torre real del aeropuerto).
##  - La Telegrafia (estación Marconi de Puig i Cadafalch, 1911): ladrillo modernista.
##  - Chimenea de ladrillo de la antigua fábrica Torras Hostench, en el Parc del Riu,
##    y mirador.
##  - Casa de la Vila (neogótica, 1905) y una parroquia con campanario.
##  - Mercat municipal de estilo noucentista.
##  - Río Llobregat con cañas y paseo; aeropuerto con pista, luces de aproximación,
##    hangar, valla, manga de viento y avión estacionado.

const Props := preload("res://scripts/track/props.gd")


static func _c(hex: String) -> Color:
	return Color(hex)


# --- Gallina Pota Blava -----------------------------------------------------------

static func pota_blava(mb) -> void:
	var stone := _c("d8d0c2")
	mb.use("default")
	mb.chamfer_box(Vector3(0, 0.6, 0), Vector3(7.0, 1.2, 7.0), 0.25, stone, stone.lightened(0.1))
	mb.chamfer_box(Vector3(0, 1.6, 0), Vector3(5.0, 0.8, 5.0), 0.2, stone.darkened(0.08))
	var y0 := 2.0
	var feather := _c("c98b45")       # plumaje leonado
	var feather_d := _c("8a5527")
	var blue := _c("3d7be0")          # ¡patas azules!
	mb.use("paint")
	# Patas y dedos
	for s: float in [-1.0, 1.0]:
		mb.tube(Vector3(s * 0.75, y0, 0.2), Vector3(s * 0.7, y0 + 2.6, 0.1), 0.26, 0.3, 7, blue)
		for a: float in [-0.5, 0.0, 0.5]:
			var d := Vector3(sin(a), 0, -cos(a))
			mb.tube(Vector3(s * 0.75, y0 + 0.12, 0.2), Vector3(s * 0.75, y0 + 0.08, 0.2) + d * 1.1, 0.13, 0.08, 6, blue)
		mb.tube(Vector3(s * 0.75, y0 + 0.12, 0.2), Vector3(s * 0.75, y0 + 0.08, 0.85), 0.11, 0.07, 6, blue)
	mb.use("cloth")
	# Cuerpo: pecho ancho y alargado
	var body := Vector3(0, y0 + 4.3, 0.2)
	mb.sphere(body, Vector3(2.0, 1.9, 2.6), 12, 8, feather)
	mb.sphere(body + Vector3(0, -0.2, -1.3), Vector3(1.75, 1.75, 1.6), 10, 6, feather.lightened(0.08))
	# Alas
	for s: float in [-1.0, 1.0]:
		mb.sphere(body + Vector3(s * 1.75, 0.2, 0.4), Vector3(0.5, 1.2, 1.9), 8, 5, feather_d)
	# Cola de plumas
	for i in 6:
		var a := lerpf(-0.6, 0.6, i / 5.0)
		var root := body + Vector3(a * 0.8, 0.8, 2.0)
		var tip := root + Vector3(a * 1.8, 2.6 - absf(a) * 1.2, 1.6)
		mb.slab(root, tip, 0.9, 0.35, 0.25, _c("2e3b2c") if i % 2 == 0 else _c("3e2a1a"), Vector3(1, 0, 0))
	# Cuello y cabeza
	var head := body + Vector3(0, 3.0, -2.1)
	mb.tube(body + Vector3(0, 1.0, -1.6), head + Vector3(0, -0.5, 0.2), 1.1, 0.75, 8, feather)
	mb.sphere(head, Vector3(0.95, 0.95, 0.95), 10, 6, feather.lightened(0.05))
	mb.use("paint")
	# Cresta roja en sierra
	for i in 5:
		var z := lerpf(-0.55, 0.65, i / 4.0)
		var h := 0.9 - absf(z - 0.05) * 0.6
		mb.slab(head + Vector3(0, 0.75, z), head + Vector3(0, 0.75 + h, z + 0.05), 0.42, 0.12, 0.16, _c("e0262f"), Vector3(1, 0, 0))
	# Pico y barbillas
	mb.tube(head + Vector3(0, -0.05, -0.8), head + Vector3(0, -0.25, -1.65), 0.3, 0.02, 6, _c("f2b632"))
	for s: float in [-1.0, 1.0]:
		mb.sphere(head + Vector3(s * 0.18, -0.85, -0.6), Vector3(0.22, 0.4, 0.15), 6, 4, _c("e0262f"))
		# Ojos
		mb.sphere(head + Vector3(s * 0.62, 0.15, -0.55), Vector3(0.2, 0.22, 0.12), 7, 4, Color.WHITE)
		mb.sphere(head + Vector3(s * 0.7, 0.15, -0.6), Vector3(0.11, 0.13, 0.08), 6, 3, _c("15100c"))


# --- Torre de control ---------------------------------------------------------------

static func control_tower(mb, glow) -> void:
	var concrete := _c("e9e6df")
	mb.use("default")
	mb.chamfer_box(Vector3(0, 3, 0), Vector3(24, 6, 16), 0.5, concrete, _c("cfcac0"))
	mb.box(Vector3(0, 3.2, -8.05), Vector3(20, 2.4, 0.1), _c("39566f"))
	# Fuste: malla hiperboloide (barras cruzadas) alrededor de un núcleo
	mb.use("metal")
	mb.cylinder(Vector3(0, 6, 0), 2.2, 40, 10, _c("aebdcc"))
	mb.use("default")
	var bars := 16
	var r_bot := 6.5
	var r_mid := 3.6
	var r_top := 6.0
	for i in bars:
		for twist: float in [1.0, -1.0]:
			var a0 := TAU * i / bars
			var a1 := a0 + twist * PI * 0.55
			var am := (a0 + a1) * 0.5
			var p0 := Vector3(cos(a0) * r_bot, 6, sin(a0) * r_bot)
			var pm := Vector3(cos(am) * r_mid, 26, sin(am) * r_mid)
			var p1 := Vector3(cos(a1) * r_top, 46, sin(a1) * r_top)
			mb.beam(p0, pm, 0.45, concrete)
			mb.beam(pm, p1, 0.45, concrete)
	# Plantas superiores y fanal octogonal
	mb.cylinder(Vector3(0, 46, 0), 6.8, 4.0, 8, concrete, _c("d6d1c6"))
	mb.use("metal")
	mb.cylinder(Vector3(0, 50, 0), 6.4, 0.5, 8, _c("55606e"))
	glow.cylinder(Vector3(0, 50.5, 0), 6.9, 4.2, 8, _c("8fd3ff"), null, 7.5, false)
	mb.cylinder(Vector3(0, 54.7, 0), 7.8, 0.8, 8, _c("55606e"), _c("cfd6dd"), 6.6)
	mb.use("default")
	mb.cylinder(Vector3(0, 55.5, 0), 4.0, 2.0, 8, concrete)
	mb.tube(Vector3(0, 57.5, 0), Vector3(0, 63, 0), 0.25, 0.12, 6, _c("b2bec3"))
	glow.sphere(Vector3(0, 63.2, 0), Vector3(0.6, 0.6, 0.6), 6, 4, _c("ff3b3b"))


# --- Aeropuerto -----------------------------------------------------------------------

## Pista de aterrizaje a lo largo del eje X local. `length` y `width` en metros.
static func runway(mb, glow, length: float, width: float) -> void:
	var hl := length * 0.5
	var hw := width * 0.5
	mb.use("default")
	mb.quad(Vector3(-hl, 0.02, -hw), Vector3(hl, 0.02, -hw), Vector3(hl, 0.02, hw), Vector3(-hl, 0.02, hw), _c("3c3f47"), Vector3.UP)
	# Márgenes y calle de rodaje
	mb.quad(Vector3(-hl, 0.015, -hw - 8), Vector3(hl, 0.015, -hw - 8), Vector3(hl, 0.015, -hw), Vector3(-hl, 0.015, -hw), _c("8f8d7a"), Vector3.UP)
	mb.quad(Vector3(-hl, 0.015, hw), Vector3(hl, 0.015, hw), Vector3(hl, 0.015, hw + 8), Vector3(-hl, 0.015, hw + 8), _c("8f8d7a"), Vector3.UP)
	mb.quad(Vector3(-hl, 0.02, -hw - 40), Vector3(hl, 0.02, -hw - 40), Vector3(hl, 0.02, -hw - 22), Vector3(-hl, 0.02, -hw - 22), _c("4a4d55"), Vector3.UP)
	var white := _c("f2f2f2")
	# Eje discontinuo
	var x := -hl + 60.0
	while x < hl - 60.0:
		mb.quad(Vector3(x, 0.03, -0.6), Vector3(x + 30, 0.03, -0.6), Vector3(x + 30, 0.03, 0.6), Vector3(x, 0.03, 0.6), white, Vector3.UP)
		x += 50.0
	# Bordes y "teclas de piano" en ambas cabeceras
	mb.quad(Vector3(-hl, 0.03, -hw + 0.5), Vector3(hl, 0.03, -hw + 0.5), Vector3(hl, 0.03, -hw + 1.2), Vector3(-hl, 0.03, -hw + 1.2), white, Vector3.UP)
	mb.quad(Vector3(-hl, 0.03, hw - 1.2), Vector3(hl, 0.03, hw - 1.2), Vector3(hl, 0.03, hw - 0.5), Vector3(-hl, 0.03, hw - 0.5), white, Vector3.UP)
	for end: float in [-1.0, 1.0]:
		var x0 := end * (hl - 14.0)
		for k in 12:
			var z := -hw + 3.0 + k * (width - 6.0) / 11.0
			mb.quad(Vector3(x0 - 12, 0.03, z - 0.9), Vector3(x0 + 12, 0.03, z - 0.9), Vector3(x0 + 12, 0.03, z + 0.9), Vector3(x0 - 12, 0.03, z + 0.9), white, Vector3.UP)
		# Zona de toma de contacto
		for k: float in [-1.0, 1.0]:
			var xt := end * (hl - 160.0)
			mb.quad(Vector3(xt - 25, 0.03, k * 8 - 2.5), Vector3(xt + 25, 0.03, k * 8 - 2.5), Vector3(xt + 25, 0.03, k * 8 + 2.5), Vector3(xt - 25, 0.03, k * 8 + 2.5), white, Vector3.UP)
	# Luces de borde (blancas) y de calle de rodaje (azules)
	x = -hl
	while x <= hl:
		for z: float in [-hw - 1.5, hw + 1.5]:
			glow.box(Vector3(x, 0.35, z), Vector3(0.5, 0.5, 0.5), _c("fff6d8"))
		glow.box(Vector3(x + 30, 0.3, -hw - 41), Vector3(0.45, 0.45, 0.45), _c("4f8cff"))
		x += 60.0
	# Luces de aproximación más allá de la cabecera +X (barras en postes)
	for k in 10:
		var xa := hl + 30.0 + k * 30.0
		var h := 1.5 + k * 0.6
		mb.use("metal")
		mb.tube(Vector3(xa, 0, 0), Vector3(xa, h, 0), 0.25, 0.2, 6, _c("d7dde3"))
		mb.box(Vector3(xa, h, 0), Vector3(0.4, 0.3, 9.0 if k % 3 == 2 else 4.0), _c("59626b"))
		var lights := 9 if k % 3 == 2 else 5
		for j in lights:
			glow.box(Vector3(xa, h + 0.3, -float(lights - 1) * 0.5 + j), Vector3(0.45, 0.35, 0.45), _c("fff2b0"))
	# PAPI (indicadores de pendiente): dos rojas y dos blancas
	for j in 4:
		mb.use("default")
		mb.chamfer_box(Vector3(hl - 300.0, 0.6, -hw - 14 - j * 3.5), Vector3(1.8, 1.2, 1.8), 0.2, _c("e0dcd0"))
		glow.box(Vector3(hl - 300.0 + 0.95, 0.7, -hw - 14 - j * 3.5), Vector3(0.1, 0.5, 0.9), _c("ff3b3b") if j < 2 else Color.WHITE)


## Valla del aeropuerto a lo largo del eje X local, de longitud `length`.
static func airport_fence(mb, length: float) -> void:
	var post := _c("8d969e")
	var mesh_col := _c("aab3bb")
	mb.use("metal")
	var x := -length * 0.5
	while x <= length * 0.5:
		mb.box(Vector3(x, 1.6, 0), Vector3(0.14, 3.2, 0.14), post)
		mb.beam(Vector3(x, 3.2, 0), Vector3(x, 3.7, -0.45), 0.08, post)
		x += 6.0
	for y: float in [0.25, 1.1, 1.95, 2.8]:
		mb.box(Vector3(0, y, 0), Vector3(length, 0.05, 0.05), mesh_col)
	for y: float in [3.35, 3.55]:
		mb.box(Vector3(0, y, -0.3 + (y - 3.35)), Vector3(length, 0.04, 0.04), mesh_col.darkened(0.2))


static func hangar(mb, glow) -> void:
	var wall := _c("dfe3e7")
	var roof := _c("9fb0bf")
	mb.use("default")
	mb.chamfer_box(Vector3(0, 5, 0), Vector3(44, 10, 30), 0.3, wall)
	# Techo abovedado
	mb.push_at(Vector3(0, 10, 0), Vector3(0, 0, 90), Vector3(1, 1, 1))
	mb.cylinder(Vector3(0, -22, 0), 15.5, 44, 12, roof, wall, -1.0)
	mb.pop()
	# Portón de chapa y franjas
	mb.box(Vector3(0, 6.5, -15.1), Vector3(38, 13, 0.3), _c("7c8a96"))
	for k in 9:
		mb.box(Vector3(-16 + k * 4, 6.5, -15.3), Vector3(0.2, 13, 0.2), _c("5f6b75"))
	mb.box(Vector3(0, 13.8, -15.3), Vector3(28, 2.2, 0.2), _c("2b6fe0"))
	glow.box(Vector3(-12, 12.0, -15.45), Vector3(1.2, 0.5, 0.1), _c("fff3c4"))
	glow.box(Vector3(12, 12.0, -15.45), Vector3(1.2, 0.5, 0.1), _c("fff3c4"))


static func windsock(mb) -> void:
	mb.use("metal")
	mb.tube(Vector3.ZERO, Vector3(0, 7, 0), 0.15, 0.1, 6, _c("d7dde3"))
	mb.use("cloth")
	for k in 5:
		var x0 := 0.2 + k * 0.8
		mb.tube(Vector3(x0, 6.9 - k * 0.12, 0), Vector3(x0 + 0.8, 6.9 - (k + 1) * 0.12, 0),
				0.55 - k * 0.07, 0.48 - k * 0.07, 8, _c("ff6a00") if k % 2 == 0 else Color.WHITE, k == 4)


# --- Edificios históricos --------------------------------------------------------------

## La Telegrafia: ladrillo modernista con torrecillas almenadas y antena Marconi.
static func telegrafia(mb, glow) -> void:
	var brick := _c("b9583a")
	var brick_d := _c("8d3f28")
	var stone := _c("efe2c6")
	mb.use("default")
	mb.chamfer_box(Vector3(0, 0.4, 0), Vector3(20, 0.8, 13), 0.1, stone)
	mb.chamfer_box(Vector3(0, 5, 0), Vector3(18, 8.4, 11), 0.15, brick, brick_d)
	# Franjas de piedra y almenas
	for y: float in [1.4, 4.6, 8.8]:
		mb.box(Vector3(0, y, 0), Vector3(18.3, 0.35, 11.3), stone)
	for i in 12:
		mb.box(Vector3(-8.25 + i * 1.5, 9.55, -5.5), Vector3(0.8, 1.0, 0.5), brick)
		mb.box(Vector3(-8.25 + i * 1.5, 9.55, 5.5), Vector3(0.8, 1.0, 0.5), brick)
	# Ventanas de arco (arco = ventana + "tejadillo" triangular)
	for i in 5:
		var x := -6.4 + i * 3.2
		for y: float in [2.0, 5.4]:
			glow.box(Vector3(x, y + 1.2, -5.55), Vector3(1.4, 2.2, 0.1), _c("ffe2a0") if (i + int(y)) % 3 == 0 else _c("3c4c5c"))
			mb.frustum(Vector3(x, y + 2.3, -5.6), Vector2(1.9, 0.25), Vector2(0.1, 0.25), 0.8, stone)
	# Torrecillas en las esquinas delanteras con remate cónico
	for s: float in [-1.0, 1.0]:
		mb.cylinder(Vector3(s * 9.0, 0, -5.5), 1.7, 12.5, 8, brick, brick_d)
		mb.cylinder(Vector3(s * 9.0, 12.5, -5.5), 2.0, 0.6, 8, stone)
		mb.use("paint")
		mb.cylinder(Vector3(s * 9.0, 13.1, -5.5), 2.0, 3.2, 8, _c("2f7d6d"), null, 0.0)
		mb.use("default")
	# Antena de telegrafía sin hilos
	mb.use("metal")
	mb.tube(Vector3(4, 9.0, 2), Vector3(4, 26, 2), 0.25, 0.1, 6, _c("4a525a"))
	for y: float in [14.0, 19.0, 24.0]:
		mb.beam(Vector3(2.5, y, 2), Vector3(5.5, y, 2), 0.1, _c("4a525a"))
	glow.sphere(Vector3(4, 26.3, 2), Vector3(0.35, 0.35, 0.35), 5, 3, _c("ff3b3b"))


## Chimenea de ladrillo de la antigua fábrica Torras Hostench.
static func factory_chimney(mb) -> void:
	var brick := _c("b4553a")
	mb.use("default")
	mb.chamfer_box(Vector3(0, 2.0, 0), Vector3(5.4, 4.0, 5.4), 0.2, _c("c97b5c"))
	mb.box(Vector3(0, 4.2, 0), Vector3(5.8, 0.4, 5.8), _c("e7d4b5"))
	mb.cylinder(Vector3(0, 4.4, 0), 2.1, 30.0, 10, brick, null, 1.15)
	for y: float in [12.0, 22.0, 32.0]:
		var r := lerpf(2.1, 1.15, (y - 4.4) / 30.0) + 0.12
		mb.cylinder(Vector3(0, y, 0), r, 0.5, 10, _c("e7d4b5"), null, -1.0, false)
	mb.cylinder(Vector3(0, 34.4, 0), 1.5, 1.2, 10, brick.darkened(0.15), _c("2a2a2a"), 1.4)


## Mirador del Parc del Riu: torre metálica con plataforma.
static func lookout(mb) -> void:
	mb.use("metal")
	for p: Vector2 in [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]:
		mb.tube(Vector3(p.x * 1.4, 0, p.y * 1.4), Vector3(p.x, 14, p.y), 0.22, 0.18, 6, _c("4f6d7a"))
	for y: float in [4.0, 8.0, 12.0]:
		mb.box(Vector3(0, y, 0), Vector3(4.6, 0.2, 4.6), _c("4f6d7a"))
	mb.use("default")
	mb.chamfer_box(Vector3(0, 14.2, 0), Vector3(6.0, 0.5, 6.0), 0.1, _c("b07a46"))
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(s * 2.9, 15.0, 0), Vector3(0.12, 1.1, 6.0), _c("4f6d7a"))
		mb.box(Vector3(0, 15.0, s * 2.9), Vector3(6.0, 1.1, 0.12), _c("4f6d7a"))


## Casa de la Vila (neogótica): torre central con reloj, arcos apuntados y senyera.
static func casa_de_la_vila(mb, glow) -> void:
	var stone := _c("efe0bf")
	var trim := _c("b88b5a")
	mb.use("default")
	mb.chamfer_box(Vector3(0, 5.5, 0), Vector3(24, 11, 12), 0.2, stone, _c("b06a4a"))
	mb.box(Vector3(0, 11.2, 0), Vector3(24.4, 0.5, 12.4), trim)
	# Arcos apuntados de la planta baja y ventanas góticas
	for i in 6:
		var x := -9.0 + i * 3.6
		mb.box(Vector3(x, 1.9, -6.05), Vector3(2.2, 3.4, 0.1), _c("3f3428"))
		mb.frustum(Vector3(x, 3.6, -6.1), Vector2(2.4, 0.25), Vector2(0.05, 0.25), 1.6, trim)
		glow.box(Vector3(x, 7.2, -6.05), Vector3(1.4, 2.6, 0.1), _c("ffe2a0") if i % 2 == 0 else _c("40546a"))
		mb.frustum(Vector3(x, 8.5, -6.1), Vector2(1.7, 0.2), Vector2(0.05, 0.2), 1.1, trim)
	# Balcón central
	mb.box(Vector3(0, 5.2, -6.7), Vector3(7.0, 0.3, 1.4), trim)
	mb.box(Vector3(0, 5.8, -7.35), Vector3(7.0, 0.9, 0.1), _c("3a3f46"))
	# Torre del reloj con pináculos
	mb.chamfer_box(Vector3(0, 14.5, -2), Vector3(5.0, 7.0, 5.0), 0.1, stone, trim)
	mb.use("paint")
	mb.cylinder(Vector3(0, 18.0, -2), 3.6, 4.5, 4, _c("6b4a3a"), null, 0.0)
	mb.use("default")
	for p: Vector2 in [Vector2(-2.4, -4.4), Vector2(2.4, -4.4), Vector2(-2.4, 0.4), Vector2(2.4, 0.4)]:
		mb.cylinder(Vector3(p.x, 18.0, p.y), 0.35, 2.4, 6, trim, null, 0.0)
	mb.push_at(Vector3(0, 15.0, -4.55), Vector3(90, 0, 0))
	mb.cylinder(Vector3.ZERO, 1.5, 0.1, 12, Color.WHITE)
	mb.pop()
	mb.box(Vector3(0, 15.3, -4.65), Vector3(0.12, 1.0, 0.05), _c("1d1d1d"))
	mb.box(Vector3(0.35, 15.0, -4.65), Vector3(0.75, 0.12, 0.05), _c("1d1d1d"))
	# Mástil con la senyera (amarilla con cuatro barras rojas)
	mb.use("metal")
	mb.tube(Vector3(-3.0, 6.0, -7.3), Vector3(-5.6, 9.0, -8.6), 0.07, 0.06, 6, _c("d7dde3"))
	mb.use("cloth")
	for k in 9:
		var y := 8.8 - k * 0.2
		mb.box(Vector3(-6.5, y, -8.6), Vector3(1.8, 0.2, 0.05), _c("fcd116") if k % 2 == 0 else _c("da121a"))


## Parroquia con nave, rosetón y campanario.
static func church(mb, glow) -> void:
	var stone := _c("e3d2b0")
	var roof := _c("b45a3c")
	mb.use("default")
	mb.chamfer_box(Vector3(0, 6, 3), Vector3(12, 12, 22), 0.15, stone)
	# Tejado a dos aguas
	for s: float in [-1.0, 1.0]:
		mb.quad(Vector3(s * 6.4, 12, -8.2), Vector3(0, 16.5, -8.2), Vector3(0, 16.5, 14.2), Vector3(s * 6.4, 12, 14.2), roof, Vector3(s, 1.2, 0))
	mb.tri(Vector3(-6.0, 12, -8.0), Vector3(6.0, 12, -8.0), Vector3(0, 16.2, -8.0), stone, Vector3.FORWARD)
	mb.tri(Vector3(-6.0, 12, 14.0), Vector3(6.0, 12, 14.0), Vector3(0, 16.2, 14.0), stone, Vector3.BACK)
	# Portada y rosetón
	mb.box(Vector3(0, 3.0, -8.05), Vector3(3.2, 6.0, 0.1), _c("5a3b2a"))
	mb.frustum(Vector3(0, 6.0, -8.1), Vector2(4.0, 0.3), Vector2(0.1, 0.3), 2.0, _c("cdb68c"))
	glow.push_at(Vector3(0, 10.2, -8.1), Vector3(90, 0, 0))
	glow.cylinder(Vector3.ZERO, 1.6, 0.1, 12, _c("f6c86a"))
	glow.pop()
	for k in 8:
		var a := TAU * k / 8.0
		mb.box(Vector3(cos(a) * 0.9, 10.2 + sin(a) * 0.9, -8.2), Vector3(0.15, 0.15, 0.06), _c("6b4a3a"))
	# Campanario
	mb.chamfer_box(Vector3(7.5, 11, -5), Vector3(5, 22, 5), 0.1, stone, stone)
	for s: float in [-1.0, 1.0]:
		mb.box(Vector3(7.5 + s * 1.2, 19.5, -7.55), Vector3(1.0, 3.0, 0.1), _c("2a2a2a"))
	mb.box(Vector3(7.5, 22.2, -5), Vector3(5.6, 0.5, 5.6), _c("cdb68c"))
	mb.use("paint")
	mb.cylinder(Vector3(7.5, 22.4, -5), 3.6, 5.0, 4, roof, null, 0.0)
	mb.use("metal")
	mb.tube(Vector3(7.5, 27.4, -5), Vector3(7.5, 29.6, -5), 0.1, 0.08, 6, _c("3a3a3a"))
	mb.box(Vector3(7.5, 29.0, -5), Vector3(1.0, 0.12, 0.12), _c("3a3a3a"))


## Mercat municipal (noucentista): nave alargada, frontón y arcos.
static func mercat(mb, glow) -> void:
	var wall := _c("f1dfb8")
	var trim := _c("c26a3d")
	mb.use("default")
	mb.chamfer_box(Vector3(0, 4.5, 0), Vector3(30, 9, 18), 0.2, wall)
	for s: float in [-1.0, 1.0]:
		mb.quad(Vector3(-15.3, 9, s * 9.3), Vector3(15.3, 9, s * 9.3), Vector3(15.3, 12.5, 0), Vector3(-15.3, 12.5, 0), _c("9aa9b3"), Vector3(0, 1, s))
	# Frontón con el rótulo
	mb.tri(Vector3(-8, 9, -9.05), Vector3(8, 9, -9.05), Vector3(0, 13.0, -9.05), wall, Vector3.FORWARD)
	mb.box(Vector3(0, 9.0, -9.2), Vector3(17, 0.5, 0.3), trim)
	for i in 7:
		var x := -12.0 + i * 4.0
		glow.box(Vector3(x, 4.2, -9.05), Vector3(2.6, 5.0, 0.1), _c("ffe6b0") if i % 2 == 1 else _c("3c4c5c"))
		mb.cylinder(Vector3(x, 6.7, -9.1), 1.45, 0.1, 8, trim, null, -1.0, false)
	mb.box(Vector3(0, 0.6, -10.5), Vector3(30, 0.15, 3.0), _c("c9b9a0"))
	for k in 6:
		mb.use("cloth")
		mb.box(Vector3(-12.5 + k * 5, 3.4, -10.6), Vector3(4.6, 0.12, 2.6), _c(Props.AWNING_COLORS[k % Props.AWNING_COLORS.size()]))
		mb.use("default")


# --- Río Llobregat -----------------------------------------------------------------------

## Tramo de río a lo largo del eje Z local, con orillas, cañas y paseo.
static func river(mb, rng: RandomNumberGenerator, length: float, width: float) -> void:
	var hl := length * 0.5
	var hw := width * 0.5
	mb.use("default")
	# Agua y motas (diques) a ambos lados, como el Llobregat canalizado
	mb.quad(Vector3(-hw, 0.05, -hl), Vector3(hw, 0.05, -hl), Vector3(hw, 0.05, hl), Vector3(-hw, 0.05, hl), _c("4f8fb0"), Vector3.UP)
	for s: float in [-1.0, 1.0]:
		mb.quad(Vector3(s * hw, 0.05, -hl), Vector3(s * (hw + 5), 1.6, -hl), Vector3(s * (hw + 5), 1.6, hl), Vector3(s * hw, 0.05, hl), _c("7e8f5a"), Vector3(-s, 2.0, 0))
		# Paseo de tierra sobre la mota y talud exterior
		mb.quad(Vector3(s * (hw + 5), 1.6, -hl), Vector3(s * (hw + 10), 1.6, -hl), Vector3(s * (hw + 10), 1.6, hl), Vector3(s * (hw + 5), 1.6, hl), _c("d9c39a"), Vector3.UP)
		mb.quad(Vector3(s * (hw + 10), 1.6, -hl), Vector3(s * (hw + 15), 0.0, -hl), Vector3(s * (hw + 15), 0.0, hl), Vector3(s * (hw + 10), 1.6, hl), _c("8fa064"), Vector3(s, 2.0, 0))
	# Reflejos alargados
	for k in 30:
		var z := rng.randf_range(-hl, hl)
		var x := rng.randf_range(-hw * 0.8, hw * 0.8)
		mb.quad(Vector3(x - 0.15, 0.07, z - 4), Vector3(x + 0.15, 0.07, z - 4), Vector3(x + 0.15, 0.07, z + 4), Vector3(x - 0.15, 0.07, z + 4), _c("9fd0e6"), Vector3.UP)
	# Cañas en las orillas
	mb.use("cloth")
	for k in 140:
		var s := -1.0 if k % 2 == 0 else 1.0
		var x := s * rng.randf_range(hw - 1.0, hw + 4.0)
		var z := rng.randf_range(-hl, hl)
		var h := rng.randf_range(1.6, 3.2)
		var lean := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
		mb.slab(Vector3(x, 0.0, z), Vector3(x, h, z) + lean, 0.18, 0.04, 0.06, _c("8aa64a").lerp(_c("c6b765"), rng.randf()), Vector3(1, 0, 0))


## Plátano de sombra (árbol típico de las avenidas).
static func plane_tree(mb, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(5.5, 7.5)
	mb.use("default")
	mb.tube(Vector3.ZERO, Vector3(0, h, 0), 0.35, 0.25, 6, _c("a59a83"))
	mb.use("cloth")
	var green := _c("5f9a3e").lerp(_c("77ad48"), rng.randf())
	for k in 4:
		var off := Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(-0.3, 1.0), rng.randf_range(-1.4, 1.4))
		mb.sphere(Vector3(0, h + 0.8, 0) + off, Vector3(2.2, 1.8, 2.2) * rng.randf_range(0.8, 1.1), 7, 4, green if k % 2 == 0 else green.darkened(0.12))


# --- Señalética ------------------------------------------------------------------------

## Pórtico de señalización sobre la carretera (eje X local = ancho de vía).
## Devuelve la posición local del panel para colocar los textos.
static func sign_gantry(mb, span: float) -> Vector3:
	var hs := span * 0.5
	mb.use("metal")
	for s: float in [-1.0, 1.0]:
		mb.tube(Vector3(s * hs, 0, 0), Vector3(s * hs, 7.2, 0), 0.25, 0.22, 8, _c("8e99a3"))
		mb.box(Vector3(s * hs, 0.25, 0), Vector3(1.0, 0.5, 1.0), _c("b2bec3"))
	mb.box(Vector3(0, 7.0, 0), Vector3(span, 0.3, 0.3), _c("8e99a3"))
	mb.box(Vector3(0, 7.6, 0), Vector3(span, 0.2, 0.2), _c("8e99a3"))
	mb.use("paint")
	mb.chamfer_box(Vector3(0, 6.2, -0.25), Vector3(10.0, 2.6, 0.15), 0.12, _c("1f4fa0"))
	mb.box(Vector3(0, 6.2, -0.34), Vector3(9.6, 2.2, 0.02), Color.WHITE)
	mb.box(Vector3(0, 6.2, -0.355), Vector3(9.4, 2.0, 0.02), _c("1f4fa0"))
	return Vector3(0, 6.2, -0.4)


## Placa azul de calle (estilo de las placas catalanas). La fachada mira a -Z.
static func street_plaque(mb) -> void:
	mb.use("paint")
	mb.chamfer_box(Vector3.ZERO, Vector3(3.2, 0.9, 0.08), 0.06, Color.WHITE)
	mb.box(Vector3(0, 0, -0.045), Vector3(3.0, 0.72, 0.02), _c("1f4fa0"))


## Cruz verde de farmacia luminosa sobre soporte.
static func pharmacy_cross(mb, glow) -> void:
	mb.use("metal")
	mb.beam(Vector3(0, 0, 0), Vector3(0, 0, -1.0), 0.12, _c("4a525a"))
	glow.box(Vector3(0, 0, -1.2), Vector3(0.45, 1.3, 0.25), _c("22c55e"))
	glow.box(Vector3(0, 0, -1.2), Vector3(1.3, 0.45, 0.25), _c("22c55e"))
