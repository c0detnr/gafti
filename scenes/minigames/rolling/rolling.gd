extends MinigameBase
## Joint sarma mini oyunu (GDD §5.4) — 6 adım: öğüt, filtre, dağıt, sar, yapıştır, bük.
## Context (isteğe bağlı): {"bud_id": StringName, "strain": StringName, "quality": int}
## Sonuç: {"score", "quality", "roll_name", "item", "smoked", "cancelled", "step_scores"}

const PAPER_SHADER: Shader = preload("res://scenes/minigames/rolling/paper_curl.gdshader")

const M_GRINDER: String = "res://assets/models/hero/grinder.glb"
const M_PAPER: String = "res://assets/models/hero/rolling_paper.glb"
const M_FILTER: String = "res://assets/models/hero/filter_tip.glb"
const M_JOINT: String = "res://assets/models/hero/joint.glb"
const M_TRAY: String = "res://assets/models/hero/rolling_tray.glb"

const PAPER_L: float = 0.11
const PAPER_W: float = 0.045
const FILTER_LEN: float = 0.018
const ROLL_R: float = 0.0045
const GRINDER_POS: Vector3 = Vector3(-0.15, 0.0, -0.035)
const CARD_POS: Vector3 = Vector3(0.15, 0.002, -0.035)
const BINS: int = 12
const SPREAD_BUDGET: float = 100.0
const LICK_SEGS: int = 16

const STEP_KEYS: Array[String] = ["ROLL_STEP_GRIND", "ROLL_STEP_FILTER", "ROLL_STEP_SPREAD", "ROLL_STEP_ROLL", "ROLL_STEP_LICK", "ROLL_STEP_TWIST"]
const HINT_KEYS: Array[String] = ["ROLL_HINT_GRIND", "ROLL_HINT_FILTER", "ROLL_HINT_SPREAD", "ROLL_HINT_ROLL", "ROLL_HINT_LICK", "ROLL_HINT_TWIST"]
const WEIGHTS: Array[float] = [0.15, 0.15, 0.2, 0.25, 0.15, 0.1]

var step: int = -1
var scores: Array[int] = [0, 0, 0, 0, 0, 0]
var outcomes: Array[StringName] = [&"", &"", &"", &"", &"", &""]
var _locked: bool = true

# Sahne düğümleri
var grinder_lid: Node3D
var grinder_root: Node3D
var card: Node3D
var card_ridges: Array[MeshInstance3D] = []
var filter_tip: Node3D
var paper_mi: MeshInstance3D
var paper_mat: ShaderMaterial
var paper_across_x: bool = false
var paper_center: float = 0.0
var paper_half: float = PAPER_W * 0.5
var paper_base_y: float = 0.0
var crumbs: MultiMeshInstance3D
var core: MeshInstance3D
var joint_root: Node3D
var seam: MeshInstance3D
var wet_marks: Array[MeshInstance3D] = []
var tip: Node3D

# UI
var meter: MinigameMeter
var pressure_meter: MinigameMeter
var heat: MinigameMeter
var guide: Label
var done_button: Button

# Adım durumları
var _grind_angle: float = 0.0
var _grind_last: float = 0.0
var _grind_has_last: bool = false
var _grain: StringName = &"good"
var _fold: int = 0
var _fold_scores: Array[float] = []
var _press_pos: Vector2 = Vector2.ZERO
var _bins: PackedFloat32Array = PackedFloat32Array()
var _budget: float = SPREAD_BUDGET
var _spilled: float = 0.0
var _crumb_accum: float = 0.0
var _roll_progress: float = 0.0
var _stroke_len: float = 0.0
var _stroke_sign: int = 0
var _frame_dy: float = 0.0
var _speed: float = 0.0
var _t_good: float = 0.0
var _t_tight: float = 0.0
var _t_loose: float = 0.0
var _wet: Array[bool] = []
var _slobber: float = 0.0
var _twist_angle: float = 0.0
var _twist_last: float = 0.0
var _twist_has_last: bool = false
var _tip_broken: bool = false

var final_score: int = 0
var roll_name: String = ""


# ================================================================ Kurulum

func _build_world() -> void:
	# Masa + tepsi
	var table: MeshInstance3D = prim(box(Vector3(1.4, 0.04, 0.9)), Color(0.42, 0.27, 0.16), world, Vector3(0, -0.03, 0), "Table")
	table.material_override = mat(Color(0.42, 0.27, 0.16), 0.85)
	var tray: Node3D = try_model(M_TRAY)
	if tray != null:
		world.add_child(tray)
		tray.position = Vector3(0, -0.01, 0)
	else:
		prim(box(Vector3(0.46, 0.006, 0.26)), Color(0.72, 0.18, 0.16), world, Vector3(0, -0.006, 0), "Tray")
		# Karadeniz motifi: sarı-yeşil kenar şeritleri
		prim(box(Vector3(0.46, 0.0065, 0.012)), Color(0.95, 0.8, 0.25), world, Vector3(0, -0.005, 0.124))
		prim(box(Vector3(0.46, 0.0065, 0.012)), Color(0.95, 0.8, 0.25), world, Vector3(0, -0.005, -0.124))
		for i: int in range(7):
			prim(sphere(0.006, 8), Color(0.2, 0.55, 0.3), world, Vector3(-0.18 + i * 0.06, -0.003, 0.124))
	_build_grinder()
	_build_card()
	_build_paper()
	_build_crumbs()
	_build_ui()


