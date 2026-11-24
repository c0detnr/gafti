class_name CharacterVisual
extends Node3D
## Oyuncu modelini (character_base.glb) yükler, özelleştirmeyi uygular ve animasyonları oynatır.
## Model henüz yoksa basit, parçalı bir yer tutucu adam üretir (aynı düğüm/materyal adlarıyla).
## Model +Z ileri bakar; ebeveyn bu düğümü yön için Y ekseninde döndürür.

signal one_shot_finished(anim: StringName)

const MODEL_PATH: String = "res://assets/models/hero/character_base.glb"

const SKIN_TONES: Array[Color] = [
	Color(0.98, 0.84, 0.72), Color(0.93, 0.74, 0.6), Color(0.84, 0.63, 0.47),
	Color(0.7, 0.5, 0.35), Color(0.52, 0.35, 0.24), Color(0.36, 0.24, 0.17),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.1, 0.08, 0.07), Color(0.3, 0.18, 0.1), Color(0.55, 0.34, 0.17), Color(0.85, 0.66, 0.35),
	Color(0.62, 0.22, 0.12), Color(0.6, 0.6, 0.6), Color(0.92, 0.92, 0.9), Color(0.2, 0.42, 0.3),
]
const TOP_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.45, 0.85, 0.55), Color(1.0, 0.5, 0.45), Color(0.55, 0.7, 1.0),
	Color(0.85, 0.7, 0.5), Color(1.0, 0.9, 0.4), Color(0.55, 0.55, 0.6), Color(1.0, 0.7, 0.4),
]
const BOOTS_COLORS: Array[Color] = [
	Color(0.12, 0.12, 0.13), Color(0.2, 0.38, 0.22), Color(0.95, 0.78, 0.2),
	Color(0.7, 0.18, 0.16), Color(0.22, 0.3, 0.52), Color(0.45, 0.3, 0.18),
]
const TOPS: Array[String] = ["raincoat", "sweater", "shirt"]
const TOP_NODES: Dictionary = {"raincoat": "Top_Raincoat", "sweater": "Top_Sweater", "shirt": "Top_Shirt"}
const LOOP_ANIMS: Array[StringName] = [&"idle", &"walk", &"run", &"sit"]

## Varsayılan görünüm (Karadeniz klasiği: sarı yağmurluk + kasket + lastik çizme).
const DEFAULT_DATA: Dictionary = {
	"skin": 1, "hair": 1, "hair_color": 1, "beard": 2, "hat": true,
	"top": "raincoat", "top_color": 0, "boots_color": 0,
}

## Ana menü → oyun sahnesi geçişinde bekleyen özelleştirme (Yeni Oyun).
static var pending_customization: Dictionary = {}

var data: Dictionary = DEFAULT_DATA.duplicate()
var is_placeholder: bool = false

var _model: Node3D = null
var _anim: AnimationPlayer = null
var _anim_map: Dictionary = {} # kısa ad -> tam animasyon adı
var _mats: Dictionary = {} # "Skin"/"Hair"/... -> Array[BaseMaterial3D]
var _loop_name: StringName = &""
var _one_shot: StringName = &""
var _bob_t: float = 0.0
var _speed_ratio: float = 0.0


func _ready() -> void:
	_load_model()
	apply_customization(data)
	play_loop(&"idle")


func _process(delta: float) -> void:
	# Yer tutucuda basit yürüme sallantısı (gerçek modelde animasyon var).
	if is_placeholder and _model != null:
		_bob_t += delta * (4.0 + 8.0 * _speed_ratio)
		_model.position.y = absf(sin(_bob_t)) * 0.06 * _speed_ratio
		_model.rotation.z = sin(_bob_t) * 0.05 * _speed_ratio


# --- Özelleştirme --------------------------------------------------------------

## Verilen anahtarları mevcut veriye ekleyip görünüme uygular.
func apply_customization(d: Dictionary) -> void:
	for k: Variant in d.keys():
		data[String(k)] = d[k]
	if _model == null:
		return
	var hair: int = int(data.get("hair", 1))
	var beard: int = int(data.get("beard", 0))
	var hat: bool = bool(data.get("hat", true))
	var top: String = String(data.get("top", "raincoat"))
	# Görünürlük
	for i: int in range(1, 7):
		_set_visible("Hair_%02d" % i, i == hair)
	for i: int in range(0, 5):
		_set_visible("Beard_%02d" % i, i == beard)
	_set_visible("Hat_Kasket", hat)
	for t: String in TOPS:
		_set_visible(String(TOP_NODES[t]), t == top)
	_set_visible("Pants_01", true)
	_set_visible("Boots_Rubber", true)
	# Renkler
	_set_color("Skin", _pick(SKIN_TONES, data.get("skin", 1)))
	_set_color("Hair", _pick(HAIR_COLORS, data.get("hair_color", 1)))
	_set_color("Cloth_Top", _pick(TOP_COLORS, data.get("top_color", 0)))
	_set_color("Boots", _pick(BOOTS_COLORS, data.get("boots_color", 0)))


