class_name Genetics
extends RefCounted
## Çaprazlama: yavru özelliği = ebeveyn ortalaması ± sapma; %5 ihtimalle mutasyon (nadir özellik).
## Tasarım: GDD §5.2.

const DEVIATION: float = 8.0
const MUTATION_CHANCE: float = 0.05
## Nadir özellikler ve etkileri (StrainData/Growth tarafından okunur).
const RARE_TRAITS: Array[StringName] = [&"purple_leaf", &"giant", &"frost_proof", &"citrus", &"double_bud"]


## İki türü çaprazlar ve yeni bir StrainData döndürür (kaydetmez; SeedBook.register_custom ile kaydet).
static func cross(a: StrainData, b: StrainData, new_name: String, rng: RandomNumberGenerator = null) -> StrainData:
	var r: RandomNumberGenerator = rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var c: StrainData = StrainData.new()
	c.custom_name = new_name.strip_edges()
	c.yield_trait = _mix(a.yield_trait, b.yield_trait, r)
	c.speed = _mix(a.speed, b.speed, r)
	c.hardiness = _mix(a.hardiness, b.hardiness, r)
	c.aroma = _mix(a.aroma, b.aroma, r)
	c.quality_potential = _mix(a.quality_potential, b.quality_potential, r)
	# Görsel özellikler: renk karışımı + hafif sapma, boy ortalaması.
	c.leaf_tint = a.leaf_tint.lerp(b.leaf_tint, r.randf_range(0.3, 0.7))
	c.leaf_tint.h = fposmod(c.leaf_tint.h + r.randf_range(-0.03, 0.03), 1.0)
	c.height_scale = clampf((a.height_scale + b.height_scale) * 0.5 + r.randf_range(-0.08, 0.08), 0.6, 1.5)
	# İdeal aralıklar ortalaması.
	c.ideal_temp_min = (a.ideal_temp_min + b.ideal_temp_min) * 0.5
	c.ideal_temp_max = (a.ideal_temp_max + b.ideal_temp_max) * 0.5
	c.ideal_humidity_min = (a.ideal_humidity_min + b.ideal_humidity_min) * 0.5
	c.ideal_humidity_max = (a.ideal_humidity_max + b.ideal_humidity_max) * 0.5
	c.ideal_ph_min = (a.ideal_ph_min + b.ideal_ph_min) * 0.5
	c.ideal_ph_max = (a.ideal_ph_max + b.ideal_ph_max) * 0.5
	c.light_need = (a.light_need + b.light_need) * 0.5
	# Nadir özellikler ebeveynden %50 ihtimalle geçer.
	var traits: Array[StringName] = []
	for t: StringName in a.rare_traits + b.rare_traits:
		if not traits.has(t) and r.randf() < 0.5:
			traits.append(t)
	# Mutasyon: yeni nadir özellik + bir özellikte sıçrama.
	if r.randf() < MUTATION_CHANCE:
		var t2: StringName = RARE_TRAITS[r.randi_range(0, RARE_TRAITS.size() - 1)]
		if not traits.has(t2):
			traits.append(t2)
		c.quality_potential = clampf(c.quality_potential + 10.0, 0.0, 100.0)
	c.rare_traits = traits
	if traits.has(&"purple_leaf"):
		c.leaf_tint = c.leaf_tint.lerp(Color(0.5, 0.25, 0.6), 0.6)
	if traits.has(&"frost_proof"):
		c.ideal_temp_min -= 5.0
	if traits.has(&"citrus"):
		c.aroma = clampf(c.aroma + 10.0, 0.0, 100.0)
	c.generation = maxi(a.generation, b.generation) + 1
	c.parents = [a.id, b.id]
	# Fiyat: kalite potansiyeli ve nadirlik (uzman müşteriler mutasyonu sever).
	c.price_multiplier = snappedf((a.price_multiplier + b.price_multiplier) * 0.5 + 0.1 * traits.size(), 0.01)
	c.seed_price = int((a.seed_price + b.seed_price) / 2)
	return c


## Bir türün "değeri" (Tohum Defteri sıralaması için).
static func score(s: StrainData) -> float:
	return (s.yield_trait + s.speed + s.hardiness + s.aroma + s.quality_potential) / 5.0 + 5.0 * s.rare_traits.size()


static func _mix(x: float, y: float, r: RandomNumberGenerator) -> float:
	return clampf((x + y) * 0.5 + r.randf_range(-DEVIATION, DEVIATION), 0.0, 100.0)
