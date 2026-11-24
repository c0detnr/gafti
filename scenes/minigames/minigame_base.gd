class_name MinigameBase
extends Control
## Tüm yakın çekim mini oyunlarının ortak tabanı (Ajan B).
## Yapı: SubViewportContainer(SubViewport + kendi 3D dünyası + Camera3D) + üstte dokunmatik giriş katmanı + UI.
## Alt sınıflar: _build_world(), _begin(), _on_press/_on_drag/_on_release, debug_skip_step() uygular.

signal finished(result: Dictionary)

const THEME_PATH: String = "res://assets/ui/gafti_theme.tres"
const C_GOOD: Color = Color(0.45, 0.9, 0.4)
const C_BAD: Color = Color(1.0, 0.42, 0.35)
const C_WARN: Color = Color(1.0, 0.78, 0.3)
const C_PANEL: Color = Color(0.09, 0.13, 0.1, 0.82)

var context: Dictionary = {}
## 2 = tam yardım, 1 = kısmi, 0 = yardım yok (beceriye göre).
var help_level: int = 2

var view_container: SubViewportContainer
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var input_layer: Control
var ui: Control
var title_label: Label
var step_label: Label
var hint_label: Label
var actions_box: HBoxContainer
var cancel_button: Button

var _pressing: bool = false
var _finished: bool = false
var _shake_strength: float = 0.0
var _cam_base_h: float = 0.0
var _cam_base_v: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(THEME_PATH):
		var th: Theme = load(THEME_PATH) as Theme
		if th != null:
			theme = th
	_build_frame()
	_build_world()
	_begin.call_deferred()


## Host tarafından add_child sonrası çağrılır.
func setup(ctx: Dictionary) -> void:
	context = ctx


# ---------------------------------------------------------------- Sanal fonksiyonlar

func _build_world() -> void:
	pass


func _begin() -> void:
	pass


func _on_press(_pos: Vector2) -> void:
	pass


func _on_drag(_pos: Vector2, _rel: Vector2) -> void:
	pass


func _on_release(_pos: Vector2) -> void:
	pass


## Test/otomasyon: o anki adımı rastgele skorla geçer.
func debug_skip_step() -> void:
	pass


func _on_cancel() -> void:
	pass


# ---------------------------------------------------------------- İskelet

func _build_frame() -> void:
	view_container = SubViewportContainer.new()
	view_container.name = "View"
	view_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	view_container.stretch = true
	view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view_container)

	viewport = SubViewport.new()
	viewport.name = "Viewport"
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view_container.add_child(viewport)

	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.2, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.82, 0.75)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.name = "Key"
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	world.add_child(sun)

	var lamp := OmniLight3D.new()
	lamp.name = "WarmLamp"
	lamp.position = Vector3(-0.3, 0.45, 0.2)
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 0.8
	lamp.omni_range = 1.6
	world.add_child(lamp)

	camera = Camera3D.new()
	camera.name = "CloseCam"
	camera.fov = 42.0
	camera.near = 0.01
	camera.far = 20.0
	camera.current = true
	world.add_child(camera)

	input_layer = Control.new()
	input_layer.name = "Input"
	input_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	input_layer.gui_input.connect(_on_input)
	add_child(input_layer)

	ui = Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	var top := PanelContainer.new()
	top.name = "Top"
	top.add_theme_stylebox_override(&"panel", _panel_style(C_PANEL, 18))
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -560
	top.offset_right = 560
	top.offset_top = 18
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(vb)
	title_label = _label("", 30, Color(1.0, 0.85, 0.45))
	step_label = _label("", 40, Color.WHITE)
	hint_label = _label("", 26, Color(0.85, 0.95, 0.85))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(title_label)
	vb.add_child(step_label)
	vb.add_child(hint_label)

	cancel_button = Button.new()
	cancel_button.name = "Cancel"
	cancel_button.text = tr("MG_CANCEL")
	cancel_button.add_theme_font_size_override(&"font_size", 30)
	cancel_button.custom_minimum_size = Vector2(190, 80)
	cancel_button.anchor_left = 1.0
	cancel_button.anchor_right = 1.0
	cancel_button.offset_left = -220
	cancel_button.offset_right = -24
	cancel_button.offset_top = 24
	cancel_button.offset_bottom = 104
	cancel_button.pressed.connect(cancel)
	ui.add_child(cancel_button)

	actions_box = HBoxContainer.new()
	actions_box.name = "Actions"
	actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_box.add_theme_constant_override(&"separation", 24)
	actions_box.anchor_left = 0.0
	actions_box.anchor_right = 1.0
	actions_box.anchor_top = 1.0
	actions_box.anchor_bottom = 1.0
	actions_box.offset_top = -130
	actions_box.offset_bottom = -30
	actions_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(actions_box)


