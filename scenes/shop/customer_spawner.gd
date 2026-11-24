class_name CustomerSpawner
extends Node
## Dükkan açıkken müşteri üretir. Sıklık: hava (Weather.get_customer_multiplier), itibar, mevsim
## (yazın turist ×2). Tipler data/customers/*.tres (CustomerProfile). Kimlik kartlarını da burada üretir.
## Ebeveyn ShopManager olmalı.

const CUSTOMER_DIR: String = "res://data/customers/"
const CUSTOMER_SCRIPT: Script = preload("res://scenes/shop/customer.gd")
## Temel gelişler arası süre (oyun dakikası).
const BASE_INTERVAL_MIN: float = 40.0
const MAX_CUSTOMERS: int = 4
const MINOR_CHANCE: float = 0.06
const EXPIRED_CHANCE: float = 0.06
const INVALID_DOC_CHANCE: float = 0.05
const HANS_CHANCE: float = 0.25   # turistler arasında

const FIRST_NAMES: Array[String] = ["Temel", "Dursun", "İdris", "Hasan", "Fadimana", "Nazmiye", "Cemile", "Recep",
	"Hüsnü", "Emine", "Şaban", "Hatice", "Rıza", "Zekiye", "Kâzım", "Hamdi", "Saniye", "Yakup", "Nurhan", "Ali Osman"]
const LAST_NAMES: Array[String] = ["Uzunoğlu", "Karadağ", "Yaylacı", "Hamsioğlu", "Fındıkçı", "Çaycıoğlu", "Kemençeci",
	"Dereli", "Sisli", "Pusluoğlu", "Ladinli", "Kekliktepe", "Horonoğlu", "Mısırekmekçi"]
const TOURIST_NAMES: Array[String] = ["Jessica Miller", "Kenji Sato", "Lars Olsen", "Marie Dubois", "Pablo García",
	"Olga Ivanova", "Tom Baker", "Sven Larsson", "Chiara Rossi"]
const EXPERT_NAMES: Array[String] = ["Selim Şehirli", "Bora Zanaat", "Defne Terroir", "Kaan Genetikçi", "Ece Terpen"]
const INVALID_DOCS: Array[String] = ["IDCARD_DOC_TEA_LOYALTY", "IDCARD_DOC_LIBRARY", "IDCARD_DOC_VERESIYE", "IDCARD_DOC_WEDDING"]

@export var enabled: bool = true

var profiles: Array[CustomerProfile] = []
var _accum: float = 0.0
var _last_total: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_profiles()
	var clock: Node = get_node_or_null(^"/root/GameClock")
	if clock != null:
		clock.connect(&"minute_passed", _on_minute_passed)


