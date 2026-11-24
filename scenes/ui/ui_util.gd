class_name GaftiUI
extends RefCounted
## Ortak UI yardımcıları: tema, autoload erişimi, düğme sesleri, basit stil kutuları.
## Başka ajanların autoload'ları henüz yoksa bile güvenli çalışır (get_node_or_null).

const THEME_PATH: String = "res://assets/ui/gafti_theme.tres"
const LOGO_PATH: String = "res://assets/logo/gafti_logo.svg"
const LOGO_PNG_PATH: String = "res://assets/logo/gafti_logo_1024.png"

# Sıcak yayla paleti
const COL_FOREST: Color = Color(0.09, 0.21, 0.16, 0.92)
const COL_MOSS: Color = Color(0.19, 0.35, 0.25, 1.0)
const COL_CREAM: Color = Color(1.0, 0.94, 0.8, 1.0)
const COL_ORANGE: Color = Color(0.96, 0.61, 0.31, 1.0)
const COL_GOOD: Color = Color(0.45, 0.78, 0.36, 1.0)
const COL_BAD: Color = Color(0.86, 0.33, 0.27, 1.0)
const COL_INFO: Color = Color(0.36, 0.6, 0.78, 1.0)
const MIN_TOUCH: float = 64.0

static var _theme_cache: Theme = null


## Sahne ağacı (statik fonksiyonlardan erişim için).
static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Autoload düğümünü döner; yoksa null.
static func autoload(autoload_name: String) -> Node:
	var t: SceneTree = tree()
	if t == null or t.root == null:
		return null
	return t.root.get_node_or_null(NodePath(autoload_name))


## Autoload'da metot varsa çağırır, yoksa varsayılanı döner.
static func call_safe(autoload_name: String, method: StringName, args: Array = [], fallback: Variant = null) -> Variant:
	var n: Node = autoload(autoload_name)
	if n != null and n.has_method(method):
		return n.callv(method, args)
	return fallback


## Autoload özelliğini güvenle okur.
static func get_prop(autoload_name: String, prop: StringName, fallback: Variant = null) -> Variant:
	var n: Node = autoload(autoload_name)
	if n == null:
		return fallback
	var v: Variant = n.get(prop)
	return fallback if v == null else v


## Autoload sinyaline güvenle bağlanır.
static func connect_safe(autoload_name: String, sig: StringName, callable: Callable) -> bool:
	var n: Node = autoload(autoload_name)
	if n != null and n.has_signal(sig) and not n.is_connected(sig, callable):
		n.connect(sig, callable)
		return true
	return false


## Oyun temasını döner (dosya varsa onu, yoksa koddan üretilen yedek temayı).
static func get_theme() -> Theme:
	if _theme_cache != null:
		return _theme_cache
	if ResourceLoader.exists(THEME_PATH):
		var t: Theme = load(THEME_PATH) as Theme
		if t != null:
			_theme_cache = t
			return t
	_theme_cache = _build_fallback_theme()
	return _theme_cache


## Control köküne temayı uygular ve düğmelere tık sesi bağlar.
static func apply_theme(root: Control) -> void:
	if root == null:
		return
	root.theme = get_theme()
	wire_click_sounds(root)


## Alt ağaçtaki tüm düğmelere ui_click sesi bağlar.
static func wire_click_sounds(root: Node) -> void:
	for n: Node in root.find_children("*", "BaseButton", true, false):
		var b: BaseButton = n as BaseButton
		if not b.has_meta(&"gafti_click"):
			b.set_meta(&"gafti_click", true)
			b.pressed.connect(_play_click)


static func _play_click() -> void:
	call_safe("AudioManager", &"play_sfx", [&"ui_click"])


## Bildirim türüne göre renk.
static func kind_color(kind: StringName) -> Color:
	match kind:
		&"good":
			return COL_GOOD
		&"bad":
			return COL_BAD
		_:
			return COL_INFO


## Yuvarlatılmış panel stili.
static func panel_style(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 16, margin: float = 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	var bw: int = 3 if border.a > 0.0 else 0
	sb.border_width_left = bw
	sb.border_width_top = bw
	sb.border_width_right = bw
	sb.border_width_bottom = bw
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.7
	sb.content_margin_bottom = margin * 0.7
	return sb


## Logo dokusu (svg/png yoksa null).
static func load_logo() -> Texture2D:
	for p: String in [LOGO_PATH, LOGO_PNG_PATH]:
		if ResourceLoader.exists(p):
			var tex: Texture2D = load(p) as Texture2D
			if tex != null:
				return tex
	return null


## Kalite (0..100) → yıldız metni (5 yıldız).
static func quality_stars(quality: int) -> String:
	var n: int = clampi(int(round(float(quality) / 20.0)), 0, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)


## Çeviri anahtarı yoksa okunabilir yedek.
static func tr_or(key: String, fallback: String) -> String:
	var s: String = TranslationServer.translate(key)
	return fallback if s == key else s


## Ekran dokunmatik modda mı?
static func is_touch() -> bool:
	return bool(get_prop("Settings", &"touch_controls", false))


static func _build_fallback_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	var normal: StyleBoxFlat = panel_style(COL_MOSS, Color(0.4, 0.5, 0.34), 14, 18.0)
	var hover: StyleBoxFlat = panel_style(Color(0.24, 0.42, 0.28), Color(0.6, 0.86, 0.38), 14, 18.0)
	var pressed: StyleBoxFlat = panel_style(Color(0.47, 0.25, 0.14), COL_ORANGE, 14, 18.0)
	for type_name: String in ["Button", "CheckButton", "OptionButton"]:
		t.set_stylebox("normal", type_name, normal)
		t.set_stylebox("hover", type_name, hover)
		t.set_stylebox("pressed", type_name, pressed)
		t.set_stylebox("hover_pressed", type_name, pressed)
		t.set_color("font_color", type_name, COL_CREAM)
		t.set_color("font_hover_color", type_name, COL_CREAM)
		t.set_color("font_pressed_color", type_name, COL_CREAM)
	t.set_stylebox("panel", "PanelContainer", panel_style(COL_FOREST, Color(0.4, 0.5, 0.34), 18, 18.0))
	t.set_stylebox("panel", "Panel", panel_style(Color(0.35, 0.22, 0.12, 0.95), COL_ORANGE, 18, 18.0))
	t.set_color("font_color", "Label", COL_CREAM)
	t.set_color("font_outline_color", "Label", Color(0.05, 0.1, 0.07))
	t.set_type_variation(&"GaftiHeading", &"Label")
	t.set_font_size("font_size", "GaftiHeading", 38)
	return t


## 12500 → "12.500 ₺"
static func format_money(amount: int, signed: bool) -> String:
	var s: String = str(absi(amount))
	var out: String = ""
	var n: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0:
			out = "." + out
	var sign_str: String = "-" if amount < 0 else ("+" if signed and amount > 0 else "")
	return "%s%s ₺" % [sign_str, out]
