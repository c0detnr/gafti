# GAFTİ oyuncu ve NPC karakter tabanı

Karakter tüm seçeneklerle birlikte 11.910 üçgendir. Tek skin, 19 kemik ve 18 mesh içerir. Orijin iki çizmenin arasında, taban yüksekliğindedir. GLB +Y yukarı, +Z ileri bakar. Godot hareket kodu −Z ileri kabul ediyorsa görsel kökü Y ekseninde 180° döndürün. Boy saç ve başlığa göre yaklaşık 1,72–1,78 m arasındadır.

## Dosyalar

| Dosya | İçerik |
|---|---|
| tools/blender/character.py | Model, iskelet, kostümler, animasyonlar ve Workbench önizlemelerinin üreticisi |
| assets/models/hero/character_base.glb | Ortak oyuncu ve NPC tabanı |
| assets/models/hero/character_base.glb.import | Godot içe aktarma ayarları ve hareket döngüleri |
| tools/previews/character_raincoat.png | Kasket, kısa saç, palabıyık ve sarı yağmurluk |
| tools/previews/character_sweater.png | Kıvırcık saç, gür sakal ve yayla desenli kazak |
| tools/previews/character_shirt.png | Topuz, tıraşlı yüz ve kiremit tonunda gömlek |
| tools/codex_logs/astra_character_report.md | Teslim ve entegrasyon notları |

## Düğümler ve özelleştirme

Godot 4.7.2 içe aktarımında mesh’ler Armature/Skeleton3D altında, AnimationPlayer ise sahne kökünün altındadır.

| Düğüm | İçerik |
|---|---|
| Body | Gövde, yüz, gözler, kaşlar ve eller tek mesh |
| Hair_01, Hair_02, Hair_03, Hair_04, Hair_05, Hair_06 | Sırasıyla kısa, kıvırcık, at kuyruğu, kel ve yanlar, dalgalı, topuz |
| Beard_00, Beard_01, Beard_02, Beard_03, Beard_04 | Sırasıyla kafa içine gizlenmiş küçük mesh, bıyık, palabıyık, kirli sakal ve gür sakal |
| Hat_Kasket | Ayrı açılıp kapanabilen kasket |
| Top_Raincoat, Top_Sweater, Top_Shirt | Sarı kapüşonlu yağmurluk, desenli örgü kazak ve yakalı gömlek |
| Pants_01, Boots_Rubber | Pantolon ve lastik çizmeler |

İskeletin merkez zinciri hips, spine, chest, neck ve head kemiklerinden oluşur. Her iki yanda shoulder, upper_arm, forearm, hand, thigh, shin ve foot kemikleri .L ve .R sonekleriyle adlandırılmıştır.

Ten, saç, üst giyim, pantolon ve çizme için materyal adları sırasıyla Skin, Hair, Cloth_Top, Cloth_Pants ve Boots. Üst giysilerde başlangıç kumaş rengini vertex renkleri verir. Bir NPC’yi diğerlerinden bağımsız renklendirmek için materyal örneğini çoğaltıp ilgili yüzeye atayın.

## Animasyon ve doğrulama

İzole bir Godot 4.7.2 projesinde son GLB içe aktarıldı ve sahne örneklendi. AnimationPlayer dokuz klibi okudu. idle, walk ve run doğrusal döngü modunda, interact, sit, roll, smoke, faint ve wave tek oynatımlı. Yürüme ve koşma yerinde oynar. roll sarma masasındaki iki el hareketini temsil eder. sit oturma, faint yatma pozunda biter.

Üç kombinasyon Blender Workbench ile 512 × 512 render edildi ve tek tek incelendi. Kasket ve göz kapağındaki taşma, saç derisindeki kesişme ve pantolonun altında görünen ten düzeltildi.

## Entegrasyon sınırları

GLB tüm seçenekleri içerir. Oyuncu veya NPC oluşturulurken birer saç, sakal ve üst giysiyi görünür bırakın. Kasket isteğe bağlıdır. Hacimli saçlarda kasketle kesişme olabilir. Üç görsel kontrol dinlenme pozuna aittir. Animasyonların oyun kamerasındaki görünümü ve her kostümün her animasyon karesindeki deformasyonu test edilmedi.
