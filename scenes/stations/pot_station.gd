class_name PotStation
extends StationBase
## Saksı istasyonu: tohum ek, sula, besle, buda, zararlı temizle, hasat.
## outdoor = true ise dış tarla saksısıdır: yağmurda kendiliğinden sulanır, kışın ekim kapalı.
## Bakım işlemlerinde EventBus.minigame_requested(&"care", ctx) yayar; dinleyici yoksa doğrudan uygular.
## ctx = {action, request_id, plant_id, strain, stage}; sonuç = {request_id, score 0..100, cancelled}.

signal plant_changed()

const PLANT_VISUAL_PATH: String = "res://scenes/plants/plant_visual.tscn"
const POT_MODEL: String = "res://assets/models/props/pot.glb"
const SOIL_HEIGHT: float = 0.32
const WATER_AMOUNT: float = 0.4
const FEED_AMOUNT: float = 0.45

## Dış tarla saksısı mı?
@export var outdoor: bool = false

var state: PlantState = null

var _visual: Node3D = null
var _status: Label3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _equip_cache: Dictionary = {}
var _equip_age: int = 999
var _pending_request: int = 0
var _pending_action: StringName = &""
static var _request_counter: int = 0


func _init() -> void:
	super._init()
	add_to_group(&"plant_pot")


func _ready() -> void:
	super._ready()
	_rng.randomize()
	_build_model()
	_status = make_status_label(1.6)
	GameClock.minute_passed.connect(_on_minute)
	_refresh_visual(true)


# ---------------------------------------------------------------------------
# Etkileşim sözleşmesi
# ---------------------------------------------------------------------------

func get_interact_text() -> String:
	var title: String = tr("PLOT_TITLE") if outdoor else tr("POT_TITLE")
	if state == null:
		return title + " — " + tr("POT_EMPTY")
	var strain: StrainData = SeedBook.get_strain(state.strain_id)
	var sname: String = strain.get_display_name() if strain != null else String(state.strain_id)
	return "%s — %s (%s)" % [title, sname, state.get_stage_name()]


func interact(_player: Node) -> void:
	var opts: Array[Dictionary] = []
	if state == null:
		opts.append({"id": &"plant", "text": tr("POT_ACT_PLANT"), "disabled": not can_plant()})
	elif state.dead:
		opts.append({"id": &"clear", "text": tr("POT_ACT_CLEAR")})
	else:
		var water_txt: String = tr("POT_ACT_WATER") % Inventory.count_of(Inventory.WATER_ID)
		opts.append({"id": &"water", "text": water_txt, "disabled": Inventory.count_of(Inventory.WATER_ID) <= 0})
		opts.append({"id": &"feed", "text": tr("POT_ACT_FEED") % Inventory.count_of(&"nutrient"), "disabled": Inventory.count_of(&"nutrient") <= 0})
		if state.stage >= PlantState.Stage.VEG and not state.pruned:
			opts.append({"id": &"prune", "text": tr("POT_ACT_PRUNE")})
		if state.pest != &"":
			opts.append({"id": &"pest", "text": tr("POT_ACT_PEST")})
		if state.can_harvest():
			opts.append({"id": &"harvest", "text": tr("POT_ACT_HARVEST")})
		opts.append({"id": &"info", "text": tr("POT_ACT_INFO")})
	ActionMenu.open(get_interact_text(), opts, _on_action)


func _on_action(id: StringName) -> void:
	match id:
		&"plant":
			_open_seed_menu()
		&"water", &"feed", &"prune", &"pest":
			request_care(id)
		&"harvest":
			harvest()
		&"clear":
			clear_dead()
		&"info":
			ActionMenu.open(get_status_text(), [], Callable())


func _open_seed_menu() -> void:
	var opts: Array[Dictionary] = []
	for it: Dictionary in Inventory.get_items(&"seed"):
		var s: StrainData = SeedBook.get_strain(it["strain"])
		var n: String = s.get_display_name() if s != null else String(it["strain"])
		opts.append({"id": it["id"], "text": "%s ×%d" % [n, int(it["count"])]})
	if opts.is_empty():
		notify(tr("POT_NO_SEEDS"), &"bad")
		return
	ActionMenu.open(tr("POT_PICK_SEED"), opts, func(seed_id: StringName) -> void: plant_seed(seed_id))


# ---------------------------------------------------------------------------
# Genel API
# ---------------------------------------------------------------------------

func can_plant() -> bool:
	if state != null:
		return false
	if outdoor and GameClock.season == &"winter":
		return false
	return true


