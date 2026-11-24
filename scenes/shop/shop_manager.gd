class_name ShopManager
extends Node3D
## GAFTİ dükkanı iç düzeninin kökü (bina orijininde, kapı +Z). Açılış saatleri, raf teklifleri, kasa kuyruğu,
## kimlik kontrolü → satış akışı. GDD §5.6. Sahne: scenes/shop/shop_interior.tscn

signal shop_opened()
signal shop_closed()
signal queue_changed()

const OPEN_HOUR: int = 16
const CLOSE_HOUR: int = 22
const ID_CHECK_SCENE: String = "res://scenes/minigames/id_check/id_check.tscn"
const QUEUE_SPACING: float = 0.9

var is_open: bool = false
## Test/hikâye için saat kısıtını kaldırır.
@export var ignore_hours: bool = false

var _queue: Array[Node] = []
var _checkout: Node = null
var _local_id_check: Node = null


func _ready() -> void:
	add_to_group(&"shop")
	add_to_group(&"persist")
	EventBus.minigame_finished.connect(_on_minigame_finished)
	var clock: Node = get_node_or_null(^"/root/GameClock")
	if clock != null:
		clock.connect(&"hour_passed", _on_hour_passed)


# ---------------------------------------------------------------- Açma / kapama

func can_open_now() -> bool:
	if ignore_hours:
		return true
	return GameClock.hour >= OPEN_HOUR and GameClock.hour < CLOSE_HOUR


func open_shop() -> bool:
	if is_open:
		return true
	if Reputation.has_method(&"is_shop_closed") and bool(Reputation.call(&"is_shop_closed")):
		EventBus.notify.emit(tr("SHOP_CLOSED_BY_INSPECTION"), &"bad")
		return false
	if not can_open_now():
		EventBus.notify.emit(tr("SHOP_HOURS") % [OPEN_HOUR, CLOSE_HOUR], &"info")
		return false
	is_open = true
	shop_opened.emit()
	EventBus.notify.emit(tr("SHOP_OPENED"), &"good")
	QuestManager.notify_event(&"shop_opened")
	_sfx(&"shop_bell")
	return true


func close_shop() -> void:
	if not is_open:
		return
	is_open = false
	shop_closed.emit()
	EventBus.notify.emit(tr("SHOP_CLOSED"), &"info")
	QuestManager.notify_event(&"shop_closed")
	for c: Node in get_customers():
		if c != _checkout and c.has_method(&"leave"):
			c.call(&"leave", "CUST_SHOP_CLOSING")


func _on_hour_passed(hour: int) -> void:
	if is_open and not ignore_hours and (hour >= CLOSE_HOUR or hour < OPEN_HOUR):
		close_shop()


# ---------------------------------------------------------------- Raflar

func get_shelves() -> Array[ShelfStation]:
	var out: Array[ShelfStation] = []
	for n: Node in find_children("*", "Node3D", true, false):
		if n is ShelfStation:
			out.append(n as ShelfStation)
	return out


func has_stock() -> bool:
	for s: ShelfStation in get_shelves():
		if s.stocked_count() > 0:
			return true
	return false


## Müşteri profiline en uygun raf teklifini bulur ve ayırır. Boş sözlük = uygun ürün yok.
## Dönen: { shelf, slot, price, item, pref, quality_fit, price_fit, score }
func find_best_offer(profile: CustomerProfile, budget: int, customer: Node) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -1.0
	for shelf: ShelfStation in get_shelves():
		for i: int in range(shelf.slots.size()):
			var slot: Dictionary = shelf.slots[i]
			var item: Dictionary = slot.get("item", {}) as Dictionary
			if item.is_empty() or slot.get("reserved_by", 0) != 0:
				continue
			var price: int = int(slot.get("price", 0))
			if price <= 0 or price > budget:
				continue
			var kind: StringName = StringName(item.get("kind", &""))
			var pref: float = 0.2
			var idx: int = profile.preferred_kinds.find(kind)
			if idx == 0:
				pref = 1.0
			elif idx == 1:
				pref = 0.7
			elif idx >= 2:
				pref = 0.5
			var q: int = int(item.get("quality", 50))
			if q < profile.min_quality:
				continue
			var quality_fit: float = clampf(float(q - profile.min_quality) / maxf(1.0, float(profile.love_quality - profile.min_quality)), 0.0, 1.0)
			var fair: int = shelf.fair_price(i)
			var ratio: float = float(price) / maxf(1.0, float(fair))
			if ratio > profile.price_tolerance:
				continue
			var price_fit: float = clampf(1.5 - ratio, 0.0, 1.0)
			var score: float = pref * 0.5 + quality_fit * 0.3 + price_fit * 0.2
			if profile.wants_rare and (bool(item.get("mutation", false)) or StringName(item.get("strain", &"")) == &"gafti"):
				score += 0.3
			score += randf() * 0.05
			if score > best_score:
				best_score = score
				best = {"shelf": shelf, "slot": i, "price": price, "item": item.duplicate(true),
					"pref": pref, "quality_fit": quality_fit, "price_fit": price_fit, "score": score}
	if not best.is_empty():
		(best["shelf"] as ShelfStation).reserve(int(best["slot"]), customer.get_instance_id())
	return best


