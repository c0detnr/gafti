class_name CustomerProfile
extends Resource
## Dükkan müşteri tipi (GDD §5.6).

@export var id: StringName = &""
@export var type: StringName = &""          # &"villager", &"tourist", &"medical", &"expert"
@export var name_key: String = ""
## Tercih edilen ürün türleri (Inventory kind), öncelik sırasıyla.
@export var preferred_kinds: Array[StringName] = []
## Kabul ettiği en düşük kalite (0..100) ve bayıldığı kalite.
@export var min_quality: int = 0
@export var love_quality: int = 80
## Bütçe aralığı (₺).
@export var budget_min: int = 50
@export var budget_max: int = 200
## Değerinin kaç katına kadar fiyata razı (1.0 = adil fiyat).
@export var price_tolerance: float = 1.1
## Aroma/nadir tür meraklısı mı (uzman: mutasyon/nadir tür bonus).
@export var wants_rare: bool = false
## Kasada bekleme sabrı (gerçek saniye).
@export var patience_sec: float = 45.0
## Doğma ağırlığı ve yaz çarpanı.
@export var spawn_weight: float = 1.0
@export var summer_multiplier: float = 1.0
@export var winter_multiplier: float = 1.0
## Memnuniyette verilen itibar ölçeği.
@export var reputation_scale: float = 1.0
## Görünüş renkleri (character_base materyalleri).
@export var top_colors: Array[Color] = []
@export var tops: Array[StringName] = []
## Selamlama ve tepki metin anahtarı öneki (ör. CUST_VILLAGER → CUST_VILLAGER_HELLO_1..3).
@export var line_prefix: String = ""
