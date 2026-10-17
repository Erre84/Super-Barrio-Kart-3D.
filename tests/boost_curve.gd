extends SceneTree
## Herramienta: curva de velocidad de un mini-turbo de nivel 3 (derrape largo, suelta y pisa).
##   godot --headless --path . --fixed-fps 60 -s res://tests/boost_curve.gd
var kart
func _initialize(): _run()
func _slip() -> float: return rad_to_deg(absf(kart.slip_angle))
func _run():
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var w := Node3D.new(); get_root().add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); cs.shape = WorldBoundaryShape3D.new(); g.add_child(cs); w.add_child(g)
	kart = load("res://scenes/kart.tscn").instantiate(); w.add_child(kart); kart.controls_enabled = true
	kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
	kart.input_override = {"accelerate": 1.0}
	for i in 240: await physics_frame
	kart.input_override = {"accelerate": 0.0, "steer_right": 1.0}
	for i in 40: await physics_frame
	kart.input_override = {"accelerate": 0.0, "steer_left": 1.0}
	while _slip() > 12.0: await physics_frame
	kart.input_override = {"accelerate": 1.0}
	var top: float = kart.max_speed * 3.6 + 1.5
	var above := 0.0
	var vmax := 0.0
	var row := ""
	var ev := []
	kart.drift_event.connect(func(k, l): ev.append("%s%d" % [k, l]))
	for i in 300:
		await physics_frame
		var v: float = kart.get_speed_kmh()
		vmax = maxf(vmax, v)
		if v > top: above += 1.0 / 60.0
		if i % 30 == 0: row += " %d" % int(v)
	print("[curva] km/h cada 0,5 s:", row)
	print("[curva] pico %.0f km/h, por encima de la punta %.1f s, eventos %s" % [vmax, above, ev])
	quit()
