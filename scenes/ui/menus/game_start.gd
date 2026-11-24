class_name GameStart
extends RefCounted
## Ana menü → oyun sahnesi geçiş bayrakları (statik, autoload gerektirmez).

const GAME_SCENE: String = "res://scenes/world/valley.tscn"
const MENU_SCENE: String = "res://scenes/ui/menus/main_menu.tscn"

## true ise oyuncu sahneye girince SaveSystem.load_game() çağrılır (Devam Et).
static var load_on_start: bool = false
