extends Node
## Komedi görev zinciri + diyalog tetikleri + Muhtar borç defteri. Sözleşme: AGENTS.md §4 (QuestManager).
## Görev verisi: data/quests/*.tres (QuestData). Diyaloglar: data/diyalog/*.tres (DialogueData).
## Diğer sistemlerin sinyallerine kendisi bağlanır; başka ajanların bir şey çağırması gerekmez.

signal quest_started(id: StringName)
signal quest_completed(id: StringName)
## Bir görevin hedef sayacı değişti (HUD için).
signal quest_progress(id: StringName)

const QUEST_DIR: String = "res://data/quests/"
const DIALOGUE_DIR: String = "res://data/dialogue/"
const DIALOGUE_BOX_SCENE: String = "res://scenes/ui/dialogue/dialogue_box.tscn"
const HARDWARE_UI_SCENE: String = "res://scenes/shop/hardware_ui.tscn"
## Hikâyenin ilk görevi.
const FIRST_QUEST: StringName = &"q_meet_muhtar"
## Muhtar borcunda bakiyenin çıkarılacağı seviye (₺).
const DEBT_CUSHION: int = 300
## Denetimde "geçti" sayılan en düşük puan.
const INSPECTION_PASS_SCORE: int = 50

var debt: int = 0
var flags: Dictionary = {}

var _quests: Dictionary = {}            # StringName -> QuestData
var _active: Array[StringName] = []
var _completed: Array[StringName] = []
var _progress: Dictionary = {}          # StringName -> Array[int]
var _dialogue_cache: Dictionary = {}    # StringName -> DialogueData
var _runtime_dialogues: Dictionary = {} # StringName -> DialogueData
var _dialogue_queue: Array[StringName] = []
var _dialogue_open: bool = false
var _story_started: bool = false


func _ready() -> void:
	_load_quests()
	EventBus.plant_harvested.connect(_on_plant_harvested)
	EventBus.sale_completed.connect(_on_sale_completed)
	EventBus.minigame_finished.connect(_on_minigame_finished)
	EventBus.inspection_finished.connect(_on_inspection_finished)
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	call_deferred(&"_late_connect")


## Diğer autoload'lar hazır olduktan sonra bağlan (sıra bağımsız olsun).
func _late_connect() -> void:
	var clock: Node = get_node_or_null(^"/root/GameClock")
	if clock != null and clock.has_signal(&"day_started"):
		clock.connect(&"day_started", _on_day_started)
	var rep: Node = get_node_or_null(^"/root/Reputation")
	if rep != null and rep.has_signal(&"license_level_changed"):
		rep.connect(&"license_level_changed", _on_license_level_changed)
	_ensure_dialogue_box()
	_ensure_story_started()


func _ensure_dialogue_box() -> void:
	if not get_tree().get_nodes_in_group(&"dialogue_box").is_empty():
		return
	if not ResourceLoader.exists(DIALOGUE_BOX_SCENE):
		return
	var scene: PackedScene = load(DIALOGUE_BOX_SCENE) as PackedScene
	if scene == null:
		return
	var box: Node = scene.instantiate()
	box.name = "DialogueBox"
	get_tree().root.add_child(box)


func _ensure_story_started() -> void:
	if _story_started or not _active.is_empty() or not _completed.is_empty():
		return
	_story_started = true
	start(FIRST_QUEST)


# ---------------------------------------------------------------- Görev verisi

func _load_quests() -> void:
	_quests.clear()
	var dir: DirAccess = DirAccess.open(QUEST_DIR)
	if dir == null:
		push_warning("QuestManager: görev klasörü yok: " + QUEST_DIR)
		return
	for f: String in dir.get_files():
		var file: String = f.trim_suffix(".remap")
		if not file.ends_with(".tres") and not file.ends_with(".res"):
			continue
		var q: QuestData = load(QUEST_DIR + file) as QuestData
		if q != null and q.id != &"":
			_quests[q.id] = q


