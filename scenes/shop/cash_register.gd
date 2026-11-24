class_name CashRegister
extends Node3D
## Kasa: sıradaki müşteri için kimlik kontrolünü başlatır (AGENTS §5 interactable).

const MODEL: String = "res://assets/models/props/cash_register.glb"

var shop: ShopManager = null


func _ready() -> void:
	var m: Node3D = ModelLoader.instance(MODEL, Vector3(0.4, 0.3, 0.35), Color(0.3, 0.3, 0.32))
	add_child(m)
	shop = _find_shop()
	InteractArea.attach(self, Vector3(1.4, 1.6, 1.4), Vector3(0, -0.9, 0))


func _find_shop() -> ShopManager:
	var n: Node = get_parent()
	while n != null:
		if n is ShopManager:
			return n as ShopManager
		n = n.get_parent()
	return null


func get_interact_text() -> String:
	if shop == null:
		return ""
	if not shop.is_open:
		return tr("REGISTER_CLOSED")
	if shop.is_checkout_busy():
		return ""
	if shop.waiting_customer() != null:
		return tr("REGISTER_SERVE")
	return tr("REGISTER_IDLE")


func interact(player: Node) -> void:
	if shop == null:
		return
	if not shop.serve_next(player):
		EventBus.notify.emit(tr("REGISTER_NOBODY"), &"info")
