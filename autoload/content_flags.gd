extends Node
## Platform ve içerik bayrakları. Play Store reddi durumunda consumption=false yapılır.

const DEMO_DAY_LIMIT: int = 7

var consumption: bool = true
var is_mobile: bool = false
var is_demo: bool = false


func _ready() -> void:
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	if OS.has_feature("demo"):
		is_demo = true
	if OS.has_feature("no_consumption"):
		consumption = false


func get_save_data() -> Dictionary:
	return {}


func load_save_data(_d: Dictionary) -> void:
	pass
