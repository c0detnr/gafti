extends Node
## Ana menü: arkada yavaşça dönen sisli yayla sahnesi, logo, Devam Et / Yeni Oyun / Ayarlar / Çıkış.
## Yeni Oyun → SaveSystem.new_game() → özelleştirme → valley.tscn.

const CUSTOMIZATION_SCENE: String = "res://scenes/ui/customization/customization.tscn"
const SETTINGS_SCENE: String = "res://scenes/ui/menus/settings_menu.tscn"
const HOUSE_PATH: String = "res://assets/models/hero/house.glb"
const GREENHOUSE_PATH: String = "res://assets/models/hero/greenhouse.glb"

var _ui: Control
var _menu_box: Control
var _buttons: VBoxContainer
var _continue_btn: Button
var _pivot: Node3D
var _overlay: Control = null
var _t: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	_build_world()
	_build_ui()
	GaftiUI.call_safe("AudioManager", &"set_auto_music", [false])
	GaftiUI.call_safe("AudioManager", &"play_music", [&"menu"])
	GaftiUI.call_safe("AudioManager", &"set_ambience", [&"birds_loop"])


func _process(delta: float) -> void:
	_t += delta
	if _pivot != null:
		_pivot.rotation.y += delta * 0.035
		_pivot.position.y = sin(_t * 0.2) * 0.6


# --- Menü eylemleri ---------------------------------------------------------------

func _has_save() -> bool:
	return bool(GaftiUI.call_safe("SaveSystem", &"has_save", [], false))


func _on_continue() -> void:
	GameStart.load_on_start = true
	_go_to_game()


func _on_new_game() -> void:
	if _has_save():
		_confirm_new_game()
	else:
		_start_new_game()


func _start_new_game() -> void:
	_close_overlay()
	GaftiUI.call_safe("SaveSystem", &"new_game")
	GameStart.load_on_start = false
	if not ResourceLoader.exists(CUSTOMIZATION_SCENE):
		_go_to_game()
		return
	var c: Control = (load(CUSTOMIZATION_SCENE) as PackedScene).instantiate() as Control
	c.set(&"allow_cancel", true)
	c.connect(&"confirmed", _on_customized)
	c.connect(&"cancelled", _close_overlay)
	_show_overlay(c)


func _on_customized(data: Dictionary) -> void:
	CharacterVisual.pending_customization = data.duplicate()
	_go_to_game()


func _go_to_game() -> void:
	if not ResourceLoader.exists(GameStart.GAME_SCENE):
		var bus: Node = GaftiUI.autoload("EventBus")
		push_warning("Oyun sahnesi henüz yok: " + GameStart.GAME_SCENE)
		if bus != null:
			bus.emit_signal(&"notify", tr("MENU_NO_GAME_SCENE"), &"bad")
		_close_overlay()
		return
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(fade)
	var tw: Tween = create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(GameStart.GAME_SCENE))


func _on_settings() -> void:
	if ResourceLoader.exists(SETTINGS_SCENE):
		var s: Control = (load(SETTINGS_SCENE) as PackedScene).instantiate() as Control
		s.connect(&"closed", func() -> void:
			_overlay = null
			_menu_box.visible = true
			_buttons.get_child(0).call_deferred(&"grab_focus"))
		_overlay = s
		_menu_box.visible = false
		_ui.add_child(s)


func _on_quit() -> void:
	get_tree().quit()


func _show_overlay(c: Control) -> void:
	_close_overlay()
	_overlay = c
	_menu_box.visible = false
	_ui.add_child(c)
	GaftiUI.apply_theme(c)


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_menu_box.visible = true


