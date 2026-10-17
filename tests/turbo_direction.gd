extends SceneTree
## Herramienta: ¿hacia dónde empuja el mini-turbo? Derrape a la derecha, contravolante,
## suelta y pisa. Mide, desde que salta, el ángulo entre la velocidad y el morro y cuánto
## se desplaza el kart de lado respecto a la dirección en la que apuntaba al saltar.
##   godot --headless --path . --fixed-fps 60 -s res://tests/turbo_direction.gd
var kart
var fired := false
func _initialize(): _run()
func _slip() -> float: return rad_to_deg(absf(kart.slip_angle))
func _vel_vs_nose() -> float:
	var fwd: Vector3 = -kart.global_transform.basis.z
	var v := Vector3(kart.velocity.x, 0, kart.velocity.z)
	return rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(v.x, v.z)))
func _run():
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var w := Node3D.new(); get_root().add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); cs.shape = WorldBoundaryShape3D.new(); g.add_child(cs); w.add_child(g)
	kart = load("res://scenes/kart.tscn").instantiate(); w.add_child(kart); kart.controls_enabled = true
	kart.drift_event.connect(func(k, _l): if k == "success": fired = true)
	for mode in ["suelta", "contra", "derecha"]:
		var fire_deg := 14.0
		fired = false
		kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
		kart.input_override = {"accelerate": 1.0}
		for i in 240: await physics_frame
		kart.input_override = {"accelerate": 0.0, "steer_right": 1.0}
		for i in 40: await physics_frame
		kart.input_override = {"accelerate": 0.0, "steer_left": 1.0}
		while _slip() > fire_deg: await physics_frame
		# pisa: soltando el volante, manteniendo el contravolante o girando aún hacia el derrape
		var hold := {"accelerate": 1.0}
		if mode == "contra": hold["steer_left"] = 0.5
		if mode == "derecha": hold["steer_right"] = 0.5
		kart.input_override = hold
		var guard := 0
		while not fired and guard < 60:
			await physics_frame
			guard += 1
		var fwd0: Vector3 = -kart.global_transform.basis.z
		fwd0.y = 0; fwd0 = fwd0.normalized()
		var right0 := Vector3(-fwd0.z, 0, fwd0.x)
		var p0: Vector3 = kart.global_position
		var a01 := 0.0
		var amax := 0.0
		var yaw_turn := 0.0
		var y0: float = kart.rotation.y
		for i in 36:
			if i == 18: kart.input_override = {"accelerate": 1.0}
			await physics_frame
			amax = maxf(amax, absf(_vel_vs_nose()))
			if i == 5: a01 = absf(_vel_vs_nose())
		yaw_turn = rad_to_deg(absf(wrapf(kart.rotation.y - y0, -PI, PI)))
		var d: Vector3 = kart.global_position - p0
		print("[dir] %-7s salta a %2d° de cruce: velocidad vs. morro a 0,1 s %.1f° (máx. %.1f°); en 0,6 s avanza %.1f m y se va de lado %.2f m; el morro sigue girando %.1f°" % [mode, int(fire_deg), a01, amax, d.dot(fwd0), absf(d.dot(right0)), yaw_turn])
	quit()
