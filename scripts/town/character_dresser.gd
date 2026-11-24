class_name CharacterDresser
extends RefCounted
## character_base.glb üzerine NPC/müşteri görünüşü uygular (parça görünürlüğü + materyal renkleri).
## Görünüş sözlüğü: { "skin": Color, "hair": StringName ("Hair_01".."Hair_06" ya da &"" = kel),
##   "hair_color": Color, "beard": StringName ("Beard_00".."Beard_04"), "hat": bool,
##   "top": StringName ("Top_Raincoat"/"Top_Sweater"/"Top_Shirt"), "top_color": Color,
##   "pants_color": Color, "boots_color": Color, "scale": float }

const MODEL_PATH: String = "res://assets/models/hero/character_base.glb"
const OPTIONAL_PREFIXES: Array[String] = ["Hair_", "Beard_", "Hat_", "Top_"]

const SKIN_TONES: Array[Color] = [
	Color(0.98, 0.84, 0.72), Color(0.93, 0.76, 0.62), Color(0.84, 0.65, 0.5),
	Color(0.72, 0.53, 0.39), Color(0.58, 0.41, 0.3), Color(0.42, 0.29, 0.21),
]


## Modeli yükler ve görünüşü uygular. Model yoksa kapsül biçimli yer tutucu döner.
static func build(look: Dictionary) -> Node3D:
	var model: Node3D = ModelLoader.instance(MODEL_PATH, Vector3(0.6, 1.75, 0.4), look.get("top_color", Color(0.5, 0.5, 0.5)) as Color)
	model.name = "Model"
	apply(model, look)
	var s: float = float(look.get("scale", 1.0))
	model.scale = Vector3(s, s, s)
	return model


static func apply(model: Node3D, look: Dictionary) -> void:
	var wanted: Array[String] = []
	var hair: String = String(look.get("hair", &"Hair_01"))
	if hair != "":
		wanted.append(hair)
	wanted.append(String(look.get("beard", &"Beard_00")))
	if bool(look.get("hat", false)):
		wanted.append("Hat_Kasket")
	wanted.append(String(look.get("top", &"Top_Shirt")))
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		var n: String = String(mi.name)
		for prefix: String in OPTIONAL_PREFIXES:
			if n.begins_with(prefix):
				mi.visible = wanted.has(n)
				break
		_tint(mi, look)


## Materyal adına göre renk uygular (Skin, Hair, Cloth_Top, Cloth_Pants, Boots).
static func _tint(mi: MeshInstance3D, look: Dictionary) -> void:
	if mi.mesh == null:
		return
	for i: int in range(mi.mesh.get_surface_count()):
		var mat: Material = mi.mesh.surface_get_material(i)
		if mat == null:
			continue
		var mname: String = mat.resource_name
		var col: Variant = null
		if mname.begins_with("Skin"):
			col = look.get("skin", null)
		elif mname.begins_with("Hair"):
			col = look.get("hair_color", null)
		elif mname.begins_with("Cloth_Top"):
			col = look.get("top_color", null)
		elif mname.begins_with("Cloth_Pants"):
			col = look.get("pants_color", null)
		elif mname.begins_with("Boots"):
			col = look.get("boots_color", null)
		if col == null:
			continue
		var copy: Material = mat.duplicate() as Material
		if copy is BaseMaterial3D:
			(copy as BaseMaterial3D).albedo_color = col as Color
		elif copy is ShaderMaterial:
			(copy as ShaderMaterial).set_shader_parameter(&"albedo", col as Color)
			(copy as ShaderMaterial).set_shader_parameter(&"base_color", col as Color)
		mi.set_surface_override_material(i, copy)


## Modeldeki AnimationPlayer'ı bulur.
static func find_anim_player(model: Node) -> AnimationPlayer:
	var list: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if list.is_empty():
		return null
	return list[0] as AnimationPlayer


## Adı verilen animasyonu (büyük/küçük harf ve önek duyarsız) oynatır. Döngüleri ayarlar.
static func play_anim(ap: AnimationPlayer, anim: String, blend: float = 0.2) -> void:
	if ap == null:
		return
	var found: String = ""
	for a: StringName in ap.get_animation_list():
		var s: String = String(a)
		if s == anim or s.to_lower() == anim or s.to_lower().ends_with("/" + anim) or s.to_lower().ends_with("|" + anim):
			found = s
			break
	if found == "":
		return
	if ap.current_animation == found and ap.is_playing():
		return
	var res: Animation = ap.get_animation(found)
	if res != null and anim in ["idle", "walk", "run", "sit"]:
		res.loop_mode = Animation.LOOP_LINEAR
	ap.play(found, blend)


## Rastgele bir köylü/müşteri görünüşü.
static func random_look(rng: RandomNumberGenerator, top_colors: Array[Color] = [], tops: Array[StringName] = []) -> Dictionary:
	var hairs: Array[String] = ["Hair_01", "Hair_02", "Hair_03", "Hair_04", "Hair_05", "Hair_06"]
	var beards: Array[String] = ["Beard_00", "Beard_00", "Beard_01", "Beard_02", "Beard_03", "Beard_04"]
	var all_tops: Array[StringName] = [&"Top_Raincoat", &"Top_Sweater", &"Top_Shirt"]
	var hair_cols: Array[Color] = [Color(0.12, 0.08, 0.05), Color(0.35, 0.22, 0.12), Color(0.6, 0.45, 0.25), Color(0.75, 0.75, 0.75), Color(0.9, 0.8, 0.5)]
	var cols: Array[Color] = top_colors if not top_colors.is_empty() else [Color(0.85, 0.7, 0.15), Color(0.2, 0.45, 0.3), Color(0.6, 0.15, 0.15), Color(0.25, 0.3, 0.55), Color(0.5, 0.4, 0.3)]
	var top_pool: Array[StringName] = tops if not tops.is_empty() else all_tops
	return {
		"skin": SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)],
		"hair": hairs[rng.randi_range(0, hairs.size() - 1)],
		"hair_color": hair_cols[rng.randi_range(0, hair_cols.size() - 1)],
		"beard": beards[rng.randi_range(0, beards.size() - 1)],
		"hat": rng.randf() < 0.3,
		"top": top_pool[rng.randi_range(0, top_pool.size() - 1)],
		"top_color": cols[rng.randi_range(0, cols.size() - 1)],
		"pants_color": Color(0.2, 0.22, 0.28).lerp(Color(0.35, 0.28, 0.2), rng.randf()),
		"boots_color": Color(0.15, 0.15, 0.15),
		"scale": rng.randf_range(0.95, 1.05),
	}
