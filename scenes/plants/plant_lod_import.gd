@tool
extends EditorScenePostImport

# Godot 4.7 stores native mesh LODs as distance/index-buffer pairs.
# Reserve 1,000 triangles across the three independently simplified surfaces.
const TRIANGLES: Dictionary[StringName, int] = {&"Leaves": 480, &"Stem": 200, &"Buds": 320}


func _post_import(scene: Node) -> Object:
	for child: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		var source: ArrayMesh = instance.mesh as ArrayMesh
		var surfaces: Array = source.get("_surfaces")
		var surface: Dictionary = surfaces[0]
		var lods: Array = surface.get("lods", [])
		var retained: Array = []
		var index_bytes: int = 2 if int(surface["vertex_count"]) <= 65536 else 4
		for i: int in range(0, lods.size(), 2):
			var indices: PackedByteArray = lods[i + 1]
			if indices.size() <= index_bytes * 3 * TRIANGLES[instance.name]:
				retained.append(lods[i])
				retained.append(indices)
		if retained.size() < lods.size():
			surface["lods"] = retained
			var mesh: ArrayMesh = ArrayMesh.new()
			mesh.resource_name = source.resource_name
			mesh.set("_surfaces", surfaces)
			instance.mesh = mesh
	return scene
