class_name MinigameMeter
extends Control
## Basit çizilen gösterge çubuğu: değer, hedef bölge (yardım), işaretçi. Yatay ya da dikey.
## bins doluysa ısı haritası şeridi olarak çizilir (her hücre hedefe göre renklenir).

var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var zone_min: float = 0.4
var zone_max: float = 0.7
var show_zone: bool = true:
	set(v):
		show_zone = v
		queue_redraw()
var vertical: bool = false
var left_text: String = ""
var right_text: String = ""
var fill_color: Color = Color(1.0, 0.8, 0.35)
var bins: PackedFloat32Array = PackedFloat32Array()
var bin_target: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_bins(b: PackedFloat32Array, target: float) -> void:
	bins = b
	bin_target = maxf(target, 0.0001)
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.05, 0.07, 0.05, 0.75))
	if bins.size() > 0:
		_draw_heat(r)
	else:
		_draw_bar(r)
	draw_rect(r, Color(1, 1, 1, 0.85), false, 3.0)
	var font: Font = get_theme_default_font()
	if font != null and (left_text != "" or right_text != ""):
		var fs: int = 24
		if vertical:
			draw_string(font, Vector2(-10, -10), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, Vector2(-10, size.y + 30), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		else:
			draw_string(font, Vector2(0, -10), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var w: float = font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(size.x - w, -10), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)


func _draw_bar(r: Rect2) -> void:
	if show_zone:
		var zr: Rect2
		if vertical:
			zr = Rect2(0, r.size.y * (1.0 - zone_max), r.size.x, r.size.y * (zone_max - zone_min))
		else:
			zr = Rect2(r.size.x * zone_min, 0, r.size.x * (zone_max - zone_min), r.size.y)
		draw_rect(zr, Color(0.35, 0.85, 0.4, 0.45))
	var in_zone: bool = value >= zone_min and value <= zone_max
	var c: Color = fill_color
	if show_zone:
		c = Color(0.45, 0.95, 0.45) if in_zone else Color(1.0, 0.5, 0.35)
	if vertical:
		var h: float = r.size.y * value
		draw_rect(Rect2(4, r.size.y - h, r.size.x - 8, h), c)
		draw_line(Vector2(-8, r.size.y - h), Vector2(r.size.x + 8, r.size.y - h), Color.WHITE, 4.0)
	else:
		var w: float = r.size.x * value
		draw_rect(Rect2(0, 4, w, r.size.y - 8), c)
		draw_line(Vector2(w, -8), Vector2(w, r.size.y + 8), Color.WHITE, 4.0)


func _draw_heat(r: Rect2) -> void:
	var n: int = bins.size()
	var w: float = r.size.x / float(n)
	for i: int in range(n):
		var ratio: float = bins[i] / bin_target
		var c: Color
		if ratio < 0.6:
			c = Color(0.2, 0.35, 0.9).lerp(Color(0.3, 0.8, 0.9), ratio / 0.6)
		elif ratio <= 1.35:
			c = Color(0.4, 0.95, 0.4)
		else:
			c = Color(1.0, 0.7, 0.2).lerp(Color(1.0, 0.25, 0.2), clampf((ratio - 1.35) / 0.8, 0.0, 1.0))
		draw_rect(Rect2(i * w + 2, 2, w - 4, r.size.y - 4), c)
