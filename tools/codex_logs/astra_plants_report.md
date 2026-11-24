# GAFTİ bitki görselleri

Beş saksısız modelin taban merkezi orijindir. glTF uzayında yukarı yön +Y, uzunluk birimi metredir. Her aşama için Blender Eevee ile 512 × 512 piksel önizleme alındı ve görüntüler incelendi.

| Model (assets/models/hero/) | Önizleme (tools/previews/) | Boy | LOD0 üçgen | LOD1 üçgen¹ | Mesh düğümleri |
|---|---|---:|---:|---:|---|
| plant_germ.glb | plant_germ.png | 0,08 m | 204 | 102 | Stem, Leaves |
| plant_seedling.glb | plant_seedling.png | 0,25 m | 556 | 278 | Stem, Leaves |
| plant_veg.glb | plant_veg.png | 0,70 m | 3.014 | 630 | Stem, Leaves, Buds |
| plant_flower.glb | plant_flower.png | 1,10 m | 3.484 | 820 | Stem, Leaves, Buds |
| plant_harvest.glb | plant_harvest.png | 1,20 m | 3.646 | 697 | Stem, Leaves, Buds |

¹ Godot her mesh için uzaklık seviyesini ayrı seçer. Değer, üç parçanın her birinde ilk sadeleştirme seviyesi seçildiğindeki toplamdır. Vejetatif aşamadaki Buds, gövdenin ucundaki küçük kapalı sürgündür.

## Dosyalar ve kullanım

- `tools/blender/plants.py` beş GLB ve karşılık gelen PNG dosyalarını üretir. Kamera, stüdyo ışıkları ve zemin yalnızca önizlemede kullanılır.
- `scenes/plants/plant_visual.tscn` kökü PlantVisual olan Node3D sahnesidir. Alt sahneler sırasıyla Germ, Seedling, Veg, Flower ve Harvest adını taşır.
- `scenes/plants/plant_visual.gd` üzerindeki `set_stage(i)` 0–4 aşamalarından birini görünür kılar. `set_health(v)`, `set_thirst(v)` ve `set_quality(v)` 0–1 aralığı kullanır. Materyaller her bitki örneğine özeldir.
- `shaders/foliage_wind.gdshader` gövdeyi sabit tutar. Yaprak uçlarında rüzgâr salınımı ve susuzluk sarkması artar. COLOR_0.r rüzgâr ağırlığını, .g boyalı ton farkını, .b yaprak damarı veya turuncu tüy vurgusunu taşır. TEXCOORD_0.y yaprakçık dibinde 0, ucunda 1’dir. Oyun paletini sahnenin materyal override’ı uygular.
- `shaders/toon.gdshader` genel prop yüzeyleri için üç kademe ışık, kenar ışığı, albedo dokusu, renk ve isteğe bağlı vertex color sağlar.
- `shaders/fog_layer.gdshader` yatay bir mesh üzerinde dünya koordinatlarında kayan iki ölçekli gürültü kullanır. 0–1 UV alanının kenarlarında sis saydamlaşır.
- `scenes/plants/plant_lod_import.gd` ve beş `assets/models/hero/plant_*.glb.import` dosyası ilk sadeleştirme seviyesinin üçgen bütçesini uygular. Bu işlem Godot editöründe içe aktarım sırasında çalışır.

## Doğrulama ve sınırlar

GLB dosyalarından düğüm adları, taban ve tepe yüksekliği, üçgen sayıları, UV uç değerleri ve rüzgâr ağırlıkları okundu. Önizlemelerde dal uçlarındaki genç yapraklar, tomurcuk silueti ve yaprak damarları görsel inceleme sonrası düzeltildi.

Teslim edilen kaynakların yalıtılmış kopyası Godot 4.7.2 ile temiz içe aktarıldı. Aşama görünürlüğü, materyal atamaları, hazır olmadan verilen değerler, parametre sınırları ve iki bitkinin materyal bağımsızlığı sınandı. Üç shader Windows üzerinde Intel UHD Graphics ve Vulkan Forward Mobile ile çizildi.

Fiziksel Android cihazda kare süresi ve tam vadi sahnesindeki görünüm ölçülmedi. Yeni autoload veya giriş aksiyonu gerekmiyor.
