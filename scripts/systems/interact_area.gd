extends Area3D
## İstasyonun etkileşim alanı. Oyuncu doğrudan bu Area3D ile konuşabilsin diye
## get_interact_text/interact çağrılarını sahibi olan istasyona iletir.


func _init() -> void:
	add_to_group(&"interactable")


func get_station() -> Node:
	return get_parent()


func get_interact_text() -> String:
	var p: Node = get_parent()
	if p != null and p.has_method("get_interact_text"):
		return String(p.call("get_interact_text"))
	return ""


func interact(player: Node) -> void:
	var p: Node = get_parent()
	if p != null and p.has_method("interact"):
		p.call("interact", player)
