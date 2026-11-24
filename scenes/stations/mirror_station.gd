extends Node3D
## Ayna: karakter özelleştirme mini oyununu (&"customize") açar.
## Sahnede minigame_host yoksa özelleştirme ekranını doğrudan kaplama olarak açar.

const MODEL_PATH: String = "res://assets/models/props/mirror.glb"
const CUSTOMIZATION_SCENE: String = "res://scenes/ui/customization/customization.tscn"

@export var model_rotation_deg: float = 0.0

var _open_layer: CanvasLayer = null


func _ready() -> void:
	add_to_group(&"interactable")
	var area: Area3D = $InteractArea
	area.add_to_group(&"interactable")
	var model: Node3D = ModelLoader.instance(MODEL_PATH, Vector3(0.7, 1.8, 0.12), Color(0.75, 0.85, 0.9))
	model.rotation.y = deg_to_rad(model_rotation_deg)
	add_child(model)


func get_interact_text() -> String:
	return "" if _open_layer != null else tr("MIRROR_CUSTOMIZE")


func interact(_player: Node) -> void:
	if _open_layer != null:
		return
	var host: Node = get_tree().get_first_node_in_group(&"minigame_host")
	if host != null:
		var bus: Node = GaftiUI.autoload("EventBus")
		if bus != null:
			bus.emit_signal(&"minigame_requested", &"customize", {})
		return
	_open_fallback()


func _open_fallback() -> void:
	if not ResourceLoader.exists(CUSTOMIZATION_SCENE):
		return
	_open_layer = CanvasLayer.new()
	_open_layer.layer = 55
	get_tree().root.add_child(_open_layer)
	var c: Control = (load(CUSTOMIZATION_SCENE) as PackedScene).instantiate() as Control
	c.set(&"allow_cancel", true)
	c.set(&"block_input", true)
	c.connect(&"confirmed", _close_fallback.unbind(1))
	c.connect(&"cancelled", _close_fallback)
	_open_layer.add_child(c)


func _close_fallback() -> void:
	if _open_layer != null and is_instance_valid(_open_layer):
		_open_layer.queue_free()
	_open_layer = null
