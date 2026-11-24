class_name ShopInspection
extends Node
## Habersiz denetim (GDD §5.7): rastgele günlerde (lisans seviyesine göre) Denetçi Nevzat Bey dükkana gelir.
## Puan = Reputation.get_inspection_score() (uyum + kimlik kontrol geçmişi + hijyen) %80 + raf etiketleme %20.
## Sonuç EventBus.inspection_finished(score, fine) ile yayılır; cezayı Economy (Ajan A) bu sinyalde keser.
## Ebeveyn ShopManager olmalı (ya da shop_path ile verilmeli).

signal inspection_started()

## Lisans seviyesine göre günlük denetim ihtimali.
const CHANCE_BY_LICENSE: Dictionary = {1: 0.22, 2: 0.18, 3: 0.14}
const ARRIVE_TIMEOUT_SEC: float = 40.0

@export var shop_path: NodePath = ^".."
## Test için: bu oyun saatinde denetimi zorla (-1 = kapalı).
@export var force_hour: int = -1

var visit_hour: int = -1
var in_progress: bool = false
var last_score: int = -1
var _visited_today: bool = false
var _nevzat: Node = null
var _wait_t: float = -1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	GameClock.day_started.connect(_on_day_started)
	GameClock.hour_passed.connect(_on_hour_passed)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	_roll_today(GameClock.day)


func _shop() -> ShopManager:
	return get_node_or_null(shop_path) as ShopManager


func _on_day_started(day: int) -> void:
	_roll_today(day)


func _roll_today(day: int) -> void:
	_visited_today = false
	visit_hour = -1
	if force_hour >= 0:
		visit_hour = force_hour
		return
	var forced: bool = QuestManager.is_active(&"q_first_inspection")
	var chance: float = float(CHANCE_BY_LICENSE.get(Reputation.license_level, 0.15))
	if forced or (day > 2 and _rng.randf() < chance):
		visit_hour = _rng.randi_range(17, 20)


func _on_hour_passed(hour: int) -> void:
	if _visited_today or in_progress or hour != visit_hour:
		return
	var shop: ShopManager = _shop()
	if shop == null or not shop.is_open:
		# Dükkan kapalıysa denetçi yarına erteler (somurtarak).
		return
	start_inspection()


## Denetimi başlatır: Nevzat Bey'i dükkana yürütür, varınca diyalog açılır.
func start_inspection() -> void:
	if in_progress:
		return
	in_progress = true
	_visited_today = true
	inspection_started.emit()
	EventBus.notify.emit(tr("INSPECTION_INCOMING"), &"bad")
	_nevzat = null
	var list: Array[Node] = get_tree().get_nodes_in_group(&"npc_nevzat")
	var shop: ShopManager = _shop()
	if not list.is_empty() and shop != null and list[0].has_method(&"go_to"):
		_nevzat = list[0]
		_nevzat.call(&"go_to", shop.marker("InspectorSpot"))
		_nevzat.connect(&"arrived", _on_nevzat_arrived, CONNECT_ONE_SHOT)
		_wait_t = ARRIVE_TIMEOUT_SEC
	else:
		_begin_dialogue()


func _process(delta: float) -> void:
	if _wait_t > 0.0:
		_wait_t -= delta
		if _wait_t <= 0.0:
			# Yolda takıldıysa beklemeden başla.
			if _nevzat != null and is_instance_valid(_nevzat) and _nevzat.is_connected(&"arrived", _on_nevzat_arrived):
				_nevzat.disconnect(&"arrived", _on_nevzat_arrived)
			_begin_dialogue()


func _on_nevzat_arrived() -> void:
	_wait_t = -1.0
	_begin_dialogue()


func _begin_dialogue() -> void:
	_wait_t = -1.0
	if _nevzat != null and is_instance_valid(_nevzat):
		_nevzat.set(&"talking", true)
	QuestManager.request_dialogue(&"inspection_start")


func _on_dialogue_finished(id: StringName) -> void:
	if not in_progress:
		return
	if id == &"inspection_start":
		_finish()
	elif id == &"rt_inspection_result":
		in_progress = false
		if _nevzat != null and is_instance_valid(_nevzat):
			_nevzat.set(&"talking", false)
			if _nevzat.has_method(&"release_override"):
				_nevzat.call(&"release_override")
		_nevzat = null


## Puanı hesaplar (0..100).
func compute_score() -> int:
	var base: float = 60.0
	if Reputation.has_method(&"get_inspection_score"):
		base = float(Reputation.call(&"get_inspection_score"))
	else:
		base = Reputation.compliance
	var labels: float = 1.0
	var shop: ShopManager = _shop()
	if shop != null:
		labels = shop.get_label_ratio()
	return clampi(int(round(base * 0.8 + labels * 20.0)), 0, 100)


static func fine_for(score: int) -> int:
	if score >= 70:
		return 0
	if score >= 50:
		return 150
	return 400


func _finish() -> void:
	var score: int = compute_score()
	var fine: int = fine_for(score)
	last_score = score
	var id_ratio: float = 1.0
	if Reputation.has_method(&"get_id_check_ratio"):
		id_ratio = float(Reputation.call(&"get_id_check_ratio"))
	EventBus.inspection_finished.emit(score, fine)
	var tier: String = "GOOD" if score >= 70 else ("OK" if score >= 50 else "BAD")
	var gafti: bool = false
	var fx: Node = get_node_or_null(^"/root/Effects")
	if fx != null:
		gafti = bool(fx.get(&"gafti_active"))
	var lines: Array[Dictionary] = []
	lines.append({"speaker": &"nevzat", "text": tr("INSPECTION_SCORE") % score})
	if gafti:
		lines.append({"speaker": &"nevzat", "text_key": "INSPECTION_GAFTI_" + tier})
	else:
		lines.append({"speaker": &"nevzat", "text_key": "INSPECTION_RESULT_" + tier})
	if fine > 0:
		lines.append({"speaker": &"nevzat", "text": tr("INSPECTION_FINE") % fine})
	var shop: ShopManager = _shop()
	if shop != null and shop.get_label_ratio() < 0.99:
		lines.append({"speaker": &"nevzat", "text_key": "INSPECTION_TIP_LABELS"})
	if id_ratio < 0.9:
		lines.append({"speaker": &"nevzat", "text_key": "INSPECTION_TIP_IDS"})
	QuestManager.register_runtime_dialogue(&"rt_inspection_result", lines)
	QuestManager.request_dialogue(&"rt_inspection_result")
