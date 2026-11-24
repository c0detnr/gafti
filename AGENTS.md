# GAFTİ — Ajan Kuralları ve Mimari Sözleşmesi

Bu dosya her ajan (Claude, Codex) için bağlayıcıdır. Tasarım: `GDD.md`.

## 1. Ortam (ZORUNLU)
- İşletim sistemi **Windows 11**. Kullanıcıya **asla Linux/bash komutu önerme** (`ls`, `cat`, `rm`, `grep`, `sed`...).
  Kullanıcıya gösterilen her komut **PowerShell** olmalı (`Get-ChildItem`, `Get-Content`, `Remove-Item`, `Select-String`).
- Kendi çalıştırdığın komutlar için de PowerShell tercih et. Yollar: `C:\Users\31\Documents\we2\...`
- Godot: `C:\Users\31\Desktop\Godot_v4.7.2-stable_win64.exe`
  - İçe aktarma: `& $godot --headless --path C:\Users\31\Documents\we2 --import`
  - Hata kontrolü: `& $godot --headless --path C:\Users\31\Documents\we2 --quit-after 120`
- Blender 5.3 (Store sürümü, doğrudan exe çalışmaz). Sadece şu sarmalayıcıyı kullan:
  `powershell -ExecutionPolicy Bypass -File C:\Users\31\Documents\we2\tools\blender\run_blender.ps1 -Script <script.py> [-ScriptArgs a,b]`
- Kullanıcıdan onay isteme; etkileşimli komut çalıştırma.

## 2. Model/ajan dağılımı
| İş | Kim |
|---|---|
| Önemli/detaylı görseller (logo, bitki, bong, joint seti, karakter, sera, shader) | Codex `gpt-6.2-astra` medium |
| İkincil modeller, kasaba props, tekrarlayan kod | Codex `gpt-6.2-sol` medium |
| Çekirdek sistemler, mini oyunlar, oyuncu/dünya kodu | Claude Opus 5.5 alt ajanları |
| Orkestrasyon, entegrasyon, doğrulama | Ana Claude oturumu |

## 3. Kod kuralları
- Godot **4.7**, GDScript, **statik tipler zorunlu** (`var x: int = 0`, `func f(a: float) -> void`).
- Tüm oyuncu metinleri `tr("ANAHTAR")`. Anahtarları `localization/parts/<alan>.csv` dosyasına ekle
  (başlık satırı: `keys,tr`). Ana oturum bunları `localization/strings.csv` içinde birleştirir.
  Anahtar biçimi: `ALAN_ACIKLAMA` (ör. `ROLL_STEP_GRIND`).
- `project.godot` dosyasını **sadece ana oturum** düzenler. Yeni autoload/input gerekiyorsa raporunda belirt.
- Bir autoload'u yalnızca **sahibi** düzenler (aşağıdaki tablo). Diğerleri sadece genel API'yi çağırır.
- Sahneler `.tscn` metin biçiminde. Kodla sahne üretmek serbest (`tools/` altında `@tool` veya headless script).
- Placeholder kullanacaksan model yolunu sabit tut; gerçek `.glb` sonra aynı yola gelir.
- Mobil uyum: dokunmatik = fare (emulate_touch açık). Mini oyunlar sadece sürükle/tıkla/basılı tut kullanır.

## 4. Autoload API sözleşmesi
Sahip sütunu: dosyayı kim yazar. İmzalar sabittir, değiştirme.

### EventBus (`autoload/event_bus.gd`) — ana oturum
Sadece sinyaller:
```
signal interaction_prompt(text: String)            # "" = gizle
signal minigame_requested(id: StringName, context: Dictionary)
signal minigame_finished(id: StringName, result: Dictionary)
signal notify(text: String, kind: StringName)      # kind: &"info", &"good", &"bad"
signal plant_harvested(plant_id: int, item: Dictionary)
signal sale_completed(amount: int, item: Dictionary, customer_type: StringName)
signal inspection_finished(score: int, fine: int)
signal dialogue_requested(dialogue_id: StringName)
signal dialogue_finished(dialogue_id: StringName)
signal player_customization_changed(data: Dictionary)
signal ui_block_input(blocked: bool)               # mini oyun/diyalog açıkken oyuncu hareketi kilitlenir
```

