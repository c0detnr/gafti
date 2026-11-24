extends Control
## Dokunmatik kontroller: sol yarıda yüzen sanal joystick, sağ yarıda kamera sürükleme/pinch zoom,
## bağlamsal etkileşim butonu ve koş/zıpla/çanta/inşa/menü butonları.
## Çoklu dokunuş: her dokunuş (index) tek bir görev üstlenir; tüm girdi _input'ta elle işlenir.
## Sadece Settings.touch_controls true iken görünür.

const JOY_RADIUS: float = 110.0
const KNOB_RADIUS: float = 48.0
const SPRINT_THRESHOLD: float = 0.92
const LEFT_ZONE: float = 0.45 # ekran genişliği oranı

@onready var _interact_btn: Button = %InteractButton
@onready var _sprint_btn: Button = %SprintButton
@onready var _jump_btn: Button = %JumpButton
@onready var _bag_btn: Button = %BagButton
@onready var _build_btn: Button = %BuildButton
@onready var _menu_btn: Button = %MenuButton

var _joy_index: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_vec: Vector2 = Vector2.ZERO
var _cam_touches: Dictionary = {} # index -> Vector2
var _pinch_dist: float = -1.0
var _button_touches: Dictionary = {} # index -> Button
var _blocked: bool = false
var _prompt: String = ""
var _sprint_from_joy: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b: Button in _buttons():
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_NONE
	_interact_btn.visible = false
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.connect(&"interaction_prompt", _on_prompt)
		bus.connect(&"ui_block_input", _on_block)
	var settings: Node = get_node_or_null("/root/Settings")
	if settings != null and settings.has_signal(&"changed"):
		settings.connect(&"changed", _refresh_visibility)
	resized.connect(queue_redraw)
	_refresh_visibility()


func _buttons() -> Array[Button]:
	return [_interact_btn, _sprint_btn, _jump_btn, _bag_btn, _build_btn, _menu_btn]


func _refresh_visibility() -> void:
	var on: bool = GaftiUI.is_touch()
	visible = on
	set_process_input(on)
	if not on:
		release_all()
	_apply_block_visuals()


func _on_block(blocked: bool) -> void:
	_blocked = blocked
	if blocked:
		release_all()
	_apply_block_visuals()


func _apply_block_visuals() -> void:
	for b: Button in [_sprint_btn, _jump_btn, _build_btn]:
		b.visible = not _blocked
	_interact_btn.visible = not _blocked and _prompt != ""
	queue_redraw()


func _on_prompt(text: String) -> void:
	_prompt = text
	_interact_btn.text = text if text != "" else tr("UI_INTERACT")
	_interact_btn.visible = not _blocked and text != ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release_all()


## Tüm basılı aksiyonları bırakır (gizlenince/kilitlenince).
func release_all() -> void:
	_joy_index = -1
	_joy_vec = Vector2.ZERO
	_cam_touches.clear()
	_pinch_dist = -1.0
	_button_touches.clear()
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"sprint", &"jump"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	_sprint_from_joy = false
	for b: Button in _buttons():
		b.button_pressed = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			if _touch_down(st.index, st.position):
				get_viewport().set_input_as_handled()
		else:
			if _touch_up(st.index):
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if _touch_drag(sd.index, sd.position, sd.relative):
			get_viewport().set_input_as_handled()


func _touch_down(index: int, pos: Vector2) -> bool:
	# Önce butonlar
	for b: Button in _buttons():
		if b.is_visible_in_tree() and b.get_global_rect().grow(6.0).has_point(pos):
			_button_touches[index] = b
			b.button_pressed = true
			_button_down(b)
			return true
	if _blocked:
		return false # Mini oyun/diyalog/menü dokunuşları serbest kalsın.
	var w: float = get_viewport_rect().size.x
	if pos.x < w * LEFT_ZONE and _joy_index == -1:
		_joy_index = index
		_joy_center = pos
		_joy_vec = Vector2.ZERO
		queue_redraw()
		return true
	if pos.x >= w * LEFT_ZONE:
		_cam_touches[index] = pos
		_pinch_dist = -1.0
		return true
	return false


func _touch_up(index: int) -> bool:
	if _button_touches.has(index):
		var b: Button = _button_touches[index] as Button
		_button_touches.erase(index)
		b.button_pressed = false
		_button_up(b, true)
		return true
	if index == _joy_index:
		_joy_index = -1
		_set_joystick(Vector2.ZERO)
		queue_redraw()
		return true
	if _cam_touches.has(index):
		_cam_touches.erase(index)
		_pinch_dist = -1.0
		return true
	return false


