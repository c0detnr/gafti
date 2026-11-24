extends Node3D
## Pusludere vadisi montajı. Arazi, binalar, dekor, istasyonlar, NPC'ler, oyuncu ve UI'ı kodla kurar.
## Koordinatlar: AGENTS.md §9.

const M_HERO: String = "res://assets/models/hero/"
const M_PROPS: String = "res://assets/models/props/"
const M_TOWN: String = "res://assets/models/town/"
const SQUARE: Vector3 = Vector3(60, 0, 0)
const FARM_Y: float = 2.0

## Binalar: [model yolu, konum, bakacağı nokta (kapı +Z buraya döner)]
var BUILDINGS: Array = [
	[M_HERO + "house.glb", Vector3(-70, FARM_Y, 40), Vector3(-62, FARM_Y, 28)],
	[M_HERO + "greenhouse.glb", Vector3(-55, FARM_Y, 30), Vector3(-55, FARM_Y, 10)],
	[M_TOWN + "drying_barn.glb", Vector3(-78, FARM_Y, 22), Vector3(-62, FARM_Y, 28)],
	[M_TOWN + "shop_building.glb", Vector3(60, 0, -14), SQUARE],
	[M_TOWN + "kahvehane.glb", Vector3(46, 0, 8), SQUARE],
	[M_TOWN + "muhtarlik.glb", Vector3(74, 0, 8), SQUARE],
	[M_TOWN + "inspection_office.glb", Vector3(78, 0, -8), SQUARE],
	[M_TOWN + "hardware_store.glb", Vector3(42, 0, -10), SQUARE],
	[M_TOWN + "bus_stop.glb", Vector3(72, 0, 48), SQUARE],
]

var static_root: Node3D
var nav_region: NavigationRegion3D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 20261124
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	add_child(nav_region)
	static_root = Node3D.new()
	static_root.name = "Static"
	nav_region.add_child(static_root)

	add_child(_instance_scene("res://scenes/world/atmosphere.gd", true))
	_build_terrain()
	_build_buildings()
	_build_water()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build_decor()
	_build_stations()
	_build_actors()
	_build_ui()
	_bake_navigation()
	_start_game()


# ---------- yardımcılar ----------

func _instance_scene(path: String, is_script: bool = false) -> Node:
	if is_script:
		var n := Node3D.new()
		n.name = path.get_file().get_basename().capitalize().replace(" ", "")
		n.set_script(load(path))
		return n
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate()
	push_warning("Eksik sahne: " + path)
	return null


func _place(path: String, pos: Vector3, yaw: float = 0.0, parent: Node = null, size: Vector3 = Vector3.ONE) -> Node3D:
	var n: Node3D = ModelLoader.instance(path, size)
	(parent if parent != null else static_root).add_child(n)
	n.global_position = pos
	n.rotation.y = yaw
	return n


func _yaw_towards(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2(d.x, d.z)


## Zeminin yüksekliğini ışınla bulur (arazi çarpışması gerekli).
func ground_y(x: float, z: float, fallback: float = 0.0) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -40, z))
	q.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return fallback
	return (hit["position"] as Vector3).y


func _instance_at(path: String, pos: Vector3, yaw: float = 0.0, parent: Node = null) -> Node:
	var n: Node = _instance_scene(path)
	if n == null:
		return null
	(parent if parent != null else self).add_child(n)
	if n is Node3D:
		(n as Node3D).global_position = pos
		(n as Node3D).rotation.y = yaw
	return n


# ---------- dünya ----------

func _build_terrain() -> void:
	var t: Node3D = _place(M_TOWN + "terrain.glb", Vector3.ZERO, 0.0, null, Vector3(260, 0.2, 260))
	t.name = "Terrain"
	if t.name.begins_with("Placeholder"):
		# Model yoksa düz zemin + çarpışma
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(260, 1, 260)
		cs.shape = box
		cs.position.y = -0.5
		body.add_child(cs)
		t.add_child(body)


func _build_buildings() -> void:
	for b: Array in BUILDINGS:
		var pos: Vector3 = b[1]
		var n: Node3D = _place(b[0], pos, _yaw_towards(pos, b[2]), null, Vector3(8, 4, 6))
		n.name = (b[0] as String).get_file().get_basename().to_pascal_case()
	# Köprü dere üzerinde, Z yönünde geçilir
	_place(M_TOWN + "bridge.glb", Vector3(5, -1, -45), 0.0).name = "Bridge"
	# Minibüs durakta
	_place(M_TOWN + "minibus.glb", Vector3(78, 0, 52), deg_to_rad(90)).name = "Minibus"


func _build_water() -> void:
	# Arazideki Water mesh'i varsa onun materyalini yumuşat; yoksa dere düzlemi ekle
	var terrain: Node = static_root.get_node_or_null("Terrain")
	if terrain != null and terrain.find_child("Water", true, false) != null:
		var w: MeshInstance3D = terrain.find_child("Water", true, false) as MeshInstance3D
		if w != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.25, 0.55, 0.60, 0.75)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.05
			mat.metallic_specular = 0.8
			w.material_override = mat
	# Yerde kayan sis katmanları (vadide üç bölge)
	if ResourceLoader.exists("res://shaders/fog_layer.gdshader"):
		for p: Vector3 in [Vector3(-40, 3.5, -60), Vector3(0, 1.5, -45), Vector3(-60, 4.0, 40)]:
			var mi := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(90, 90)
			mi.mesh = plane
			var sm := ShaderMaterial.new()
			sm.shader = load("res://shaders/fog_layer.gdshader")
			mi.material_override = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.global_position = p


