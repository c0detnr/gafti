class_name ShopCustomer
extends Node3D
## Dükkan müşterisi: kapıdan girer → rafa gider → ürün seçer → kasada bekler → kimlik/satış → çıkar.
## Hareket düz çizgi yol noktalarıyla (dükkan içi küçük, navmesh gerekmez).

enum State { ENTER, BROWSE, TO_QUEUE, WAIT, CHECKOUT, LEAVE }

const WALK_SPEED: float = 1.5
const BROWSE_SEC: float = 2.5
const BUBBLE_SEC: float = 3.5
## Kimlik kartlarındaki "bugün" yılı.
const GAME_YEAR: int = 2026

var shop: ShopManager = null
var profile: CustomerProfile = null
var card: Dictionary = {}
var look: Dictionary = {}
var budget: int = 100
var offer: Dictionary = {}
var state: State = State.ENTER

var _path: Array[Vector3] = []
var _patience: float = 45.0
var _browse_t: float = 0.0
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _bubble: Label3D = null
var _bubble_t: float = 0.0
var _browse_shelf: ShelfStation = null


func _ready() -> void:
	add_to_group(&"shop_customer")
	_model = CharacterDresser.build(look)
	add_child(_model)
	_anim = CharacterDresser.find_anim_player(_model)
	_bubble = Label3D.new()
	_bubble.position = Vector3(0, 2.25 * float(look.get("scale", 1.0)), 0)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 36
	_bubble.outline_size = 12
	_bubble.pixel_size = 0.004
	_bubble.width = 600.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.visible = false
	add_child(_bubble)
	var mult: float = 1.0
	var fx: Node = get_node_or_null(^"/root/Effects")
	if fx != null and fx.has_method(&"get_customer_patience_multiplier"):
		mult = float(fx.call(&"get_customer_patience_multiplier"))
	_patience = (profile.patience_sec if profile != null else 40.0) * mult
	_path = [shop.marker("DoorOutside"), shop.marker("DoorInside")]
	state = State.ENTER
	say(_hello_key())


func _hello_key() -> String:
	if bool(card.get("minor", false)):
		return "CUST_KID_HELLO"
	if String(card.get("variant", "")) == "hans":
		return "CUST_HANS_HELLO"
	return profile.line_prefix + "_HELLO_%d" % randi_range(1, 3)


func is_minor() -> bool:
	return bool(card.get("minor", false))


# ---------------------------------------------------------------- Konuşma balonu

func say(key: String) -> void:
	_bubble.text = tr(key)
	_bubble.visible = true
	_bubble_t = BUBBLE_SEC


# ---------------------------------------------------------------- Durum makinesi

func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.visible = false
	if not _path.is_empty():
		_walk(delta)
		return
	match state:
		State.ENTER:
			_start_browse()
		State.BROWSE:
			_browse_t -= delta
			if _browse_t <= 0.0:
				_choose()
		State.TO_QUEUE:
			state = State.WAIT
			_play("idle")
			_face_dir(shop.global_transform.basis.x)
		State.WAIT:
			_patience -= delta
			if _patience <= 0.0:
				Reputation.add_reputation(-0.5)
				_drop_offer()
				leave("CUST_IMPATIENT")
			elif _patience < 10.0 and _bubble_t <= 0.0 and randf() < 0.01:
				say("CUST_HURRY")
		State.LEAVE:
			shop.leave_queue(self)
			queue_free()
		_:
			pass


func _walk(delta: float) -> void:
	var target: Vector3 = _path[0]
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() < 0.08:
		global_position = Vector3(target.x, global_position.y, target.z)
		_path.pop_front()
		if _path.is_empty():
			_play("idle")
		return
	var step: float = minf(WALK_SPEED * delta, to.length())
	global_position += to.normalized() * step
	_face_dir(to)
	_play("walk")


func _face_dir(dir: Vector3) -> void:
	if _model != null and dir.length() > 0.01:
		_model.global_rotation.y = atan2(dir.x, dir.z)


func _play(anim: String) -> void:
	CharacterDresser.play_anim(_anim, anim)


func _start_browse() -> void:
	state = State.BROWSE
	_browse_t = BROWSE_SEC
	var shelves: Array[ShelfStation] = shop.get_shelves()
	if shelves.is_empty() or is_minor():
		_browse_t = 0.5
		return
	_browse_shelf = shelves[randi() % shelves.size()]
	var front: Vector3 = _browse_shelf.global_position + _browse_shelf.global_transform.basis.z.normalized() * 0.9
	_path = [front]


func _choose() -> void:
	if is_minor():
		say("CUST_KID_WANTS")
		_go_queue()
		return
	offer = shop.find_best_offer(profile, budget, self)
	if offer.is_empty():
		var key: String = "CUST_NOTHING" if shop.has_stock() else "CUST_EMPTY_SHELVES"
		Reputation.add_reputation(-0.1)
		leave(key)
		return
	say(profile.line_prefix + "_PICK")
	_play("interact")
	_go_queue()


func _go_queue() -> void:
	var idx: int = shop.join_queue(self)
	state = State.TO_QUEUE
	_path = [shop.queue_position(idx)]


## Önündeki müşteri ayrılınca kuyrukta ilerler.
func update_queue_target() -> void:
	if state != State.WAIT and state != State.TO_QUEUE:
		return
	var idx: int = shop.queue_index(self)
	if idx < 0:
		return
	state = State.TO_QUEUE
	_path = [shop.queue_position(idx)]


func is_waiting_at_counter() -> bool:
	return state == State.WAIT and shop.queue_index(self) == 0


func begin_checkout() -> void:
	state = State.CHECKOUT
	say("CUST_SHOW_ID" if not is_minor() else "CUST_KID_SHOW_ID")


func cancel_checkout() -> void:
	state = State.WAIT


## Satış/ret sonucu: konuş ve çık.
func finish(line_key: String, bought: bool) -> void:
	if bought:
		_play("wave")
	leave(line_key)


func leave(line_key: String = "") -> void:
	if state == State.LEAVE and _path.size() > 0:
		return
	_drop_offer()
	if line_key != "":
		say(line_key)
	shop.leave_queue(self)
	state = State.LEAVE
	_path = [shop.marker("DoorInside"), shop.marker("DoorOutside"), shop.marker("ExitSpawn")]


func _drop_offer() -> void:
	if offer.is_empty():
		return
	var shelf: ShelfStation = offer.get("shelf", null) as ShelfStation
	if shelf != null and is_instance_valid(shelf):
		var i: int = int(offer.get("slot", -1))
		if i >= 0 and int(shelf.slots[i].get("reserved_by", 0)) == get_instance_id():
			shelf.release(i)
	offer = {}
