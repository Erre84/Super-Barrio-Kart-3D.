extends Node3D
## Menú principal: vitrina 3D del corredor elegido + selección de corredor y de circuito.
## Teclado (flechas/WASD, Intro, Esc), mando (cruceta/stick, A, B) y táctil (tocar tarjetas).
##
## Paso 1: ELIGE CORREDOR (rejilla de 14; los que aún no tienen modelo 3D salen
##         como "PRÓXIMAMENTE" y no se pueden elegir).
## Paso 2: ELIGE CIRCUITO (El Prat 3D; el Aeropuerto de la v16 queda anunciado).

const Roster := preload("res://scripts/racers/roster.gd")
const GameState := preload("res://scripts/core/game_state.gd")
const KartScene := preload("res://scenes/kart.tscn")
const InputSetup := preload("res://scripts/core/input_setup.gd")
const TrackScript := preload("res://scripts/track/track_el_prat.gd")

const YELLOW := Color("ffd23f")
const PANEL := Color(0.06, 0.07, 0.14, 0.88)
const COLS := 7

const TRACKS := [
	{"id": "el_prat", "name": "EL PRAT", "sub": "Circuito urbano 3D · 3 vueltas",
		"desc": "Plaça de la Vila, Carrer Major, la Carxofa, la Pota Blava, el Parc del Riu y la valla del aeropuerto con aviones despegando.",
		"ready": true},
	{"id": "aeropuerto", "name": "AEROPUERTO", "sub": "Próximamente en 3D",
		"desc": "El segundo circuito de la v16 (2D). Se modelará más adelante.", "ready": false},
]

var step := 0                 # 0 corredor, 1 circuito
var racer_index := 0
var track_index := 0

var _turntable: Node3D
var _kart: Node3D
var _shown_racer := ""
var _spin := 0.0

var _ui: Control
var _title: Label
var _step_label: Label
var _cards: Array[Button] = []
var _roster_box: Control
var _track_box: Control
var _track_cards: Array[Button] = []
var _info_name: Label
var _info_kart: Label
var _info_extra: Label
var _go: Button
var _back: Button
var _map: Control


func _ready() -> void:
	InputSetup.setup()
	# Opciones de desarrollo y pruebas: ir directamente a la carrera
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--racer="):
			GameState.racer_id = a.substr(8)
	if "--autopilot" in args or "--race" in args or "--touch" in args:
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	_build_stage()
	_build_ui()
	var ids := Roster.ids()
	racer_index = maxi(ids.find(GameState.racer_id), 0)
	track_index = 0
	_set_step(0)
	_select_racer(racer_index)
	# Captura del menú para la documentación: --menu-shot=<png> [--menu-step=1] [--menu-racer=dami]
	for a in args:
		if a.begins_with("--menu-shot="):
			_shot(a.substr(12), args)


func _shot(path: String, args: PackedStringArray) -> void:
	for a in args:
		if a.begins_with("--menu-racer="):
			_select_racer(Roster.ids().find(a.substr(13)))
		if a == "--menu-step=1":
			_set_step(1)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


# =============================================================================
# Vitrina 3D
# =============================================================================

