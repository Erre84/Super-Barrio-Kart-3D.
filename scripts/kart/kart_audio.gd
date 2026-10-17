extends Node
## Sonido del kart generado por código (sin archivos externos), barato para móvil:
## los sonidos se sintetizan UNA vez al arrancar en buffers PCM en bucle y luego solo
## se cambia su volumen y su tono.
##  - Motor: tono que sube con la velocidad.
##  - Chirrido de neumáticos: ruido filtrado + silbido; su volumen y tono crecen con
##    la deriva (progresivo: empieza suave al perder agarre y chilla en derrape pleno).
##  - "¡Ahora!": campanita al enderezar un derrape válido (ventana abierta).
##  - Mini-turbo: explosión con barrido ascendente. Fallo: "bloop" grave corto.
##  - Turbo de barra y golpes.

const RATE := 22050

static var _cache := {}

var kart: Node
var _engine: AudioStreamPlayer
var _squeal: AudioStreamPlayer
var _fx: Array[AudioStreamPlayer] = []
var _squeal_level := 0.0


func setup(k: Node) -> void:
	kart = k
	_engine = _player(_stream("engine"), -14.0, true)
	_squeal = _player(_stream("squeal"), -60.0, true)
	for i in 3:
		_fx.append(_player(null, -6.0, false))
	kart.drift_event.connect(_on_drift_event)
	kart.boost_started.connect(_on_boost)
	kart.wall_hit.connect(func(s: float): play("thump", clampf(-20.0 + s * 0.6, -18.0, -4.0)))


func _player(stream: AudioStream, vol: float, autoplay: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol
	add_child(p)
	if autoplay and stream != null:
		p.play()
	return p


func play(sound: String, vol_db: float = -6.0, pitch: float = 1.0) -> void:
	for p in _fx:
		if not p.playing:
			p.stream = _stream(sound)
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return
	_fx[0].stream = _stream(sound)
	_fx[0].volume_db = vol_db
	_fx[0].play()


func _process(delta: float) -> void:
	if kart == null:
		return
	var spd: float = Vector2(kart.velocity.x, kart.velocity.z).length()
	var ratio := clampf(spd / float(kart.max_speed), 0.0, 1.4)
	_engine.pitch_scale = 0.6 + ratio * 0.85 + (0.12 if kart.boost_time > 0.0 else 0.0)
	_engine.volume_db = lerpf(-20.0, -11.0, clampf(ratio + float(kart.throttle_input) * 0.2, 0.0, 1.0))
	# Chirrido progresivo: sigue a la deriva y a la velocidad
	var target: float = 0.0
	if kart.is_on_floor() and kart.on_road and spd > 6.0:
		target = clampf(float(kart.slide_amount) * 1.15, 0.0, 1.0)
		if kart.braking_input > 0.5 and kart.forward_speed > 10.0:
			target = maxf(target, 0.45)
	_squeal_level = move_toward(_squeal_level, target, delta * (6.0 if target > _squeal_level else 3.0))
	_squeal.volume_db = linear_to_db(maxf(_squeal_level, 0.0001)) - 7.0
	_squeal.pitch_scale = 0.85 + _squeal_level * 0.35 + ratio * 0.1


func _on_drift_event(kind: String, _level: int) -> void:
	match kind:
		"window":
			play("chime", -5.0, 1.0 + 0.08 * _level)
		"success":
			play("boost", 0.0, 1.0 + 0.06 * _level)
		"fail_late", "fail_lift", "fail_short", "fail_spin":
			play("fail", -10.0)


func _on_boost(kind: String) -> void:
	if kind == "turbo" or kind == "pad" or kind == "start":
		play("boost", -5.0, 0.8)


# --- Síntesis ---------------------------------------------------------------------

static func _stream(sound_name: String) -> AudioStreamWAV:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var s: AudioStreamWAV
	match sound_name:
		"engine": s = _make_engine()
		"squeal": s = _make_squeal()
		"chime": s = _make_chime()
		"boost": s = _make_boost()
		"fail": s = _make_fail()
		"thump": s = _make_thump()
	_cache[sound_name] = s
	return s


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Motor: diente de sierra + armónicos a 140 Hz (audible en altavoces de móvil).
static func _make_engine() -> AudioStreamWAV:
	var f0 := RATE / 150.0   # 147 Hz: periodo entero de 150 muestras, bucle sin clics
	var n := int(RATE / f0) * 40
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var ph := fmod(t * f0, 1.0)
		var saw := ph * 2.0 - 1.0
		var v := saw * 0.4 + sin(TAU * f0 * t) * 0.3 + sin(TAU * f0 * 2.0 * t) * 0.2
		v += (sin(TAU * f0 * 3.0 * t) * 0.1) * (0.6 + 0.4 * sin(TAU * 8.0 * t))
		out[i] = v * 0.55
	return _wav(out, true)


## Chirrido: ruido pasado por un filtro resonante ~1,4 kHz + silbido con vibrato.
static func _make_squeal() -> AudioStreamWAV:
	var n := RATE  # 1 s
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Filtro paso banda (biquad) a 1400 Hz, Q alto
	var fc := 1400.0
	var q := 6.0
	var w0 := TAU * fc / RATE
	var alpha := sin(w0) / (2.0 * q)
	var b0 := alpha
	var b2 := -alpha
	var a0 := 1.0 + alpha
	var a1 := -2.0 * cos(w0)
	var a2 := 1.0 - alpha
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		var y := (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		var whistle := sin(TAU * 1750.0 * t + 0.6 * sin(TAU * 11.0 * t))
		out[i] = y * 2.2 + whistle * 0.18
	# Fundido en los bordes del bucle para que no haga "clic"
	for i in 200:
		var k := float(i) / 200.0
		out[i] *= k
		out[n - 1 - i] *= k
	return _wav(out, true)


## Campanita de dos notas (aviso de ventana: "¡suelta y pisa!").
static func _make_chime() -> AudioStreamWAV:
	var n := int(RATE * 0.28)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 1318.5 if t < 0.09 else 1975.5
		var t2 := t if t < 0.09 else t - 0.09
		out[i] = sin(TAU * f * t) * exp(-t2 * 14.0) * 0.6 + sin(TAU * f * 2.0 * t) * exp(-t2 * 22.0) * 0.15
	return _wav(out, false)


## Impulso: golpe grave + barrido de ruido ascendente.
static func _make_boost() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t * 40.0, 1.0) * exp(-t * 4.5)
		var cutoff := lerpf(0.05, 0.6, minf(t * 2.0, 1.0))
		lp += (rng.randf_range(-1, 1) - lp) * cutoff
		phase += TAU * lerpf(90.0, 360.0, minf(t * 1.6, 1.0)) / RATE
		out[i] = (lp * 0.9 + sin(phase) * 0.45) * env
	return _wav(out, false)


static func _make_fail() -> AudioStreamWAV:
	var n := int(RATE * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(260.0, 120.0, t / 0.22) / RATE
		out[i] = sin(phase) * exp(-t * 10.0) * 0.6
	return _wav(out, false)


static func _make_thump() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.08
		out[i] = (sin(TAU * 90.0 * t) * 0.6 + lp * 1.3) * exp(-t * 18.0)
	return _wav(out, false)
