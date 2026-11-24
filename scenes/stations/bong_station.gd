extends Node3D
## Seradaki kova bong köşesi (Ajan B). Etkileşim → EventBus.minigame_requested(&"gravity_bong").
## ContentFlags.consumption kapalıysa sadece dekor: komik bir yorum verir.

const M_BUCKET: String = "res://assets/models/hero/bong_bucket.glb"
const M_BOTTLE: String = "res://assets/models/hero/bong_bottle.glb"
const DECOR_KEYS: Array[String] = ["BONG_DECOR_1", "BONG_DECOR_2", "BONG_DECOR_3"]

@onready var visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"interactable")
	var bucket: Node3D = ModelLoader.instance(M_BUCKET, Vector3(0.32, 0.32, 0.32), Color(0.2, 0.45, 0.85))
	visual.add_child(bucket)
	var bottle: Node3D = ModelLoader.instance(M_BOTTLE, Vector3(0.1, 0.3, 0.1), Color(0.85, 0.95, 0.9))
	visual.add_child(bottle)
	bottle.position = Vector3(0, 0.08, 0)


func get_interact_text() -> String:
	if MinigameUtil.consumption_enabled():
		return tr("BONG_INTERACT")
	return tr("BONG_INTERACT_DECOR")


func interact(_player: Node) -> void:
	if not MinigameUtil.consumption_enabled():
		MinigameUtil.notify(tr(DECOR_KEYS[randi() % DECOR_KEYS.size()]), &"info")
		_wobble()
		return
	if MinigameUtil.has_inventory() and MinigameUtil.best_dry_bud(0.25).is_empty():
		MinigameUtil.notify(tr("BONG_NO_BUD"), &"bad")
		_wobble()
		return
	var bus: Node = MinigameUtil.autoload("EventBus")
	if bus != null:
		bus.emit_signal(&"minigame_requested", &"gravity_bong", {"station": get_path()})


func _wobble() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(visual, "rotation:z", 0.12, 0.08)
	tw.tween_property(visual, "rotation:z", -0.1, 0.1)
	tw.tween_property(visual, "rotation:z", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
