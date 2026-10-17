extends CanvasLayer
## Interfaz provisional: velocímetro, vueltas, tiempos, barra de turbo,
## indicador de mini-turbo, minimapa, cuenta atrás y mensajes.

const TouchControls := preload("res://scripts/ui/touch_controls.gd")

signal pause_requested

var touch: Control

var _lap_label: Label
var _time_label: Label
var _best_label: Label
var _center_label: Label
var _sub_label: Label
var _hint_label: Label
var _speedo: Speedo
var _turbo: TurboBar
var _minimap: Minimap
var drift_meter: DriftMeter
var _pause_panel: PanelContainer
var _msg_time := 0.0


# --- Widgets dibujados a mano --------------------------------------------------

class Speedo extends Control:
	var kmh := 0.0
	var max_kmh := 140.0
	var drift_level := 0
	var boosting := false

	func _draw() -> void:
		var c := size * Vector2(0.5, 0.62)
		var r := minf(size.x, size.y * 1.6) * 0.42
		var start := deg_to_rad(150)
		var end := deg_to_rad(390)
		draw_arc(c, r, start, end, 40, Color(0, 0, 0, 0.45), r * 0.2, true)
		var t := clampf(kmh / max_kmh, 0.0, 1.0)
		var col := Color("ffd23f").lerp(Color("ff4d2d"), t)
		if boosting:
			col = Color("ff7b00")
		if t > 0.001:
			draw_arc(c, r, start, lerpf(start, end, t), 40, col, r * 0.14, true)
		var font := get_theme_default_font()
		var txt := str(int(round(kmh)))
		var fs := int(r * 0.7)
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string_outline(font, c + Vector2(-ts.x * 0.5, fs * 0.3), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, 8, Color(0, 0, 0, 0.8))
		draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.3), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)
		var unit := "km/h"
		var fs2 := int(r * 0.22)
		var ts2 := font.get_string_size(unit, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2)
		draw_string(font, c + Vector2(-ts2.x * 0.5, fs * 0.3 + fs2 * 1.2), unit, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2, Color(1, 1, 1, 0.85))
		if drift_level > 0:
			var dc: Color = [Color("3fa9ff"), Color("ff8c1a"), Color("c75cff")][clampi(drift_level, 1, 3) - 1]
			for i in drift_level:
				draw_circle(c + Vector2((i - (drift_level - 1) * 0.5) * r * 0.28, -r * 0.62), r * 0.09, dc)


