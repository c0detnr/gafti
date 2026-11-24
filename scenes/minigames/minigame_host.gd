extends CanvasLayer
## Mini oyun sunucusu (Ajan B). EventBus.minigame_requested dinler, sahneyi bu katmanda açar,
## oyuncu girdisini kilitler, bitince EventBus.minigame_finished yayar ve kilidi açar.
## Protokol (sahne tarafı, hepsi isteğe bağlı):
##   setup(context) ya da start(context)  → add_child sonrası çağrılır
##   signal finished(result: Dictionary)  → host kapatır ve minigame_finished yayar
##   Sahne EventBus.minigame_finished'ı kendisi yayıp queue_free olursa host tekrar yaymaz.

const SCENES: Dictionary = {
	&"rolling": "res://scenes/minigames/rolling/rolling.tscn",
	&"gravity_bong": "res://scenes/minigames/gravity_bong/gravity_bong.tscn",
	&"care": "res://scenes/minigames/care/care.tscn",
	&"id_check": "res://scenes/minigames/id_check/id_check.tscn",
	&"customize": "res://scenes/ui/customization/customization.tscn",
}

var current_id: StringName = &""
var current: Node = null

var _emitting: bool = false
var _closed_by_scene: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _fade: ColorRect = null


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"minigame_host")
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var bus: Node = MinigameUtil.autoload("EventBus")
	if bus != null:
		bus.connect(&"minigame_requested", _on_requested)
		bus.connect(&"minigame_finished", _on_bus_finished)


func is_busy() -> bool:
	return current != null and is_instance_valid(current)


func open(id: StringName, context: Dictionary = {}) -> void:
	_on_requested(id, context)


func _on_requested(id: StringName, context: Dictionary) -> void:
	if is_busy():
		MinigameUtil.notify(tr("MG_BUSY"), &"info")
		return
	if id == &"gravity_bong" and not MinigameUtil.consumption_enabled():
		MinigameUtil.notify(tr("BONG_DECOR_ONLY"), &"info")
		_emit_finished(id, {"cancelled": true, "decor": true})
		return
	var path: String = String(SCENES.get(id, ""))
	if path == "" or not ResourceLoader.exists(path):
		MinigameUtil.notify(MinigameUtil.fmt(tr("MG_MISSING"), String(id)), &"bad")
		_emit_finished(id, {"cancelled": true, "missing": true})
		return
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		_emit_finished(id, {"cancelled": true, "missing": true})
		return
	var inst: Node = ps.instantiate()
	current = inst
	current_id = id
	_closed_by_scene = false
	_set_block(true)
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if inst.has_signal(&"finished"):
		inst.connect(&"finished", _on_scene_finished.bind(inst))
	inst.tree_exited.connect(_on_scene_exited.bind(inst))
	add_child(inst)
	move_child(_fade, -1)
	if inst.has_method(&"setup"):
		inst.call(&"setup", context)
	elif inst.has_method(&"start"):
		inst.call(&"start", context)
	MinigameUtil.sfx(&"ui_open")
	# Yumuşak giriş
	if inst is CanvasItem:
		var ci: CanvasItem = inst as CanvasItem
		ci.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(ci, "modulate:a", 1.0, 0.35)


func _on_scene_finished(result: Dictionary, inst: Node) -> void:
	if inst != current:
		return
	var id: StringName = current_id
	_close_current()
	_emit_finished(id, result)


## Sahne minigame_finished'ı kendisi yaydıysa (ör. customize) sadece kapat.
func _on_bus_finished(id: StringName, _result: Dictionary) -> void:
	if _emitting or not is_busy() or id != current_id:
		return
	_closed_by_scene = true
	_close_current()


func _on_scene_exited(inst: Node) -> void:
	if inst != current:
		return
	# Sahne kendini sinyal vermeden kapattı.
	var id: StringName = current_id
	current = null
	current_id = &""
	_unlock()
	if not _closed_by_scene:
		_emit_finished(id, {"cancelled": true})


func _close_current() -> void:
	var inst: Node = current
	current = null
	current_id = &""
	_unlock()
	MinigameUtil.sfx(&"ui_close")
	if inst != null and is_instance_valid(inst) and not inst.is_queued_for_deletion():
		if inst is CanvasItem:
			var ci: CanvasItem = inst as CanvasItem
			var tw: Tween = create_tween()
			tw.tween_property(ci, "modulate:a", 0.0, 0.25)
			tw.tween_callback(inst.queue_free)
		else:
			inst.queue_free()


func _unlock() -> void:
	_set_block(false)
	Input.mouse_mode = _prev_mouse_mode


func _set_block(blocked: bool) -> void:
	var bus: Node = MinigameUtil.autoload("EventBus")
	if bus != null:
		bus.emit_signal(&"ui_block_input", blocked)


func _emit_finished(id: StringName, result: Dictionary) -> void:
	var bus: Node = MinigameUtil.autoload("EventBus")
	if bus == null:
		return
	_emitting = true
	bus.emit_signal(&"minigame_finished", id, result)
	_emitting = false
