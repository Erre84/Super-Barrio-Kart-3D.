extends SceneTree
## Mapa de facilidad del derrape (herramienta de ajuste, no es una prueba):
##   godot --headless --path . --fixed-fps 60 -s res://tests/drift_ease_map.gd [-- grip_peak=15 ...]
## Para cada velocidad y cantidad de volante: ·=agarra, D=derrapa, T=abre ventana de mini-turbo.
var kart
func _initialize(): _run()
func _frames(n): for i in n: await physics_frame
func _slip(): return rad_to_deg(absf(kart.slip_angle))
func _run():
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var w := Node3D.new(); get_root().add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); cs.shape = WorldBoundaryShape3D.new(); g.add_child(cs); w.add_child(g)
	kart = load("res://scenes/kart.tscn").instantiate(); w.add_child(kart); kart.controls_enabled = true
	for a in OS.get_cmdline_user_args():
		var kv = a.split("=")
		if kv.size() == 2: kart.set(kv[0], float(kv[1]))
	var ev := []
	kart.drift_event.connect(func(k, l): ev.append(k))
	print("[ease] filas: velocidad; columnas: volante (giro de 0,5 s y contravolante). D=derrapa, T=abre ventana de turbo, ·=agarra")
	for kmh in [50, 65, 80, 104]:
		var row := "%3d km/h:" % kmh
		for st in [0.4, 0.55, 0.7, 0.85, 1.0]:
			ev.clear()
			kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
			kart.input_override = {"accelerate": 1.0}
			while kart.get_speed_kmh() < kmh - 1 and kart.get_speed_kmh() < 104:
				await physics_frame
			kart.input_override = {"accelerate": 0.0 if kmh < 100 else 1.0, "steer_right": st}
			var mx := 0.0
			for i in 30:
				await physics_frame
				mx = maxf(mx, _slip())
			kart.input_override = {"accelerate": 1.0, "steer_left": 1.0}
			for i in 150:
				await physics_frame
				mx = maxf(mx, _slip())
				if _slip() < 4.0: kart.input_override = {"accelerate": 1.0}
				if kart.drift_state != 1 and i > 5: break
			var c := "T" if ("window" in ev or "success" in ev) else ("D" if "slide" in ev else "·")
			row += "  %.2f:%s(%2d°)" % [st, c, int(mx)]
		print("[ease] ", row)
	quit()
