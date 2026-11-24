extends MinigameBase
## Kova bong mini oyunu (GDD §5.5) — 5 adım: batır, doldur, yak, YAVAŞÇA kaldır, çek.
## Sonuç: {"score", "dose", "strength", "minutes", "coughed", "cancelled"}

const M_BUCKET: String = "res://assets/models/hero/bong_bucket.glb"
const M_BOTTLE: String = "res://assets/models/hero/bong_bottle.glb"
const M_LIGHTER: String = "res://assets/models/hero/lighter.glb"
const SMOKE_FX: String = "res://scenes/minigames/gravity_bong/smoke_fx.tscn"
const EXHALE_FX: String = "res://scenes/minigames/gravity_bong/exhale_fx.tscn"

const STEP_KEYS: Array[String] = ["BONG_STEP_PREP", "BONG_STEP_FILL", "BONG_STEP_LIGHT", "BONG_STEP_LIFT", "BONG_STEP_DRAW"]
const HINT_KEYS: Array[String] = ["BONG_HINT_PREP", "BONG_HINT_FILL", "BONG_HINT_LIGHT", "BONG_HINT_LIFT", "BONG_HINT_DRAW"]
## Doz tablosu: gram, temel güç, süre (oyun dakikası)
const DOSES: Dictionary = {
	&"low": [0.25, 0.35, 60],
	&"mid": [0.5, 0.6, 120],
	&"high": [1.0, 0.9, 180],
}
const LEAK_SPEED: float = 0.09 # m/sn üstü kaldırma = duman kaçar

var step: int = -1
var _locked: bool = true
var scores: Array[int] = [0, 0, 0, 0, 0]

var bucket_root: Node3D
var bottle_root: Node3D
var cap_parts: Array[Node3D] = []
var mound: MeshInstance3D
var mound_mat: StandardMaterial3D
var lighter_root: Node3D
var lighter_wheel: Node3D
var flame: MeshInstance3D
var flame_light: OmniLight3D
var smoke_column: MeshInstance3D
var smoke_mat: StandardMaterial3D
var smoke_fx: Node3D
var leak_fx: Node3D

var water_y: float = 0.26
var bottle_h: float = 0.29
var y_start: float = 0.3
var y_sunk: float = 0.04
var y_safe_top: float = 0.22
var y_out: float = 0.25

var meter: MinigameMeter
var ember_meter: MinigameMeter

var dose: StringName = &"mid"
var _bud_id: StringName = &""
var _ember: float = 0.0
var _hold_time: float = 0.0
var _overheat: float = 0.0
var _lighting: bool = false
var _flame_on: bool = false
var _smoke: float = 0.0 # şişedeki duman 0..1
var _leaked: float = 0.0
var _lift_dy: float = 0.0
var _lift_speed: float = 0.0
var _out_of_water: bool = false
var _cap_off: bool = false
var _breath: float = 0.0
var _inhaling: bool = false
var _coughed: bool = false
var _result_strength: float = 0.0
var _result_minutes: int = 0
var final_score: int = 0


# ================================================================ Kurulum

func _build_world() -> void:
	prim(box(Vector3(3, 0.02, 3)), Color(0.36, 0.3, 0.22), world, Vector3(0, -0.01, 0), "Floor")
	# Sera ışığı hissi
	var grow := OmniLight3D.new()
	grow.position = Vector3(0.3, 0.8, -0.3)
	grow.light_color = Color(1.0, 0.55, 0.85)
	grow.light_energy = 0.6
	grow.omni_range = 2.0
	world.add_child(grow)
	_build_bucket()
	_build_bottle()
	_build_lighter()
	_build_ui()