func _load_profiles() -> void:
	var dir: DirAccess = DirAccess.open(CUSTOMER_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		var file: String = f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var p: CustomerProfile = load(CUSTOMER_DIR + file) as CustomerProfile
			if p != null:
				profiles.append(p)


func _shop() -> ShopManager:
	return get_parent() as ShopManager


func _on_minute_passed(total: int) -> void:
	var step: int = 1 if _last_total < 0 else maxi(0, total - _last_total)
	_last_total = total
	var shop: ShopManager = _shop()
	if not enabled or shop == null or not shop.is_open:
		_accum = 0.0
		return
	_accum += float(step)
	if _accum >= current_interval():
		_accum = 0.0
		if shop.get_customers().size() < MAX_CUSTOMERS:
			spawn()


## Şu anki gelişler arası süre (oyun dakikası).
func current_interval() -> float:
	var mult: float = 1.0
	if Weather.has_method(&"get_customer_multiplier"):
		mult *= Weather.get_customer_multiplier()
	mult *= clampf(0.6 + Reputation.reputation / 60.0, 0.6, 2.2)
	return BASE_INTERVAL_MIN / maxf(0.15, mult)


func _season() -> StringName:
	return GameClock.season


## Ağırlıklı rastgele profil (yazın turist çarpanı, kışın kış çarpanı, uzman itibara bağlı).
func pick_profile() -> CustomerProfile:
	if profiles.is_empty():
		return null
	var total: float = 0.0
	var weights: Array[float] = []
	for p: CustomerProfile in profiles:
		var w: float = p.spawn_weight
		if _season() == &"summer":
			w *= p.summer_multiplier
		elif _season() == &"winter":
			w *= p.winter_multiplier
		if p.type == &"expert" and Reputation.reputation < 25.0 and Reputation.license_level < 2:
			w *= 0.15
		weights.append(w)
		total += w
	var r: float = _rng.randf() * total
	for i: int in range(profiles.size()):
		r -= weights[i]
		if r <= 0.0:
			return profiles[i]
	return profiles[profiles.size() - 1]


func spawn() -> ShopCustomer:
	var shop: ShopManager = _shop()
	var p: CustomerProfile = pick_profile()
	if shop == null or p == null:
		return null
	var c: ShopCustomer = CUSTOMER_SCRIPT.new() as ShopCustomer
	c.name = "Customer_%d" % _rng.randi()
	c.shop = shop
	c.profile = p
	var budget_mult: float = 1.3 if _season() == &"winter" else 1.0
	c.budget = int(float(_rng.randi_range(p.budget_min, p.budget_max)) * budget_mult)
	c.card = make_card(p)
	if bool(c.card.get("minor", false)):
		c.look = _kid_look()
	elif String(c.card.get("variant", "")) == "hans":
		c.look = {"skin": Color(0.98, 0.84, 0.72), "hair": "Hair_05", "hair_color": Color(0.92, 0.8, 0.45),
			"beard": "Beard_00", "top": "Top_Shirt", "top_color": Color(0.98, 0.5, 0.2), "scale": 1.06}
	else:
		c.look = CharacterDresser.random_look(_rng, p.top_colors, p.tops)
	c.card["photo_look"] = c.look.duplicate()
	if bool(c.card.get("minor", false)):
		# Kartta keçeli kalemle bıyık çizilmiş çocuk fotoğrafı.
		(c.card["photo_look"] as Dictionary)["beard"] = "Beard_02"
		(c.card["photo_look"] as Dictionary)["crayon"] = true
	shop.add_child(c)
	c.global_position = shop.marker("ExitSpawn")
	return c


func _kid_look() -> Dictionary:
	var l: Dictionary = CharacterDresser.random_look(_rng)
	l["beard"] = "Beard_00"
	l["hat"] = true
	l["scale"] = 0.68
	l["kid"] = true
	return l


## Kimlik kartı üretir. Varyantlar: normal, hans (Almanya ehliyeti — geçerli), minor (çocuk — reddet),
## expired (süresi geçmiş — reddet), invalid (kimlik değil — reddet).
func make_card(p: CustomerProfile) -> Dictionary:
	var r: float = _rng.randf()
	var variant: String = "normal"
	if p.type == &"tourist" and _rng.randf() < HANS_CHANCE:
		variant = "hans"
	elif r < MINOR_CHANCE:
		variant = "minor"
	elif r < MINOR_CHANCE + EXPIRED_CHANCE:
		variant = "expired"
	elif r < MINOR_CHANCE + EXPIRED_CHANCE + INVALID_DOC_CHANCE:
		variant = "invalid"
	var name_: String = _random_name(p)
	var by: int = _rng.randi_range(1948, 2004)
	var card: Dictionary = {
		"variant": variant, "name": name_, "birth_day": _rng.randi_range(1, 28), "birth_month": _rng.randi_range(1, 12),
		"birth_year": by, "expiry_year": _rng.randi_range(_year_plus(1), _year_plus(9)),
		"doc_key": "IDCARD_DOC_YAYLA", "should_approve": true, "minor": false, "reason_key": "",
	}
	match variant:
		"hans":
			card["name"] = "Hans Müller"
			card["birth_year"] = 1968
			card["doc_key"] = "IDCARD_DOC_FUHRERSCHEIN"
			card["reason_key"] = "IDCARD_REASON_HANS"
		"minor":
			card["name"] = "Mehmet Bıyıklı"
			card["birth_year"] = 1978
			card["minor"] = true
			card["should_approve"] = false
			card["reason_key"] = "IDCARD_REASON_MINOR"
		"expired":
			card["expiry_year"] = _rng.randi_range(2009, 2024)
			card["should_approve"] = false
			card["reason_key"] = "IDCARD_REASON_EXPIRED"
		"invalid":
			card["doc_key"] = INVALID_DOCS[_rng.randi_range(0, INVALID_DOCS.size() - 1)]
			card["birth_year"] = 0
			card["should_approve"] = false
			card["reason_key"] = "IDCARD_REASON_INVALID"
	return card


static func _year_plus(n: int) -> int:
	return ShopCustomer.GAME_YEAR + n


func _random_name(p: CustomerProfile) -> String:
	match p.type:
		&"tourist":
			return TOURIST_NAMES[_rng.randi_range(0, TOURIST_NAMES.size() - 1)]
		&"expert":
			return EXPERT_NAMES[_rng.randi_range(0, EXPERT_NAMES.size() - 1)]
	return "%s %s" % [FIRST_NAMES[_rng.randi_range(0, FIRST_NAMES.size() - 1)], LAST_NAMES[_rng.randi_range(0, LAST_NAMES.size() - 1)]]
