extends SceneTree
## Herramienta de ajuste: ¿da turbo soltar y pisar X segundos después de enderezar?
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
	kart.drift_event.connect(func(k, l): ev.append(k))
	for hold in [20, 30, 45]:
		for delay in [0.1, 0.3, 0.5, 0.7, 0.9, 1.2]:
			ev.clear()
			kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
			kart.input_override = {"accelerate": 1.0}
			await _frames(200)
			kart.input_override = {"accelerate": 1.0, "steer_right": 1.0}
			await _frames(hold)
			kart.input_override = {"accelerate": 1.0, "steer_left": 1.0}
			var st := -1
			for i in 200:
				await physics_frame
				if _slip() < 4.0 and st < 0:
					st = i
					kart.input_override = {"accelerate": 1.0}
				if st >= 0 and i == st + int(delay * 60): kart.input_override = {}
				if st >= 0 and i == st + int(delay * 60) + 8: kart.input_override = {"accelerate": 1.0}
			print("[late] volantazo %.2fs · suelta %.1fs tras enderezar: %s %s" % [hold / 60.0, delay, "TURBO" if "success" in ev else "nada ", str(ev)])
	quit()
