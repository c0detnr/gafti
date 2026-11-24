class_name SeedBook
extends RefCounted
## Tohum Defteri: temel türler + çaprazlanmış özel türler + keşfedilen türler koleksiyonu.
## Statik durum tutar; kaydını SaveSystem "seed_book" anahtarıyla alır.

const BASE_STRAIN_PATHS: Array[String] = [
	"res://data/strains/pusu_kusu.tres",
	"res://data/strains/ladin_duman.tres",
	"res://data/strains/cay_yapragi.tres",
	"res://data/strains/gafti.tres",
]
## Başlangıçta oyuncunun bildiği türler (GAFTİ hikâye ödülüdür).
const STARTING_STRAINS: Array[StringName] = [&"pusu_kusu", &"ladin_duman", &"cay_yapragi"]

static var _base: Dictionary = {}       # id -> StrainData
static var _custom: Dictionary = {}     # id -> StrainData
static var _discovered: Array[StringName] = []
static var _next_custom: int = 1


static func _ensure_base() -> void:
	if not _base.is_empty():
		return
	for p: String in BASE_STRAIN_PATHS:
		if ResourceLoader.exists(p):
			var s: StrainData = load(p) as StrainData
			if s != null:
				_base[s.id] = s
	if _discovered.is_empty():
		_discovered = STARTING_STRAINS.duplicate()


static func get_strain(id: StringName) -> StrainData:
	_ensure_base()
	if _base.has(id):
		return _base[id]
	if _custom.has(id):
		return _custom[id]
	return null


static func has_strain(id: StringName) -> bool:
	return get_strain(id) != null


## Tüm bilinen türler (temel + özel).
static func all_strains() -> Array[StrainData]:
	_ensure_base()
	var out: Array[StrainData] = []
	for k: StringName in _base:
		out.append(_base[k])
	for k: StringName in _custom:
		out.append(_custom[k])
	return out


## Oyuncunun keşfettiği türler (Tohum Defteri koleksiyonu).
static func get_discovered() -> Array[StrainData]:
	_ensure_base()
	var out: Array[StrainData] = []
	for id: StringName in _discovered:
		var s: StrainData = get_strain(id)
		if s != null:
			out.append(s)
	return out


static func is_discovered(id: StringName) -> bool:
	_ensure_base()
	return _discovered.has(id)


static func discover(id: StringName) -> void:
	_ensure_base()
	if not _discovered.has(id) and get_strain(id) != null:
		_discovered.append(id)


## Yeni (çaprazlanmış) türü kaydeder ve benzersiz id verir.
static func register_custom(s: StrainData) -> StringName:
	_ensure_base()
	if s.id == &"" or _base.has(s.id) or _custom.has(s.id):
		s.id = StringName("custom_%d" % _next_custom)
		_next_custom += 1
	_custom[s.id] = s
	discover(s.id)
	return s.id


static func get_custom_count() -> int:
	return _custom.size()


static func reset() -> void:
	_custom.clear()
	_discovered.clear()
	_next_custom = 1
	_base.clear()
	_ensure_base()


static func get_save_data() -> Dictionary:
	_ensure_base()
	var customs: Array = []
	for k: StringName in _custom:
		customs.append((_custom[k] as StrainData).to_dict())
	var disc: Array[String] = []
	for id: StringName in _discovered:
		disc.append(String(id))
	return {"custom": customs, "discovered": disc, "next": _next_custom}


static func load_save_data(d: Dictionary) -> void:
	reset()
	if d.is_empty():
		return
	for raw: Variant in d.get("custom", []):
		if raw is Dictionary:
			var s: StrainData = StrainData.from_dict(raw)
			_custom[s.id] = s
	_discovered.clear()
	for id: Variant in d.get("discovered", []):
		_discovered.append(StringName(String(id)))
	_next_custom = int(d.get("next", _custom.size() + 1))
