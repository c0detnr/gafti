class_name BuildSystem
extends Node3D
## İnşa modu: B tuşu (build_mode aksiyonu) veya toggle() ile açılır.
## 0.5 m grid, hayalet önizleme (yeşil = geçerli, kırmızı = geçersiz), R / sağ tık ile döndürme,
## sol tık (PC) ile satın al + yerleştir; mobilde dokunarak konumla + "Onayla" butonu.
## Satış modu: yerleştirilen nesneye tıkla → %50 iade.
## Yerleştirilen nesneler bu düğümün "Placed" çocuğu altında durur ve kayıtlıdır (persist_spawner).

signal build_mode_changed(active: bool)
signal placed(node: Node3D, buildable_id: StringName)
signal removed(buildable_id: StringName)

const GRID: float = 0.5
const SELL_RATIO: float = 0.5
const RAY_LENGTH: float = 60.0

## Ghost sınırı: bu düğümden en fazla bu kadar uzağa yerleştirilebilir (0 = sınırsız).
@export var max_build_distance: float = 0.0

var active: bool = false
var sell_mode: bool = false
var selected: BuildableData = null
var rotation_steps: int = 0

var _placed_root: Node3D
var _ghost: Node3D = null
var _ghost_mat_ok: StandardMaterial3D
var _ghost_mat_bad: StandardMaterial3D
var _ghost_valid: bool = false
var _ui: CanvasLayer = null
var _hint: Label
var _confirm_btn: Button
var _next_id: int = 1


func _init() -> void:
	add_to_group(&"persist_spawner")
	add_to_group(&"build_system")


func _ready() -> void:
	_placed_root = Node3D.new()
	_placed_root.name = "Placed"
	add_child(_placed_root)
	_ghost_mat_ok = _make_ghost_mat(Color(0.3, 1.0, 0.4, 0.45))
	_ghost_mat_bad = _make_ghost_mat(Color(1.0, 0.25, 0.2, 0.45))


