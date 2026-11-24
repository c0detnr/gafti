class_name DialogueData
extends Resource
## Diyalog verisi. Satır: { "speaker": StringName, "text_key": String, "text": String (ops., hazır metin),
##   "action": String (ops., satır gösterilince), "next": int (ops.),
##   "choices": [ { "text_key": String, "next": int (-1 = bitir), "action": String } ] }

@export var id: StringName = &""
@export var lines: Array[Dictionary] = []
## Gaftî Modu'nda bunun yerine gösterilen absürt satırlar (boşsa normal satırlar).
@export var gafti_lines: Array[Dictionary] = []
## true ise satırlardan rastgele BİRİ gösterilir (selamlama havuzları için).
@export var pick_random: bool = false
