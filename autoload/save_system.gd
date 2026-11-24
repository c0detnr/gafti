extends Node
## Kayıt/yükleme: tüm autoload'lar + "persist" grubundaki sahne düğümleri → user://save_1.json
## Sözleşme: AGENTS.md §4 (SaveSystem).
## - Autoload'lar: get_save_data() / load_save_data(d) (varsa reset()).
## - Persist düğümleri: get_save_id() -> String, get_save_data(), load_save_data(d).
## - "persist_spawner" grubundaki düğümler (ör. BuildSystem) önce yüklenir; yarattıkları
##   düğümler aynı çağrıda persist verisini alır.
## - load_game() sahne değiştirmez. Sahnede henüz olmayan persist düğümleri sahneye girdiğinde
##   (node_added) bekleyen verilerini alır.

signal saved()
signal loaded()

const SAVE_PATH: String = "user://save_1.json"
const SAVE_VERSION: int = 1
## Kaydedilen autoload'lar (sıra önemli: saat → hava → diğerleri).
const AUTOLOADS: Array[String] = [
	"GameClock", "Weather", "Economy", "Reputation", "Inventory", "QuestManager", "Effects", "ContentFlags",
]

## Sahneye henüz girmemiş persist düğümlerinin verileri: save_id -> Dictionary
var _pending: Dictionary = {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"autoloads": {},
		"seed_book": SeedBook.get_save_data(),
		"nodes": {},
	}
	var autos: Dictionary = data["autoloads"]
	for n: String in AUTOLOADS:
		var node: Node = get_node_or_null("/root/" + n)
		if node != null and node.has_method("get_save_data"):
			autos[n] = node.call("get_save_data")
	var nodes: Dictionary = data["nodes"]
	# Henüz sahneye girmemiş düğümlerin verisini kaybetme.
	for k: String in _pending:
		nodes[k] = _pending[k]
	for node: Node in _persist_nodes():
		var sid: String = _save_id(node)
		if sid != "":
			nodes[sid] = node.call("get_save_data")
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: kayıt dosyası açılamadı: %s" % FileAccess.get_open_error())
		EventBus.notify.emit(tr("SAVE_FAILED"), &"bad")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	saved.emit()
	EventBus.notify.emit(tr("SAVE_DONE"), &"good")


func load_game() -> bool:
	if not has_save():
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		push_warning("SaveSystem: kayıt dosyası bozuk.")
		return false
	var data: Dictionary = parsed
	SeedBook.load_save_data(data.get("seed_book", {}))
	var autos: Dictionary = data.get("autoloads", {})
	for n: String in AUTOLOADS:
		var node: Node = get_node_or_null("/root/" + n)
		if node != null and node.has_method("load_save_data") and autos.has(n):
			node.call("load_save_data", autos[n])
	_pending = (data.get("nodes", {}) as Dictionary).duplicate(true)
	_apply_pending_to_scene()
	loaded.emit()
	return true


## Yeni oyun: tüm autoload'ları başlangıç durumuna döndürür (kayıt dosyasını silmez).
func new_game() -> void:
	_pending.clear()
	SeedBook.reset()
	for n: String in AUTOLOADS:
		var node: Node = get_node_or_null("/root/" + n)
		if node == null:
			continue
		if node.has_method("reset"):
			node.call("reset")
		elif node.has_method("load_save_data"):
			node.call("load_save_data", {})


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------------------------------------------------------------------------
# İç mantık
# ---------------------------------------------------------------------------

func _persist_nodes() -> Array[Node]:
	var out: Array[Node] = []
	for g: StringName in [&"persist_spawner", &"persist"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			if out.has(n):
				continue
			if n.has_method("get_save_data") and n.has_method("load_save_data") and n.is_inside_tree():
				out.append(n)
	return out


func _save_id(node: Node) -> String:
	if node.has_method("get_save_id"):
		return String(node.call("get_save_id"))
	return String(node.get_path())


func _apply_pending_to_scene() -> void:
	# Önce üreticiler (BuildSystem vb.): yerleştirilmiş nesneleri yeniden yaratırlar.
	for node: Node in get_tree().get_nodes_in_group(&"persist_spawner"):
		_apply_to(node)
	for node: Node in _persist_nodes():
		_apply_to(node)


func _apply_to(node: Node) -> void:
	if not node.has_method("load_save_data"):
		return
	var sid: String = _save_id(node)
	if sid != "" and _pending.has(sid):
		var d: Variant = _pending[sid]
		_pending.erase(sid)
		node.call("load_save_data", d if d is Dictionary else {})


func _on_node_added(node: Node) -> void:
	if _pending.is_empty():
		return
	if node.is_in_group(&"persist") or node.is_in_group(&"persist_spawner"):
		# _ready sonrası uygula (save_id dışa aktarılan değişkenlerden gelebilir).
		_apply_deferred.call_deferred(node)


func _apply_deferred(node: Node) -> void:
	if is_instance_valid(node) and node.is_inside_tree():
		_apply_to(node)
