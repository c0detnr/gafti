# GAFTİ | Kova ve sarma seti

Üretici betik `tools/blender/paraphernalia.py`. Blender 5.3 ile proje sarmalayıcısından çalıştırılır. Ölçek metredir. GLB dosyaları +Y yukarı ekseniyle dışa aktarılır. Materyaller ve sarma kâğıdının lif dokusu dosyaların içindedir.

| Model | Mesh düğümleri | GLB üçgen sayısı | 512 × 512 Eevee önizlemesi |
|---|---|---:|---|
| [bong_bucket.glb](../../assets/models/hero/bong_bucket.glb) | Bucket, Water | 1924 | [Kova](../previews/bong_bucket.png) |
| [bong_bottle.glb](../../assets/models/hero/bong_bottle.glb) | Bottle, Cap, Bowl | 1934 | [Şişe](../previews/bong_bottle.png) |
| [lighter.glb](../../assets/models/hero/lighter.glb) | Body, Wheel | 992 | [Çakmak](../previews/lighter.png) |
| [grinder.glb](../../assets/models/hero/grinder.glb) | Base, Lid | 1471 | [Öğütücü](../previews/grinder.png) |
| [rolling_paper.glb](../../assets/models/hero/rolling_paper.glb) | Paper | 1984 | [Sarma kâğıdı](../previews/rolling_paper.png) |
| [filter_tip.glb](../../assets/models/hero/filter_tip.glb) | Filter | 174 | [Filtre](../previews/filter_tip.png) |
| [joint.glb](../../assets/models/hero/joint.glb) | Joint | 1354 | [Bükülmüş uç](../previews/joint.png) |
| [rolling_tray.glb](../../assets/models/hero/rolling_tray.glb) | Tray | 628 | [Yayla motifli tepsi](../previews/rolling_tray.png) |

Kâğıt 90 × 43 mm ve 32 × 31 segmenttir. Öğütücü kapağı GLB içinde kapalı konumda, kendi merkezi çevresinde döner. Önizlemede dişleri göstermek için kapağı yana aldım. Şişe orijini kesik tabanın merkezindedir.

## Duman efektleri

- [smoke.gdshader](../../shaders/smoke.gdshader) kameraya bakan parçacıklara hareketli gürültü kenarı ve ömre bağlı büyüme, belirme ve sönme verir. Renk `smoke_color`, yoğunluk `alpha` ile ayarlanır.
- [smoke_fx.tscn](../../scenes/minigames/gravity_bong/smoke_fx.tscn) kökü `SmokeFX`, türü `GPUParticles3D`, miktarı 42. Şişe tabanına sıfır yerel dönüşümle bağlanır. `emitting` ile başlatılıp durdurulur ve parçacıklar şişeyle birlikte hareket eder.
- [exhale_fx.tscn](../../scenes/minigames/gravity_bong/exhale_fx.tscn) kökü `ExhaleFX`, türü `GPUParticles3D`, miktarı 30. Ağız konumundan yerel −Z yönüne tek atımlık bulut çıkarır. Tekrar oynatmak için `restart()` çağrılır.

## Doğrulama ve sınırlar

Sekiz nihai PNG görsel olarak incelendi. Üçgen sayıları ve düğüm adları dışa aktarılan GLB verisinden okundu. Sekiz GLB ayrı bir test projesinde Godot 4.7.2 ile içe aktarıldı. Her iki parçacık sahnesi aynı sürümde Vulkan Mobile ile çalıştırıldı ve parçacık yayımı açıldı. Bu kontrollerde motor veya shader hatası görülmedi.

Mini oyunun kendi kamerasındaki saydam yüzey sıralaması ve fiziksel Android cihazdaki performans doğrulanmadı.