func _build_grinder() -> void:
	grinder_root = Node3D.new()
	grinder_root.name = "Grinder"
	world.add_child(grinder_root)
	grinder_root.position = GRINDER_POS
	var g: Node3D = try_model(M_GRINDER)
	if g != null:
		grinder_root.add_child(g)
		grinder_lid = find_part(g, "Lid")
	if grinder_lid == null:
		if g != null:
			g.visible = false
		var base: MeshInstance3D = prim(cyl(0.03, 0.03, 0.03, 32), Color(0.55, 0.6, 0.62), grinder_root, Vector3(0, 0.015, 0), "Base")
		base.material_override = mat(Color(0.55, 0.6, 0.62), 0.35, 0.8)
		grinder_lid = Node3D.new()
		grinder_lid.name = "Lid"
		grinder_root.add_child(grinder_lid)
		grinder_lid.position = Vector3(0, 0.037, 0)
		var lid_mesh: MeshInstance3D = prim(cyl(0.031, 0.031, 0.014, 32), Color(0.2, 0.55, 0.35), grinder_lid, Vector3.ZERO, "LidMesh")
		lid_mesh.material_override = mat(Color(0.2, 0.55, 0.35), 0.3, 0.7)
		# Tırtıklar (dönüşü görünür kılar)
		for i: int in range(12):
			var a: float = TAU * float(i) / 12.0
			prim(box(Vector3(0.004, 0.012, 0.004)), Color(0.9, 0.8, 0.3), grinder_lid, Vector3(cos(a) * 0.031, 0, sin(a) * 0.031))
		prim(box(Vector3(0.022, 0.003, 0.004)), Color(1, 1, 1), grinder_lid, Vector3(0, 0.0085, 0))


func _build_card() -> void:
	card = Node3D.new()
	card.name = "FilterCard"
	world.add_child(card)
	card.position = CARD_POS
	prim(box(Vector3(0.06, 0.0008, 0.02)), Color(0.86, 0.78, 0.6), card, Vector3.ZERO, "Card")
	for i: int in range(3):
		var r: MeshInstance3D = prim(box(Vector3(0.0012, 0.003, 0.02)), Color(0.7, 0.6, 0.42), card, Vector3(-0.02 + i * 0.02, 0.0015, 0))
		r.visible = false
		card_ridges.append(r)


func _build_paper() -> void:
	paper_mat = ShaderMaterial.new()
	paper_mat.shader = PAPER_SHADER
	paper_mi = MeshInstance3D.new()
	paper_mi.name = "Paper"
	world.add_child(paper_mi)
	var used_glb: bool = false
	var pm: Node3D = try_model(M_PAPER)
	if pm != null:
		var src: MeshInstance3D = find_part(pm, "Paper") as MeshInstance3D
		if src == null:
			for n: Node in pm.find_children("*", "MeshInstance3D", true, false):
				src = n as MeshInstance3D
				break
		if src != null and src.mesh != null:
			var a: AABB = src.mesh.get_aabb()
			var long_len: float = maxf(a.size.x, a.size.z)
			if long_len > 0.0001:
				used_glb = true
				paper_mi.mesh = src.mesh
				paper_across_x = a.size.x < a.size.z
				paper_center = (a.get_center().x if paper_across_x else a.get_center().z)
				paper_half = (a.size.x if paper_across_x else a.size.z) * 0.5
				paper_base_y = a.position.y + a.size.y * 0.5
				var s: float = PAPER_L / long_len
				var basis: Basis = Basis.IDENTITY
				if paper_across_x:
					basis = Basis(Vector3.UP, PI * 0.5) # yerel Z (uzun) → dünya X
				basis = basis.scaled(Vector3(s, s, s))
				var c: Vector3 = a.get_center()
				c.y = a.position.y
				paper_mi.transform = Transform3D(basis, -(basis * c))
		pm.free()
	if not used_glb:
		var pl := PlaneMesh.new()
		pl.size = Vector2(PAPER_L, PAPER_W)
		pl.subdivide_width = 8
		pl.subdivide_depth = 32
		paper_mi.mesh = pl
		paper_across_x = false
		paper_center = 0.0
		paper_half = PAPER_W * 0.5
		paper_base_y = 0.0
		paper_mi.position = Vector3(0, 0.001, 0)
	paper_mat.set_shader_parameter(&"across_x", paper_across_x)
	paper_mat.set_shader_parameter(&"center", paper_center)
	paper_mat.set_shader_parameter(&"half_width", paper_half)
	paper_mat.set_shader_parameter(&"base_y", paper_base_y)
	var scale_f: float = paper_mi.transform.basis.get_scale().x
	paper_mat.set_shader_parameter(&"radius", ROLL_R / maxf(scale_f, 0.0001))
	paper_mat.set_shader_parameter(&"curl", 0.0)
	paper_mi.material_override = paper_mat
	paper_mi.extra_cull_margin = 0.05


