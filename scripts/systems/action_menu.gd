class_name ActionMenu
extends CanvasLayer
## İstasyonlar için basit bağlamsal eylem menüsü (dokunmatik + fare uyumlu, kodla kurulur).
## Kullanım:
##   ActionMenu.open(tr("POT_TITLE"), [{"id": &"water", "text": tr("POT_ACT_WATER")}], _on_pick)
## Seçenek: { id: StringName, text: String, disabled: bool (ops.) }
## Açıkken EventBus.ui_block_input(true) yayar; kapanınca false.

const THEME_PATH: String = "res://assets/ui/gafti_theme.tres"

static var _current: ActionMenu = null

var _callback: Callable
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _box: VBoxContainer


## Menüyü açar. Seçimde callback(id: StringName) çağrılır; iptalde çağrılmaz.
static func open(title: String, options: Array[Dictionary], callback: Callable) -> ActionMenu:
	close_current()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var m: ActionMenu = ActionMenu.new()
	m._callback = callback
	tree.root.add_child(m)
	m._build(title, options)
	_current = m
	return m


static func close_current() -> void:
	if _current != null and is_instance_valid(_current):
		_current._close()
	_current = null


static func is_open() -> bool:
	return _current != null and is_instance_valid(_current)


func _build(title: String, options: Array[Dictionary]) -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(THEME_PATH):
		root.theme = load(THEME_PATH) as Theme
	add_child(root)
	# Yarı saydam arka plan: dışına tıklayınca kapanır.
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	root.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	margin.add_child(_box)
	var t: Label = Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(t)
	var first: Button = null
	for opt: Dictionary in options:
		var b: Button = Button.new()
		b.text = String(opt.get("text", ""))
		b.disabled = bool(opt.get("disabled", false))
		b.custom_minimum_size = Vector2(0, 64) # dokunmatik için büyük hedef
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_on_pick.bind(StringName(opt.get("id", &""))))
		_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	var cancel: Button = Button.new()
	cancel.text = tr("UI_CLOSE")
	cancel.custom_minimum_size = Vector2(0, 56)
	cancel.pressed.connect(_close)
	_box.add_child(cancel)
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_block_input.emit(true)
	if first != null:
		first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close()


func _on_pick(id: StringName) -> void:
	var cb: Callable = _callback
	_close()
	if cb.is_valid():
		cb.call(id)


func _close() -> void:
	if is_queued_for_deletion():
		return
	if _current == self:
		_current = null
	Input.mouse_mode = _prev_mouse_mode
	EventBus.ui_block_input.emit(false)
	queue_free()
