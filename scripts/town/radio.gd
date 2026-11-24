class_name KahvehaneRadio
extends Node3D
## Kahvehane radyosu: yarının hava tahmini (Weather.tomorrow) + %30 ihtimalle tersini söyleyen Fadime yorumu.

const MODEL: String = "res://assets/models/props/radio.glb"
const FADIME_FLIP_CHANCE: float = 0.3
## Tahminin "tersi".
const OPPOSITE: Dictionary = {
	&"sunny": &"rainy", &"cloudy": &"sunny", &"foggy": &"sunny", &"rainy": &"sunny", &"storm": &"sunny", &"snow": &"sunny",
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var m: Node3D = ModelLoader.instance(MODEL, Vector3(0.35, 0.22, 0.15), Color(0.55, 0.3, 0.18))
	add_child(m)
	InteractArea.attach(self, Vector3(1.4, 1.6, 1.4), Vector3(0, -0.6, 0))


func get_interact_text() -> String:
	return tr("RADIO_INTERACT")


func interact(_player: Node) -> void:
	var am: Node = get_node_or_null(^"/root/AudioManager")
	if am != null and am.has_method(&"play_sfx"):
		am.call(&"play_sfx", &"radio_static", global_position)
	QuestManager.register_runtime_dialogue(&"rt_radio", build_lines())
	QuestManager.request_dialogue(&"rt_radio")
	QuestManager.notify_event(&"radio_listened", {"tomorrow": Weather.tomorrow})


func build_lines() -> Array[Dictionary]:
	var tomorrow: StringName = Weather.tomorrow
	var w: String = String(tomorrow).to_upper()
	var lines: Array[Dictionary] = []
	lines.append({"speaker": &"radio", "text_key": "RADIO_INTRO_%d" % _rng.randi_range(1, 3)})
	lines.append({"speaker": &"radio", "text_key": "RADIO_FORECAST_" + w})
	var fx: Node = get_node_or_null(^"/root/Effects")
	if fx != null and bool(fx.get(&"gafti_active")):
		lines.append({"speaker": &"radio", "text_key": "RADIO_GAFTI_%d" % _rng.randi_range(1, 2)})
	if _rng.randf() < FADIME_FLIP_CHANCE:
		var opp: StringName = OPPOSITE.get(tomorrow, &"sunny") as StringName
		lines.append({"speaker": &"fadime", "text_key": "FADIME_RADIO_FLIP_" + String(opp).to_upper()})
	else:
		lines.append({"speaker": &"radio", "text_key": "RADIO_OUTRO_%d" % _rng.randi_range(1, 2)})
	return lines
