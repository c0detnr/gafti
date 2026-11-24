extends CharacterBody3D
## Oyuncu: kameraya göre 3. şahıs hareket, koşma, zıplama, etkileşim, animasyon, ayak sesi, kayıt.
## Gruplar: "player", "persist". Etkileşim: layer 4 Area3D'leri tarar (AGENTS §5).

const HOME_POSITION: Vector3 = Vector3(-62.0, 2.0, 28.0)
const INTERACT_LAYER_MASK: int = 1 << 3 # layer 4

@export var walk_speed: float = 3.4
@export var run_speed: float = 6.2
@export var acceleration: float = 12.0
@export var air_control: float = 3.0
@export var jump_velocity: float = 4.6
@export var turn_speed: float = 12.0
@export var step_distance: float = 0.75 # ayak sesi aralığı (m)

@onready var visual: CharacterVisual = $Visual
@onready var sensor: Area3D = $InteractSensor
@onready var camera_rig: Node3D = $CameraRig

var input_blocked: bool = false
var _gravity: float = 9.8
var _current_target: Node = null
var _prompt_text: String = ""
var _scan_timer: float = 0.0
var _step_accum: float = 0.0
var _action_lock: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	add_to_group(&"persist")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.45
	sensor.collision_layer = 0
	sensor.collision_mask = INTERACT_LAYER_MASK
	sensor.monitoring = true
	sensor.monitorable = false
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.connect(&"ui_block_input", _on_ui_block)
		bus.connect(&"player_customization_changed", apply_customization)
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock != null and clock.has_signal(&"fainted"):
		clock.connect(&"fainted", _on_fainted)
	visual.one_shot_finished.connect(_on_one_shot_finished)
	# Yeni oyun: menüdeki özelleştirmeyi uygula.
	if not CharacterVisual.pending_customization.is_empty():
		apply_customization(CharacterVisual.pending_customization)
		CharacterVisual.pending_customization = {}
	# Devam Et: kayıt yükleme isteği.
	if GameStart.load_on_start:
		GameStart.load_on_start = false
		_load_saved_game.call_deferred()
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method(&"set_auto_music"):
		audio.call(&"set_auto_music", true)
		audio.call(&"set_ambience", &"auto")


func _load_saved_game() -> void:
	var save: Node = get_node_or_null("/root/SaveSystem")
	if save != null and save.has_method(&"load_game"):
		save.call(&"load_game")


func _physics_process(delta: float) -> void:
	_action_lock = maxf(_action_lock - delta, 0.0)
	var input: Vector2 = Vector2.ZERO
	if not input_blocked and _action_lock <= 0.0:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var yaw: float = 0.0
	if camera_rig != null and camera_rig.has_method(&"get_yaw"):
		yaw = float(camera_rig.call(&"get_yaw"))
	var dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var running: bool = Input.is_action_pressed(&"sprint") and not input_blocked
	var speed: float = (run_speed if running else walk_speed) * _move_multiplier()
	var target_vel: Vector3 = dir * speed
	var accel: float = acceleration if is_on_floor() else air_control
	var horiz: Vector3 = Vector3(velocity.x, 0.0, velocity.z).lerp(target_vel, 1.0 - exp(-accel * delta))
	velocity.x = horiz.x
	velocity.z = horiz.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif not input_blocked and _action_lock <= 0.0 and Input.is_action_just_pressed(&"jump"):
		velocity.y = jump_velocity
		_play_sfx(&"jump")
	move_and_slide()
	# Yön ve animasyon
	var flat_speed: float = Vector2(velocity.x, velocity.z).length()
	if flat_speed > 0.2 and dir.length_squared() > 0.001:
		var want: float = atan2(velocity.x, velocity.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, want, 1.0 - exp(-turn_speed * delta))
	if not visual.is_busy():
		visual.set_locomotion(clampf(flat_speed / run_speed, 0.0, 1.0) if is_on_floor() else 0.3)
	# Ayak sesi
	if is_on_floor() and flat_speed > 0.5:
		_step_accum += flat_speed * delta
		if _step_accum >= step_distance * (1.3 if flat_speed > walk_speed + 0.5 else 1.0):
			_step_accum = 0.0
			_play_sfx(_footstep_id(), global_position)
	# Etkileşim taraması (10 Hz)
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.1
		_scan_interactables()


func _unhandled_input(event: InputEvent) -> void:
	if input_blocked:
		return
	if event.is_action_pressed(&"interact"):
		try_interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not GaftiUI.is_touch():
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _current_target != null:
			try_interact()


# --- Genel API -----------------------------------------------------------------

## En yakın etkileşilebilir nesneyle etkileşir (E tuşu / mobil buton).
func try_interact() -> void:
	if input_blocked or _current_target == null or not is_instance_valid(_current_target):
		return
	if _current_target.has_method(&"interact"):
		_face_target(_current_target)
		visual.play_one_shot(&"interact")
		_current_target.call(&"interact", self)


