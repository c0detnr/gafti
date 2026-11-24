extends Node
## Oyuncu ayarları (user://settings.cfg).

signal changed()

const PATH: String = "user://settings.cfg"

var day_length_minutes: float = 14.0
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var graphics_quality: int = 1 # 0 düşük, 1 orta, 2 yüksek
var touch_controls: bool = false


func _ready() -> void:
	touch_controls = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if OS.has_feature("mobile"):
		graphics_quality = 0
	load_settings()
	apply()


func apply() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	changed.emit()


func _set_bus_volume(bus_name: String, v: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "day_length_minutes", day_length_minutes)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "quality", graphics_quality)
	cfg.set_value("input", "touch_controls", touch_controls)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	day_length_minutes = cfg.get_value("game", "day_length_minutes", day_length_minutes)
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	graphics_quality = cfg.get_value("video", "quality", graphics_quality)
	touch_controls = cfg.get_value("input", "touch_controls", touch_controls)