func get_quest(id: StringName) -> QuestData:
	return _quests.get(id, null) as QuestData


func get_all_quest_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in _quests.keys():
		out.append(k as StringName)
	return out


func get_completed() -> Array[StringName]:
	return _completed.duplicate()


func is_completed(id: StringName) -> bool:
	return _completed.has(id)


# ---------------------------------------------------------------- Sözleşme API

func start(id: StringName) -> void:
	var q: QuestData = get_quest(id)
	if q == null:
		push_warning("QuestManager: bilinmeyen görev " + String(id))
		return
	if _active.has(id) or _completed.has(id):
		return
	_story_started = true
	_active.append(id)
	var prog: Array[int] = []
	for _o: Dictionary in q.objectives:
		prog.append(0)
	_progress[id] = prog
	quest_started.emit(id)
	EventBus.notify.emit(tr("QUEST_STARTED") % tr(q.title_key), &"info")
	_play_sfx(&"quest_start")
	if q.start_dialogue != &"":
		request_dialogue(q.start_dialogue)
	_check_instant(id)


func complete(id: StringName) -> void:
	var q: QuestData = get_quest(id)
	if q == null or _completed.has(id):
		return
	_active.erase(id)
	_progress.erase(id)
	_completed.append(id)
	_give_rewards(q)
	quest_completed.emit(id)
	EventBus.notify.emit(tr("QUEST_COMPLETED") % tr(q.title_key), &"good")
	_play_sfx(&"quest_complete")
	if q.end_dialogue != &"":
		request_dialogue(q.end_dialogue)
	for nid: StringName in q.next_quests:
		start(nid)


func is_active(id: StringName) -> bool:
	return _active.has(id)


func get_active() -> Array[StringName]:
	return _active.duplicate()


## Görev hedeflerini ilerletir. Sayaç her çağrıda 1 artar; hedefte "match" varsa data alanları eşit olmalı,
## "match_min" varsa data alanları >= olmalı.
func notify_event(event: StringName, data: Dictionary = {}) -> void:
	for id: StringName in _active.duplicate():
		var q: QuestData = get_quest(id)
		if q == null:
			continue
		var prog: Array = _progress.get(id, []) as Array
		var changed: bool = false
		for i: int in range(q.objectives.size()):
			var o: Dictionary = q.objectives[i]
			var need: int = int(o.get("count", 1))
			if int(prog[i]) >= need:
				continue
			if q.sequential and i != _current_objective_index(id):
				continue
			if StringName(o.get("event", &"")) != event:
				continue
			if not _matches(o, data):
				continue
			prog[i] = int(prog[i]) + 1
			changed = true
			if q.sequential:
				break
		if changed:
			_progress[id] = prog
			quest_progress.emit(id)
			if _is_done(id):
				complete(id)


func _matches(o: Dictionary, data: Dictionary) -> bool:
	var m: Dictionary = o.get("match", {}) as Dictionary
	for key: Variant in m.keys():
		if not data.has(key):
			return false
		if str(data[key]) != str(m[key]):
			return false
	var mm: Dictionary = o.get("match_min", {}) as Dictionary
	for key: Variant in mm.keys():
		if not data.has(key):
			return false
		if float(data[key]) < float(mm[key]):
			return false
	return true


func _is_done(id: StringName) -> bool:
	var q: QuestData = get_quest(id)
	var prog: Array = _progress.get(id, []) as Array
	for i: int in range(q.objectives.size()):
		if int(prog[i]) < int(q.objectives[i].get("count", 1)):
			return false
	return true


func _current_objective_index(id: StringName) -> int:
	var q: QuestData = get_quest(id)
	var prog: Array = _progress.get(id, []) as Array
	for i: int in range(q.objectives.size()):
		if int(prog[i]) < int(q.objectives[i].get("count", 1)):
			return i
	return -1


