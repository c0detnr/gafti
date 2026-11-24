GOREV=astra_logo
İŞ: GAFTİ logosu, uygulama ikonu ve UI teması.
1. assets\logo\gafti_logo.svg: esprili, çizgi film tarzı yazı logosu. Kalın, yuvarlak, hafif zıplayan harfler "GAFTİ". "İ" harfinin noktası küçük bir kenevir yaprağı ya da kıvrımlı duman bulutu. Renkler: yeşil tonlar + sıcak turuncu vurgu, koyu kontur ve hafif gölge; hem koyu hem açık zeminde okunur. Harfleri fonta bağımlı olmadan path olarak çiz.
2. assets\logo\icon.svg: 512x512 kare uygulama ikonu (yuvarlatılmış kare zemin, "G" + yaprak/duman motifi). Küçükte de net.
3. PNG: assets\logo\gafti_logo_1024.png, assets\logo\icon_512.png, assets\logo\icon_192.png (Inkscape yoksa Blender'da SVG import + render ya da Python ile dönüştür).
4. Font: Türkçe karakter destekli OFL lisanslı yuvarlak bir başlık fontu (ör. Fredoka veya Baloo 2, Google Fonts GitHub deposundan) ve okunaklı gövde fontu (ör. Nunito) indir → assets\fonts\ + lisans dosyaları.
5. assets\ui\gafti_theme.tres: Godot 4 Theme (metin formatı). Varsayılan font, Button (normal/hover/pressed/disabled/focus), Panel, PanelContainer, Label, ProgressBar, LineEdit, HSlider, CheckButton, TabContainer, ItemList stilleri. StyleBoxFlat: yuvarlatılmış köşeler, koyu ahşap/koyu yeşil panel, krem metin, turuncu vurgu. Butonlar en az 56px yüksek (mobil).
6. assets\logo\README.md: palet hex kodları.
Logo ve ikon render önizlemelerini tools\previews\logo_*.png olarak kaydet ve kontrol et.
