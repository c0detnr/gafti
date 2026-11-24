extends Node
## Girdi aksiyonlarını kodla tanımlar (project.godot sade kalsın diye).

func _ready() -> void:
	_key(&"move_forward", [KEY_W, KEY_UP])
	_key(&"move_back", [KEY_S, KEY_DOWN])
	_key(&"move_left", [KEY_A, KEY_LEFT])
	_key(&"move_right", [KEY_D, KEY_RIGHT])
	_key(&"sprint", [KEY_SHIFT])
	_key(&"interact", [KEY_E])
	_key(&"inventory", [KEY_TAB, KEY_I])
	_key(&"build_mode", [KEY_B])
	_key(&"pause", [KEY_ESCAPE, KEY_P])
	_key(&"jump", [KEY_SPACE])
	_mouse(&"camera_zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_mouse(&"camera_zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis(&"move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis(&"move_back", JOY_AXIS_LEFT_Y, 1.0)
	_joy_button(&"interact", JOY_BUTTON_A)
	_joy_button(&"pause", JOY_BUTTON_START)


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _key(action: StringName, keys: Array) -> void:
	_ensure(action)
	for k: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		InputMap.action_add_event(action, ev)


func _mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _joy_button(action: StringName, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