func get_customization() -> Dictionary:
	return data.duplicate()


## Renk girdisi indeks (int) ya da "#rrggbb" olabilir.
func _pick(palette: Array[Color], v: Variant) -> Color:
	if v is String and String(v).begins_with("#"):
		return Color.from_string(String(v), palette[0])
	if v is Color:
		return v as Color
	return palette[clampi(int(v), 0, palette.size() - 1)]


func _set_visible(node_name: String, vis: bool) -> void:
	var n: Node = _model.find_child(node_name, true, false)
	if n is Node3D:
		(n as Node3D).visible = vis


func _set_color(slot: String, c: Color) -> void:
	if not _mats.has(slot):
		return
	for m: BaseMaterial3D in _mats[slot]:
		m.albedo_color = c


# --- Animasyon -------------------------------------------------------------------

## Döngüsel animasyon (idle/walk/run/sit). Tek seferlik oynuyorsa bitince buna döner.
func play_loop(anim: StringName, speed: float = 1.0) -> void:
	_loop_name = anim
	if _anim == null or _one_shot != &"":
		return
	var full: StringName = _resolve(anim)
	if full == &"":
		return
	if _anim.current_animation != String(full):
		_anim.play(full, 0.22)
	_anim.speed_scale = speed


## Yürüme/koşma karışımı: ratio 0 = dur, ~0.5 = yürü, 1 = koş.
func set_locomotion(ratio: float) -> void:
	_speed_ratio = ratio
	if ratio < 0.05:
		play_loop(&"idle")
	elif ratio < 0.65:
		play_loop(&"walk", clampf(ratio / 0.45, 0.7, 1.3))
	else:
		play_loop(&"run", clampf(ratio, 0.85, 1.2))


## Tek seferlik animasyon (interact, wave, smoke, faint, roll...). Süreyi döner (yoksa 0.6 sn).
func play_one_shot(anim: StringName) -> float:
	var full: StringName = _resolve(anim)
	if _anim == null or full == &"":
		get_tree().create_timer(0.6).timeout.connect(func() -> void: one_shot_finished.emit(anim))
		return 0.6
	_one_shot = anim
	_anim.play(full, 0.15)
	_anim.speed_scale = 1.0
	return _anim.current_animation_length


func is_busy() -> bool:
	return _one_shot != &""


func has_animation(anim: StringName) -> bool:
	return _resolve(anim) != &""


func _resolve(anim: StringName) -> StringName:
	return StringName(_anim_map.get(String(anim).to_lower(), ""))


func _on_animation_finished(full: StringName) -> void:
	if _one_shot == &"":
		return
	if String(_resolve(_one_shot)) != String(full):
		return
	var finished: StringName = _one_shot
	_one_shot = &""
	one_shot_finished.emit(finished)
	if finished == &"faint" or finished == &"sit":
		return # Bu pozlar ebeveyn karar verene kadar kalsın.
	var loop: StringName = _loop_name if _loop_name != &"" else &"idle"
	_loop_name = &""
	play_loop(loop)


## Takılı kalan pozdan (faint/sit) çıkar.
func reset_pose() -> void:
	_one_shot = &""
	var loop: StringName = _loop_name if _loop_name != &"" else &"idle"
	_loop_name = &""
	play_loop(loop)


# --- Model yükleme -----------------------------------------------------------------

func _load_model() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var ps: PackedScene = load(MODEL_PATH) as PackedScene
		if ps != null:
			_model = ps.instantiate() as Node3D
	if _model == null:
		_model = _build_placeholder()
		is_placeholder = true
	_model.name = "Model"
	add_child(_model)
	_collect_materials()
	_setup_animations()


