# sol_audio teslim raporu

40 istenen sesin 34’ü üretildi. Teslimde 22 Kenney efekti, 6 ortam döngüsü ve OpenGameArt’tan 6 müzik parçası var. Tüm sesler Ogg Vorbis biçiminde ve kaynak lisansları CC0 1.0. [Dosya bazında kaynaklar](../../assets/audio/CREDITS.md)

Bu görev ses varlıklarını kapsadığı için sahne düğümü veya Blender önizlemesi üretilmedi.

## Üretilen dosyalar

Yollar `assets/audio/` dizinine göredir.

| Dosya | Süre (sn) | Godot döngüsü |
|---|---:|---|
| `sfx/cash_register.ogg` | 0,79 | Kapalı |
| `sfx/coin.ogg` | 0,85 | Kapalı |
| `sfx/door_close.ogg` | 0,68 | Kapalı |
| `sfx/door_open.ogg` | 0,92 | Kapalı |
| `sfx/footstep_grass_1.ogg` | 0,78 | Kapalı |
| `sfx/footstep_grass_2.ogg` | 0,67 | Kapalı |
| `sfx/footstep_grass_3.ogg` | 0,69 | Kapalı |
| `sfx/footstep_grass_4.ogg` | 0,67 | Kapalı |
| `sfx/footstep_wood_1.ogg` | 0,25 | Kapalı |
| `sfx/footstep_wood_2.ogg` | 0,25 | Kapalı |
| `sfx/footstep_wood_3.ogg` | 0,25 | Kapalı |
| `sfx/footstep_wood_4.ogg` | 0,25 | Kapalı |
| `sfx/grinder.ogg` | 0,52 | Kapalı |
| `sfx/harvest_snip.ogg` | 0,57 | Kapalı |
| `sfx/lighter_flick.ogg` | 0,45 | Kapalı |
| `sfx/notify_bad.ogg` | 0,10 | Kapalı |
| `sfx/notify_good.ogg` | 0,54 | Kapalı |
| `sfx/paper_rustle.ogg` | 0,43 | Kapalı |
| `sfx/plant_place.ogg` | 0,94 | Kapalı |
| `sfx/ui_click.ogg` | 0,10 | Kapalı |
| `sfx/ui_close.ogg` | 0,15 | Kapalı |
| `sfx/ui_open.ogg` | 0,15 | Kapalı |
| `ambience/birds_loop.ogg` | 24,95 | Açık |
| `ambience/cafe_murmur_loop.ogg` | 40,05 | Açık |
| `ambience/creek_loop.ogg` | 28,05 | Açık |
| `ambience/night_crickets_loop.ogg` | 31,05 | Açık |
| `ambience/rain_loop.ogg` | 20,63 | Açık |
| `ambience/wind_loop.ogg` | 21,56 | Açık |
| `music/day_1.ogg` | 129,33 | Kapalı |
| `music/day_2.ogg` | 97,22 | Açık |
| `music/evening.ogg` | 76,80 | Açık |
| `music/gafti.ogg` | 131,72 | Kapalı |
| `music/menu.ogg` | 124,10 | Açık |
| `music/night.ogg` | 234,98 | Kapalı |

## Godot içe aktarma

Altı ortam kaydı döngü başlangıcı ile sonu arasında çapraz geçişle kurgulandı. Bu dosyalarda ve döngü sürümü kullanılan `menu`, `day_2`, `evening` parçalarında `Loop` açık, `Loop Offset` 0. Bu ayarlar ilgili `.ogg.import` dosyalarında kayıtlıdır.

Godot’ta bir ayarı yeniden uygulamak için `.ogg` varlığını seç, **Import** sekmesinde **Loop** seçeneğini aç, **Loop Offset** değerini 0 olarak bırak ve **Reimport** düğmesine bas. Efektler tek tetiklemelidir.

## Doğrulama

- FFprobe 34 dosyanın tamamında birer Vorbis akışı ve pozitif süre bildirdi. FFmpeg her dosyayı sonuna kadar hatasız çözdü.
- Godot 4.7.2, ayrı bir geçici projede 34 varlığı `AudioStreamOggVorbis` olarak yükledi ve 9 döngü ayarını doğruladı. Oyun içi ses miksajı bu kontrolün kapsamı dışındaydı.

## Bilinen eksikler ve kaynak seçimleri

- **EKSİK** `water_pour`, `lick`, `bubble`, `inhale`, `cough`, `thunder`. İncelenen Kenney paketlerinde bu olaylar için uygun ve erişilebilir CC0 kayıt doğrulanamadı.
- `grinder` metal sürtünme seslerinden, `cash_register` mandal ve zil seslerinden kurgulandı. `paper_rustle`, `lighter_flick`, `harvest_snip` ve `plant_place` sırasıyla sayfa, metal tıkı, kısa kesme ve kap yerleştirme kayıtlarını kullanır.
- Ortam seslerinde Freesound’un HQ önizleme dosyaları kullanıldı. `rain_loop` bir araç tavanına vuran yağmur kaydından alındı.
- `night` ve `gafti` için OpenGameArt’ın oynatıcı dosyaları kullanıldı. Müzik seçiminde akustik gitar, lo-fi ve yumuşak piyano öne çıkıyor. GDD’deki kemençe dokusu kaynak seçiminde karşılanamadı.
