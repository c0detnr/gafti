extends Node
## Oyun saati: dakika/saat/gün, gün fazları, mevsimler, bayılma ve demo sınırı.
## Sözleşme: AGENTS.md §4 (GameClock). Oyun günü 06:00'da başlar; 00:00-05:59 hâlâ aynı güne aittir.

signal minute_passed(total_minutes: int)
signal hour_passed(hour: int)
signal phase_changed(phase: StringName)   # &"morning", &"noon", &"evening", &"night"
signal day_started(day: int)
signal season_changed(season: StringName) # &"spring", &"summer", &"autumn", &"winter"
signal fainted()                          # 02:00'da uyumayan oyuncu bayıldı (ek sinyal)

const MINUTES_PER_DAY: int = 1440
const DAY_START_HOUR: int = 6
const FAINT_HOUR: int = 2
const FAINT_WAKE_HOUR: int = 9
const DAYS_PER_SEASON: int = 7
const SEASONS: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]

var day: int = 1
var hour: int = DAY_START_HOUR
var minute: int = 0
var season: StringName = &"spring"
var paused: bool = false
var time_scale: float = 1.0
## Oyun başından beri geçen toplam oyun dakikası.
var total_minutes: int = 0
## Şu anki faz (phase_changed yalnız değişince yayılır).
var phase: StringName = &"morning"

var _accum: float = 0.0
var _demo_blocked: bool = false
var _advancing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	phase = _phase_for_hour(hour)


func _process(delta: float) -> void:
	if paused or _demo_blocked:
		return
	_accum += delta * time_scale
	var spm: float = get_seconds_per_game_minute()
	# Çok büyük bir delta gelirse (takılma) tek karede en fazla 120 dakika işle.
	var guard: int = 0
	while _accum >= spm and guard < 120:
		_accum -= spm
		guard += 1
		_tick_minute()
		if _demo_blocked:
			_accum = 0.0
			break


## Gerçek saniye cinsinden bir oyun dakikasının süresi (Settings.day_length_minutes'e göre).
func get_seconds_per_game_minute() -> float:
	var day_len: float = 14.0
	var settings: Node = get_node_or_null("/root/Settings")
	if settings != null:
		day_len = float(settings.get("day_length_minutes"))
	return maxf(day_len, 0.1) * 60.0 / float(MINUTES_PER_DAY)


func get_time_string() -> String:
	return "%02d:%02d" % [hour, minute]


## 0..1, 0 = gece yarısı.
func get_day_fraction() -> float:
	return float(hour * 60 + minute) / float(MINUTES_PER_DAY)


## Oyun gününün başından (06:00) bu yana geçen dakika.
func get_minutes_since_day_start() -> int:
	var m: int = hour * 60 + minute - DAY_START_HOUR * 60
	if m < 0:
		m += MINUTES_PER_DAY
	return m


## Yatakta uyuma serbest mi? (20:00 - 06:00 arası)
func is_sleep_allowed() -> bool:
	return hour >= 20 or hour < DAY_START_HOUR


## Bir sonraki 06:00'ya kadar zamanı ilerletir (tüm dakikalar simüle edilir).
func sleep_until_morning() -> void:
	_advance_to_hour(DAY_START_HOUR)


func advance_minutes(m: int) -> void:
	if m <= 0:
		return
	_advancing = true
	for i: int in range(m):
		_tick_minute()
		if _demo_blocked:
			break
	_advancing = false


## Mevsim indeksi 0..3.
func get_season_index() -> int:
	return SEASONS.find(season)


func get_day_in_season() -> int:
	return ((day - 1) % DAYS_PER_SEASON) + 1


func get_year() -> int:
	return ((day - 1) / (DAYS_PER_SEASON * SEASONS.size())) + 1


func is_daytime() -> bool:
	return hour >= 6 and hour < 20


func season_for_day(d: int) -> StringName:
	var idx: int = ((d - 1) / DAYS_PER_SEASON) % SEASONS.size()
	return SEASONS[idx]


func get_phase() -> StringName:
	return phase


# ---------------------------------------------------------------------------
# İç mantık
# ---------------------------------------------------------------------------

