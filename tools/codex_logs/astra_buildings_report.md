# GAFTİ · Dedenin serası ve evi

| Model | Çarpışma dahil üçgen | Net kapı açıklığı (en × boy) | Blender Eevee önizlemesi |
|---|---:|---|---|
| [greenhouse.glb](../../assets/models/hero/greenhouse.glb) | 6.302 | 1,84 × 2,41 m | [greenhouse.png](../previews/greenhouse.png) |
| [house.glb](../../assets/models/hero/house.glb) | 7.928 | 1,74 × 2,28 m | [house.png](../previews/house.png) |

Her iki modelin girişi Godot yerel +Z yönüne bakar. Orijin tabanın merkezinde, yürüme düzlemi Y = 0 m'dedir. Ölçek 1 birim = 1 metredir. [buildings_hero.py](../blender/buildings_hero.py) iki GLB'yi ve 512 × 512 px önizlemelerini yeniden üretir.

## Sera ve saksı yerleşimi

Duvar çarpışmalarının iç yüzleri arasında X boyunca 12,00 m, Z boyunca 6,00 m vardır. Her tezgâhın üst yüzeyi 9,80 × 1,015 m'dir. Ön tezgâhın merkezi (0, 0.80, 0.78), arka tezgâhın merkezi (0, 0.80, -1.77) konumundadır. Saksı tabanları için yerel Godot koordinatları metre cinsinden aşağıdadır.

| Saksı | FrontBench (X, Y, Z) | RearBench (X, Y, Z) |
|---|---|---|
| 1 | (-4.00, 0.80, 0.78) | (-4.00, 0.80, -1.77) |
| 2 | (-2.40, 0.80, 0.78) | (-2.40, 0.80, -1.77) |
| 3 | (-0.80, 0.80, 0.78) | (-0.80, 0.80, -1.77) |
| 4 | (0.80, 0.80, 0.78) | (0.80, 0.80, -1.77) |
| 5 | (2.40, 0.80, 0.78) | (2.40, 0.80, -1.77) |
| 6 | (4.00, 0.80, 0.78) | (4.00, 0.80, -1.77) |

**Sera düğümleri** — Floor, FrontBench, Glass, MossyFooting, NurserySign, PaneRepairs, PendantLamps, RearBench, RoofVent, SlidingDoor, TimberFrame. Glass ayrı, çift taraflı ve 0,22 alfa değerli bir mesh'tir. Sürgü kapı açık konumdadır.

**Ev düğümleri** — Balcony, Bed, Chimney, Floor, HippedRoof, Joinery, LowerWalls, Mirror, PorchLamp, RoofSeams, Sofa, Stonework, UpperStorey, WindowBoxes. Oynanabilir tek oda taş zemin kattadır. Yatak arka solda, kanepe arka sağda, ayna sağ duvardadır.

**Ortak çarpışma düğümleri** — Floor-col, WestWall-col, EastWall-col, FrontWest-col, FrontEast-col, RearWall-col, Lintel-col. Serada ayrıca FrontBench-col ve RearBench-col, evde Bed-col ve Sofa-col bulunur. Her biri 12 üçgenli kutu geometrisidir.

## Doğrulama ve kapsam

Her iki Eevee renderı görsel olarak incelendi. Üçgen sayıları dışa aktarılan GLB indekslerinden hesaplandı. Modeller yalıtılmış bir Godot 4.7.2 projesine içe aktarıldı. Motor her binada dokuz CollisionShape3D üretti. Fizik ışınları her iki girişte üç genişlik konumu ve üç yükseklikte serbest geçişi, bitişik duvarlarda çarpışmayı ve 12 saksı merkezinde Y = 0,80 m tezgâh yüksekliğini doğruladı.

Balkon ve üst kat dış cephe dekorudur. Sürgü kapı, havalandırma kanadı ve mobilyalar statiktir. Vadi yerleşimi ve oyuncu kamerasıyla yürüyüş testi entegrasyon aşamasına aittir.