func _build_stage() -> void:
	preload("res://scripts/game/lighting.gd").build(self, OS.has_feature("mobile"))
	var env: Environment = ($WorldEnvironment as WorldEnvironment).environment if has_node("WorldEnvironment") else null
	if env != null:
		env.fog_enabled = false
	# Plataforma giratoria: disco con borde de colores de bordillo
	_turntable = Node3D.new()
	add_child(_turntable)
	var mb := preload("res://scripts/core/mesh_builder.gd").new()
	mb.use("paint")
	mb.cylinder(Vector3(0, -0.12, 0), 3.0, 0.12, 40, Color("2a2e3d"), Color("343a4d"))
	for i in 40:
		var a0 := TAU * i / 40.0
		var a1 := TAU * (i + 1) / 40.0
		var col := Color("e63946") if i % 2 == 0 else Color("f1f1f1")
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		mb.quad(p0 * 2.75 + Vector3(0, 0.003, 0), p1 * 2.75 + Vector3(0, 0.003, 0),
				p1 * 3.0 + Vector3(0, 0.003, 0), p0 * 3.0 + Vector3(0, 0.003, 0), col, Vector3.UP)
	var disc := MeshInstance3D.new()
	disc.mesh = mb.commit()
	_turntable.add_child(disc)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(cs)
	add_child(floor_body)
	# Suelo lejano
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("3d4152")
	ground.material_override = gm
	ground.position.y = -0.125
	add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 42.0
	add_child(cam)
	cam.position = Vector3(-2.4, 1.9, -5.6)
	cam.look_at(Vector3(-1.1, 0.2, 0.0), Vector3.UP)
	cam.current = true


func _show_racer(id: String) -> void:
	if id == _shown_racer:
		return
	_shown_racer = id
	if _kart != null:
		_kart.queue_free()
	_kart = KartScene.instantiate()
	_kart.racer_id = id if Roster.is_modeled(id) else "zule"
	_turntable.add_child(_kart)
	_kart.set_physics_process(false)
	_kart.process_mode = Node.PROCESS_MODE_DISABLED
	_kart.position = Vector3(0, 0.0, 0)
	_kart.visible = Roster.is_modeled(id)


func _process(delta: float) -> void:
	_spin += delta * 0.45
	if _turntable != null:
		_turntable.rotation.y = _spin
	_handle_input()


# =============================================================================
# Interfaz
# =============================================================================

func _panel_style(border: Color, bg: Color = PANEL, width: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	return sb


func _mk_label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 8))
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)

	_title = _mk_label(_ui, "SUPER BARRIO KART", 54, YELLOW)
	_title.position = Vector2(28, 14)
	var sub := _mk_label(_ui, "3D", 54, Color("ff5d5d"))
	sub.position = Vector2(28 + 548, 14)
	_step_label = _mk_label(_ui, "", 30, Color.WHITE)
	_step_label.position = Vector2(30, 84)

	# Ficha del corredor (derecha)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", _panel_style(YELLOW))
	info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info.offset_left = -430
	info.offset_right = -24
	info.offset_top = 24
	info.offset_bottom = 214
	_ui.add_child(info)
	var ivb := VBoxContainer.new()
	info.add_child(ivb)
	_info_name = _mk_label(ivb, "", 44, YELLOW)
	_info_kart = _mk_label(ivb, "", 24, Color.WHITE)
	_info_extra = _mk_label(ivb, "", 20, Color(1, 1, 1, 0.8))
	_info_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_extra.custom_minimum_size = Vector2(380, 0)

	# Rejilla de corredores (abajo)
	_roster_box = PanelContainer.new()
	_roster_box.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.25)))
	_roster_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_roster_box.offset_left = 24
	_roster_box.offset_right = -24
	_roster_box.offset_top = -222
	_roster_box.offset_bottom = -92
	_ui.add_child(_roster_box)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_roster_box.add_child(grid)
	var i := 0
	for r in Roster.RACERS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		var ready: bool = Roster.is_modeled(r["id"])
		b.text = r["name"] if ready else r["name"] + " · pronto"
		b.add_theme_font_size_override("font_size", 20 if ready else 15)
		var idx := i
		b.pressed.connect(func(): _on_card(idx))
		grid.add_child(b)
		_cards.append(b)
		i += 1

	# Circuitos
	_track_box = HBoxContainer.new()
	_track_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_track_box.offset_left = 24
	_track_box.offset_right = -24
	_track_box.offset_top = -330
	_track_box.offset_bottom = -92
	_track_box.add_theme_constant_override("separation", 14)
	_ui.add_child(_track_box)
	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.25)))
	map_panel.custom_minimum_size = Vector2(250, 230)
	_track_box.add_child(map_panel)
	_map = TrackMap.new()
	_map.custom_minimum_size = Vector2(230, 210)
	map_panel.add_child(_map)
	var j := 0
	for t in TRACKS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 230)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s\n%s\n\n%s" % [t["name"], t["sub"], t["desc"]]
		b.add_theme_font_size_override("font_size", 20)
		var idx := j
		b.pressed.connect(func(): _on_track_card(idx))
		_track_box.add_child(b)
		_track_cards.append(b)
		j += 1

	# Botones de navegación
	_back = Button.new()
	_back.text = "◀ ATRÁS"
	_back.focus_mode = Control.FOCUS_NONE
	_back.add_theme_font_size_override("font_size", 28)
	_back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_back.offset_left = 24
	_back.offset_right = 244
	_back.offset_top = -80
	_back.offset_bottom = -18
	_back.pressed.connect(func(): _go_back())
	_ui.add_child(_back)
	_go = Button.new()
	_go.focus_mode = Control.FOCUS_NONE
	_go.add_theme_font_size_override("font_size", 32)
	_go.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_go.offset_left = -344
	_go.offset_right = -24
	_go.offset_top = -80
	_go.offset_bottom = -18
	_go.pressed.connect(func(): _go_forward())
	_ui.add_child(_go)
	_style_button(_go, Color("1f8f4e"), Color("54d17a"))
	_style_button(_back, Color(0.15, 0.16, 0.24, 0.95), Color(1, 1, 1, 0.4))

	var hint := _mk_label(_ui, "←→↑↓ / cruceta: elegir · Intro / A: aceptar · Esc / B: atrás · o toca la pantalla", 16,
			Color(1, 1, 1, 0.7))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 270
	hint.offset_top = -62
	hint.offset_bottom = -36


