extends Node3D

const FOLIAGE: Shader = preload("res://shaders/foliage_wind.gdshader")
const HEIGHTS: Array[float] = [0.08, 0.25, 0.70, 1.10, 1.20]
const PARTS: Array[StringName] = [&"Stem", &"Leaves", &"Buds"]

var _stage: int = 0
var _health: float = 1.0
var _thirst: float = 0.0
var _quality: float = 0.5
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	for part_index: int in range(PARTS.size()):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = FOLIAGE
		material.set_shader_parameter(&"part", part_index)
		_materials.append(material)
	for child: Node in get_children():
		for node: Node in child.find_children("*", "MeshInstance3D", true, false):
			var mesh_node: MeshInstance3D = node as MeshInstance3D
			var index: int = PARTS.find(mesh_node.name)
			if index >= 0:
				mesh_node.material_override = _materials[index]
				mesh_node.extra_cull_margin = 0.25
	set_stage(_stage)
	set_health(_health)
	set_thirst(_thirst)
	set_quality(_quality)


func set_stage(i: int) -> void:
	_stage = clampi(i, 0, HEIGHTS.size() - 1)
	for index: int in range(get_child_count()):
		var stage_node: Node3D = get_child(index) as Node3D
		stage_node.visible = index == _stage
	_set_parameter(&"plant_height", HEIGHTS[_stage])


func set_health(v: float) -> void:
	_health = clampf(v, 0.0, 1.0)
	_set_parameter(&"health", _health)


func set_thirst(v: float) -> void:
	_thirst = clampf(v, 0.0, 1.0)
	_set_parameter(&"thirst", _thirst)


func set_quality(v: float) -> void:
	_quality = clampf(v, 0.0, 1.0)
	_set_parameter(&"quality", _quality)


func _set_parameter(parameter: StringName, value: float) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(parameter, value)
