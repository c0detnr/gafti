class_name Growth
extends RefCounted
## Bitki simülasyonu: oyun dakikası başına bir adım.
## Girdi ortamı (env) Dictionary:
##   light: float 0..1, temperature: float °C, humidity: float 0..1, daytime: bool,
##   outdoor: bool, raining: bool, storm: bool, sunny: bool, season: StringName
## Tasarım: GDD §5.1 (aşamalar, değişkenler, kalite, zararlılar), §3.3 (mevsim/hava).

## Bir adımda üretilebilecek olaylar.
const EV_NONE: StringName = &""
const EV_STAGE_UP: StringName = &"stage_up"
const EV_READY: StringName = &"ready"
const EV_DIED: StringName = &"died"
const EV_PEST: StringName = &"pest"

const DT: float = 1.0 / 60.0 # bir dakika = 1/60 saat
## Saatlik baz su tüketimi (1.0 dolu saksı ~1 gün dayanır).
const WATER_USE_PER_HOUR: float = 0.032
const NUTRIENT_USE_PER_HOUR: float = 0.012
## Hasada hazır olduktan sonra kalite düşmeye başlamadan önceki tolerans (dakika).
const RIPE_GRACE_MINUTES: int = 1440


## Tek bir oyun dakikası simüle eder. Gerçekleşen en önemli olayı döndürür.
static func step(s: PlantState, strain: StrainData, env: Dictionary, rng: RandomNumberGenerator) -> StringName:
	if s.dead or s.is_empty() or strain == null:
		return EV_NONE
	var event: StringName = EV_NONE
	s.age_minutes += 1
	var outdoor: bool = bool(env.get("outdoor", false))
	var season: StringName = StringName(env.get("season", &"spring"))
	s.light = float(env.get("light", 0.0))
	s.temperature = float(env.get("temperature", 20.0))
	s.humidity = float(env.get("humidity", 0.6))
	var hardy: float = strain.hardiness / 100.0

	# --- Kaynak tüketimi -----------------------------------------------------
	var use: float = WATER_USE_PER_HOUR * (1.0 + 0.15 * float(mini(s.stage, 3)))
	if bool(env.get("sunny", false)):
		use *= 1.3 if outdoor else 1.15
	if s.temperature > strain.ideal_temp_max:
		use *= 1.3
	s.water = maxf(0.0, s.water - use * DT)
	if outdoor and bool(env.get("raining", false)):
		s.water = minf(1.0, s.water + 0.4 * DT) # yağmur dış tarlayı sular
	var n_use: float = NUTRIENT_USE_PER_HOUR * (0.5 if s.stage < PlantState.Stage.VEG else 1.5)
	s.nutrients = maxf(0.0, s.nutrients - n_use * DT)
	# pH yavaşça 7.0'a doğru kayar (sert su); besleme düzeltir.
	s.ph += (7.0 - s.ph) * 0.004 * DT

	# --- İdeal aralık skoru ---------------------------------------------------
	var score: float = get_ideal_score(s, strain, env)

	# --- Zararlılar -----------------------------------------------------------
	if s.pest == &"":
		var aphid_p: float = 0.00015 * (1.0 - hardy * 0.6)
		var mold_p: float = 0.0
		if s.humidity > 0.78:
			mold_p = 0.0004 * (1.0 - hardy * 0.5)
		var roll: float = rng.randf()
		if roll < mold_p:
			s.pest = &"mold"
			s.pest_level = 0.05
			event = EV_PEST
		elif roll < mold_p + aphid_p and s.stage >= PlantState.Stage.SEEDLING:
			s.pest = &"aphid"
			s.pest_level = 0.05
			event = EV_PEST
	else:
		s.pest_level = minf(1.0, s.pest_level + 0.03 * DT)

	# --- Sağlık ---------------------------------------------------------------
	var dmg: float = 0.0
	if score < 0.5:
		dmg += (0.5 - score) * 0.09 * (1.0 - hardy * 0.4)
	if s.water <= 0.02:
		dmg += 0.06 # kuruma
	elif s.water > 0.98:
		dmg += 0.01 # aşırı sulama / kök çürümesi
	if s.temperature < 2.0 and not strain.has_rare_trait(&"frost_proof"):
		dmg += 0.12 # don
	if outdoor and bool(env.get("storm", false)):
		dmg += 0.025 * (1.0 - hardy * 0.6)
	if s.pest != &"":
		dmg += s.pest_level * 0.03
	s.health -= dmg * DT
	if dmg <= 0.0001 and score > 0.7:
		s.health += 0.02 * DT
	s.health = clampf(s.health, 0.0, 1.0)
	if s.health <= 0.0:
		s.dead = true
		return EV_DIED

	# --- Büyüme ---------------------------------------------------------------
	if s.stage < PlantState.Stage.READY:
		var rate: float = 1.0 / (strain.get_growth_days() * 1440.0)
		rate *= (0.35 + 0.65 * score) * (0.5 + 0.5 * s.health)
		if season == &"spring" and s.stage == PlantState.Stage.GERM:
			rate *= 1.15 # ilkbahar çimlenme bonusu
		if outdoor and season == &"summer":
			rate *= 1.1 # yaz: dış tarla en verimli
		if s.pruned and s.stage >= PlantState.Stage.VEG:
			rate *= 1.05
		s.growth = minf(1.0, s.growth + rate)
		s.ideal_sum += score
		s.ideal_samples += 1
		var new_stage: int = stage_for_growth(s.growth)
		if new_stage != s.stage:
			s.stage = new_stage
			event = EV_READY if new_stage == PlantState.Stage.READY else EV_STAGE_UP
	else:
		s.ripe_minutes += 1
	s.quality = compute_quality(s, strain)
	return event


