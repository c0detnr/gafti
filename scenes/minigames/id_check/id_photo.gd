class_name IdPhoto
extends Control
## Basit çizilmiş yüz portresi (kimlik kartı fotoğrafı ya da müşterinin "gerçek" yüzü).
## look: CharacterDresser görünüş sözlüğü (+ "kid": bool, "crayon": bool).

var look: Dictionary = {}:
	set(v):
		look = v
		queue_redraw()
var bg: Color = Color(0.78, 0.86, 0.92)


func _draw() -> void:
	var s: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, s), bg)
	var kid: bool = bool(look.get("kid", false))
	var skin: Color = look.get("skin", Color(0.9, 0.75, 0.6)) as Color
	var hair_c: Color = look.get("hair_color", Color(0.2, 0.15, 0.1)) as Color
	var top_c: Color = look.get("top_color", Color(0.4, 0.4, 0.5)) as Color
	var cx: float = s.x * 0.5
	var head_r: float = s.x * (0.3 if kid else 0.26)
	var head_y: float = s.y * (0.5 if kid else 0.42)
	# Omuzlar
	draw_circle(Vector2(cx, s.y * 1.05), s.x * (0.38 if kid else 0.48), top_c)
	# Kafa
	draw_circle(Vector2(cx, head_y), head_r, skin)
	# Saç
	var hair: String = String(look.get("hair", "Hair_01"))
	if hair != "Hair_04":
		draw_circle(Vector2(cx, head_y - head_r * 0.55), head_r * 0.78, hair_c)
		draw_circle(Vector2(cx, head_y - head_r * 0.05), head_r * 0.9, skin)
	else:
		draw_circle(Vector2(cx - head_r * 0.95, head_y), head_r * 0.25, hair_c)
		draw_circle(Vector2(cx + head_r * 0.95, head_y), head_r * 0.25, hair_c)
	if hair == "Hair_06":
		draw_circle(Vector2(cx, head_y - head_r * 1.15), head_r * 0.35, hair_c)
	if bool(look.get("hat", false)):
		draw_rect(Rect2(cx - head_r, head_y - head_r * 1.05, head_r * 2.0, head_r * 0.45), Color(0.3, 0.28, 0.25))
		draw_rect(Rect2(cx - head_r * 0.2, head_y - head_r * 0.7, head_r * 1.5, head_r * 0.15), Color(0.25, 0.23, 0.2))
	# Gözler (çocukta kocaman)
	var eye_r: float = head_r * (0.16 if kid else 0.1)
	draw_circle(Vector2(cx - head_r * 0.38, head_y - head_r * 0.05), eye_r, Color.WHITE)
	draw_circle(Vector2(cx + head_r * 0.38, head_y - head_r * 0.05), eye_r, Color.WHITE)
	draw_circle(Vector2(cx - head_r * 0.38, head_y - head_r * 0.02), eye_r * 0.55, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(cx + head_r * 0.38, head_y - head_r * 0.02), eye_r * 0.55, Color(0.1, 0.1, 0.1))
	# Ağız
	draw_arc(Vector2(cx, head_y + head_r * 0.35), head_r * 0.25, 0.3, PI - 0.3, 12, Color(0.4, 0.15, 0.12), 2.0)
	# Sakal / bıyık
	var beard: String = String(look.get("beard", "Beard_00"))
	var crayon: bool = bool(look.get("crayon", false))
	var bc: Color = Color(0.1, 0.1, 0.12) if crayon else hair_c
	var w: float = 5.0 if crayon else 3.5
	match beard:
		"Beard_01":
			draw_line(Vector2(cx - head_r * 0.35, head_y + head_r * 0.25), Vector2(cx + head_r * 0.35, head_y + head_r * 0.25), bc, w)
		"Beard_02":
			draw_polyline(PackedVector2Array([
				Vector2(cx - head_r * 0.6, head_y + head_r * 0.12), Vector2(cx - head_r * 0.3, head_y + head_r * 0.3),
				Vector2(cx, head_y + head_r * 0.22), Vector2(cx + head_r * 0.3, head_y + head_r * 0.3),
				Vector2(cx + head_r * 0.6, head_y + head_r * 0.12)]), bc, w * 1.4)
		"Beard_03":
			for i: int in range(14):
				var a: float = 0.2 + float(i) / 13.0 * (PI - 0.4)
				draw_circle(Vector2(cx, head_y) + Vector2(cos(a), sin(a)) * head_r * 0.8, 1.6, bc)
		"Beard_04":
			draw_circle(Vector2(cx, head_y + head_r * 0.65), head_r * 0.55, bc)
			draw_arc(Vector2(cx, head_y + head_r * 0.35), head_r * 0.25, 0.3, PI - 0.3, 12, Color(0.4, 0.15, 0.12), 2.0)
	if crayon:
		# Keçeli kalem karalaması
		draw_line(Vector2(s.x * 0.08, s.y * 0.12), Vector2(s.x * 0.3, s.y * 0.06), Color(0.9, 0.2, 0.2), 3.0)
		draw_circle(Vector2(s.x * 0.85, s.y * 0.15), 6.0, Color(1.0, 0.85, 0.1))