## Görev başladığında koşulu zaten sağlanmış hedefler (ör. lisans zaten 2).
func _check_instant(id: StringName) -> void:
	var q: QuestData = get_quest(id)
	for o: Dictionary in q.objectives:
		if StringName(o.get("event", &"")) == &"license_level":
			var lvl: int = int(_get_prop(&"Reputation", &"license_level", 1))
			if _active.has(id):
				notify_event(&"license_level", {"level": lvl})


func _give_rewards(q: QuestData) -> void:
	var r: Dictionary = q.rewards
	var money: int = int(r.get("money", 0))
	if money > 0:
		Economy.add(money, "quest:" + String(q.id))
	var rep: float = float(r.get("reputation", 0.0))
	if rep != 0.0:
		Reputation.add_reputation(rep)
	var lvl: int = int(r.get("license_level", 0))
	if lvl > 0 and Reputation.license_level < lvl:
		if Reputation.has_method(&"set_license_level"):
			Reputation.call(&"set_license_level", lvl)
		else:
			Reputation.license_level = lvl
			Reputation.license_level_changed.emit(lvl)
	var item: Dictionary = r.get("item", {}) as Dictionary
	if not item.is_empty():
		Inventory.add_item(item.duplicate(true))


# ---------------------------------------------------------------- HUD yardımcıları

func get_quest_title(id: StringName) -> String:
	var q: QuestData = get_quest(id)
	return tr(q.title_key) if q != null else String(id)


## Şu anki hedefin metni + sayacı ("Çöp yığınlarını temizle (1/3)").
func get_quest_objective(id: StringName) -> String:
	var q: QuestData = get_quest(id)
	if q == null:
		return ""
	var prog: Array = _progress.get(id, []) as Array
	for i: int in range(q.objectives.size()):
		var o: Dictionary = q.objectives[i]
		var need: int = int(o.get("count", 1))
		var have: int = int(prog[i]) if i < prog.size() else 0
		if have < need:
			var text: String = tr(String(o.get("text_key", q.description_key)))
			if need > 1:
				text += " (%d/%d)" % [have, need]
			return text
	return tr("QUEST_DONE_SHORT")


func get_quest_summary(id: StringName) -> String:
	return get_quest_title(id) + "\n" + get_quest_objective(id)


func get_quest_progress_text(id: StringName) -> String:
	return get_quest_objective(id)


# ---------------------------------------------------------------- Diyalog

## Diyalog kaynağını döndürür: önce çalışma zamanı kayıtları, sonra data/dialogue/<id>.tres
func get_dialogue(id: StringName) -> DialogueData:
	if _runtime_dialogues.has(id):
		return _runtime_dialogues[id] as DialogueData
	if _dialogue_cache.has(id):
		return _dialogue_cache[id] as DialogueData
	var path: String = DIALOGUE_DIR + String(id) + ".tres"
	if not ResourceLoader.exists(path):
		return null
	var d: DialogueData = load(path) as DialogueData
	_dialogue_cache[id] = d
	return d


func has_dialogue(id: StringName) -> bool:
	return get_dialogue(id) != null


## Kodla üretilen (dinamik metinli) diyaloğu kaydeder. Satırlarda "text" hazır metin olabilir.
func register_runtime_dialogue(id: StringName, lines: Array[Dictionary]) -> void:
	var d := DialogueData.new()
	d.id = id
	d.lines = lines
	_runtime_dialogues[id] = d


## Diyalog açar; başka diyalog açıksa sıraya koyar.
func request_dialogue(id: StringName) -> void:
	if _dialogue_open:
		_dialogue_queue.append(id)
		return
	EventBus.dialogue_requested.emit(id)


func is_dialogue_busy() -> bool:
	return _dialogue_open or not _dialogue_queue.is_empty()


func _on_dialogue_requested(_id: StringName) -> void:
	_dialogue_open = true


func _on_dialogue_finished(_id: StringName) -> void:
	_dialogue_open = false
	if not _dialogue_queue.is_empty():
		call_deferred(&"_pop_dialogue")


