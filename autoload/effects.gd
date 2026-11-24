extends Node
## Gaftî Modu ve ekran efektleri (Ajan B). Sözleşme: AGENTS.md §4 "Effects".
## Süre oyun dakikasıyla sayılır (GameClock.minute_passed). GameClock yoksa gerçek zamanla yaklaşık sayar.

signal gafti_mode_changed(active: bool, strength: float)

const POST_SHADER_PATH: String = "res://shaders/gafti_post.gdshader"
const MUSIC_BUS: String = "Music"
## "Bol" doz eşiği: bu güç ve üstünde komik bayılma ihtimali var.
const FAINT_THRESHOLD: float = 0.9
const FAINT_CHANCE: float = 0.45
const FAINT_MINUTES: int = 120
const FADE_IN_SEC: float = 2.5
const FADE_OUT_SEC: float = 3.5

var gafti_active: bool = false
var gafti_strength: float = 0.0 # 0..1

## Sarma becerisi: kaç joint sarıldı (yardım göstergeleri bununla azalır).
var rolled_count: int = 0
## Açılmış kuru tomurcuk birimlerinden artan gramlar (eşya id → gram). Sarma 0.5 g kullanır.
var loose_bud: Dictionary = {}

var _remaining_minutes: int = 0
var _total_minutes: int = 0
var _last_clock_total: int = -1
var _clock_connected: bool = false
var _realtime_accum: float = 0.0

var _layer: CanvasLayer = null
var _rect: ColorRect = null
var _material: ShaderMaterial = null
var _faint_rect: ColorRect = null
var _visual_strength: float = 0.0
var _visual_tween: Tween = null

var _pitch_fx: AudioEffectPitchShift = null
var _lowpass_fx: AudioEffectLowPassFilter = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	# Diğer autoload'lar hazır olsun diye bağlantıyı bir kare ertele.
	_connect_clock.call_deferred()


# ---------------------------------------------------------------- Genel API

func start_gafti(strength: float, duration_game_minutes: int) -> void:
	if strength <= 0.0 or duration_game_minutes <= 0:
		return
	var s: float = clampf(strength, 0.0, 1.0)
	# Üst üste içilirse güç birikir (ama 1'i geçmez), süre uzar.
	if gafti_active:
		gafti_strength = clampf(maxf(gafti_strength, s) + s * 0.25, 0.0, 1.0)
		_remaining_minutes += duration_game_minutes
		_total_minutes += duration_game_minutes
	else:
		gafti_strength = s
		_remaining_minutes = duration_game_minutes
		_total_minutes = duration_game_minutes
	gafti_active = true
	_connect_clock()
	_ensure_music_fx()
	_tween_visual(gafti_strength, FADE_IN_SEC)
	gafti_mode_changed.emit(true, gafti_strength)
	if s >= FAINT_THRESHOLD and randf() < FAINT_CHANCE:
		_schedule_faint()


## Gaftî'yi hemen (yumuşakça) bitirir.
func stop_gafti() -> void:
	if not gafti_active:
		return
	gafti_active = false
	gafti_strength = 0.0
	_remaining_minutes = 0
	_total_minutes = 0
	_tween_visual(0.0, FADE_OUT_SEC)
	gafti_mode_changed.emit(false, 0.0)


func get_move_multiplier() -> float:
	return 0.85 if gafti_active else 1.0


func get_customer_patience_multiplier() -> float:
	return 1.3 if gafti_active else 1.0


func get_rolling_bonus() -> int:
	return 10 if gafti_active else 0


func get_water_jitter() -> float:
	if not gafti_active:
		return 0.0
	return randf_range(-0.2, 0.2)


## Kalan Gaftî süresi (oyun dakikası).
func get_remaining_minutes() -> int:
	return _remaining_minutes


## Sarma mini oyunu bitince çağrılır (beceri sayacı).
func register_roll() -> void:
	rolled_count += 1


## Kısa ekran flaşı (mini oyunlar için yardımcı).
func flash(color: Color = Color(1, 1, 1, 0.6), duration: float = 0.25) -> void:
	if _faint_rect == null:
		return
	_faint_rect.color = color
	var tw: Tween = create_tween()
	tw.tween_property(_faint_rect, "color:a", 0.0, duration)


func get_save_data() -> Dictionary:
	return {
		"active": gafti_active,
		"strength": gafti_strength,
		"remaining": _remaining_minutes,
		"total": _total_minutes,
		"rolled_count": rolled_count,
		"loose_bud": loose_bud.duplicate(),
	}


func load_save_data(d: Dictionary) -> void:
	rolled_count = int(d.get("rolled_count", 0))
	var lb: Variant = d.get("loose_bud", {})
	loose_bud = (lb as Dictionary).duplicate() if lb is Dictionary else {}
	var active: bool = bool(d.get("active", false))
	var remaining: int = int(d.get("remaining", 0))
	if active and remaining > 0:
		gafti_active = true
		gafti_strength = clampf(float(d.get("strength", 0.5)), 0.0, 1.0)
		_remaining_minutes = remaining
		_total_minutes = maxi(int(d.get("total", remaining)), remaining)
		_ensure_music_fx()
		_tween_visual(gafti_strength, 0.5)
		gafti_mode_changed.emit(true, gafti_strength)
	else:
		gafti_active = false
		gafti_strength = 0.0
		_remaining_minutes = 0
		_total_minutes = 0
		_set_visual(0.0)
		_remove_music_fx()
	_last_clock_total = -1


# ---------------------------------------------------------------- Saat