## Envanterdeki tohumu eker (ör. &"seed_pusu_kusu").
func plant_seed(seed_id: StringName) -> bool:
	if outdoor and GameClock.season == &"winter":
		notify(tr("PLOT_WINTER_CLOSED"), &"bad")
		return false
	if state != null:
		return false
	var item: Dictionary = Inventory.get_item(seed_id)
	if item.is_empty() or item["kind"] != &"seed":
		notify(tr("POT_NO_SEEDS"), &"bad")
		return false
	var strain_id: StringName = item["strain"]
	if SeedBook.get_strain(strain_id) == null:
		return false
	if not Inventory.remove_item(seed_id, 1):
		return false
	state = PlantState.new()
	state.strain_id = strain_id
	state.water = 0.6
	state.nutrients = 0.5
	play_sfx(&"plant_seed")
	notify(tr("POT_PLANTED") % SeedBook.get_strain(strain_id).get_display_name(), &"good")
	quest_event(&"plant_seeded", {"strain": strain_id})
	_refresh_visual(true)
	plant_changed.emit()
	return true


## Bakım isteği: mini oyun sistemi varsa ona yönlendirir, yoksa doğrudan uygular.
func request_care(action: StringName) -> void:
	if not _can_care(action):
		return
	if EventBus.minigame_requested.get_connections().is_empty():
		apply_care(action, 100)
		return
	_request_counter += 1
	_pending_request = _request_counter
	_pending_action = action
	if not EventBus.minigame_finished.is_connected(_on_minigame_finished):
		EventBus.minigame_finished.connect(_on_minigame_finished)
	EventBus.minigame_requested.emit(&"care", {
		"action": action, "request_id": _pending_request, "plant_id": get_plant_id(),
		"strain": state.strain_id if state != null else &"", "stage": state.stage if state != null else 0,
	})


## Bakımı uygular. score 0..100 etkinliği belirler (0.5 + 0.5 * score/100).
func apply_care(action: StringName, score: int = 100) -> bool:
	if not _can_care(action):
		return false
	var eff: float = 0.5 + 0.5 * clampf(float(score) / 100.0, 0.0, 1.0)
	match action:
		&"water":
			if not Inventory.remove_item(Inventory.WATER_ID, 1):
				notify(tr("POT_NO_WATER"), &"bad")
				return false
			var amount: float = WATER_AMOUNT * eff * (1.0 + _get_water_jitter())
			state.water = minf(1.0, state.water + amount)
			state.ph += 0.05 # sert su pH'ı biraz yükseltir
			play_sfx(&"water_pour")
			quest_event(&"plant_watered", {"strain": state.strain_id})
		&"feed":
			if not Inventory.remove_item(&"nutrient", 1):
				notify(tr("POT_NO_NUTRIENT"), &"bad")
				return false
			state.nutrients = minf(1.0, state.nutrients + FEED_AMOUNT * eff)
			# Besin çözeltisi pH'ı türün ideal ortasına çeker.
			var strain: StrainData = SeedBook.get_strain(state.strain_id)
			var target: float = (strain.ideal_ph_min + strain.ideal_ph_max) * 0.5 if strain != null else 6.3
			state.ph = lerpf(state.ph, target, 0.6 * eff)
			play_sfx(&"feed")
		&"prune":
			state.pruned = true
			state.health = minf(1.0, state.health + 0.05 * eff)
			play_sfx(&"prune")
		&"pest":
			# İlaç varsa tam temizlik, yoksa elle (etkinliğe bağlı).
			if Inventory.remove_item(&"pesticide", 1):
				state.pest_level = 0.0
			else:
				state.pest_level = maxf(0.0, state.pest_level - 0.7 * eff)
			if state.pest_level <= 0.05:
				state.pest = &""
				state.pest_level = 0.0
				notify(tr("POT_PEST_CLEANED"), &"good")
			play_sfx(&"pest_clean")
	_refresh_visual(false)
	plant_changed.emit()
	return true


## Hasat eder; ıslak tomurcuğu envantere ekler ve eşyayı döndürür.
func harvest() -> Dictionary:
	if state == null or not state.can_harvest():
		return {}
	var strain: StrainData = SeedBook.get_strain(state.strain_id)
	var item: Dictionary = Growth.harvest(state, strain, GameClock.season)
	if item.is_empty():
		return {}
	Inventory.add_item(item)
	EventBus.plant_harvested.emit(get_plant_id(), item)
	quest_event(&"plant_harvested", {"strain": item["strain"], "grams": item["count"], "quality": item["quality"]})
	notify(tr("POT_HARVESTED") % [int(item["count"]), strain.get_display_name(), int(item["quality"])], &"good")
	play_sfx(&"harvest")
	state = null
	_refresh_visual(true)
	plant_changed.emit()
	return item


