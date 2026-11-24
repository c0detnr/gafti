class_name Npc
extends CharacterBody3D
## Kasaba NPC'si: günlük program (saate göre noktalar arası dolaşma), konuşma (interactable → diyalog),
## character_base.glb üzerine kendi görünüş preset'i. Navmesh yoksa düz çizgi yürür.
## Kullanım: npc.tscn örneği, npc_id = &"muhtar" | &"fadime" | &"hayri" | &"cemil" | &"hans" | &"nevzat"

signal arrived()

const WALK_SPEED: float = 1.6
const ARRIVE_DIST: float = 0.6
const GRAVITY: float = 9.8
const STUCK_TELEPORT_SEC: float = 25.0

## Program girdisi: [başlangıç saati, konum, poz ("idle" | "sit" | "wander" | "hidden")]
## "hidden" = evde / içeride (görünmez, etkileşilemez).
## Konumlar AGENTS.md §9 vadi koordinatlarıdır (meydan (60,0,0)).
const PRESETS: Dictionary = {
	&"muhtar": {
		"look": {"skin": Color(0.84, 0.65, 0.5), "hair": "Hair_04", "hair_color": Color(0.7, 0.7, 0.7),
			"beard": "Beard_02", "hat": true, "top": "Top_Sweater", "top_color": Color(0.22, 0.38, 0.26),
			"pants_color": Color(0.3, 0.3, 0.32), "boots_color": Color(0.12, 0.12, 0.12), "scale": 1.04},
		"schedule": [
			[0, Vector3(84, 0, 18), "hidden"], [7, Vector3(74, 0, 13), "idle"], [11, Vector3(60, 0, 3), "wander"],
			[13, Vector3(74, 0, 13), "idle"], [18, Vector3(49, 0, 4), "sit"], [22, Vector3(84, 0, 18), "hidden"],
		],
	},
	&"fadime": {
		"look": {"skin": Color(0.93, 0.76, 0.62), "hair": "Hair_06", "hair_color": Color(0.3, 0.16, 0.1),
			"beard": "Beard_00", "hat": false, "top": "Top_Sweater", "top_color": Color(0.7, 0.2, 0.22),
			"pants_color": Color(0.25, 0.2, 0.3), "boots_color": Color(0.2, 0.35, 0.2), "scale": 0.96},
		"schedule": [
			[0, Vector3(40, 0, 14), "hidden"], [6, Vector3(46, 0, 3.5), "idle"], [12, Vector3(44, 0, 4), "wander"],
			[15, Vector3(46, 0, 3.5), "idle"], [23, Vector3(40, 0, 14), "hidden"],
		],
	},
	&"hayri": {
		"look": {"skin": Color(0.72, 0.53, 0.39), "hair": "Hair_04", "hair_color": Color(0.92, 0.92, 0.9),
			"beard": "Beard_04", "hat": false, "top": "Top_Shirt", "top_color": Color(0.55, 0.45, 0.32),
			"pants_color": Color(0.35, 0.3, 0.25), "boots_color": Color(0.25, 0.18, 0.12), "scale": 0.98},
		"schedule": [
			[0, Vector3(36, 0, -4), "hidden"], [8, Vector3(56, 0, 4), "sit"], [11, Vector3(49, 0, 2.5), "sit"],
			[16, Vector3(60, 0, -7), "idle"], [19, Vector3(48, 0, 4), "sit"], [22, Vector3(36, 0, -4), "hidden"],
		],
	},
	&"cemil": {
		"look": {"skin": Color(0.84, 0.65, 0.5), "hair": "Hair_02", "hair_color": Color(0.15, 0.1, 0.06),
			"beard": "Beard_03", "hat": true, "top": "Top_Raincoat", "top_color": Color(0.95, 0.78, 0.1),
			"pants_color": Color(0.2, 0.25, 0.35), "boots_color": Color(0.1, 0.25, 0.12), "scale": 1.0},
		"schedule": [
			[0, Vector3(28, 0, 20), "hidden"], [6, Vector3(20, 0, 7), "wander"], [10, Vector3(64, 0, 4), "wander"],
			[13, Vector3(50, 0, 2.5), "sit"], [17, Vector3(70, 0, 44), "wander"], [21, Vector3(28, 0, 20), "hidden"],
		],
	},
	&"hans": {
		"look": {"skin": Color(0.98, 0.84, 0.72), "hair": "Hair_05", "hair_color": Color(0.92, 0.8, 0.45),
			"beard": "Beard_00", "hat": false, "top": "Top_Shirt", "top_color": Color(0.98, 0.5, 0.2),
			"pants_color": Color(0.75, 0.65, 0.45), "boots_color": Color(0.35, 0.22, 0.12), "scale": 1.06},
		"schedule": [
			[0, Vector3(76, 0, 52), "hidden"], [7, Vector3(72, 0, 45.5), "idle"], [10, Vector3(58, 0, -2), "wander"],
			[13, Vector3(47, 0, 4.5), "sit"], [16, Vector3(61, 0, -6.5), "idle"], [20, Vector3(62, 0, 2), "wander"],
			[23, Vector3(76, 0, 52), "hidden"],
		],
	},
	&"nevzat": {
		"look": {"skin": Color(0.93, 0.76, 0.62), "hair": "Hair_01", "hair_color": Color(0.08, 0.06, 0.05),
			"beard": "Beard_01", "hat": false, "top": "Top_Shirt", "top_color": Color(0.82, 0.84, 0.88),
			"pants_color": Color(0.15, 0.17, 0.22), "boots_color": Color(0.05, 0.05, 0.05), "scale": 1.02},
		"schedule": [
			[0, Vector3(82, 0, -12), "hidden"], [8, Vector3(78, 0, -3.5), "idle"], [12, Vector3(48, 0, 5), "sit"],
			[13, Vector3(78, 0, -3.5), "idle"], [18, Vector3(82, 0, -12), "hidden"],
		],
	},
}

