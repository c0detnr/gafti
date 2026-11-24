extends Node
## Günlük hava durumu, ertesi gün tahmini, elektrik kesintisi ve ortam değerleri.
## Sözleşme: AGENTS.md §4 (Weather). Tablolar: GDD §3.3.

signal weather_changed(weather: StringName)  # &"sunny", &"cloudy", &"foggy", &"rainy", &"storm", &"snow"
signal power_changed(out: bool)              # ek sinyal: kesinti başladı/bitti

const ALL: Array[StringName] = [&"sunny", &"cloudy", &"foggy", &"rainy", &"storm", &"snow"]

## Mevsime göre hava olasılık ağırlıkları.
const SEASON_WEIGHTS: Dictionary = {
	&"spring": {&"sunny": 25, &"cloudy": 20, &"foggy": 20, &"rainy": 30, &"storm": 5},
	&"summer": {&"sunny": 50, &"cloudy": 20, &"foggy": 10, &"rainy": 12, &"storm": 8},
	&"autumn": {&"sunny": 20, &"cloudy": 25, &"foggy": 20, &"rainy": 20, &"storm": 15},
	&"winter": {&"sunny": 15, &"cloudy": 25, &"foggy": 15, &"snow": 35, &"storm": 10},
}

## Havaya göre müşteri çarpanı.
const CUSTOMER_MULT: Dictionary = {
	&"sunny": 1.1, &"cloudy": 1.0, &"foggy": 0.9, &"rainy": 0.8, &"storm": 0.5, &"snow": 0.7,
}

## Mevsime göre müşteri çarpanı (yaz turist ×2 etkisi, kış az müşteri).
const SEASON_CUSTOMER_MULT: Dictionary = {
	&"spring": 1.0, &"summer": 1.5, &"autumn": 0.9, &"winter": 0.7,
}

## Havaya göre güneş ışığı oranı.
const SUN_FACTOR: Dictionary = {
	&"sunny": 1.0, &"cloudy": 0.6, &"foggy": 0.45, &"rainy": 0.4, &"storm": 0.25, &"snow": 0.5,
}

## Mevsim ortalama dış sıcaklığı (°C).
const SEASON_TEMP: Dictionary = {
	&"spring": 15.0, &"summer": 24.0, &"autumn": 13.0, &"winter": 1.0,
}

var current: StringName = &"foggy"
var tomorrow: StringName = &"rainy"

## Kesinti penceresi (oyun dakikası, gün içi 0..1439). -1 = yok.
var _outage_start: int = -1
var _outage_end: int = -1
var _power_out_cache: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	GameClock.day_started.connect(_on_day_started)
	GameClock.minute_passed.connect(_on_minute_passed)


func _on_day_started(_day: int) -> void:
	set_weather(tomorrow)
	tomorrow = roll_weather(GameClock.season_for_day(GameClock.day + 1))


## Havayı değiştirir ve gerekirse kesinti penceresi belirler.
func set_weather(w: StringName) -> void:
	current = w
	_outage_start = -1
	_outage_end = -1
	if current == &"storm" and _rng.randf() < 0.7:
		# Fırtınada 08:00-20:00 arası bir saatte 3-6 saatlik kesinti.
		var start_h: int = _rng.randi_range(8, 20)
		_outage_start = start_h * 60
		_outage_end = _outage_start + _rng.randi_range(3, 6) * 60
	weather_changed.emit(current)
	_update_power()


func roll_weather(for_season: StringName) -> StringName:
	var table: Dictionary = SEASON_WEIGHTS.get(for_season, SEASON_WEIGHTS[&"spring"])
	var total: int = 0
	for k: StringName in table:
		total += int(table[k])
	var r: int = _rng.randi_range(1, total)
	for k: StringName in table:
		r -= int(table[k])
		if r <= 0:
			return k
	return &"cloudy"


func get_customer_multiplier() -> float:
	var w: float = float(CUSTOMER_MULT.get(current, 1.0))
	var s: float = float(SEASON_CUSTOMER_MULT.get(GameClock.season, 1.0))
	return w * s