## Indicador de derrape (v0.3): barra que se llena mientras derrapas (azul → naranja
## → morado) y, al enderezar un derrape válido, aviso "¡SUELTA Y PISA!" con la
## ventana de tiempo que se agota.
class DriftMeter extends Control:
	const COLS := [Color("3fa9ff"), Color("ff8c1a"), Color("c75cff")]
	var state := 0          # 0 nada, 1 derrapando, 2 ventana
	var drift_time := 0.0
	var levels: Array[float] = [0.3, 0.8, 1.4]
	var level := 0
	var window_frac := 0.0
	var slip_deg := 0.0
	var t := 0.0

	func _draw() -> void:
		if state == 0:
			return
		var font := get_theme_default_font()
		var w := size.x
		var h := 16.0
		var y := size.y - h
		if state == 1:
			draw_rect(Rect2(0, y, w, h), Color(0, 0, 0, 0.5))
			var maxt: float = levels[levels.size() - 1] * 1.15
			for i in levels.size():
				var x0: float = (0.0 if i == 0 else levels[i - 1]) / maxt * w
				var x1: float = minf(drift_time, levels[i]) / maxt * w
				if x1 > x0:
					draw_rect(Rect2(x0, y + 2, x1 - x0, h - 4), COLS[i])
				draw_line(Vector2(levels[i] / maxt * w, y - 3), Vector2(levels[i] / maxt * w, y + h + 3), Color.WHITE, 2.0)
			var txt := "DERRAPE  %d°" % int(slip_deg)
			if level == 0:
				txt += "  (aguanta…)"
			draw_string_outline(font, Vector2(0, y - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(0, y - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COLS[maxi(level - 1, 0)] if level > 0 else Color.WHITE)
		else:
			var pulse := 0.75 + 0.25 * sin(t * 28.0)
			var col: Color = COLS[clampi(level - 1, 0, 2)]
			draw_rect(Rect2(0, y, w, h), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(2, y + 2, (w - 4) * window_frac, h - 4), Color(1.0, 0.85, 0.15))
			var txt2 := "¡SUELTA Y PISA!"
			var fs := 34
			var ts := font.get_string_size(txt2, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			var p := Vector2((w - ts.x) * 0.5, y - 10)
			draw_string_outline(font, p, txt2, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, 8, Color(0, 0, 0, 0.85))
			draw_string(font, p, txt2, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(col.lightened(0.3), pulse))


class TurboBar extends Control:
	var value := 1.0

	func _draw() -> void:
		var full := value >= 1.0
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		var col := Color("c75cff") if full else Color("8e44ad")
		draw_rect(Rect2(Vector2(3, 3), Vector2((size.x - 6) * value, size.y - 6)), col)
		var font := get_theme_default_font()
		var fs := int(size.y * 0.62)
		var txt := "TURBO ¡LISTO!" if full else "TURBO"
		draw_string(font, Vector2(8, size.y * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


class Minimap extends Control:
	var pts := PackedVector2Array()
	var kart_pos := Vector2.ZERO
	var kart_dir := Vector2.UP
	var _min := Vector2.ZERO
	var _scale := 1.0

	func set_track(p: PackedVector2Array) -> void:
		pts = p
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for v in pts:
			lo = lo.min(v)
			hi = hi.max(v)
		_min = lo
		var ext := hi - lo
		_scale = minf((size.x - 16) / ext.x, (size.y - 16) / ext.y)
		queue_redraw()

	func _map(v: Vector2) -> Vector2:
		return (v - _min) * _scale + Vector2(8, 8)

	func _draw() -> void:
		if pts.size() < 2:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		var mapped := PackedVector2Array()
		for v in pts:
			mapped.append(_map(v))
		mapped.append(mapped[0])
		draw_polyline(mapped, Color(1, 1, 1, 0.9), 5.0, true)
		draw_polyline(mapped, Color("474b55"), 3.0, true)
		draw_circle(mapped[0], 4.0, Color.WHITE)
		var p := _map(kart_pos)
		var f := kart_dir.normalized()
		var r := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([p + f * 8, p - f * 5 + r * 5, p - f * 5 - r * 5]), Color("ffd23f"))


# --- Construcción ----------------------------------------------------------------

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_lap_label = _label(root, 44, Color.WHITE)
	_lap_label.position = Vector2(24, 14)
	_time_label = _label(root, 30, Color("ffd23f"))
	_time_label.position = Vector2(26, 70)
	_best_label = _label(root, 22, Color(1, 1, 1, 0.8))
	_best_label.position = Vector2(26, 108)

	_minimap = Minimap.new()
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_minimap, Control.PRESET_TOP_RIGHT, Vector2(-206, 14), Vector2(190, 190))
	root.add_child(_minimap)

	_speedo = Speedo.new()
	_speedo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_speedo, Control.PRESET_BOTTOM_RIGHT, Vector2(-260, -196), Vector2(240, 150))
	root.add_child(_speedo)

	drift_meter = DriftMeter.new()
	drift_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(drift_meter, Control.PRESET_CENTER_BOTTOM, Vector2(-200, -150), Vector2(400, 70))
	root.add_child(drift_meter)

	_turbo = TurboBar.new()
	_turbo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_turbo, Control.PRESET_BOTTOM_RIGHT, Vector2(-250, -44), Vector2(220, 28))
	root.add_child(_turbo)

	_center_label = _label(root, 110, Color("ffd23f"))
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_center_label, Control.PRESET_CENTER, Vector2(-450, -190), Vector2(900, 140))
	_sub_label = _label(root, 34, Color.WHITE)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_sub_label, Control.PRESET_CENTER, Vector2(-450, -60), Vector2(900, 50))

	_hint_label = _label(root, 17, Color(1, 1, 1, 0.85))
	_place(_hint_label, Control.PRESET_BOTTOM_LEFT, Vector2(20, -122), Vector2(640, 112))
	_hint_label.text = ("W/↑ acelerar · S/↓ frenar/atrás · A D/← → girar\n"
			+ "Gira fuerte a velocidad para derrapar · contravolante para enderezar\n"
			+ "Al enderezar: suelta y pisa el acelerador = mini-turbo · E turbo · Q atrás\n"
			+ "R reaparecer · Esc pausa · F3 controles táctiles")

	_pause_panel = PanelContainer.new()
	_place(_pause_panel, Control.PRESET_CENTER, Vector2(-210, -115), Vector2(420, 230))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.15, 0.9)
	sb.border_color = Color("ffd23f")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	_pause_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(vb)
	var title := _label(vb, 44, Color("ffd23f"))
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var resume := Button.new()
	resume.text = "Continuar"
	resume.add_theme_font_size_override("font_size", 26)
	resume.pressed.connect(func(): pause_requested.emit())
	vb.add_child(resume)
	var restart := Button.new()
	restart.text = "Reiniciar carrera"
	restart.add_theme_font_size_override("font_size", 26)
	restart.pressed.connect(_on_restart)
	vb.add_child(restart)
	_pause_panel.visible = false
	root.add_child(_pause_panel)

	touch = TouchControls.new()
	touch.pause_pressed.connect(func(): pause_requested.emit())
	root.add_child(touch)
	_layout_for_touch(touch.visible)


