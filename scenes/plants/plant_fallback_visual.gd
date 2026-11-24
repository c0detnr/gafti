class_name PlantFallbackVisual
extends Node3D
## plant_visual.tscn (Codex) bulunamazsa kullanılan basit yer tutucu bitki.
## Aynı API: set_stage(i), set_health(v), set_thirst(v), set_quality(v).

const HEIGHTS: Array[float] = [0.08, 0.25, 0.70, 1.10, 1.20]

var leaf_tint: Color = Color(0.35, 0.65, 0.3)

var _stage: int = 0
var _health: float = 1.0
var _thirst: float = 0.0
var _quality: float = 0.5
var _stem: MeshInstance3D
var _leaves: MeshInstance3D
var _buds: MeshInstance3D
var _leaf_mat: StandardMaterial3D
var _bud_mat: StandardMaterial3D


func _ready() -> void:
	var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.35, 0.5, 0.2)
	_stem = _mesh(CylinderMesh.new(), stem_mat)
	_leaf_mat = StandardMaterial3D.new()
	_leaves = _mesh(SphereMesh.new(), _leaf_mat)
	_bud_mat = StandardMaterial3D.new()
	_bud_mat.albedo_color = Color(0.75, 0.8, 0.45)
	_buds = _mesh(SphereMesh.new(), _bud_mat)
	_refresh()


func set_stage(i: int) -> void:
	_stage = clampi(i, 0, HEIGHTS.size() - 1)
	_refresh()


func set_health(v: float) -> void:
	_health = clampf(v, 0.0, 1.0)
	_refresh()


func set_thirst(v: float) -> void:
	_thirst = clampf(v, 0.0, 1.0)
	_refresh()


func set_quality(v: float) -> void:
	_quality = clampf(v, 0.0, 1.0)
	_refresh()


func _mesh(m: PrimitiveMesh, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	add_child(mi)
	return mi


func _refresh() -> void:
	if _stem == null:
		return
	var h: float = HEIGHTS[_stage]
	# Susuzlukta bitki sarkar (boy kısalır).
	var droop: float = 1.0 - _thirst * 0.25
	var stem: CylinderMesh = _stem.mesh as CylinderMesh
	stem.top_radius = 0.012 + h * 0.015
	stem.bottom_radius = 0.02 + h * 0.02
	stem.height = h * droop
	_stem.position.y = h * droop * 0.5
	var leaves: SphereMesh = _leaves.mesh as SphereMesh
	var r: float = maxf(0.05, h * 0.35)
	leaves.radius = r
	leaves.height = r * 2.0 * droop
	_leaves.position.y = h * droop * 0.65
	# Sağlık düşükse sararır, kalite yüksekse doygun yeşil.
	var sick: Color = Color(0.7, 0.6, 0.25)
	var c: Color = sick.lerp(leaf_tint, _health)
	c = c.lerp(c * 1.15, _quality)
	_leaf_mat.albedo_color = c
	_buds.visible = _stage >= 3
	var buds: SphereMesh = _buds.mesh as SphereMesh
	buds.radius = 0.06 + 0.04 * float(_stage - 3)
	buds.height = buds.radius * 2.4
	_buds.position.y = h * droop
