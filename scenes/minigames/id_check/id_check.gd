extends CanvasLayer
## Kimlik kontrolü mini oyunu (AGENTS §5, id: &"id_check").
## Host (scenes/minigames/minigame_host.gd) sahneyi açar, start(context) çağırır; biz `finished(result)` yayarız.
## result = { approved: bool, correct: bool, skipped: bool, customer_id: int }
## Kurallar: 18 yaşından küçük → reddet; süresi geçmiş belge → reddet; kimlik olmayan belge → reddet.
## Reşit olmayanlar oyunda asla ürün satın almaz; doğru davranış reddetmektir.

signal finished(result: Dictionary)

const FEEDBACK_SEC: float = 1.6
const LEGAL_AGE: int = 18

var context: Dictionary = {}
var _done: bool = false
var _built: bool = false

var _doc_title: Label
var _card_photo: IdPhoto
var _real_photo: IdPhoto
var _fields: Label
var _today: Label
var _feedback: Label
var _buttons: HBoxContainer
var _customer_line: Label


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if not context.is_empty():
		_fill()


func start(ctx: Dictionary) -> void:
	context = ctx
	if _built:
		_fill()


func _build() -> void:
	_built = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://assets/ui/gafti_theme.tres"):
		root.theme = load("res://assets/ui/gafti_theme.tres") as Theme
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.06, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := VBoxContainer.new()
	center.anchor_left = 0.1
	center.anchor_right = 0.9
	center.anchor_top = 0.06
	center.anchor_bottom = 0.94
	center.add_theme_constant_override(&"separation", 16)
	root.add_child(center)

	var title := Label.new()
	title.text = tr("IDCHECK_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 42)
	center.add_child(title)
	_today = Label.new()
	_today.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_today.modulate = Color(1, 1, 1, 0.8)
	center.add_child(_today)

	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override(&"separation", 40)
	center.add_child(hb)

	# Kimlik kartı
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 440)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.93, 0.9, 0.8)
	cs.border_color = Color(0.3, 0.45, 0.6)
	cs.set_border_width_all(6)
	cs.set_corner_radius_all(26)
	cs.set_content_margin_all(24)
	card.add_theme_stylebox_override(&"panel", cs)
	hb.add_child(card)
	var cv := VBoxContainer.new()
	card.add_child(cv)
	_doc_title = Label.new()
	_doc_title.add_theme_font_size_override(&"font_size", 32)
	_doc_title.add_theme_color_override(&"font_color", Color(0.15, 0.3, 0.45))
	cv.add_child(_doc_title)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override(&"separation", 24)
	cv.add_child(ch)
	_card_photo = IdPhoto.new()
	_card_photo.custom_minimum_size = Vector2(240, 300)
	ch.add_child(_card_photo)
	_fields = Label.new()
	_fields.add_theme_font_size_override(&"font_size", 28)
	_fields.add_theme_color_override(&"font_color", Color(0.12, 0.12, 0.12))
	_fields.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(_fields)

	# Müşterinin kendisi
	var real := VBoxContainer.new()
	real.add_theme_constant_override(&"separation", 8)
	hb.add_child(real)
	var rl := Label.new()
	rl.text = tr("IDCHECK_CUSTOMER")
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.add_theme_font_size_override(&"font_size", 28)
	real.add_child(rl)
	_real_photo = IdPhoto.new()
	_real_photo.custom_minimum_size = Vector2(300, 360)
	_real_photo.bg = Color(0.55, 0.42, 0.3)
	real.add_child(_real_photo)
	_customer_line = Label.new()
	_customer_line.custom_minimum_size = Vector2(300, 0)
	_customer_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_customer_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	real.add_child(_customer_line)

	var rule := Label.new()
	rule.text = tr("IDCHECK_RULES")
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.modulate = Color(1, 0.9, 0.7)
	center.add_child(rule)

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override(&"font_size", 36)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_feedback)

	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override(&"separation", 30)
	center.add_child(_buttons)
	_add_button("IDCHECK_APPROVE", Color(0.3, 0.65, 0.35), approve)
	_add_button("IDCHECK_REJECT", Color(0.75, 0.25, 0.22), reject)
	_add_button("IDCHECK_SKIP", Color(0.45, 0.45, 0.45), skip)


