extends CanvasLayer
## Oyun içi HUD: saat/gün/mevsim/hava, para, itibar/lisans, etkileşim istemi, bildirim tostları,
## Gaftî Modu göstergesi, aktif görev özeti. Ayrıca envanter, duraklatma menüsü, gün raporu ve
## mobil kontrolleri barındırır (oyun sahnesine sadece player + hud eklemek yeter). Grup: "hud".

const INVENTORY_SCENE: String = "res://scenes/ui/inventory/inventory.tscn"
const PAUSE_SCENE: String = "res://scenes/ui/menus/pause_menu.tscn"
const DAY_REPORT_SCENE: String = "res://scenes/ui/menus/day_report.tscn"
const MAX_TOASTS: int = 4
const TOAST_TIME: float = 3.6

@onready var root: Control = $Root
@onready var mobile_controls: Control = $Root/MobileControls

var _time_label: Label
var _day_label: Label
var _season_icon: HudIcon
var _weather_icon: HudIcon
var _money_label: Label
var _rep_label: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _toasts: VBoxContainer
var _gafti_box: PanelContainer
var _gafti_bar: ProgressBar
var _quest_box: PanelContainer
var _quest_title: Label
var _quest_obj: Label
var _top_left: PanelContainer
var _top_right: PanelContainer
var _inventory: Control = null
var _pause: CanvasLayer = null
var _poll: float = 0.0
var _gafti_t: float = 0.0
var _shown_money: float = 0.0
var _target_money: int = 0


func _ready() -> void:
	add_to_group(&"hud")
	layer = 10
	_build()
	GaftiUI.apply_theme(root)
	# Envanter ve duraklatma menüsü
	if ResourceLoader.exists(INVENTORY_SCENE):
		_inventory = (load(INVENTORY_SCENE) as PackedScene).instantiate() as Control
		root.add_child(_inventory)
		root.move_child(mobile_controls, root.get_child_count() - 1)
	if ResourceLoader.exists(PAUSE_SCENE):
		_pause = (load(PAUSE_SCENE) as PackedScene).instantiate() as CanvasLayer
		add_child(_pause)
	_connect_signals()
	_update_clock()
	_target_money = int(GaftiUI.get_prop("Economy", &"money", 0))
	_shown_money = float(_target_money)
	_money_label.text = GaftiUI.format_money(_target_money, false)
	_update_reputation()
	_update_quest()
	var settings: Node = GaftiUI.autoload("Settings")
	if settings != null and settings.has_signal(&"changed"):
		settings.connect(&"changed", _apply_scale)
	_apply_scale()


