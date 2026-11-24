# GAFTİ · Kasaba ve vadi teslimi

`tools/blender/town.py` dokuz kasaba modelini, `tools/blender/terrain.py` vadiyi üretir. Modeller `assets/models/town/`, 512 × 512 Eevee önizlemeleri `tools/previews/` altında yer alır. Her GLB için aynı adlı bir PNG ve arazi için ayrıca 15 konumun işaretlendiği `terrain_top.png` bulunur.

## GLB düğümleri ve üçgen sayıları

Üçgen sayıları GLB içindeki görsel geometriyi ve çarpışma geometrisini kapsar.

| Dosya | Üçgen | Görsel mesh düğümleri | Çarpışma düğümleri |
|---|---:|---|---|
| `shop_building.glb` | 7453 | `Canopy`, `Ceiling`, `Chimney`, `Cladding`, `Doorframe`, `Fascia`, `Floor`, `Floorboards`, `Frame`, `Gables`, `Lanterns`, `Roof`, `Roof seams`, `Sign`, `Stonework`, `Threshold`, `Walls`, `Windows` | `Ceiling-col`, `Shell-col`, `Threshold-col` |
| `kahvehane.glb` | 7810 | `Canopy`, `Ceiling`, `Chimney`, `Cladding`, `Doorframe`, `Fascia`, `Floor`, `Floorboards`, `Frame`, `Gables`, `Porch`, `Roof`, `Roof seams`, `Shutters`, `Sign`, `Stonework`, `Threshold`, `Walls`, `Windows` | `Ceiling-col`, `Porch-col`, `Shell-col`, `Threshold-col` |
| `muhtarlik.glb` | 6289 | `Banner`, `Ceiling`, `Cladding`, `Doorframe`, `Fascia`, `Floor`, `Floorboards`, `Frame`, `Gables`, `Roof`, `Roof seams`, `Shutters`, `Sign`, `Stonework`, `Threshold`, `Walls`, `Windows` | `Ceiling-col`, `Shell-col`, `Threshold-col` |
| `hardware_store.glb` | 6419 | `Ceiling`, `Cladding`, `Crates`, `Doorframe`, `Fascia`, `Floor`, `Floorboards`, `Frame`, `Gables`, `Lanterns`, `Roof`, `Roof seams`, `Sign`, `Stonework`, `Threshold`, `Walls`, `Windows` | `Ceiling-col`, `Crates-col`, `Shell-col`, `Threshold-col` |
| `inspection_office.glb` | 6844 | `Ceiling`, `Cladding`, `Doorframe`, `Fascia`, `Floor`, `Floorboards`, `Frame`, `Gables`, `Lanterns`, `Roof`, `Roof seams`, `Sign`, `Stonework`, `Threshold`, `Walls`, `Windows` | `Ceiling-col`, `Shell-col`, `Threshold-col` |
| `bus_stop.glb` | 2586 | `Back wall`, `Bench`, `Fascia`, `Footings`, `Frame`, `Platform`, `Roof`, `Roof seams`, `Sign`, `Timetable` | `Back-col`, `Bench-col`, `Ceiling-col`, `Shell-col` |
| `minibus.glb` | 5514 | `Beltline`, `Body`, `Bumpers`, `Grille`, `Lights`, `Mirrors`, `Roof rack`, `Sign`, `Trim`, `Wheel arches`, `Wheels`, `Windows`, `Wipers` | `Body-col` |
| `drying_barn.glb` | 5410 | `Ceiling`, `Cladding`, `Doorframe`, `Fascia`, `Floor`, `Floorboards`, `Frame`, `Gables`, `Roof`, `Roof seams`, `Shutters`, `Stonework`, `Threshold`, `Vents`, `Walls`, `Windows` | `Ceiling-col`, `Shell-col`, `Threshold-col` |
| `bridge.glb` | 7896 | `Arch`, `Cobbled deck`, `End piers`, `Lichen`, `Parapets`, `Spandrel`, `Voussoirs` | `Arch-col`, `Deck-col`, `Parapets-col` |
| `terrain.glb` | 47830 | `Creek`, `Ground`, `Road`, `Water` | `Ground-col` |

## Yerleşim ve doğrulama

- GAFTİ dükkânının duvarlar arasındaki net ölçüsü 8 × 6 m. +Z cephesi 1,84 m açıklığa sahip ve ahşap döşeme düz. İç mekân ayrı raf ve tezgâh yerleşimine hazır.
- Arazi X ve Z eksenlerinde −130 ile 130 m arasında uzanıyor. Blender `(x, y, z)` koordinatları GLB'de `(x, z, -y)` olarak doğrulandı. Çiftlik noktaları +2 m'deki tek terasa bağlandı. Meydan ve durak 0 m, Keklik Tepe düzlüğü 28 m. Belirtilen yol geçiş noktaları GLB'nin `Road` yüzeyinde sorgulandı.
- Köprü Godot `(5, -1, -45)` konumunda Z doğrultusunda yerleşir. Taş kemerin iki rampa ucu çevredeki 0 m düzlükle birleşir. Dere tabanı köprü merkezinde −1 m, düz su yüzeyi −0,69 m. Dere, sözleşmedeki iki uçtan geçer.
- Godot 4.7.2 ile on GLB geçici bir test projesinde içe aktarıldı. Fizik ışınları bina girişlerini, arka ve yan duvarları, iç zeminleri, köprü açıklığını ve güvertesini, düz alanların çevrelerinde 72'şer örneği ve arazi sınırlarını doğruladı. Sonuç 0 hata.
- Bütün önizlemeler görsel olarak incelendi. Çatı kadrajları, minibüsün ön renk ayrımı ve arazinin renk geçişleri inceleme sonrası düzeltildi.

## Bilinen sınırlar

- Minibüs statik bir model. Tekerlek dönüşü ve kapı animasyonu yok. Bina camları opak.
- Su düz ve statik bir yüzey. Ladin ormanı bölgesindeki ağaç yerleşimi ve binaların sahneye montajı dünya sahnesinin entegrasyonuna ait.
- Doğrulama, Godot'un varlık içe aktarma ve fizik kontrollerini kapsıyor. Tam oyun sahnesinde karakterle oynanış kontrolü yapılmadı.

## Yeniden üretim

Proje kökünden çalıştırın.

```powershell
powershell -ExecutionPolicy Bypass -File tools/blender/run_blender.ps1 -Script C:/Users/31/Documents/we2/tools/blender/town.py
powershell -ExecutionPolicy Bypass -File tools/blender/run_blender.ps1 -Script C:/Users/31/Documents/we2/tools/blender/terrain.py
```