func _pop_dialogue() -> void:
	if _dialogue_open or _dialogue_queue.is_empty():
		return
	var next_id: StringName = _dialogue_queue.pop_front()
	EventBus.dialogue_requested.emit(next_id)


## Bir NPC ile konuşulunca hangi diyaloğun açılacağını seçer.
func get_npc_dialogue(npc_id: StringName) -> StringName:
	var npc: String = String(npc_id)
	# 1) Muhtar borç defteri
	if npc_id == &"muhtar":
		if Economy.money < 0:
			return _build_debt_dialogue()
		var owed: int = _current_debt()
		if owed > 0 and Economy.money >= owed + 200:
			return _build_repay_dialogue()
	# 2) Aktif görevlerin NPC'ye bağlı hedefleri (ana hikâye önce)
	var ordered: Array[StringName] = _active.duplicate()
	ordered.sort_custom(func(a: StringName, b: StringName) -> bool:
		return get_quest(a).main_story and not get_quest(b).main_story)
	for id: StringName in ordered:
		var q: QuestData = get_quest(id)
		var prog: Array = _progress.get(id, []) as Array
		for i: int in range(q.objectives.size()):
			var o: Dictionary = q.objectives[i]
			if int(prog[i]) >= int(o.get("count", 1)):
				continue
			if q.sequential and i != _current_objective_index(id):
				continue
			if StringName(o.get("npc", &"")) == npc_id and StringName(o.get("dialogue", &"")) != &"":
				return StringName(o["dialogue"])
	# 3) Görev teklifleri
	for qid: Variant in _quests.keys():
		var q2: QuestData = _quests[qid] as QuestData
		if q2.giver != npc_id or q2.offer_dialogue == &"":
			continue
		if _active.has(q2.id) or _completed.has(q2.id):
			continue
		var ok: bool = true
		for r: StringName in q2.requires:
			if not _completed.has(r):
				ok = false
				break
		if ok:
			return q2.offer_dialogue
	# 4) Aktif görevlerin genel ipuçları
	for id: StringName in ordered:
		var q3: QuestData = get_quest(id)
		if q3.talk_dialogues.has(npc) or q3.talk_dialogues.has(npc_id):
			return StringName(q3.talk_dialogues.get(npc, q3.talk_dialogues.get(npc_id, &"")))
	# 5) Selamlama (Gaftî varyantı diyalog kutusunda gafti_lines ile seçilir)
	return StringName(npc + "_greet")


func _build_debt_dialogue() -> StringName:
	var amount: int = DEBT_CUSHION - Economy.money
	var lines: Array[Dictionary] = [
		{"speaker": &"muhtar", "text_key": "MUHTAR_DEBT_1"},
		{"speaker": &"muhtar", "text": tr("MUHTAR_DEBT_2") % amount},
		{"speaker": &"muhtar", "text_key": "MUHTAR_DEBT_3", "choices": [
			{"text_key": "MUHTAR_DEBT_ACCEPT", "next": 3, "action": "borrow:%d" % amount},
			{"text_key": "MUHTAR_DEBT_REFUSE", "next": 4, "action": ""},
		]},
		{"speaker": &"muhtar", "text_key": "MUHTAR_DEBT_4", "next": -1},
		{"speaker": &"muhtar", "text_key": "MUHTAR_DEBT_5", "next": -1},
	]
	register_runtime_dialogue(&"rt_muhtar_debt", lines)
	return &"rt_muhtar_debt"


func _build_repay_dialogue() -> StringName:
	var lines: Array[Dictionary] = [
		{"speaker": &"muhtar", "text": tr("MUHTAR_REPAY_1") % _current_debt(), "choices": [
			{"text_key": "MUHTAR_REPAY_YES", "next": 1, "action": "repay"},
			{"text_key": "MUHTAR_REPAY_NO", "next": 2, "action": ""},
		]},
		{"speaker": &"muhtar", "text_key": "MUHTAR_REPAY_2", "next": -1},
		{"speaker": &"muhtar", "text_key": "MUHTAR_REPAY_3", "next": -1},
	]
	register_runtime_dialogue(&"rt_muhtar_repay", lines)
	return &"rt_muhtar_repay"


