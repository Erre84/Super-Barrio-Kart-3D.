extends Control
## Controles táctiles multitáctiles para Android.
## Cada botón "pulsa" una acción del InputMap, así el kart no distingue entre
## teclado, mando o pantalla. Se dibujan con _draw (sin texturas).
##
## Izquierda: girar ◀ ▶ y mirar atrás.  Derecha: acelerar, frenar/atrás, derrape, turbo.
## En PC se pueden mostrar con F3 y usar con el ratón para probarlos.

signal pause_pressed

var buttons: Array = []           # {id, action, label, center(rel), radius(rel), color}
var _touch_to_button := {}        # índice de dedo -> id de botón
var _pressed := {}                # id -> bool
var _strength := {}               # id -> intensidad del giro (táctil analógico)
const MOUSE_ID := -100


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons = [
		{"id": "left", "action": "steer_left", "label": "◀", "pos": Vector2(0.09, 0.80), "r": 0.085, "color": Color("2b6fe0")},
		{"id": "right", "action": "steer_right", "label": "▶", "pos": Vector2(0.235, 0.80), "r": 0.085, "color": Color("2b6fe0")},
		{"id": "look", "action": "look_back", "label": "ATRÁS", "pos": Vector2(0.07, 0.52), "r": 0.05, "color": Color("6c757d")},
		{"id": "accel", "action": "accelerate", "label": "ACEL", "pos": Vector2(0.885, 0.76), "r": 0.115, "color": Color("2a9d8f")},
		{"id": "brake", "action": "brake", "label": "FRENO", "pos": Vector2(0.715, 0.85), "r": 0.07, "color": Color("e63946")},
		{"id": "turbo", "action": "turbo", "label": "TURBO", "pos": Vector2(0.9, 0.44), "r": 0.065, "color": Color("8e44ad")},
		{"id": "pause", "action": "", "label": "II", "pos": Vector2(0.36, 0.07), "r": 0.035, "color": Color("1d2135")},
	]
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	process_mode = Node.PROCESS_MODE_ALWAYS


## Escala de los botones: se adapta a pantallas más anchas o más estrechas que 16:9.
func _unit() -> float:
	return minf(size.x, size.y * 16.0 / 9.0) * 0.75


func _btn_center(b: Dictionary) -> Vector2:
	var rel: Vector2 = b["pos"]
	return Vector2(rel.x * size.x, rel.y * size.y)


func _btn_radius(b: Dictionary) -> float:
	return float(b["r"]) * _unit()


func _button_at(p: Vector2) -> String:
	for b in buttons:
		# Zona táctil un 25 % más grande que el dibujo: más fácil de acertar
		if p.distance_to(_btn_center(b)) <= _btn_radius(b) * 1.25:
			return b["id"]
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_assign(t.index, _button_at(t.position))
			_update_steer_strength(t.index, t.position)
		else:
			_assign(t.index, "")
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		# Deslizar el pulgar entre ◀ y ▶ cambia de botón sin levantarlo
		var id := _button_at(d.position)
		var cur: String = _touch_to_button.get(d.index, "")
		if id != cur and (id in ["left", "right"] or cur in ["left", "right"]):
			_assign(d.index, id)
		_update_steer_strength(d.index, d.position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		if m.device == InputEvent.DEVICE_ID_EMULATION:
			return  # ratón emulado a partir de un toque: ya lo hemos tratado
		_assign(MOUSE_ID, _button_at(m.position) if m.pressed else "")


## Dirección analógica en táctil: en el borde exterior del botón se gira a fondo y
## hacia el interior (hacia el otro botón) se gira menos. Permite trazar curvas con
## agarre sin derrapar, y derrapar a propósito llevando el pulgar hacia fuera.
const STEER_MIN := 0.4

func _update_steer_strength(finger: int, pos: Vector2) -> void:
	var id: String = _touch_to_button.get(finger, "")
	if not (id in ["left", "right"]):
		return
	for b in buttons:
		if b["id"] != id:
			continue
		var c := _btn_center(b)
		var r := _btn_radius(b)
		var outward := (c.x - pos.x) / r if id == "left" else (pos.x - c.x) / r
		var strength := clampf(lerpf(STEER_MIN, 1.0, (outward + 0.6) / 1.2), STEER_MIN, 1.0)
		_strength[id] = strength
		Input.action_press(b["action"], strength)
		queue_redraw()


func _assign(finger: int, id: String) -> void:
	var old: String = _touch_to_button.get(finger, "")
	if old == id:
		return
	if old != "":
		_touch_to_button.erase(finger)
		_set_button(old, false)
	if id != "":
		_touch_to_button[finger] = id
		_set_button(id, true)
	queue_redraw()


func _set_button(id: String, down: bool) -> void:
	# Un botón puede estar pulsado por varios dedos: solo se suelta con el último.
	if not down:
		for f in _touch_to_button:
			if _touch_to_button[f] == id:
				return
	_pressed[id] = down
	for b in buttons:
		if b["id"] != id:
			continue
		if id == "pause":
			if down:
				pause_pressed.emit()
			return
		var action: String = b["action"]
		if down:
			Input.action_press(action, 1.0)
		else:
			Input.action_release(action)
			_strength.erase(id)


func release_all() -> void:
	for f in _touch_to_button.keys():
		_assign(f, "")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		release_all()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()


func _draw() -> void:
	var font := get_theme_default_font()
	for b in buttons:
		var c := _btn_center(b)
		var r := _btn_radius(b)
		var col: Color = b["color"]
		var down: bool = _pressed.get(b["id"], false)
		draw_circle(c + Vector2(0, r * 0.08), r, Color(0, 0, 0, 0.25))
		draw_circle(c, r, Color(col, 0.85 if down else 0.45))
		draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.9 if down else 0.6), maxf(2.0, r * 0.06), true)
		if b["id"] in ["left", "right"]:
			var sx := -1.0 if b["id"] == "left" else 1.0
			var pts := PackedVector2Array([c + Vector2(sx * r * 0.45, 0), c + Vector2(-sx * r * 0.3, -r * 0.4),
					c + Vector2(-sx * r * 0.3, r * 0.4)])
			draw_colored_polygon(pts, Color(1, 1, 1, 0.95))
			# Intensidad del giro (táctil analógico): arco amarillo
			if down:
				var st: float = _strength.get(b["id"], 1.0)
				draw_arc(c, r * 1.12, -PI * 0.5 - st * PI * 0.5, -PI * 0.5 + st * PI * 0.5, 24,
						Color(1.0, 0.85, 0.2, 0.9), maxf(3.0, r * 0.08), true)
			continue
		var label: String = b["label"]
		var fs := int(r * (0.9 if label.length() <= 2 else 0.36))
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs,
				Color(1, 1, 1, 0.95))