### ContentFlags — ana oturum
`var consumption: bool = true` (içme sahneleri), `var is_mobile: bool`, `var is_demo: bool`, `const DEMO_DAY_LIMIT := 7`.

### Settings — ana oturum
`day_length_minutes: float = 14.0`, `master_volume`, `music_volume`, `sfx_volume`, `graphics_quality: int (0..2)`, `save()`, `load_settings()`.

### InputSetup — ana oturum
Kodla tanımlanan aksiyonlar: `move_forward, move_back, move_left, move_right, sprint, interact, inventory, build_mode, pause, jump, camera_zoom_in, camera_zoom_out`.

### GameClock — Ajan A (sistemler)
```
signal minute_passed(total_minutes: int)
signal hour_passed(hour: int)
signal phase_changed(phase: StringName)   # &"morning", &"noon", &"evening", &"night"
signal day_started(day: int)
signal season_changed(season: StringName) # &"spring", &"summer", &"autumn", &"winter"
var day: int; var hour: int; var minute: int; var season: StringName; var paused: bool; var time_scale: float
func get_time_string() -> String
func get_day_fraction() -> float          # 0..1, 0 = gece yarısı
func sleep_until_morning() -> void
func advance_minutes(m: int) -> void
```

### Weather — Ajan A
```
signal weather_changed(weather: StringName)  # &"sunny", &"cloudy", &"foggy", &"rainy", &"storm", &"snow"
var current: StringName; var tomorrow: StringName
func get_customer_multiplier() -> float
func is_power_out() -> bool
```

### Economy — Ajan A
```
signal money_changed(money: int)
var money: int
func add(amount: int, reason: String) -> void
func spend(amount: int, reason: String) -> bool   # yetersizse false
func get_day_report() -> Dictionary
```

### Reputation — Ajan A
```
signal reputation_changed(value: float)
signal license_level_changed(level: int)
var reputation: float; var license_level: int; var compliance: float
func add_reputation(v: float) -> void
func record_id_check(done: bool) -> void
```

### Inventory — Ajan A
Eşya = Dictionary: `{ "id": StringName, "kind": StringName, "strain": StringName, "quality": int, "grams": float, "count": int }`
kind: `&"seed", &"wet_bud", &"dry_bud", &"jar", &"preroll", &"paper", &"filter", &"nutrient", &"tool"`
```
signal changed()
func add_item(item: Dictionary) -> void
func remove_item(id: StringName, count: int = 1) -> bool
func count_of(id: StringName) -> int
func get_items(kind: StringName = &"") -> Array[Dictionary]
```

### QuestManager — Ajan C
```
signal quest_started(id: StringName); signal quest_completed(id: StringName)
func start(id: StringName) -> void; func complete(id: StringName) -> void
func is_active(id: StringName) -> bool; func get_active() -> Array[StringName]
func notify_event(event: StringName, data: Dictionary = {}) -> void   # görev hedefi ilerletme
```

### SaveSystem — Ajan A
Her autoload `func get_save_data() -> Dictionary` ve `func load_save_data(d: Dictionary) -> void` sağlar.
Sahnedeki kalıcı düğümler `persist` grubunda ve aynı iki fonksiyonu sağlar (`get_save_id() -> String` de).
```
func save_game() -> void; func load_game() -> bool; func has_save() -> bool; func new_game() -> void
```
Kayıt yolu: `user://save_1.json`.

### Effects — Ajan B (mini oyunlar)
```
signal gafti_mode_changed(active: bool, strength: float)
var gafti_active: bool; var gafti_strength: float   # 0..1
func start_gafti(strength: float, duration_game_minutes: int) -> void
func get_move_multiplier() -> float                 # Gaftî'de 0.85
func get_customer_patience_multiplier() -> float    # Gaftî'de 1.3
func get_rolling_bonus() -> int                     # Gaftî'de +10
func get_water_jitter() -> float                    # Gaftî'de ±0.2
```

