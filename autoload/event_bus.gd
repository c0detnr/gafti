extends Node
## Sistemler arası global sinyaller. Sözleşme: AGENTS.md §4.

signal interaction_prompt(text: String)
signal minigame_requested(id: StringName, context: Dictionary)
signal minigame_finished(id: StringName, result: Dictionary)
signal notify(text: String, kind: StringName)
signal plant_harvested(plant_id: int, item: Dictionary)
signal sale_completed(amount: int, item: Dictionary, customer_type: StringName)
signal inspection_finished(score: int, fine: int)
signal dialogue_requested(dialogue_id: StringName)
signal dialogue_finished(dialogue_id: StringName)
signal player_customization_changed(data: Dictionary)
signal ui_block_input(blocked: bool)
