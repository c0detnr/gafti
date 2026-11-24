class_name HudIcon
extends Control
## Mevsim ve hava ikonlarını koddan çizer (doku gerektirmez, her ölçekte keskin).
## kind: sunny, cloudy, foggy, rainy, storm, snow, spring, summer, autumn, winter

@export var kind: StringName = &"sunny":
	set(v):
		kind = v
		queue_redraw()

const SUN: Color = Color(1.0, 0.78, 0.25)
const CLOUD: Color = Color(0.92, 0.93, 0.95)
const DARK_CLOUD: Color = Color(0.55, 0.58, 0.64)
const RAIN: Color = Color(0.45, 0.7, 1.0)
const LEAF: Color = Color(0.45, 0.8, 0.35)
const AUTUMN: Color = Color(0.95, 0.5, 0.18)
const SNOW: Color = Color(0.85, 0.95, 1.0)


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(48, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	match kind:
		&"sunny", &"summer":
			_sun(c, s * 0.22)
		&"cloudy":
			_sun(c + Vector2(-s * 0.15, -s * 0.12), s * 0.15)
			_cloud(c + Vector2(0, s * 0.08), s, CLOUD)
		&"foggy":
			for i: int in 4:
				var y: float = c.y - s * 0.27 + float(i) * s * 0.18
				var x_off: float = s * 0.08 * float(i % 2)
				draw_line(Vector2(c.x - s * 0.35 + x_off, y), Vector2(c.x + s * 0.35 - x_off, y), CLOUD, s * 0.07, true)
		&"rainy":
			_cloud(c + Vector2(0, -s * 0.1), s, CLOUD)
			for i: int in 3:
				var x: float = c.x - s * 0.18 + float(i) * s * 0.18
				draw_line(Vector2(x, c.y + s * 0.15), Vector2(x - s * 0.06, c.y + s * 0.38), RAIN, s * 0.06, true)
		&"storm":
			_cloud(c + Vector2(0, -s * 0.12), s, DARK_CLOUD)
			var bolt: PackedVector2Array = PackedVector2Array([
				c + Vector2(s * 0.02, s * 0.05), c + Vector2(-s * 0.12, s * 0.28), c + Vector2(0, s * 0.26),
				c + Vector2(-s * 0.06, s * 0.45), c + Vector2(s * 0.12, s * 0.2), c + Vector2(0, s * 0.22),
			])
			draw_colored_polygon(bolt, SUN)
		&"snow", &"winter":
			for i: int in 3:
				var a: float = float(i) * PI / 3.0
				var d: Vector2 = Vector2(cos(a), sin(a)) * s * 0.36
				draw_line(c - d, c + d, SNOW, s * 0.06, true)
			draw_circle(c, s * 0.07, SNOW)
		&"spring":
			for i: int in 5:
				var a2: float = float(i) * TAU / 5.0
				draw_circle(c + Vector2(cos(a2), sin(a2)) * s * 0.18, s * 0.13, Color(1.0, 0.7, 0.8))
			draw_circle(c, s * 0.1, SUN)
		&"autumn":
			_leaf(c, s, AUTUMN)
		_:
			_leaf(c, s, LEAF)


func _sun(c: Vector2, r: float) -> void:
	for i: int in 8:
		var a: float = float(i) * TAU / 8.0
		var d: Vector2 = Vector2(cos(a), sin(a))
		draw_line(c + d * r * 1.3, c + d * r * 1.75, SUN, r * 0.28, true)
	draw_circle(c, r, SUN)


func _cloud(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.16, s * 0.04), s * 0.15, col)
	draw_circle(c + Vector2(s * 0.02, -s * 0.06), s * 0.2, col)
	draw_circle(c + Vector2(s * 0.2, s * 0.05), s * 0.14, col)
	draw_rect(Rect2(c + Vector2(-s * 0.16, s * 0.04), Vector2(s * 0.36, s * 0.15)), col)


func _leaf(c: Vector2, s: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var t: float = float(i) / 16.0
		var y: float = lerpf(-0.4, 0.35, t) * s
		var w: float = sin(t * PI) * s * 0.24
		pts.append(c + Vector2(w, y))
	for i: int in range(15, 0, -1):
		var t2: float = float(i) / 16.0
		var y2: float = lerpf(-0.4, 0.35, t2) * s
		var w2: float = sin(t2 * PI) * s * 0.24
		pts.append(c + Vector2(-w2, y2))
	draw_colored_polygon(pts, col)
	draw_line(c + Vector2(0, -s * 0.35), c + Vector2(0, s * 0.45), col.darkened(0.4), s * 0.04, true)