### AudioManager — Ajan C
`func play_sfx(id: StringName, pos: Variant = null) -> void`, `func play_music(id: StringName) -> void`, `func set_ambience(id: StringName) -> void`.
Eksik ses dosyasında sessizce geç (hata verme).

## 5. Etkileşim sözleşmesi
- Etkileşilebilir her nesne `interactable` grubunda, bir `Area3D` (layer 4) içerir ve şu fonksiyonları sağlar:
  `func get_interact_text() -> String` ve `func interact(player: Node) -> void`.
- Oyuncu: `scenes/player/player.tscn`, kök `CharacterBody3D`, `player` grubunda.
- Mini oyun sahneleri `CanvasLayer` + `SubViewport` ya da kendi `Camera3D` ile yakın çekim. Mini oyunu
  `scenes/minigames/minigame_host.gd` açar: `EventBus.minigame_requested` dinler, sahneyi yükler, bitince
  `EventBus.minigame_finished` yayar.
- Mini oyun id'leri: `&"rolling"`, `&"gravity_bong"`, `&"care"`, `&"id_check"`, `&"customize"`.

## 6. Sahiplik
| Alan | Sahip |
|---|---|
| `autoload/game_clock, weather, economy, reputation, inventory, save_system` + `scripts/systems/` (bitki, genetik, işleme, inşa) + `scenes/plants/` (plant_visual hariç) + `scenes/stations/` (saksı, kurutma, çaprazlama, su deposu) + `scenes/build/` + `data/strains,items,buildables` | Ajan A (Opus) |
| `autoload/effects` + `scenes/minigames/` (id_check hariç) + `scenes/stations/bong_station*, rolling_station*` + `shaders/gafti_post.gdshader` | Ajan B (Opus) |
| `autoload/audio_manager` + `scenes/player/` + `scenes/ui/` (dialogue hariç) + `scenes/stations/bed*, mirror*` | Ajan C (Opus) |
| `autoload/quest_manager` + `scenes/npc/` + `scenes/shop/` + `scenes/ui/dialogue/` + `scenes/minigames/id_check/` + `scripts/town/` + `data/customers,quests,dialogue` | Ajan D (Opus) |
| `scenes/world/` (vadi montajı), `localization/strings.csv` birleştirme | Ana oturum |
| `assets/models/hero/`, `assets/logo/`, `shaders/` (toon, foliage, fog) | Codex astra |
| `assets/models/props/`, `assets/models/town/`, `assets/models/characters/npc_*` | Codex sol |

## 7. Model dosya sözleşmesi (Blender → .glb)
- Ölçek: 1 birim = 1 metre, +Y yukarı (glTF), orijin tabanın ortasında.
- Script: `tools/blender/<ad>.py` → çıktı `assets/models/<klasör>/<ad>.glb`. Script tekrar çalıştırılabilir olmalı.
- Stil: detaylı stilize; yumuşak bevel, abartılı oranlar, el boyaması hissi veren vertex color/basit dokular, düşük üçgen sayısı.
- Bütçe: bitki aşaması ≤4k üçgen, prop ≤2k, karakter ≤12k, bina ≤8k.
- Animasyonlu modellerde aksiyon isimleri: `idle, walk, run, interact, sit` vb. (küçük harf).

## 8. Model listesi (dosya adları sabit)
Mesh düğüm adları önemli: kod bunlara göre materyal/görünürlük ayarlar.

