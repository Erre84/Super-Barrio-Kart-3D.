extends SceneTree
## Herramienta: giro a baja velocidad (recuperarse tras un choque).
##   godot --headless --path . --fixed-fps 60 -s res://tests/low_speed_turn.gd
## A) Parado, gas y volante a fondo: cuánto gira en 0,5 / 1 / 1,5 s y a qué velocidad va.
## B) Radio de giro con el volante a fondo manteniendo 20 / 35 / 50 / 80 / 104 km/h.
var kart
func _initialize(): _run()
func _run():
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var w := Node3D.new(); get_root().add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); cs.shape = WorldBoundaryShape3D.new(); g.add_child(cs); w.add_child(g)
	kart = load("res://scenes/kart.tscn").instantiate(); w.add_child(kart); kart.controls_enabled = true
	kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
	for i in 10: await physics_frame
	var y0: float = kart.rotation.y
	kart.input_override = {"accelerate": 1.0, "steer_left": 1.0}
	var row := ""
	for i in 90:
		await physics_frame
		if (i + 1) % 30 == 0:
			row += "  %.1f s: %3d° a %2d km/h" % [(i + 1) / 60.0, int(rad_to_deg(absf(wrapf(kart.rotation.y - y0, -PI, PI)))), int(kart.get_speed_kmh())]
	print("[giro] desde parado, gas + volante a fondo:", row)
	row = ""
	for kmh in [20, 35, 50, 80, 104]:
		kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
		kart.input_override = {"accelerate": 1.0}
		var guard := 0
		while kart.get_speed_kmh() < kmh - 1 and guard < 600:
			await physics_frame
			guard += 1
		var yaw_sum := 0.0
		var v_sum := 0.0
		for i in 90:
			kart.input_override = {"accelerate": 1.0 if kart.get_speed_kmh() < kmh else 0.0, "steer_left": 1.0}
			await physics_frame
			if i >= 30:
				yaw_sum += absf(kart.yaw_rate)
				v_sum += kart.get_speed_kmh() / 3.6
		var yr := yaw_sum / 60.0
		row += "  %d km/h: %.1f m (%.2f rad/s)" % [kmh, (v_sum / 60.0) / maxf(yr, 0.001), yr]
	print("[giro] radio con volante a fondo:", row)
	quit()
