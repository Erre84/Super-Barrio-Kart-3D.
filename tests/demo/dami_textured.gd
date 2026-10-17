extends "res://scripts/racers/dami.gd"
## PRUEBA (no se usa en el juego): Dami con la cara de su dibujo original como textura
## sobre una cabeza suave, en lugar de ojos, gafas y barba hechos con piezas.

func _build_head_shape(mb: MB, hc: Vector3) -> void:
	mb.use("skin")
	mb.cylinder(Vector3(0, -0.04, 0), 0.075, 0.14, 10, _col("skin"))
	var head := MeshInstance3D.new()
	head.name = "TexturedHead"
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 40
	sm.rings = 20
	head.mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://tests/demo/cara_textura.gdshader")
	mat.set_shader_parameter("face", load("res://tests/demo/dami_cara.png"))
	head.material_override = mat
	head.scale = Vector3(0.37, 0.42, 0.36)
	head.position = hc + Vector3(0, -0.02, 0)
	head_pivot.add_child(head)


func _build_hair(mb: MB, hc: Vector3) -> void:
	# Solo la coleta de rastas (los lados rapados van en la textura)
	var knot := hc + Vector3(0, 0.56, 0.08)
	for i in 7:
		var a := TAU * i / 7
		var root := hc + Vector3(cos(a) * 0.12, 0.33, sin(a) * 0.1 + 0.04)
		mb.tube(root, knot + Vector3(cos(a) * 0.04, -0.04, sin(a) * 0.04), 0.045, 0.04, 6, [DREAD, DREAD_LO][i % 2], false)
	mb.use("cloth")
	mb.sphere(hc + Vector3(0, 0.12, 0.06), Vector3(0.22, 0.32, 0.3), 12, 5, DREAD_LO, 0.0, PI * 0.42)
	mb.sphere(knot, Vector3(0.1, 0.07, 0.1), 10, 5, DREAD_LO)
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
		mb.tube(p0, p1, 0.036, 0.034, 6, col, false)
		mb.tube(p1, p2, 0.034, 0.032, 6, col, false)
		mb.tube(p2, p3, 0.032, 0.026, 6, col)


func _build_head_extras(_mb: MB, _hc: Vector3) -> void:
	pass   # las gafas ya están en la textura


func _build_face(_hc: Vector3) -> void:
	# La cara es la textura: solo hacen falta los nodos de boca que usa la animación
	_mouth_smile = Node3D.new()
	_mouth_grin = Node3D.new()
	head_pivot.add_child(_mouth_smile)
	head_pivot.add_child(_mouth_grin)


func _setup_style() -> void:
	super._setup_style()
	style["beard"] = null
