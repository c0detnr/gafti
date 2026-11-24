class_name QuestTrigger
extends Node3D
## Genel görev tetikleyicisi (ör. seradaki çöp yığınları → &"clean_greenhouse").
## Etkileşince QuestManager.notify_event(event) çağırır. required_quest aktif değilse gizlenir.

@export var event: StringName = &"clean_greenhouse"
## Boşsa her zaman görünür/etkin.
@export var required_quest: StringName = &"q_clean_greenhouse"
@export var text_key: String = "TRIGGER_CLEAN"
@export var one_shot: bool = true
@export_file("*.glb") var model_path: String = ""
@export var placeholder_size: Vector3 = Vector3(0.8, 0.5, 0.8)
@export var placeholder_color: Color = Color(0.4, 0.35, 0.25)
@export var sfx: StringName = &"trash"

var done: bool = false
var _area: InteractArea = null


func _ready() -> void:
	add_to_group(&"persist")
	var m: Node3D = ModelLoader.instance(model_path, placeholder_size, placeholder_color) if model_path != "" else ModelLoader.placeholder(placeholder_size, placeholder_color, "trigger")
	add_child(m)
	_area = InteractArea.attach(self, placeholder_size + Vector3(0.8, 1.2, 0.8))
	QuestManager.quest_started.connect(func(_id: StringName) -> void: _refresh())
	QuestManager.quest_completed.connect(func(_id: StringName) -> void: _refresh())
	_refresh.call_deferred()


func _is_enabled() -> bool:
	if done and one_shot:
		return false
	return required_quest == &"" or QuestManager.is_active(required_quest)


func _refresh() -> void:
	var on: bool = _is_enabled()
	visible = on
	_area.collision_layer = (1 << 3) if on else 0


func get_interact_text() -> String:
	return tr(text_key) if _is_enabled() else ""


func interact(_player: Node) -> void:
	if not _is_enabled():
		return
	if one_shot:
		done = true
	QuestManager.notify_event(event, {"source": String(name)})
	var am: Node = get_node_or_null(^"/root/AudioManager")
	if am != null and am.has_method(&"play_sfx"):
		am.call(&"play_sfx", sfx, global_position)
	_refresh()


func get_save_id() -> String:
	return "quest_trigger_" + String(get_path())


func get_save_data() -> Dictionary:
	return {"done": done}


func load_save_data(d: Dictionary) -> void:
	done = bool(d.get("done", false))
	_refresh()
