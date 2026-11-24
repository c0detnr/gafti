extends Control
## Gün sonu raporu (uyuyunca). show_report(Economy.get_day_report()).
## Bilinen anahtarlar: day, income, expenses, profit, entries[{amount, reason}], bills_due, money.

signal closed()

var _list: VBoxContainer
var _title: Label
var _summary: GridContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GaftiUI.apply_theme(self)


func show_report(report: Dictionary) -> void:
	if _title == null:
		_build()
	var day: int = int(report.get("day", GaftiUI.get_prop("GameClock", &"day", 1)))
	_title.text = GaftiUI.tr_or("REPORT_TITLE", "%d. Gün Raporu").replace("%d", str(day))
	for c: Node in _summary.get_children():
		c.queue_free()
	for c2: Node in _list.get_children():
		c2.queue_free()
	_row("REPORT_INCOME", int(report.get("income", 0)), GaftiUI.COL_GOOD)
	_row("REPORT_EXPENSES", -absi(int(report.get("expenses", 0))), GaftiUI.COL_BAD)
	var profit: int = int(report.get("profit", int(report.get("income", 0)) - absi(int(report.get("expenses", 0)))))
	_row("REPORT_PROFIT", profit, GaftiUI.COL_GOOD if profit >= 0 else GaftiUI.COL_BAD)
	if report.has("bills_due"):
		_row("REPORT_BILLS", -absi(int(report.get("bills_due", 0))), GaftiUI.COL_ORANGE)
	if report.has("money"):
		_row("REPORT_MONEY", int(report.get("money", 0)), GaftiUI.COL_CREAM)
	var entries: Variant = report.get("entries", [])
	if entries is Array:
		for e: Variant in (entries as Array).slice(-12):
			if e is Dictionary:
				var ed: Dictionary = e as Dictionary
				var l := Label.new()
				var amt: int = int(ed.get("amount", 0))
				l.text = "%s   %s" % [GaftiUI.format_money(amt, true), String(ed.get("reason", ""))]
				l.add_theme_color_override("font_color", GaftiUI.COL_GOOD if amt >= 0 else GaftiUI.COL_BAD)
				l.add_theme_font_size_override("font_size", 18)
				_list.add_child(l)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	GaftiUI.call_safe("AudioManager", &"play_sfx", [&"ui_open"])


func _row(key: String, amount: int, col: Color) -> void:
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(320, 0)
	_summary.add_child(k)
	var v := Label.new()
	v.text = GaftiUI.format_money(amount, false)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_color_override("font_color", col)
	v.add_theme_font_size_override("font_size", 28)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_child(v)


func _build() -> void:
	if _title != null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	_title = Label.new()
	_title.theme_type_variation = &"GaftiHeading"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_summary = GridContainer.new()
	_summary.columns = 2
	_summary.add_theme_constant_override("v_separation", 8)
	vb.add_child(_summary)
	vb.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var ok := Button.new()
	ok.text = "REPORT_CONTINUE"
	ok.custom_minimum_size = Vector2(340, 76)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_on_ok)
	vb.add_child(ok)


func _on_ok() -> void:
	closed.emit()
	var bus: Node = GaftiUI.autoload("EventBus")
	if bus != null:
		bus.emit_signal(&"ui_block_input", false)
	queue_free()
