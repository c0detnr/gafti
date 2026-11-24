Sera ve ev tamamlandı. Her iki model de çarpışma geometrisi dahil **8.000 üçgen sınırının altında**.

| Model | Üçgen | +Z giriş genişliği | 512 px önizleme |
|---|---:|---:|---|
| [Sera](assets/models/hero/greenhouse.glb) | 6.302 | 1,84 m | [Sera renderı](tools/previews/greenhouse.png) |
| [Ev](assets/models/hero/house.glb) | 7.928 | 1,74 m | [Ev renderı](tools/previews/house.png) |

İki Eevee önizlemesini görsel olarak inceledim. Godot 4.7.2 fizik testinde her iki girişin açık olduğunu, bitişik duvarların çarpışma verdiğini ve seradaki 12 saksı konumunun tamamında tezgâh yüksekliğinin **0,80 m** olduğunu doğruladım.

Evin girilebilir odası taş zemin katta. Balkon ve ahşap üst kat dekoratif. Vadi içinde oyuncu kamerasıyla yürüyüş testi entegrasyon aşamasına kaldı.

[Üretim betiği](tools/blender/buildings_hero.py) · [Düğüm adları, saksı koordinatları ve doğrulama raporu](tools/codex_logs/astra_buildings_report.md)