func _connect_signals() -> void:
	var bus: Node = GaftiUI.autoload("EventBus")
	if bus != null:
		bus.connect(&"interaction_prompt", _on_prompt)
		bus.connect(&"notify", show_toast)
	GaftiUI.connect_safe("Economy", &"money_changed", _on_money)
	GaftiUI.connect_safe("Reputation", &"reputation_changed", func(_v: float) -> void: _update_reputation())
	GaftiUI.connect_safe("Reputation", &"license_level_changed", func(_l: int) -> void: _update_reputation())
	GaftiUI.connect_safe("Effects", &"gafti_mode_changed", _on_gafti)
	GaftiUI.connect_safe("QuestManager", &"quest_started", func(_id: StringName) -> void: _update_quest())
	GaftiUI.connect_safe("QuestManager", &"quest_completed", _on_quest_completed)
	GaftiUI.connect_safe("QuestManager", &"quest_progress", func(_id: StringName) -> void: _update_quest())
	GaftiUI.connect_safe("Weather", &"weather_changed", func(_w: StringName) -> void: _update_clock())
	GaftiUI.connect_safe("GameClock", &"season_changed", func(_s: StringName) -> void: _update_clock())


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_update_clock()
	# Para sayacı yumuşak sayar.
	if absf(_shown_money - float(_target_money)) > 0.5:
		_shown_money = lerpf(_shown_money, float(_target_money), 1.0 - exp(-8.0 * delta))
		if absf(_shown_money - float(_target_money)) < 1.0:
			_shown_money = float(_target_money)
		_money_label.text = GaftiUI.format_money(int(round(_shown_money)), false)
	if _gafti_box.visible:
		_gafti_t += delta
		var hue: float = fmod(_gafti_t * 0.15, 1.0)
		_gafti_box.self_modulate = Color.from_hsv(hue, 0.35, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		if _pause != null and _pause.call(&"is_open"):
			return
		if _inventory != null:
			# Başka bir sistem (mini oyun/diyalog) kilitliyken envanter açılmaz, ama açıksa kapanır.
			if not _inventory.call(&"is_open") and _is_world_blocked():
				return
			_inventory.call(&"toggle")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		if _inventory != null and _inventory.call(&"is_open"):
			_inventory.call(&"close")
			get_viewport().set_input_as_handled()
		elif _pause != null and not _pause.call(&"is_open"):
			_pause.call(&"open")
			get_viewport().set_input_as_handled()


var _world_blocked: bool = false


func _is_world_blocked() -> bool:
	return _world_blocked


# --- Genel API -------------------------------------------------------------------

## Bildirim tostu (EventBus.notify buraya bağlı). kind: &"info", &"good", &"bad".
func show_toast(text: String, kind: StringName = &"info") -> void:
	if text == "":
		return
	while _toasts.get_child_count() >= MAX_TOASTS:
		var old: Node = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var p := PanelContainer.new()
	var col: Color = GaftiUI.kind_color(kind)
	p.add_theme_stylebox_override("panel", GaftiUI.panel_style(Color(0.08, 0.16, 0.12, 0.92), col, 14, 16.0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	var dot := ColorRect.new()
	dot.color = col
	dot.custom_minimum_size = Vector2(10, 0)
	hb.add_child(dot)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	hb.add_child(l)
	_toasts.add_child(p)
	p.modulate.a = 0.0
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(TOAST_TIME)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	if kind == &"good":
		GaftiUI.call_safe("AudioManager", &"play_sfx", [&"notify_good"])
	elif kind == &"bad":
		GaftiUI.call_safe("AudioManager", &"play_sfx", [&"notify_bad"])


## Gün sonu raporunu gösterir (yatak çağırır). Kapanınca ui_block_input(false) yayılır.
func show_day_report(report: Dictionary) -> Control:
	if not ResourceLoader.exists(DAY_REPORT_SCENE):
		return null
	var dr: Control = (load(DAY_REPORT_SCENE) as PackedScene).instantiate() as Control
	root.add_child(dr)
	GaftiUI.apply_theme(dr)
	dr.call(&"show_report", report)
	var bus: Node = GaftiUI.autoload("EventBus")
	if bus != null:
		bus.emit_signal(&"ui_block_input", true)
	return dr


func open_inventory() -> void:
	if _inventory != null:
		_inventory.call(&"open")


func open_pause_menu() -> void:
	if _pause != null:
		_pause.call(&"open")


# --- Güncellemeler -----------------------------------------------------------------

func _update_clock() -> void:
	var clock: Node = GaftiUI.autoload("GameClock")
	if clock != null:
		if clock.has_method(&"get_time_string"):
			_time_label.text = String(clock.call(&"get_time_string"))
		var day: int = int(clock.get(&"day")) if clock.get(&"day") != null else 1
		_day_label.text = GaftiUI.tr_or("HUD_DAY", "Gün %d").replace("%d", str(day))
		var season: Variant = clock.get(&"season")
		if season != null:
			var sn: StringName = StringName(season)
			if _season_icon.kind != sn:
				_season_icon.kind = sn
				_season_icon.tooltip_text = tr("SEASON_" + String(sn).to_upper())
		_day_label.text += "  ·  " + GaftiUI.tr_or("SEASON_" + String(_season_icon.kind).to_upper(), String(_season_icon.kind).capitalize())
	else:
		_time_label.text = "--:--"
		_day_label.text = ""
	var w: Variant = GaftiUI.get_prop("Weather", &"current", &"sunny")
	var wn: StringName = StringName(w)
	if _weather_icon.kind != wn:
		_weather_icon.kind = wn


func _on_money(money: int) -> void:
	var diff: int = money - _target_money
	_target_money = money
	if diff != 0:
		_flash_money(diff)
		if diff > 0:
			GaftiUI.call_safe("AudioManager", &"play_sfx", [&"coin"])


func _flash_money(diff: int) -> void:
	var l := Label.new()
	l.text = GaftiUI.format_money(diff, true)
	l.add_theme_color_override("font_color", GaftiUI.COL_GOOD if diff > 0 else GaftiUI.COL_BAD)
	l.add_theme_font_size_override("font_size", 24)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	l.position = _top_right.global_position + Vector2(20, _top_right.size.y * _top_right.scale.y + 6)
	var tw: Tween = l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 40.0, 1.4)
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func _update_reputation() -> void:
	var rep: float = float(GaftiUI.get_prop("Reputation", &"reputation", 0.0))
	var lic: int = int(GaftiUI.get_prop("Reputation", &"license_level", 1))
	_rep_label.text = "%s %.1f   ·   %s %d" % [tr("HUD_REPUTATION"), rep, tr("HUD_LICENSE"), lic]


func _on_prompt(text: String) -> void:
	if text == "":
		_prompt_panel.visible = false
		return
	var touch: bool = GaftiUI.is_touch()
	# Dokunmatikte metin mobil etkileşim butonunda zaten yazıyor.
	_prompt_panel.visible = not touch
	_prompt_label.text = ("[E]  " + text) if not touch else text


func _on_gafti(active: bool, strength: float) -> void:
	_gafti_box.visible = active
	_gafti_bar.value = strength * 100.0
	if not active:
		_gafti_box.self_modulate = Color.WHITE


func _on_quest_completed(id: StringName) -> void:
	var title: String = _quest_text(id, &"get_quest_title", "QUEST_%s_TITLE")
	show_toast(GaftiUI.tr_or("HUD_QUEST_DONE", "Görev tamamlandı: %s").replace("%s", title), &"good")
	_update_quest()


func _update_quest() -> void:
	var qm: Node = GaftiUI.autoload("QuestManager")
	if qm == null or not qm.has_method(&"get_active"):
		_quest_box.visible = false
		return
	var active: Array = qm.call(&"get_active") as Array
	if active.is_empty():
		_quest_box.visible = false
		return
	var id: StringName = StringName(active[0])
	_quest_title.text = _quest_text(id, &"get_quest_title", "QUEST_%s_TITLE")
	var obj: String = ""
	if qm.has_method(&"get_quest_progress_text"):
		obj = String(qm.call(&"get_quest_progress_text", id))
	if obj == "":
		obj = _quest_text(id, &"get_quest_objective", "QUEST_%s_OBJECTIVE")
	if obj == "" and qm.has_method(&"get_quest_summary"):
		obj = String(qm.call(&"get_quest_summary", id))
	_quest_obj.text = obj
	_quest_obj.visible = obj != ""
	_quest_box.visible = true


func _quest_text(id: StringName, method: StringName, key_fmt: String) -> String:
	var qm: Node = GaftiUI.autoload("QuestManager")
	if qm != null and qm.has_method(method):
		var s: String = String(qm.call(method, id))
		if s != "":
			return s
	var key: String = key_fmt % String(id).to_upper()
	var t: String = tr(key)
	return "" if t == key and method != &"get_quest_title" else (t if t != key else String(id).capitalize())


func _apply_scale() -> void:
	var s: float = 1.3 if GaftiUI.is_touch() else 1.0
	for c: Control in [_top_left, _top_right, _quest_box, _gafti_box]:
		c.scale = Vector2(s, s)
	_top_right.pivot_offset = Vector2(_top_right.size.x, 0)


# --- Kurulum ---------------------------------------------------------------------

func _build() -> void:
	var bus: Node = GaftiUI.autoload("EventBus")
	if bus != null:
		bus.connect(&"ui_block_input", func(b: bool) -> void: _world_blocked = b)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var forest: StyleBoxFlat = GaftiUI.panel_style(Color(0.08, 0.17, 0.13, 0.82), Color(0.4, 0.5, 0.34, 0.8), 18, 16.0)

	# Sol üst: saat
	_top_left = PanelContainer.new()
	_top_left.add_theme_stylebox_override("panel", forest)
	_top_left.position = Vector2(24, 20)
	_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top_left)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	_top_left.add_child(hb)
	_season_icon = HudIcon.new()
	_season_icon.custom_minimum_size = Vector2(56, 56)
	_season_icon.kind = &"spring"
	hb.add_child(_season_icon)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -4)
	hb.add_child(tv)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 38)
	_time_label.text = "06:00"
	tv.add_child(_time_label)
	_day_label = Label.new()
	_day_label.add_theme_font_size_override("font_size", 20)
	tv.add_child(_day_label)
	_weather_icon = HudIcon.new()
	_weather_icon.custom_minimum_size = Vector2(56, 56)
	hb.add_child(_weather_icon)

	# Sağ üst: para + itibar
	_top_right = PanelContainer.new()
	_top_right.add_theme_stylebox_override("panel", forest)
	_top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_top_right.offset_right = -24
	_top_right.offset_top = 20
	_top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top_right)
	var mv := VBoxContainer.new()
	_top_right.add_child(mv)
	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 36)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mv.add_child(_money_label)
	_rep_label = Label.new()
	_rep_label.add_theme_font_size_override("font_size", 18)
	_rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mv.add_child(_rep_label)

	# Sol: Gaftî göstergesi + görev
	var left := VBoxContainer.new()
	left.position = Vector2(24, 140)
	left.add_theme_constant_override("separation", 12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	_gafti_box = PanelContainer.new()
	_gafti_box.add_theme_stylebox_override("panel", GaftiUI.panel_style(Color(0.35, 0.15, 0.4, 0.85), Color(0.95, 0.6, 1.0), 18, 14.0))
	_gafti_box.visible = false
	_gafti_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_gafti_box)
	var gv := VBoxContainer.new()
	_gafti_box.add_child(gv)
	var gl := Label.new()
	gl.text = "HUD_GAFTI_MODE"
	gl.add_theme_font_size_override("font_size", 24)
	gv.add_child(gl)
	_gafti_bar = ProgressBar.new()
	_gafti_bar.custom_minimum_size = Vector2(220, 16)
	_gafti_bar.show_percentage = false
	gv.add_child(_gafti_bar)

	_quest_box = PanelContainer.new()
	_quest_box.add_theme_stylebox_override("panel", forest)
	_quest_box.visible = false
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_quest_box)
	var qv := VBoxContainer.new()
	_quest_box.add_child(qv)
	var qh := Label.new()
	qh.text = "HUD_QUEST"
	qh.add_theme_font_size_override("font_size", 16)
	qh.add_theme_color_override("font_color", GaftiUI.COL_ORANGE)
	qv.add_child(qh)
	_quest_title = Label.new()
	_quest_title.add_theme_font_size_override("font_size", 22)
	_quest_title.custom_minimum_size = Vector2(320, 0)
	_quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qv.add_child(_quest_title)
	_quest_obj = Label.new()
	_quest_obj.add_theme_font_size_override("font_size", 18)
	_quest_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_obj.custom_minimum_size = Vector2(320, 0)
	_quest_obj.modulate = Color(1, 1, 1, 0.85)
	qv.add_child(_quest_obj)

	# Üst orta: tostlar
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_top = 24
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	# Alt orta: etkileşim istemi
	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override("panel", GaftiUI.panel_style(Color(0.08, 0.17, 0.13, 0.9), GaftiUI.COL_ORANGE, 20, 18.0))
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.offset_bottom = -120
	_prompt_panel.visible = false
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_panel)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 26)
	_prompt_panel.add_child(_prompt_label)

	# Mobil kontroller en üstte kalsın.
	root.move_child(mobile_controls, root.get_child_count() - 1)
