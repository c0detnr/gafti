class_name DryingRackStation
extends StationBase
## Kurutma rafı: ıslak tomurcuk → kuru tomurcuk (3-7 oyun saati, nem dengesine bağlı).
## Kuru ağırlık ≈ ıslak × 0.3. İyi nemde (0.45-0.65) +2 kalite, aksi halde -3.

const MODEL: String = "res://assets/models/props/drying_rack.glb"
const CAPACITY: int = 3
const DRY_RATIO: float = 0.3

## Partiler: { strain, quality, grams(ıslak), start: int (toplam dakika), duration: int }
var batches: Array[Dictionary] = []

var _status: Label3D


func _ready() -> void:
	super._ready()
	var m: Node3D = ModelLoader.instance(MODEL, Vector3(1.2, 1.7, 0.4), Color(0.5, 0.36, 0.22))
	m.name = "Model"
	add_child(m)
	_status = make_status_label(2.0)
	GameClock.hour_passed.connect(func(_h: int) -> void: _update_status())
	_update_status()


func get_interact_text() -> String:
	return tr("DRY_PROMPT") % [batches.size(), CAPACITY, count_done()]


func interact(_player: Node) -> void:
	var opts: Array[Dictionary] = []
	for it: Dictionary in Inventory.get_items(&"wet_bud"):
		var s: StrainData = SeedBook.get_strain(it["strain"])
		var n: String = s.get_display_name() if s != null else String(it["strain"])
		opts.append({
			"id": it["id"], "text": tr("DRY_ACT_HANG") % [n, int(it["count"]), int(it["quality"])],
			"disabled": batches.size() >= CAPACITY,
		})
	opts.append({"id": &"_collect", "text": tr("DRY_ACT_COLLECT") % count_done(), "disabled": count_done() == 0})
	ActionMenu.open(tr("DRY_TITLE"), opts, _on_action)


func _on_action(id: StringName) -> void:
	if id == &"_collect":
		collect()
	else:
		hang(id)


## Envanterdeki ıslak tomurcuk yığınının tamamını rafa asar.
func hang(wet_id: StringName) -> bool:
	if batches.size() >= CAPACITY:
		notify(tr("DRY_FULL"), &"bad")
		return false
	var it: Dictionary = Inventory.get_item(wet_id)
	if it.is_empty() or it["kind"] != &"wet_bud":
		return false
	var grams: int = int(it["count"])
	if not Inventory.remove_item(wet_id, grams):
		return false
	var hum: float = Weather.get_outdoor_humidity()
	# Nem yüksekse kuruma uzar: 3..7 saat.
	var hours: float = clampf(5.0 + (hum - 0.6) * 10.0, 3.0, 7.0)
	batches.append({
		"strain": String(it["strain"]), "quality": int(it["quality"]), "grams": grams,
		"start": GameClock.total_minutes, "duration": int(hours * 60.0), "hum": hum,
	})
	play_sfx(&"hang")
	notify(tr("DRY_HUNG") % int(round(hours)), &"good")
	_update_status()
	return true


func count_done() -> int:
	var n: int = 0
	for b: Dictionary in batches:
		if _is_done(b):
			n += 1
	return n


## Kuruyan partileri kuru tomurcuk olarak envantere ekler. Eklenen toplam gramı döndürür.
func collect() -> int:
	var total: int = 0
	var remaining: Array[Dictionary] = []
	for b: Dictionary in batches:
		if not _is_done(b):
			remaining.append(b)
			continue
		var hum: float = float(b.get("hum", 0.6))
		var q: int = int(b["quality"]) + (2 if hum >= 0.45 and hum <= 0.65 else -3)
		var grams: int = maxi(1, int(round(float(b["grams"]) * DRY_RATIO)))
		var strain: StringName = StringName(String(b["strain"]))
		Inventory.add_item(Inventory.make_item(&"dry_bud", strain, q, grams, 1.0))
		total += grams
		quest_event(&"drying_done", {"strain": strain, "grams": grams})
	batches = remaining
	if total > 0:
		notify(tr("DRY_COLLECTED") % total, &"good")
	_update_status()
	return total


func _is_done(b: Dictionary) -> bool:
	return GameClock.total_minutes - int(b["start"]) >= int(b["duration"])


func _update_status() -> void:
	if _status == null:
		return
	var done: int = count_done()
	if done > 0:
		_status.text = tr("DRY_STATUS_DONE")
	elif batches.size() > 0:
		_status.text = tr("DRY_STATUS_DRYING")
	else:
		_status.text = ""


func get_save_data() -> Dictionary:
	return {"batches": batches.duplicate(true)}


func load_save_data(d: Dictionary) -> void:
	batches.clear()
	for b: Variant in d.get("batches", []):
		if b is Dictionary:
			batches.append(b)
	_update_status()