## Diyalog eylemlerini çalıştırır. Birden çok eylem ";" ile ayrılır.
## event:<ad> | start:<görev> | complete:<görev> | give:<kind,kind>:<olay> | pay:<tutar>:<olay>
## gafti:<olay> | borrow:<tutar> | repay | upgrade_license | hardware | notify:<ANAHTAR> | rep:<x> | money:<x> | sfx:<id>
func run_action(action: String) -> void:
	for part: String in action.split(";", false):
		_run_single(part.strip_edges())


func _run_single(action: String) -> void:
	if action == "":
		return
	var p: PackedStringArray = action.split(":")
	var cmd: String = p[0]
	match cmd:
		"event":
			if p.size() > 1:
				notify_event(StringName(p[1]))
		"start":
			if p.size() > 1:
				start(StringName(p[1]))
		"complete":
			if p.size() > 1:
				complete(StringName(p[1]))
		"give":
			if p.size() > 2:
				_give_item(p[1].split(","), StringName(p[2]))
		"pay":
			if p.size() > 1:
				var amount: int = int(p[1])
				if Economy.spend(amount, "dialogue"):
					if p.size() > 2:
						notify_event(StringName(p[2]))
				else:
					EventBus.notify.emit(tr("QUEST_NO_MONEY"), &"bad")
		"gafti":
			if p.size() > 1:
				if _gafti_active():
					notify_event(StringName(p[1]))
				else:
					EventBus.notify.emit(tr("QUEST_NEED_GAFTI"), &"info")
		"borrow":
			if p.size() > 1:
				var b: int = int(p[1])
				if Economy.has_method(&"take_loan"):
					Economy.call(&"take_loan", b)
				else:
					Economy.add(b, "muhtar_borc")
				debt = _economy_debt() if Economy.has_method(&"take_loan") else debt + b
				notify_event(&"borrowed")
		"repay":
			var owed: int = _economy_debt() if Economy.has_method(&"repay_loan") else debt
			var paid: bool = false
			if Economy.has_method(&"repay_loan"):
				paid = owed > 0 and bool(Economy.call(&"repay_loan", owed))
			else:
				paid = owed > 0 and Economy.spend(owed, "muhtar_borc")
			if paid:
				debt = 0
				Reputation.add_reputation(1.0)
				notify_event(&"debt_repaid")
		"upgrade_license":
			if Reputation.has_method(&"upgrade_license"):
				var ok: bool = bool(Reputation.call(&"upgrade_license"))
				if not ok:
					EventBus.notify.emit(tr("QUEST_LICENSE_NOT_YET"), &"bad")
		"hardware":
			open_hardware_ui()
		"notify":
			if p.size() > 1:
				EventBus.notify.emit(tr(p[1]), &"info")
		"rep":
			if p.size() > 1:
				Reputation.add_reputation(float(p[1]))
		"money":
			if p.size() > 1:
				Economy.add(int(p[1]), "dialogue")
		"sfx":
			if p.size() > 1:
				_play_sfx(StringName(p[1]))
		_:
			push_warning("QuestManager: bilinmeyen eylem " + action)


func _give_item(kinds: PackedStringArray, event: StringName) -> void:
	for kind: String in kinds:
		var items: Array[Dictionary] = Inventory.get_items(StringName(kind))
		for it: Dictionary in items:
			if int(it.get("count", 0)) <= 0:
				continue
			if Inventory.remove_item(StringName(it.get("id", &"")), 1):
				notify_event(event, {"kind": StringName(kind), "item": it})
				EventBus.notify.emit(tr("QUEST_ITEM_GIVEN"), &"info")
				return
	EventBus.notify.emit(tr("QUEST_NEED_ITEM"), &"bad")


