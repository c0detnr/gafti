extends Node
## Oyuncu envanteri. Eşya = Dictionary:
## { "id": StringName, "kind": StringName, "strain": StringName, "quality": int, "grams": float, "count": int }
## Kurallar: aynı id'li eşyalar tek yığında birleşir (count toplanır).
##  - Tomurcuk (wet_bud/dry_bud): 1 adet = 1 gram, grams = 1.0
##  - Kavanoz: count = kavanoz sayısı, grams = kavanoz başına gram (5.0)
##  - Pre-roll: count = adet, grams = 1.0
## Sözleşme: AGENTS.md §4 (Inventory).

signal changed()

const KINDS: Array[StringName] = [
	&"seed", &"wet_bud", &"dry_bud", &"jar", &"preroll", &"paper", &"filter", &"nutrient", &"tool",
]
const JAR_GRAMS: float = 5.0
## Kalite yığın aralığı (yığın sayısını azaltmak için kalite 5'in katına yuvarlanır).
const QUALITY_STEP: int = 5
const WATER_ID: StringName = &"water"
const WATER_CAN_ID: StringName = &"watering_can"
const WATER_CAN_CAPACITY: int = 6

var _items: Array[Dictionary] = []


## Standart eşya sözlüğü üretir.
static func make_item(kind: StringName, strain: StringName = &"", quality: int = 0, count: int = 1, grams: float = 1.0) -> Dictionary:
	var q: int = quantize_quality(quality)
	return {
		"id": make_id(kind, strain, q), "kind": kind, "strain": strain,
		"quality": q, "grams": grams, "count": count,
	}


## Eşya id'si: tohum "seed_<tür>", ürünler "<tür>_<strain>_q<kalite>", diğerleri kind adı.
static func make_id(kind: StringName, strain: StringName = &"", quality: int = 0) -> StringName:
	match kind:
		&"seed":
			return StringName("seed_" + String(strain))
		&"wet_bud", &"dry_bud", &"jar", &"preroll":
			return StringName("%s_%s_q%d" % [kind, strain, quantize_quality(quality)])
	return kind


static func quantize_quality(q: int) -> int:
	return clampi(int(round(float(q) / QUALITY_STEP)) * QUALITY_STEP, 0, 100)


func add_item(item: Dictionary) -> void:
	var it: Dictionary = _normalize(item)
	if int(it["count"]) <= 0:
		return
	var idx: int = _find(it["id"])
	if idx >= 0:
		_items[idx]["count"] = int(_items[idx]["count"]) + int(it["count"])
	else:
		_items.append(it)
	if it["kind"] == &"seed" and it["strain"] != &"":
		SeedBook.discover(it["strain"])
	changed.emit()


func remove_item(id: StringName, count: int = 1) -> bool:
	var idx: int = _find(id)
	if idx < 0 or int(_items[idx]["count"]) < count:
		return false
	_items[idx]["count"] = int(_items[idx]["count"]) - count
	if int(_items[idx]["count"]) <= 0:
		_items.remove_at(idx)
	changed.emit()
	return true


func count_of(id: StringName) -> int:
	var idx: int = _find(id)
	return 0 if idx < 0 else int(_items[idx]["count"])


func get_items(kind: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in _items:
		if kind == &"" or it["kind"] == kind:
			out.append(it.duplicate())
	return out


## Tek eşyanın kopyası (yoksa boş sözlük).
func get_item(id: StringName) -> Dictionary:
	var idx: int = _find(id)
	return {} if idx < 0 else _items[idx].duplicate()


func has_item(id: StringName, count: int = 1) -> bool:
	return count_of(id) >= count


## Bir türdeki toplam gram (tomurcuklar için adet = gram).
func total_grams(kind: StringName) -> float:
	var g: float = 0.0
	for it: Dictionary in _items:
		if it["kind"] == kind:
			g += float(it["grams"]) * float(it["count"])
	return g


func clear() -> void:
	_items.clear()
	changed.emit()


func _find(id: StringName) -> int:
	for i: int in range(_items.size()):
		if _items[i]["id"] == id:
			return i
	return -1


func _normalize(item: Dictionary) -> Dictionary:
	var kind: StringName = StringName(item.get("kind", &"tool"))
	var strain: StringName = StringName(item.get("strain", &""))
	var quality: int = int(item.get("quality", 0))
	var id: StringName = StringName(item.get("id", &""))
	if id == &"":
		id = make_id(kind, strain, quality)
	return {
		"id": id, "kind": kind, "strain": strain, "quality": quality,
		"grams": float(item.get("grams", 1.0)), "count": int(item.get("count", 1)),
	}


# ---------------------------------------------------------------------------
# Yeni oyun ve kayıt
# ---------------------------------------------------------------------------

## GDD §5.9: 3 tohum türü × 2 + sulama kabı + temel sarf malzemeleri + dedenin zulası.
func reset() -> void:
	_items.clear()
	for s: StringName in [&"pusu_kusu", &"ladin_duman", &"cay_yapragi"]:
		add_item(make_item(&"seed", s, 0, 2, 0.0))
	add_item({"id": WATER_CAN_ID, "kind": &"tool", "count": 1})
	add_item({"id": WATER_ID, "kind": &"tool", "count": 3})
	add_item({"id": &"nutrient", "kind": &"nutrient", "count": 5})
	add_item({"id": &"pesticide", "kind": &"tool", "count": 2})
	add_item({"id": &"paper", "kind": &"paper", "count": 10})
	add_item({"id": &"filter", "kind": &"filter", "count": 10})
	add_item(make_item(&"dry_bud", &"pusu_kusu", 50, 20, 1.0))
	changed.emit()


func get_save_data() -> Dictionary:
	var arr: Array = []
	for it: Dictionary in _items:
		arr.append({
			"id": String(it["id"]), "kind": String(it["kind"]), "strain": String(it["strain"]),
			"quality": it["quality"], "grams": it["grams"], "count": it["count"],
		})
	return {"items": arr}


func load_save_data(d: Dictionary) -> void:
	if d.is_empty():
		reset()
		return
	_items.clear()
	for raw: Variant in d.get("items", []):
		if raw is Dictionary:
			var r: Dictionary = raw
			_items.append(_normalize({
				"id": StringName(String(r.get("id", ""))), "kind": StringName(String(r.get("kind", "tool"))),
				"strain": StringName(String(r.get("strain", ""))), "quality": int(r.get("quality", 0)),
				"grams": float(r.get("grams", 1.0)), "count": int(r.get("count", 1)),
			}))
	changed.emit()