@export var npc_id: StringName = &"muhtar"
## Programı devre dışı bırakır (sabit duran NPC; testler ya da özel sahneler için).
@export var use_schedule: bool = true
## Programdaki konumlara eklenecek kayma (vadi dışındaki test sahneleri için).
@export var schedule_offset: Vector3 = Vector3.ZERO

var model: Node3D = null
var talking: bool = false

var _agent: NavigationAgent3D = null
var _anim: AnimationPlayer = null
var _target: Vector3 = Vector3.ZERO
var _pose: String = "idle"
var _override: bool = false
var _moving: bool = false
var _hidden: bool = false
var _wander_timer: float = 0.0
var _stuck_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _area: InteractArea = null
var _name_tag: Label3D = null


func _ready() -> void:
	add_to_group(&"npc")
	add_to_group(StringName("npc_" + String(npc_id)))
	_rng.randomize()
	collision_layer = 1 << 1
	collision_mask = 1
	_agent = get_node_or_null(^"NavigationAgent3D") as NavigationAgent3D
	var preset: Dictionary = PRESETS.get(npc_id, {}) as Dictionary
	var look: Dictionary = preset.get("look", {}) as Dictionary
	model = CharacterDresser.build(look)
	add_child(model)
	_anim = CharacterDresser.find_anim_player(model)
	_area = InteractArea.attach(self, Vector3(1.6, 2.0, 1.6))
	_name_tag = Label3D.new()
	_name_tag.text = tr("NPC_NAME_" + String(npc_id).to_upper())
	_name_tag.position = Vector3(0, 2.15, 0)
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.font_size = 40
	_name_tag.outline_size = 10
	_name_tag.pixel_size = 0.004
	_name_tag.visibility_range_end = 9.0
	add_child(_name_tag)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	var clock: Node = get_node_or_null(^"/root/GameClock")
	if clock != null:
		clock.connect(&"hour_passed", _on_hour_passed)
	if use_schedule:
		_apply_schedule(true)
	else:
		_target = global_position
		_set_pose("idle")


# ---------------------------------------------------------------- Program

func _current_slot() -> Array:
	var preset: Dictionary = PRESETS.get(npc_id, {}) as Dictionary
	var sched: Array = preset.get("schedule", []) as Array
	if sched.is_empty():
		return []
	var h: int = GameClock.hour
	var best: Array = sched[sched.size() - 1] as Array
	for e: Variant in sched:
		var entry: Array = e as Array
		if int(entry[0]) <= h:
			best = entry
	return best


## Programa göre hedef seçer. snap = true ise doğrudan konuma ışınlanır (sahne açılışı/yükleme).
func _apply_schedule(snap: bool) -> void:
	if _override or not use_schedule:
		return
	var slot: Array = _current_slot()
	if slot.is_empty():
		return
	var pos: Vector3 = (slot[1] as Vector3) + schedule_offset
	_pose = String(slot[2])
	if snap:
		global_position = pos + Vector3(0, 0.05, 0)
		_target = pos
		_arrive()
	else:
		_set_hidden(false)
		_go(pos)


func _on_hour_passed(_hour: int) -> void:
	if talking:
		return
	_apply_schedule(false)