func _style_button(b: Button, bg: Color, border: Color) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := _panel_style(border, bg if st != "hover" else bg.lightened(0.12), 3)
		if st == "pressed":
			sb.bg_color = bg.darkened(0.2)
		if st == "disabled":
			sb.bg_color = bg.darkened(0.5)
		b.add_theme_stylebox_override(st, sb)


func _refresh_cards() -> void:
	for k in _cards.size():
		var r: Dictionary = Roster.RACERS[k]
		var ready: bool = Roster.is_modeled(r["id"])
		var sel := k == racer_index
		var base: Color = r["color"]
		var bg := base.darkened(0.55) if ready else Color(0.12, 0.13, 0.18, 0.9)
		var border := YELLOW if sel else (base if ready else Color(1, 1, 1, 0.15))
		for st in ["normal", "hover", "pressed"]:
			var sb := _panel_style(border, bg if st == "normal" else bg.lightened(0.1), 5 if sel else 2)
			_cards[k].add_theme_stylebox_override(st, sb)
		_cards[k].add_theme_color_override("font_color", Color.WHITE if ready else Color(1, 1, 1, 0.45))
		_cards[k].add_theme_color_override("font_hover_color", Color.WHITE if ready else Color(1, 1, 1, 0.55))
	for k in _track_cards.size():
		var t: Dictionary = TRACKS[k]
		var sel := k == track_index
		var bg := Color(0.1, 0.12, 0.22, 0.92) if t["ready"] else Color(0.1, 0.1, 0.13, 0.85)
		for st in ["normal", "hover", "pressed"]:
			_track_cards[k].add_theme_stylebox_override(st,
					_panel_style(YELLOW if sel else Color(1, 1, 1, 0.2), bg if st == "normal" else bg.lightened(0.08), 5 if sel else 2))
		_track_cards[k].add_theme_color_override("font_color", Color.WHITE if t["ready"] else Color(1, 1, 1, 0.45))