func _build_crumbs() -> void:
	crumbs = MultiMeshInstance3D.new()
	crumbs.name = "Crumbs"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 600
	mm.visible_instance_count = 0
	var m: SphereMesh = sphere(0.0013, 6)
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 0.9
	m.material = cm
	mm.mesh = m
	crumbs.multimesh = mm
	world.add_child(crumbs)
	core = prim(cyl(ROLL_R * 0.8, ROLL_R * 0.8, PAPER_L - FILTER_LEN - 0.004, 12), Color(0.33, 0.48, 0.22), world, Vector3.ZERO, "Core")
	core.rotation_degrees = Vector3(0, 0, 90)
	core.visible = false


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

	pressure_meter = MinigameMeter.new()
	pressure_meter.vertical = true
	pressure_meter.anchor_left = 1.0
	pressure_meter.anchor_right = 1.0
	pressure_meter.anchor_top = 0.5
	pressure_meter.anchor_bottom = 0.5
	pressure_meter.offset_left = -150
	pressure_meter.offset_right = -96
	pressure_meter.offset_top = -220
	pressure_meter.offset_bottom = 220
	pressure_meter.zone_min = 0.35
	pressure_meter.zone_max = 0.65
	pressure_meter.right_text = tr("ROLL_TIGHT")
	pressure_meter.left_text = tr("ROLL_LOOSE")
	pressure_meter.visible = false
	ui.add_child(pressure_meter)

	heat = MinigameMeter.new()
	heat.anchor_left = 0.5
	heat.anchor_right = 0.5
	heat.anchor_top = 1.0
	heat.anchor_bottom = 1.0
	heat.offset_left = -420
	heat.offset_right = 420
	heat.offset_top = -290
	heat.offset_bottom = -240
	heat.visible = false
	ui.add_child(heat)

	guide = _label("", 64, Color(1, 1, 0.6))
	guide.visible = false
	ui.add_child(guide)


func _begin() -> void:
	var rc: int = MinigameUtil.rolled_count()
	help_level = 2 if rc < 3 else (1 if rc < 8 else 0)
	set_title(tr("ROLL_TITLE"))
	look_from(Vector3(0, 0.34, 0.26), Vector3(0, 0, 0), 0.0)
	var tw: Tween = create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(_enter_step.bind(0))


# ================================================================ Adım makinesi

