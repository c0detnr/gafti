extends Node
## Ses yöneticisi (Ajan C). Sözleşme: AGENTS.md §4.
## Dosya yolları: res://assets/audio/{sfx,music,ambience}/<id>.ogg (yoksa .wav/.mp3; yoksa sessizce geçer).
## Müzik/ambiyans iki oynatıcı arasında crossfade yapar. Hava/saat değişince ambiyans ve müzik otomatik seçilir.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const AMBIENCE_DIR: String = "res://assets/audio/ambience/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
const POOL_2D: int = 8
const POOL_3D: int = 12
const FADE_TIME: float = 2.0
const SILENT_DB: float = -60.0

## Effects (Ajan B) bunu görünce müziğe ayrıca filtre uygulamaz; Gaftî müzik filtresi burada.
var handles_gafti_music: bool = true
var auto_ambience: bool = true
var auto_music: bool = false

var _cache: Dictionary = {} # yol anahtarı -> AudioStream ya da null
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _music: Array[AudioStreamPlayer] = []
var _amb: Array[AudioStreamPlayer] = []
var _music_idx: int = 0
var _amb_idx: int = 0
var _music_id: StringName = &""
var _amb_id: StringName = &""
var _music_tween: Tween = null
var _amb_tween: Tween = null
var _gafti: bool = false
var _storm: bool = false
var _lowpass: AudioEffectLowPassFilter = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = _bus(&"SFX")
		add_child(p)
		_pool_2d.append(p)
	for i: int in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = _bus(&"SFX")
		p3.unit_size = 6.0
		p3.max_distance = 40.0
		add_child(p3)
		_pool_3d.append(p3)
	for i: int in 2:
		var m := AudioStreamPlayer.new()
		m.bus = _bus(&"Music")
		m.volume_db = SILENT_DB
		m.finished.connect(_on_loop_finished.bind(m))
		add_child(m)
		_music.append(m)
		var a := AudioStreamPlayer.new()
		a.bus = _bus(&"Ambience")
		a.volume_db = SILENT_DB
		a.finished.connect(_on_loop_finished.bind(a))
		add_child(a)
		_amb.append(a)
	_setup_music_filter()
	# Diğer autoload'lar hazır olsun diye bağlantıları bir kare sonra yap.
	_connect_systems.call_deferred()


# --- Genel API (AGENTS §4) -------------------------------------------------

## Efekt sesi çalar. pos Vector3 ise 3B konumda, değilse 2B.
## id dosyası yoksa id_1..id_4 varyantlarından rastgele biri denenir.
func play_sfx(id: StringName, pos: Variant = null) -> void:
	var stream: AudioStream = _find_sfx(id)
	if stream == null:
		return
	if pos is Vector3:
		var p3: AudioStreamPlayer3D = _free_3d()
		p3.stream = stream
		p3.global_position = pos as Vector3
		p3.pitch_scale = randf_range(0.94, 1.06)
		p3.play()
	else:
		var p: AudioStreamPlayer = _free_2d()
		p.stream = stream
		p.pitch_scale = randf_range(0.96, 1.04)
		p.play()


## Müziği crossfade ile değiştirir. Aynı parça çalıyorsa bir şey yapmaz. &"" müziği kapatır.
func play_music(id: StringName) -> void:
	if id == _music_id:
		return
	if id == &"":
		_music_id = &""
		_fade_out_all(_music, true)
		return
	var stream: AudioStream = _find_loop(MUSIC_DIR, id)
	if stream == null:
		return # Eksik dosya: sessizce geç, mevcut müzik sürsün.
	_music_id = id
	_music_idx = 1 - _music_idx
	_crossfade(_music, _music_idx, stream, _music_target_db(), true)


## Ambiyansı değiştirir. &"auto" otomatik moda döner, &"" ambiyansı kapatır.
func set_ambience(id: StringName) -> void:
	if id == &"auto":
		auto_ambience = true
		_update_auto_ambience()
		return
	auto_ambience = false
	_set_ambience_internal(id)


