extends CanvasLayer
## Diyalog kutusu: portre + ad, daktilo efekti, seçenekler, dokunarak/E ile ilerleme.
## EventBus.dialogue_requested dinler; açıkken EventBus.ui_block_input(true) yayar.
## Diyalog verisi QuestManager.get_dialogue(id) üzerinden gelir (dosya ya da çalışma zamanı).

const CHARS_PER_SEC: float = 48.0
const INPUT_GRACE_SEC: float = 0.2

## Konuşmacı → portre rengi.
const SPEAKER_COLORS: Dictionary = {
	&"muhtar": Color(0.36, 0.5, 0.3), &"fadime": Color(0.75, 0.3, 0.3), &"hayri": Color(0.55, 0.45, 0.3),
	&"cemil": Color(0.85, 0.7, 0.15), &"hans": Color(0.95, 0.55, 0.2), &"nevzat": Color(0.35, 0.4, 0.5),
	&"radio": Color(0.3, 0.3, 0.3), &"player": Color(0.3, 0.55, 0.6), &"customer": Color(0.5, 0.5, 0.6),
	&"cow": Color(0.9, 0.9, 0.85), &"narrator": Color(0.2, 0.2, 0.2), &"temel": Color(0.4, 0.3, 0.55),
}

var dialogue_id: StringName = &""
var is_open: bool = false

var _lines: Array[Dictionary] = []
var _index: int = -1
var _typing: bool = false
var _visible_chars: float = 0.0
var _total_chars: int = 0
var _open_time: float = 0.0