func _build_bucket() -> void:
	bucket_root = Node3D.new()
	bucket_root.name = "Bucket"
	world.add_child(bucket_root)
	var b: Node3D = try_model(M_BUCKET)
	if b != null:
		bucket_root.add_child(b)
		var w: Node3D = find_part(b, "Water")
		var a: AABB = combined_aabb(w if w != null else b)
		water_y = a.get_center().y if w != null else a.end.y * 0.85
	else:
		var c: CylinderMesh = cyl(0.165, 0.135, 0.32, 32)
		c.cap_top = false
		var bm: MeshInstance3D = prim(c, Color(0.2, 0.45, 0.85), bucket_root, Vector3(0, 0.16, 0), "Bucket")
		var m: StandardMaterial3D = mat(Color(0.2, 0.45, 0.85), 0.5)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		bm.material_override = m
		# Sap
		var handle := TorusMesh.new()
		handle.inner_radius = 0.16
		handle.outer_radius = 0.17
		var hm: MeshInstance3D = prim(handle, Color(0.7, 0.7, 0.72), bucket_root, Vector3(0, 0.32, 0), "Handle")
		hm.rotation_degrees = Vector3(90, 0, 0)
		hm.scale = Vector3(1, 1, 0.6)
		water_y = 0.26
		var wm: MeshInstance3D = prim(cyl(0.158, 0.158, 0.004, 32), Color(0.3, 0.6, 0.8, 0.55), bucket_root, Vector3(0, water_y, 0), "Water")
		wm.material_override = mat(Color(0.3, 0.6, 0.8, 0.55), 0.05)


func _build_bottle() -> void:
	bottle_root = Node3D.new()
	bottle_root.name = "BottleRoot"
	world.add_child(bottle_root)
	var bm: Node3D = try_model(M_BOTTLE)
	var top_y: float = 0.29
	if bm != null:
		bottle_root.add_child(bm)
		var bottle: Node3D = find_part(bm, "Bottle")
		var a: AABB = combined_aabb(bottle if bottle != null else bm)
		bottle_h = a.end.y
		top_y = combined_aabb(bm).end.y
		for pn: String in ["Cap", "Bowl"]:
			var p: Node3D = find_part(bm, pn)
			if p != null:
				cap_parts.append(p)
	else:
		var body_m: CylinderMesh = cyl(0.048, 0.048, 0.24, 28)
		body_m.cap_bottom = false
		body_m.cap_top = false
		var body: MeshInstance3D = prim(body_m, Color(0.85, 0.95, 0.9, 0.3), bottle_root, Vector3(0, 0.12, 0), "Bottle")
		var gm: StandardMaterial3D = mat(Color(0.85, 0.95, 0.9, 0.3), 0.05)
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		body.material_override = gm
		var neck: MeshInstance3D = prim(cyl(0.015, 0.048, 0.05, 28), Color(0.85, 0.95, 0.9, 0.3), bottle_root, Vector3(0, 0.265, 0), "Neck")
		neck.material_override = gm
		# Etiket kalıntısı
		prim(cyl(0.0485, 0.0485, 0.05, 28), Color(0.9, 0.3, 0.25, 0.85), bottle_root, Vector3(0, 0.17, 0), "Label")
		var cap := Node3D.new()
		cap.name = "Cap"
		bottle_root.add_child(cap)
		cap.position = Vector3(0, 0.298, 0)
		prim(cyl(0.017, 0.017, 0.016, 18), Color(0.2, 0.55, 0.3), cap, Vector3.ZERO, "CapMesh")
		var bowl: MeshInstance3D = prim(cyl(0.016, 0.008, 0.012, 16), Color(0.82, 0.83, 0.85), cap, Vector3(0, 0.014, 0), "Bowl")
		bowl.material_override = mat(Color(0.82, 0.83, 0.85), 0.25, 0.9)
		cap_parts.append(cap)
		bottle_h = 0.24
		top_y = 0.32
	# Kase dolgusu
	mound = MeshInstance3D.new()
	mound.name = "Mound"
	mound.mesh = sphere(0.012, 10)
	mound_mat = mat(Color(0.35, 0.5, 0.22), 0.9)
	mound_mat.emission_enabled = true
	mound_mat.emission = Color(1.0, 0.35, 0.05)
	mound_mat.emission_energy_multiplier = 0.0
	mound.material_override = mound_mat
	bottle_root.add_child(mound)
	mound.position = Vector3(0, top_y + 0.002, 0)
	mound.scale = Vector3(1, 0.5, 1) * 0.01
	mound.visible = false
	# Şişedeki duman sütunu
	smoke_mat = mat(Color(0.9, 0.95, 0.9, 0.0), 1.0)
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_column = prim(cyl(0.044, 0.044, 1.0, 20), Color(0.9, 0.95, 0.9, 0.0), world, Vector3.ZERO, "SmokeColumn")
	smoke_column.material_override = smoke_mat
	smoke_column.visible = false
	# Duman parçacıkları (Codex sahnesi ya da yedek)
	smoke_fx = _load_fx(SMOKE_FX, false)
	bottle_root.add_child(smoke_fx)
	smoke_fx.position = Vector3(0, bottle_h * 0.55, 0)
	smoke_fx.scale = Vector3.ONE * clampf(bottle_h / 0.24, 0.5, 2.5)
	_set_fx(smoke_fx, false, 0.0)
	leak_fx = _load_fx(SMOKE_FX, false)
	world.add_child(leak_fx)
	leak_fx.position = Vector3(0.06, water_y, 0.03)
	leak_fx.scale = Vector3(2.5, 1.2, 2.5)
	_set_fx(leak_fx, false, 0.0)
	# Konumlar
	y_sunk = water_y - bottle_h + 0.03
	y_start = water_y + 0.04
	y_safe_top = water_y - 0.035
	y_out = water_y - 0.004
	bottle_root.position = Vector3(0, y_start, 0)


