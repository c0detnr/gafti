extends Node3D
## Test etkileşim nesnesi: her etkileşimde bildirim gösterir ve sayacı artırır.

var count: int = 0


func _ready() -> void:
	add_to_group(&"interactable")


func get_interact_text() -> String:
	return "Test kutusuna dokun (%d)" % count


func interact(_player: Node) -> void:
	count += 1
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		var kinds: Array[StringName] = [&"info", &"good", &"bad"]
		bus.emit_signal(&"notify", "Etkileşim %d" % count, kinds[count % 3])
