extends Control
## Karakter özelleştirme: solda SubViewport'ta dönen önizleme, sağda seçenekler.
## "Tamam" → EventBus.player_customization_changed(data) + confirmed(data).
## Mini oyun olarak açıldıysa (host setup() çağırdı ya da "minigame_host" grubunda bir atası var)
## ayrıca EventBus.minigame_finished(&"customize", data) yayar ve kendini siler.

signal confirmed(data: Dictionary)
signal cancelled()

@export var allow_cancel: bool = false
## true ise açılışta/kapanışta EventBus.ui_block_input yayar (ayna yedeği için).
@export var block_input: bool = false

@onready var _preview: CharacterVisual = %PreviewCharacter
@onready var _options: VBoxContainer = %Options
@onready var _ok_btn: Button = %OkButton
@onready var _cancel_btn: Button = %CancelButton
@onready var _random_btn: Button = %RandomButton
@onready var _viewport_box: SubViewportContainer = %ViewportBox

var data: Dictionary = CharacterVisual.DEFAULT_DATA.duplicate()
var _minigame_mode: bool = false
var _groups: Dictionary = {} # anahtar -> Array[Button]
var _hat_check: CheckButton
var _drag_rot: float = 0.0
var _auto_spin: bool = true
var _dragging: bool = false


func _ready() -> void:
	GaftiUI.apply_theme(self)
	var p: Node = get_tree().get_first_node_in_group(&"player")
	if p != null and p.has_method(&"get_customization"):
		data = (p.call(&"get_customization") as Dictionary).duplicate()
	elif not CharacterVisual.pending_customization.is_empty():
		data = CharacterVisual.pending_customization.duplicate()
	_build_options()
	_ok_btn.pressed.connect(_on_ok)
	_cancel_btn.pressed.connect(_on_cancel)
	_random_btn.pressed.connect(_randomize)
	_viewport_box.gui_input.connect(_on_preview_input)
	_refresh()
	if _is_minigame():
		allow_cancel = true
	_cancel_btn.visible = allow_cancel
	if block_input:
		_emit(&"ui_block_input", [true])
	GaftiUI.wire_click_sounds(self)


## Mini oyun host'u çağırır.
func setup(context: Dictionary) -> void:
	_minigame_mode = true
	allow_cancel = true
	if is_node_ready():
		_cancel_btn.visible = true
	var d: Variant = context.get("data", null)
	if d is Dictionary:
		data.merge(d as Dictionary, true)
		if is_node_ready():
			_refresh()


func _process(delta: float) -> void:
	if _auto_spin and not _dragging:
		_drag_rot += delta * 0.5
	_preview.rotation.y = lerp_angle(_preview.rotation.y, _drag_rot, 1.0 - exp(-10.0 * delta))


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_auto_spin = false
	elif event is InputEventMouseMotion and _dragging:
		_drag_rot += (event as InputEventMouseMotion).relative.x * 0.012


func _is_minigame() -> bool:
	if _minigame_mode:
		return true
	var n: Node = get_parent()
	while n != null:
		if n.is_in_group(&"minigame_host"):
			return true
		n = n.get_parent()
	return false


# --- Seçenekler --------------------------------------------------------------------

func _build_options() -> void:
	_section("CUST_SKIN")
	_swatches("skin", CharacterVisual.SKIN_TONES)
	_section("CUST_HAIR")
	var hair_keys: Array[String] = []
	for i: int in range(1, 7):
		hair_keys.append("CUST_HAIR_%d" % i)
	_choices("hair", hair_keys, 1)
	_swatches("hair_color", CharacterVisual.HAIR_COLORS)
	_section("CUST_BEARD")
	var beard_keys: Array[String] = []
	for i: int in range(0, 5):
		beard_keys.append("CUST_BEARD_%d" % i)
	_choices("beard", beard_keys, 0)
	_section("CUST_HAT")
	_hat_check = CheckButton.new()
	_hat_check.text = "CUST_HAT_KASKET"
	_hat_check.custom_minimum_size = Vector2(0, 64)
	_hat_check.toggled.connect(func(on: bool) -> void: _set_value("hat", on))
	_options.add_child(_hat_check)
	_section("CUST_TOP")
	var top_keys: Array[String] = ["CUST_TOP_RAINCOAT", "CUST_TOP_SWEATER", "CUST_TOP_SHIRT"]
	_choices("top", top_keys, 0, CharacterVisual.TOPS)
	_swatches("top_color", CharacterVisual.TOP_COLORS)
	_section("CUST_BOOTS")
	_swatches("boots_color", CharacterVisual.BOOTS_COLORS)


