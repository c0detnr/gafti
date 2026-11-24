extends CanvasLayer
## Hırdavatçı satın alma arayüzü. Ajan A'nın Catalog'unu (scripts/systems/catalog.gd) kullanır:
## Catalog.get_catalog() -> Array[Dictionary] {id, kind, name, name_key, description, price, min_license, available}
## Catalog.buy(id) -> bool

const CATALOG_PATH: String = "res://scripts/systems/catalog.gd"
const TABS: Array[StringName] = [&"seed", &"supply", &"buildable"]

var _list: VBoxContainer
var _money: Label
var _tab: StringName = &"seed"
var _catalog: Script = null
var _prev_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"hardware_ui")
	if ResourceLoader.exists(CATALOG_PATH):
		_catalog = load(CATALOG_PATH) as Script
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_block_input.emit(true)
	EventBus.interaction_prompt.emit("")
	_build()
	refresh()
	Economy.money_changed.connect(_on_money_changed)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://assets/ui/gafti_theme.tres"):
		root.theme = load("res://assets/ui/gafti_theme.tres") as Theme
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 12)
	panel.add_child(vb)

	var top := HBoxContainer.new()
	vb.add_child(top)
	var title := Label.new()
	title.text = tr("HARDWARE_TITLE")
	title.add_theme_font_size_override(&"font_size", 38)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_money = Label.new()
	_money.add_theme_font_size_override(&"font_size", 30)
	top.add_child(_money)

	var greet := Label.new()
	greet.text = tr("HARDWARE_GREET_%d" % randi_range(1, 3))
	greet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	greet.modulate = Color(1, 1, 1, 0.8)
	vb.add_child(greet)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 8)
	vb.add_child(tabs)
	for t: StringName in TABS:
		var b := Button.new()
		b.text = tr("HARDWARE_TAB_" + String(t).to_upper())
		b.custom_minimum_size = Vector2(180, 56)
		b.pressed.connect(_on_tab.bind(t))
		tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 8)
	scroll.add_child(_list)

	var close_b := Button.new()
	close_b.text = tr("UI_CLOSE")
	close_b.custom_minimum_size = Vector2(220, 64)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_b.pressed.connect(close)
	vb.add_child(close_b)


func get_entries() -> Array:
	if _catalog == null:
		return []
	var v: Variant = _catalog.call(&"get_catalog")
	return v as Array if v is Array else []


func refresh() -> void:
	_money.text = "%d ₺" % Economy.money
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var entries: Array = get_entries()
	if entries.is_empty():
		var l := Label.new()
		l.text = tr("HARDWARE_EMPTY")
		_list.add_child(l)
		return
	for e: Variant in entries:
		var d: Dictionary = e as Dictionary
		if StringName(d.get("kind", &"")) != _tab:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := Label.new()
		var nm: String = String(d.get("name", ""))
		if nm == "":
			nm = tr(String(d.get("name_key", d.get("id", ""))))
		n.text = nm
		n.add_theme_font_size_override(&"font_size", 28)
		info.add_child(n)
		var desc := Label.new()
		desc.text = String(d.get("description", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.modulate = Color(1, 1, 1, 0.7)
		info.add_child(desc)
		row.add_child(info)
		var buy := Button.new()
		var available: bool = bool(d.get("available", true))
		var price: int = int(d.get("price", 0))
		if available:
			buy.text = tr("HARDWARE_BUY") % price
		else:
			buy.text = tr("HARDWARE_LOCKED") % int(d.get("min_license", 1))
		buy.disabled = not available or Economy.money < price
		buy.custom_minimum_size = Vector2(220, 60)
		buy.pressed.connect(_on_buy.bind(StringName(d.get("id", &""))))
		row.add_child(buy)
		_list.add_child(row)


func _on_tab(t: StringName) -> void:
	_tab = t
	refresh()


func _on_buy(id: StringName) -> void:
	if _catalog == null:
		return
	var ok: bool = bool(_catalog.call(&"buy", id))
	if ok:
		EventBus.notify.emit(tr("HARDWARE_BOUGHT"), &"good")
		QuestManager.notify_event(&"item_bought_hardware", {"id": id})
	refresh.call_deferred()


func _on_money_changed(_m: int) -> void:
	if is_inside_tree():
		_money.text = "%d ₺" % Economy.money


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if Economy.money_changed.is_connected(_on_money_changed):
		Economy.money_changed.disconnect(_on_money_changed)
	Input.mouse_mode = _prev_mouse
	EventBus.ui_block_input.emit(false)
	queue_free()
