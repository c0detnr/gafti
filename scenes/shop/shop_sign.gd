class_name ShopSign
extends Node3D
## "AÇIK / KAPALI" tabelası: dükkanı açar/kapatır (16:00–22:00).

var shop: ShopManager = null
var _label: Label3D = null
var _board: MeshInstance3D = null
var _mat: StandardMaterial3D = null


func _ready() -> void:
	shop = get_parent() as ShopManager
	if shop == null and get_parent() != null:
		shop = get_parent().get_parent() as ShopManager
	_board = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.5, 0.05)
	_board.mesh = bm
	_board.position = Vector3(0, 1.5, 0)
	_mat = StandardMaterial3D.new()
	_board.material_override = _mat
	add_child(_board)
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04
	pm.bottom_radius = 0.05
	pm.height = 1.3
	post.mesh = pm
	post.position = Vector3(0, 0.65, 0)
	add_child(post)
	_label = Label3D.new()
	_label.position = Vector3(0, 1.5, 0.035)
	_label.font_size = 64
	_label.pixel_size = 0.003
	_label.outline_size = 8
	add_child(_label)
	InteractArea.attach(self, Vector3(1.2, 2.0, 1.2))
	if shop != null:
		shop.shop_opened.connect(_update)
		shop.shop_closed.connect(_update)
	_update()


func _update() -> void:
	var open: bool = shop != null and shop.is_open
	_label.text = tr("SIGN_OPEN") if open else tr("SIGN_CLOSED")
	_mat.albedo_color = Color(0.25, 0.6, 0.3) if open else Color(0.6, 0.22, 0.2)


func get_interact_text() -> String:
	if shop == null:
		return ""
	return tr("SIGN_CLOSE_SHOP") if shop.is_open else tr("SIGN_OPEN_SHOP")


func interact(_player: Node) -> void:
	if shop == null:
		return
	if shop.is_open:
		shop.close_shop()
	else:
		shop.open_shop()
	_update()