# --- Ek API ------------------------------------------------------------------

## Oyun sahnesinde true (saat/havaya göre müzik), menüde false.
func set_auto_music(enabled: bool) -> void:
	auto_music = enabled
	if enabled:
		_update_auto_music()


## Bir sesin dosyası var mı?
func has_sound(category: String, id: StringName) -> bool:
	var dir: String = SFX_DIR
	if category == "music":
		dir = MUSIC_DIR
	elif category == "ambience":
		dir = AMBIENCE_DIR
	return _load_stream(dir, String(id)) != null


# --- İç işler ----------------------------------------------------------------

func _bus(bus_name: StringName) -> StringName:
	return bus_name if AudioServer.get_bus_index(bus_name) >= 0 else &"Master"


func _connect_systems() -> void:
	var weather: Node = get_node_or_null("/root/Weather")
	if weather != null and weather.has_signal(&"weather_changed"):
		weather.connect(&"weather_changed", _on_weather_changed)
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock != null and clock.has_signal(&"phase_changed"):
		clock.connect(&"phase_changed", _on_phase_changed)
	var fx: Node = get_node_or_null("/root/Effects")
	if fx != null and fx.has_signal(&"gafti_mode_changed"):
		fx.connect(&"gafti_mode_changed", _on_gafti_changed)


func _on_weather_changed(_w: StringName) -> void:
	_update_auto_ambience()
	_update_auto_music()


func _on_phase_changed(_p: StringName) -> void:
	_update_auto_ambience()
	_update_auto_music()


func _on_gafti_changed(active: bool, strength: float) -> void:
	_gafti = active
	var pitch: float = lerpf(1.0, 0.85, clampf(strength, 0.0, 1.0)) if active else 1.0
	for m: AudioStreamPlayer in _music:
		m.pitch_scale = pitch
	if _lowpass != null:
		var idx: int = AudioServer.get_bus_index(&"Music")
		if idx >= 0:
			AudioServer.set_bus_effect_enabled(idx, _lowpass_index(idx), active)
	_update_auto_music()


func _setup_music_filter() -> void:
	var idx: int = AudioServer.get_bus_index(&"Music")
	if idx < 0:
		return
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 1400.0
	AudioServer.add_bus_effect(idx, _lowpass)
	AudioServer.set_bus_effect_enabled(idx, _lowpass_index(idx), false)


func _lowpass_index(bus_idx: int) -> int:
	for i: int in AudioServer.get_bus_effect_count(bus_idx):
		if AudioServer.get_bus_effect(bus_idx, i) == _lowpass:
			return i
	return 0


func _current_weather() -> StringName:
	var w: Node = get_node_or_null("/root/Weather")
	if w == null:
		return &"sunny"
	var v: Variant = w.get(&"current")
	return StringName(v) if v != null else &"sunny"


func _current_phase() -> StringName:
	var c: Node = get_node_or_null("/root/GameClock")
	if c == null:
		return &"morning"
	var hour_v: Variant = c.get(&"hour")
	var h: int = int(hour_v) if hour_v != null else 9
	if h >= 22 or h < 5:
		return &"night"
	if h >= 16:
		return &"evening"
	if h >= 11:
		return &"noon"
	return &"morning"


func _update_auto_ambience() -> void:
	if not auto_ambience:
		return
	var w: StringName = _current_weather()
	var phase: StringName = _current_phase()
	var id: StringName = &"birds_loop"
	if w == &"rainy" or w == &"storm":
		id = &"rain_loop"
	elif w == &"snow" or w == &"foggy":
		id = &"wind_loop"
	elif phase == &"night":
		id = &"night_crickets_loop"
	_set_ambience_internal(id)


