class_name BuildableData
extends Resource
## İnşa modunda yerleştirilebilir nesne tanımı (data/buildables/*.tres).

@export var id: StringName = &""
@export var name_key: String = ""
@export var description_key: String = ""
@export var price: int = 100
## İstasyon sahnesi (varsa). Boşsa model + PlacedEquipment kullanılır.
@export_file("*.tscn") var scene_path: String = ""
@export_file("*.glb") var model_path: String = ""
## Yer tutucu/çarpışma kutusu boyutu.
@export var size: Vector3 = Vector3(0.5, 0.5, 0.5)
@export var color: Color = Color(0.6, 0.6, 0.6)
## Yerleşimde başka nesnelerle çakışma yarıçapı (m).
@export var footprint: float = 0.3
## Ekipman etkisi: &"light", &"water", &"humidity", &"heat", &"generator", &"shelf" veya boş.
@export var effect: StringName = &""
## Etki yarıçapı (m).
@export var effect_radius: float = 2.0
## Günlük elektrik gideri (₺).
@export var power_cost_per_day: int = 0
@export var min_license: int = 1
## Tüketilen ek gruplar (ör. "shop_shelf").
@export var extra_groups: Array[StringName] = []


func get_display_name() -> String:
	return TranslationServer.translate(name_key) if name_key != "" else String(id)


func get_kit_id() -> StringName:
	return StringName("kit_" + String(id))