func _add_button(key: String, col: Color, cb: Callable) -> void:
	var b := Button.new()
	b.text = tr(key)
	b.custom_minimum_size = Vector2(280, 84)
	b.add_theme_font_size_override(&"font_size", 32)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(18)
	b.add_theme_stylebox_override(&"normal", sb)
	var sh: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sh.bg_color = col.lightened(0.15)
	b.add_theme_stylebox_override(&"hover", sh)
	b.add_theme_stylebox_override(&"pressed", sh)
	b.pressed.connect(cb)
	_buttons.add_child(b)


func _fill() -> void:
	var year: int = int(context.get("today_year", 2026))
	var day: int = int(GameClock.day) if get_node_or_null(^"/root/GameClock") != null else 1
	_today.text = tr("IDCHECK_TODAY") % [day, year]
	_doc_title.text = tr(String(context.get("doc_key", "IDCARD_DOC_YAYLA")))
	var photo: Dictionary = context.get("photo_look", {}) as Dictionary
	_card_photo.look = photo
	var real: Dictionary = photo.duplicate()
	real["crayon"] = false
	if bool(context.get("minor", false)):
		real["beard"] = "Beard_00"
		real["kid"] = true
	_real_photo.look = real
	var by: int = int(context.get("birth_year", 0))
	var lines: PackedStringArray = []
	lines.append(tr("IDCARD_FIELD_NAME") % String(context.get("name", "?")))
	if by > 0:
		lines.append(tr("IDCARD_FIELD_BIRTH") % [int(context.get("birth_day", 1)), int(context.get("birth_month", 1)), by])
		lines.append(tr("IDCARD_FIELD_EXPIRY") % int(context.get("expiry_year", year + 5)))
		lines.append(tr("IDCARD_FIELD_REGION"))
	else:
		lines.append(tr(String(context.get("doc_key", "")) + "_BODY"))
	_fields.text = "\n".join(lines)
	var v: String = String(context.get("variant", "normal"))
	match v:
		"minor":
			_customer_line.text = tr("IDCHECK_SAY_MINOR")
		"hans":
			_customer_line.text = tr("IDCHECK_SAY_HANS")
		"expired":
			_customer_line.text = tr("IDCHECK_SAY_EXPIRED")
		"invalid":
			_customer_line.text = tr("IDCHECK_SAY_INVALID")
		_:
			_customer_line.text = tr("IDCHECK_SAY_NORMAL_%d" % randi_range(1, 3))


## Kartın gerçekten onaylanması gerekiyor mu? (kurallara göre yeniden hesaplanır)
func should_approve() -> bool:
	if context.has("should_approve"):
		return bool(context["should_approve"])
	var year: int = int(context.get("today_year", 2026))
	var by: int = int(context.get("birth_year", 0))
	if by <= 0 or bool(context.get("minor", false)):
		return false
	if year - by < LEGAL_AGE:
		return false
	return int(context.get("expiry_year", year)) >= year


func approve() -> void:
	_decide(true, false)


func reject() -> void:
	_decide(false, false)


func skip() -> void:
	_decide(true, true)


func _decide(approved: bool, skipped: bool) -> void:
	if _done:
		return
	_done = true
	for b: Node in _buttons.get_children():
		(b as Button).disabled = true
	var correct: bool = false if skipped else (approved == should_approve())
	var rep: Node = get_node_or_null(^"/root/Reputation")
	if rep != null:
		rep.call(&"record_id_check", not skipped)
	if skipped:
		_feedback.text = tr("IDCHECK_FB_SKIPPED")
		_feedback.modulate = Color(1, 0.8, 0.4)
	elif correct:
		_feedback.text = tr("IDCHECK_FB_CORRECT")
		_feedback.modulate = Color(0.5, 1, 0.55)
	else:
		_feedback.text = tr("IDCHECK_FB_WRONG")
		_feedback.modulate = Color(1, 0.5, 0.45)
	var reason: String = String(context.get("reason_key", ""))
	if reason != "" and not skipped:
		_feedback.text += "\n" + tr(reason)
	var result: Dictionary = {
		"approved": approved, "correct": correct, "skipped": skipped,
		"customer_id": int(context.get("customer_id", 0)), "variant": String(context.get("variant", "normal")),
	}
	await get_tree().create_timer(FEEDBACK_SEC, true, false, true).timeout
	finished.emit(result)