var _root: Control
var _panel: PanelContainer
var _portrait: Panel
var _portrait_style: StyleBoxFlat
var _initial: Label
var _name_label: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"dialogue_box")
	_build_ui()
	_root.visible = false
	EventBus.dialogue_requested.connect(_on_dialogue_requested)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui_input)
	var theme_path: String = "res://assets/ui/gafti_theme.tres"
	if ResourceLoader.exists(theme_path):
		_root.theme = load(theme_path) as Theme
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -300.0
	_panel.offset_bottom = -32.0
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.11, 0.14, 0.12, 0.93)
	ps.border_color = Color(0.95, 0.62, 0.25)
	ps.set_border_width_all(4)
	ps.set_corner_radius_all(22)
	ps.set_content_margin_all(22)
	_panel.add_theme_stylebox_override(&"panel", ps)
	_root.add_child(_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override(&"separation", 22)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(hb)

	_portrait = Panel.new()
	_portrait.custom_minimum_size = Vector2(150, 150)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_style = StyleBoxFlat.new()
	_portrait_style.set_corner_radius_all(75)
	_portrait_style.border_color = Color(1, 1, 1, 0.85)
	_portrait_style.set_border_width_all(4)
	_portrait.add_theme_stylebox_override(&"panel", _portrait_style)
	hb.add_child(_portrait)
	_initial = Label.new()
	_initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initial.add_theme_font_size_override(&"font_size", 72)
	_portrait.add_child(_initial)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override(&"separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(vb)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override(&"font_size", 34)
	_name_label.add_theme_color_override(&"font_color", Color(0.98, 0.72, 0.32))
	vb.add_child(_name_label)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_text.add_theme_font_size_override(&"normal_font_size", 30)
	vb.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override(&"separation", 8)
	vb.add_child(_choices)

	_hint = Label.new()
	_hint.text = tr("DLG_HINT_CONTINUE")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override(&"font_size", 20)
	_hint.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(_hint)


# ---------------------------------------------------------------- Açma / kapama

func _on_dialogue_requested(id: StringName) -> void:
	open(id)


func open(id: StringName) -> void:
	var data: DialogueData = QuestManager.get_dialogue(id)
	if data == null:
		push_warning("Diyalog bulunamadı: " + String(id))
		# Akış takılmasın diye "bitti" olarak bildir.
		_emit_finished_deferred(id)
		return
	var src: Array[Dictionary] = data.lines
	if _gafti_active() and not data.gafti_lines.is_empty():
		src = data.gafti_lines
	if src.is_empty():
		_emit_finished_deferred(id)
		return
	_lines.clear()
	if data.pick_random:
		var line: Dictionary = src[randi() % src.size()].duplicate(true)
		line["next"] = -1
		_lines.append(line)
	else:
		for l: Dictionary in src:
			_lines.append(l.duplicate(true))
	dialogue_id = id
	if not is_open:
		is_open = true
		_root.visible = true
		EventBus.ui_block_input.emit(true)
		EventBus.interaction_prompt.emit("")
	_open_time = Time.get_ticks_msec() / 1000.0
	_show_line(0)


func _emit_finished_deferred(id: StringName) -> void:
	await get_tree().process_frame
	EventBus.dialogue_finished.emit(id)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	_clear_choices()
	var id: StringName = dialogue_id
	dialogue_id = &""
	EventBus.ui_block_input.emit(false)
	EventBus.dialogue_finished.emit(id)


# ---------------------------------------------------------------- Satırlar

func _show_line(i: int) -> void:
	if i < 0 or i >= _lines.size():
		close()
		return
	_index = i
	var line: Dictionary = _lines[i]
	var speaker: StringName = StringName(line.get("speaker", &"narrator"))
	_set_speaker(speaker)
	var body: String = String(line.get("text", ""))
	if body == "":
		body = tr(String(line.get("text_key", "")))
	if _gafti_active():
		body = "[wave amp=28 freq=4]" + body + "[/wave]"
	_text.text = body
	_total_chars = _text.get_total_character_count()
	_visible_chars = 0.0
	_text.visible_characters = 0
	_typing = true
	_clear_choices()
	_hint.visible = false
	var action: String = String(line.get("action", ""))
	if action != "":
		QuestManager.run_action(action)
	_play_blip()


func _set_speaker(speaker: StringName) -> void:
	var col: Color = SPEAKER_COLORS.get(speaker, Color(0.45, 0.45, 0.5)) as Color
	_portrait_style.bg_color = col
	var name_text: String = ""
	match speaker:
		&"narrator":
			name_text = ""
		&"player":
			name_text = tr("NPC_NAME_PLAYER")
		_:
			name_text = tr("NPC_NAME_" + String(speaker).to_upper())
	_name_label.text = name_text
	_portrait.visible = speaker != &"narrator"
	_initial.text = name_text.substr(0, 1) if name_text != "" else ""


func _process(delta: float) -> void:
	if not is_open or not _typing:
		return
	var speed: float = CHARS_PER_SEC * (0.6 if _gafti_active() else 1.0)
	_visible_chars += delta * speed
	_text.visible_characters = int(_visible_chars)
	if int(_visible_chars) >= _total_chars:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	var line: Dictionary = _lines[_index]
	var choices: Array = line.get("choices", []) as Array
	if choices.is_empty():
		_hint.visible = true
		return
	for c_i: int in range(choices.size()):
		var c: Dictionary = choices[c_i] as Dictionary
		var b := Button.new()
		var label: String = String(c.get("text", ""))
		if label == "":
			label = tr(String(c.get("text_key", "")))
		b.text = "%d) %s" % [c_i + 1, label]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 54)
		b.add_theme_font_size_override(&"font_size", 26)
		b.pressed.connect(_on_choice.bind(c_i))
		_choices.add_child(b)
	(_choices.get_child(0) as Button).grab_focus.call_deferred()


func _on_choice(c_i: int) -> void:
	if not is_open or _index < 0:
		return
	var choices: Array = _lines[_index].get("choices", []) as Array
	if c_i >= choices.size():
		return
	var c: Dictionary = choices[c_i] as Dictionary
	var cur: StringName = dialogue_id
	var action: String = String(c.get("action", ""))
	var next: int = int(c.get("next", _index + 1))
	if action != "":
		QuestManager.run_action(action)
	# Eylem bu kutuyu başka bir diyaloğa geçirdiyse eski akışı sürdürme.
	if dialogue_id != cur or not is_open:
		return
	if next < 0:
		close()
	else:
		_show_line(next)


## İlerle: yazıyorsa tamamla, değilse sonraki satır.
func advance() -> void:
	if not is_open:
		return
	if _typing:
		_finish_typing()
		return
	if _choices.get_child_count() > 0:
		return
	var line: Dictionary = _lines[_index]
	var next: int = int(line.get("next", _index + 1))
	if next < 0:
		close()
	else:
		_show_line(next)


## Test/otomasyon için: i'nci seçeneği seç.
func choose(c_i: int) -> void:
	if _typing:
		_finish_typing()
	_on_choice(c_i)


func has_choices() -> bool:
	return not _typing and _choices.get_child_count() > 0


func _clear_choices() -> void:
	for c: Node in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


# ---------------------------------------------------------------- Girdi

func _on_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	var pressed: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed and _grace_over():
		advance()
		_root.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		if _grace_over():
			advance()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and _choices.get_child_count() > 0:
		var k: int = (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			choose(k - KEY_1)
			get_viewport().set_input_as_handled()


func _grace_over() -> bool:
	return Time.get_ticks_msec() / 1000.0 - _open_time > INPUT_GRACE_SEC


func _gafti_active() -> bool:
	var fx: Node = get_node_or_null(^"/root/Effects")
	return fx != null and bool(fx.get(&"gafti_active"))


func _play_blip() -> void:
	var am: Node = get_node_or_null(^"/root/AudioManager")
	if am != null and am.has_method(&"play_sfx"):
		am.call(&"play_sfx", &"dialogue_blip", null)
