extends Node
## İtibar (0..100), lisans seviyesi (MVP: 1..3) ve denetim uyum puanı (0..100).
## Sözleşme: AGENTS.md §4 (Reputation). Tasarım: GDD §5.7.

signal reputation_changed(value: float)
signal license_level_changed(level: int)

const MAX_LICENSE_MVP: int = 3
const LOW_INSPECTION_SCORE: int = 50
## Lisans tablosu: maliyet, gereken itibar, izin verilen saksı sayısı.
const LICENSES: Dictionary = {
	1: {"cost": 0, "rep_required": 0.0, "max_pots": 6},
	2: {"cost": 1500, "rep_required": 20.0, "max_pots": 10},
	3: {"cost": 4000, "rep_required": 45.0, "max_pots": 16},
}

var reputation: float = 10.0
var license_level: int = 1
var compliance: float = 70.0

var id_checks_done: int = 0
var id_checks_total: int = 0
## Üst üste düşük denetim puanı sayısı.
var low_inspections_in_row: int = 0
## Bu gün (dahil) ve öncesinde dükkan kapalı. 0 = kapalı değil.
var shop_closed_day: int = 0


func _ready() -> void:
	EventBus.inspection_finished.connect(_on_inspection_finished)


func add_reputation(v: float) -> void:
	var old: float = reputation
	reputation = clampf(reputation + v, 0.0, 100.0)
	if not is_equal_approx(old, reputation):
		reputation_changed.emit(reputation)


## Her müşteride kimlik kontrolü yapıldı mı? Atlamak uyumu düşürür.
func record_id_check(done: bool) -> void:
	id_checks_total += 1
	if done:
		id_checks_done += 1
		compliance = clampf(compliance + 0.5, 0.0, 100.0)
	else:
		compliance = clampf(compliance - 4.0, 0.0, 100.0)


func get_id_check_ratio() -> float:
	if id_checks_total == 0:
		return 1.0
	return float(id_checks_done) / float(id_checks_total)


func set_license_level(level: int) -> void:
	var l: int = clampi(level, 1, MAX_LICENSE_MVP)
	if l == license_level:
		return
	license_level = l
	license_level_changed.emit(license_level)


func get_license_info(level: int = -1) -> Dictionary:
	var l: int = license_level if level < 0 else level
	if not LICENSES.has(l):
		return {}
	var info: Dictionary = (LICENSES[l] as Dictionary).duplicate()
	info["level"] = l
	return info


func get_max_pots() -> int:
	return int(get_license_info().get("max_pots", 6))


func can_upgrade_license() -> bool:
	var next: int = license_level + 1
	if next > MAX_LICENSE_MVP:
		return false
	var info: Dictionary = get_license_info(next)
	return reputation >= float(info["rep_required"]) and Economy.money >= int(info["cost"])


## Bir üst lisansı satın alır (para + itibar şartı).
func upgrade_license() -> bool:
	var next: int = license_level + 1
	if next > MAX_LICENSE_MVP:
		EventBus.notify.emit(tr("REP_LICENSE_MAX"), &"info")
		return false
	var info: Dictionary = get_license_info(next)
	if reputation < float(info["rep_required"]):
		EventBus.notify.emit(tr("REP_LICENSE_NEED_REP") % int(info["rep_required"]), &"bad")
		return false
	if not Economy.spend(int(info["cost"]), tr("ECON_REASON_LICENSE")):
		return false
	set_license_level(next)
	EventBus.notify.emit(tr("REP_LICENSE_UPGRADED") % next, &"good")
	_quest_event(&"license_upgraded", {"level": next})
	return true


## Denetim puanı önerisi (0..100): uyum %50, kimlik kontrol oranı %30, sera hijyeni %20.
func get_inspection_score() -> int:
	var hygiene: float = 1.0
	var pots: Array[Node] = get_tree().get_nodes_in_group(&"plant_pot")
	var bad: int = 0
	for p: Node in pots:
		if p.has_method("is_unhygienic") and bool(p.call("is_unhygienic")):
			bad += 1
	if pots.size() > 0:
		hygiene = 1.0 - float(bad) / float(pots.size())
	var score: float = compliance * 0.5 + get_id_check_ratio() * 30.0 + hygiene * 20.0
	return clampi(int(round(score)), 0, 100)


func is_shop_closed() -> bool:
	return shop_closed_day > 0 and GameClock.day <= shop_closed_day


func _on_inspection_finished(score: int, _fine: int) -> void:
	# Denetim sonucu uyumu puana doğru çeker; kontrol geçmişi sıfırlanır.
	compliance = clampf(lerpf(compliance, float(score), 0.5), 0.0, 100.0)
	id_checks_done = 0
	id_checks_total = 0
	if score < LOW_INSPECTION_SCORE:
		low_inspections_in_row += 1
		add_reputation(-3.0)
		if low_inspections_in_row >= 2:
			shop_closed_day = GameClock.day + 1
			low_inspections_in_row = 0
			EventBus.notify.emit(tr("REP_SHOP_CLOSED"), &"bad")
	else:
		low_inspections_in_row = 0
		add_reputation(2.0)


func _quest_event(event: StringName, data: Dictionary) -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm != null and qm.has_method("notify_event"):
		qm.call("notify_event", event, data)


# ---------------------------------------------------------------------------
# Kayıt
# ---------------------------------------------------------------------------

func reset() -> void:
	reputation = 10.0
	compliance = 70.0
	id_checks_done = 0
	id_checks_total = 0
	low_inspections_in_row = 0
	shop_closed_day = 0
	license_level = 1
	reputation_changed.emit(reputation)
	license_level_changed.emit(license_level)


func get_save_data() -> Dictionary:
	return {
		"reputation": reputation, "license_level": license_level, "compliance": compliance,
		"id_done": id_checks_done, "id_total": id_checks_total,
		"low_row": low_inspections_in_row, "closed_day": shop_closed_day,
	}


func load_save_data(d: Dictionary) -> void:
	if d.is_empty():
		reset()
		return
	reputation = float(d.get("reputation", 10.0))
	license_level = int(d.get("license_level", 1))
	compliance = float(d.get("compliance", 70.0))
	id_checks_done = int(d.get("id_done", 0))
	id_checks_total = int(d.get("id_total", 0))
	low_inspections_in_row = int(d.get("low_row", 0))
	shop_closed_day = int(d.get("closed_day", 0))
	reputation_changed.emit(reputation)
	license_level_changed.emit(license_level)