func _build_lighter() -> void:
	lighter_root = Node3D.new()
	lighter_root.name = "Lighter"
	world.add_child(lighter_root)
	var lm: Node3D = try_model(M_LIGHTER)
	if lm != null:
		lighter_root.add_child(lm)
		lighter_wheel = find_part(lm, "Wheel")
	else:
		prim(box(Vector3(0.025, 0.07, 0.013)), Color(0.9, 0.25, 0.3), lighter_root, Vector3(0, 0.035, 0), "Body")
		prim(box(Vector3(0.022, 0.012, 0.012)), Color(0.75, 0.75, 0.78), lighter_root, Vector3(0, 0.076, 0), "Hood")
	if lighter_wheel == null:
		lighter_wheel = Node3D.new()
		lighter_wheel.name = "Wheel"
		lighter_root.add_child(lighter_wheel)
		lighter_wheel.position = Vector3(-0.004, 0.085, 0)
		var wm: MeshInstance3D = prim(cyl(0.006, 0.006, 0.008, 12), Color(0.4, 0.4, 0.42), lighter_wheel, Vector3.ZERO, "WheelMesh")
		wm.rotation_degrees = Vector3(90, 0, 0)
	flame = MeshInstance3D.new()
	flame.name = "Flame"
	flame.mesh = sphere(0.007, 10)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.65, 0.15, 0.9)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.5, 0.1)
	fm.emission_energy_multiplier = 3.0
	flame.material_override = fm
	lighter_root.add_child(flame)
	flame.position = Vector3(0, 0.1, 0)
	flame.scale = Vector3(1, 2.2, 1)
	flame.visible = false
	flame_light = OmniLight3D.new()
	flame_light.light_color = Color(1.0, 0.6, 0.2)
	flame_light.omni_range = 0.6
	flame_light.light_energy = 0.0
	lighter_root.add_child(flame_light)
	flame_light.position = Vector3(0, 0.11, 0)
	lighter_root.position = Vector3(0.3, 0.0, 0.18)
	lighter_root.rotation_degrees = Vector3(0, -30, 0)


func _build_ui() -> void:
	meter = MinigameMeter.new()
	meter.anchor_left = 0.5
	meter.anchor_right = 0.5
	meter.anchor_top = 1.0
	meter.anchor_bottom = 1.0
	meter.offset_left = -360
	meter.offset_right = 360
	meter.offset_top = -210
	meter.offset_bottom = -166
	meter.visible = false
	ui.add_child(meter)
	ember_meter = MinigameMeter.new()
	ember_meter.vertical = true
	ember_meter.anchor_left = 1.0
	ember_meter.anchor_right = 1.0
	ember_meter.anchor_top = 0.5
	ember_meter.anchor_bottom = 0.5
	ember_meter.offset_left = -150
	ember_meter.offset_right = -96
	ember_meter.offset_top = -220
	ember_meter.offset_bottom = 220
	ember_meter.visible = false
	ui.add_child(ember_meter)


