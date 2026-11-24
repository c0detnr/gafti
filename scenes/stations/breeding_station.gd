class_name BreedingStation
extends StationBase
## Çaprazlama masası: iki türün birer tohumu → yeni türden 3 tohum. Oyuncu isim verir.
## Ayrıca Tohum Defteri'ni (SeedBook) gösterir.

const MODEL: String = "res://assets/models/props/crate.glb"
const OFFSPRING_SEEDS: int = 3

var _panel: CanvasLayer = null


func _ready() -> void:
	super._ready()
	var m: Node3D = ModelLoader.instance(MODEL, Vector3(1.1, 0.85, 0.6), Color(0.45, 0.3, 0.2))
	m.name = "Model"
	add_child(m)


func get_interact_text() -> String:
	return tr("BREED_PROMPT")


func interact(_player: Node) -> void:
	open_panel()


## Çaprazlar: her ebeveynden 1 tohum harcar, yeni türü kaydeder, 3 tohum verir.
## Başarılıysa yeni tür id'si, değilse &"" döner.
func breed(a_id: StringName, b_id: StringName, new_name: String) -> StringName:
	var a: StrainData = SeedBook.get_strain(a_id)
	var b: StrainData = SeedBook.get_strain(b_id)
	if a == null or b == null or a_id == b_id:
		notify(tr("BREED_NEED_TWO"), &"bad")
		return &""
	var nm: String = new_name.strip_edges()
	if nm == "":
		notify(tr("BREED_NEED_NAME"), &"bad")
		return &""
	var sa: StringName = Inventory.make_id(&"seed", a_id)
	var sb: StringName = Inventory.make_id(&"seed", b_id)
	if Inventory.count_of(sa) < 1 or Inventory.count_of(sb) < 1:
		notify(tr("BREED_NEED_SEEDS"), &"bad")
		return &""
	Inventory.remove_item(sa, 1)
	Inventory.remove_item(sb, 1)
	var child: StrainData = Genetics.cross(a, b, nm.left(24))
	var id: StringName = SeedBook.register_custom(child)
	Inventory.add_item(Inventory.make_item(&"seed", id, 0, OFFSPRING_SEEDS, 0.0))
	var kind: StringName = &"good"
	var msg: String = tr("BREED_DONE") % child.get_display_name()
	if not child.rare_traits.is_empty():
		msg += " " + tr("BREED_RARE")
	notify(msg, kind)
	play_sfx(&"breed")
	quest_event(&"strain_bred", {"strain": id, "parents": [a_id, b_id]})
	return id


## Nadir özellik adları (yerelleştirilmiş).
static func trait_names(s: StrainData) -> String:
	var parts: PackedStringArray = []
	for t: StringName in s.rare_traits:
		parts.append(TranslationServer.translate("TRAIT_" + String(t).to_upper()))
	return ", ".join(parts)


# ---------------------------------------------------------------------------
# Arayüz (kodla kurulan panel)
# ---------------------------------------------------------------------------

func open_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	_panel = CanvasLayer.new()
	_panel.layer = 50
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(ActionMenu.THEME_PATH):
		root.theme = load(ActionMenu.THEME_PATH) as Theme
	_panel.add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var pc: PanelContainer = PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	pc.custom_minimum_size = Vector2(900, 620)
	root.add_child(pc)
	var mc: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 20)
	pc.add_child(mc)
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	mc.add_child(hb)

	# Sol: çaprazlama formu.
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	hb.add_child(left)
	left.add_child(_label(tr("BREED_TITLE"), 30))
	left.add_child(_label(tr("BREED_PARENT_A"), 22))
	var opt_a: OptionButton = _strain_option()
	left.add_child(opt_a)
	left.add_child(_label(tr("BREED_PARENT_B"), 22))
	var opt_b: OptionButton = _strain_option()
	if opt_b.item_count > 1:
		opt_b.select(1)
	left.add_child(opt_b)
	left.add_child(_label(tr("BREED_NAME"), 22))
	var name_edit: LineEdit = LineEdit.new()
	name_edit.placeholder_text = tr("BREED_NAME_HINT")
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(0, 56)
	left.add_child(name_edit)
	var go: Button = Button.new()
	go.text = tr("BREED_ACT")
	go.custom_minimum_size = Vector2(0, 64)
	left.add_child(go)
	var close: Button = Button.new()
	close.text = tr("UI_CLOSE")
	close.custom_minimum_size = Vector2(0, 56)
	left.add_child(close)

	# Sağ: Tohum Defteri.
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	right.add_child(_label(tr("SEEDBOOK_TITLE"), 30))
	var book: RichTextLabel = RichTextLabel.new()
	book.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book.bbcode_enabled = true
	book.scroll_active = true
	right.add_child(book)
	_fill_book(book)

	go.pressed.connect(func() -> void:
		var a: StringName = opt_a.get_item_metadata(opt_a.selected) if opt_a.selected >= 0 else &""
		var b: StringName = opt_b.get_item_metadata(opt_b.selected) if opt_b.selected >= 0 else &""
		if breed(a, b, name_edit.text) != &"":
			name_edit.text = ""
			_refill_option(opt_a)
			_refill_option(opt_b)
			_fill_book(book)
	)
	close.pressed.connect(close_panel)
	get_tree().root.add_child(_panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_block_input.emit(true)


func close_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	EventBus.ui_block_input.emit(false)


func _label(text: String, size: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _strain_option() -> OptionButton:
	var o: OptionButton = OptionButton.new()
	o.custom_minimum_size = Vector2(0, 56)
	_refill_option(o)
	return o


## Sadece tohumu olan türler listelenir.
func _refill_option(o: OptionButton) -> void:
	var prev: int = o.selected
	o.clear()
	for it: Dictionary in Inventory.get_items(&"seed"):
		var s: StrainData = SeedBook.get_strain(it["strain"])
		if s == null:
			continue
		o.add_item("%s ×%d" % [s.get_display_name(), int(it["count"])])
		o.set_item_metadata(o.item_count - 1, s.id)
	if prev >= 0 and prev < o.item_count:
		o.select(prev)


func _fill_book(book: RichTextLabel) -> void:
	var t: String = ""
	for s: StrainData in SeedBook.get_discovered():
		t += "[b]%s[/b]  (%s %d)\n" % [s.get_display_name(), tr("SEEDBOOK_GEN"), s.generation]
		t += tr("SEEDBOOK_STATS") % [int(s.yield_trait), int(s.speed), int(s.hardiness), int(s.aroma), int(s.quality_potential)]
		var tn: String = trait_names(s)
		if tn != "":
			t += "\n[color=#e0a040]" + tr("SEEDBOOK_RARE") % tn + "[/color]"
		t += "\n\n"
	book.text = t


func _exit_tree() -> void:
	if _panel != null and is_instance_valid(_panel):
		close_panel()