func _collect_materials() -> void:
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var node_slot: String = _slot_for_node(String(mi.name))
		for s: int in mi.mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(s)
			if src == null:
				src = mi.mesh.surface_get_material(s)
			var slot: String = _slot_for_material(src)
			if slot == "":
				slot = node_slot
			if slot == "":
				continue
			var m: BaseMaterial3D
			if src is BaseMaterial3D:
				m = (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			else:
				m = StandardMaterial3D.new()
			mi.set_surface_override_material(s, m)
			if not _mats.has(slot):
				_mats[slot] = [] as Array[BaseMaterial3D]
			(_mats[slot] as Array[BaseMaterial3D]).append(m)


func _slot_for_material(m: Material) -> String:
	if m == null:
		return ""
	var n: String = m.resource_name
	for slot: String in ["Skin", "Hair", "Cloth_Top", "Cloth_Pants", "Boots"]:
		if n == slot or n.begins_with(slot + "."):
			return slot
	return ""


func _slot_for_node(n: String) -> String:
	if n == "Body":
		return "Skin"
	if n.begins_with("Hair_") or n.begins_with("Beard_"):
		return "Hair"
	if n.begins_with("Top_"):
		return "Cloth_Top"
	if n.begins_with("Pants"):
		return "Cloth_Pants"
	if n.begins_with("Boots"):
		return "Boots"
	return ""


func _setup_animations() -> void:
	var found: Array[Node] = _model.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return
	_anim = found[0] as AnimationPlayer
	for full: StringName in _anim.get_animation_list():
		var short: String = String(full).get_slice("|", String(full).get_slice_count("|") - 1).to_lower()
		_anim_map[short] = String(full)
		var a: Animation = _anim.get_animation(full)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR if LOOP_ANIMS.has(StringName(short)) else Animation.LOOP_NONE
	_anim.animation_finished.connect(_on_animation_finished)


## Model yokken kullanılan parçalı yer tutucu (düğüm adları sözleşmeyle aynı).
func _build_placeholder() -> Node3D:
	var root := Node3D.new()
	_ph_part(root, "Body", _capsule(0.2, 0.75), Vector3(0, 1.2, 0), Vector3.ONE, "Skin") # gövde/kafa çekirdeği
	_ph_part(root, "Head", _sphere(0.2), Vector3(0, 1.58, 0), Vector3.ONE, "Skin")
	_ph_part(root, "Nose", _sphere(0.05), Vector3(0, 1.57, 0.19), Vector3.ONE, "Skin")
	_ph_part(root, "Pants_01", _capsule(0.19, 0.8), Vector3(0, 0.55, 0), Vector3(1.0, 1.0, 0.85), "Cloth_Pants")
	_ph_part(root, "Boots_Rubber", _box(Vector3(0.38, 0.22, 0.32)), Vector3(0, 0.11, 0.03), Vector3.ONE, "Boots")
	_ph_part(root, "Top_Raincoat", _capsule(0.27, 0.8), Vector3(0, 1.05, 0), Vector3.ONE, "Cloth_Top")
	_ph_part(root, "Top_Sweater", _capsule(0.25, 0.62), Vector3(0, 1.12, 0), Vector3.ONE, "Cloth_Top")
	_ph_part(root, "Top_Shirt", _capsule(0.235, 0.55), Vector3(0, 1.15, 0), Vector3.ONE, "Cloth_Top")
	var hair_scales: Array[Vector3] = [
		Vector3(1.05, 0.55, 1.05), Vector3(1.2, 0.75, 1.2), Vector3(1.05, 0.6, 1.25),
		Vector3(1.1, 0.25, 1.1), Vector3(1.12, 0.7, 1.15), Vector3(1.0, 0.9, 1.0),
	]
	for i: int in 6:
		_ph_part(root, "Hair_%02d" % (i + 1), _sphere(0.2), Vector3(0, 1.64 + 0.04 * float(i == 5), -0.02), hair_scales[i], "Hair")
	_ph_part(root, "Beard_00", _box(Vector3(0.01, 0.01, 0.01)), Vector3(0, 1.5, 0.15), Vector3.ONE, "Hair")
	_ph_part(root, "Beard_01", _box(Vector3(0.16, 0.035, 0.04)), Vector3(0, 1.52, 0.19), Vector3.ONE, "Hair")
	_ph_part(root, "Beard_02", _box(Vector3(0.26, 0.05, 0.05)), Vector3(0, 1.51, 0.19), Vector3.ONE, "Hair")
	_ph_part(root, "Beard_03", _sphere(0.19), Vector3(0, 1.5, 0.04), Vector3(1.02, 0.6, 1.0), "Hair")
	_ph_part(root, "Beard_04", _sphere(0.17), Vector3(0, 1.43, 0.1), Vector3(1.0, 1.0, 0.8), "Hair")
	var hat := CylinderMesh.new()
	hat.top_radius = 0.2
	hat.bottom_radius = 0.22
	hat.height = 0.1
	_ph_part(root, "Hat_Kasket", hat, Vector3(0, 1.76, 0.02), Vector3.ONE, "Cloth_Pants")
	return root


func _ph_part(root: Node3D, n: String, mesh: Mesh, pos: Vector3, scl: Vector3, mat_name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name
	m.albedo_color = Color(0.6, 0.6, 0.6)
	m.roughness = 0.85
	mesh.surface_set_material(0, m)
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	root.add_child(mi)


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
