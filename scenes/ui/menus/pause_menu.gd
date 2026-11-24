extends CanvasLayer
## Duraklatma menüsü: Devam, Kaydet, Ayarlar, Ana Menü. Açıkken ağaç duraklatılır.

const SETTINGS_SCENE: String = "res://scenes/ui/menus/settings_menu.tscn"

var _root: Control
var _buttons: VBoxContainer
var _is_open: bool = false
var _settings: Control = null


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_root.visible = true
	get_tree().paused = true
	GaftiUI.call_safe("AudioManager", &"play_sfx", [&"ui_open"])
	(_buttons.get_child(0) as Button).grab_focus()


func close() -> void:
	if not _is_open:
		return
	if _settings != null and is_instance_valid(_settings):
		_settings.queue_free()
		_settings = null
	_is_open = false
	_root.visible = false
	get_tree().paused = false
	GaftiUI.call_safe("AudioManager", &"play_sfx", [&"ui_close"])


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open or (_settings != null and is_instance_valid(_settings)):
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "PAUSE_TITLE"
	title.theme_type_variation = &"GaftiHeading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	vb.add_child(_buttons)
	_add_button("PAUSE_RESUME", close)
	_add_button("PAUSE_SAVE", _on_save)
	_add_button("PAUSE_SETTINGS", _on_settings)
	_add_button("PAUSE_MAIN_MENU", _on_main_menu)
	GaftiUI.apply_theme(_root)


func _add_button(key: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(440, 76)
	b.pressed.connect(cb)
	_buttons.add_child(b)


func _on_save() -> void:
	var save: Node = GaftiUI.autoload("SaveSystem")
	var bus: Node = GaftiUI.autoload("EventBus")
	if save != null and save.has_method(&"save_game"):
		save.call(&"save_game")
		if bus != null:
			bus.emit_signal(&"notify", tr("PAUSE_SAVED"), &"good")
	elif bus != null:
		bus.emit_signal(&"notify", tr("PAUSE_SAVE_FAILED"), &"bad")
	close()


func _on_settings() -> void:
	if not ResourceLoader.exists(SETTINGS_SCENE):
		return
	_settings = (load(SETTINGS_SCENE) as PackedScene).instantiate() as Control
	_root.add_child(_settings)


func _on_main_menu() -> void:
	get_tree().paused = false
	_is_open = false
	var bus: Node = GaftiUI.autoload("EventBus")
	if bus != null:
		bus.emit_signal(&"ui_block_input", false)
	GaftiUI.call_safe("AudioManager", &"set_auto_music", [false])
	get_tree().change_scene_to_file(GameStart.MENU_SCENE)
