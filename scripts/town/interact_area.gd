class_name InteractArea
extends Area3D
## Etkileşim alanı (layer 4). get_interact_text()/interact() çağrılarını hedef düğüme yönlendirir.
## Kullanım: InteractArea.attach(self, Vector3(1.5, 2, 1.5))

var target: Node = null


static func attach(owner_node: Node3D, size: Vector3, offset: Vector3 = Vector3.ZERO) -> InteractArea:
	var area := InteractArea.new()
	area.name = "InteractArea"
	area.target = owner_node
	area.collision_layer = 1 << 3   # layer 4
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset + Vector3(0.0, size.y * 0.5, 0.0)
	area.add_child(shape)
	owner_node.add_child(area)
	if not owner_node.is_in_group(&"interactable"):
		owner_node.add_to_group(&"interactable")
	return area


func get_interact_text() -> String:
	if target != null and target.has_method(&"get_interact_text"):
		return target.call(&"get_interact_text") as String
	return ""


func interact(player: Node) -> void:
	if target != null and target.has_method(&"interact"):
		target.call(&"interact", player)