## Kışın fiyatlar yüksek (GDD §3.3). Dükkan fiyat hesabında kullanılabilir.
func get_price_multiplier() -> float:
	return 1.25 if GameClock.season == &"winter" else 1.0


## Elektrik kesik mi? Sahnede "generator" grubunda bir jeneratör varsa kesinti hissedilmez.
func is_power_out() -> bool:
	return is_grid_down() and not has_generator()


## Şebeke kesintisi (jeneratörden bağımsız).
func is_grid_down() -> bool:
	if _outage_start < 0:
		return false
	var now: int = GameClock.hour * 60 + GameClock.minute
	return now >= _outage_start and now < _outage_end


func has_generator() -> bool:
	return get_tree() != null and get_tree().get_nodes_in_group(&"generator").size() > 0


func is_raining() -> bool:
	return current == &"rainy" or current == &"storm"


## Güneş ışığı 0..1 (saat ve havaya göre). 06-20 arası sinüs eğrisi.
func get_sun_light() -> float:
	var t: float = float(GameClock.hour) + float(GameClock.minute) / 60.0
	if t < 6.0 or t > 20.0:
		return 0.0
	var curve: float = sin((t - 6.0) / 14.0 * PI)
	return clampf(curve, 0.0, 1.0) * float(SUN_FACTOR.get(current, 0.6))


## Dış sıcaklık (°C): mevsim ortalaması + gündüz/gece salınımı + hava etkisi.
func get_outdoor_temperature() -> float:
	var base: float = float(SEASON_TEMP.get(GameClock.season, 15.0))
	var t: float = float(GameClock.hour) + float(GameClock.minute) / 60.0
	# En sıcak 15:00, en soğuk 03:00.
	var swing: float = cos((t - 15.0) / 24.0 * TAU) * 5.0
	var w: float = 0.0
	match current:
		&"sunny": w = 2.0
		&"rainy": w = -2.0
		&"storm": w = -3.0
		&"snow": w = -4.0
		&"foggy": w = -1.0
	return base + swing + w


## Dış nem 0..1.
func get_outdoor_humidity() -> float:
	match current:
		&"sunny": return 0.45
		&"cloudy": return 0.6
		&"foggy": return 0.85
		&"rainy": return 0.9
		&"storm": return 0.9
		&"snow": return 0.7
	return 0.6


func get_weather_name(w: StringName = &"") -> String:
	var key: StringName = current if w == &"" else w
	return tr("WEATHER_" + String(key).to_upper())


func get_forecast_text() -> String:
	return tr("WEATHER_FORECAST") % get_weather_name(tomorrow)


func _on_minute_passed(_total: int) -> void:
	_update_power()


func _update_power() -> void:
	var out: bool = is_power_out()
	if out != _power_out_cache:
		_power_out_cache = out
		power_changed.emit(out)
		if out:
			EventBus.notify.emit(tr("WEATHER_POWER_OUT"), &"bad")
		else:
			EventBus.notify.emit(tr("WEATHER_POWER_BACK"), &"good")


# ---------------------------------------------------------------------------
# Kayıt
# ---------------------------------------------------------------------------

func reset() -> void:
	tomorrow = roll_weather(&"spring")
	set_weather(&"foggy") # İlk sabah: atmosferik sis.


func get_save_data() -> Dictionary:
	return {
		"current": String(current), "tomorrow": String(tomorrow),
		"outage_start": _outage_start, "outage_end": _outage_end,
	}


func load_save_data(d: Dictionary) -> void:
	if d.is_empty():
		reset()
		return
	current = StringName(String(d.get("current", "cloudy")))
	tomorrow = StringName(String(d.get("tomorrow", "cloudy")))
	_outage_start = int(d.get("outage_start", -1))
	_outage_end = int(d.get("outage_end", -1))
	weather_changed.emit(current)
	_update_power()