func _confirm_new_game() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var l := Label.new()
	l.text = "MENU_CONFIRM_NEW"
	l.custom_minimum_size = Vector2(560, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	var no := Button.new()
	no.text = "UI_CANCEL"
	no.custom_minimum_size = Vector2(260, 72)
	no.pressed.connect(_close_overlay)
	hb.add_child(no)
	var yes := Button.new()
	yes.text = "MENU_CONFIRM_YES"
	yes.custom_minimum_size = Vector2(260, 72)
	yes.pressed.connect(_start_new_game)
	hb.add_child(yes)
	_show_overlay(dim)
	no.grab_focus.call_deferred()


# --- Arayüz -------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_ui.theme = GaftiUI.get_theme()
	# Sol tarafta okunabilirlik için sıcak degrade
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.07, 0.14, 0.1, 0.88), Color(0.07, 0.14, 0.1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.6
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)

	_menu_box = MarginContainer.new()
	_menu_box.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_menu_box.add_theme_constant_override("margin_left", 110)
	_menu_box.add_theme_constant_override("margin_top", 70)
	_menu_box.add_theme_constant_override("margin_bottom", 60)
	_ui.add_child(_menu_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_box.add_child(vb)
	var logo_tex: Texture2D = GaftiUI.load_logo()
	if logo_tex != null:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(560, 300)
		vb.add_child(logo)
		logo.pivot_offset = Vector2(280, 150)
		var lt: Tween = logo.create_tween().set_loops()
		lt.tween_property(logo, "scale", Vector2(1.03, 1.03), 2.4).set_trans(Tween.TRANS_SINE)
		lt.tween_property(logo, "scale", Vector2.ONE, 2.4).set_trans(Tween.TRANS_SINE)
	else:
		var title := Label.new()
		title.text = "GAFTİ"
		title.theme_type_variation = &"GaftiHeading"
		title.add_theme_font_size_override("font_size", 140)
		title.add_theme_color_override("font_color", Color(0.6, 0.86, 0.38))
		vb.add_child(title)
	var tagline := Label.new()
	tagline.text = "MENU_TAGLINE"
	tagline.add_theme_font_size_override("font_size", 24)
	tagline.modulate = Color(1, 1, 1, 0.85)
	vb.add_child(tagline)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	vb.add_child(_buttons)
	_continue_btn = _menu_button("MENU_CONTINUE", _on_continue)
	_continue_btn.visible = _has_save()
	_menu_button("MENU_NEW_GAME", _on_new_game)
	_menu_button("MENU_SETTINGS", _on_settings)
	var quit: Button = _menu_button("MENU_QUIT", _on_quit)
	quit.visible = not OS.has_feature("web")

	var ver := Label.new()
	ver.text = "v" + String(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -24
	ver.offset_bottom = -16
	ver.modulate = Color(1, 1, 1, 0.6)
	_ui.add_child(ver)

	GaftiUI.wire_click_sounds(_ui)
	for b: Node in _buttons.get_children():
		if (b as Button).visible:
			(b as Button).grab_focus.call_deferred()
			break
	_ui.modulate.a = 0.0
	create_tween().tween_property(_ui, "modulate:a", 1.0, 1.2)


func _menu_button(key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(460, 80)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	_buttons.add_child(b)
	return b


# --- Arka plan 3B sahne ---------------------------------------------------------------

func _build_world() -> void:
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	# Ortam: yumuşak gökyüzü + yoğun yayla sisi
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.58, 0.62)
	sky_mat.sky_horizon_color = Color(0.82, 0.84, 0.8)
	sky_mat.ground_horizon_color = Color(0.7, 0.75, 0.72)
	sky_mat.ground_bottom_color = Color(0.2, 0.28, 0.24)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.82, 0.8)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.1
	sun.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(-35.0), 0.0)
	sun.shadow_enabled = true
	world.add_child(sun)
	# Zemin ve tepeler
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	ground.mesh = pm
	ground.material_override = _mat(Color(0.3, 0.48, 0.25))
	world.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1453
	for i: int in 14:
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 24
		sm.rings = 12
		hill.mesh = sm
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(45.0, 140.0)
		var r: float = rng.randf_range(22.0, 55.0)
		hill.position = Vector3(cos(ang) * dist, -r * 0.35, sin(ang) * dist)
		hill.scale = Vector3(r, r * rng.randf_range(0.5, 0.9), r)
		hill.material_override = _mat(Color(0.22, 0.4, 0.24).lerp(Color(0.32, 0.5, 0.28), rng.randf()))
		world.add_child(hill)
	# Ladin ormanı (MultiMesh: az draw call)
	_spawn_trees(world, rng)
	# Ev + sera (varsa gerçek modeller)
	var house: Node3D = ModelLoader.instance(HOUSE_PATH, Vector3(8, 6, 8), Color(0.5, 0.35, 0.22))
	house.position = Vector3(-6, 0, -4)
	house.rotation.y = deg_to_rad(20.0)
	world.add_child(house)
	var gh: Node3D = ModelLoader.instance(GREENHOUSE_PATH, Vector3(12, 4, 6), Color(0.7, 0.85, 0.8))
	gh.position = Vector3(10, 0, 4)
	gh.rotation.y = deg_to_rad(-15.0)
	world.add_child(gh)
	# Kamera yörüngesi
	_pivot = Node3D.new()
	world.add_child(_pivot)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 9, 34)
	cam.rotation.x = deg_to_rad(-10.0)
	cam.fov = 55.0
	cam.far = 800.0
	_pivot.add_child(cam)
	cam.make_current()


func _spawn_trees(world: Node3D, rng: RandomNumberGenerator) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.2
	cone.height = 6.0
	cone.radial_segments = 8
	cone.material = _mat(Color(0.12, 0.27, 0.18))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = 160
	for i: int in mm.instance_count:
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(22.0, 120.0)
		var s: float = rng.randf_range(0.7, 1.6)
		var pos := Vector3(cos(ang) * dist, 3.0 * s - 0.2, sin(ang) * dist)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	world.add_child(mmi)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m
