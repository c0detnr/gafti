class_name QuestData
extends Resource
## Bir komedi görevinin verisi. QuestManager data/quests/*.tres dosyalarını yükler.

## Görev kimliği (dosya adıyla aynı).
@export var id: StringName = &""
## Başlık ve açıklama çeviri anahtarları.
@export var title_key: String = ""
@export var description_key: String = ""
## Görevi veren NPC (boşsa otomatik başlar / zincirle gelir).
@export var giver: StringName = &""
## Görev teklif diyaloğu (giver ile konuşulunca, ön koşullar tamamsa açılır).
@export var offer_dialogue: StringName = &""
## Ön koşul görevler (hepsi bitmiş olmalı).
@export var requires: Array[StringName] = []
## Hedefler: [{ "event": StringName, "count": int, "match": Dictionary (ops.),
##   "npc": StringName (ops.), "dialogue": StringName (ops.), "text_key": String (ops.) }]
## "npc"+"dialogue" verilirse hedef açıkken o NPC ile konuşunca bu diyalog gösterilir.
@export var objectives: Array[Dictionary] = []
## Hedefler sırayla mı ilerlesin?
@export var sequential: bool = false
## Ödüller: { "money": int, "reputation": float, "license_level": int, "item": Dictionary }
@export var rewards: Dictionary = {}
## Bitince otomatik başlayacak görevler.
@export var next_quests: Array[StringName] = []
## Başlarken / bitince gösterilecek diyaloglar.
@export var start_dialogue: StringName = &""
@export var end_dialogue: StringName = &""
## Görev aktifken NPC'lerin genel ipucu diyalogları: { npc_id: dialogue_id }
@export var talk_dialogues: Dictionary = {}
## Ana hikâye zinciri mi (HUD sıralaması için)?
@export var main_story: bool = false