## En modo táctil los botones ocupan las esquinas inferiores: velocímetro y turbo suben arriba.
func _layout_for_touch(on: bool) -> void:
	_hint_label.visible = not on
	if on:
		_place(_speedo, Control.PRESET_CENTER_TOP, Vector2(-110, 0), Vector2(220, 130))
		_place(_turbo, Control.PRESET_CENTER_TOP, Vector2(-100, 128), Vector2(200, 24))
	else:
		_place(_speedo, Control.PRESET_BOTTOM_RIGHT, Vector2(-260, -196), Vector2(240, 150))
		_place(_turbo, Control.PRESET_BOTTOM_RIGHT, Vector2(-250, -44), Vector2(220, 28))


## Ancla un control y fija su rectángulo relativo a ese ancla.
func _place(c: Control, preset: int, offset: Vector2, sz: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + sz.x
	c.offset_bottom = offset.y + sz.y


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _label(parent: Node, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	l.add_theme_constant_override("outline_size", maxi(4, size_px / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# --- API para la carrera -----------------------------------------------------------

func set_track(points: PackedVector2Array) -> void:
	_minimap.set_track(points)


func update_race(lap: int, total_laps: int, time: float, best: float, finished: bool) -> void:
	_lap_label.text = "META" if finished else "VUELTA %d/%d" % [clampi(lap, 1, total_laps), total_laps]
	_time_label.text = format_time(time)
	_best_label.text = "MEJOR VUELTA  " + (format_time(best) if best > 0.0 else "--:--.--")


func update_kart(kmh: float, turbo: float, drift_level: int, boosting: bool, pos: Vector3, dir: Vector3) -> void:
	_speedo.kmh = kmh
	_speedo.drift_level = drift_level
	_speedo.boosting = boosting
	_speedo.queue_redraw()
	_turbo.value = turbo
	_turbo.queue_redraw()
	_minimap.kart_pos = Vector2(pos.x, pos.z)
	_minimap.kart_dir = Vector2(dir.x, dir.z)
	_minimap.queue_redraw()


## Estado del derrape para el indicador (llamado cada fotograma por la carrera).
func update_drift(state: int, drift_time: float, level: int, window_left: float, window_total: float,
		slip_deg: float, levels: Array[float]) -> void:
	drift_meter.state = state
	drift_meter.drift_time = drift_time
	drift_meter.level = level
	drift_meter.window_frac = clampf(window_left / maxf(window_total, 0.01), 0.0, 1.0)
	drift_meter.slip_deg = slip_deg
	drift_meter.levels = levels
	drift_meter.t += get_process_delta_time()
	drift_meter.queue_redraw()


func show_message(text: String, sub: String = "", seconds: float = 1.5, col: Color = Color("ffd23f")) -> void:
	_center_label.text = text
	_center_label.add_theme_color_override("font_color", col)
	_sub_label.text = sub
	_msg_time = seconds


func set_paused(p: bool) -> void:
	_pause_panel.visible = p


func toggle_touch() -> void:
	touch.visible = not touch.visible
	_layout_for_touch(touch.visible)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		pause_requested.emit()
	if Input.is_action_just_pressed("toggle_touch"):
		toggle_touch()
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_center_label.text = ""
			_sub_label.text = ""


static func format_time(t: float) -> String:
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%d:%05.2f" % [m, s]