func get_save_id() -> String:
	return "build_system"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_mode"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		set_active(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_R:
		rotate_ghost()
	elif event is InputEventMouseMotion and not _is_touch():
		_update_ghost((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			rotate_ghost()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if sell_mode:
				_try_sell_at(mb.position)
			else:
				_update_ghost(mb.position)
				if not _is_touch():
					confirm_place()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Genel API
# ---------------------------------------------------------------------------

func toggle() -> void:
	set_active(not active)


func set_active(v: bool) -> void:
	if v == active:
		return
	active = v
	if active:
		_build_ui()
		var all: Array[BuildableData] = Catalog.get_buildables()
		if selected == null and not all.is_empty():
			select(all[0].id)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_clear_ghost()
		if _ui != null:
			_ui.queue_free()
			_ui = null
		sell_mode = false
	build_mode_changed.emit(active)


func select(id: StringName) -> void:
	selected = Catalog.get_buildable(id)
	sell_mode = false
	_clear_ghost()
	if selected != null and active:
		_ghost = _make_visual(selected)
		_ghost.name = "Ghost"
		_ghost.rotation.y = rotation_steps * PI * 0.5
		add_child(_ghost)
		_ghost.visible = false
	_update_hint()


func rotate_ghost() -> void:
	rotation_steps = (rotation_steps + 1) % 4
	if _ghost != null:
		_ghost.rotation.y = rotation_steps * PI * 0.5


## Hayaletin olduğu yere yerleştirir (mobil onay butonu da bunu çağırır).
func confirm_place() -> bool:
	if selected == null or _ghost == null or not _ghost.visible:
		return false
	if not _ghost_valid:
		EventBus.notify.emit(tr("BUILD_INVALID"), &"bad")
		return false
	return place_buildable(selected.id, _ghost.global_position, rotation_steps) != null


## Kodla yerleştirme (test/senaryo için de kullanılır). Kit varsa onu harcar, yoksa satın alır.
func place_buildable(id: StringName, world_pos: Vector3, rot_steps: int = 0, free: bool = false) -> Node3D:
	var data: BuildableData = Catalog.get_buildable(id)
	if data == null:
		return null
	var reason: String = get_invalid_reason(data, world_pos)
	if reason != "":
		EventBus.notify.emit(reason, &"bad")
		return null
	if not free:
		var kit: StringName = data.get_kit_id()
		if Inventory.count_of(kit) > 0:
			Inventory.remove_item(kit, 1)
		elif not Economy.spend(data.price, tr("ECON_REASON_BUILD") % data.get_display_name()):
			return null
	var sid: String = "build_%d" % _next_id
	_next_id += 1
	var node: Node3D = _spawn(data, world_pos, rot_steps, sid)
	EventBus.notify.emit(tr("BUILD_PLACED") % data.get_display_name(), &"good")
	_play_sfx(&"build_place")
	_quest_event(&"item_built", {"id": id})
	_refresh_pots()
	placed.emit(node, id)
	return node


## Yerleştirilmiş nesneyi satar (%50 iade). Canlı bitkili saksı satılamaz.
func sell(node: Node3D) -> bool:
	if node == null or not node.has_meta(&"buildable_id") or node.get_parent() != _placed_root:
		return false
	if node.has_method("get_state") and node.call("get_state") != null:
		EventBus.notify.emit(tr("BUILD_SELL_HAS_PLANT"), &"bad")
		return false
	var drying: Variant = node.get("batches")
	if drying is Array and not (drying as Array).is_empty():
		EventBus.notify.emit(tr("BUILD_SELL_NOT_EMPTY"), &"bad")
		return false
	var id: StringName = node.get_meta(&"buildable_id")
	var data: BuildableData = Catalog.get_buildable(id)
	var refund: int = int(round(float(data.price if data != null else 0) * SELL_RATIO))
	Economy.add(refund, tr("ECON_REASON_SELL_BUILD"))
	node.queue_free()
	_placed_root.remove_child(node)
	EventBus.notify.emit(tr("BUILD_SOLD") % refund, &"info")
	_refresh_pots()
	removed.emit(id)
	return true


func get_placed() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c: Node in _placed_root.get_children():
		if c is Node3D and not c.is_queued_for_deletion():
			out.append(c)
	return out


## Geçersizse sebep metni, geçerliyse "" döner.
func get_invalid_reason(data: BuildableData, world_pos: Vector3) -> String:
	if Reputation.license_level < data.min_license:
		return tr("CATALOG_NEED_LICENSE") % data.min_license
	if data.id == &"pot":
		var pots: int = get_tree().get_nodes_in_group(&"plant_pot").size()
		if pots >= Reputation.get_max_pots():
			return tr("BUILD_POT_LIMIT") % Reputation.get_max_pots()
	if max_build_distance > 0.0 and world_pos.distance_to(global_position) > max_build_distance:
		return tr("BUILD_TOO_FAR")
	for n: Node in get_tree().get_nodes_in_group(&"placed_buildable"):
		var n3: Node3D = n as Node3D
		if n3 == null or n3.is_queued_for_deletion():
			continue
		var od: BuildableData = Catalog.get_buildable(n3.get_meta(&"buildable_id", &""))
		var r: float = od.footprint if od != null else 0.3
		var a: Vector2 = Vector2(n3.global_position.x, n3.global_position.z)
		var b: Vector2 = Vector2(world_pos.x, world_pos.z)
		if a.distance_to(b) < r + data.footprint - 0.01:
			return tr("BUILD_OVERLAP")
	if Inventory.count_of(data.get_kit_id()) <= 0 and Economy.money < data.price:
		return tr("ECON_NOT_ENOUGH") % data.price
	return ""


static func snap(p: Vector3) -> Vector3:
	return Vector3(snappedf(p.x, GRID), p.y, snappedf(p.z, GRID))


# ---------------------------------------------------------------------------
# Hayalet ve ışın testi
# ---------------------------------------------------------------------------

func _update_ghost(screen_pos: Vector2) -> void:
	if _ghost == null or selected == null:
		return
	var hit: Dictionary = _raycast(screen_pos)
	if hit.is_empty():
		_ghost.visible = false
		return
	var p: Vector3 = snap(hit["position"])
	_ghost.global_position = p
	_ghost.visible = true
	_ghost_valid = get_invalid_reason(selected, p) == ""
	_apply_ghost_mat(_ghost, _ghost_mat_ok if _ghost_valid else _ghost_mat_bad)
	_update_hint()


func _raycast(screen_pos: Vector2) -> Dictionary:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var to: Vector3 = from + cam.project_ray_normal(screen_pos) * RAY_LENGTH
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	# Oyuncuyu ışından çıkar.
	var excl: Array[RID] = []
	for pl: Node in get_tree().get_nodes_in_group(&"player"):
		if pl is CollisionObject3D:
			excl.append((pl as CollisionObject3D).get_rid())
	q.exclude = excl
	return get_world_3d().direct_space_state.intersect_ray(q)


func _try_sell_at(screen_pos: Vector2) -> void:
	var hit: Dictionary = _raycast(screen_pos)
	if hit.is_empty():
		return
	var n: Node = hit["collider"] as Node
	while n != null and n != _placed_root:
		if n.has_meta(&"buildable_id") and n.get_parent() == _placed_root:
			sell(n as Node3D)
			return
		n = n.get_parent()


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null


func _make_ghost_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _apply_ghost_mat(root: Node, mat: Material) -> void:
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = mat


## Önizleme modeli (çarpışmasız).
func _make_visual(data: BuildableData) -> Node3D:
	if data.model_path != "":
		return ModelLoader.instance(data.model_path, data.size, data.color)
	return ModelLoader.placeholder(data.size, data.color, String(data.id))


# ---------------------------------------------------------------------------
# Yaratma
# ---------------------------------------------------------------------------

func _spawn(data: BuildableData, world_pos: Vector3, rot_steps: int, sid: String) -> Node3D:
	var node: Node3D = null
	if data.scene_path != "" and ResourceLoader.exists(data.scene_path):
		var ps: PackedScene = load(data.scene_path) as PackedScene
		node = ps.instantiate() as Node3D
		if node != null and "save_id" in node:
			node.set("save_id", sid)
	if node == null:
		var eq: PlacedEquipment = PlacedEquipment.new()
		eq.setup(data)
		node = eq
	node.set_meta(&"buildable_id", data.id)
	node.set_meta(&"save_id", sid)
	node.add_to_group(&"placed_buildable")
	_placed_root.add_child(node)
	node.global_position = world_pos
	node.rotation.y = rot_steps * PI * 0.5
	return node


func _refresh_pots() -> void:
	get_tree().call_group(&"plant_pot", &"refresh_equipment")


# ---------------------------------------------------------------------------
# Arayüz
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 40
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ActionMenu.THEME_PATH):
		root.theme = load(ActionMenu.THEME_PATH) as Theme
	_ui.add_child(root)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position.y = 24
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 26)
	root.add_child(_hint)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)
	var vb: VBoxContainer = VBoxContainer.new()
	panel.add_child(vb)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 96)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var items: HBoxContainer = HBoxContainer.new()
	items.add_theme_constant_override("separation", 8)
	scroll.add_child(items)
	for d: BuildableData in Catalog.get_buildables():
		var b: Button = Button.new()
		var kits: int = Inventory.count_of(d.get_kit_id())
		b.text = "%s\n%s" % [d.get_display_name(), (tr("BUILD_KIT_COUNT") % kits) if kits > 0 else ("%d ₺" % d.price)]
		b.custom_minimum_size = Vector2(170, 84)
		b.disabled = Reputation.license_level < d.min_license
		b.pressed.connect(select.bind(d.id))
		items.add_child(b)
	var tools: HBoxContainer = HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 12)
	vb.add_child(tools)
	var rot: Button = Button.new()
	rot.text = tr("BUILD_ROTATE")
	rot.custom_minimum_size = Vector2(160, 64)
	rot.pressed.connect(rotate_ghost)
	tools.add_child(rot)
	var sellb: Button = Button.new()
	sellb.text = tr("BUILD_SELL_MODE")
	sellb.toggle_mode = true
	sellb.custom_minimum_size = Vector2(160, 64)
	sellb.toggled.connect(func(on: bool) -> void:
		sell_mode = on
		if _ghost != null:
			_ghost.visible = false
		_update_hint())
	tools.add_child(sellb)
	_confirm_btn = Button.new()
	_confirm_btn.text = tr("BUILD_CONFIRM")
	_confirm_btn.custom_minimum_size = Vector2(160, 64)
	_confirm_btn.visible = _is_touch()
	_confirm_btn.pressed.connect(func() -> void: confirm_place())
	tools.add_child(_confirm_btn)
	var close: Button = Button.new()
	close.text = tr("UI_CLOSE")
	close.custom_minimum_size = Vector2(160, 64)
	close.pressed.connect(set_active.bind(false))
	tools.add_child(close)
	add_child(_ui)
	_update_hint()


