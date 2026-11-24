class_name PlantState
extends Resource
## Bir saksıdaki bitkinin anlık durumu. Simülasyon: Growth.step().

enum Stage { GERM, SEEDLING, VEG, FLOWER, READY }

## Aşama eşikleri (toplam büyüme ilerlemesi 0..1 içinde). GDD §5.1 oranlarına yakın.
const STAGE_THRESHOLDS: Array[float] = [0.0, 0.15, 0.35, 0.65, 1.0]
const STAGE_KEYS: Array[String] = [
	"PLANT_STAGE_GERM", "PLANT_STAGE_SEEDLING", "PLANT_STAGE_VEG", "PLANT_STAGE_FLOWER", "PLANT_STAGE_READY",
]

@export var strain_id: StringName = &""
@export var stage: int = Stage.GERM
## Toplam büyüme ilerlemesi 0..1 (1 = hasada hazır).
@export var growth: float = 0.0
@export var water: float = 0.6
## Son simülasyon adımındaki ışık seviyesi 0..1.
@export var light: float = 0.0
@export var nutrients: float = 0.5
@export var ph: float = 6.3
## Son adımdaki sıcaklık (°C) ve nem (0..1).
@export var temperature: float = 20.0
@export var humidity: float = 0.6
@export var health: float = 1.0
## Kalite 0..100 (ideal aralıkta geçen süreye göre).
@export var quality: float = 50.0
## Zararlı: &"" yok, &"aphid" yaprak biti, &"mold" küf.
@export var pest: StringName = &""
@export var pest_level: float = 0.0
@export var dead: bool = false
@export var pruned: bool = false
## Toplam yaş (oyun dakikası) ve hasada hazır olduktan sonra geçen süre.
@export var age_minutes: int = 0
@export var ripe_minutes: int = 0
## Kalite ortalaması için ideal-uyum toplamı ve örnek sayısı.
@export var ideal_sum: float = 0.0
@export var ideal_samples: int = 0
## Hava hasarı / bonuslar için mevsim notları.
@export var autumn_minutes: int = 0


func is_empty() -> bool:
	return strain_id == &""


func is_ready() -> bool:
	return not dead and stage == Stage.READY


## Erken de olsa hasat edilebilir mi? (Çiçeklenme sonu)
func can_harvest() -> bool:
	return not dead and (stage == Stage.READY or (stage == Stage.FLOWER and growth >= 0.85))


func get_stage_name() -> String:
	if dead:
		return TranslationServer.translate("PLANT_STAGE_DEAD")
	return TranslationServer.translate(STAGE_KEYS[clampi(stage, 0, STAGE_KEYS.size() - 1)])


## Görsel için susuzluk 0..1 (1 = çok susuz).
func get_thirst() -> float:
	return clampf(1.0 - water / 0.5, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {
		"strain": String(strain_id), "stage": stage, "growth": growth, "water": water, "light": light,
		"nutrients": nutrients, "ph": ph, "temp": temperature, "hum": humidity, "health": health,
		"quality": quality, "pest": String(pest), "pest_level": pest_level, "dead": dead,
		"pruned": pruned, "age": age_minutes, "ripe": ripe_minutes, "isum": ideal_sum,
		"isamp": ideal_samples, "autumn": autumn_minutes,
	}


static func from_dict(d: Dictionary) -> PlantState:
	var s: PlantState = PlantState.new()
	s.strain_id = StringName(String(d.get("strain", "")))
	s.stage = int(d.get("stage", 0))
	s.growth = float(d.get("growth", 0.0))
	s.water = float(d.get("water", 0.6))
	s.light = float(d.get("light", 0.0))
	s.nutrients = float(d.get("nutrients", 0.5))
	s.ph = float(d.get("ph", 6.3))
	s.temperature = float(d.get("temp", 20.0))
	s.humidity = float(d.get("hum", 0.6))
	s.health = float(d.get("health", 1.0))
	s.quality = float(d.get("quality", 50.0))
	s.pest = StringName(String(d.get("pest", "")))
	s.pest_level = float(d.get("pest_level", 0.0))
	s.dead = bool(d.get("dead", false))
	s.pruned = bool(d.get("pruned", false))
	s.age_minutes = int(d.get("age", 0))
	s.ripe_minutes = int(d.get("ripe", 0))
	s.ideal_sum = float(d.get("isum", 0.0))
	s.ideal_samples = int(d.get("isamp", 0))
	s.autumn_minutes = int(d.get("autumn", 0))
	return s
