class_name Catalog
extends RefCounted
## Hırdavatçı kataloğu (tohum, sarf malzemesi, ekipman kiti). Tüm fonksiyonlar statiktir.
## D'nin hırdavatçı NPC'si: Catalog.get_catalog() ve Catalog.buy(id).
## Girdi anahtarları: id, kind (&"seed" | &"supply" | &"buildable"), name, name_key,
##   description, price, min_license, available.
## Ekipman alımı envantere &"kit_<id>" ekler; inşa modunda kit bedava yerleştirilir.

const BUILDABLE_PATHS: Array[String] = [
	"res://data/buildables/pot.tres",
	"res://data/buildables/led_lamp.tres",
	"res://data/buildables/drip_irrigation.tres",
	"res://data/buildables/humidifier.tres",
	"res://data/buildables/heater.tres",
	"res://data/buildables/generator.tres",
	"res://data/buildables/drying_rack.tres",
	"res://data/buildables/curing_jars.tres",
	"res://data/buildables/shop_shelf.tres",
]

## Sarf malzemeleri: id → { item, price, name_key, desc_key, min_license }
const SUPPLIES: Dictionary = {
	&"nutrient": {"item": {"id": &"nutrient", "kind": &"nutrient", "count": 3}, "price": 60, "name_key": "CATALOG_NUTRIENT", "desc_key": "CATALOG_NUTRIENT_DESC", "min_license": 1},
	&"pesticide": {"item": {"id": &"pesticide", "kind": &"tool", "count": 1}, "price": 40, "name_key": "CATALOG_PESTICIDE", "desc_key": "CATALOG_PESTICIDE_DESC", "min_license": 1},
	&"paper": {"item": {"id": &"paper", "kind": &"paper", "count": 10}, "price": 20, "name_key": "CATALOG_PAPER", "desc_key": "CATALOG_PAPER_DESC", "min_license": 1},
	&"filter": {"item": {"id": &"filter", "kind": &"filter", "count": 10}, "price": 15, "name_key": "CATALOG_FILTER", "desc_key": "CATALOG_FILTER_DESC", "min_license": 1},
	&"watering_can": {"item": {"id": &"watering_can", "kind": &"tool", "count": 1}, "price": 90, "name_key": "CATALOG_WATERING_CAN", "desc_key": "CATALOG_WATERING_CAN_DESC", "min_license": 1},
}

## Satılan tohum türleri (GAFTİ hikâye ödülüdür, satılmaz). Lisansla açılır.
const SEED_STRAINS: Dictionary = {&"pusu_kusu": 1, &"cay_yapragi": 1, &"ladin_duman": 2}

static var _buildables: Dictionary = {}


## Tüm yerleştirilebilir tanımlar (id → BuildableData).
static func get_buildables() -> Array[BuildableData]:
	_ensure()
	var out: Array[BuildableData] = []
	for p: String in BUILDABLE_PATHS:
		var d: BuildableData = _buildables.get(StringName(p.get_file().get_basename()))
		if d != null:
			out.append(d)
	return out


static func get_buildable(id: StringName) -> BuildableData:
	_ensure()
	return _buildables.get(id)


static func _ensure() -> void:
	if not _buildables.is_empty():
		return
	for p: String in BUILDABLE_PATHS:
		if ResourceLoader.exists(p):
			var d: BuildableData = load(p) as BuildableData
			if d != null:
				_buildables[d.id] = d


static func _license() -> int:
	var rep: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Reputation")
	return int(rep.get("license_level")) if rep != null else 1


static func get_catalog() -> Array[Dictionary]:
	_ensure()
	var lic: int = _license()
	var out: Array[Dictionary] = []
	for sid: StringName in SEED_STRAINS:
		var s: StrainData = SeedBook.get_strain(sid)
		if s == null:
			continue
		var ml: int = int(SEED_STRAINS[sid])
		out.append({
			"id": StringName("seed_" + String(sid)), "kind": &"seed", "name": tr_key("CATALOG_SEED") % s.get_display_name(),
			"name_key": s.name_key, "description": tr_key(s.description_key), "price": s.seed_price,
			"min_license": ml, "available": lic >= ml,
		})
	for id: StringName in SUPPLIES:
		var e: Dictionary = SUPPLIES[id]
		var ml2: int = int(e["min_license"])
		out.append({
			"id": id, "kind": &"supply", "name": tr_key(e["name_key"]), "name_key": e["name_key"],
			"description": tr_key(e["desc_key"]), "price": int(e["price"]), "min_license": ml2, "available": lic >= ml2,
		})
	for d: BuildableData in get_buildables():
		out.append({
			"id": d.id, "kind": &"buildable", "name": d.get_display_name(), "name_key": d.name_key,
			"description": tr_key(d.description_key), "price": d.price, "min_license": d.min_license,
			"available": lic >= d.min_license,
		})
	return out


## Satın alır: para düşer, eşya envantere eklenir. Başarısızsa false.
static func buy(id: StringName) -> bool:
	_ensure()
	var entry: Dictionary = {}
	for e: Dictionary in get_catalog():
		if e["id"] == id:
			entry = e
			break
	if entry.is_empty():
		return false
	var bus: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"EventBus")
	if not bool(entry["available"]):
		if bus != null:
			bus.emit_signal(&"notify", tr_key("CATALOG_NEED_LICENSE") % int(entry["min_license"]), &"bad")
		return false
	if not Economy.spend(int(entry["price"]), tr_key("ECON_REASON_PURCHASE") % String(entry["name"])):
		return false
	match entry["kind"]:
		&"seed":
			var strain: StringName = StringName(String(id).trim_prefix("seed_"))
			Inventory.add_item(Inventory.make_item(&"seed", strain, 0, 1, 0.0))
		&"supply":
			Inventory.add_item((SUPPLIES[id]["item"] as Dictionary).duplicate())
		&"buildable":
			Inventory.add_item({"id": StringName("kit_" + String(id)), "kind": &"tool", "strain": id, "count": 1})
	if bus != null:
		bus.emit_signal(&"notify", tr_key("CATALOG_BOUGHT") % String(entry["name"]), &"good")
	var qm: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"QuestManager")
	if qm != null and qm.has_method("notify_event"):
		qm.call("notify_event", &"item_bought", {"id": id, "kind": entry["kind"]})
	return true


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)
