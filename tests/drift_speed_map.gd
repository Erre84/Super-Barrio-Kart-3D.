extends SceneTree
## Herramienta de ajuste: ¿a partir de qué velocidad se puede derrapar?
## Para cada velocidad de crucero (mantenida dosificando el gas) hace un zigzag en recta con el
## volante al 75 % cambiando de lado cada 0,5 s y soltando el gas en cada cambio.
## Cuenta derrapes, mini-turbos y la deriva máxima.
##   godot --headless --path . --fixed-fps 60 -s res://tests/drift_speed_map.gd [-- param=valor ...]
var kart
var ev := []
func _initialize(): _run()
func _slip() -> float: return rad_to_deg(absf(kart.slip_angle))
func _run():
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var w := Node3D.new(); get_root().add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); cs.shape = WorldBoundaryShape3D.new(); g.add_child(cs); w.add_child(g)
	kart = load("res://scenes/kart.tscn").instantiate(); w.add_child(kart); kart.controls_enabled = true
	var amount := 0.75
	for a in OS.get_cmdline_user_args():
		var kv = a.split("=")
		if kv.size() == 2:
			if kv[0] == "amount": amount = float(kv[1])
			else: kart.set(kv[0], float(kv[1]))
	kart.drift_event.connect(func(k, _l): ev.append(k))
	print("[speed] zigzag al %d%% de volante, cambio cada 0,5 s" % int(amount * 100))
	for kmh in [40, 50, 55, 60, 65, 70, 75, 80, 90, 104]:
		ev.clear()
		kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
		kart.input_override = {"accelerate": 1.0}
		var guard := 0
		while kart.get_speed_kmh() < kmh - 1 and guard < 600:
			await physics_frame
			guard += 1
		var mx := 0.0
		var side := 1.0
		var frames := 15   # primer tramo: la mitad
		var vsum := 0.0
		var n := 0
		for change in 7:
			for i in frames:
				var lift := i < 9 and change > 0
				var gas := 0.0 if lift else (1.0 if kart.get_speed_kmh() < kmh else 0.0)
				var o := {"accelerate": gas}
				o["steer_right" if side > 0 else "steer_left"] = amount
				kart.input_override = o
				await physics_frame
				mx = maxf(mx, _slip())
				vsum += kart.get_speed_kmh(); n += 1
			frames = 30
			side = -side
		kart.input_override = {"accelerate": 1.0}
		for i in 60:
			await physics_frame
		var slides := ev.count("slide")
		var turbos := ev.count("success")
		print("[speed] %3d km/h (media %3d): derrapes %d, mini-turbos %d, deriva máx %4.1f°" % [kmh, int(vsum / maxf(n, 1)), slides, turbos, mx])
	quit()
