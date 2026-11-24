extends MinigameBase
## Hızlı bakım mini oyunu: sulama/besleme (kabı eğ, çizgide bırak), budama (işaretli yaprakları kes),
## zararlı (yaprak bitlerini ez).
## Context: {"action": &"water"|&"feed"|&"prune"|&"pest", "request_id": int, "plant_id": int, "strain", "stage": int}
## Sonuç: {"request_id", "score", "quality_delta", "action", "plant_id", "cancelled"}

const PLANT_SCENE: String = "res://scenes/plants/plant_visual.tscn"
const M_POT: String = "res://assets/models/props/pot.glb"
const M_CAN: String = "res://assets/models/props/watering_can.glb"
const PLANT_HEIGHTS: Array[float] = [0.08, 0.25, 0.7, 1.1, 1.2]
const VIEW_H: float = 0.55 # bitki bu yüksekliğe ölçeklenir
const POT_H: float = 0.22
const TIME_LIMIT: float = 12.0

var action: StringName = &"water"
var plant_root: Node3D
var can_root: Node3D
var stream: CPUParticles3D
var soil: MeshInstance3D
var soil_mat: StandardMaterial3D
var meter: MinigameMeter
var timer_label: Label

var _locked: bool = true
var _fill: float = 0.0
var _target: float = 0.65
var _pouring: bool = false
var _jitter: float = 0.0
var _jitter_t: float = 0.0
var _time_left: float = TIME_LIMIT
var _targets: Array[Node3D] = [] # budama yaprakları ya da yaprak bitleri
var _marked: Array[bool] = []
var _velocities: Array[Vector3] = []
var _hits: int = 0
var _mistakes: int = 0
var _total_marked: int = 0


func _build_world() -> void:
	prim(box(Vector3(3, 0.02, 3)), Color(0.4, 0.33, 0.24), world, Vector3(0, -0.01, 0), "Bench")
	var grow := OmniLight3D.new()
	grow.position = Vector3(-0.2, 1.1, 0.3)
	grow.light_color = Color(1.0, 0.85, 0.65)
	grow.light_energy = 0.9
	grow.omni_range = 2.5
	world.add_child(grow)
	# Saksı
	var pot: Node3D = try_model(M_POT)
	if pot != null:
		world.add_child(pot)
		var a: AABB = combined_aabb(pot)
		var k: float = POT_H / maxf(a.size.y, 0.01)
		pot.scale = Vector3(k, k, k)
	else:
		prim(cyl(0.14, 0.1, POT_H, 24), Color(0.72, 0.38, 0.22), world, Vector3(0, POT_H * 0.5, 0), "Pot")
	soil_mat = mat(Color(0.28, 0.19, 0.12), 0.95)
	soil = prim(cyl(0.128, 0.128, 0.01, 24), Color(0.28, 0.19, 0.12), world, Vector3(0, POT_H - 0.012, 0), "Soil")
	soil.material_override = soil_mat
	meter = MinigameMeter.new()
	meter.vertical = true
	meter.anchor_left = 1.0
	meter.anchor_right = 1.0
	meter.anchor_top = 0.5
	meter.anchor_bottom = 0.5
	meter.offset_left = -170
	meter.offset_right = -100
	meter.offset_top = -260
	meter.offset_bottom = 260
	meter.visible = false
	ui.add_child(meter)
	timer_label = _label("", 48, Color(1, 0.95, 0.7))
	timer_label.position = Vector2(40, 40)
	timer_label.visible = false
	ui.add_child(timer_label)


func _cancel_result() -> Dictionary:
	return {
		"cancelled": true,
		"request_id": int(context.get("request_id", -1)),
		"score": 0,
		"quality_delta": 0,
		"action": action,
		"plant_id": int(context.get("plant_id", -1)),
	}


func _begin() -> void:
	action = StringName(str(context.get("action", "water")))
	if action not in [&"water", &"feed", &"prune", &"pest"]:
		action = &"water"
	_build_plant(clampi(int(context.get("stage", 2)), 0, 4))
	set_title(tr("CARE_TITLE"))
	look_from(Vector3(0, 0.75, 0.95), Vector3(0, 0.45, 0), 0.0)
	_locked = false
	match action:
		&"water", &"feed":
			_start_pour()
		&"prune":
			_start_prune()
		&"pest":
			_start_pest()


