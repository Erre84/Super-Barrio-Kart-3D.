extends RefCounted
## Registra por código todas las acciones de entrada (teclado + mando).
## Se hace así para no depender de eventos serializados a mano en project.godot
## y para que funcione igual en el editor, en exportaciones y en los tests.

const DEADZONE := 0.15

static func setup() -> void:
	_action("accelerate", [KEY_W, KEY_UP], [JOY_BUTTON_A], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_action("brake", [KEY_S, KEY_DOWN], [JOY_BUTTON_B], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_action("steer_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("steer_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("drift", [KEY_SPACE, KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER], [])
	_action("turbo", [KEY_E, KEY_CTRL], [JOY_BUTTON_X], [])
	_action("look_back", [KEY_Q, KEY_C], [JOY_BUTTON_Y], [])
	_action("reset", [KEY_R], [JOY_BUTTON_BACK], [])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_action("toggle_touch", [KEY_F3], [], [])


static func _action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, DEADZONE)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[0]
		jm.axis_value = a[1]
		InputMap.action_add_event(action, jm)
