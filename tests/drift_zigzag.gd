extends SceneTree
## Herramienta de ajuste: zigzag en recta. Alterna el volante de un lado a otro (cantidad y
## ritmo variables), soltando el gas al cambiar de lado y pisando al cruzar el centro.
## Cuenta derrapes, mini-turbos y cuánto se aparta el kart de la línea recta.
##   godot --headless --path . --fixed-fps 60 -s res://tests/drift_zigzag.gd [-- param=valor ...]
var kart
var ev := []
func _initialize(): _run()
func _frames(n): for i in n: await physics_frame
func _slip() -> float: return rad_to_deg(absf(kart.slip_angle))
func _run():
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var w := Node3D.new(); get_root().add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); cs.shape = WorldBoundaryShape3D.new(); g.add_child(cs); w.add_child(g)
	kart = load("res://scenes/kart.tscn").instantiate(); w.add_child(kart); kart.controls_enabled = true
	for a in OS.get_cmdline_user_args():
		var kv = a.split("=")
		if kv.size() == 2: kart.set(kv[0], float(kv[1]))
	kart.drift_event.connect(func(k, l): ev.append(k))
	for amount in [0.5, 0.6, 0.7, 0.85]:
		var row := "volante %3d%%:" % int(amount * 100)
		for half in [0.5, 0.7, 0.9]:
			ev.clear()
			kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
			kart.input_override = {"accelerate": 1.0}
			await _frames(200)
			var x0: float = kart.global_position.x
			var maxdev := 0.0
			var speed_sum := 0.0
			var n := int(half * 60)
			var side := 1.0
			for k in 8:
				# el primer tramo dura la mitad para que el zigzag oscile alrededor de la recta.
				# Suelta el gas al empezar a girar al otro lado y pisa a los 0,15 s.
				var steps := n / 2 if k == 0 else n
				for i in steps:
					var gas := 0.0 if i < 9 and k > 0 else 1.0
					var d := {"accelerate": gas}
					d["steer_right" if side > 0 else "steer_left"] = amount
					kart.input_override = d
					await physics_frame
					maxdev = maxf(maxdev, absf(kart.global_position.x - x0))
					speed_sum += kart.get_speed_kmh()
				side = -side
			var slides := ev.count("slide")
			var turbos := ev.count("success")
			row += "  %.1fs/lado: %d derrapes %d turbos, ±%.0f m, %.0f km/h" % [half, slides, turbos, maxdev, speed_sum / (7 * n + n / 2)]
		print("[zigzag] ", row)
	quit()
