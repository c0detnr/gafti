extends Node3D
## Ajan A sistem testi: zemin + 3 saksı + su deposu + kurutma + kürleme + çaprazlama + inşa modu.
## Hızlandırılmış saatle (GameClock.advance_minutes) çalışır ve sonuçları print eder.
## Çalıştır: Godot --headless --path <proje> res://tests/test_systems.tscn --quit-after 600

var _pass: int = 0
var _fail: int = 0
var pots: Array[PotStation] = []
var tank: WaterTankStation
var rack: DryingRackStation
var cure: CuringStation
var breeder: BreedingStation
var build: BuildSystem


func _ready() -> void:
	_build_scene()
	_run.call_deferred()


func _build_scene() -> void:
	# Zemin
	var ground: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(30, 1, 30)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(30, 30)
	mi.mesh = pm
	ground.add_child(mi)
	add_child(ground)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0, 6, 8)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	# İstasyonlar
	for i: int in range(3):
		var p: PotStation = (load("res://scenes/stations/pot_station.tscn") as PackedScene).instantiate() as PotStation
		p.save_id = "test_pot_%d" % i
		p.position = Vector3(-2.0 + 2.0 * i, 0, 0)
		add_child(p)
		pots.append(p)
	tank = _inst("res://scenes/stations/water_tank_station.tscn", Vector3(-4, 0, 2)) as WaterTankStation
	rack = _inst("res://scenes/stations/drying_rack_station.tscn", Vector3(0, 0, 3)) as DryingRackStation
	cure = _inst("res://scenes/stations/curing_station.tscn", Vector3(2, 0, 3)) as CuringStation
	breeder = _inst("res://scenes/stations/breeding_station.tscn", Vector3(4, 0, 3)) as BreedingStation
	build = (load("res://scenes/build/build_mode.tscn") as PackedScene).instantiate() as BuildSystem
	add_child(build)


func _inst(path: String, pos: Vector3) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	n.set("save_id", path.get_file().get_basename())
	n.position = pos
	add_child(n)
	return n


func _check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
		print("[TEST] PASS  ", name, ("  (" + info + ")") if info != "" else "")
	else:
		_fail += 1
		print("[TEST] FAIL  ", name, ("  (" + info + ")") if info != "" else "")


