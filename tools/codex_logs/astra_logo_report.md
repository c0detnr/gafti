# GAFTİ logo, ikon ve tema teslimi

| Konum | Dosyalar |
|---|---|
| `assets/logo/` | `gafti_logo.svg`, `gafti_logo_1024.png` (1024 × 416), `icon.svg` (512 × 512), `icon_512.png`, `icon_192.png`, `README.md` |
| `assets/fonts/` | `Baloo2.ttf`, `Baloo2-OFL.txt`, `Nunito.ttf`, `Nunito-OFL.txt` |
| `assets/ui/` | `gafti_theme.tres`, `slider_knob.svg`, `slider_knob_active.svg`, `slider_knob_disabled.svg`, `toggle_on.svg`, `toggle_off.svg` |
| `tools/previews/` | `logo_wordmark.png`, `logo_icon.png` (her biri 512 × 512) |

## Vektör grupları ve tema

Logo SVG’sinde ön yüz grupları harf sırasıyla `G`, `A`, `F`, `T`, `I` ve `Leaf` adlarını taşır. İkon `G` ve `Leaf` gruplarını kullanır. Son harfin turuncu yaprağı Türkçe İ’nin noktasını oluşturur. Harflerin tamamı vektör yoldur.

Varsayılan arayüz fontu 20 px Nunito’dur. Başlık için Label düğümünün `theme_type_variation` özelliğine `GaftiHeading` verilince 36 px Baloo 2 kullanılır. Her iki değişken font da özgün SIL Open Font License dosyasıyla teslim edildi. [Baloo 2 kaynağı](https://github.com/google/fonts/tree/main/ofl/baloo2) · [Nunito kaynağı](https://github.com/google/fonts/tree/main/ofl/nunito)

Tema Button, Panel, PanelContainer, Label, ProgressBar, LineEdit, HSlider, CheckButton, TabContainer ve ItemList denetimlerini kapsar.

## Doğrulama ve kapsam

Godot 4.7.2’de temiz bir geçici projeye içe aktarılan tema ve iki SVG yüklendi. Temadaki StyleBox adları motorun varsayılan temasındaki karşılıklarıyla denetlendi. Boş Button’ın ölçülen asgari yüksekliği 56 px. Her iki fontta da Çç, Ğğ, İı, Öö, Şş ve Üü glifleri doğrulandı.

Python ile SVG’lerden RGBA PNG üretildi. Logo açık ve koyu zeminlerde, ikon 320, 96, 48 ve 24 px boyutlarında görsel olarak incelendi. Dış kontur ve logo çevresindeki şeffaf boşluk bu kontrolde düzeltildi.

Teslim edilen varlıklarda bilinen eksik yok. Tema doğrulaması bağımsız test projesinde yapıldı. Ana oyundaki menü yerleşimi ve fiziksel cihaz görünümü test kapsamı dışındadır.
