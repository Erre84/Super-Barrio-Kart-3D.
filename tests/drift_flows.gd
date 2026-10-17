extends SceneTree
## Herramienta de ajuste: prueba las formas "naturales" de salir de un derrape y si dan
## mini-turbo. Uso: godot --headless --path . --fixed-fps 60 -s res://tests/drift_flows.gd
var kart
var ev := []
func _initialize(): _run()
func _frames(n): for i in n: await physics_frame
func _slip() -> float: return rad_to_deg(absf(kart.slip_angle))
func _flow(name_: String, lift_when: String, press_when: String) -> void:
	ev.clear()
	kart.place(Transform3D(Basis(), Vector3(900, 0.05, 900)))
	kart.input_override = {"accelerate": 1.0}
	await _frames(200)
	var gas := 1.0
	kart.input_override = {"accelerate": gas, "steer_right": 1.0}
	var v_before: float = kart.get_speed_kmh()
	for i in 40:
		if lift_when == "derrape" and i == 15: gas = 0.0
		kart.input_override = {"accelerate": gas, "steer_right": 1.0}
		await physics_frame
	var steer := {"steer_left": 1.0}
	var straight_t := -1
	var vmin := 999.0
	var vmax := 0.0
	var fire_v := -1.0
	for i in 150:
		var s := _slip()
		if s < 4.0: steer = {}
		if straight_t < 0 and s < 4.0: straight_t = i
		if lift_when == "contravolante" and i == 0: gas = 0.0
		if lift_when == "al_enderezar" and straight_t >= 0 and i == straight_t + 2: gas = 0.0
		if press_when == "recuperando" and gas == 0.0 and s < 12.0 and s > 4.0: gas = 1.0
		if press_when == "enderezado" and gas == 0.0 and straight_t >= 0 and i >= straight_t + 8: gas = 1.0
		var d := steer.duplicate(); d["accelerate"] = gas
		kart.input_override = d
		await physics_frame
		vmin = minf(vmin, kart.get_speed_kmh())
		if "success" in ev:
			vmax = maxf(vmax, kart.get_speed_kmh())
			if fire_v < 0.0: fire_v = vmin
	kart.input_override = {"accelerate": 1.0}
	for i in 60:
		await physics_frame
		if "success" in ev: vmax = maxf(vmax, kart.get_speed_kmh())
	var ok := "success" in ev
	print("[flujo] %-52s %s  sale del derrape a %.0f km/h → pico %.0f km/h  %s" % [name_, "TURBO" if ok else "nada ", vmin, vmax, str(ev)])
func _run():
	preload("res://scripts/core/input_setup.gd").setup()
	await process_frame
	var w := Node3D.new(); get_root().add_child(w)
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); cs.shape = WorldBoundaryShape3D.new(); g.add_child(cs); w.add_child(g)
	kart = load("res://scenes/kart.tscn").instantiate(); w.add_child(kart); kart.controls_enabled = true
	kart.drift_event.connect(func(k, l): ev.append(k))
	await _flow("A gas a fondo · al enderezar suelta y pisa", "al_enderezar", "enderezado")
	await _flow("B suelta EN el derrape · pisa al enderezar", "derrape", "enderezado")
	await _flow("C suelta en el derrape · pisa mientras recupera", "derrape", "recuperando")
	await _flow("D suelta al contravolantear · pisa al enderezar", "contravolante", "enderezado")
	await _flow("E suelta al contravolantear · pisa mientras recupera", "contravolante", "recuperando")
	await _flow("F nunca suelta el gas", "nunca", "nunca")
	quit()
