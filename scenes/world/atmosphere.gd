extends Node3D
## Pusludere atmosferi: gün/gece ışığı, gökyüzü, sis, mevsim tonu ve hava efektleri.
## GameClock ve Weather autoload'larını dinler. Valley sahnesinin çocuğu olarak çalışır.

@export var follow_target_group: StringName = &"player"

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var world_env: WorldEnvironment
var env: Environment
var sky_mat: ProceduralSkyMaterial
var rain: GPUParticles3D
var snow: GPUParticles3D
var lightning_timer: float = 0.0
var _weather: StringName = &"sunny"
var _fog_target: float = 0.004
var _cloud_target: float = 0.0
var _rain_amount: float = 0.0
var _snow_amount: float = 0.0

# Gün içi renk anahtarları: (gün oranı, güneş rengi, güneş gücü, gökyüzü üst, ufuk)
const KEYS: Array = [
	[0.00, Color(0.35, 0.42, 0.70), 0.00, Color(0.03, 0.05, 0.12), Color(0.08, 0.10, 0.18)],
	[0.22, Color(0.95, 0.55, 0.35), 0.25, Color(0.25, 0.30, 0.50), Color(0.95, 0.60, 0.45)],
	[0.30, Color(1.00, 0.85, 0.70), 0.90, Color(0.35, 0.55, 0.80), Color(0.80, 0.85, 0.85)],
	[0.50, Color(1.00, 0.97, 0.90), 1.20, Color(0.30, 0.55, 0.85), Color(0.75, 0.85, 0.90)],
	[0.72, Color(1.00, 0.70, 0.45), 0.80, Color(0.35, 0.45, 0.75), Color(0.95, 0.70, 0.50)],
	[0.80, Color(0.90, 0.40, 0.30), 0.20, Color(0.15, 0.15, 0.35), Color(0.75, 0.40, 0.35)],
	[0.88, Color(0.35, 0.42, 0.70), 0.00, Color(0.03, 0.05, 0.12), Color(0.08, 0.10, 0.18)],
	[1.00, Color(0.35, 0.42, 0.70), 0.00, Color(0.03, 0.05, 0.12), Color(0.08, 0.10, 0.18)],
]


func _ready() -> void:
	_build_environment()
	_build_lights()
	rain = _make_precip(Color(0.75, 0.82, 0.95, 0.55), Vector3(0.02, 0.5, 0.02), 900, 14.0)
	snow = _make_precip(Color(1, 1, 1, 0.9), Vector3(0.07, 0.07, 0.07), 500, 2.0)
	if has_node("/root/Weather"):
		var w: Node = get_node("/root/Weather")
		if w.has_signal("weather_changed"):
			w.weather_changed.connect(_on_weather_changed)
		_on_weather_changed(w.get("current") if w.get("current") != null else &"sunny")
	if has_node("/root/Settings"):
		get_node("/root/Settings").changed.connect(_apply_quality)
	_apply_quality()


func _build_environment() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.12, 0.16, 0.12)
	sky_mat.ground_horizon_color = Color(0.55, 0.62, 0.60)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.70, 0.76, 0.78)
	env.fog_density = 0.004
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.6
	env.fog_height = 6.0
	env.fog_height_density = 0.08
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	world_env.environment = env
	add_child(world_env)


func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.18
	moon.shadow_enabled = false
	add_child(moon)