func _update_hint() -> void:
	if _hint == null or not is_instance_valid(_hint):
		return
	if sell_mode:
		_hint.text = tr("BUILD_HINT_SELL")
	elif selected != null:
		var txt: String = tr("BUILD_HINT_TOUCH") if _is_touch() else tr("BUILD_HINT_PC")
		_hint.text = "%s — %s" % [selected.get_display_name(), txt]
	else:
		_hint.text = ""


func _is_touch() -> bool:
	var flags: Node = get_node_or_null("/root/ContentFlags")
	if flags != null and bool(flags.get("is_mobile")):
		return true
	var settings: Node = get_node_or_null("/root/Settings")
	return settings != null and bool(settings.get("touch_controls"))


func _play_sfx(id: StringName) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx"):
		am.call("play_sfx", id)


func _quest_event(event: StringName, data: Dictionary) -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm != null and qm.has_method("notify_event"):
		qm.call("notify_event", event, data)


# ---------------------------------------------------------------------------
# Kayıt
# ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var arr: Array = []
	for n: Node3D in get_placed():
		arr.append({
			"id": String(n.get_meta(&"buildable_id")), "sid": String(n.get_meta(&"save_id", "")),
			"x": n.global_position.x, "y": n.global_position.y, "z": n.global_position.z,
			"rot": int(round(n.rotation.y / (PI * 0.5))) % 4,
		})
	return {"items": arr, "next": _next_id}


func load_save_data(d: Dictionary) -> void:
	for n: Node3D in get_placed():
		_placed_root.remove_child(n)
		n.queue_free()
	_next_id = int(d.get("next", 1))
	for raw: Variant in d.get("items", []):
		if not raw is Dictionary:
			continue
		var r: Dictionary = raw
		var data: BuildableData = Catalog.get_buildable(StringName(String(r.get("id", ""))))
		if data == null:
			continue
		var pos: Vector3 = Vector3(float(r.get("x", 0.0)), float(r.get("y", 0.0)), float(r.get("z", 0.0)))
		_spawn(data, pos, int(r.get("rot", 0)), String(r.get("sid", "build_%d" % _next_id)))
	_refresh_pots()