func _section(key: String) -> void:
	var l := Label.new()
	l.text = key
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", GaftiUI.COL_ORANGE)
	_options.add_child(l)


func _swatches(key: String, palette: Array[Color]) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	_options.add_child(flow)
	var arr: Array[Button] = []
	for i: int in palette.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		var col: Color = palette[i]
		b.add_theme_stylebox_override("normal", GaftiUI.panel_style(col, Color(0, 0, 0, 0.35), 32, 0.0))
		b.add_theme_stylebox_override("hover", GaftiUI.panel_style(col.lightened(0.1), Color(1, 1, 1, 0.6), 32, 0.0))
		b.add_theme_stylebox_override("pressed", GaftiUI.panel_style(col, GaftiUI.COL_CREAM, 32, 0.0))
		b.add_theme_stylebox_override("hover_pressed", GaftiUI.panel_style(col, GaftiUI.COL_CREAM, 32, 0.0))
		b.pressed.connect(_set_value.bind(key, i))
		flow.add_child(b)
		arr.append(b)
	_groups[key] = arr


func _choices(key: String, labels: Array[String], first_value: int, values: Array = []) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	_options.add_child(flow)
	var arr: Array[Button] = []
	for i: int in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(120, 64)
		var v: Variant = values[i] if i < values.size() else first_value + i
		b.set_meta(&"value", v)
		b.pressed.connect(_set_value.bind(key, v))
		flow.add_child(b)
		arr.append(b)
	_groups[key] = arr


func _set_value(key: String, v: Variant) -> void:
	data[key] = v
	_refresh()


func _refresh() -> void:
	_preview.apply_customization(data)
	for key: String in _groups.keys():
		var arr: Array[Button] = _groups[key]
		for i: int in arr.size():
			var b: Button = arr[i]
			var bv: Variant = b.get_meta(&"value", i)
			b.set_pressed_no_signal(str(bv) == str(data.get(key, -1)))
	if _hat_check != null:
		_hat_check.set_pressed_no_signal(bool(data.get("hat", true)))


func _randomize() -> void:
	data["skin"] = randi() % CharacterVisual.SKIN_TONES.size()
	data["hair"] = 1 + randi() % 6
	data["hair_color"] = randi() % CharacterVisual.HAIR_COLORS.size()
	data["beard"] = randi() % 5
	data["hat"] = randf() < 0.5
	data["top"] = CharacterVisual.TOPS[randi() % CharacterVisual.TOPS.size()]
	data["top_color"] = randi() % CharacterVisual.TOP_COLORS.size()
	data["boots_color"] = randi() % CharacterVisual.BOOTS_COLORS.size()
	_refresh()
	if _preview.has_animation(&"wave"):
		_preview.play_one_shot(&"wave")


# --- Bitiş ------------------------------------------------------------------------

func _on_ok() -> void:
	var result: Dictionary = data.duplicate()
	_emit(&"player_customization_changed", [result])
	confirmed.emit(result)
	_finish(result)


func _on_cancel() -> void:
	cancelled.emit()
	_finish({"cancelled": true})


func _finish(result: Dictionary) -> void:
	if block_input:
		_emit(&"ui_block_input", [false])
	if _is_minigame():
		_emit(&"minigame_finished", [&"customize", result])
		queue_free()


func _emit(sig: StringName, args: Array) -> void:
	var bus: Node = GaftiUI.autoload("EventBus")
	if bus != null:
		bus.callv(&"emit_signal", [sig] + args)


func _unhandled_input(event: InputEvent) -> void:
	if allow_cancel and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()