func _enter_step(i: int) -> void:
	step = i
	_locked = false
	clear_actions()
	done_button = null
	meter.visible = false
	pressure_meter.visible = false
	heat.visible = false
	guide.visible = false
	set_step(i + 1, 6, tr(STEP_KEYS[i]), tr(HINT_KEYS[i]) if help_level > 0 else "")
	match i:
		0:
			look_from(GRINDER_POS + Vector3(0, 0.17, 0.11), GRINDER_POS + Vector3(0, 0.03, 0))
			meter.left_text = tr("ROLL_COARSE")
			meter.right_text = tr("ROLL_POWDER")
			meter.zone_min = 0.4
			meter.zone_max = 0.7
			meter.show_zone = help_level >= 1
			meter.value = 0.0
			meter.visible = true
			done_button = add_action(tr("MG_DONE"), _finish_grind)
			done_button.disabled = true
		1:
			look_from(CARD_POS + Vector3(0, 0.12, 0.08), CARD_POS)
			_fold = 0
			_fold_scores.clear()
			_update_fold_guide()
		2:
			_bins = PackedFloat32Array()
			_bins.resize(BINS)
			_bins.fill(0.0)
			_budget = SPREAD_BUDGET
			_spilled = 0.0
			look_from(Vector3(0, 0.15, 0.1), Vector3(0, 0, 0))
			heat.visible = help_level >= 1
			heat.set_bins(_bins, SPREAD_BUDGET / float(BINS))
			meter.left_text = tr("ROLL_BUD_LEFT")
			meter.right_text = ""
			meter.show_zone = false
			meter.fill_color = Color(0.45, 0.8, 0.35)
			meter.value = 1.0
			meter.visible = true
			done_button = add_action(tr("MG_DONE"), _finish_spread)
			done_button.disabled = true
		3:
			_roll_progress = 0.0
			_t_good = 0.0
			_t_tight = 0.0
			_t_loose = 0.0
			_speed = 0.0
			look_from(Vector3(0, 0.12, 0.13), Vector3(0, 0.004, 0))
			pressure_meter.show_zone = help_level >= 1
			pressure_meter.value = 0.0
			pressure_meter.visible = true
			meter.left_text = tr("ROLL_PROGRESS")
			meter.right_text = ""
			meter.show_zone = false
			meter.fill_color = Color(0.95, 0.9, 0.75)
			meter.value = 0.0
			meter.visible = true
			if help_level >= 2:
				_show_guide("↕", Vector2(0.5, 0.55))
		4:
			_wet.clear()
			for k: int in range(LICK_SEGS):
				_wet.append(false)
			_slobber = 0.0
			look_from(Vector3(0, 0.09, 0.09), Vector3(0, 0.005, 0))
			seam.visible = true
			_pulse_seam()
			meter.left_text = tr("ROLL_GLUE")
			meter.right_text = ""
			meter.show_zone = false
			meter.fill_color = Color(0.5, 0.8, 1.0)
			meter.value = 0.0
			meter.visible = true
			done_button = add_action(tr("MG_DONE"), _finish_lick)
			done_button.disabled = true
			if help_level >= 2:
				_show_guide("⟷", Vector2(0.5, 0.62))
		5:
			_twist_angle = 0.0
			_twist_has_last = false
			_tip_broken = false
			var tip_pos: Vector3 = tip.global_position
			look_from(tip_pos + Vector3(0.05, 0.07, 0.07), tip_pos)
			tip.visible = true
			tip.scale = Vector3(0.1, 0.1, 0.1)
			var tw: Tween = create_tween()
			tw.tween_property(tip, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			meter.left_text = tr("ROLL_TWIST_LESS")
			meter.right_text = tr("ROLL_TWIST_MORE")
			meter.zone_min = 0.33
			meter.zone_max = 0.66
			meter.show_zone = help_level >= 1
			meter.fill_color = Color(1.0, 0.8, 0.35)
			meter.value = 0.0
			meter.visible = true
			done_button = add_action(tr("MG_DONE"), _finish_twist)
			done_button.disabled = true


func _complete_step(score: int, outcome: StringName) -> void:
	if _locked:
		return
	_locked = true
	scores[step] = clampi(score, 0, 100)
	outcomes[step] = outcome
	var txt: String
	var col: Color
	if score >= 85:
		txt = tr("MG_RATE_PERFECT")
		col = C_GOOD
		sfx(&"notify_good")
	elif score >= 60:
		txt = tr("MG_RATE_GOOD")
		col = Color(0.75, 0.95, 0.45)
	elif score >= 35:
		txt = tr("MG_RATE_MEH")
		col = C_WARN
	else:
		txt = tr("MG_RATE_BAD")
		col = C_BAD
		sfx(&"notify_bad")
		shake(0.6)
	pop_text("%s  %d" % [txt, scores[step]], Vector2(-1, -1), col, 64)
	clear_actions()
	guide.visible = false
	var tw: Tween = create_tween()
	tw.tween_interval(1.0)
	if step < 5:
		tw.tween_callback(_enter_step.bind(step + 1))
	else:
		tw.tween_callback(_show_final)


func debug_skip_step() -> void:
	if _locked or step < 0:
		return
	match step:
		0:
			_grind_angle = TAU * 5.0
			_finish_grind()
		1:
			_fold = 3
			_after_folds()
			_complete_step(randi_range(40, 100), &"ok")
		2:
			for k: int in range(BINS):
				_bins[k] = SPREAD_BUDGET / float(BINS) * randf_range(0.7, 1.3)
			_budget = 0.0
			_finish_spread()
		3:
			_roll_progress = 1.0
			_t_good = 1.0
			_finish_roll()
		4:
			for k: int in range(LICK_SEGS):
				_wet[k] = true
			_finish_lick()
		5:
			_twist_angle = TAU * 2.0
			_finish_twist()


# ================================================================ Giriş

func _on_press(pos: Vector2) -> void:
	if _locked:
		return
	_press_pos = pos
	_grind_has_last = false
	_twist_has_last = false
	_stroke_len = 0.0
	_stroke_sign = 0


func _on_drag(pos: Vector2, rel: Vector2) -> void:
	if _locked:
		return
	match step:
		0: _drag_grind(pos)
		2: _drag_spread(pos, rel)
		3: _drag_roll(rel)
		4: _drag_lick(pos, rel)
		5: _drag_twist(pos)


func _on_release(pos: Vector2) -> void:
	if _locked:
		return
	if step == 1:
		_release_fold(pos)


func _process(delta: float) -> void:
	super._process(delta)
	if step == 3 and not _locked:
		_process_roll(delta)


# ================================================================ 1. Öğüt

func _drag_grind(pos: Vector2) -> void:
	var c: Vector2 = world_to_screen(GRINDER_POS + Vector3(0, 0.037, 0))
	var v: Vector2 = pos - c
	if v.length() < 18.0:
		return
	var a: float = v.angle()
	if _grind_has_last:
		var d: float = wrapf(a - _grind_last, -PI, PI)
		var before: int = int(_grind_angle / TAU)
		_grind_angle += absf(d)
		grinder_lid.rotate_y(-d)
		var after: int = int(_grind_angle / TAU)
		if after > before:
			sfx(&"grinder")
			squash(grinder_lid, 0.12)
			shake(0.15)
			burst(GRINDER_POS + Vector3(0, 0.045, 0), Color(0.35, 0.55, 0.22), 10, 0.0016, 0.18)
			if after == 3 and help_level >= 1:
				pop_text(tr("ROLL_POP_GRIND_OK"), c + Vector2(0, -160), C_GOOD)
			elif after == 9:
				pop_text(tr("ROLL_POP_DUST"), c + Vector2(0, -160), C_BAD)
	_grind_last = a
	_grind_has_last = true
	var turns: float = _grind_angle / TAU
	meter.value = turns / 10.0
	if done_button != null:
		done_button.disabled = turns < 1.0


func _finish_grind() -> void:
	var turns: float = _grind_angle / TAU
	var sc: float
	if turns < 4.0:
		_grain = &"coarse"
		sc = 100.0 - (4.0 - turns) * 24.0
	elif turns > 7.0:
		_grain = &"powder"
		sc = 100.0 - (turns - 7.0) * 18.0
	else:
		_grain = &"good"
		sc = 100.0
	_complete_step(int(sc), _grain)


# ================================================================ 2. Filtre

func _update_fold_guide() -> void:
	if help_level < 2 or _fold >= 3:
		guide.visible = false
		return
	var dirs: Array[String] = ["→", "←", "→"]
	_show_guide(dirs[_fold] + " " + dirs[_fold] + " " + dirs[_fold], Vector2(0.5, 0.62))


func _release_fold(pos: Vector2) -> void:
	if _fold >= 3:
		return
	var d: Vector2 = pos - _press_pos
	var want: float = 1.0 if _fold % 2 == 0 else -1.0
	if absf(d.x) < 60.0:
		return
	var sc: float = 0.0
	if signf(d.x) == want:
		var straight: float = clampf(1.0 - absf(d.y) / maxf(absf(d.x), 1.0), 0.0, 1.0)
		var length_ok: float = clampf(absf(d.x) / 220.0, 0.0, 1.0)
		sc = 100.0 * straight * (0.5 + 0.5 * length_ok)
	else:
		pop_text(tr("ROLL_POP_WRONG_WAY"), pos, C_BAD)
		shake(0.4)
		sc = 15.0
	_fold_scores.append(sc)
	var r: MeshInstance3D = card_ridges[_fold]
	r.visible = true
	r.scale = Vector3(1, 0.1, 1)
	var tw: Tween = create_tween()
	tw.tween_property(r, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "scale:x", 1.0 - 0.2 * float(_fold + 1), 0.25)
	sfx(&"paper_rustle")
	squash(card, 0.2)
	_fold += 1
	_update_fold_guide()
	if _fold >= 3:
		var total: float = 0.0
		for s: float in _fold_scores:
			total += s
		_after_folds()
		_complete_step(int(total / 3.0), &"ok" if total / 3.0 >= 50.0 else &"clogged")


## Katlanan karton filtre ucuna dönüşüp kağıdın soluna uçar.
func _after_folds() -> void:
	filter_tip = Node3D.new()
	filter_tip.name = "FilterTip"
	world.add_child(filter_tip)
	var fm: Node3D = try_model(M_FILTER)
	if fm != null:
		filter_tip.add_child(fm)
		_fit_long_axis_x(fm, FILTER_LEN)
	else:
		var c: MeshInstance3D = prim(cyl(ROLL_R * 0.9, ROLL_R * 0.9, FILTER_LEN, 16), Color(0.86, 0.78, 0.6), filter_tip, Vector3.ZERO, "Filter")
		c.rotation_degrees = Vector3(0, 0, 90)
	filter_tip.global_position = card.global_position + Vector3(0, ROLL_R, 0)
	var dest: Vector3 = Vector3(-PAPER_L * 0.5 + FILTER_LEN * 0.5, ROLL_R, PAPER_W * 0.5 - ROLL_R - 0.002)
	var tw: Tween = create_tween()
	tw.tween_property(card, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_property(filter_tip, "global_position", dest + Vector3(0, 0.04, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(filter_tip, "global_position", dest, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: card.visible = false)


# ================================================================ 3. Dağıt

func _drag_spread(pos: Vector2, rel: Vector2) -> void:
	if _budget <= 0.0:
		return
	var hit: Vector3 = screen_to_plane(pos, 0.002)
	var amount: float = minf(rel.length() * 0.07, _budget)
	if amount <= 0.0:
		return
	_budget -= amount
	var x0: float = -PAPER_L * 0.5 + FILTER_LEN
	var x1: float = PAPER_L * 0.5
	var on_paper: bool = hit.x >= x0 and hit.x <= x1 and absf(hit.z) <= PAPER_W * 0.38
	if on_paper:
		var idx: int = clampi(int((hit.x - x0) / (x1 - x0) * float(BINS)), 0, BINS - 1)
		_bins[idx] += amount
	else:
		_spilled += amount
	_crumb_accum += amount
	while _crumb_accum >= 0.25:
		_crumb_accum -= 0.25
		_add_crumb(hit if on_paper else hit + Vector3(0, -0.001, 0))
	if randf() < 0.05:
		sfx(&"paper_rustle")
	heat.set_bins(_bins, SPREAD_BUDGET / float(BINS))
	meter.value = _budget / SPREAD_BUDGET
	if done_button != null:
		done_button.disabled = _budget > SPREAD_BUDGET * 0.5
	if _budget <= 0.01:
		_locked_finish(_finish_spread)


func _add_crumb(at: Vector3) -> void:
	var mm: MultiMesh = crumbs.multimesh
	var i: int = mm.visible_instance_count
	if i >= mm.instance_count:
		return
	var size: float = 1.0
	match _grain:
		&"coarse": size = 1.9
		&"powder": size = 0.55
	size *= randf_range(0.6, 1.3)
	var jitter: Vector3 = Vector3(randf_range(-0.004, 0.004), 0.001, randf_range(-0.004, 0.004))
	var b: Basis = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, 0)).scaled(Vector3(size, size * 0.8, size))
	mm.set_instance_transform(i, Transform3D(b, at + jitter))
	mm.set_instance_color(i, Color(0.3, 0.5, 0.2).lerp(Color(0.55, 0.62, 0.25), randf()))
	mm.visible_instance_count = i + 1


func _locked_finish(cb: Callable) -> void:
	if _locked:
		return
	_locked = true
	var tw: Tween = create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		_locked = false
		cb.call())


func _finish_spread() -> void:
	var sum: float = 0.0
	for v: float in _bins:
		sum += v
	var mean: float = sum / float(BINS)
	var variance: float = 0.0
	for v: float in _bins:
		variance += (v - mean) * (v - mean)
	var cv: float = sqrt(variance / float(BINS)) / maxf(mean, 0.001)
	var even: float = clampf(1.0 - cv, 0.0, 1.0)
	var coverage: float = clampf(sum / SPREAD_BUDGET * 1.1, 0.0, 1.0)
	var sc: float = 100.0 * even * coverage - _spilled * 0.6
	if _spilled > 15.0:
		pop_text(tr("ROLL_POP_SPILL"), Vector2(-1, 300), C_WARN)
	_complete_step(int(sc), &"uneven" if even < 0.5 else &"ok")


# ================================================================ 4. Sar

func _drag_roll(rel: Vector2) -> void:
	_frame_dy += absf(rel.y)
	var sgn: int = int(signf(rel.y))
	if sgn == 0:
		return
	if _stroke_sign != 0 and sgn != _stroke_sign:
		if _stroke_len > 30.0:
			_roll_progress += clampf(_stroke_len / 260.0, 0.2, 1.0) * 0.085
			sfx(&"paper_rustle")
			squash(core if core.visible else paper_mi, 0.08)
		_stroke_len = 0.0
	_stroke_sign = sgn
	_stroke_len += absf(rel.y)


func _process_roll(delta: float) -> void:
	var inst_speed: float = _frame_dy / maxf(delta, 0.001)
	_frame_dy = 0.0
	if not is_pressing():
		inst_speed = 0.0
	_speed = lerpf(_speed, inst_speed, 1.0 - exp(-6.0 * delta))
	var pressure: float = clampf(_speed / 2400.0, 0.0, 1.0)
	pressure_meter.value = pressure
	if is_pressing() and _speed > 60.0:
		if pressure < 0.35:
			_t_loose += delta
		elif pressure > 0.65:
			_t_tight += delta
			if randf() < delta * 1.5:
				shake(0.25)
		else:
			_t_good += delta
	_roll_progress = clampf(_roll_progress, 0.0, 1.0)
	meter.value = _roll_progress
	_apply_curl(_roll_progress)
	if _roll_progress >= 1.0:
		_finish_roll()


func _apply_curl(p: float) -> void:
	var c: float = p * 0.97
	paper_mat.set_shader_parameter(&"curl", c)
	crumbs.visible = p < 0.12
	core.visible = p >= 0.05
	if core.visible:
		# Sarım silindirinin paper-yerel konumu → dünya
		var rolled: float = c * paper_half * 2.0
		var a: float = paper_center + paper_half - rolled
		var r_local: float = ROLL_R / maxf(paper_mi.transform.basis.get_scale().x, 0.0001)
		var local: Vector3 = Vector3(a, paper_base_y + r_local, 0.0) if paper_across_x else Vector3(0.0, paper_base_y + r_local, a)
		var g: Vector3 = paper_mi.global_transform * local
		core.global_position = Vector3(FILTER_LEN * 0.5, g.y, g.z)


func _finish_roll() -> void:
	if _locked:
		return
	var total: float = maxf(_t_good + _t_tight + _t_loose, 0.001)
	var sc: float = 100.0 * _t_good / total
	var outcome: StringName = &"ok"
	if _t_tight > _t_good and _t_tight >= _t_loose:
		outcome = &"tight"
	elif _t_loose > _t_good:
		outcome = &"loose"
	_build_joint()
	_complete_step(int(sc), outcome)


## Kağıt + öz yerine bitmiş joint (ya da yedek silindir) gelir.
func _build_joint() -> void:
	var center_z: float = core.global_position.z if core.visible else 0.0
	joint_root = Node3D.new()
	joint_root.name = "Joint"
	world.add_child(joint_root)
	joint_root.global_position = Vector3(0, ROLL_R, center_z)
	var jm: Node3D = try_model(M_JOINT)
	if jm != null:
		joint_root.add_child(jm)
		_fit_long_axis_x(jm, PAPER_L)
	else:
		var body: MeshInstance3D = prim(cyl(ROLL_R * 1.05, ROLL_R * 0.92, PAPER_L - FILTER_LEN, 20), Color(0.97, 0.94, 0.88), joint_root, Vector3(FILTER_LEN * 0.5, 0, 0), "Body")
		body.rotation_degrees = Vector3(0, 0, 90)
		var f: MeshInstance3D = prim(cyl(ROLL_R * 0.92, ROLL_R * 0.92, FILTER_LEN, 16), Color(0.86, 0.78, 0.6), joint_root, Vector3(-PAPER_L * 0.5 + FILTER_LEN * 0.5, 0, 0), "FilterEnd")
		f.rotation_degrees = Vector3(0, 0, 90)
	paper_mi.visible = false
	core.visible = false
	crumbs.visible = false
	if filter_tip != null:
		filter_tip.visible = false
	# Yapıştırma çizgisi (dikiş) + ıslak izler
	var seam_pos: Vector3 = Vector3(0, ROLL_R * 1.6, ROLL_R * 0.75)
	seam = prim(box(Vector3(PAPER_L * 0.92, 0.0006, 0.0012)), Color(0.4, 0.75, 1.0, 0.85), joint_root, seam_pos, "Seam")
	seam.visible = false
	var seg_len: float = PAPER_L * 0.92 / float(LICK_SEGS)
	for k: int in range(LICK_SEGS):
		var w: MeshInstance3D = prim(box(Vector3(seg_len, 0.0008, 0.0022)), Color(0.75, 0.9, 1.0, 0.7), joint_root, seam_pos + Vector3(-PAPER_L * 0.46 + seg_len * (float(k) + 0.5), 0.0003, 0), "Wet%d" % k)
		var wm: StandardMaterial3D = mat(Color(0.75, 0.9, 1.0, 0.7), 0.05, 0.2)
		w.material_override = wm
		w.visible = false
		wet_marks.append(w)
	# Bükülecek uç (filtrenin karşı ucu)
	tip = Node3D.new()
	tip.name = "Tip"
	joint_root.add_child(tip)
	tip.position = Vector3(PAPER_L * 0.5 + 0.004, 0, 0)
	var cone: MeshInstance3D = prim(cyl(0.0006, ROLL_R, 0.012, 12), Color(0.97, 0.94, 0.88), tip, Vector3.ZERO, "TwistCone")
	cone.rotation_degrees = Vector3(0, 0, -90)
	prim(box(Vector3(0.008, 0.0012, 0.0006)), Color(0.85, 0.8, 0.7), tip, Vector3(0.002, ROLL_R * 0.6, 0), "Fold")
	tip.visible = false
	joint_root.scale = Vector3(0.8, 0.8, 0.8)
	var tw: Tween = create_tween()
	tw.tween_property(joint_root, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	burst(joint_root.global_position + Vector3(0, 0.01, 0), Color(1, 1, 0.8), 14, 0.0015, 0.15)


## Bir modeli en uzun ekseni dünya X'ine gelecek ve verilen uzunlukta olacak şekilde yerleştirir.
func _fit_long_axis_x(model: Node3D, length: float) -> void:
	model.transform = Transform3D.IDENTITY
	var parent: Node3D = model.get_parent() as Node3D
	var inv: Transform3D = parent.global_transform.affine_inverse()
	var a: AABB = inv * combined_aabb(model)
	var s: Vector3 = a.size
	var basis: Basis = Basis.IDENTITY
	var longest: float = s.x
	if s.y > longest and s.y >= s.z:
		basis = Basis(Vector3(0, 0, 1), -PI * 0.5)
		longest = s.y
	elif s.z > longest:
		basis = Basis(Vector3.UP, PI * 0.5)
		longest = s.z
	var k: float = length / maxf(longest, 0.0001)
	basis = basis.scaled(Vector3(k, k, k))
	var c: Vector3 = basis * a.get_center()
	model.transform = Transform3D(basis, -c)


# ================================================================ 5. Yapıştır

func _pulse_seam() -> void:
	if seam == null or help_level < 1:
		return
	var m: StandardMaterial3D = seam.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(0.4, 0.75, 1.0)
	var tw: Tween = create_tween().set_loops(6)
	tw.tween_property(m, "emission_energy_multiplier", 2.0, 0.4)
	tw.tween_property(m, "emission_energy_multiplier", 0.2, 0.4)


func _drag_lick(pos: Vector2, rel: Vector2) -> void:
	var top_y: float = joint_root.global_position.y + ROLL_R * 1.6
	var hit: Vector3 = screen_to_plane(pos, top_y)
	var local: Vector3 = joint_root.global_transform.affine_inverse() * hit
	var seam_z: float = ROLL_R * 0.75
	var half_len: float = PAPER_L * 0.46
	if absf(local.z - seam_z) <= 0.009 and absf(local.x) <= half_len:
		var k: int = clampi(int((local.x + half_len) / (half_len * 2.0) * float(LICK_SEGS)), 0, LICK_SEGS - 1)
		if not _wet[k]:
			_wet[k] = true
			var w: MeshInstance3D = wet_marks[k]
			w.visible = true
			w.scale = Vector3(0.2, 1, 0.2)
			var tw: Tween = create_tween()
			tw.tween_property(w, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var n: int = _wet_count()
			if n % 4 == 1:
				sfx(&"lick")
				pop_text(tr("ROLL_POP_LICK"), pos + Vector2(0, -80), Color(0.6, 0.85, 1.0), 40)
			meter.value = float(n) / float(LICK_SEGS)
			if done_button != null:
				done_button.disabled = false
			if n >= LICK_SEGS:
				_locked_finish(_finish_lick)
	else:
		_slobber += rel.length() * 0.02


func _wet_count() -> int:
	var n: int = 0
	for b: bool in _wet:
		if b:
			n += 1
	return n


func _finish_lick() -> void:
	var coverage: float = float(_wet_count()) / float(LICK_SEGS)
	var sc: float = coverage * 100.0 - minf(_slobber, 25.0)
	if _slobber > 20.0:
		pop_text(tr("ROLL_POP_SOAKED"), Vector2(-1, 300), C_WARN)
	if seam != null:
		seam.visible = false
	_complete_step(int(sc), &"open" if coverage < 0.6 else &"ok")


# ================================================================ 6. Bük

func _drag_twist(pos: Vector2) -> void:
	if _tip_broken:
		return
	var c: Vector2 = world_to_screen(tip.global_position)
	var v: Vector2 = pos - c
	if v.length() < 14.0:
		return
	var a: float = v.angle()
	if _twist_has_last:
		var d: float = wrapf(a - _twist_last, -PI, PI)
		var before: int = int(_twist_angle / PI)
		_twist_angle += absf(d)
		tip.rotate_object_local(Vector3.RIGHT, d)
		var turns: float = _twist_angle / TAU
		tip.scale = Vector3(1.0 + turns * 0.12, 1.0 - minf(turns * 0.08, 0.4), 1.0 - minf(turns * 0.08, 0.4))
		if int(_twist_angle / PI) > before:
			sfx(&"paper_rustle")
		meter.value = turns / 4.5
		if done_button != null:
			done_button.disabled = turns < 0.5
		if turns >= 4.5:
			_break_tip()
	_twist_last = a
	_twist_has_last = true


func _break_tip() -> void:
	_tip_broken = true
	shake(1.0)
	pop_text(tr("ROLL_POP_SNAP"), Vector2(-1, -1), C_BAD, 70)
	sfx(&"notify_bad")
	var tw: Tween = create_tween()
	tw.tween_property(tip, "position", tip.position + Vector3(0.08, 0.06, 0.02), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(tip, "rotation", Vector3(6.0, 3.0, 2.0), 0.5)
	tw.tween_property(tip, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
	tw.tween_callback(_finish_twist)


func _finish_twist() -> void:
	var turns: float = _twist_angle / TAU
	var sc: float
	var outcome: StringName = &"ok"
	if _tip_broken:
		sc = 10.0
		outcome = &"snapped"
	elif turns < 1.5:
		sc = 100.0 - (1.5 - turns) * 50.0
		outcome = &"untwisted"
	elif turns > 3.0:
		sc = 100.0 - (turns - 3.0) * 40.0
	else:
		sc = 100.0
	_complete_step(int(sc), outcome)


# ================================================================ Sonuç

func _show_guide(text: String, anchor: Vector2) -> void:
	guide.text = text
	guide.visible = true
	guide.reset_size()
	guide.position = get_viewport_rect().size * anchor - guide.size * 0.5
	guide.modulate.a = 1.0
	var tw: Tween = create_tween().set_loops(4)
	tw.tween_property(guide, "modulate:a", 0.25, 0.5)
	tw.tween_property(guide, "modulate:a", 1.0, 0.5)


func compute_total() -> int:
	var t: float = 0.0
	for i: int in range(6):
		t += float(scores[i]) * WEIGHTS[i]
	return clampi(int(round(t)) + MinigameUtil.rolling_bonus(), 0, 100)


## Skora ve en kötü adıma göre komik isim.
func name_for(score: int) -> String:
	if score >= 90:
		return tr("ROLL_NAME_MASTER")
	if score >= 75:
		return tr("ROLL_NAME_CLASSIC")
	if score >= 55:
		return tr("ROLL_NAME_OK")
	var worst: int = 0
	for i: int in range(6):
		if scores[i] < scores[worst]:
			worst = i
	var o: StringName = outcomes[worst]
	match o:
		&"coarse": return tr("ROLL_NAME_PEBBLE")
		&"powder": return tr("ROLL_NAME_DUST")
		&"clogged": return tr("ROLL_NAME_CHIMNEY")
		&"uneven": return tr("ROLL_NAME_CARROT")
		&"loose": return tr("ROLL_NAME_MUHTAR")
		&"tight": return tr("ROLL_NAME_MATCH")
		&"open": return tr("ROLL_NAME_UMBRELLA")
		&"snapped": return tr("ROLL_NAME_COMET")
	return tr("ROLL_NAME_MUHTAR") if score >= 35 else tr("ROLL_NAME_MATCH")


func _base_quality() -> int:
	if context.has("quality"):
		return int(context["quality"])
	var bud: Dictionary = MinigameUtil.best_dry_bud(MinigameUtil.BUD_PER_JOINT)
	return int(bud.get("quality", 60)) if not bud.is_empty() else 60


func _show_final() -> void:
	final_score = compute_total()
	roll_name = name_for(final_score)
	look_from(Vector3(0, 0.1, 0.12), joint_root.global_position if joint_root != null else Vector3.ZERO, 0.8)
	if joint_root != null:
		var tw: Tween = create_tween().set_loops(3)
		tw.tween_property(joint_root, "rotation:x", TAU, 1.2).from(0.0)
	step_label.text = tr("ROLL_RESULT")
	var q: int = int(round(float(_base_quality()) * float(final_score) / 100.0))
	var lines: Array[String] = [
		"“%s”" % roll_name,
		MinigameUtil.fmt(tr("ROLL_RESULT_QUALITY"), q),
	]
	var bonus: int = MinigameUtil.rolling_bonus()
	if bonus > 0:
		lines.append(MinigameUtil.fmt(tr("ROLL_RESULT_CALM_HAND"), bonus))
	var buttons: Array = [[tr("ROLL_KEEP"), _keep.bind(q)]]
	if MinigameUtil.consumption_enabled():
		buttons.append([tr("ROLL_SMOKE_NOW"), _smoke_now.bind(q), Color(0.75, 0.45, 0.2)])
	show_result(tr("ROLL_RESULT_TITLE"), final_score, lines, buttons)


func _consume_materials() -> bool:
	if not MinigameUtil.has_inventory():
		return true
	var bud_id: StringName = StringName(str(context.get("bud_id", "")))
	if bud_id == &"":
		var bud: Dictionary = MinigameUtil.best_dry_bud(MinigameUtil.BUD_PER_JOINT)
		bud_id = StringName(str(bud.get("id", "")))
	if bud_id == &"" or MinigameUtil.count_of(&"paper") < 1:
		MinigameUtil.notify(tr("ROLL_NO_MATERIALS"), &"bad")
		return false
	if not MinigameUtil.consume(&"paper", 1):
		MinigameUtil.notify(tr("ROLL_NO_MATERIALS"), &"bad")
		return false
	if not MinigameUtil.consume_bud(bud_id, MinigameUtil.BUD_PER_JOINT):
		MinigameUtil.notify(tr("ROLL_NO_MATERIALS"), &"bad")
		return false
	if MinigameUtil.count_of(&"filter") > 0:
		MinigameUtil.consume(&"filter", 1)
	return true


func _strain() -> StringName:
	if context.has("strain"):
		return StringName(str(context["strain"]))
	var bud: Dictionary = MinigameUtil.best_dry_bud(MinigameUtil.BUD_PER_JOINT)
	return StringName(str(bud.get("strain", "dede")))


func _keep(q: int) -> void:
	var strain: StringName = _strain()
	if not _consume_materials():
		finish({"cancelled": true, "score": final_score})
		return
	var item: Dictionary = MinigameUtil.add_preroll(strain, q, roll_name, final_score)
	_register()
	MinigameUtil.notify(MinigameUtil.fmt(tr("ROLL_ADDED"), roll_name), &"good")
	finish({"score": final_score, "quality": q, "roll_name": roll_name, "item": item, "smoked": false, "step_scores": scores.duplicate()})


func _smoke_now(q: int) -> void:
	if not _consume_materials():
		finish({"cancelled": true, "score": final_score})
		return
	_register()
	sfx(&"inhale")
	MinigameUtil.start_gafti(0.35, 60)
	MinigameUtil.notify(tr("ROLL_SMOKED"), &"info")
	finish({"score": final_score, "quality": q, "roll_name": roll_name, "item": {}, "smoked": true, "step_scores": scores.duplicate()})


func _register() -> void:
	var fx: Node = MinigameUtil.effects()
	if fx != null and fx.has_method(&"register_roll"):
		fx.call(&"register_roll")
	var qm: Node = MinigameUtil.autoload("QuestManager")
	if qm != null and qm.has_method(&"notify_event"):
		qm.call(&"notify_event", &"joint_rolled", {"score": final_score})