func _run() -> void:
	print("[TEST] ===== Ajan A sistem testi başlıyor =====")
	GameClock.paused = true # gerçek zamanlı ilerlemeyi kapat; sadece advance_minutes
	SaveSystem.new_game()
	_check("yeni oyun parası 2000", Economy.money == 2000, str(Economy.money))
	_check("başlangıç tohumları", Inventory.count_of(&"seed_pusu_kusu") == 2 and Inventory.count_of(&"seed_ladin_duman") == 2)
	_check("gün 1, 06:00, ilkbahar", GameClock.day == 1 and GameClock.get_time_string() == "06:00" and GameClock.season == &"spring")
	_check("istasyon interactable + Area3D layer 4",
		pots[0].is_in_group(&"interactable") and pots[0].interact_area != null and pots[0].interact_area.collision_layer == 8)
	_check("etkileşim metni", pots[0].get_interact_text() != "", pots[0].get_interact_text())

	# --- İnşa: LED lamba (satın al + yerleştir), sonra sat ---
	var money0: int = Economy.money
	var lamp: Node3D = build.place_buildable(&"led_lamp", Vector3(-1.0, 0, 0.5))
	_check("LED lamba yerleştirildi", lamp != null and Economy.money == money0 - 250, str(Economy.money))
	var bad: Node3D = build.place_buildable(&"led_lamp", Vector3(-1.0, 0, 0.5))
	_check("çakışan yerleşim reddedildi", bad == null)
	var extra_pot: Node3D = build.place_buildable(&"pot", BuildSystem.snap(Vector3(5.2, 0, -2.1)))
	_check("inşa ile saksı", extra_pot != null and extra_pot is PotStation)
	var money1: int = Economy.money
	_check("saksı satıldı (%50 iade)", build.sell(extra_pot) and Economy.money == money1 + 40, str(Economy.money))

	# --- Ekim ---
	_check("ekim 1", pots[0].plant_seed(&"seed_pusu_kusu"))
	_check("ekim 2", pots[1].plant_seed(&"seed_cay_yapragi"))
	_check("ekim 3", pots[2].plant_seed(&"seed_ladin_duman"))
	_check("tohum harcandı", Inventory.count_of(&"seed_pusu_kusu") == 1)

	# --- Büyüme döngüsü: 6 saatte bir bakım ---
	Inventory.add_item({"id": &"nutrient", "kind": &"nutrient", "count": 40})
	Inventory.add_item({"id": &"pesticide", "kind": &"tool", "count": 10})
	var max_stage: int = 0
	var harvested: Array[Dictionary] = []
	for cycle: int in range(4 * 9): # en fazla 9 gün
		tank.fill_can()
		for p: PotStation in pots:
			var s: PlantState = p.get_state()
			if s == null or s.dead:
				continue
			if s.water < 0.6:
				p.apply_care(&"water", 90)
			if s.nutrients < 0.5 and s.stage >= PlantState.Stage.SEEDLING:
				p.apply_care(&"feed", 90)
			if s.pest != &"":
				p.apply_care(&"pest", 100)
			if s.stage >= PlantState.Stage.VEG and not s.pruned:
				p.apply_care(&"prune", 80)
			max_stage = maxi(max_stage, s.stage)
			if s.is_ready():
				harvested.append(p.harvest())
		GameClock.advance_minutes(360)
		if harvested.size() >= 3:
			break
	var info: String = ""
	for p: PotStation in pots:
		if p.get_state() != null:
			info += p.get_status_text().replace("\n", " ") + " | "
	_check("bitki büyüdü (aşama ≥ çiçeklenme)", max_stage >= PlantState.Stage.FLOWER, "max_stage=%d gün=%d" % [max_stage, GameClock.day])
	_check("hasat yapıldı", harvested.size() >= 1, "hasat=%d %s" % [harvested.size(), info])
	if harvested.size() > 0:
		var h: Dictionary = harvested[0]
		print("[TEST] hasat örneği: ", h)
		_check("ıslak tomurcuk envanterde", Inventory.total_grams(&"wet_bud") > 0.0)
	print("[TEST] gün=%d %s hava=%s para=%d" % [GameClock.day, GameClock.get_time_string(), Weather.current, Economy.money])

	# --- Kurutma ---
	var wet: Array[Dictionary] = Inventory.get_items(&"wet_bud")
	if not wet.is_empty():
		_check("rafa asıldı", rack.hang(wet[0]["id"]))
		GameClock.advance_minutes(8 * 60)
		var dry_g: int = rack.collect()
		_check("kurutma → kuru tomurcuk", dry_g > 0, "%d g" % dry_g)
	# --- Kürleme + paketleme ---
	var dry: Array[Dictionary] = Inventory.get_items(&"dry_bud")
	if not dry.is_empty():
		var before_q: int = int(dry[0]["quality"])
		_check("kürlemeye kondu", cure.put(dry[0]["id"]))
		GameClock.advance_minutes(2 * 1440 + 10)
		cure.take_all()
		var best_q: int = 0
		for it: Dictionary in Inventory.get_items(&"dry_bud"):
			best_q = maxi(best_q, int(it["quality"]))
		_check("kürleme kaliteyi artırdı", best_q > before_q, "%d → %d" % [before_q, best_q])
		var packed: int = 0
		for it: Dictionary in Inventory.get_items(&"dry_bud"):
			packed += cure.pack(it["id"])
		_check("paketleme → kavanoz", packed > 0 and Inventory.get_items(&"jar").size() > 0, "%d kavanoz" % packed)
		var jars: Array[Dictionary] = Inventory.get_items(&"jar")
		if not jars.is_empty():
			print("[TEST] kavanoz değeri: ", Economy.get_item_value(jars[0]), " ₺/adet")

	# --- Çaprazlama ---
	Inventory.add_item(Inventory.make_item(&"seed", &"pusu_kusu", 0, 1, 0.0))
	Inventory.add_item(Inventory.make_item(&"seed", &"ladin_duman", 0, 1, 0.0))
	var new_id: StringName = breeder.breed(&"pusu_kusu", &"ladin_duman", "Test Kuşu")
	_check("çaprazlama yeni tür", new_id != &"" and SeedBook.get_strain(new_id) != null, String(new_id))
	_check("yeni tür tohumları", Inventory.count_of(Inventory.make_id(&"seed", new_id)) == 3)
	_check("Tohum Defteri", SeedBook.is_discovered(new_id))
	var gen_ok: bool = true
	var a: StrainData = SeedBook.get_strain(&"pusu_kusu")
	var b: StrainData = SeedBook.get_strain(&"ladin_duman")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var mut: int = 0
	for i: int in range(400):
		var c: StrainData = Genetics.cross(a, b, "x", rng)
		if c.yield_trait < 0.0 or c.yield_trait > 100.0:
			gen_ok = false
		if not c.rare_traits.is_empty():
			mut += 1
	_check("genetik sınırlar + mutasyon oranı", gen_ok and mut > 5 and mut < 50, "%d/400 mutasyon" % mut)

	# --- Katalog ---
	var cat: Array[Dictionary] = Catalog.get_catalog()
	var m2: int = Economy.money
	_check("katalog dolu", cat.size() >= 10, str(cat.size()))
	_check("katalogdan alım", Catalog.buy(&"nutrient") and Economy.money == m2 - 60)
	_check("kit alımı", Catalog.buy(&"humidifier") and Inventory.count_of(&"kit_humidifier") == 1)
	var m3: int = Economy.money
	var hum: Node3D = build.place_buildable(&"humidifier", Vector3(1.0, 0, 1.5))
	_check("kit ile bedava yerleşim", hum != null and Economy.money == m3 and Inventory.count_of(&"kit_humidifier") == 0)

	# --- Lisans ---
	Reputation.add_reputation(30.0)
	Economy.add(5000, "test")
	_check("lisans yükseltme", Reputation.upgrade_license() and Reputation.license_level == 2)

	# --- Kayıt / yükleme ---
	pots[0].plant_seed(Inventory.make_id(&"seed", new_id))
	GameClock.advance_minutes(120)
	var saved_money: int = Economy.money
	var saved_day: int = GameClock.day
	var saved_growth: float = pots[0].get_state().growth if pots[0].get_state() != null else -1.0
	var saved_items: int = Inventory.get_items().size()
	var saved_placed: int = build.get_placed().size()
	SaveSystem.save_game()
	_check("kayıt dosyası var", SaveSystem.has_save())
	Economy.add(12345, "bozma")
	GameClock.advance_minutes(1440)
	pots[0].harvest()
	pots[0].load_save_data({})
	Inventory.clear()
	build.load_save_data({})
	SeedBook.reset()
	_check("yükleme", SaveSystem.load_game())
	_check("para geri geldi", Economy.money == saved_money, "%d vs %d" % [Economy.money, saved_money])
	_check("gün geri geldi", GameClock.day == saved_day)
	_check("envanter geri geldi", Inventory.get_items().size() == saved_items)
	_check("özel tür geri geldi", SeedBook.get_strain(new_id) != null)
	_check("yerleştirilenler geri geldi", build.get_placed().size() == saved_placed, "%d" % build.get_placed().size())
	var g: float = pots[0].get_state().growth if pots[0].get_state() != null else -1.0
	_check("saksı durumu geri geldi", is_equal_approx(g, saved_growth), "%f vs %f" % [g, saved_growth])

	# --- Bayılma: 02:00'da %10 ceza ---
	var target: int = (GameClock.FAINT_HOUR * 60 + 24 * 60 - (GameClock.hour * 60 + GameClock.minute) - 1) % (24 * 60)
	GameClock.advance_minutes(target)
	var before_faint: int = Economy.money
	GameClock._tick_minute()
	_check("02:00 bayılma cezası", Economy.money == before_faint - int(ceil(before_faint * 0.1)), "%d → %d" % [before_faint, Economy.money])
	await get_tree().process_frame
	_check("bayılınca 09:00", GameClock.hour == 9, GameClock.get_time_string())

	# --- Hava ---
	var seen: Dictionary = {}
	for i: int in range(200):
		seen[Weather.roll_weather(&"winter")] = true
	_check("kışın kar gelir, yağmur gelmez", seen.has(&"snow") and not seen.has(&"rainy"))

	# --- Demo sınırı ---
	ContentFlags.is_demo = true
	var dbefore: int = GameClock.day
	GameClock.advance_minutes(1440 * 10)
	_check("demo: 7. günden sonra gün ilerlemez", GameClock.day == maxi(dbefore, ContentFlags.DEMO_DAY_LIMIT), "gün=%d" % GameClock.day)
	ContentFlags.is_demo = false

	print("[TEST] ===== SONUÇ: %d geçti, %d kaldı =====" % [_pass, _fail])
	SaveSystem.delete_save()
	get_tree().quit(0 if _fail == 0 else 1)