func _build_plant(stage: int) -> void:
	plant_root = Node3D.new()
	plant_root.name = "PlantRoot"
	world.add_child(plant_root)
	plant_root.position = Vector3(0, POT_H - 0.01, 0)
	var k: float = clampf(VIEW_H / PLANT_HEIGHTS[stage], 0.4, 4.0)
	if ResourceLoader.exists(PLANT_SCENE):
		var ps: PackedScene = load(PLANT_SCENE) as PackedScene
		var pv: Node3D = ps.instantiate() as Node3D if ps != null else null
		if pv != null:
			plant_root.add_child(pv)
			if pv.has_method(&"set_stage"):
				pv.call(&"set_stage", stage)
			pv.scale = Vector3(k, k, k)
			return
	# Yedek: gövde + yaprak topları
	var h: float = PLANT_HEIGHTS[stage] * k
	prim(cyl(0.008, 0.012, h, 8), Color(0.35, 0.55, 0.25), plant_root, Vector3(0, h * 0.5, 0), "Stem")
	for i: int in range(6):
		var y: float = h * (0.3 + 0.12 * float(i))
		var a: float = float(i) * 2.4
		prim(sphere(0.07 - 0.008 * float(i), 8), Color(0.25, 0.6, 0.25), plant_root, Vector3(cos(a) * 0.06, y, sin(a) * 0.06), "Leaves")


func _process(delta: float) -> void:
	super._process(delta)
	if _locked:
		return
	match action:
		&"water", &"feed": _process_pour(delta)
		&"prune": _tick_timer(delta)
		&"pest":
			_move_pests(delta)
			_tick_timer(delta)


# ================================================================ Sulama / besleme

func _start_pour() -> void:
	var is_feed: bool = action == &"feed"
	_target = randf_range(0.3, 0.5) if is_feed else randf_range(0.55, 0.78)
	set_step(1, 1, tr("CARE_STEP_FEED") if is_feed else tr("CARE_STEP_WATER"), tr("CARE_HINT_POUR"))
	meter.zone_min = _target - 0.05
	meter.zone_max = _target + 0.05
	meter.show_zone = true
	meter.right_text = tr("CARE_FULL")
	meter.left_text = ""
	meter.value = 0.0
	meter.visible = true
	can_root = Node3D.new()
	can_root.name = "Can"
	world.add_child(can_root)
	can_root.position = Vector3(-0.26, POT_H + 0.25, 0.02)
	var cm: Node3D = null if is_feed else try_model(M_CAN)
	if cm != null:
		can_root.add_child(cm)
		var a: AABB = combined_aabb(cm)
		var k: float = 0.22 / maxf(a.size.y, 0.01)
		cm.scale = Vector3(k, k, k)
		cm.position = Vector3(0, -0.1, 0)
	elif is_feed:
		prim(cyl(0.03, 0.035, 0.12, 16), Color(0.95, 0.55, 0.15, 0.85), can_root, Vector3(0, -0.02, 0), "NutrientBottle")
		prim(cyl(0.008, 0.015, 0.04, 12), Color(1, 1, 1), can_root, Vector3(0.0, 0.06, 0), "Dropper")
	else:
		prim(cyl(0.07, 0.08, 0.14, 20), Color(0.3, 0.6, 0.4), can_root, Vector3(0, -0.03, 0), "CanBody")
		var spout: MeshInstance3D = prim(cyl(0.008, 0.012, 0.18, 10), Color(0.3, 0.6, 0.4), can_root, Vector3(0.11, 0.02, 0), "Spout")
		spout.rotation_degrees = Vector3(0, 0, -60)
	stream = CPUParticles3D.new()
	stream.amount = 60
	stream.lifetime = 0.6
	stream.direction = Vector3(0.6, -0.4, 0)
	stream.spread = 6.0
	stream.initial_velocity_min = 0.4
	stream.initial_velocity_max = 0.55
	stream.gravity = Vector3(0, -3.0, 0)
	var dm: SphereMesh = sphere(0.006 if not is_feed else 0.005, 6)
	dm.material = mat(Color(0.95, 0.6, 0.2, 0.9) if is_feed else Color(0.55, 0.8, 1.0, 0.8), 0.05)
	stream.mesh = dm
	stream.emitting = false
	can_root.add_child(stream)
	stream.position = Vector3(0.2, 0.06, 0) if not is_feed else Vector3(0.02, 0.08, 0)
	look_from(Vector3(0.05, 0.75, 0.8), Vector3(0, 0.3, 0), 0.5)


func _process_pour(delta: float) -> void:
	_jitter_t -= delta
	if _jitter_t <= 0.0:
		_jitter_t = 0.5
		_jitter = MinigameUtil.water_jitter()
	if _pouring:
		var rate: float = (0.12 if action == &"feed" else 0.2) * (1.0 + _jitter)
		_fill = minf(_fill + rate * delta, 1.0)
		meter.value = _fill
		soil_mat.albedo_color = Color(0.28, 0.19, 0.12).lerp(Color(0.14, 0.09, 0.05), _fill)
		if _fill >= 1.0:
			pop_text(tr("CARE_POP_FLOOD"), Vector2(-1, -1), C_BAD, 60)
			shake(0.8)
			_release_pour()