func _build_decor() -> void:
	var decor := Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	# Ladin ormanı (güneybatı) + vadi kenarlarına serpiştirilmiş ağaçlar
	for i: int in 70:
		var c: Vector3 = Vector3(-45, 0, -70)
		var p: Vector3 = c + Vector3(rng.randf_range(-35, 35), 0, rng.randf_range(-22, 22))
		_scatter(M_PROPS + "spruce_tree.glb", p, decor, rng.randf_range(0.8, 1.5))
	for i: int in 60:
		var ang: float = rng.randf() * TAU
		var r: float = rng.randf_range(95, 120)
		_scatter(M_PROPS + "spruce_tree.glb", Vector3(cos(ang) * r, 0, sin(ang) * r), decor, rng.randf_range(1.0, 1.8))
	# Çay bahçeleri: ev ile kasaba arasındaki yol kenarı yamaçları
	for row: int in 6:
		for col: int in 10:
			var p2: Vector3 = Vector3(-30 + col * 2.6, 0, 18 + row * 2.4)
			_scatter(M_PROPS + "tea_bush.glb", p2, decor, rng.randf_range(0.8, 1.1))
	for row: int in 5:
		for col: int in 9:
			_scatter(M_PROPS + "tea_bush.glb", Vector3(5 + col * 2.6, 0, 20 + row * 2.4), decor, rng.randf_range(0.8, 1.1))
	# Kayalar
	for i: int in 40:
		var p3: Vector3 = Vector3(rng.randf_range(-110, 110), 0, rng.randf_range(-110, 110))
		if _near_any_zone(p3, 18.0):
			continue
		_scatter(M_PROPS + ("rock_01.glb" if i % 2 == 0 else "rock_02.glb"), p3, decor, rng.randf_range(0.6, 1.8))
	# Çiftlik çiti
	for i: int in 12:
		_place(M_PROPS + "fence.glb", Vector3(-85 + i * 2.2, ground_y(-85 + i * 2.2, 56, FARM_Y), 56), 0.0, decor)
	# Meydan: banklar, sokak lambaları, tavla masası
	for a: int in 6:
		var ang2: float = a * TAU / 6.0
		var lp: Vector3 = SQUARE + Vector3(cos(ang2) * 14, 0, sin(ang2) * 14)
		_place(M_PROPS + "lamp_post.glb", lp, -ang2, decor)
		_add_lamp_light(lp + Vector3(0, 3.6, 0), decor)
	_place(M_PROPS + "bench.glb", SQUARE + Vector3(-6, 0, 6), deg_to_rad(180), decor)
	_place(M_PROPS + "bench.glb", SQUARE + Vector3(6, 0, 6), deg_to_rad(180), decor)
	_place(M_PROPS + "tavla_table.glb", Vector3(48, 0, 13), 0.0, decor)
	_place(M_PROPS + "tavla_table.glb", Vector3(44, 0, 13), 0.3, decor)
	_place(M_PROPS + "crate.glb", Vector3(39, 0, -6), 0.4, decor)
	_place(M_PROPS + "crate.glb", Vector3(39.8, 0, -4.8), 1.1, decor)
	_place(M_PROPS + "bench.glb", Vector3(70, 0, 45), deg_to_rad(-90), decor)
	# Ev içi: yatak/ayna/kanepe house.glb içinde zaten var; yanına sandık
	_place(M_PROPS + "crate.glb", Vector3(-60, FARM_Y, 37), 0.2, decor)


func _scatter(path: String, p: Vector3, parent: Node3D, s: float) -> void:
	var n: Node3D = _place(path, Vector3(p.x, ground_y(p.x, p.z, 0.0), p.z), rng.randf() * TAU, parent, Vector3(1, 3, 1))
	n.scale = Vector3.ONE * s


func _near_any_zone(p: Vector3, r: float) -> bool:
	for z: Vector3 in [Vector3(-62, 0, 32), SQUARE, Vector3(72, 0, 48), Vector3(5, 0, -45), Vector3(0, 0, -110)]:
		if Vector2(p.x - z.x, p.z - z.z).length() < r + 14.0:
			return true
	return false


func _add_lamp_light(p: Vector3, parent: Node3D) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.45)
	l.omni_range = 9.0
	l.light_energy = 0.0
	l.add_to_group("night_lights")
	parent.add_child(l)
	l.global_position = p


func _build_stations() -> void:
	pass # İstasyonlar ajan raporlarına göre eklenecek (bkz. _build_stations_impl).


func _build_actors() -> void:
	pass


func _build_ui() -> void:
	pass


func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.agent_radius = 0.4
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.filter_baking_aabb = AABB(Vector3(-30, -5, -40), Vector3(130, 30, 110))
	nav_region.navigation_mesh = nm
	nav_region.bake_navigation_mesh(true)


func _start_game() -> void:
	pass


func _process(_delta: float) -> void:
	# Gece sokak lambaları yanar
	var night: bool = false
	if has_node("/root/GameClock"):
		var h: int = int(get_node("/root/GameClock").get("hour"))
		night = h >= 19 or h < 6
	for l: Node in get_tree().get_nodes_in_group("night_lights"):
		(l as OmniLight3D).light_energy = lerpf((l as OmniLight3D).light_energy, 1.6 if night else 0.0, 0.05)
