extends Node3D
## Yatak: uyu → gün raporu verisi alınır, GameClock.sleep_until_morning(), SaveSystem.save_game(),
## ekran kararır ve gün sonu raporu gösterilir. 20:00'den önce "Daha erken" uyarısı.
## Kök ve Area3D (layer 4) "interactable" grubunda.

const MODEL_PATH: String = "res://assets/models/props/bed.glb"
const DAY_REPORT_SCENE: String = "res://scenes/ui/menus/day_report.tscn"

@export var model_rotation_deg: float = 0.0

var _sleeping: bool = false


func _ready() -> void:
	add_to_group(&"interactable")
	var area: Area3D = $InteractArea
	area.add_to_group(&"interactable")
	var model: Node3D = ModelLoader.instance(MODEL_PATH, Vector3(1.2, 0.6, 2.1), Color(0.55, 0.38, 0.25))
	model.rotation.y = deg_to_rad(model_rotation_deg)
	add_child(model)


func get_interact_text() -> String:
	return "" if _sleeping else tr("BED_SLEEP")


func interact(player: Node) -> void:
	if _sleeping:
		return
	if not _sleep_allowed():
		_notify(tr("BED_TOO_EARLY"), &"info")
		return
	_sleep(player)


func _sleep_allowed() -> bool:
	var clock: Node = GaftiUI.autoload("GameClock")
	if clock == null:
		return true
	if clock.has_method(&"is_sleep_allowed"):
		return bool(clock.call(&"is_sleep_allowed"))
	var h: int = int(clock.get(&"hour"))
	return h >= 20 or h < 6


func _sleep(player: Node) -> void:
	_sleeping = true
	_emit(&"ui_block_input", [true])
	if player != null and player.has_method(&"play_action"):
		player.call(&"play_action", &"sit", false)
	# Kararma
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(0.02, 0.03, 0.06, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	var tw: Tween = create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.0)
	await tw.finished
	# Rapor uyumadan önce alınır (gün kapanmadan).
	var report: Dictionary = {}
	var r: Variant = GaftiUI.call_safe("Economy", &"get_day_report", [], {})
	if r is Dictionary:
		report = r as Dictionary
	GaftiUI.call_safe("GameClock", &"sleep_until_morning")
	GaftiUI.call_safe("SaveSystem", &"save_game")
	if player != null and player.has_method(&"stand_up"):
		player.call(&"stand_up")
	# Raporu göster (HUD varsa onun üstünden).
	var dr: Control = null
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_day_report"):
		dr = hud.call(&"show_day_report", report) as Control
	elif ResourceLoader.exists(DAY_REPORT_SCENE):
		dr = (load(DAY_REPORT_SCENE) as PackedScene).instantiate() as Control
		layer.add_child(dr)
		GaftiUI.apply_theme(dr)
		dr.call(&"show_report", report)
	var tw2: Tween = create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 1.2)
	if dr != null:
		await dr.tree_exited
	else:
		_emit(&"ui_block_input", [false])
	if tw2.is_valid() and tw2.is_running():
		await tw2.finished
	if is_instance_valid(layer):
		layer.queue_free()
	_sleeping = false


func _notify(text: String, kind: StringName) -> void:
	_emit(&"notify", [text, kind])


func _emit(sig: StringName, args: Array) -> void:
	var bus: Node = GaftiUI.autoload("EventBus")
	if bus != null:
		bus.callv(&"emit_signal", [sig] + args)