func _on_press(_pos: Vector2) -> void:
	if _locked:
		return
	match action:
		&"water", &"feed":
			_pouring = true
			stream.emitting = true
			sfx(&"water_pour")
			var tw: Tween = create_tween()
			tw.tween_property(can_root, "rotation_degrees:z", -45.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		&"prune":
			_try_cut(_pos)
		&"pest":
			_try_squash(_pos)


func _on_release(_pos: Vector2) -> void:
	if _locked:
		return
	if action == &"water" or action == &"feed":
		if _pouring and _fill > 0.05:
			_release_pour()
		elif _pouring:
			_pouring = false
			stream.emitting = false
			var tw: Tween = create_tween()
			tw.tween_property(can_root, "rotation_degrees:z", 0.0, 0.25)


func _release_pour() -> void:
	_pouring = false
	stream.emitting = false
	_locked = true
	var tw: Tween = create_tween()
	tw.tween_property(can_root, "rotation_degrees:z", 0.0, 0.3)
	# Kalan damlalar biraz daha doldurur
	_fill = minf(_fill + 0.015, 1.0)
	meter.value = _fill
	var err: float = absf(_fill - _target)
	var sc: int = clampi(int(100.0 - maxf(err - 0.02, 0.0) * 450.0), 0, 100)
	_end(sc)


# ================================================================ Budama

func _start_prune() -> void:
	set_step(1, 1, tr("CARE_STEP_PRUNE"), tr("CARE_HINT_PRUNE"))
	_spawn_targets(10, true)
	_time_left = TIME_LIMIT
	timer_label.visible = true


func _spawn_targets(n: int, leaves: bool) -> void:
	var a: AABB = combined_aabb(plant_root)
	var c: Vector3 = a.get_center()
	var radius: float = clampf(maxf(a.size.x, a.size.z) * 0.38, 0.06, 0.25)
	var bottom: float = a.position.y + a.size.y * 0.25
	var top: float = a.end.y - a.size.y * 0.05
	_targets.clear()
	_marked.clear()
	_velocities.clear()
	_total_marked = 0
	for i: int in range(n):
		# Kameraya (+Z) dönük tarafı tercih et
		var ang: float = randf_range(PI * 0.1, PI * 0.9)
		var pos: Vector3 = Vector3(c.x + cos(ang) * radius * randf_range(0.6, 1.0), randf_range(bottom, top), c.z + sin(ang) * radius * randf_range(0.6, 1.0))
		var node := Node3D.new()
		world.add_child(node)
		node.global_position = pos
		var marked: bool = true
		if leaves:
			marked = i < 4
			var leaf_mesh: SphereMesh = sphere(0.035, 10)
			var col: Color = Color(0.78, 0.66, 0.2) if marked else Color(0.3, 0.68, 0.28)
			var mi: MeshInstance3D = prim(leaf_mesh, col, node, Vector3.ZERO, "Leaf")
			mi.scale = Vector3(1.0, 0.25, 0.6)
			mi.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.4, 0.4))
			if marked:
				_total_marked += 1
				var mm: StandardMaterial3D = mi.material_override as StandardMaterial3D
				mm.emission_enabled = true
				mm.emission = Color(1.0, 0.3, 0.2)
				var tw: Tween = create_tween().set_loops(20)
				tw.tween_property(mm, "emission_energy_multiplier", 0.8, 0.35)
				tw.tween_property(mm, "emission_energy_multiplier", 0.0, 0.35)
		else:
			_total_marked += 1
			prim(sphere(0.011, 8), Color(0.18, 0.3, 0.12), node, Vector3.ZERO, "Aphid")
			prim(sphere(0.006, 6), Color(0.05, 0.08, 0.05), node, Vector3(0.01, 0.002, 0), "Head")
			_velocities.append(Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)).normalized() * 0.03)
		_targets.append(node)
		_marked.append(marked)


