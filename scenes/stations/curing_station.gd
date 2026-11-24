class_name CuringStation
extends StationBase
## Kürleme kavanozları (jar_curing) + paketleme.
## Kürleme: her tam oyun günü +5 kalite (en fazla 3 gün / +15; tür potansiyeli + 15 sınırı).
## Paketleme: kuru tomurcuk → kavanoz (Inventory.JAR_GRAMS gram/kavanoz), kind &"jar".

const MODEL: String = "res://assets/models/props/jar.glb"
const CAPACITY: int = 4
const BONUS_PER_DAY: int = 5
const MAX_DAYS: int = 3

## Partiler: { strain, quality, grams, start }
var batches: Array[Dictionary] = []


func _ready() -> void:
	super._ready()
	# Rafta üç kavanoz.
	var shelf: Node3D = ModelLoader.placeholder(Vector3(0.8, 0.6, 0.4), Color(0.5, 0.36, 0.22), "curing_shelf")
	shelf.name = "Shelf"
	add_child(shelf)
	for i: int in range(3):
		var j: Node3D = ModelLoader.instance(MODEL, Vector3(0.12, 0.18, 0.12), Color(0.7, 0.85, 0.9))
		j.position = Vector3(-0.25 + 0.25 * i, 0.6, 0.0)
		add_child(j)


func get_interact_text() -> String:
	return tr("CURE_PROMPT") % [batches.size(), CAPACITY]


func interact(_player: Node) -> void:
	var opts: Array[Dictionary] = []
	opts.append({"id": &"_put", "text": tr("CURE_ACT_PUT"), "disabled": batches.size() >= CAPACITY or Inventory.get_items(&"dry_bud").is_empty()})
	opts.append({"id": &"_take", "text": tr("CURE_ACT_TAKE") % batches.size(), "disabled": batches.is_empty()})
	opts.append({"id": &"_pack", "text": tr("CURE_ACT_PACK"), "disabled": Inventory.get_items(&"dry_bud").is_empty()})
	ActionMenu.open(tr("CURE_TITLE"), opts, _on_action)


func _on_action(id: StringName) -> void:
	match id:
		&"_put":
			ActionMenu.open(tr("CURE_PICK"), _dry_bud_options(), func(bud: StringName) -> void: put(bud))
		&"_take":
			take_all()
		&"_pack":
			ActionMenu.open(tr("CURE_PICK_PACK"), _dry_bud_options(), func(bud: StringName) -> void: pack(bud))


func _dry_bud_options() -> Array[Dictionary]:
	var opts: Array[Dictionary] = []
	for it: Dictionary in Inventory.get_items(&"dry_bud"):
		var s: StrainData = SeedBook.get_strain(it["strain"])
		var n: String = s.get_display_name() if s != null else String(it["strain"])
		opts.append({"id": it["id"], "text": tr("ITEM_BUD_LINE") % [n, int(it["count"]), int(it["quality"])]})
	return opts


## Kuru tomurcuk yığınını kürlemeye koyar.
func put(dry_id: StringName) -> bool:
	if batches.size() >= CAPACITY:
		notify(tr("CURE_FULL"), &"bad")
		return false
	var it: Dictionary = Inventory.get_item(dry_id)
	if it.is_empty() or it["kind"] != &"dry_bud":
		return false
	var grams: int = int(it["count"])
	if not Inventory.remove_item(dry_id, grams):
		return false
	batches.append({"strain": String(it["strain"]), "quality": int(it["quality"]), "grams": grams, "start": GameClock.total_minutes})
	play_sfx(&"jar_close")
	notify(tr("CURE_PUT"), &"good")
	return true


## Kürlenme bonusu (tam gün sayısına göre).
func get_bonus(b: Dictionary) -> int:
	var days: int = (GameClock.total_minutes - int(b["start"])) / GameClock.MINUTES_PER_DAY
	return mini(days, MAX_DAYS) * BONUS_PER_DAY


## Tüm partileri çıkarır (kalite bonusuyla). Toplam gramı döndürür.
func take_all() -> int:
	var total: int = 0
	for b: Dictionary in batches:
		var strain: StringName = StringName(String(b["strain"]))
		var sd: StrainData = SeedBook.get_strain(strain)
		var cap: int = int(sd.quality_potential) + 15 if sd != null else 100
		var q: int = mini(int(b["quality"]) + get_bonus(b), maxi(cap, int(b["quality"])))
		Inventory.add_item(Inventory.make_item(&"dry_bud", strain, q, int(b["grams"]), 1.0))
		total += int(b["grams"])
		if get_bonus(b) > 0:
			quest_event(&"curing_done", {"strain": strain, "grams": int(b["grams"])})
	batches.clear()
	if total > 0:
		notify(tr("CURE_TAKEN") % total, &"good")
	return total


## Kuru tomurcuğu kavanozlara paketler. Oluşan kavanoz sayısını döndürür.
func pack(dry_id: StringName) -> int:
	var it: Dictionary = Inventory.get_item(dry_id)
	if it.is_empty() or it["kind"] != &"dry_bud":
		return 0
	var per: int = int(Inventory.JAR_GRAMS)
	var jars: int = int(it["count"]) / per
	if jars <= 0:
		notify(tr("CURE_PACK_NOT_ENOUGH") % per, &"bad")
		return 0
	if not Inventory.remove_item(dry_id, jars * per):
		return 0
	Inventory.add_item(Inventory.make_item(&"jar", it["strain"], int(it["quality"]), jars, Inventory.JAR_GRAMS))
	play_sfx(&"jar_close")
	notify(tr("CURE_PACKED") % jars, &"good")
	quest_event(&"jar_packed", {"strain": it["strain"], "count": jars})
	return jars


func get_save_data() -> Dictionary:
	return {"batches": batches.duplicate(true)}


func load_save_data(d: Dictionary) -> void:
	batches.clear()
	for b: Variant in d.get("batches", []):
		if b is Dictionary:
			batches.append(b)