## Ölü bitkiyi temizler: kompost → 1 besin.
func clear_dead() -> bool:
	if state == null or not state.dead:
		return false
	state = null
	Inventory.add_item({"id": &"nutrient", "kind": &"nutrient", "count": 1})
	notify(tr("POT_COMPOSTED"), &"info")
	_refresh_visual(true)
	plant_changed.emit()
	return true


func get_plant_id() -> int:
	return get_instance_id()


func get_state() -> PlantState:
	return state


## Denetim hijyeni: ölü bitki veya zararlı varsa true.
func is_unhygienic() -> bool:
	return state != null and (state.dead or state.pest != &"")


func get_status_text() -> String:
	if state == null:
		return tr("POT_EMPTY")
	return tr("POT_INFO") % [
		state.get_stage_name(), int(state.growth * 100.0), int(state.water * 100.0),
		int(state.nutrients * 100.0), state.ph, state.temperature, int(state.humidity * 100.0),
		int(state.light * 100.0), int(state.health * 100.0), int(state.quality),
	]


## Ortam değerlerini hesaplar (Growth.step için env sözlüğü).
func compute_env() -> Dictionary:
	if _equip_age >= 30:
		_refresh_equipment()
	var sun: float = Weather.get_sun_light()
	var out_t: float = Weather.get_outdoor_temperature()
	var out_h: float = Weather.get_outdoor_humidity()
	var power: bool = not Weather.is_power_out()
	var light: float
	var temp: float
	var hum: float
	if outdoor:
		light = sun
		temp = out_t
		hum = out_h
	else:
		# Sera: cam ışığı %80 geçirir, pasif ısınma, hafif nem.
		light = sun * 0.8
		temp = out_t * 0.6 + 10.0
		if Weather.current == &"snow":
			temp -= 2.0
		hum = clampf(out_h * 0.8 + 0.1, 0.0, 1.0)
		if power:
			var lamps: int = int(_equip_cache.get(&"light", 0))
			if lamps > 0 and GameClock.hour >= 6:
				light = minf(1.0, light + 0.6 * float(lamps))
			temp += minf(12.0, 9.0 * float(_equip_cache.get(&"heat", 0)))
			hum = clampf(hum + 0.15 * float(_equip_cache.get(&"humidity", 0)), 0.0, 0.95)
	return {
		"light": light, "temperature": temp, "humidity": hum,
		"daytime": GameClock.hour >= 6 and GameClock.hour < 21,
		"outdoor": outdoor, "raining": Weather.is_raining(), "storm": Weather.current == &"storm",
		"sunny": Weather.current == &"sunny", "season": GameClock.season,
	}


# ---------------------------------------------------------------------------
# Simülasyon
# ---------------------------------------------------------------------------

func _on_minute(_total: int) -> void:
	_equip_age += 1
	if state == null or state.dead:
		return
	var strain: StrainData = SeedBook.get_strain(state.strain_id)
	if strain == null:
		return
	# Damla sulama: su azalınca otomatik doldurur.
	if int(_equip_cache.get(&"water", 0)) > 0 and state.water < 0.35:
		state.water = 0.8
	var prev_stage: int = state.stage
	var ev: StringName = Growth.step(state, strain, compute_env(), _rng)
	match ev:
		Growth.EV_DIED:
			notify(tr("POT_DIED") % strain.get_display_name(), &"bad")
			_refresh_visual(true)
		Growth.EV_READY:
			notify(tr("POT_READY") % strain.get_display_name(), &"good")
			_refresh_visual(true)
		Growth.EV_PEST:
			notify(tr("POT_PEST_" + String(state.pest).to_upper()), &"bad")
	if state.stage != prev_stage or (state.age_minutes % 10) == 0:
		_refresh_visual(state.stage != prev_stage)


func _can_care(action: StringName) -> bool:
	if state == null or state.dead:
		return false
	match action:
		&"water":
			if Inventory.count_of(Inventory.WATER_ID) <= 0:
				notify(tr("POT_NO_WATER"), &"bad")
				return false
		&"feed":
			if Inventory.count_of(&"nutrient") <= 0:
				notify(tr("POT_NO_NUTRIENT"), &"bad")
				return false
		&"prune":
			return state.stage >= PlantState.Stage.VEG and not state.pruned
		&"pest":
			return state.pest != &""
	return true


