class_name WaterTankStation
extends StationBase
## Su deposu (dere kenarı / sera): sulama kabını doldurur (bedava; taşımak emek ister).

const MODEL: String = "res://assets/models/props/water_tank.glb"


func _ready() -> void:
	super._ready()
	var m: Node3D = ModelLoader.instance(MODEL, Vector3(0.9, 1.3, 0.9), Color(0.3, 0.45, 0.6))
	m.name = "Model"
	add_child(m)


func get_interact_text() -> String:
	return tr("TANK_PROMPT") % [Inventory.count_of(Inventory.WATER_ID), Inventory.WATER_CAN_CAPACITY]


func interact(_player: Node) -> void:
	fill_can()


## Sulama kabını tam kapasiteye doldurur. Kap yoksa false.
func fill_can() -> bool:
	if Inventory.count_of(Inventory.WATER_CAN_ID) <= 0:
		notify(tr("TANK_NO_CAN"), &"bad")
		return false
	var cap: int = Inventory.WATER_CAN_CAPACITY * Inventory.count_of(Inventory.WATER_CAN_ID)
	var missing: int = cap - Inventory.count_of(Inventory.WATER_ID)
	if missing <= 0:
		notify(tr("TANK_ALREADY_FULL"), &"info")
		return false
	Inventory.add_item({"id": Inventory.WATER_ID, "kind": &"tool", "count": missing})
	play_sfx(&"water_fill")
	notify(tr("TANK_FILLED"), &"good")
	return true
