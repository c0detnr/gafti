class_name HardwareCounter
extends Node3D
## Hırdavatçı tezgahı: tohum/malzeme/ekipman satın alma arayüzünü açar (A'nın Catalog'u).

const MODEL: String = "res://assets/models/props/counter.glb"
@export var show_counter_model: bool = true


func _ready() -> void:
	if show_counter_model:
		var m: Node3D = ModelLoader.instance(MODEL, Vector3(1.6, 0.95, 0.6), Color(0.45, 0.32, 0.2))
		add_child(m)
	InteractArea.attach(self, Vector3(2.0, 2.0, 2.2), Vector3(0, 0, 0.6))


func get_interact_text() -> String:
	return tr("HARDWARE_INTERACT")


func interact(_player: Node) -> void:
	QuestManager.open_hardware_ui()
	QuestManager.notify_event(&"talk_hardware")