## Efekt sahnesini yükler; yoksa geçici GPUParticles3D duman üretir.
func _load_fx(path: String, big: bool) -> Node3D:
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path) as PackedScene
		if ps != null:
			var n: Node = ps.instantiate()
			if n is Node3D:
				return n as Node3D
			n.free()
	var p := GPUParticles3D.new()
	p.name = "FallbackSmoke"
	p.amount = 40 if big else 32
	p.lifetime = 1.6
	p.one_shot = big
	p.explosiveness = 0.85 if big else 0.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.15, -1) if big else Vector3.UP
	pm.spread = 18.0 if big else 10.0
	pm.initial_velocity_min = 0.4 if big else 0.01
	pm.initial_velocity_max = 0.8 if big else 0.03
	pm.gravity = Vector3(0, 0.2, 0) if big else Vector3(0, 0.003, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.05, 0.05, 0.05) if big else Vector3(0.016, 0.05, 0.016)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.35) if big else Vector2(0.05, 0.06)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.92, 0.95, 0.9, 0.35)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = qm
	p.draw_pass_1 = q
	p.emitting = false
	return p


## Duman yoğunluğu: GPUParticles3D ise amount_ratio, değilse varsa set_intensity/density.
func _set_fx(fx: Node, on: bool, intensity: float) -> void:
	if fx == null:
		return
	if fx.has_method(&"set_intensity"):
		fx.call(&"set_intensity", intensity)
	if fx is GPUParticles3D:
		var gp: GPUParticles3D = fx as GPUParticles3D
		gp.amount_ratio = clampf(intensity, 0.05, 1.0)
		if gp.emitting != on:
			gp.emitting = on
	for c: Node in fx.find_children("*", "GPUParticles3D", true, false):
		var g2: GPUParticles3D = c as GPUParticles3D
		g2.amount_ratio = clampf(intensity, 0.05, 1.0)
		g2.emitting = on


func _begin() -> void:
	if not MinigameUtil.consumption_enabled():
		MinigameUtil.notify(tr("BONG_DECOR_ONLY"), &"info")
		finish({"cancelled": true, "decor": true})
		return
	set_title(tr("BONG_TITLE"))
	help_level = 2
	look_from(Vector3(0, 0.62, 0.62), Vector3(0, 0.24, 0), 0.0)
	var tw: Tween = create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(_enter_step.bind(0))


# ================================================================ Adımlar

