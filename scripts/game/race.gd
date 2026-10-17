extends Node3D
## Escena principal: monta el circuito, el kart, la cámara y el HUD, y lleva la
## lógica de carrera (cuenta atrás, puntos de control, vueltas, tiempos, pausa).

const InputSetup := preload("res://scripts/core/input_setup.gd")
const TrackScene := preload("res://scenes/track_el_prat.tscn")
const KartScene := preload("res://scenes/kart.tscn")
const HudScene := preload("res://scenes/hud.tscn")
const ChaseCamera := preload("res://scripts/kart/chase_camera.gd")
const KartScript := preload("res://scripts/kart/kart.gd")
const TrackScript := preload("res://scripts/track/track_el_prat.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const Airplane := preload("res://scripts/track/airplane.gd")

const TOTAL_LAPS := 3
const CHECKPOINTS := [0.25, 0.5, 0.75]
const COUNTDOWN := 3.0

var track: TrackScript
var kart: KartScript
var camera: ChaseCamera
var hud: HudScript

var state := "countdown"   # countdown | racing | finished
var countdown := COUNTDOWN + 0.6
var race_time := 0.0
var lap := 1
var lap_start := 0.0
var best_lap := 0.0
var lap_times: Array[float] = []
var next_cp := 0
var _prev_progress := 0.0
var _wrong_way_time := 0.0
var _accel_first_press := -1.0
var _last_count_shown := -1


func _ready() -> void:
	InputSetup.setup()
	_build_environment()

	track = TrackScene.instantiate()
	add_child(track)
	track.build()

	kart = KartScene.instantiate()
	kart.track = track
	add_child(kart)
	kart.place(track.start_transform(0))

	camera = ChaseCamera.new()
	camera.target = kart
	add_child(camera)
	camera.make_current()

	for spec in [[Vector3(520, 150, -520), Vector3(-420, 35, 420), 0.15],
			[Vector3(600, 220, -300), Vector3(-500, 90, 520), 0.62]]:
		var plane := Airplane.new()
		plane.from = spec[0]
		plane.to = spec[1]
		plane.phase = spec[2]
		add_child(plane)

	hud = HudScene.instantiate()
	add_child(hud)
	hud.set_track(track.minimap_points())
	hud.pause_requested.connect(_toggle_pause)

	kart.wall_hit.connect(_on_wall_hit)
	kart.boost_started.connect(_on_boost)

	# Opciones de desarrollo (godot --path . -- --touch / --autopilot)
	if "--touch" in OS.get_cmdline_user_args() and not hud.touch.visible:
		hud.toggle_touch()
	if "--autopilot" in OS.get_cmdline_user_args():
		var ap: Node = load("res://tests/autopilot.gd").new()
		ap.name = "Autopilot"
		ap.set("race", self)
		add_child(ap)


func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2f7fdc")
	sky_mat.sky_horizon_color = Color("bfe2f4")
	sky_mat.ground_horizon_color = Color("bfe2f4")
	sky_mat.ground_bottom_color = Color("8a9a7a")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Luz ambiente de color fijo (más predecible que la del cielo en Compatibility)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a9bfd6")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("cfe0ee")
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)


func _physics_process(delta: float) -> void:
	match state:
		"countdown":
			_update_countdown(delta)
		"racing":
			race_time += delta
			_update_progress()
		"finished":
			_update_progress()


func _update_countdown(delta: float) -> void:
	countdown -= delta
	if Input.is_action_just_pressed("accelerate") and countdown < 0.6 and countdown > 0.0:
		_accel_first_press = countdown
	var shown := int(ceil(countdown))
	if countdown <= COUNTDOWN and shown != _last_count_shown and shown > 0:
		_last_count_shown = shown
		hud.show_message(str(shown), "", 0.9, Color.WHITE)
	if countdown <= 0.0:
		state = "racing"
		kart.controls_enabled = true
		lap_start = 0.0
		hud.show_message("¡YA!", "", 1.0, Color("54d17a"))
		if _accel_first_press > 0.0 and Input.is_action_pressed("accelerate"):
			kart.apply_boost(1.0, "start")
			hud.show_message("¡YA!", "¡Salida perfecta!", 1.2, Color("54d17a"))


func _update_progress() -> void:
	var info: Dictionary = kart.track_info
	if info.is_empty():
		return
	var progress: float = info["progress"]
	# Puntos de control en orden: impiden atajar o dar la vuelta marcha atrás
	if next_cp < CHECKPOINTS.size():
		var cp: float = CHECKPOINTS[next_cp]
		if progress >= cp and progress < cp + 0.12:
			next_cp += 1
	elif _prev_progress > 0.85 and progress < 0.15:
		_complete_lap()
	_prev_progress = progress

	# Sentido contrario
	var fwd := -kart.global_transform.basis.z
	var dir: Vector3 = info["dir"]
	if fwd.dot(dir) < -0.35 and kart.get_speed_kmh() > 15.0:
		_wrong_way_time += get_physics_process_delta_time()
		if _wrong_way_time > 1.2 and _wrong_way_time - get_physics_process_delta_time() <= 1.2:
			hud.show_message("¡SENTIDO CONTRARIO!", "", 1.6, Color("ff4d4d"))
	else:
		_wrong_way_time = 0.0


func _complete_lap() -> void:
	next_cp = 0
	if state != "racing":
		return
	var lt := race_time - lap_start
	lap_start = race_time
	lap_times.append(lt)
	var is_best := best_lap <= 0.0 or lt < best_lap
	if is_best:
		best_lap = lt
	if lap >= TOTAL_LAPS:
		state = "finished"
		hud.show_message("¡META!", "Tiempo total %s · mejor vuelta %s · Esc para reiniciar"
				% [hud.format_time(race_time), hud.format_time(best_lap)], 8.0, Color("ffd23f"))
		return
	lap += 1
	if lap == TOTAL_LAPS:
		hud.show_message("ÚLTIMA VUELTA", hud.format_time(lt), 2.0, Color("ff7b00"))
	else:
		hud.show_message("VUELTA %d" % lap, hud.format_time(lt) + ("  ¡récord!" if is_best else ""), 1.8)


func _process(_delta: float) -> void:
	if hud == null:
		return
	var shown_time := race_time
	hud.update_race(lap, TOTAL_LAPS, shown_time, best_lap, state == "finished")
	hud.update_kart(kart.get_speed_kmh(), kart.turbo_meter, kart.drift_level, kart.boost_time > 0.0,
			kart.global_position, -kart.global_transform.basis.z)


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	hud.set_paused(p)
	if p:
		hud.touch.release_all()


func _on_wall_hit(strength: float) -> void:
	camera.add_shake(clampf(strength / 40.0, 0.05, 0.5))


func _on_boost(kind: String) -> void:
	match kind:
		"turbo":
			hud.show_message("¡TURBO!", "", 0.8, Color("c75cff"))
		"mini3":
			hud.show_message("¡SUPER MINI-TURBO!", "", 0.8, Color("c75cff"))
		"pad":
			hud.show_message("¡ACELERADOR!", "", 0.6, Color("ff7b00"))
