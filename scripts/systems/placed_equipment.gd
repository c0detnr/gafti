class_name PlacedEquipment
extends Node3D
## İnşa moduyla yerleştirilen basit ekipman (lamba, damla sulama, nemlendirici, ısıtıcı, jeneratör, raf).
## Saksılar "grow_equipment" grubundan effect/radius okuyarak etkilenir.

var buildable_id: StringName = &""
var effect: StringName = &""
var radius: float = 2.0
var power_cost_per_day: int = 0


## BuildableData'dan kurulur (add_child öncesi çağrılmalı).
func setup(data: BuildableData) -> void:
	buildable_id = data.id
	effect = data.effect
	radius = data.effect_radius
	power_cost_per_day = data.power_cost_per_day
	name = "Placed_" + String(data.id)
	if effect != &"" and effect != &"shelf" and effect != &"generator":
		add_to_group(&"grow_equipment")
	if power_cost_per_day > 0:
		add_to_group(&"power_consumer")
	match effect:
		&"generator":
			add_to_group(&"generator")
		&"heat":
			add_to_group(&"heater")
		&"shelf":
			add_to_group(&"shop_shelf")
	for g: StringName in data.extra_groups:
		add_to_group(g)
	var model: Node3D = ModelLoader.instance(data.model_path, data.size, data.color) if data.model_path != "" \
		else ModelLoader.placeholder(data.size, data.color, String(data.id))
	model.name = "Model"
	add_child(model)
	# Çarpışma (oyuncu + inşa modunda satış için ışın testi).
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Body"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = data.size
	shape.shape = box
	shape.position.y = data.size.y * 0.5
	body.add_child(shape)
	add_child(body)
	if effect == &"light":
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.75, 0.5)
		lamp.omni_range = radius
		lamp.light_energy = 0.8
		lamp.position.y = data.size.y
		lamp.name = "Lamp"
		add_child(lamp)


func _ready() -> void:
	if has_node(^"Lamp"):
		Weather.power_changed.connect(_on_power_changed)
		_on_power_changed(Weather.is_power_out())


func _on_power_changed(out: bool) -> void:
	var lamp: OmniLight3D = get_node_or_null(^"Lamp") as OmniLight3D
	if lamp != null:
		lamp.visible = not out