func _connect_clock() -> void:
	if _clock_connected:
		return
	var clock: Node = get_node_or_null(^"/root/GameClock")
	if clock == null or not clock.has_signal(&"minute_passed"):
		return
	clock.connect(&"minute_passed", _on_minute_passed)
	_clock_connected = true


func _on_minute_passed(total_minutes: int) -> void:
	var delta_min: int = 1
	if _last_clock_total >= 0:
		delta_min = total_minutes - _last_clock_total
	_last_clock_total = total_minutes
	if delta_min <= 0:
		return
	_consume_minutes(delta_min)


func _process(delta: float) -> void:
	if not gafti_active:
		return
	# GameClock yoksa: gerçek zamanla yaklaşık say (14 dk = 1 gün).
	if _clock_connected:
		return
	_connect_clock()
	if _clock_connected:
		return
	var day_len: float = 14.0
	var settings: Node = get_node_or_null(^"/root/Settings")
	if settings != null and "day_length_minutes" in settings:
		day_len = float(settings.get("day_length_minutes"))
	var sec_per_game_min: float = maxf(day_len * 60.0 / 1440.0, 0.05)
	_realtime_accum += delta
	while _realtime_accum >= sec_per_game_min and gafti_active:
		_realtime_accum -= sec_per_game_min
		_consume_minutes(1)


func _consume_minutes(m: int) -> void:
	if not gafti_active:
		return
	_remaining_minutes -= m
	if _remaining_minutes <= 0:
		stop_gafti()
		return
	# Son %25'te efekt yavaşça söner.
	var frac: float = float(_remaining_minutes) / float(maxi(_total_minutes, 1))
	var target: float = gafti_strength * clampf(frac / 0.25, 0.0, 1.0)
	if _visual_tween == null or not _visual_tween.is_running():
		_set_visual(target)


# ---------------------------------------------------------------- Görsel

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "GaftiLayer"
	_layer.layer = 90
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.name = "GaftiPost"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	if ResourceLoader.exists(POST_SHADER_PATH):
		var sh: Shader = load(POST_SHADER_PATH) as Shader
		if sh != null:
			_material = ShaderMaterial.new()
			_material.shader = sh
			_material.set_shader_parameter(&"strength", 0.0)
			_rect.material = _material
	_layer.add_child(_rect)
	_faint_rect = ColorRect.new()
	_faint_rect.name = "Fade"
	_faint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_faint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faint_rect.color = Color(0, 0, 0, 0)
	_layer.add_child(_faint_rect)


func _tween_visual(target: float, seconds: float) -> void:
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	_visual_tween = create_tween()
	_visual_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_visual_tween.tween_method(_set_visual, _visual_strength, target, seconds)
	if target <= 0.0:
		_visual_tween.tween_callback(_remove_music_fx)


func _set_visual(v: float) -> void:
	_visual_strength = clampf(v, 0.0, 1.0)
	if _rect != null:
		_rect.visible = _visual_strength > 0.001 and _material != null
	if _material != null:
		_material.set_shader_parameter(&"strength", _visual_strength)
	if _pitch_fx != null:
		_pitch_fx.pitch_scale = lerpf(1.0, 0.86, _visual_strength)
	if _lowpass_fx != null:
		_lowpass_fx.cutoff_hz = lerpf(20000.0, 1400.0, _visual_strength)


# ---------------------------------------------------------------- Müzik

## AudioManager Gaftî müziğini kendisi filtreliyorsa (handles_gafti_music) çift filtre uygulama.
func _audio_manager_handles_music() -> bool:
	var am: Node = get_node_or_null(^"/root/AudioManager")
	if am == null:
		return false
	if "handles_gafti_music" in am:
		return bool(am.get("handles_gafti_music"))
	return false


func _ensure_music_fx() -> void:
	if _audio_manager_handles_music():
		return
	var bus: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus < 0:
		return
	if _pitch_fx == null:
		_pitch_fx = AudioEffectPitchShift.new()
		_pitch_fx.pitch_scale = 1.0
		AudioServer.add_bus_effect(bus, _pitch_fx)
	if _lowpass_fx == null:
		_lowpass_fx = AudioEffectLowPassFilter.new()
		_lowpass_fx.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(bus, _lowpass_fx)


func _remove_music_fx() -> void:
	var bus: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0:
		for i: int in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			var fx: AudioEffect = AudioServer.get_bus_effect(bus, i)
			if fx == _pitch_fx or fx == _lowpass_fx:
				AudioServer.remove_bus_effect(bus, i)
	_pitch_fx = null
	_lowpass_fx = null


# ---------------------------------------------------------------- Bayılma

func _schedule_faint() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(5.0, true)
	timer.timeout.connect(_do_faint)


func _do_faint() -> void:
	if not gafti_active:
		return
	var tw: Tween = create_tween()
	tw.tween_property(_faint_rect, "color", Color(0, 0, 0, 1), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_faint_blackout)
	tw.tween_interval(1.4)
	tw.tween_property(_faint_rect, "color", Color(0, 0, 0, 0), 2.0).set_trans(Tween.TRANS_SINE)


func _faint_blackout() -> void:
	_bus_notify(tr("FX_FAINT"), &"bad")
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method(&"teleport_home"):
		player.call(&"teleport_home")
	var clock: Node = get_node_or_null(^"/root/GameClock")
	if clock != null and clock.has_method(&"advance_minutes"):
		clock.call(&"advance_minutes", FAINT_MINUTES)
	else:
		_consume_minutes(FAINT_MINUTES)
	_bus_notify(tr("FX_WAKE_UP"), &"info")


func _bus_notify(text: String, kind: StringName) -> void:
	var bus: Node = get_node_or_null(^"/root/EventBus")
	if bus != null:
		bus.emit_signal(&"notify", text, kind)