func _panel_style(c: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override(&"outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func set_title(t: String) -> void:
	title_label.text = t


func set_step(index: int, total: int, text: String, hint: String) -> void:
	step_label.text = "%d/%d · %s" % [index, total, text]
	hint_label.text = hint
	step_label.pivot_offset = step_label.size * 0.5
	step_label.scale = Vector2(1.25, 1.25)
	var tw: Tween = create_tween()
	tw.tween_property(step_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- Giriş

func _on_input(event: InputEvent) -> void:
	if _finished:
		return
	# Dokunmatik olaylar fareye çevrildiği için sadece fare olaylarını işle.
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_on_press(mb.position)
		else:
			_pressing = false
			_on_release(mb.position)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _pressing:
			_on_drag(mm.position, mm.relative)


func is_pressing() -> bool:
	return _pressing


## Ekran noktasından yatay düzleme (y = h) ışın kesişimi.
func screen_to_plane(pos: Vector2, h: float) -> Vector3:
	var origin: Vector3 = camera.project_ray_origin(pos)
	var dir: Vector3 = camera.project_ray_normal(pos)
	if absf(dir.y) < 0.0001:
		return origin
	var t: float = (h - origin.y) / dir.y
	return origin + dir * t


func world_to_screen(p: Vector3) -> Vector2:
	return camera.unproject_position(p)


# ---------------------------------------------------------------- Kamera & sulu efektler

func look_from(from: Vector3, target: Vector3, seconds: float = 0.6) -> void:
	if seconds <= 0.0 or not camera.is_inside_tree():
		camera.position = from
		camera.look_at(target, Vector3.UP)
		return
	var start_t: Transform3D = camera.global_transform
	var end_t: Transform3D = Transform3D(Basis.looking_at(target - from, Vector3.UP), from)
	var tw: Tween = create_tween()
	tw.tween_method(func(f: float) -> void:
		camera.global_transform = start_t.interpolate_with(end_t, f), 0.0, 1.0, seconds
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func shake(amount: float = 0.5) -> void:
	_shake_strength = maxf(_shake_strength, amount)


func _process(delta: float) -> void:
	if camera == null:
		return
	if _shake_strength > 0.001:
		_shake_strength = move_toward(_shake_strength, 0.0, delta * 2.5)
		var s: float = _shake_strength * _shake_strength * 0.012
		camera.h_offset = _cam_base_h + _rng.randf_range(-s, s)
		camera.v_offset = _cam_base_v + _rng.randf_range(-s, s)
		view_container.position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake_strength * 10.0
	else:
		camera.h_offset = _cam_base_h
		camera.v_offset = _cam_base_v
		view_container.position = Vector2.ZERO


## Ekranda süzülen komik yazı ("Harika!", "Şlurp!").
func pop_text(text: String, at: Vector2 = Vector2(-1, -1), color: Color = Color.WHITE, size: int = 44) -> void:
	var l: Label = _label(text, size, color)
	ui.add_child(l)
	var p: Vector2 = at
	if p.x < 0.0:
		p = get_viewport_rect().size * Vector2(0.5, 0.45)
	l.reset_size()
	l.position = p - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.3, 0.3)
	l.rotation = _rng.randf_range(-0.15, 0.15)
	var tw: Tween = create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(l, "position:y", l.position.y - 90.0, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)


func sfx(id: StringName) -> void:
	MinigameUtil.sfx(id)


func squash(n: Node3D, amount: float = 0.25) -> void:
	if n == null:
		return
	var base: Vector3 = n.scale
	var tw: Tween = create_tween()
	tw.tween_property(n, "scale", base * Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount), 0.07)
	tw.tween_property(n, "scale", base, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Küçük parça patlaması (kırıntı, su damlası, sıvı).
func burst(at: Vector3, color: Color, count: int = 16, size: float = 0.004, speed: float = 0.25) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = 0.8
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -1.2, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material = mat
	p.mesh = m
	world.add_child(p)
	p.global_position = at
	p.emitting = true
	var t: SceneTreeTimer = get_tree().create_timer(1.6)
	t.timeout.connect(p.queue_free)


# ---------------------------------------------------------------- Model yardımcıları

## Modeli yükler; dosya yoksa null döner (alt sınıf prosedürel yedeğini kurar).
func try_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = ModelLoader.instance(path)
	if n == null or String(n.name).begins_with("Placeholder_"):
		if n != null:
			n.free()
		return null
	return n


func find_part(root: Node, part: String) -> Node3D:
	if root == null:
		return null
	return ModelLoader.find(root, part) as Node3D


func mat(color: Color, rough: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func prim(mesh: Mesh, color: Color, parent: Node3D, pos: Vector3 = Vector3.ZERO, node_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	mi.position = pos
	return mi


func cyl(top_r: float, bottom_r: float, h: float, segs: int = 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


func box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func sphere(r: float, segs: int = 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(segs / 2, 3)
	return s


## Bir düğüm ağacının dünya uzayındaki birleşik AABB'si.
func combined_aabb(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = n as VisualInstance3D
		if vi.is_inside_tree() and not vi.is_visible_in_tree():
			continue
		var a: AABB = vi.global_transform * vi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	if root is VisualInstance3D:
		var a2: AABB = root.global_transform * (root as VisualInstance3D).get_aabb()
		out = a2 if first else out.merge(a2)
	return out


# ---------------------------------------------------------------- Butonlar & sonuç

func clear_actions() -> void:
	for c: Node in actions_box.get_children():
		c.queue_free()


func add_action(text: String, cb: Callable, color: Color = Color(0.3, 0.62, 0.35)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 96)
	b.add_theme_font_size_override(&"font_size", 34)
	var sb: StyleBoxFlat = _panel_style(color, 22)
	b.add_theme_stylebox_override(&"normal", sb)
	var sb_h: StyleBoxFlat = _panel_style(color.lightened(0.15), 22)
	b.add_theme_stylebox_override(&"hover", sb_h)
	b.add_theme_stylebox_override(&"pressed", _panel_style(color.darkened(0.2), 22))
	b.add_theme_stylebox_override(&"disabled", _panel_style(Color(0.3, 0.3, 0.3, 0.7), 22))
	b.pressed.connect(func() -> void:
		sfx(&"ui_click")
		cb.call())
	actions_box.add_child(b)
	b.pivot_offset = b.custom_minimum_size * 0.5
	b.scale = Vector2(0.6, 0.6)
	var tw: Tween = create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return b


## Sonuç paneli: başlık, skor sayacı, satırlar ve buton listesi ([metin, Callable] çiftleri).
func show_result(title: String, score: int, lines: Array[String], buttons: Array) -> void:
	clear_actions()
	hint_label.text = ""
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(dim)
	ui.move_child(dim, 0)
	var tw0: Tween = create_tween()
	tw0.tween_property(dim, "color:a", 0.45, 0.4)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _panel_style(Color(0.1, 0.16, 0.11, 0.95), 28))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -480
	panel.offset_right = 480
	panel.offset_top = -330
	panel.offset_bottom = 330
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override(&"separation", 14)
	panel.add_child(vb)
	vb.add_child(_label(title, 52, Color(1.0, 0.85, 0.4)))
	var score_label: Label = _label("0", 96, Color.WHITE)
	vb.add_child(score_label)
	for line: String in lines:
		var l: Label = _label(line, 30, Color(0.88, 0.95, 0.88))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override(&"separation", 24)
	vb.add_child(hb)
	for pair: Variant in buttons:
		var arr: Array = pair as Array
		var b := Button.new()
		b.text = String(arr[0])
		b.custom_minimum_size = Vector2(280, 96)
		b.add_theme_font_size_override(&"font_size", 34)
		var col: Color = arr[2] as Color if arr.size() > 2 else Color(0.3, 0.62, 0.35)
		b.add_theme_stylebox_override(&"normal", _panel_style(col, 22))
		b.add_theme_stylebox_override(&"hover", _panel_style(col.lightened(0.15), 22))
		b.add_theme_stylebox_override(&"pressed", _panel_style(col.darkened(0.2), 22))
		var cb: Callable = arr[1] as Callable
		b.pressed.connect(func() -> void:
			sfx(&"ui_click")
			cb.call())
		hb.add_child(b)

	panel.pivot_offset = Vector2(480, 330)
	panel.scale = Vector2(0.4, 0.4)
	panel.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_method(func(v: float) -> void:
		score_label.text = str(int(v))
		score_label.add_theme_color_override(&"font_color", C_BAD.lerp(C_GOOD, v / 100.0)), 0.0, float(score), 1.0)
	tw.tween_callback(func() -> void:
		sfx(&"notify_good" if score >= 55 else &"notify_bad")
		shake(0.4 if score >= 55 else 0.8))
	cancel_button.visible = false


# ---------------------------------------------------------------- Bitiş

func cancel() -> void:
	if _finished:
		return
	_on_cancel()
	finish(_cancel_result())


## Vazgeçildiğinde dönecek sonuç (alt sınıflar ek alan ekleyebilir).
func _cancel_result() -> Dictionary:
	return {"cancelled": true}


func finish(result: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	if not result.has("cancelled"):
		result["cancelled"] = false
	finished.emit(result)