## Dükkandaki raf etiketleme oranı (denetim için). Raf boşsa 1.0.
func get_label_ratio() -> float:
	var total: int = 0
	var labeled: int = 0
	for s: ShelfStation in get_shelves():
		for slot: Dictionary in s.slots:
			if not (slot.get("item", {}) as Dictionary).is_empty():
				total += 1
				if bool(slot.get("labeled", false)):
					labeled += 1
	return 1.0 if total == 0 else float(labeled) / float(total)


# ---------------------------------------------------------------- Kuyruk

func get_customers() -> Array[Node]:
	var out: Array[Node] = []
	for c: Node in get_tree().get_nodes_in_group(&"shop_customer"):
		if c.get(&"shop") == self:
			out.append(c)
	return out


func join_queue(c: Node) -> int:
	if not _queue.has(c):
		_queue.append(c)
	queue_changed.emit()
	return _queue.find(c)


func leave_queue(c: Node) -> void:
	_queue.erase(c)
	if _checkout == c:
		_checkout = null
	for other: Node in _queue:
		if is_instance_valid(other) and other.has_method(&"update_queue_target"):
			other.call(&"update_queue_target")
	queue_changed.emit()


func queue_index(c: Node) -> int:
	return _queue.find(c)


func queue_position(index: int) -> Vector3:
	var spot: Node3D = get_node_or_null(^"Markers/QueueSpot") as Node3D
	var base: Vector3 = spot.global_position if spot != null else global_position
	return base + global_transform.basis.z.normalized() * QUEUE_SPACING * float(index)


func marker(name_: String) -> Vector3:
	var m: Node3D = get_node_or_null(NodePath("Markers/" + name_)) as Node3D
	return m.global_position if m != null else global_position


## Kasada bekleyen ilk müşteri.
func waiting_customer() -> Node:
	if _checkout != null and is_instance_valid(_checkout):
		return null
	for c: Node in _queue:
		if is_instance_valid(c) and bool(c.call(&"is_waiting_at_counter")):
			return c
	return null


func is_checkout_busy() -> bool:
	return _checkout != null and is_instance_valid(_checkout)


# ---------------------------------------------------------------- Kasa → kimlik → satış

## Kasadan çağrılır: sıradaki müşteri için kimlik kontrolü açar.
func serve_next(_player: Node = null) -> bool:
	var c: Node = waiting_customer()
	if c == null:
		return false
	_checkout = c
	c.call(&"begin_checkout")
	var ctx: Dictionary = (c.get(&"card") as Dictionary).duplicate(true)
	ctx["customer_id"] = c.get_instance_id()
	ctx["customer_type"] = (c.get(&"profile") as CustomerProfile).type if c.get(&"profile") != null else &"kid"
	ctx["today_year"] = ShopCustomer.GAME_YEAR
	if get_tree().get_nodes_in_group(&"minigame_host").is_empty():
		_open_local_id_check(ctx)
	else:
		EventBus.minigame_requested.emit(&"id_check", ctx)
	return true