func _set_step(s: int) -> void:
	step = s
	_roster_box.visible = step == 0
	_track_box.visible = step == 1
	_step_label.text = ["ELIGE CORREDOR", "ELIGE CIRCUITO"][step]
	_go.text = "SIGUIENTE ▶" if step == 0 else "¡A CORRER! ▶"
	_back.visible = step == 1
	_refresh_cards()
	_update_go()


func _update_go() -> void:
	var ok := Roster.is_modeled(Roster.RACERS[racer_index]["id"]) if step == 0 else bool(TRACKS[track_index]["ready"])
	_go.disabled = not ok


func _select_racer(k: int) -> void:
	racer_index = clampi(k, 0, Roster.RACERS.size() - 1)
	var r: Dictionary = Roster.RACERS[racer_index]
	var ready: bool = Roster.is_modeled(r["id"])
	_info_name.text = r["name"]
	_info_name.add_theme_color_override("font_color", r["color"])
	_info_kart.text = "Kart: " + String(r["kart"])
	if ready:
		_info_extra.text = "Poderes: " + " · ".join(r["powers"]) + " (llegarán más adelante)"
	else:
		_info_extra.text = "Su modelo 3D está en preparación. ¡Pronto en la parrilla!"
	_show_racer(r["id"])
	_refresh_cards()
	_update_go()


func _on_card(k: int) -> void:
	if k == racer_index and Roster.is_modeled(Roster.RACERS[k]["id"]):
		_go_forward()
	else:
		_select_racer(k)


func _on_track_card(k: int) -> void:
	if k == track_index and TRACKS[k]["ready"]:
		_go_forward()
	else:
		track_index = k
		_refresh_cards()
		_update_go()


func _go_forward() -> void:
	if _go.disabled:
		return
	if step == 0:
		_set_step(1)
	else:
		GameState.racer_id = Roster.RACERS[racer_index]["id"]
		GameState.track_id = TRACKS[track_index]["id"]
		GameState.from_menu = true
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _go_back() -> void:
	if step == 1:
		_set_step(0)


func _handle_input() -> void:
	var dx := 0
	var dy := 0
	if Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("steer_right"):
		dx = 1
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("steer_left"):
		dx = -1
	if Input.is_action_just_pressed("ui_down"):
		dy = 1
	if Input.is_action_just_pressed("ui_up"):
		dy = -1
	if step == 0:
		if dx != 0 or dy != 0:
			var n := Roster.RACERS.size()
			_select_racer(posmod(racer_index + dx + dy * COLS, n))
	else:
		if dx != 0:
			track_index = posmod(track_index + dx, TRACKS.size())
			_refresh_cards()
			_update_go()
	if Input.is_action_just_pressed("ui_accept"):
		_go_forward()
	if Input.is_action_just_pressed("ui_cancel"):
		_go_back()


## Plano del circuito dibujado a partir de los puntos de control de El Prat.
class TrackMap extends Control:
	func _draw() -> void:
		var pts: Array = TrackScript.CONTROL_POINTS
		if pts.is_empty():
			return
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		var flat := PackedVector2Array()
		for p in pts:
			var v := Vector2(p.x, p.z) if p is Vector3 else Vector2(p)
			flat.append(v)
			mn = mn.min(v)
			mx = mx.max(v)
		var sz := mx - mn
		var sc := minf((size.x - 20) / sz.x, (size.y - 20) / sz.y)
		var off := (size - sz * sc) * 0.5
		var line := PackedVector2Array()
		var n := flat.size()
		for i in n:
			for t in 8:
				var f := t / 8.0
				var p0 := flat[(i - 1 + n) % n]
				var p1 := flat[i]
				var p2 := flat[(i + 1) % n]
				var p3 := flat[(i + 2) % n]
				var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
						+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f)
				line.append((q - mn) * sc + off)
		line.append(line[0])
		draw_polyline(line, Color(0, 0, 0, 0.6), 12.0, true)
		draw_polyline(line, Color("e8e8f0"), 7.0, true)
		draw_circle(line[0], 8.0, Color("ffd23f"))