func _on_minigame_finished(id: StringName, result: Dictionary) -> void:
	if id != &"care" or _pending_request == 0:
		return
	if result.has("request_id") and int(result["request_id"]) != _pending_request:
		return
	var action: StringName = _pending_action
	_pending_request = 0
	_pending_action = &""
	EventBus.minigame_finished.disconnect(_on_minigame_finished)
	if bool(result.get("cancelled", false)):
		return
	apply_care(action, int(result.get("score", 100)))


func _get_water_jitter() -> float:
	var fx: Node = get_node_or_null("/root/Effects")
	if fx != null and fx.has_method("get_water_jitter"):
		return float(fx.call("get_water_jitter"))
	return 0.0


## Yakındaki ekipmanları sayar ("grow_equipment" grubu: effect + radius özellikleri).
func _refresh_equipment() -> void:
	_equip_age = 0
	_equip_cache.clear()
	if not is_inside_tree():
		return
	for n: Node in get_tree().get_nodes_in_group(&"grow_equipment"):
		var n3: Node3D = n as Node3D
		if n3 == null:
			continue
		var eff: Variant = n3.get("effect")
		var radius: Variant = n3.get("radius")
		if eff == null or radius == null:
			continue
		if n3.global_position.distance_to(global_position) <= float(radius):
			var key: StringName = StringName(eff)
			_equip_cache[key] = int(_equip_cache.get(key, 0)) + 1


## Ekipman değişince (inşa modu) çağrılır.
func refresh_equipment() -> void:
	_equip_age = 999


# ---------------------------------------------------------------------------
# Görsel
# ---------------------------------------------------------------------------

func _build_model() -> void:
	var model: Node3D
	if outdoor:
		model = ModelLoader.placeholder(Vector3(0.9, 0.15, 0.9), Color(0.33, 0.22, 0.12), "plot")
	else:
		model = ModelLoader.instance(POT_MODEL, Vector3(0.45, SOIL_HEIGHT, 0.45), Color(0.55, 0.32, 0.18))
	model.name = "Model"
	add_child(model)


## rebuild: aşama değişimi gibi büyük güncellemeler (şimdilik görsel her durumda güncellenir).
func _refresh_visual(_rebuild: bool) -> void:
	if not is_inside_tree() or _status == null:
		return
	if state == null:
		if _visual != null:
			_visual.queue_free()
			_visual = null
		_status.text = ""
		return
	if _visual == null:
		_visual = _make_plant_visual()
		_visual.name = "Plant"
		_visual.position.y = 0.15 if outdoor else SOIL_HEIGHT
		add_child(_visual)
	if _visual == null:
		return
	var strain: StrainData = SeedBook.get_strain(state.strain_id)
	if strain != null:
		_visual.scale = Vector3.ONE * strain.height_scale
	_visual.call("set_stage", state.stage)
	_visual.call("set_health", 0.0 if state.dead else state.health)
	_visual.call("set_thirst", state.get_thirst())
	_visual.call("set_quality", state.quality / 100.0)
	_status.text = _status_icon()


func _make_plant_visual() -> Node3D:
	if ResourceLoader.exists(PLANT_VISUAL_PATH):
		var ps: PackedScene = load(PLANT_VISUAL_PATH) as PackedScene
		if ps != null:
			var v: Node3D = ps.instantiate() as Node3D
			if v != null and v.has_method("set_stage"):
				return v
	var fb: PlantFallbackVisual = PlantFallbackVisual.new()
	var strain: StrainData = SeedBook.get_strain(state.strain_id)
	if strain != null:
		fb.leaf_tint = strain.leaf_tint
	return fb


func _status_icon() -> String:
	if state.dead:
		return tr("POT_STATUS_DEAD")
	if state.is_ready():
		return tr("POT_STATUS_READY")
	if state.pest != &"":
		return tr("POT_STATUS_PEST")
	if state.water < 0.2:
		return tr("POT_STATUS_THIRSTY")
	if state.nutrients < 0.15 and state.stage >= PlantState.Stage.SEEDLING:
		return tr("POT_STATUS_HUNGRY")
	return ""


# ---------------------------------------------------------------------------
# Kayıt
# ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"plant": state.to_dict() if state != null else {}}


func load_save_data(d: Dictionary) -> void:
	var p: Variant = d.get("plant", {})
	if p is Dictionary and not (p as Dictionary).is_empty():
		state = PlantState.from_dict(p)
	else:
		state = null
	if _visual != null:
		_visual.queue_free()
		_visual = null
	_refresh_visual(true)
	plant_changed.emit()