func open_hardware_ui() -> void:
	if not get_tree().get_nodes_in_group(&"hardware_ui").is_empty():
		return
	if not ResourceLoader.exists(HARDWARE_UI_SCENE):
		return
	var ui: Node = (load(HARDWARE_UI_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(ui)


# ---------------------------------------------------------------- Sinyal köprüleri

func _on_plant_harvested(plant_id: int, item: Dictionary) -> void:
	var d: Dictionary = item.duplicate()
	d["plant_id"] = plant_id
	notify_event(&"harvest", d)


func _on_sale_completed(amount: int, item: Dictionary, customer_type: StringName) -> void:
	notify_event(&"sale", {"amount": amount, "kind": item.get("kind", &""), "customer_type": customer_type, "quality": item.get("quality", 0)})


func _on_minigame_finished(id: StringName, result: Dictionary) -> void:
	if bool(result.get("cancelled", false)):
		return
	match id:
		&"rolling":
			notify_event(&"preroll_made", result)
		&"gravity_bong":
			notify_event(&"bong_used", result)
		&"care":
			notify_event(&"care_done", result)
		&"id_check":
			notify_event(&"id_checked", result)
		&"customize":
			notify_event(&"customized", result)
	notify_event(StringName("minigame_" + String(id)), result)


func _on_inspection_finished(score: int, fine: int) -> void:
	notify_event(&"inspection_done", {"score": score, "fine": fine})
	if score >= INSPECTION_PASS_SCORE:
		notify_event(&"inspection_passed", {"score": score})


func _on_day_started(day: int) -> void:
	_ensure_story_started()
	notify_event(&"day_started", {"day": day})


func _on_license_level_changed(level: int) -> void:
	notify_event(&"license_level", {"level": level})


# ---------------------------------------------------------------- Yardımcılar

## Muhtar borcu Economy.debt'te tutulur (varsa); yoksa yerel sayaç.
func _economy_debt() -> int:
	var v: Variant = Economy.get(&"debt")
	return int(v) if v != null else debt


func _current_debt() -> int:
	return _economy_debt()


func _gafti_active() -> bool:
	return bool(_get_prop(&"Effects", &"gafti_active", false))


func _get_prop(autoload_name: StringName, prop: StringName, fallback: Variant) -> Variant:
	var n: Node = get_node_or_null(NodePath("/root/" + String(autoload_name)))
	if n == null:
		return fallback
	var v: Variant = n.get(prop)
	return fallback if v == null else v


func _play_sfx(id: StringName) -> void:
	var am: Node = get_node_or_null(^"/root/AudioManager")
	if am != null and am.has_method(&"play_sfx"):
		am.call(&"play_sfx", id, null)


# ---------------------------------------------------------------- Kayıt

func get_save_data() -> Dictionary:
	var prog: Dictionary = {}
	for k: Variant in _progress.keys():
		prog[String(k)] = (_progress[k] as Array).duplicate()
	var act: Array[String] = []
	for a: StringName in _active:
		act.append(String(a))
	var comp: Array[String] = []
	for c: StringName in _completed:
		comp.append(String(c))
	return {"active": act, "completed": comp, "progress": prog, "debt": debt, "flags": flags.duplicate(true)}


func load_save_data(d: Dictionary) -> void:
	_active.clear()
	_completed.clear()
	_progress.clear()
	_dialogue_queue.clear()
	debt = int(d.get("debt", 0))
	flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	for c: Variant in d.get("completed", []) as Array:
		_completed.append(StringName(str(c)))
	var prog: Dictionary = d.get("progress", {}) as Dictionary
	for a: Variant in d.get("active", []) as Array:
		var id: StringName = StringName(str(a))
		var q: QuestData = get_quest(id)
		if q == null:
			continue
		_active.append(id)
		var arr: Array[int] = []
		var saved: Array = prog.get(String(id), []) as Array
		for i: int in range(q.objectives.size()):
			arr.append(int(saved[i]) if i < saved.size() else 0)
		_progress[id] = arr
	_story_started = not _active.is_empty() or not _completed.is_empty()
	if d.is_empty():
		_ensure_story_started()