func _advance_to_hour(target_hour: int) -> void:
	var now: int = hour * 60 + minute
	var target: int = target_hour * 60
	var diff: int = target - now
	if diff <= 0:
		diff += MINUTES_PER_DAY
	advance_minutes(diff)


func _tick_minute() -> void:
	# Demo: 7. günün sonundan (ertesi 06:00) öteye geçilmez.
	if _is_demo() and day >= _demo_limit() and hour == DAY_START_HOUR - 1 and minute == 59:
		if not _demo_blocked:
			_demo_blocked = true
			EventBus.notify.emit(tr("CLOCK_DEMO_END"), &"info")
		return
	minute += 1
	total_minutes += 1
	var hour_changed: bool = false
	if minute >= 60:
		minute = 0
		hour = (hour + 1) % 24
		hour_changed = true
	minute_passed.emit(total_minutes)
	if hour_changed:
		hour_passed.emit(hour)
		_update_phase()
		if hour == DAY_START_HOUR:
			_start_new_day()
		elif hour == FAINT_HOUR and not _advancing:
			# Uyku/hızlı ilerletme sırasında bayılma olmaz.
			_faint()


func _start_new_day() -> void:
	day += 1
	var new_season: StringName = season_for_day(day)
	day_started.emit(day)
	if new_season != season:
		season = new_season
		season_changed.emit(season)
		EventBus.notify.emit(tr("CLOCK_SEASON_" + String(season).to_upper()), &"info")
	if _is_demo() and day >= _demo_limit():
		EventBus.notify.emit(tr("CLOCK_DEMO_LAST_DAY"), &"info")


func _update_phase() -> void:
	var p: StringName = _phase_for_hour(hour)
	if p != phase:
		phase = p
		phase_changed.emit(phase)


func _phase_for_hour(h: int) -> StringName:
	if h >= 6 and h < 11:
		return &"morning"
	if h >= 11 and h < 16:
		return &"noon"
	if h >= 16 and h < 22:
		return &"evening"
	return &"night"


## 02:00'da hâlâ ayaktaysa: %10 para cezası, 09:00'da uyanır.
func _faint() -> void:
	var economy: Node = get_node_or_null("/root/Economy")
	var fine: int = 0
	if economy != null and economy.has_method("apply_faint_penalty"):
		fine = economy.apply_faint_penalty()
	EventBus.notify.emit(tr("CLOCK_FAINTED") % fine, &"bad")
	fainted.emit()
	# Bayılma sırasında zaman 09:00'a atlar (sinyaller içinde güvenli olsun diye ertele).
	_skip_to_faint_wake.call_deferred()


func _skip_to_faint_wake() -> void:
	if hour == FAINT_HOUR or (hour > FAINT_HOUR and hour < FAINT_WAKE_HOUR):
		_advance_to_hour(FAINT_WAKE_HOUR)


func _is_demo() -> bool:
	var flags: Node = get_node_or_null("/root/ContentFlags")
	return flags != null and bool(flags.get("is_demo"))


func _demo_limit() -> int:
	var flags: Node = get_node_or_null("/root/ContentFlags")
	if flags != null and flags.get("DEMO_DAY_LIMIT") != null:
		return int(flags.get("DEMO_DAY_LIMIT"))
	return 7


# ---------------------------------------------------------------------------
# Kayıt
# ---------------------------------------------------------------------------

func reset() -> void:
	day = 1
	hour = DAY_START_HOUR
	minute = 0
	season = &"spring"
	total_minutes = 0
	paused = false
	time_scale = 1.0
	_accum = 0.0
	_demo_blocked = false
	phase = _phase_for_hour(hour)
	phase_changed.emit(phase)
	day_started.emit(day)


func get_save_data() -> Dictionary:
	return {
		"day": day, "hour": hour, "minute": minute,
		"season": String(season), "total_minutes": total_minutes,
	}


func load_save_data(d: Dictionary) -> void:
	if d.is_empty():
		reset()
		return
	day = int(d.get("day", 1))
	hour = int(d.get("hour", DAY_START_HOUR))
	minute = int(d.get("minute", 0))
	total_minutes = int(d.get("total_minutes", 0))
	season = StringName(String(d.get("season", "spring")))
	_accum = 0.0
	_demo_blocked = false
	phase = _phase_for_hour(hour)
	phase_changed.emit(phase)
	season_changed.emit(season)
