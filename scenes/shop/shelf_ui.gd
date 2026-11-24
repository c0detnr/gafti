class_name ShelfUI
extends CanvasLayer
## Raf düzenleme arayüzü: soldaki slotlar (fiyat, etiket, kaldır), sağda envanterdeki satılabilir ürünler.

var shelf: ShelfStation = null

var _slot_box: VBoxContainer
var _inv_box: VBoxContainer
var _prev_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"shelf_ui")
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_block_input.emit(true)
	EventBus.interaction_prompt.emit("")
	_build()
	refresh()


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
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = tr("SHELF_TITLE")
	title.add_theme_font_size_override(&"font_size", 38)
	vb.add_child(title)
	var hint := Label.new()
	hint.text = tr("SHELF_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.75)
	vb.add_child(hint)

	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override(&"separation", 24)
	vb.add_child(hb)

	var left := ScrollContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.4
	hb.add_child(left)
	_slot_box = VBoxContainer.new()
	_slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_box.add_theme_constant_override(&"separation", 10)
	left.add_child(_slot_box)

	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	_inv_box = VBoxContainer.new()
	_inv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_box.add_theme_constant_override(&"separation", 8)
	right.add_child(_inv_box)

	var close_b := Button.new()
	close_b.text = tr("UI_CLOSE")
	close_b.custom_minimum_size = Vector2(220, 64)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_b.pressed.connect(close)
	vb.add_child(close_b)


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func item_label(item: Dictionary) -> String:
	var kind: String = String(item.get("kind", ""))
	var strain: String = String(item.get("strain", ""))
	var strain_name: String = _t("STRAIN_" + strain.to_upper())
	if strain_name == "STRAIN_" + strain.to_upper():
		strain_name = strain.capitalize()
	var base: String = _t("ITEM_KIND_" + kind.to_upper())
	if kind == "dry_bud" and float(item.get("grams", 1.0)) > 1.0:
		base = _t("SHELF_BAG") % int(float(item.get("grams", 5.0)))
	return "%s — %s (%s %d)" % [base, strain_name, _t("UI_QUALITY_SHORT"), int(item.get("quality", 0))]


func refresh() -> void:
	if shelf == null:
		return
	for c: Node in _slot_box.get_children():
		_slot_box.remove_child(c)
		c.queue_free()
	for c: Node in _inv_box.get_children():
		_inv_box.remove_child(c)
		c.queue_free()

	var head := Label.new()
	head.text = tr("SHELF_SLOTS")
	head.add_theme_font_size_override(&"font_size", 28)
	_slot_box.add_child(head)
	for i: int in range(shelf.slots.size()):
		var slot: Dictionary = shelf.slots[i]
		var item: Dictionary = slot.get("item", {}) as Dictionary
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		if item.is_empty():
			l.text = "%d. %s" % [i + 1, tr("SHELF_EMPTY")]
			l.modulate = Color(1, 1, 1, 0.5)
		else:
			l.text = "%d. %s" % [i + 1, item_label(item)]
			var price := SpinBox.new()
			price.min_value = 1
			price.max_value = 99999
			price.step = 5
			price.value = int(slot.get("price", 1))
			price.suffix = "₺"
			price.custom_minimum_size = Vector2(170, 0)
			price.tooltip_text = tr("SHELF_FAIR_PRICE") % shelf.fair_price(i)
			price.value_changed.connect(_on_price_changed.bind(i))
			row.add_child(price)
			var lab := CheckBox.new()
			lab.text = tr("SHELF_LABEL")
			lab.button_pressed = bool(slot.get("labeled", false))
			lab.toggled.connect(_on_label_toggled.bind(i))
			row.add_child(lab)
			var rm := Button.new()
			rm.text = tr("SHELF_REMOVE")
			rm.disabled = int(slot.get("reserved_by", 0)) != 0
			rm.pressed.connect(_on_remove.bind(i))
			row.add_child(rm)
		_slot_box.add_child(row)

	var head2 := Label.new()
	head2.text = tr("SHELF_INVENTORY")
	head2.add_theme_font_size_override(&"font_size", 28)
	_inv_box.add_child(head2)
	var any: bool = false
	for kind: StringName in ShelfStation.SELLABLE_KINDS:
		for it: Dictionary in Inventory.get_items(kind):
			if int(it.get("count", 0)) <= 0:
				continue
			any = true
			var row2 := HBoxContainer.new()
			var l2 := Label.new()
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l2.clip_text = true
			var unit: String = tr("UI_GRAMS_SHORT") if kind == &"dry_bud" else tr("UI_PIECES_SHORT")
			l2.text = "%s ×%d %s" % [item_label(it), int(it.get("count", 0)), unit]
			row2.add_child(l2)
			var put := Button.new()
			put.text = tr("SHELF_PUT")
			put.disabled = shelf.first_empty_slot() < 0
			put.pressed.connect(_on_put.bind(it))
			row2.add_child(put)
			_inv_box.add_child(row2)
	if not any:
		var none := Label.new()
		none.text = tr("SHELF_NO_PRODUCTS")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.modulate = Color(1, 1, 1, 0.6)
		_inv_box.add_child(none)


func _on_price_changed(v: float, i: int) -> void:
	shelf.set_price(i, int(v))


func _on_label_toggled(on: bool, i: int) -> void:
	shelf.set_labeled(i, on)


func _on_remove(i: int) -> void:
	shelf.unstock(i)
	refresh.call_deferred()


func _on_put(it: Dictionary) -> void:
	shelf.stock_from_inventory(it)
	refresh.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	Input.mouse_mode = _prev_mouse
	EventBus.ui_block_input.emit(false)
	queue_free()