### Codex astra → `assets/models/hero/`
| Dosya | İçerik / düğüm adları |
|---|---|
| `plant_germ.glb`, `plant_seedling.glb`, `plant_veg.glb`, `plant_flower.glb`, `plant_harvest.glb` | Saksısız bitki. Düğümler: `Stem`, `Leaves`, `Buds` (germ/seedling'de Buds yok). Vertex color + yaprak maskesi (UV.y = kökten uca 0..1, rüzgâr için). Boylar: 0.08 / 0.25 / 0.7 / 1.1 / 1.2 m |
| `bong_bucket.glb` | Kova + su yüzeyi. Düğümler: `Bucket`, `Water` |
| `bong_bottle.glb` | Kesik pet şişe + kapak-kase. Düğümler: `Bottle`, `Cap`, `Bowl`. Orijin şişenin altı |
| `lighter.glb` | Çakmak. Düğümler: `Body`, `Wheel` |
| `grinder.glb` | Düğümler: `Base`, `Lid` (Lid kendi ekseninde döner, orijini merkezde) |
| `rolling_paper.glb` | Düz kağıt, `Paper` (sarılma için ≥24 enine segment) |
| `filter_tip.glb` | `Filter` |
| `joint.glb` | Bitmiş joint, `Joint` |
| `rolling_tray.glb` | Sarma tepsisi, `Tray` |
| `character_base.glb` | Rigli oyuncu. Armatür `Armature`, gövde `Body`. Seçmeli parçalar aynı armatüre bağlı: `Hair_01..Hair_06`, `Beard_00..Beard_04` (00 = yok, boş), `Hat_Kasket`, `Top_Raincoat`, `Top_Sweater`, `Top_Shirt`, `Pants_01`, `Boots_Rubber`. Animasyonlar: `idle, walk, run, interact, sit, roll, smoke, faint, wave` |
| `greenhouse.glb` | Ahşap + cam yayla serası, iç ölçü ~12×6 m, kapı +Z yönünde. İçeride saksı tezgahları. `Glass` düğümü ayrı (şeffaf materyal) |
| `house.glb` | Dedenin ahşap Karadeniz evi (dış + basit iç: yatak, ayna, kanepe) |

### Codex sol → `assets/models/props/` ve `assets/models/town/`
props: `pot.glb, grow_lamp.glb, shelf_shop.glb, counter.glb, cash_register.glb, drying_rack.glb, jar.glb, rolling_table.glb, generator.glb, water_tank.glb, watering_can.glb, fence.glb, spruce_tree.glb, tea_bush.glb, rock_01.glb, rock_02.glb, bench.glb, lamp_post.glb, sofa.glb, mirror.glb, bed.glb, crate.glb, tavla_table.glb`
town: `shop_building.glb` (GAFTİ dükkanı, girilebilir, iç ~8×6 m), `kahvehane.glb`, `muhtarlik.glb`, `hardware_store.glb`, `inspection_office.glb`, `bus_stop.glb`, `minibus.glb`, `drying_barn.glb`, `bridge.glb`, `terrain.glb`

## 9. Vadi yerleşimi (Godot koordinatları, metre, Y yukarı)
Arazi 260×260 m, merkez (0,0,0). Düz alanlar (pad) arazide bu noktalarda olmalı:
| Bölge | Merkez (x, z) | Yükseklik y | Pad yarıçapı |
|---|---|---|---|
| Oyuncu başlangıcı / ev önü | (-62, 28) | 2 | — |
| Ev | (-70, 40) | 2 | 14 (ev+sera+tarla tek pad) |
| Sera | (-55, 30) | 2 | (aynı pad) |
| Dış tarla | (-45, 48) | 2 | (aynı pad) |
| Kurutma ambarı | (-78, 22) | 2 | (aynı pad) |
| Kasaba meydanı | (60, 0) | 0 | 22 |
| GAFTİ Dükkanı | (60, -14) | 0 | (meydan) |
| Kahvehane | (46, 8) | 0 | (meydan) |
| Muhtarlık | (74, 8) | 0 | (meydan) |
| Denetim ofisi | (78, -8) | 0 | (meydan) |
| Hırdavatçı | (42, -10) | 0 | (meydan) |
| Minibüs durağı | (72, 48) | 0 | 6 |
| Köprü & dere | (5, -45) | -1 | dere x yönünde değil, (−130,−60)→(130,−35) boyunca akar |
| Ladin ormanı | (-45, -70) çevresi | — | ağaçlar |
| Keklik Tepe zirvesi | (0, -110) | 28 | 6 |
Yol: Ev padinden (-50, 25) → (0, 10) → meydan (40, 0); meydandan durağa (72, 48); meydandan köprüye (5,-45) → tepeye patika.
Arazide yol düğümü `Road` (ayrı materyal), zemin `Ground`, dere yatağı `Creek`. Arazi kenarları dağlarla kapalı (oyuncu çıkamaz).
