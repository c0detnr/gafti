class_name ModelProp
extends Node3D
## Sahnede .glb modelini çalışma anında yükler (model henüz yoksa yer tutucu kutu).
## İsteğe bağlı basit kutu çarpışması ekler.

@export_file("*.glb") var model_path: String = ""
@export var placeholder_size: Vector3 = Vector3.ONE
@export var placeholder_color: Color = Color(0.6, 0.45, 0.3)
@export var add_box_collision: bool = false


func _ready() -> void:
	var m: Node3D = ModelLoader.instance(model_path, placeholder_size, placeholder_color)
	add_child(m)
	if add_box_collision:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = placeholder_size
		cs.shape = box
		cs.position = Vector3(0, placeholder_size.y * 0.5, 0)
		body.add_child(cs)
		add_child(body)