## 0..1: değişkenlerin türün ideal aralığına uyumu.
static func get_ideal_score(s: PlantState, strain: StrainData, env: Dictionary) -> float:
	var w: float = range_score(s.water, strain.ideal_water_min, strain.ideal_water_max, 0.25)
	var t: float = range_score(s.temperature, strain.ideal_temp_min, strain.ideal_temp_max, 7.0)
	var h: float = range_score(s.humidity, strain.ideal_humidity_min, strain.ideal_humidity_max, 0.25)
	var n: float = 1.0
	var p: float = 1.0
	if s.stage >= PlantState.Stage.SEEDLING:
		n = range_score(s.nutrients, strain.ideal_nutrient_min, strain.ideal_nutrient_max, 0.25)
		p = range_score(s.ph, strain.ideal_ph_min, strain.ideal_ph_max, 0.8)
	var l: float = 1.0
	if bool(env.get("daytime", true)):
		var need: float = strain.light_need * (0.6 if s.stage <= PlantState.Stage.SEEDLING else 1.0)
		l = clampf(s.light / maxf(need, 0.01), 0.0, 1.0)
	# Ağırlıklı ortalama: su ve ışık en önemli.
	return (w * 2.0 + l * 1.5 + t + h * 0.75 + n + p * 0.75) / 7.0


## Aralık içinde 1, dışında "soft" mesafede 0'a iner.
static func range_score(v: float, lo: float, hi: float, soft: float) -> float:
	if v >= lo and v <= hi:
		return 1.0
	var d: float = lo - v if v < lo else v - hi
	return clampf(1.0 - d / soft, 0.0, 1.0)


static func stage_for_growth(g: float) -> int:
	var st: int = 0
	for i: int in range(PlantState.STAGE_THRESHOLDS.size()):
		if g >= PlantState.STAGE_THRESHOLDS[i]:
			st = i
	return st


static func compute_quality(s: PlantState, strain: StrainData) -> float:
	var avg: float = s.ideal_sum / float(s.ideal_samples) if s.ideal_samples > 0 else 0.5
	var q: float = strain.quality_potential * (0.25 + 0.75 * avg) * (0.7 + 0.3 * s.health)
	var over: int = maxi(0, s.ripe_minutes - RIPE_GRACE_MINUTES)
	q -= float(over) / 60.0 * 0.5 # geç hasat: saatte -0.5
	return clampf(q, 0.0, 100.0)


## Hasat: ıslak tomurcuk eşyası döndürür (hasat edilemiyorsa boş sözlük).
## Erken hasat = az verim; geç hasat = düşük kalite (compute_quality içinde).
static func harvest(s: PlantState, strain: StrainData, season: StringName) -> Dictionary:
	if not s.can_harvest() or strain == null:
		return {}
	var grams: float = strain.get_base_yield_grams() * (0.4 + 0.6 * s.health)
	if s.stage < PlantState.Stage.READY:
		grams *= lerpf(0.55, 0.9, clampf((s.growth - 0.85) / 0.15, 0.0, 1.0))
	if s.pruned:
		grams *= 1.1
	var q: float = s.quality
	if season == &"autumn":
		q += 8.0 # sonbahar hasat bonusu
	q = minf(q, strain.quality_potential + 10.0)
	var count: int = maxi(1, int(round(grams)))
	return Inventory.make_item(&"wet_bud", s.strain_id, int(round(q)), count, 1.0)