func _make_precip(color: Color, size: Vector3, amount: int, speed: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.5
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(25, 1, 25)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 4.0
	pm.initial_velocity_min = speed
	pm.initial_velocity_max = speed * 1.3
	pm.gravity = Vector3(0, -2, 0)
	if speed < 5.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.5
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.position.y = 18.0
	add_child(p)
	return p


func _on_weather_changed(weather: StringName) -> void:
	_weather = weather
	match weather:
		&"sunny":
			_fog_target = 0.0025; _cloud_target = 0.0; _rain_amount = 0.0; _snow_amount = 0.0
		&"cloudy":
			_fog_target = 0.005; _cloud_target = 0.5; _rain_amount = 0.0; _snow_amount = 0.0
		&"foggy":
			_fog_target = 0.035; _cloud_target = 0.6; _rain_amount = 0.0; _snow_amount = 0.0
		&"rainy":
			_fog_target = 0.012; _cloud_target = 0.8; _rain_amount = 0.7; _snow_amount = 0.0
		&"storm":
			_fog_target = 0.016; _cloud_target = 1.0; _rain_amount = 1.0; _snow_amount = 0.0
		&"snow":
			_fog_target = 0.014; _cloud_target = 0.7; _rain_amount = 0.0; _snow_amount = 1.0
		_:
			_fog_target = 0.004; _cloud_target = 0.2; _rain_amount = 0.0; _snow_amount = 0.0
	rain.emitting = _rain_amount > 0.0
	rain.amount_ratio = maxf(_rain_amount, 0.01)
	snow.emitting = _snow_amount > 0.0


func _apply_quality() -> void:
	var q: int = 1
	if has_node("/root/Settings"):
		q = int(get_node("/root/Settings").get("graphics_quality"))
	sun.shadow_enabled = q >= 1
	env.glow_enabled = q >= 1
	env.ssao_enabled = q >= 2
	sun.directional_shadow_max_distance = 50.0 if q == 1 else 90.0
	rain.amount_ratio = maxf(_rain_amount, 0.01) * (0.5 if q == 0 else 1.0)


func _process(delta: float) -> void:
	var t: float = 0.35
	var season: StringName = &"spring"
	if has_node("/root/GameClock"):
		var gc: Node = get_node("/root/GameClock")
		if gc.has_method("get_day_fraction"):
			t = gc.get_day_fraction()
		var s: Variant = gc.get("season")
		if s != null:
			season = s
	_apply_time(t, season)
	# Sis ve bulut yumuşak geçiş
	env.fog_density = lerpf(env.fog_density, _fog_target, delta * 0.5)
	# Yağış oyuncuyu takip eder
	var target: Node3D = get_tree().get_first_node_in_group(follow_target_group) as Node3D
	if target != null:
		rain.global_position = target.global_position + Vector3(0, 18, 0)
		snow.global_position = target.global_position + Vector3(0, 14, 0)
	# Fırtınada şimşek
	if _weather == &"storm":
		lightning_timer -= delta
		if lightning_timer <= 0.0:
			lightning_timer = randf_range(6.0, 16.0)
			_flash()


func _apply_time(t: float, season: StringName) -> void:
	var a: Array = KEYS[0]
	var b: Array = KEYS[KEYS.size() - 1]
	for i: int in KEYS.size() - 1:
		if t >= float(KEYS[i][0]) and t <= float(KEYS[i + 1][0]):
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var span: float = maxf(float(b[0]) - float(a[0]), 0.0001)
	var k: float = clampf((t - float(a[0])) / span, 0.0, 1.0)
	var cloud: float = _cloud_target
	var sun_col: Color = (a[1] as Color).lerp(b[1], k)
	var sun_e: float = lerpf(float(a[2]), float(b[2]), k) * (1.0 - cloud * 0.6)
	var top: Color = (a[3] as Color).lerp(b[3], k)
	var hor: Color = (a[4] as Color).lerp(b[4], k)
	# Bulutlu havada gökyüzü griye kayar
	var grey: Color = Color(0.55, 0.58, 0.60) * maxf(sun_e, 0.15)
	top = top.lerp(grey, cloud * 0.7)
	hor = hor.lerp(grey * 1.1, cloud * 0.6)
	# Mevsim tonu
	match season:
		&"autumn":
			hor = hor.lerp(Color(0.95, 0.70, 0.45), 0.12)
			env.adjustment_saturation = 1.0
		&"winter":
			top = top.lerp(Color(0.70, 0.75, 0.82), 0.25)
			env.adjustment_saturation = 0.85
		&"summer":
			env.adjustment_saturation = 1.15
		_:
			env.adjustment_saturation = 1.08
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor.darkened(0.2)
	sun.light_color = sun_col
	sun.light_energy = sun_e
	# Güneş yörüngesi: 06:00 doğar (0.25), 18:00 batar (0.75)
	var ang: float = (t - 0.25) / 0.5 * PI
	sun.rotation = Vector3(-sin(ang) * deg_to_rad(65.0) - deg_to_rad(5.0), deg_to_rad(-35.0), 0.0)
	sun.visible = sun_e > 0.01
	moon.visible = not sun.visible or sun_e < 0.2
	moon.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(140.0), 0.0)
	env.ambient_light_energy = clampf(0.25 + sun_e * 0.6, 0.25, 1.0)
	env.fog_light_color = hor.lerp(Color(0.7, 0.75, 0.78), 0.5)


func _flash() -> void:
	var tw: Tween = create_tween()
	var base: float = env.ambient_light_energy
	tw.tween_property(env, "ambient_light_energy", 3.0, 0.05)
	tw.tween_property(env, "ambient_light_energy", base, 0.25)
	if has_node("/root/AudioManager") and get_node("/root/AudioManager").has_method("play_sfx"):
		get_tree().create_timer(randf_range(0.4, 1.5)).timeout.connect(
			func() -> void: get_node("/root/AudioManager").play_sfx(&"thunder"))
