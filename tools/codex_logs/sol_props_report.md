# GAFTİ · sol_props raporu

`tools/blender/props.py`, AGENTS.md §8’deki 23 propun tamamını metre ölçeğinde ve glTF +Y yukarı ekseniyle üretir. Her dosyanın kök düğümü dosya adını taşır ve model tabanı Y=0 düzlemindedir. Saksı 0,30 m çapında, tezgâh 0,90 m, mağaza rafı 1,77 m yüksekliğindedir.

## Dosyalar ve düğümler

GLB’ler `assets/models/props/`, 512 × 512 Eevee önizlemeleri `tools/previews/` altındadır. Üçgen sayısına `-col` geometrisi dahildir.

| GLB | Önizleme | Mesh düğümleri | Üçgen |
| --- | --- | --- | ---: |
| `pot.glb` | `pot.png` | `Pot`, `Soil` | 996 |
| `grow_lamp.glb` | `grow_lamp.png` | `Bulb`, `Shade` | 1136 |
| `shelf_shop.glb` | `shelf_shop.png` | `Shelf`, `Shelf-col` | 1508 |
| `counter.glb` | `counter.png` | `Counter`, `Counter-col` | 706 |
| `cash_register.glb` | `cash_register.png` | `Register` | 1172 |
| `drying_rack.glb` | `drying_rack.png` | `DryingRack`, `DryingRack-col` | 1508 |
| `jar.glb` | `jar.png` | `Glass`, `Label`, `Lid` | 1122 |
| `rolling_table.glb` | `rolling_table.png` | `RollingTable` | 632 |
| `generator.glb` | `generator.png` | `Generator`, `Generator-col` | 908 |
| `water_tank.glb` | `water_tank.png` | `Tank`, `Tank-col` | 1644 |
| `watering_can.glb` | `watering_can.png` | `Can` | 920 |
| `fence.glb` | `fence.png` | `Fence`, `Fence-col` | 388 |
| `spruce_tree.glb` | `spruce_tree.png` | `Needles`, `Trunk`, `Trunk-col` | 1398 |
| `tea_bush.glb` | `tea_bush.png` | `Branches`, `Foliage` | 1392 |
| `rock_01.glb` | `rock_01.png` | `Rock`, `Rock-col` | 172 |
| `rock_02.glb` | `rock_02.png` | `Rock`, `Rock-col` | 172 |
| `bench.glb` | `bench.png` | `Bench` | 672 |
| `lamp_post.glb` | `lamp_post.png` | `Bulb`, `Post` | 1080 |
| `sofa.glb` | `sofa.png` | `Sofa`, `Sofa-col` | 1152 |
| `mirror.glb` | `mirror.png` | `Frame`, `Glass` | 321 |
| `bed.glb` | `bed.png` | `Bed`, `Bed-col`, `Quilt` | 1372 |
| `crate.glb` | `crate.png` | `Crate` | 988 |
| `tavla_table.glb` | `tavla_table.png` | `Pieces`, `TavlaTable` | 1580 |

## Doğrulama

- `tools/previews/props_sheet.png` tüm modelleri gösterir. İlk Eevee incelemesinden sonra ahşap damarları, kumaş, çay yaprakları ve kaya yosunu işlendi.
- Dışa aktarılan GLB’lerde düğüm adları, PBR malzemeler, taban hizası ve üçgen sayıları doğrulandı. `grow_lamp.glb` içindeki `Bulb` sıcak emissive malzeme, `jar.glb` içindeki `Glass` yarı saydam malzeme kullanır. Mantar kapak `Lid` düğümündedir.
- Yalıtılmış Godot 4.7.2 projesi 23 GLB’yi yükledi, 11 `-col` düğümünden statik çarpışma şekli oluşturdu ve çarpışma mesh’lerinin saydam malzemesini doğruladı. İstenen nesnelere ek olarak kurutma rafına da çarpışma eklendi.

## Bilinen sınırlar

- Lambalar emissive yüzey taşır. Çevreyi aydınlatacak ışık düğümü sahne entegrasyonunda eklenebilir.
- Ayna, metalik PBR yüzeyle cam görünümü verir. Sahnenin ayna yansıması için ayrıca yansıma kurulumu gerekir.
- Çarpışma mesh’leri basitleştirilmiştir. Örneğin rafın gözleri ve çitin ray aralıkları tek dış çarpışma hacmine dahildir.

## Yeniden üretim

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\blender\run_blender.ps1 -Script (Resolve-Path .\tools\blender\props.py).Path
```
