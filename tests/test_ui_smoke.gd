extends Node
## Headless duman testi (Ajan C): oyuncu, HUD, envanter, duraklatma, ayarlar, gün raporu,
## özelleştirme, yatak/ayna, mobil joystick ve ses yöneticisini kodla dener.
## Çalıştır: Godot --headless --path <proje> res://tests/test_ui_smoke.tscn --quit-after 900

var _scene: Node
var _step: int = 0
var _timer: float = 0.0


func _ready() -> void:
	_scene = (load("res://tests/test_player.tscn") as PackedScene).instantiate()
	add_child(_scene)


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.25:
		return
	_timer = 0.0
	_step += 1
	var player: Node = get_tree().get_first_node_in_group(&"player")
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	match _step:
		1:
			print("SMOKE: player=", player != null, " hud=", hud != null)
			EventBus.notify.emit("Merhaba", &"good")
			EventBus.notify.emit("Kötü haber", &"bad")
			Input.action_press(&"move_forward")
		3:
			Input.action_release(&"move_forward")
			print("SMOKE: moved to ", (player as Node3D).global_position)
			Input.action_press(&"sprint")
			Input.action_press(&"move_left")
		5:
			Input.action_release(&"sprint")
			Input.action_release(&"move_left")
			(player as Node3D).global_position = Vector3(0, 0.2, -2.5)
		7:
			player.call(&"try_interact")
			print("SMOKE: test interactable count=", get_node("TestPlayer/TestInteractable").get(&"count"))
		8:
			hud.call(&"open_inventory")
			Inventory.add_item({"id": &"seed_pusu", "kind": &"seed", "strain": &"pusu_kusu", "quality": 70, "grams": 0.0, "count": 3})
		10:
			_press(&"inventory")
		11:
			hud.call(&"open_pause_menu")
			print("SMOKE: paused=", get_tree().paused)
		12:
			var pause: Node = hud.get_child(hud.get_child_count() - 1)
			pause.call(&"_on_settings")
		14:
			_press(&"pause") # ayarları kapatır
		15:
			_press(&"pause") # duraklatmayı kapatır
			print("SMOKE: paused after close=", get_tree().paused)
		16:
			print("SMOKE: paused (sonraki kare)=", get_tree().paused)
			hud.call(&"show_day_report", {"day": 3, "income": 1500, "expenses": 320, "profit": 1180, "entries": [{"amount": 500, "reason": "Satış"}, {"amount": -120, "reason": "Elektrik"}], "bills_due": 90, "money": 3180})
		18:
			var dr: Node = get_tree().root.find_child("DayReport", true, false)
			if dr != null:
				dr.call(&"_on_ok")
		19:
			# Ayna: host yoksa yedek kaplama açılır.
			get_node("TestPlayer/MirrorStation").call(&"interact", player)
		21:
			var c: Node = get_tree().root.find_child("Customization", true, false)
			print("SMOKE: customization open=", c != null)
			if c != null:
				c.call(&"_randomize")
				c.call(&"_on_ok")
		23:
			print("SMOKE: player custom=", player.call(&"get_customization"))
			GameClock.hour = 21
			get_node("TestPlayer/BedStation").call(&"interact", player)
		30:
			var dr2: Node = get_tree().root.find_child("DayReport", true, false)
			print("SMOKE: bed report open=", dr2 != null, " day=", GameClock.day)
			if dr2 != null:
				dr2.call(&"_on_ok")
		31:
			# Mobil joystick simülasyonu
			Settings.touch_controls = true
			Settings.apply()
			var mc: Node = get_tree().root.find_child("MobileControls", true, false)
			mc.call(&"_touch_down", 0, Vector2(200, 900))
			mc.call(&"_touch_drag", 0, Vector2(200, 780), Vector2(0, -120))
			mc.call(&"_touch_down", 1, Vector2(1400, 500))
			mc.call(&"_touch_drag", 1, Vector2(1450, 520), Vector2(50, 20))
			print("SMOKE: joy forward strength=", Input.get_action_strength(&"move_forward"), " sprint=", Input.is_action_pressed(&"sprint"))
		33:
			var mc2: Node = get_tree().root.find_child("MobileControls", true, false)
			mc2.call(&"_touch_up", 0)
			mc2.call(&"_touch_up", 1)
			print("SMOKE: joy released=", Input.get_action_strength(&"move_forward"))
			AudioManager.play_sfx(&"ui_click")
			AudioManager.play_sfx(&"footstep_grass", Vector3.ZERO)
			AudioManager.play_music(&"day_1")
			AudioManager.set_ambience(&"rain_loop")
			player.call(&"teleport_home")
			print("SMOKE: save data=", player.call(&"get_save_data"))
		36:
			print("SMOKE OK")
			get_tree().quit()


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)
