extends SceneTree
## Fotos de estudio de los corredores para compararlos con sus láminas originales.
## Uso (necesita render, no --headless; en servidor: xvfb-run):
##   godot --path . --resolution 960x720 -s res://tests/racer_gallery.gd -- --out=<carpeta> [--racers=zule,giovanni]
## Por corredor: frente 3/4, trasera 3/4, perfil, cara, vista de conducción (cámara de juego)
## y vista "mirar atrás".

const KartScene := preload("res://scenes/kart.tscn")
const Roster := preload("res://scripts/racers/roster.gd")

var _out := "user://gallery"
var _racers: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--racers="):
			_racers = Array(a.substr(9).split(","))
	if _racers.is_empty():
		_racers = Roster.ids()
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _run() -> void:
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	preload("res://scripts/game/lighting.gd").build(root3d)
	var env: Environment = (root3d.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.fog_enabled = false
	# Suelo de estudio: asfalto con una línea, para ver sombras y escala
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("4b4f5c")
	gm.roughness = 0.9
	ground.material_override = gm
	root3d.add_child(ground)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	root3d.add_child(body)

	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.current = true
	for id in _racers:
		var kart = KartScene.instantiate()
		kart.racer_id = id
		root3d.add_child(kart)
		kart.place(Transform3D(Basis(), Vector3(0, 0.05, 0)))
		kart.set_physics_process(false)
		for i in 3:
			await process_frame
		var k: Vector3 = kart.global_position
		var fwd := Vector3(0, 0, -1)
		var right := Vector3(1, 0, 0)
		var shots := [
			["frente", k + fwd * 3.7 + right * 2.2 + Vector3.UP * 1.5, k + Vector3.UP * 0.95, 42.0],
			["detras", k - fwd * 3.8 - right * 2.1 + Vector3.UP * 1.6, k + Vector3.UP * 0.95, 42.0],
			["perfil", k + right * 4.8 - fwd * 0.2 + Vector3.UP * 1.1, k + Vector3.UP * 0.9, 42.0],
			["cara", k + fwd * 1.5 + right * 0.35 + Vector3.UP * 1.62, k + Vector3.UP * 1.38 - fwd * 0.2, 38.0],
			["conduccion", k - fwd * 4.6 + Vector3.UP * 1.9, k + fwd * 3.0 + Vector3.UP * 0.6, 65.0],
		]
		for s in shots:
			cam.global_position = s[1]
			cam.look_at(s[2], Vector3.UP)
			cam.fov = s[3]
			# Pose de conducción: algo de volante y suspensión asentada
			kart.model.update_visual({"speed": 0.0, "speed_ratio": 0.0, "steer": 0.25 if s[0] == "conduccion" else 0.0,
				"drifting": false, "drift_dir": 0, "yaw_rate": 0.0, "boost": false, "distance": 0.0,
				"grounded": true, "braking": false, "look_back": false}, 0.5)
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := get_root().get_texture().get_image()
			img.save_png(_out.path_join("%s_%s.png" % [id, s[0]]))
		print("[galeria] ", id, " triángulos: ", _count_tris(kart), " superficies: ", _count_surfaces(kart))
		kart.queue_free()
		await process_frame
	quit(0)


static func _count_tris(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and n.mesh != null and n.visible:
		for s in n.mesh.get_surface_count():
			var arr: Array = n.mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
	for c in n.get_children():
		t += _count_tris(c)
	return t


static func _count_surfaces(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and n.mesh != null and n.visible:
		t += n.mesh.get_surface_count()
	for c in n.get_children():
		t += _count_surfaces(c)
	return t
