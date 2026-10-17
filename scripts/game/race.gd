extends Node3D
## Escena principal: monta el circuito, el kart, la cámara y el HUD, y lleva la
## lógica de carrera (cuenta atrás, puntos de control, vueltas, tiempos, pausa).

const InputSetup := preload("res://scripts/core/input_setup.gd")
const TrackScene := preload("res://scenes/track_el_prat.tscn")
const KartScene := preload("res://scenes/kart.tscn")
const HudScene := preload("res://scenes/hud.tscn")
const ChaseCamera := preload("res://scripts/kart/chase_camera.gd")
const Lighting := preload("res://scripts/game/lighting.gd")
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

	# Aviones: uno aterrizando y otro despegando, alineados con la pista
	for spec in [["landing", 0.2, 34.0], ["takeoff", 0.55, 40.0]]:
		var plane := Airplane.new()
		plane.mode = spec[0]
		plane.phase = spec[1]
		plane.duration = spec[2]
		plane.runway_center = Vector3(track.RUNWAY_X, 0, track.RUNWAY_Z)
		plane.runway_length = track.RUNWAY_LEN
		add_child(plane)

	hud = HudScene.instantiate()
	add_child(hud)
	hud.set_track(track.minimap_points())
	hud.pause_requested.connect(_toggle_pause)

	kart.wall_hit.connect(_on_wall_hit)
	kart.boost_started.connect(_on_boost)
	kart.drift_event.connect(_on_drift_event)

	# Opciones de desarrollo (godot --path . -- --touch / --autopilot)
	if "--touch" in OS.get_cmdline_user_args() and not hud.touch.visible:
		hud.toggle_touch()
	if "--autopilot" in OS.get_cmdline_user_args():
		var ap: Node = load("res://tests/autopilot.gd").new()
		ap.name = "Autopilot"
		ap.set("race", self)
		add_child(ap)


func _build_environment() -> void:
	Lighting.build(self, OS.has_feature("mobile"))


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
	hud.update_drift(int(kart.drift_state), kart.drift_time, kart.drift_level, kart.window_left,
			kart.boost_window, rad_to_deg(absf(kart.slip_angle)), kart.drift_level_times)


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	hud.set_paused(p)
	if p:
		hud.touch.release_all()


func _on_wall_hit(strength: float) -> void:
	camera.add_shake(clampf(strength / 40.0, 0.05, 0.5))


const DRIFT_COLS := [Color("3fa9ff"), Color("ff8c1a"), Color("c75cff")]

func _on_drift_event(kind: String, level: int) -> void:
	var col: Color = DRIFT_COLS[clampi(level, 1, 3) - 1]
	match kind:
		"success":
			hud.show_message(["¡MINI-TURBO!", "¡MINI-TURBO!", "¡SUPER MINI-TURBO!"][clampi(level, 1, 3) - 1],
					"", 0.8, col)
			camera.punch(4.0 + level * 2.0)
		"fail_late":
			hud.show_message("", "Tarde: pisa antes", 0.9, Color.WHITE)
		"fail_lift":
			hud.show_message("", "Suelta el acelerador y vuelve a pisar", 1.0, Color.WHITE)
		"fail_spin":
			hud.show_message("", "¡Trompo! Contravolantea antes", 1.1, Color.WHITE)
		"fail_wall":
			hud.show_message("", "Derrape perdido por el choque", 0.9, Color.WHITE)


func _on_boost(kind: String) -> void:
	match kind:
		"turbo":
			hud.show_message("¡TURBO!", "", 0.8, Color("c75cff"))
		"pad":
			hud.show_message("¡ACELERADOR!", "", 0.6, Color("ff7b00"))