func _enter_step(i: int) -> void:
	step = i
	_locked = false
	clear_actions()
	meter.visible = false
	ember_meter.visible = false
	set_step(i + 1, 5, tr(STEP_KEYS[i]), tr(HINT_KEYS[i]))
	match i:
		0:
			look_from(Vector3(0, 0.6, 0.55), Vector3(0, 0.22, 0))
			meter.left_text = tr("BONG_DEPTH")
			meter.right_text = ""
			meter.show_zone = true
			meter.zone_min = 0.85
			meter.zone_max = 1.0
			meter.value = 0.0
			meter.visible = true
		1:
			look_from(Vector3(0, water_y + 0.25, 0.25), Vector3(0, water_y + 0.03, 0))
			_add_dose_button(&"low", "BONG_DOSE_LOW")
			_add_dose_button(&"mid", "BONG_DOSE_MID")
			_add_dose_button(&"high", "BONG_DOSE_HIGH")
		2:
			look_from(Vector3(0.12, water_y + 0.16, 0.24), Vector3(0, water_y + 0.04, 0))
			var bowl_top: Vector3 = mound.global_position
			var tw: Tween = create_tween()
			tw.tween_property(lighter_root, "global_position", bowl_top + Vector3(0.025, -0.11, 0.025), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(lighter_root, "rotation_degrees", Vector3(0, 0, 25), 0.6)
			ember_meter.zone_min = 0.85
			ember_meter.zone_max = 1.0
			ember_meter.right_text = tr("BONG_EMBER")
			ember_meter.left_text = ""
			ember_meter.value = 0.0
			ember_meter.visible = true
			_ember = 0.0
			_overheat = 0.0
			_hold_time = 0.0
		3:
			look_from(Vector3(0, water_y + 0.05, 0.6), Vector3(0, water_y - 0.08, 0))
			var tw2: Tween = create_tween()
			tw2.tween_property(lighter_root, "position", Vector3(0.3, 0.0, 0.18), 0.5)
			tw2.parallel().tween_property(lighter_root, "rotation_degrees", Vector3(0, -30, 0), 0.5)
			_smoke = 0.0
			_leaked = 0.0
			_out_of_water = false
			smoke_column.visible = true
			meter.left_text = tr("BONG_SMOKE")
			meter.right_text = ""
			meter.show_zone = false
			meter.fill_color = Color(0.9, 0.95, 0.9)
			meter.value = 0.0
			meter.visible = true
			ember_meter.value = _ember
			ember_meter.show_zone = false
			ember_meter.visible = true
			add_action(tr("MG_DONE"), _finish_lift)
		4:
			look_from(Vector3(0, bottle_root.position.y + bottle_h + 0.12, 0.3), Vector3(0, bottle_root.position.y + bottle_h, 0))
			_cap_off = false
			_breath = 0.0
			_inhaling = false
			add_action(tr("BONG_REMOVE_CAP"), _remove_cap)


func _complete_step(score: int) -> void:
	if _locked:
		return
	_locked = true
	scores[step] = clampi(score, 0, 100)
	var txt: String = tr("MG_RATE_PERFECT") if score >= 85 else (tr("MG_RATE_GOOD") if score >= 60 else (tr("MG_RATE_MEH") if score >= 35 else tr("MG_RATE_BAD")))
	var col: Color = C_GOOD if score >= 60 else (C_WARN if score >= 35 else C_BAD)
	pop_text(txt, Vector2(-1, -1), col, 60)
	clear_actions()
	var tw: Tween = create_tween()
	tw.tween_interval(0.9)
	if step < 4:
		tw.tween_callback(_enter_step.bind(step + 1))
	else:
		tw.tween_callback(_exhale)


func debug_skip_step() -> void:
	if _locked or step < 0:
		return
	match step:
		0:
			bottle_root.position.y = y_sunk
			_complete_step(100)
		1:
			_choose_dose(&"mid")
		2:
			_ember = 1.0
			_flame_on = false
			_complete_step(90)
		3:
			_smoke = 0.8
			_finish_lift()
		4:
			_cap_off = true
			_breath = 0.85
			_finish_draw()


# ================================================================ Giriş

func _on_press(_pos: Vector2) -> void:
	if _locked:
		return
	if step == 2:
		_lighting = true
		_hold_time = 0.0
		sfx(&"lighter_flick")
		burst(lighter_wheel.global_position + Vector3(0, 0.008, 0), Color(1.0, 0.8, 0.3), 8, 0.0012, 0.25)
	elif step == 4 and _cap_off:
		_inhaling = true
		sfx(&"inhale")


func _on_drag(_pos: Vector2, rel: Vector2) -> void:
	if _locked:
		return
	if step == 0:
		var y: float = clampf(bottle_root.position.y - rel.y * 0.0009, y_sunk, y_start)
		bottle_root.position.y = y
		meter.value = inverse_lerp(y_start, y_sunk, y)
		if y < water_y and randf() < 0.3:
			sfx(&"bubble")
		if y <= y_sunk + 0.002:
			sfx(&"water_pour")
			burst(Vector3(0.05, water_y, 0.0), Color(0.5, 0.75, 1.0, 0.8), 18, 0.004, 0.35)
			squash(bucket_root, 0.06)
			_complete_step(100)
	elif step == 3:
		_lift_dy += -rel.y * 0.0006


func _on_release(_pos: Vector2) -> void:
	if _locked:
		return
	if step == 2:
		_lighting = false
		if _ember >= 0.85:
			_flame(false)
			var sc: int = int(100.0 - _overheat * 60.0)
			if _overheat > 0.6:
				pop_text(tr("BONG_POP_CHARCOAL"), Vector2(-1, 320), C_BAD)
			_complete_step(sc)
	elif step == 4 and _inhaling:
		_inhaling = false
		_finish_draw()


func _process(delta: float) -> void:
	super._process(delta)
	if _locked:
		_flame_flicker(delta)
		return
	match step:
		2: _process_light(delta)
		3: _process_lift(delta)
		4: _process_draw(delta)
	_flame_flicker(delta)


# ---------------------------------------------------------------- 2. Doldur

func _add_dose_button(d: StringName, key: String) -> void:
	var b: Button = add_action(tr(key), _choose_dose.bind(d), Color(0.3, 0.55, 0.35) if d != &"high" else Color(0.7, 0.35, 0.2))
	if MinigameUtil.has_inventory():
		var grams: float = float((DOSES[d] as Array)[0])
		if MinigameUtil.best_dry_bud(grams).is_empty():
			b.disabled = true


func _choose_dose(d: StringName) -> void:
	if _locked:
		return
	dose = d
	var grams: float = float((DOSES[d] as Array)[0])
	if MinigameUtil.has_inventory():
		var bud: Dictionary = MinigameUtil.best_dry_bud(grams)
		if bud.is_empty():
			MinigameUtil.notify(tr("BONG_NO_BUD"), &"bad")
			return
		_bud_id = StringName(str(bud.get("id", "")))
	mound.visible = true
	var s: float = 0.7 + grams * 0.6
	var tw: Tween = create_tween()
	tw.tween_property(mound, "scale", Vector3(s, 0.6 * s, s), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	burst(mound.global_position + Vector3(0, 0.01, 0), Color(0.35, 0.55, 0.22), 12, 0.002, 0.15)
	sfx(&"grinder")
	if d == &"high":
		pop_text(tr("BONG_POP_HIGH"), Vector2(-1, 330), C_WARN)
	_complete_step(100)


# ---------------------------------------------------------------- 3. Yak

func _process_light(delta: float) -> void:
	if _lighting:
		_hold_time += delta
		if lighter_wheel != null:
			lighter_wheel.rotate_object_local(Vector3.FORWARD, delta * 25.0)
		if _hold_time > 0.35 and not _flame_on:
			_flame(true)
		if _flame_on:
			_ember = minf(_ember + delta * 0.6, 1.0)
			if _ember >= 1.0:
				_overheat += delta * 0.5
				if randf() < delta * 3.0:
					shake(0.2)
				if _overheat > 1.4:
					_lighting = false
					_flame(false)
					pop_text(tr("BONG_POP_CHARCOAL"), Vector2(-1, 320), C_BAD)
					shake(0.8)
					_complete_step(15)
					return
	else:
		_ember = maxf(_ember - delta * 0.25, 0.0)
	ember_meter.value = _ember
	mound_mat.emission_energy_multiplier = _ember * 2.5
	if _ember > 0.5 and randf() < delta * 6.0:
		burst(mound.global_position + Vector3(0, 0.008, 0), Color(1.0, 0.5, 0.1), 3, 0.0008, 0.1)


func _flame(on: bool) -> void:
	_flame_on = on
	flame.visible = on
	if on:
		sfx(&"lighter_flick")
		flame.scale = Vector3(0.2, 0.4, 0.2)
		var tw: Tween = create_tween()
		tw.tween_property(flame, "scale", Vector3(1, 2.2, 1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		flame_light.light_energy = 0.0


func _flame_flicker(_delta: float) -> void:
	if _flame_on:
		flame_light.light_energy = 1.4 + randf_range(-0.4, 0.4)
		flame.scale.y = 2.2 + randf_range(-0.3, 0.3)


# ---------------------------------------------------------------- 4. Kaldır

func _process_lift(delta: float) -> void:
	var dy: float = _lift_dy
	_lift_dy = 0.0
	var y0: float = bottle_root.position.y
	var y1: float = clampf(y0 + dy, y_sunk, y_out + 0.02)
	bottle_root.position.y = y1
	var moved: float = y1 - y0
	var inst_speed: float = moved / maxf(delta, 0.001)
	_lift_speed = lerpf(_lift_speed, inst_speed, 1.0 - exp(-8.0 * delta))
	_ember = maxf(_ember - delta * 0.06, 0.0)
	ember_meter.value = _ember
	mound_mat.emission_energy_multiplier = _ember * 2.5
	if moved > 0.0:
		var total: float = maxf(y_safe_top - y_sunk, 0.01)
		var gain: float = moved / total
		if _lift_speed > LEAK_SPEED:
			# Çok hızlı: dumanın bir kısmı kaçar
			var loss: float = clampf((_lift_speed - LEAK_SPEED) / LEAK_SPEED, 0.0, 1.0)
			_leaked += gain * loss
			gain *= 1.0 - loss * 0.8
			_set_fx(leak_fx, true, loss)
			if randf() < 0.15:
				sfx(&"bubble")
				shake(0.3)
				pop_text(tr("BONG_POP_LEAK"), world_to_screen(Vector3(0, water_y, 0)) + Vector2(randf_range(-150, 150), 0), C_WARN, 38)
		else:
			_set_fx(leak_fx, false, 0.0)
			if randf() < 0.08:
				sfx(&"bubble")
		_smoke = clampf(_smoke + gain * clampf(0.3 + _ember, 0.0, 1.0), 0.0, 1.0)
	else:
		_set_fx(leak_fx, false, 0.0)
	_update_smoke_visual()
	meter.value = _smoke
	if y1 >= y_out and not _out_of_water:
		_out_of_water = true
		_smoke *= 0.1
		_set_fx(leak_fx, true, 1.0)
		shake(1.0)
		sfx(&"water_pour")
		burst(Vector3(0, water_y, 0), Color(0.5, 0.75, 1.0, 0.8), 24, 0.005, 0.5)
		pop_text(tr("BONG_POP_OUT"), Vector2(-1, -1), C_BAD, 64)
		_finish_lift()


func _update_smoke_visual() -> void:
	var bottom: float = water_y
	var top: float = bottle_root.position.y + bottle_h
	var h: float = maxf(top - bottom, 0.001)
	smoke_column.position = Vector3(0, bottom + h * 0.5, 0)
	smoke_column.scale = Vector3(1, h, 1)
	smoke_mat.albedo_color.a = _smoke * 0.55
	_set_fx(smoke_fx, _smoke > 0.02, _smoke)


func _finish_lift() -> void:
	if _locked:
		return
	_set_fx(leak_fx, false, 0.0)
	var reach: float = clampf(inverse_lerp(y_sunk, y_safe_top, bottle_root.position.y), 0.0, 1.0)
	var sc: float = 100.0 * _smoke * (0.6 + 0.4 * reach)
	if _out_of_water:
		sc = 10.0
	_complete_step(int(sc))


# ---------------------------------------------------------------- 5. Çek

func _remove_cap() -> void:
	if _cap_off or _locked:
		return
	_cap_off = true
	clear_actions()
	sfx(&"paper_rustle")
	var tw: Tween = create_tween().set_parallel(true)
	for p: Node3D in cap_parts:
		tw.tween_property(p, "position", p.position + Vector3(0.12, 0.08, 0.02), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", Vector3(0.6, 0, 1.2), 0.4)
	tw.tween_property(mound, "position", mound.position + Vector3(0.12, 0.08, 0.02), 0.4)
	hint_label.text = tr("BONG_HINT_BREATH")
	meter.left_text = tr("BONG_BREATH")
	meter.right_text = tr("BONG_LUNGS_FULL")
	meter.zone_min = 0.75
	meter.zone_max = 0.92
	meter.show_zone = true
	meter.fill_color = Color(0.6, 0.85, 1.0)
	meter.value = 0.0
	meter.visible = true


func _process_draw(delta: float) -> void:
	if not _cap_off or not _inhaling:
		return
	_breath += delta * (0.3 + 0.3 * _smoke)
	meter.value = _breath
	# Şişe aşağı itilir, duman çekilir
	var target_y: float = lerpf(bottle_root.position.y, y_sunk, delta * 0.8)
	bottle_root.position.y = target_y
	_smoke = maxf(_smoke - delta * 0.35, 0.0)
	_update_smoke_visual()
	if randf() < delta * 4.0:
		sfx(&"bubble")
	if _breath >= 1.0:
		_inhaling = false
		_finish_draw()


func _finish_draw() -> void:
	if _locked:
		return
	var sc: float
	if _breath >= 1.0:
		_coughed = true
		sc = 30.0
	elif _breath >= 0.75 and _breath <= 0.92:
		sc = 100.0
	elif _breath > 0.92:
		sc = 85.0
		_coughed = randf() < 0.5
	else:
		sc = _breath / 0.75 * 80.0
	_complete_step(int(sc))


# ================================================================ Sonuç

func _exhale() -> void:
	var d: Array = DOSES[dose] as Array
	var grams: float = float(d[0])
	if MinigameUtil.has_inventory() and _bud_id != &"":
		MinigameUtil.consume_bud(_bud_id, grams)
	var eff: float = (float(scores[2]) + float(scores[3]) + float(scores[4])) / 300.0
	_result_strength = clampf(float(d[1]) * (0.5 + 0.5 * eff), 0.1, 1.0)
	if dose == &"high" and eff >= 0.8:
		_result_strength = 1.0
	_result_minutes = int(round(float(d[2]) * (0.7 + 0.3 * eff)))
	final_score = int(round(eff * 100.0))
	# Kamera geri çekilir, dev komik duman bulutu
	look_from(Vector3(0, 0.55, 0.75), Vector3(0, 0.3, 0), 0.6)
	var ex: Node3D = _load_fx(EXHALE_FX, true)
	world.add_child(ex)
	ex.global_position = camera.global_position + Vector3(0, -0.12, -0.25)
	ex.scale = Vector3.ONE * (0.6 + _result_strength)
	_set_fx(ex, true, 1.0)
	if ex is GPUParticles3D:
		(ex as GPUParticles3D).restart()
	sfx(&"cough")
	shake(1.0 if _coughed else 0.5)
	pop_text(tr("BONG_POP_COUGH") if _coughed else tr("BONG_POP_EXHALE"), Vector2(-1, -1), Color(0.95, 0.95, 0.8), 72)
	if _coughed:
		var tw: Tween = create_tween()
		for k: int in range(3):
			tw.tween_interval(0.45)
			tw.tween_callback(func() -> void:
				sfx(&"cough")
				shake(0.7)
				pop_text(tr("BONG_POP_COUGH_SMALL"), Vector2(randf_range(400, 1500), randf_range(300, 700)), Color(1, 0.9, 0.8), 44))
	var tw2: Tween = create_tween()
	tw2.tween_interval(1.6)
	tw2.tween_callback(_show_final)


func _show_final() -> void:
	step_label.text = tr("BONG_RESULT")
	var lines: Array[String] = [
		MinigameUtil.fmt(tr("BONG_RESULT_STRENGTH"), int(round(_result_strength * 100.0))),
		MinigameUtil.fmt(tr("BONG_RESULT_DURATION"), (float(_result_minutes) / 60.0)),
	]
	if _coughed:
		lines.append(tr("BONG_RESULT_COUGHED"))
	if dose == &"high":
		lines.append(tr("BONG_RESULT_HIGH_WARN"))
	show_result(tr("BONG_RESULT_TITLE"), final_score, lines, [[tr("MG_OK"), _apply_and_finish]])


func _apply_and_finish() -> void:
	MinigameUtil.start_gafti(_result_strength, _result_minutes)
	var qm: Node = MinigameUtil.autoload("QuestManager")
	if qm != null and qm.has_method(&"notify_event"):
		qm.call(&"notify_event", &"bong_used", {"dose": dose, "score": final_score})
	finish({"score": final_score, "dose": dose, "strength": _result_strength, "minutes": _result_minutes, "coughed": _coughed})
