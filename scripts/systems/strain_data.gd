class_name StrainData
extends Resource
## Bir kenevir türünün genetik özellikleri ve ideal yetiştirme aralıkları.
## Temel türler: data/strains/*.tres. Çaprazlanan türler SeedBook içinde saklanır.

@export var id: StringName = &""
## Görünen ad için çeviri anahtarı (özel türlerde boş, custom_name kullanılır).
@export var name_key: String = ""
## Oyuncunun verdiği isim (çaprazlanmış türler).
@export var custom_name: String = ""
@export var description_key: String = ""

@export_group("Genetik (0..100)")
## Verim: hasat gramajını belirler.
@export_range(0, 100) var yield_trait: float = 50.0
## Hız: toplam büyüme süresini kısaltır.
@export_range(0, 100) var speed: float = 50.0
## Dayanıklılık: stres, zararlı ve hava hasarına direnç.
@export_range(0, 100) var hardiness: float = 50.0
## Aroma: tıbbi/uzman müşteri tercihi.
@export_range(0, 100) var aroma: float = 50.0
## Kalite potansiyeli: ulaşılabilecek en yüksek kalite.
@export_range(0, 100) var quality_potential: float = 60.0

@export_group("Görsel")
@export var leaf_tint: Color = Color(0.35, 0.65, 0.3)
@export_range(0.5, 1.6) var height_scale: float = 1.0

@export_group("İdeal aralıklar")
@export var ideal_temp_min: float = 19.0
@export var ideal_temp_max: float = 28.0
@export var ideal_humidity_min: float = 0.4
@export var ideal_humidity_max: float = 0.7
@export var ideal_ph_min: float = 5.8
@export var ideal_ph_max: float = 6.8
@export var ideal_water_min: float = 0.3
@export var ideal_water_max: float = 0.9
@export var ideal_nutrient_min: float = 0.3
@export var ideal_nutrient_max: float = 0.9
## Gündüz saatlerinde gereken ışık seviyesi (0..1).
@export var light_need: float = 0.45

@export_group("Ekonomi")
@export var seed_price: int = 60
@export var price_multiplier: float = 1.0
## Nadir özellikler (mutasyon): &"purple_leaf", &"giant", &"frost_proof", &"citrus", &"double_bud"
@export var rare_traits: Array[StringName] = []
@export var generation: int = 0
@export var parents: Array[StringName] = []


## Görünen ad.
func get_display_name() -> String:
	if custom_name != "":
		return custom_name
	if name_key != "":
		return TranslationServer.translate(name_key)
	return String(id)


## Hıza göre toplam büyüme süresi (oyun günü): hız 0 → 7 gün, hız 100 → 4 gün.
func get_growth_days() -> float:
	return lerpf(7.0, 4.0, speed / 100.0)


## Tam sağlıkta, zamanında hasatta beklenen ıslak gram.
func get_base_yield_grams() -> float:
	var g: float = 40.0 + yield_trait * 0.8
	if rare_traits.has(&"giant"):
		g *= 1.3
	if rare_traits.has(&"double_bud"):
		g *= 1.2
	return g


func has_rare_trait(t: StringName) -> bool:
	return rare_traits.has(t)


## Kayıt için düz sözlük.
func to_dict() -> Dictionary:
	var traits: Array[String] = []
	for t: StringName in rare_traits:
		traits.append(String(t))
	var par: Array[String] = []
	for p: StringName in parents:
		par.append(String(p))
	return {
		"id": String(id), "name_key": name_key, "custom_name": custom_name,
		"yield": yield_trait, "speed": speed, "hardiness": hardiness, "aroma": aroma,
		"quality_potential": quality_potential, "leaf_tint": leaf_tint.to_html(),
		"height_scale": height_scale,
		"t_min": ideal_temp_min, "t_max": ideal_temp_max,
		"h_min": ideal_humidity_min, "h_max": ideal_humidity_max,
		"ph_min": ideal_ph_min, "ph_max": ideal_ph_max,
		"w_min": ideal_water_min, "w_max": ideal_water_max,
		"n_min": ideal_nutrient_min, "n_max": ideal_nutrient_max,
		"light_need": light_need, "seed_price": seed_price, "price_mult": price_multiplier,
		"rare": traits, "gen": generation, "parents": par,
	}


static func from_dict(d: Dictionary) -> StrainData:
	var s: StrainData = StrainData.new()
	s.id = StringName(String(d.get("id", "")))
	s.name_key = String(d.get("name_key", ""))
	s.custom_name = String(d.get("custom_name", ""))
	s.yield_trait = float(d.get("yield", 50.0))
	s.speed = float(d.get("speed", 50.0))
	s.hardiness = float(d.get("hardiness", 50.0))
	s.aroma = float(d.get("aroma", 50.0))
	s.quality_potential = float(d.get("quality_potential", 60.0))
	s.leaf_tint = Color.html(String(d.get("leaf_tint", "5aa64dff")))
	s.height_scale = float(d.get("height_scale", 1.0))
	s.ideal_temp_min = float(d.get("t_min", 19.0))
	s.ideal_temp_max = float(d.get("t_max", 28.0))
	s.ideal_humidity_min = float(d.get("h_min", 0.4))
	s.ideal_humidity_max = float(d.get("h_max", 0.7))
	s.ideal_ph_min = float(d.get("ph_min", 5.8))
	s.ideal_ph_max = float(d.get("ph_max", 6.8))
	s.ideal_water_min = float(d.get("w_min", 0.3))
	s.ideal_water_max = float(d.get("w_max", 0.9))
	s.ideal_nutrient_min = float(d.get("n_min", 0.3))
	s.ideal_nutrient_max = float(d.get("n_max", 0.9))
	s.light_need = float(d.get("light_need", 0.45))
	s.seed_price = int(d.get("seed_price", 60))
	s.price_multiplier = float(d.get("price_mult", 1.0))
	s.generation = int(d.get("gen", 0))
	var traits: Array[StringName] = []
	for t: Variant in d.get("rare", []):
		traits.append(StringName(String(t)))
	s.rare_traits = traits
	var par: Array[StringName] = []
	for p: Variant in d.get("parents", []):
		par.append(StringName(String(p)))
	s.parents = par
	return s
