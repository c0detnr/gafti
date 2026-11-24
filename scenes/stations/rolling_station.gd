extends Node3D
## Sarma masası (Ajan B). Etkileşim → EventBus.minigame_requested(&"rolling", {bud_id, strain, quality}).
## Envanterde kâğıt + 0.5 g kuru ürün yoksa uyarı verir.

const M_TABLE: String = "res://assets/models/props/rolling_table.glb"
const M_TRAY: String = "res://assets/models/hero/rolling_tray.glb"
const M_GRINDER: String = "res://assets/models/hero/grinder.glb"
const TABLE_H: float = 0.78

@onready var visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"interactable")
	var table: Node3D = ModelLoader.instance(M_TABLE, Vector3(1.0, TABLE_H, 0.6), Color(0.45, 0.3, 0.18))
	visual.add_child(table)
	var tray: Node3D = ModelLoader.instance(M_TRAY, Vector3(0.4, 0.02, 0.26), Color(0.72, 0.18, 0.16))
	visual.add_child(tray)
	tray.position = Vector3(0, TABLE_H, 0)
	var grinder: Node3D = ModelLoader.instance(M_GRINDER, Vector3(0.06, 0.05, 0.06), Color(0.55, 0.6, 0.62))
	visual.add_child(grinder)
	grinder.position = Vector3(0.3, TABLE_H, 0.05)


func get_interact_text() -> String:
	return tr("ROLL_INTERACT")


func interact(_player: Node) -> void:
	var ctx: Dictionary = {"station": get_path()}
	if MinigameUtil.has_inventory():
		if MinigameUtil.count_of(&"paper") < 1:
			MinigameUtil.notify(tr("ROLL_NEED_PAPER"), &"bad")
			return
		var bud: Dictionary = MinigameUtil.best_dry_bud(MinigameUtil.BUD_PER_JOINT)
		if bud.is_empty():
			MinigameUtil.notify(tr("ROLL_NEED_BUD"), &"bad")
			return
		ctx["bud_id"] = StringName(str(bud.get("id", "")))
		ctx["strain"] = StringName(str(bud.get("strain", "")))
		ctx["quality"] = int(bud.get("quality", 60))
	var bus: Node = MinigameUtil.autoload("EventBus")
	if bus != null:
		bus.emit_signal(&"minigame_requested", &"rolling", ctx)