## Evin önüne ışınlar.
func teleport_home() -> void:
	global_position = HOME_POSITION
	velocity = Vector3.ZERO
	visual.reset_pose()
	if camera_rig != null and camera_rig.has_method(&"snap_to_target"):
		camera_rig.call(&"snap_to_target")


## Görünüm verisini uygular (ten, saç, sakal, kasket, üst, renkler).
func apply_customization(data: Dictionary) -> void:
	visual.apply_customization(data)


func get_customization() -> Dictionary:
	return visual.get_customization()


## Tek seferlik animasyon: &"interact", &"wave", &"smoke", &"faint", &"sit", &"roll".
## Animasyon süresince hareket kilitlenir. Süreyi döner.
func play_action(anim: StringName, lock_movement: bool = true) -> float:
	var d: float = visual.play_one_shot(anim)
	if lock_movement:
		_action_lock = d
	return d


## sit/faint pozundan çık.
func stand_up() -> void:
	_action_lock = 0.0
	visual.reset_pose()


# --- Kayıt -----------------------------------------------------------------------

func get_save_id() -> String:
	return "player"


func get_save_data() -> Dictionary:
	return {
		"pos": [global_position.x, global_position.y, global_position.z],
		"yaw": visual.rotation.y,
		"customization": visual.get_customization(),
	}


func load_save_data(d: Dictionary) -> void:
	var p: Variant = d.get("pos", null)
	if p is Array and (p as Array).size() == 3:
		var a: Array = p as Array
		global_position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		velocity = Vector3.ZERO
		if camera_rig != null and camera_rig.has_method(&"snap_to_target"):
			camera_rig.call(&"snap_to_target")
	visual.rotation.y = float(d.get("yaw", 0.0))
	var c: Variant = d.get("customization", null)
	if c is Dictionary:
		apply_customization(c as Dictionary)


# --- İç işler ----------------------------------------------------------------------

func _move_multiplier() -> float:
	var fx: Node = get_node_or_null("/root/Effects")
	if fx != null and fx.has_method(&"get_move_multiplier"):
		return float(fx.call(&"get_move_multiplier"))
	return 1.0


func _on_ui_block(blocked: bool) -> void:
	input_blocked = blocked
	if blocked:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_prompt("")
		_current_target = null


func _on_fainted() -> void:
	# Bayılma: kısa animasyon, sonra eve taşınır.
	var d: float = play_action(&"faint")
	get_tree().create_timer(maxf(d, 1.0) + 0.6).timeout.connect(teleport_home)


func _on_one_shot_finished(_anim: StringName) -> void:
	pass


func _face_target(t: Node) -> void:
	if t is Node3D:
		var to: Vector3 = (t as Node3D).global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.01:
			visual.rotation.y = atan2(to.x, to.z)


func _scan_interactables() -> void:
	if input_blocked:
		return
	var best: Node = null
	var best_d: float = INF
	for area: Area3D in sensor.get_overlapping_areas():
		var target: Node = _interactable_for(area)
		if target == null:
			continue
		var d: float = area.global_position.distance_squared_to(global_position)
		# Önündeki nesneler hafif öncelikli.
		var fwd: Vector3 = Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))
		var to: Vector3 = (area.global_position - global_position)
		to.y = 0.0
		if to.length_squared() > 0.0001 and fwd.dot(to.normalized()) > 0.3:
			d *= 0.6
		if d < best_d:
			best_d = d
			best = target
	_current_target = best
	var text: String = ""
	if best != null and best.has_method(&"get_interact_text"):
		text = String(best.call(&"get_interact_text"))
	if text == "":
		_current_target = null
	_set_prompt(text)


## Area3D kendisi ya da ebeveyn zinciri "interactable" grubundaysa ilgili düğümü döner.
func _interactable_for(area: Area3D) -> Node:
	if area.has_method(&"get_interact_text") and area.has_method(&"interact"):
		return area
	var n: Node = area
	while n != null and n != get_tree().root:
		if n.is_in_group(&"interactable") and n.has_method(&"interact"):
			return n
		n = n.get_parent()
	return null


func _set_prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal(&"interaction_prompt", text)


func _footstep_id() -> StringName:
	# Ahşap zemin (ev/dükkan) "wood" meta'sı ya da grubu taşıyorsa ahşap ses.
	var col: KinematicCollision3D = get_last_slide_collision()
	if col != null:
		var c: Object = col.get_collider()
		if c is Node and ((c as Node).is_in_group(&"floor_wood") or (c as Node).get_meta(&"surface", "") == "wood"):
			return &"footstep_wood"
	return &"footstep_grass"


func _play_sfx(id: StringName, pos: Variant = null) -> void:
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method(&"play_sfx"):
		audio.call(&"play_sfx", id, pos)
