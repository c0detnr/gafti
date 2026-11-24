extends Node
## Para, işlemler, günlük faturalar ve gün sonu raporu.
## Sözleşme: AGENTS.md §4 (Economy). Denge: GDD §5.9 (başlangıç 2000 ₺).

signal money_changed(money: int)

const START_MONEY: int = 2000
const FAINT_PENALTY: float = 0.10
## Ürün başına baz gram fiyatı (₺) — kalite ve tür ile çarpılır.
const BASE_PRICE_PER_GRAM: float = 30.0
const KIND_MULT: Dictionary = {
	&"wet_bud": 0.3, &"dry_bud": 1.0, &"jar": 1.15, &"preroll": 1.6,
}

var money: int = START_MONEY
## Muhtar'dan alınan faizsiz borç.
var debt: int = 0

var _today: Dictionary = {}
var _last_report: Dictionary = {}


func _ready() -> void:
	_reset_today(GameClock.day)
	GameClock.day_started.connect(_on_day_started)
	EventBus.inspection_finished.connect(_on_inspection_finished)


func add(amount: int, reason: String) -> void:
	if amount == 0:
		return
	money += amount
	_record(amount, reason)
	money_changed.emit(money)


## Satın alma: para yetmezse false döner ve hiçbir şey değişmez.
func spend(amount: int, reason: String) -> bool:
	if amount < 0:
		return false
	if money < amount:
		EventBus.notify.emit(tr("ECON_NOT_ENOUGH") % amount, &"bad")
		return false
	if amount == 0:
		return true
	money -= amount
	_record(-amount, reason)
	money_changed.emit(money)
	return true


## Zorunlu ödeme (fatura, ceza): bakiye eksiye düşebilir.
func charge(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	money -= amount
	_record(-amount, reason)
	money_changed.emit(money)


func get_day_report() -> Dictionary:
	var r: Dictionary = _today.duplicate(true)
	r["profit"] = int(r["income"]) - int(r["expenses"])
	r["bills_due"] = estimate_daily_bills()
	r["money"] = money
	return r


## Bir önceki günün kapanmış raporu.
func get_last_day_report() -> Dictionary:
	return _last_report.duplicate(true)


## Muhtar'dan borç al (eksi bakiyede oyun bitmesin diye).
func take_loan(amount: int) -> void:
	debt += amount
	add(amount, tr("ECON_REASON_LOAN"))


func repay_loan(amount: int) -> bool:
	var a: int = mini(amount, debt)
	if a <= 0 or not spend(a, tr("ECON_REASON_LOAN_REPAY")):
		return false
	debt -= a
	return true


## Bayılma cezası (%10, sadece pozitif bakiyeden). Kesilen tutarı döndürür.
func apply_faint_penalty() -> int:
	if money <= 0:
		return 0
	var fine: int = int(ceil(float(money) * FAINT_PENALTY))
	charge(fine, tr("ECON_REASON_FAINT"))
	return fine


## Önerilen birim satış fiyatı (₺). Tomurcukta 1 adet = 1 gram; kavanozda adet başı "grams".
func get_item_value(item: Dictionary) -> int:
	var kind: StringName = StringName(item.get("kind", &""))
	if not KIND_MULT.has(kind):
		return 0
	var quality: float = float(item.get("quality", 50))
	var grams: float = float(item.get("grams", 1.0))
	var strain_mult: float = 1.0
	var strain: StrainData = SeedBook.get_strain(StringName(item.get("strain", &"")))
	if strain != null:
		strain_mult = strain.price_multiplier
	var q_mult: float = 0.4 + quality / 100.0 * 1.2
	var season_mult: float = 1.0
	if GameClock.season == &"winter":
		season_mult = 1.25
	return maxi(1, int(round(BASE_PRICE_PER_GRAM * grams * float(KIND_MULT[kind]) * q_mult * strain_mult * season_mult)))


## Günlük elektrik/ısıtma faturası: "power_consumer" grubundaki düğümlerin power_cost_per_day toplamı.
func estimate_daily_bills() -> int:
	var total: int = 0
	if get_tree() == null:
		return 0
	for n: Node in get_tree().get_nodes_in_group(&"power_consumer"):
		var cost: Variant = n.get("power_cost_per_day")
		if cost != null:
			var c: int = int(cost)
			# Isıtıcı sadece kışın (ve sonbaharda yarım) çalışır.
			if n.is_in_group(&"heater"):
				if GameClock.season == &"autumn":
					c /= 2
				elif GameClock.season != &"winter":
					c = 0
			total += c
	return total


func _on_day_started(day: int) -> void:
	# Önceki günün raporunu kapat, faturaları yeni güne yaz.
	_last_report = get_day_report()
	_reset_today(day)
	var bills: int = estimate_daily_bills()
	if bills > 0:
		charge(bills, tr("ECON_REASON_BILLS"))
		EventBus.notify.emit(tr("ECON_BILLS_PAID") % bills, &"info")


func _on_inspection_finished(_score: int, fine: int) -> void:
	if fine > 0:
		charge(fine, tr("ECON_REASON_FINE"))


func _reset_today(day: int) -> void:
	_today = {"day": day, "income": 0, "expenses": 0, "entries": []}


func _record(amount: int, reason: String) -> void:
	if amount > 0:
		_today["income"] = int(_today["income"]) + amount
	else:
		_today["expenses"] = int(_today["expenses"]) - amount
	var entries: Array = _today["entries"]
	entries.append({"amount": amount, "reason": reason, "time": GameClock.get_time_string()})


# ---------------------------------------------------------------------------
# Kayıt
# ---------------------------------------------------------------------------

func reset() -> void:
	money = START_MONEY
	debt = 0
	_last_report = {}
	_reset_today(GameClock.day)
	money_changed.emit(money)


func get_save_data() -> Dictionary:
	return {"money": money, "debt": debt, "today": _today, "last": _last_report}


func load_save_data(d: Dictionary) -> void:
	if d.is_empty():
		reset()
		return
	money = int(d.get("money", START_MONEY))
	debt = int(d.get("debt", 0))
	var t: Variant = d.get("today", {})
	if t is Dictionary and (t as Dictionary).has("income"):
		_today = (t as Dictionary).duplicate(true)
		_today["income"] = int(_today["income"])
		_today["expenses"] = int(_today["expenses"])
		_today["day"] = int(_today.get("day", GameClock.day))
		if not _today.has("entries"):
			_today["entries"] = []
	else:
		_reset_today(GameClock.day)
	var l: Variant = d.get("last", {})
	_last_report = (l as Dictionary).duplicate(true) if l is Dictionary else {}
	money_changed.emit(money)
