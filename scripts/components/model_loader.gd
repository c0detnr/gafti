class_name ModelLoader
extends RefCounted
## .glb modelini yükler; dosya henüz yoksa (Codex üretiyor olabilir) renkli bir yer tutucu kutu döner.
## Kullanım: add_child(ModelLoader.instance("res://assets/models/props/pot.glb", Vector3(0.3, 0.3, 0.3)))


static func instance(path: String, placeholder_size: Vector3 = Vector3.ONE, color: Color = Color(0.8, 0.3, 0.8)) -> Node3D:
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene != null:
			return scene.instantiate() as Node3D
	return placeholder(placeholder_size, color, path.get_file().get_basename())


static func placeholder(size: Vector3, color: Color, label: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "Placeholder_" + label
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position.y = size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	root.add_child(mi)
	return root


## Bir model ağacında adı verilen düğümü (MeshInstance3D vb.) bulur.
static func find(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	return root.find_child(node_name, true, false)