## Programı geçersiz kılıp bir noktaya yürür (ör. denetim için dükkana). Varınca `arrived` yayılır.
func go_to(pos: Vector3) -> void:
	_override = true
	_pose = "idle"
	_set_hidden(false)
	_go(pos)


## Geçersiz kılmayı bırakır, programa döner.
func release_override() -> void:
	_override = false
	_apply_schedule(false)


func is_hidden() -> bool:
	return _hidden


func _go(pos: Vector3) -> void:
	_target = pos
	_moving = true
	_stuck_timer = 0.0
	if _agent != null:
		_agent.target_position = pos
	_set_pose_anim("walk")


func _arrive() -> void:
	_moving = false
	velocity = Vector3.ZERO
	match _pose:
		"hidden":
			_set_hidden(true)
		"sit":
			_set_pose_anim("sit")
		_:
			_set_pose_anim("idle")
	_wander_timer = _rng.randf_range(4.0, 9.0)
	arrived.emit()


# ---------------------------------------------------------------- Hareket

func _physics_process(delta: float) -> void:
	if _hidden:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	if talking:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _moving:
		var next: Vector3 = _next_point()
		var to: Vector3 = next - global_position
		to.y = 0.0
		var flat_to_target: Vector3 = _target - global_position
		flat_to_target.y = 0.0
		if flat_to_target.length() < ARRIVE_DIST:
			_arrive()
		else:
			var dir: Vector3 = to.normalized() if to.length() > 0.01 else flat_to_target.normalized()
			var speed: float = WALK_SPEED
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_face(dir)
			_stuck_timer += delta
			if _stuck_timer > STUCK_TELEPORT_SEC:
				# Takılırsa hedefe ışınla (navmesh/çarpışma sorunlarına karşı sigorta).
				global_position = _target + Vector3(0, 0.05, 0)
				_arrive()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _pose == "wander" and not _override:
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				var slot: Array = _current_slot()
				if not slot.is_empty():
					var base: Vector3 = (slot[1] as Vector3) + schedule_offset
					var off: Vector3 = Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5))
					_go(base + off)
					_pose = "wander"
	move_and_slide()


## Navmesh varsa bir sonraki yol noktası; yoksa doğrudan hedef.
func _next_point() -> Vector3:
	if _agent == null:
		return _target
	var map: RID = _agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_regions(map).is_empty():
		return _target
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return _target
	var p: Vector3 = _agent.get_next_path_position()
	if p.distance_to(global_position) < 0.05:
		return _target
	return p


func _face(dir: Vector3) -> void:
	if model == null or dir.length() < 0.01:
		return
	# Model +Z ileri bakar.
	var yaw: float = atan2(dir.x, dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, yaw, 0.2)


func face_point(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length() > 0.01 and model != null:
		model.rotation.y = atan2(d.x, d.z)


func _set_pose(p: String) -> void:
	_pose = p
	_set_pose_anim("sit" if p == "sit" else "idle")


func _set_pose_anim(anim: String) -> void:
	CharacterDresser.play_anim(_anim, anim)


func _set_hidden(h: bool) -> void:
	if _hidden == h:
		return
	_hidden = h
	visible = not h
	collision_layer = 0 if h else (1 << 1)
	if _area != null:
		_area.monitorable = not h
		_area.collision_layer = 0 if h else (1 << 3)


# ---------------------------------------------------------------- Etkileşim (AGENTS §5)

func get_interact_text() -> String:
	if _hidden or talking:
		return ""
	return tr("NPC_TALK") % tr("NPC_NAME_" + String(npc_id).to_upper())


func interact(player: Node) -> void:
	if _hidden or talking:
		return
	talking = true
	if player is Node3D:
		face_point((player as Node3D).global_position)
	_set_pose_anim("wave")
	# Konuşma olayı önce gelir: görev bitip kendi diyaloğunu açtıysa NPC'ninkini açma.
	QuestManager.notify_event(StringName("talk_" + String(npc_id)), {"npc": npc_id})
	if QuestManager.is_dialogue_busy():
		return
	var d: StringName = QuestManager.get_npc_dialogue(npc_id)
	QuestManager.request_dialogue(d)


func _on_dialogue_finished(_id: StringName) -> void:
	if not talking:
		return
	# Kuyrukta başka diyalog varsa (görev bitişi vb.) onların da bitmesini bekle.
	if QuestManager.is_dialogue_busy():
		return
	talking = false
	if not _moving:
		_set_pose_anim("sit" if _pose == "sit" else "idle")
	if not _override:
		_apply_schedule(false)