func _touch_drag(index: int, pos: Vector2, relative: Vector2) -> bool:
	if _button_touches.has(index):
		return true
	if index == _joy_index:
		var off: Vector2 = pos - _joy_center
		# Parmak çok uzaklaşırsa taban onu takip eder.
		if off.length() > JOY_RADIUS * 1.4:
			_joy_center = pos - off.normalized() * JOY_RADIUS * 1.4
			off = pos - _joy_center
		_set_joystick((off / JOY_RADIUS).limit_length(1.0))
		queue_redraw()
		return true
	if _cam_touches.has(index):
		_cam_touches[index] = pos
		var rig: Node = get_tree().get_first_node_in_group(&"camera_rig")
		if _cam_touches.size() >= 2:
			var pts: Array = _cam_touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
			if _pinch_dist > 0.0 and rig != null and rig.has_method(&"zoom_by"):
				rig.call(&"zoom_by", (_pinch_dist - d) * 0.02)
			_pinch_dist = d
		elif rig != null and rig.has_method(&"rotate_by"):
			rig.call(&"rotate_by", relative, -1.0)
		return true
	return false


## Joystick vektörünü move_* aksiyonlarına güçle yazar.
func _set_joystick(v: Vector2) -> void:
	_joy_vec = v
	_axis(&"move_left", &"move_right", v.x)
	_axis(&"move_forward", &"move_back", v.y)
	var full: bool = v.length() >= SPRINT_THRESHOLD
	if full and not _sprint_from_joy:
		_sprint_from_joy = true
		Input.action_press(&"sprint")
	elif not full and _sprint_from_joy:
		_sprint_from_joy = false
		if not _sprint_btn.button_pressed:
			Input.action_release(&"sprint")


func _axis(neg: StringName, pos: StringName, value: float) -> void:
	const DEAD: float = 0.12
	if value < -DEAD:
		Input.action_press(neg, clampf(-value, 0.0, 1.0))
		Input.action_release(pos)
	elif value > DEAD:
		Input.action_press(pos, clampf(value, 0.0, 1.0))
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _button_down(b: Button) -> void:
	if b == _sprint_btn:
		Input.action_press(&"sprint")
	elif b == _jump_btn:
		Input.action_press(&"jump")
		get_tree().create_timer(0.12).timeout.connect(func() -> void: Input.action_release(&"jump"))


func _button_up(b: Button, inside: bool) -> void:
	if b == _sprint_btn:
		if not _sprint_from_joy:
			Input.action_release(&"sprint")
		return
	if not inside:
		return
	GaftiUI.call_safe("AudioManager", &"play_sfx", [&"ui_click"])
	if b == _interact_btn:
		var p: Node = get_tree().get_first_node_in_group(&"player")
		if p != null and p.has_method(&"try_interact"):
			p.call(&"try_interact")
	elif b == _bag_btn:
		_tap_action(&"inventory")
	elif b == _build_btn:
		_tap_action(&"build_mode")
	elif b == _menu_btn:
		_tap_action(&"pause")


## Aksiyonu klavyeden basılmış gibi olay olarak gönderir (diğer sistemler aynı yolla tepki verir).
func _tap_action(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


func _draw() -> void:
	if _blocked:
		return
	var vp: Vector2 = get_viewport_rect().size
	var center: Vector2 = _joy_center if _joy_index != -1 else Vector2(JOY_RADIUS + 70.0, vp.y - JOY_RADIUS - 70.0)
	var alpha: float = 0.55 if _joy_index != -1 else 0.3
	draw_circle(center, JOY_RADIUS, Color(0.09, 0.21, 0.16, alpha * 0.8))
	draw_arc(center, JOY_RADIUS, 0.0, TAU, 48, Color(1.0, 0.94, 0.8, alpha), 4.0, true)
	var knob: Vector2 = center + _joy_vec * JOY_RADIUS
	var kc: Color = Color(0.96, 0.61, 0.31, 0.9) if _joy_vec.length() >= SPRINT_THRESHOLD else Color(1.0, 0.94, 0.8, alpha + 0.3)
	draw_circle(knob, KNOB_RADIUS, kc)
