class_name StationBase
extends Node3D
## Tüm istasyonların ortak tabanı (AGENTS.md §5 etkileşim sözleşmesi):
## - Kök düğüm ve alt Area3D (layer 4) "interactable" grubunda; ikisi de
##   get_interact_text() ve interact(player) sağlar.
## - "persist" grubunda; get_save_id/get_save_data/load_save_data alt sınıflarca doldurulur.
## - Fiziksel çarpışma için StaticBody3D (layer 1).

const INTERACT_LAYER: int = 1 << 3 # layer 4

## Kayıt kimliği. Boşsa sahne yolu kullanılır (sahnede sabit duran istasyonlar için yeterli).
@export var save_id: String = ""
## Etkileşim alanı boyutu.
@export var interact_size: Vector3 = Vector3(1.4, 1.6, 1.4)
## Çarpışma kutusu boyutu (sıfır = çarpışma yok).
@export var body_size: Vector3 = Vector3(0.6, 0.8, 0.6)

var interact_area: Area3D


func _init() -> void:
	add_to_group(&"interactable")
	add_to_group(&"persist")


func _ready() -> void:
	_build_interaction()
	_build_body()


func get_save_id() -> String:
	if save_id != "":
		return save_id
	return String(get_path())


## Alt sınıflar geçersiz kılar.
func get_interact_text() -> String:
	return ""


## Alt sınıflar geçersiz kılar.
func interact(_player: Node) -> void:
	pass


func get_save_data() -> Dictionary:
	return {}


func load_save_data(_d: Dictionary) -> void:
	pass


func _build_interaction() -> void:
	interact_area = Area3D.new()
	interact_area.name = "InteractArea"
	interact_area.set_script(load("res://scripts/systems/interact_area.gd"))
	interact_area.collision_layer = INTERACT_LAYER
	interact_area.collision_mask = 0
	interact_area.monitoring = false
	interact_area.monitorable = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = interact_size
	shape.shape = box
	shape.position.y = interact_size.y * 0.5
	interact_area.add_child(shape)
	add_child(interact_area)


func _build_body() -> void:
	if body_size == Vector3.ZERO:
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = body_size
	shape.shape = box
	shape.position.y = body_size.y * 0.5
	body.add_child(shape)
	add_child(body)


## Görev sistemine olay bildirir (QuestManager yoksa sessizce geçer).
func quest_event(event: StringName, data: Dictionary = {}) -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm != null and qm.has_method("notify_event"):
		qm.call("notify_event", event, data)


## Ses efekti (AudioManager yoksa sessizce geçer).
func play_sfx(id: StringName) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx"):
		am.call("play_sfx", id, global_position)


func notify(text: String, kind: StringName = &"info") -> void:
	EventBus.notify.emit(text, kind)


## Durum etiketi (bitki/kurutma uyarıları için başın üstünde küçük yazı).
func make_status_label(height: float) -> Label3D:
	var l: Label3D = Label3D.new()
	l.name = "Status"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.004
	l.font_size = 40
	l.outline_size = 10
	l.no_depth_test = false
	l.position.y = height
	l.modulate = Color(1.0, 0.95, 0.7)
	add_child(l)
	return l
