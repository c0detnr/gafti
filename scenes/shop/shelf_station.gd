class_name ShelfStation
extends Node3D
## Dükkan rafı: envanterden kavanoz / pre-roll / 5 g paket yerleştir, fiyat ve etiket belirle.
## Etkileşim (AGENTS §5): rafa yaklaşıp E → ShelfUI açılır. Raf yüzü yerel +Z yönündedir.

const SHELF_MODEL: String = "res://assets/models/props/shelf_shop.glb"
const JAR_MODEL: String = "res://assets/models/props/jar.glb"
const JOINT_MODEL: String = "res://assets/models/hero/joint.glb"
const SELLABLE_KINDS: Array[StringName] = [&"jar", &"preroll", &"dry_bud"]
## Gevşek tomurcuk raf paketi (gram).
const BAG_GRAMS: int = 5

@export var slot_count: int = 4
## Raf genişliği (slot yerleşimi için, metre).
@export var width: float = 1.2

## Slot: { "item": Dictionary (birim ürün), "price": int, "labeled": bool, "reserved_by": int, "taken": int }
var slots: Array[Dictionary] = []

var _slot_visuals: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"shop_shelf")
	var m: Node3D = ModelLoader.instance(SHELF_MODEL, Vector3(width, 1.8, 0.45), Color(0.55, 0.38, 0.22))
	m.name = "ShelfModel"
	add_child(m)
	_add_collider()
	for i: int in range(slot_count):
		slots.append(_empty_slot())
		_slot_visuals.append(null)
	InteractArea.attach(self, Vector3(width + 0.4, 2.0, 1.6), Vector3(0, 0, 0.5))


func _add_collider() -> void:
	var body := StaticBody3D.new()
	body.name = "Collider"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.8, 0.45)
	cs.shape = box
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	add_child(body)


func _empty_slot() -> Dictionary:
	return {"item": {}, "price": 0, "labeled": false, "reserved_by": 0, "taken": 0}


# ---------------------------------------------------------------- Etkileşim

func get_interact_text() -> String:
	return tr("SHELF_INTERACT") % [stocked_count(), slots.size()]


func interact(_player: Node) -> void:
	if not get_tree().get_nodes_in_group(&"shelf_ui").is_empty():
		return
	var ui := ShelfUI.new()
	ui.shelf = self
	get_tree().root.add_child(ui)


# ---------------------------------------------------------------- Stok API

func stocked_count() -> int:
	var n: int = 0
	for s: Dictionary in slots:
		if not (s.get("item", {}) as Dictionary).is_empty():
			n += 1
	return n


func first_empty_slot() -> int:
	for i: int in range(slots.size()):
		if (slots[i].get("item", {}) as Dictionary).is_empty():
			return i
	return -1


## Envanter eşyasından bir birim rafa koyar. Başarılıysa slot indeksi, değilse -1.
func stock_from_inventory(inv_item: Dictionary, slot_i: int = -1) -> int:
	var i: int = slot_i if slot_i >= 0 else first_empty_slot()
	if i < 0 or i >= slots.size() or not (slots[i].get("item", {}) as Dictionary).is_empty():
		return -1
	var kind: StringName = StringName(inv_item.get("kind", &""))
	if not SELLABLE_KINDS.has(kind):
		return -1
	var take: int = BAG_GRAMS if kind == &"dry_bud" else 1
	if int(inv_item.get("count", 0)) < take:
		EventBus.notify.emit(tr("SHELF_NEED_GRAMS") % BAG_GRAMS, &"bad")
		return -1
	if not Inventory.remove_item(StringName(inv_item.get("id", &"")), take):
		return -1
	var unit: Dictionary = inv_item.duplicate(true)
	unit["count"] = 1
	if kind == &"dry_bud":
		unit["grams"] = float(BAG_GRAMS)
	slots[i] = {"item": unit, "price": 0, "labeled": false, "reserved_by": 0, "taken": take}
	slots[i]["price"] = fair_price(i)
	_refresh_visual(i)
	QuestManager.notify_event(&"shelf_stocked", {"kind": kind})
	return i