## Mini oyun sunucusu yoksa (test sahnesi) kimlik kontrolünü kendimiz açar ve sonucu yayarız.
func _open_local_id_check(ctx: Dictionary) -> void:
	if not ResourceLoader.exists(ID_CHECK_SCENE):
		EventBus.minigame_finished.emit(&"id_check", {"approved": true, "correct": true, "skipped": true, "customer_id": ctx["customer_id"]})
		return
	_local_id_check = (load(ID_CHECK_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(_local_id_check)
	EventBus.ui_block_input.emit(true)
	_local_id_check.connect(&"finished", _on_local_id_check_finished)
	_local_id_check.call(&"start", ctx)


func _on_local_id_check_finished(result: Dictionary) -> void:
	if _local_id_check != null and is_instance_valid(_local_id_check):
		_local_id_check.queue_free()
	_local_id_check = null
	EventBus.ui_block_input.emit(false)
	EventBus.minigame_finished.emit(&"id_check", result)


func _on_minigame_finished(id: StringName, result: Dictionary) -> void:
	if id != &"id_check":
		return
	var c: Node = _checkout
	if c == null or not is_instance_valid(c):
		_checkout = null
		return
	if int(result.get("customer_id", 0)) != c.get_instance_id():
		return
	if bool(result.get("cancelled", false)):
		_checkout = null
		c.call(&"cancel_checkout")
		return
	_resolve(c, result)


func _resolve(c: Node, result: Dictionary) -> void:
	var approved: bool = bool(result.get("approved", false))
	var skipped: bool = bool(result.get("skipped", false))
	var correct: bool = bool(result.get("correct", false))
	var card: Dictionary = c.get(&"card") as Dictionary
	var offer: Dictionary = c.get(&"offer") as Dictionary
	_checkout = null
	if bool(card.get("minor", false)):
		# Reşit olmayan: ASLA satış yok. Onaylanırsa/atlanırsa çocuk kaçar, itibar düşer.
		if approved or skipped:
			Reputation.add_reputation(-1.5)
			EventBus.notify.emit(tr("SHOP_MINOR_WARNING"), &"bad")
			c.call(&"finish", "CUST_KID_RUN", false)
		else:
			Reputation.add_reputation(0.3)
			c.call(&"finish", "CUST_KID_BUSTED", false)
		return
	if not approved and not skipped:
		_release_offer(offer)
		if correct:
			c.call(&"finish", "CUST_REJECT_FAIR", false)
		else:
			Reputation.add_reputation(-0.5)
			c.call(&"finish", "CUST_REJECT_ANGRY", false)
		return
	# Onaylandı ya da kontrol atlandı → satış.
	_complete_sale(c, offer)


func _complete_sale(c: Node, offer: Dictionary) -> void:
	if offer.is_empty():
		c.call(&"finish", "CUST_NOTHING", false)
		return
	var shelf: ShelfStation = offer.get("shelf", null) as ShelfStation
	var slot_i: int = int(offer.get("slot", -1))
	if shelf == null or not is_instance_valid(shelf) or (shelf.slots[slot_i].get("item", {}) as Dictionary).is_empty():
		c.call(&"finish", "CUST_NOTHING", false)
		return
	var price: int = int(shelf.slots[slot_i].get("price", 0))
	var item: Dictionary = shelf.take(slot_i)
	var profile: CustomerProfile = c.get(&"profile") as CustomerProfile
	Economy.add(price, tr("SHOP_SALE_REASON"))
	EventBus.sale_completed.emit(price, item, profile.type)
	var sat: float = float(offer.get("pref", 0.5)) * 0.4 + float(offer.get("quality_fit", 0.5)) * 0.3 + float(offer.get("price_fit", 0.5)) * 0.3
	if _gafti():
		sat += 0.05
	var rep: float = (sat - 0.45) * 2.0 * profile.reputation_scale
	Reputation.add_reputation(rep)
	_sfx(&"cash_register")
	var line: String = "_HAPPY" if sat >= 0.55 else "_OK"
	c.call(&"finish", profile.line_prefix + line, true)


func _release_offer(offer: Dictionary) -> void:
	if offer.is_empty():
		return
	var shelf: ShelfStation = offer.get("shelf", null) as ShelfStation
	if shelf != null and is_instance_valid(shelf):
		shelf.release(int(offer.get("slot", -1)))


func _gafti() -> bool:
	var fx: Node = get_node_or_null(^"/root/Effects")
	return fx != null and bool(fx.get(&"gafti_active"))


func _sfx(id: StringName) -> void:
	var am: Node = get_node_or_null(^"/root/AudioManager")
	if am != null and am.has_method(&"play_sfx"):
		am.call(&"play_sfx", id, global_position)


# ---------------------------------------------------------------- Kayıt (persist)

func get_save_id() -> String:
	return "shop_" + String(name)


func get_save_data() -> Dictionary:
	var shelves: Dictionary = {}
	for s: ShelfStation in get_shelves():
		shelves[String(s.name)] = s.get_slots_save()
	return {"is_open": is_open, "shelves": shelves}


func load_save_data(d: Dictionary) -> void:
	is_open = bool(d.get("is_open", false))
	var shelves: Dictionary = d.get("shelves", {}) as Dictionary
	for s: ShelfStation in get_shelves():
		if shelves.has(String(s.name)):
			s.load_slots_save(shelves[String(s.name)] as Array)
