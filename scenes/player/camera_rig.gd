extends Node3D
## Omuz üstü 3. şahıs kamera. Hedefi yumuşak takip eder, SpringArm3D ile duvarlara çarpar.
## PC: sağ/orta fare tuşu basılıyken sürükle = döndür, tekerlek = zoom.
## Mobil: MobileControls rotate_by()/zoom_by() çağırır. ui_block_input açıkken girdiler donar.

@export var target_path: NodePath = NodePath("..")
@export var height: float = 1.55
@export var follow_speed: float = 10.0
@export var mouse_sensitivity: float = 0.25 # derece / piksel
@export var touch_sensitivity: float = 0.3
@export var min_pitch_deg: float = -65.0
@export var max_pitch_deg: float = 25.0
@export var min_distance: float = 1.8
@export var max_distance: float = 8.0
@export var distance: float = 4.2

@onready var _yaw: Node3D = $Yaw
@onready var _pitch: Node3D = $Yaw/Pitch
@onready var _arm: SpringArm3D = $Yaw/Pitch/SpringArm3D
@onready var camera: Camera3D = $Yaw/Pitch/SpringArm3D/Camera3D

var _target: Node3D = null
var _blocked: bool = false
var _rotating: bool = false
var _target_distance: float = 4.2
var _yaw_target: float = 0.0
var _pitch_target: float = -0.3


func _ready() -> void:
	add_to_group(&"camera_rig")
	top_level = true
	_target = get_node_or_null(target_path) as Node3D
	_target_distance = distance
	_arm.spring_length = distance
	_arm.add_excluded_object(_target_rid())
	_yaw_target = _yaw.rotation.y
	_pitch.rotation.x = _pitch_target
	if _target != null:
		global_position = _target.global_position + Vector3.UP * height
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.connect(&"ui_block_input", _on_ui_block)
	camera.make_current()


func _target_rid() -> RID:
	if _target is CollisionObject3D:
		return (_target as CollisionObject3D).get_rid()
	return RID()


func _on_ui_block(blocked: bool) -> void:
	_blocked = blocked
	_rotating = false
	if not blocked:
		_restore_camera.call_deferred()


## Mini oyun kendi kamerasını kapattıysa bizimki tekrar etkin olsun.
func _restore_camera() -> void:
	var cur: Camera3D = get_viewport().get_camera_3d()
	if cur == null or not is_instance_valid(cur) or not cur.is_inside_tree():
		camera.make_current()


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	# Yumuşak takip (kare hızından bağımsız üstel yaklaşım).
	var goal: Vector3 = _target.global_position + Vector3.UP * height
	var t: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(goal, t)
	_yaw.rotation.y = lerp_angle(_yaw.rotation.y, _yaw_target, 1.0 - exp(-18.0 * delta))
	_pitch.rotation.x = lerpf(_pitch.rotation.x, _pitch_target, 1.0 - exp(-18.0 * delta))
	_arm.spring_length = lerpf(_arm.spring_length, _target_distance, 1.0 - exp(-8.0 * delta))


func _unhandled_input(event: InputEvent) -> void:
	if _blocked:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(-0.5)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(0.5)
	elif event is InputEventMouseMotion and _rotating:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_by(mm.relative, mouse_sensitivity)
	elif event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		zoom_by((1.0 - mg.factor) * 4.0)
	elif event is InputEventPanGesture:
		var pg: InputEventPanGesture = event as InputEventPanGesture
		zoom_by(pg.delta.y * 0.3)


## Piksel cinsinden sürükleme ile döndürür.
func rotate_by(relative: Vector2, sensitivity: float = -1.0) -> void:
	if _blocked:
		return
	var s: float = touch_sensitivity if sensitivity < 0.0 else sensitivity
	_yaw_target -= deg_to_rad(relative.x * s)
	_pitch_target = clampf(_pitch_target - deg_to_rad(relative.y * s), deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


## Pozitif = uzaklaş.
func zoom_by(amount: float) -> void:
	if _blocked:
		return
	_target_distance = clampf(_target_distance + amount, min_distance, max_distance)


## Hareket için kameranın yatay açısı (radyan).
func get_yaw() -> float:
	return _yaw.rotation.y


## Kamerayı hedefin arkasına hemen yerleştirir (ışınlama sonrası).
func snap_to_target() -> void:
	if _target != null:
		global_position = _target.global_position + Vector3.UP * height