## Raftaki birimi envantere geri koyar.
func unstock(i: int) -> void:
	if i < 0 or i >= slots.size():
		return
	var item: Dictionary = slots[i].get("item", {}) as Dictionary
	if item.is_empty() or int(slots[i].get("reserved_by", 0)) != 0:
		return
	var back: Dictionary = item.duplicate(true)
	var taken: int = int(slots[i].get("taken", 1))
	back["count"] = taken
	if StringName(back.get("kind", &"")) == &"dry_bud":
		back["grams"] = 1.0
	Inventory.add_item(back)
	slots[i] = _empty_slot()
	_refresh_visual(i)


## Satış: birimi raftan çıkarır ve döndürür.
func take(i: int) -> Dictionary:
	if i < 0 or i >= slots.size():
		return {}
	var item: Dictionary = (slots[i].get("item", {}) as Dictionary).duplicate(true)
	slots[i] = _empty_slot()
	_refresh_visual(i)
	return item


func set_price(i: int, price: int) -> void:
	if i >= 0 and i < slots.size():
		slots[i]["price"] = maxi(1, price)


func set_labeled(i: int, v: bool) -> void:
	if i >= 0 and i < slots.size():
		slots[i]["labeled"] = v
		if v:
			QuestManager.notify_event(&"shelf_labeled")


func reserve(i: int, customer_id: int) -> void:
	if i >= 0 and i < slots.size():
		slots[i]["reserved_by"] = customer_id


func release(i: int) -> void:
	if i >= 0 and i < slots.size():
		slots[i]["reserved_by"] = 0


## Adil fiyat (Economy.get_item_value varsa onu kullanır).
func fair_price(i: int) -> int:
	var item: Dictionary = slots[i].get("item", {}) as Dictionary
	if item.is_empty():
		return 0
	if Economy.has_method(&"get_item_value"):
		return maxi(1, int(Economy.call(&"get_item_value", item)))
	var mult: float = 1.6 if StringName(item.get("kind", &"")) == &"preroll" else 1.0
	return maxi(1, int(30.0 * float(item.get("grams", 1.0)) * mult * (0.4 + float(item.get("quality", 50)) / 100.0 * 1.2)))


func slot_world_position(i: int) -> Vector3:
	return to_global(_slot_local(i))


func _slot_local(i: int) -> Vector3:
	var step: float = width / float(maxi(1, slot_count))
	var x: float = -width * 0.5 + step * (float(i) + 0.5)
	return Vector3(x, 1.02, 0.02)


func _refresh_visual(i: int) -> void:
	if _slot_visuals[i] != null and is_instance_valid(_slot_visuals[i]):
		_slot_visuals[i].queue_free()
	_slot_visuals[i] = null
	var item: Dictionary = slots[i].get("item", {}) as Dictionary
	if item.is_empty():
		return
	var v: Node3D
	if StringName(item.get("kind", &"")) == &"preroll":
		v = ModelLoader.instance(JOINT_MODEL, Vector3(0.1, 0.02, 0.02), Color(0.95, 0.92, 0.85))
	elif StringName(item.get("kind", &"")) == &"dry_bud":
		v = ModelLoader.placeholder(Vector3(0.14, 0.1, 0.1), Color(0.35, 0.55, 0.25), "bag")
	else:
		v = ModelLoader.instance(JAR_MODEL, Vector3(0.12, 0.16, 0.12), Color(0.7, 0.85, 0.75))
	v.position = _slot_local(i)
	add_child(v)
	_slot_visuals[i] = v


# ---------------------------------------------------------------- Kayıt

func get_slots_save() -> Array:
	var out: Array = []
	for s: Dictionary in slots:
		var c: Dictionary = s.duplicate(true)
		c["reserved_by"] = 0
		out.append(c)
	return out


func load_slots_save(arr: Array) -> void:
	for i: int in range(mini(arr.size(), slots.size())):
		var s: Dictionary = (arr[i] as Dictionary).duplicate(true)
		s["reserved_by"] = 0
		var item: Dictionary = s.get("item", {}) as Dictionary
		if item.has("id"):
			item["id"] = StringName(str(item["id"]))
			item["kind"] = StringName(str(item.get("kind", "")))
			item["strain"] = StringName(str(item.get("strain", "")))
		slots[i] = s
		_refresh_visual(i)