func _update_auto_music() -> void:
	_storm = _current_weather() == &"storm"
	if not auto_music:
		return
	var id: StringName
	if _gafti:
		id = &"gafti"
	else:
		match _current_phase():
			&"night":
				id = &"night"
			&"evening":
				id = &"evening"
			&"noon":
				id = &"day_2"
			_:
				id = &"day_1"
	play_music(id)
	# Fırtınada müzik kısılır.
	var cur: AudioStreamPlayer = _music[_music_idx]
	if cur.playing and (_music_tween == null or not _music_tween.is_running()):
		cur.volume_db = _music_target_db()


func _music_target_db() -> float:
	return -14.0 if _storm else 0.0


func _set_ambience_internal(id: StringName) -> void:
	if id == _amb_id:
		return
	if id == &"":
		_amb_id = &""
		_fade_out_all(_amb, false)
		return
	var stream: AudioStream = _find_loop(AMBIENCE_DIR, id)
	if stream == null:
		return
	_amb_id = id
	_amb_idx = 1 - _amb_idx
	_crossfade(_amb, _amb_idx, stream, -4.0, false)


func _crossfade(players: Array[AudioStreamPlayer], new_idx: int, stream: AudioStream, target_db: float, is_music: bool) -> void:
	var incoming: AudioStreamPlayer = players[new_idx]
	var outgoing: AudioStreamPlayer = players[1 - new_idx]
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", target_db, FADE_TIME).set_trans(Tween.TRANS_SINE)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", SILENT_DB, FADE_TIME).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(_stop_if_silent.bind(outgoing))
	if is_music:
		if _music_tween != null:
			_music_tween.kill()
		_music_tween = tw
	else:
		if _amb_tween != null:
			_amb_tween.kill()
		_amb_tween = tw


func _fade_out_all(players: Array[AudioStreamPlayer], is_music: bool) -> void:
	var tw: Tween = create_tween().set_parallel(true)
	for p: AudioStreamPlayer in players:
		if p.playing:
			tw.tween_property(p, "volume_db", SILENT_DB, FADE_TIME)
	tw.chain().tween_callback(func() -> void:
		for p: AudioStreamPlayer in players:
			p.stop())
	if is_music:
		_music_tween = tw
	else:
		_amb_tween = tw


func _stop_if_silent(p: AudioStreamPlayer) -> void:
	if p.volume_db <= SILENT_DB + 1.0:
		p.stop()


## Döngü dosyası olmayan (wav/mp3) parçalar bitince yeniden başlar.
func _on_loop_finished(p: AudioStreamPlayer) -> void:
	if p.volume_db > SILENT_DB + 1.0:
		p.play()


func _free_2d() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _pool_2d:
		if not p.playing:
			return p
	return _pool_2d[randi() % _pool_2d.size()]


func _free_3d() -> AudioStreamPlayer3D:
	for p: AudioStreamPlayer3D in _pool_3d:
		if not p.playing:
			return p
	return _pool_3d[randi() % _pool_3d.size()]


func _find_sfx(id: StringName) -> AudioStream:
	var s: AudioStream = _load_stream(SFX_DIR, String(id))
	if s != null:
		return s
	# Varyant: footstep_grass → footstep_grass_1..4
	var variants: Array[AudioStream] = []
	for i: int in range(1, 6):
		var v: AudioStream = _load_stream(SFX_DIR, "%s_%d" % [id, i])
		if v != null:
			variants.append(v)
	if variants.is_empty():
		return null
	return variants[randi() % variants.size()]


func _find_loop(dir: String, id: StringName) -> AudioStream:
	var s: AudioStream = _load_stream(dir, String(id))
	if s == null and not String(id).ends_with("_loop"):
		s = _load_stream(dir, String(id) + "_loop")
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	return s


func _load_stream(dir: String, base: String) -> AudioStream:
	var key: String = dir + base
	if _cache.has(key):
		return _cache[key] as AudioStream
	var found: AudioStream = null
	for ext: String in EXTENSIONS:
		var path: String = "%s%s.%s" % [dir, base, ext]
		if ResourceLoader.exists(path):
			found = load(path) as AudioStream
			if found != null:
				break
	_cache[key] = found
	return found
