extends SceneTree
## Controlabilidad (herramienta de ajuste): derrape sostenido, enderezar, trompos, eses.
##   godot --headless --path . --fixed-fps 60 -s res://tests/drift_control.gd [-- parámetro=valor ...]
var kart
func _initialize(): _run()
func _frames(n): for i in n: await physics_frame
func _slip(): return rad_to_deg(absf(kart.slip_angle))
func _go(kmh := 104.0):
	kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
	kart.input_override = {"accelerate": 1.0}
	while kart.get_speed_kmh() < kmh - 1 and kart.get_speed_kmh() < 104: await physics_frame
	await _frames(5)
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
	# Sostenido a fondo 2,5 s
	await _go(); ev.clear()
	kart.input_override = {"accelerate": 1.0, "steer_right": 1.0}
	var mx := 0.0
	await _frames(60)
	var mn := 99.0
	for i in 90:
		await physics_frame
		mx = maxf(mx, _slip()); mn = minf(mn, _slip())
	var spin := "fail_spin" in ev
	# Enderezar
	var rt := {}
	for mode in ["contra", "neutro"]:
		await _go()
		kart.input_override = {"accelerate": 1.0, "steer_right": 1.0}
		await _frames(45)
		kart.input_override = {"accelerate": 1.0, "steer_left": 1.0} if mode == "contra" else {"accelerate": 1.0}
		var t := 0.0
		while _slip() > 5.0 and t < 4.0:
			await physics_frame
			t += 1.0 / 60.0
			if mode == "contra" and _slip() < 8.0: kart.input_override = {"accelerate": 1.0}
		rt[mode] = t
	# Eses suaves (50 %) a 80 km/h: ¿se mantiene en línea?
	await _go(80); ev.clear()
	var smx := 0.0
	for k in 4:
		kart.input_override = {"accelerate": 1.0, "steer_right" if k % 2 == 0 else "steer_left": 0.5}
		for i in 40:
			await physics_frame
			smx = maxf(smx, _slip())
	print("[ctrl] sostenido %.0f-%.0f° trompo=%s | enderezar contra %.2fs / suelto %.2fs | eses 50%% a 80: deriva máx %.1f° | %s" % [mn, mx, str(spin), rt["contra"], rt["neutro"], smx, str(ev)])
	quit()
