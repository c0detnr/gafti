extends Control
## Envanter paneli: Inventory autoload'unu tür filtreleriyle ızgarada gösterir (kalite yıldızlı).
## open()/close()/toggle(). Açıkken EventBus.ui_block_input(true).

signal closed()

const FILTERS: Array[Dictionary] = [
	{"key": "INV_FILTER_ALL", "kinds": []},
	{"key": "INV_FILTER_SEED", "kinds": [&"seed"]},
	{"key": "INV_FILTER_BUD", "kinds": [&"wet_bud", &"dry_bud"]},
	{"key": "INV_FILTER_JAR", "kinds": [&"jar"]},
	{"key": "INV_FILTER_PREROLL", "kinds": [&"preroll"]},
	{"key": "INV_FILTER_SUPPLY", "kinds": [&"paper", &"filter", &"nutrient"]},
	{"key": "INV_FILTER_TOOL", "kinds": [&"tool"]},
]

var _filter_idx: int = 0
var _grid: GridContainer
var _empty_label: Label
var _filter_buttons: Array[Button] = []
var _is_open: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	GaftiUI.apply_theme(self)
	GaftiUI.connect_safe("Inventory", &"changed", _refresh)


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_refresh()
	_emit_block(true)
	GaftiUI.call_safe("AudioManager", &"play_sfx", [&"ui_open"])
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	_emit_block(false)
	GaftiUI.call_safe("AudioManager", &"play_sfx", [&"ui_close"])
	closed.emit()


func _emit_block(b: bool) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal(&"ui_block_input", b)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 760)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	# Başlık + kapat
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Label.new()
	title.text = "INV_TITLE"
	title.theme_type_variation = &"GaftiHeading"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "UI_CLOSE"
	close_btn.custom_minimum_size = Vector2(140, 64)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	# Filtreler
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 10)
	filters.add_theme_constant_override("v_separation", 10)
	vb.add_child(filters)
	for i: int in FILTERS.size():
		var b := Button.new()
		b.text = String(FILTERS[i]["key"])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(120, 60)
		b.button_pressed = i == 0
		b.pressed.connect(_set_filter.bind(i))
		filters.add_child(b)
		_filter_buttons.append(b)
	# Izgara
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	_empty_label = Label.new()
	_empty_label.text = "INV_EMPTY"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(_empty_label)


func _set_filter(i: int) -> void:
	_filter_idx = i
	for j: int in _filter_buttons.size():
		_filter_buttons[j].button_pressed = j == i
	_refresh()


func _refresh() -> void:
	if _grid == null or not _is_open:
		return
	for c: Node in _grid.get_children():
		c.queue_free()
	var kinds: Array = FILTERS[_filter_idx]["kinds"]
	var items: Array = []
	var inv: Node = GaftiUI.autoload("Inventory")
	if inv != null and inv.has_method(&"get_items"):
		items = inv.call(&"get_items", &"") as Array
	var shown: int = 0
	for it: Variant in items:
		if not it is Dictionary:
			continue
		var d: Dictionary = it as Dictionary
		if not kinds.is_empty() and not kinds.has(StringName(d.get("kind", &""))):
			continue
		_grid.add_child(_make_card(d))
		shown += 1
	_empty_label.visible = shown == 0


func _make_card(d: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(265, 150)
	card.add_theme_stylebox_override("panel", GaftiUI.panel_style(Color(0.19, 0.3, 0.22, 0.95), Color(0.4, 0.5, 0.34), 14, 14.0))
	var vb := VBoxContainer.new()
	card.add_child(vb)
	var id: String = String(d.get("id", ""))
	var kind: String = String(d.get("kind", ""))
	var name_l := Label.new()
	name_l.text = GaftiUI.tr_or("ITEM_" + id.to_upper(), id.capitalize())
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(name_l)
	var strain: String = String(d.get("strain", ""))
	var sub := Label.new()
	var kind_text: String = GaftiUI.tr_or("KIND_" + kind.to_upper(), kind.capitalize())
	sub.text = kind_text if strain == "" else "%s · %s" % [kind_text, GaftiUI.tr_or("STRAIN_" + strain.to_upper(), strain.capitalize())]
	sub.modulate = Color(1, 1, 1, 0.75)
	sub.add_theme_font_size_override("font_size", 18)
	vb.add_child(sub)
	var row := HBoxContainer.new()
	vb.add_child(row)
	var amount := Label.new()
	var grams: float = float(d.get("grams", 0.0))
	var count: int = int(d.get("count", 1))
	amount.text = ("%.1f g" % grams) if grams > 0.0 else ("x%d" % count)
	if grams > 0.0 and count > 1:
		amount.text = "x%d · %.1f g" % [count, grams]
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(amount)
	if d.has("quality") and kind != "tool" and kind != "paper" and kind != "filter":
		var stars := Label.new()
		stars.text = GaftiUI.quality_stars(int(d.get("quality", 0)))
		stars.add_theme_color_override("font_color", GaftiUI.COL_ORANGE)
		stars.tooltip_text = "%d / 100" % int(d.get("quality", 0))
		row.add_child(stars)
	return card
