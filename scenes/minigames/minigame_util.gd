class_name MinigameUtil
extends RefCounted
## Mini oyunlar ve istasyonlar için güvenli autoload yardımcıları (Ajan B).
## Diğer ajanların autoload'ları henüz yoksa sessizce varsayılan davranır.

const BUD_PER_JOINT: float = 0.5


static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func autoload(n: String) -> Node:
	var t: SceneTree = tree()
	if t == null or t.root == null:
		return null
	return t.root.get_node_or_null(NodePath(n))


static func sfx(id: StringName) -> void:
	var am: Node = autoload("AudioManager")
	if am != null and am.has_method(&"play_sfx"):
		am.call(&"play_sfx", id)


## tr() sonucu biçimlendirme; çeviri yüklenmemişse (anahtar döndüyse) güvenle ekler.
static func fmt(text: String, args: Variant) -> String:
	if text.contains("%"):
		return text % args
	return "%s %s" % [text, str(args)]


static func notify(text: String, kind: StringName = &"info") -> void:
	var bus: Node = autoload("EventBus")
	if bus != null:
		bus.emit_signal(&"notify", text, kind)
	else:
		print("[notify] ", text)


static func consumption_enabled() -> bool:
	var cf: Node = autoload("ContentFlags")
	if cf != null and "consumption" in cf:
		return bool(cf.get("consumption"))
	return true


static func effects() -> Node:
	return autoload("Effects")


static func rolled_count() -> int:
	var fx: Node = effects()
	if fx != null and "rolled_count" in fx:
		return int(fx.get("rolled_count"))
	return 0


static func rolling_bonus() -> int:
	var fx: Node = effects()
	if fx != null and fx.has_method(&"get_rolling_bonus"):
		return int(fx.call(&"get_rolling_bonus"))
	return 0


static func water_jitter() -> float:
	var fx: Node = effects()
	if fx != null and fx.has_method(&"get_water_jitter"):
		return float(fx.call(&"get_water_jitter"))
	return 0.0


static func start_gafti(strength: float, minutes: int) -> void:
	var fx: Node = effects()
	if fx != null and fx.has_method(&"start_gafti"):
		fx.call(&"start_gafti", strength, minutes)


# ---------------------------------------------------------------- Envanter

static func has_inventory() -> bool:
	var inv: Node = autoload("Inventory")
	return inv != null and inv.has_method(&"get_items")


static func count_of(id: StringName) -> int:
	var inv: Node = autoload("Inventory")
	if inv == null or not inv.has_method(&"count_of"):
		return 0
	return int(inv.call(&"count_of", id))


static func get_items(kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inv: Node = autoload("Inventory")
	if inv == null or not inv.has_method(&"get_items"):
		return out
	var raw: Variant = inv.call(&"get_items", kind)
	if raw is Array:
		for v: Variant in raw:
			if v is Dictionary:
				out.append(v as Dictionary)
	return out


## Bir kuru tomurcuk yığınındaki toplam gram (count = gram, grams = birim başı gram).
static func item_grams(item: Dictionary) -> float:
	var per: float = float(item.get("grams", 1.0))
	if per <= 0.0:
		per = 1.0
	return float(item.get("count", 1)) * per


## Yeterli gramı olan en kaliteli kuru tomurcuğu döner (yoksa boş).
static func best_dry_bud(min_grams: float) -> Dictionary:
	var best: Dictionary = {}
	for it: Dictionary in get_items(&"dry_bud"):
		var avail: float = item_grams(it) + loose_grams_for(StringName(str(it.get("id", ""))))
		if avail + 0.0001 < min_grams:
			continue
		if best.is_empty() or int(it.get("quality", 0)) > int(best.get("quality", 0)):
			best = it
	return best


static func loose_grams_for(id: StringName) -> float:
	var fx: Node = effects()
	if fx == null or not ("loose_bud" in fx):
		return 0.0
	var loose: Dictionary = fx.get("loose_bud") as Dictionary
	return float(loose.get(String(id), 0.0))


## Kuru tomurcuktan gram düşer. Birim (1 count) açılınca artan kısım Effects.loose_bud'da saklanır.
static func consume_bud(id: StringName, grams: float) -> bool:
	var inv: Node = autoload("Inventory")
	if inv == null or not inv.has_method(&"remove_item"):
		return true # Test/envantersiz ortam: serbest.
	var fx: Node = effects()
	var loose: Dictionary = {}
	if fx != null and "loose_bud" in fx:
		loose = fx.get("loose_bud") as Dictionary
	var key: String = String(id)
	var have: float = float(loose.get(key, 0.0))
	var need: float = grams
	while have + 0.0001 < need:
		if not bool(inv.call(&"remove_item", id, 1)):
			return false
		have += 1.0
	have -= need
	if have > 0.0001:
		loose[key] = have
	else:
		loose.erase(key)
	if fx != null and "loose_bud" in fx:
		fx.set("loose_bud", loose)
	return true


static func consume(id: StringName, count: int = 1) -> bool:
	var inv: Node = autoload("Inventory")
	if inv == null or not inv.has_method(&"remove_item"):
		return true
	return bool(inv.call(&"remove_item", id, count))


static func add_preroll(strain: StringName, quality: int, roll_name: String, score: int) -> Dictionary:
	var item: Dictionary = {}
	var inv: Node = autoload("Inventory")
	if inv != null and inv.has_method(&"make_item"):
		var made: Variant = inv.call(&"make_item", &"preroll", strain, quality, 1, 1.0)
		if made is Dictionary:
			item = made as Dictionary
	if item.is_empty():
		item = {
			"id": StringName("preroll_%s_q%d" % [String(strain), quality]),
			"kind": &"preroll",
			"strain": strain,
			"quality": quality,
			"grams": BUD_PER_JOINT,
			"count": 1,
		}
	item["roll_name"] = roll_name
	item["roll_score"] = score
	if inv != null and inv.has_method(&"add_item"):
		inv.call(&"add_item", item)
	return item