func _nearest_target(pos: Vector2, max_px: float) -> int:
	var best: int = -1
	var best_d: float = max_px
	for i: int in range(_targets.size()):
		var t: Node3D = _targets[i]
		if t == null or not t.visible:
			continue
		var d: float = world_to_screen(t.global_position).distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func _try_cut(pos: Vector2) -> void:
	var i: int = _nearest_target(pos, 60.0)
	if i < 0:
		return
	var leaf: Node3D = _targets[i]
	leaf.visible = false
	var fall := leaf.duplicate() as Node3D
	world.add_child(fall)
	fall.global_position = leaf.global_position
	fall.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(fall, "global_position", fall.global_position + Vector3(randf_range(-0.1, 0.1), -0.4, 0.15), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fall, "rotation", Vector3(2.0, 3.0, 1.0), 0.8)
	tw.tween_callback(fall.queue_free)
	sfx(&"harvest_snip")
	if _marked[i]:
		_hits += 1
		pop_text(tr("CARE_POP_SNIP"), pos + Vector2(0, -60), C_GOOD, 40)
		if _hits >= _total_marked:
			_finish_timed()
	else:
		_mistakes += 1
		shake(0.6)
		pop_text(tr("CARE_POP_WRONG_LEAF"), pos + Vector2(0, -60), C_BAD, 40)


# ================================================================ Zararlı

func _start_pest() -> void:
	set_step(1, 1, tr("CARE_STEP_PEST"), tr("CARE_HINT_PEST"))
	_spawn_targets(12, false)
	_time_left = TIME_LIMIT
	timer_label.visible = true


func _move_pests(delta: float) -> void:
	var a: AABB = combined_aabb(plant_root)
	var c: Vector3 = a.get_center()
	for i: int in range(_targets.size()):
		var t: Node3D = _targets[i]
		if not t.visible:
			continue
		var v: Vector3 = _velocities[i]
		v = v.rotated(Vector3.UP, randf_range(-3.0, 3.0) * delta)
		var p: Vector3 = t.global_position + v * delta
		# Bitkinin etrafında kal
		var off: Vector3 = p - c
		if Vector2(off.x, off.z).length() > maxf(a.size.x, a.size.z) * 0.45 or p.y < a.position.y + a.size.y * 0.2 or p.y > a.end.y:
			v = -v
			p = t.global_position
		_velocities[i] = v
		t.global_position = p
		if v.length() > 0.0001:
			t.look_at(p + v, Vector3.UP)


func _try_squash(pos: Vector2) -> void:
	var i: int = _nearest_target(pos, 50.0)
	if i < 0:
		_mistakes += 1
		return
	var bug: Node3D = _targets[i]
	_hits += 1
	sfx(&"bubble")
	shake(0.2)
	burst(bug.global_position, Color(0.4, 0.75, 0.2), 10, 0.003, 0.2)
	pop_text(tr("CARE_POP_SQUASH"), pos + Vector2(0, -60), Color(0.7, 1.0, 0.4), 40)
	var tw: Tween = create_tween()
	tw.tween_property(bug, "scale", Vector3(1.8, 0.1, 1.8), 0.1)
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void: bug.visible = false)
	_velocities[i] = Vector3.ZERO
	if _hits >= _total_marked:
		_finish_timed()


# ================================================================ Ortak bitiş

func _tick_timer(delta: float) -> void:
	_time_left -= delta
	timer_label.text = MinigameUtil.fmt(tr("CARE_TIME"), maxf(_time_left, 0.0))
	if _time_left <= 0.0:
		pop_text(tr("CARE_POP_TIME_UP"), Vector2(-1, -1), C_WARN, 60)
		_finish_timed()


func _finish_timed() -> void:
	if _locked:
		return
	_locked = true
	var ratio: float = float(_hits) / float(maxi(_total_marked, 1))
	var penalty: float = float(_mistakes) * (20.0 if action == &"prune" else 3.0)
	var sc: int = clampi(int(ratio * 100.0 - penalty + maxf(_time_left, 0.0) * 1.0), 0, 100)
	_end(sc)


func _end(score: int) -> void:
	var qd: int = clampi(int(round((float(score) - 50.0) / 10.0)), -5, 5)
	var key: String = "MG_RATE_PERFECT" if score >= 85 else ("MG_RATE_GOOD" if score >= 60 else ("MG_RATE_MEH" if score >= 35 else "MG_RATE_BAD"))
	sfx(&"notify_good" if score >= 60 else &"notify_bad")
	pop_text(tr(key), Vector2(-1, -1), C_GOOD if score >= 60 else C_BAD, 64)
	var result: Dictionary = {
		"request_id": int(context.get("request_id", -1)),
		"score": score,
		"quality_delta": qd,
		"action": action,
		"plant_id": int(context.get("plant_id", -1)),
	}
	var tw: Tween = create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(finish.bind(result))


func debug_skip_step() -> void:
	if _locked:
		return
	match action:
		&"water", &"feed":
			_fill = _target
			_release_pour()
		_:
			_hits = _total_marked
			_finish_timed()
