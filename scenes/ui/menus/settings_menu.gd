extends Control
## Ayarlar: ses kaydırıcıları, grafik kalitesi, gün süresi, dokunmatik kontroller.
## Değerleri Settings autoload'una yazar; kapatınca Settings.save(). Kapanınca "closed" yayar ve kendini siler.

signal closed()

var _quality_buttons: Array[Button] = []
var _day_value: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GaftiUI.apply_theme(self)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "SETTINGS_TITLE"
	title.theme_type_variation = &"GaftiHeading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	vb.add_child(grid)
	_slider_row(grid, "SETTINGS_MASTER", &"master_volume", 0.0, 1.0, 0.05)
	_slider_row(grid, "SETTINGS_MUSIC", &"music_volume", 0.0, 1.0, 0.05)
	_slider_row(grid, "SETTINGS_SFX", &"sfx_volume", 0.0, 1.0, 0.05)

	# Grafik kalitesi
	grid.add_child(_label("SETTINGS_GRAPHICS"))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 10)
	qrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(qrow)
	var q: int = int(GaftiUI.get_prop("Settings", &"graphics_quality", 1))
	for i: int in 3:
		var b := Button.new()
		b.text = ["SETTINGS_Q_LOW", "SETTINGS_Q_MED", "SETTINGS_Q_HIGH"][i]
		b.toggle_mode = true
		b.button_pressed = i == q
		b.custom_minimum_size = Vector2(150, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_quality.bind(i))
		qrow.add_child(b)
		_quality_buttons.append(b)

	# Gün süresi
	grid.add_child(_label("SETTINGS_DAY_LENGTH"))
	var drow := HBoxContainer.new()
	drow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(drow)
	var ds := HSlider.new()
	ds.min_value = 10.0
	ds.max_value = 20.0
	ds.step = 1.0
	ds.value = float(GaftiUI.get_prop("Settings", &"day_length_minutes", 14.0))
	ds.custom_minimum_size = Vector2(380, 56)
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(ds)
	_day_value = Label.new()
	_day_value.custom_minimum_size = Vector2(110, 0)
	_day_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	drow.add_child(_day_value)
	_update_day_label(ds.value)
	ds.value_changed.connect(func(v: float) -> void:
		_write(&"day_length_minutes", v)
		_update_day_label(v))

	# Dokunmatik
	grid.add_child(_label("SETTINGS_TOUCH"))
	var touch := CheckButton.new()
	touch.button_pressed = bool(GaftiUI.get_prop("Settings", &"touch_controls", false))
	touch.custom_minimum_size = Vector2(0, 64)
	touch.toggled.connect(func(on: bool) -> void: _write(&"touch_controls", on))
	grid.add_child(touch)

	var close_btn := Button.new()
	close_btn.text = "UI_BACK"
	close_btn.custom_minimum_size = Vector2(260, 72)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)
	close_btn.grab_focus.call_deferred()


func _label(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.custom_minimum_size = Vector2(260, 0)
	return l


func _slider_row(grid: GridContainer, key: String, prop: StringName, lo: float, hi: float, step: float) -> void:
	grid.add_child(_label(key))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(GaftiUI.get_prop("Settings", prop, 1.0))
	s.custom_minimum_size = Vector2(480, 56)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void: _write(prop, v))
	grid.add_child(s)


func _update_day_label(v: float) -> void:
	_day_value.text = GaftiUI.tr_or("SETTINGS_MINUTES", "%d dk") % int(v)


func _set_quality(i: int) -> void:
	for j: int in _quality_buttons.size():
		_quality_buttons[j].button_pressed = j == i
	_write(&"graphics_quality", i)


func _write(prop: StringName, v: Variant) -> void:
	var s: Node = GaftiUI.autoload("Settings")
	if s == null:
		return
	s.set(prop, v)
	if s.has_method(&"apply"):
		s.call(&"apply")


func close() -> void:
	GaftiUI.call_safe("Settings", &"save")
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
