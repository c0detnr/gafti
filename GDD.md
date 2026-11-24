# GAFTİ — Oyun Tasarım Dokümanı (GDD) v1.0

> Karadeniz yaylasında lisanslı kenevir serası + dükkan işletme oyunu. Komedi tonlu, cozy ama sonuçlu.
> Motor: Godot 4.7 · Platform: PC (Steam) + Mobil (Play Store) · Dil: Türkçe (çeviriye hazır) · Derecelendirme: 18+

---

## 1. Özet

Şehirde her işi batırmış karakterimiz, kimsenin istemediği yayla serasını devralır ve **Pusludere**
yaylasına taşınır. Sisli sabahlarda bitkilerine bakar, öğlen hasadını kurutup joint sarar, akşam kasaba
meydanındaki dükkanında köylülere ve turistlere satış yapar. Gece serada kova bongla günü kapatır.
Kasabanın tuhaf insanları, absürt görevleri ve kesintisiz bir yayla mizahı oyunu taşır.

**Üç sütun:**
1. **Dokunsal ustalık:** Bakım, sarma ve bong anları elle hissedilen mini oyunlardır.
2. **Atmosfer:** Sis, yağmur, mevsimler, ahşap ve yeşil. Oyunun asıl hissi yayladan gelir.
3. **Mizah:** Her NPC bir skeç. Ciddi bir ana hikâye yok.

---

## 2. Modlar

| Mod | İçerik |
|---|---|
| **Hikâye (Komedi)** | Ana hikâye yok; birbirine bağlı **komik görev zinciri** (NPC skeçleri). Oyunu öğretir, lisans seviyelerini açar. ~4 mevsim (28 gün). |
| **Serbest** | Hikâye bittikten sonra ya da baştan: sonsuz işletme, tüm sistemler açık. |

**Zorluk:** Cozy ama sonuçlu. Bitki ölebilir, para eksiye düşebilir, denetimde ceza gelebilir.
Oyun asla bitmez: eksi bakiyede Muhtar'dan faizsiz (ama utandırıcı) borç alınır.

---

## 3. Dünya: Pusludere Yaylası

### 3.1 Harita (küçük açık vadi, yüklemesiz)
```
                 ⛰  KEKLİKTEPE (manzara, hikâye finali)
                      │ patika
        🌲 LADİN ORMANI ── 🌉 KÖPRÜ & DERE (su deposu dolumu)
              │                      │
 [DEDENİN SERASI + EV] ── çay bahçeli yol ── [KASABA MEYDANI]
   ├ Sera (saksılar)                          ├ GAFTİ Dükkanı
   ├ Dış tarla (mevsimsel)                    ├ Fadime'nin Kahvehanesi
   ├ Kurutma ambarı                           ├ Muhtarlık
   ├ Sarma masası                             ├ Lisans & Denetim Ofisi
   └ Kova bong köşesi                         └ Hırdavatçı (ekipman/tohum)
                                                   │
                                          🚐 MİNİBÜS DURAĞI
                                       (turistler, toptan siparişler)
```
- Sera → dükkan yürüme süresi ~40 sn; ilerleyen oyunda **eski motosiklet** (sürüş, ~15 sn).
- Mobil: bölgeler `VisibilityRange` + streaming ile parça parça yüklenir; oyuncu yükleme ekranı görmez.

### 3.2 Atmosfer
- **Görsel stil:** Detaylı stilize. El boyaması hissi veren toon shading, yumuşak kenar ışığı, doygun yeşiller,
  ahşap/taş dokuları, rüzgârla sallanan bitki shader'ı, katmanlı sis.
- **Renk paleti:** Ladin yeşili, çay yeşili, ıslak taş grisi, ahşap kahvesi, sıcak lamba turuncusu (sera ışıkları).
- **Ses:** Yağmurun çatıya vuruşu, dere, kuşlar, uzaktan inek çanı, kahvehanede tavla sesi. Müzik: lo-fi + kemençe
  dokunuşlu sakin parçalar (CC0). Gece daha sakin bir müzik çalar, fırtınada müzik kısılır.

### 3.3 Mevsimler & Hava
1 yıl = 4 mevsim × 7 gün = 28 gün.

| Mevsim | Etki |
|---|---|
| İlkbahar | Ekim bonusu (+%15 çimlenme), sık yağmur (dış tarla kendiliğinden sulanır) |
| Yaz | Dış tarla en verimli, turist sayısı ×2, sıcaklık stresi |
| Sonbahar | Hasat bonusu (+kalite), fırtına ihtimali |
| Kış | Dış tarla kapalı, kar, sera ısıtma gideri; müşteri az ama fiyat yüksek |

| Hava | Etki |
|---|---|
| Güneşli | Dış ışık +, su tüketimi + |
| Bulutlu | Nötr |
| Sisli | Görüş düşük, atmosfer max; müşteri biraz az |
| Yağmurlu | Dış tarla otomatik sulanır, müşteri −%20 |
| Fırtına | Dış bitkilere hasar riski, **elektrik kesintisi** (jeneratör yükseltmesi çözer) |
| Kar | Kışa özel, sera ısı ihtiyacı + |

Ertesi günün hava tahmini akşamları kahvehane radyosundan duyulur.

---

## 4. Çekirdek Döngü

```
SABAH  (06–11)  Sera & tarla: sula, besle, ışık ayarla, buda, zararlı temizle, hasat et
ÖĞLE   (11–16)  İşleme: kurut, kürle, paketle, joint sar (pre-roll)
AKŞAM  (16–22)  Dükkan: rafları diz, fiyat koy, kimlik kontrol et, sat
GECE   (22–02)  Planla: yükselt, çaprazla, inşa et · Kova bong · Uyu (kayıt)
```
- 1 oyun günü ≈ 14 dk gerçek zaman (ayarlardan 10–20 dk).
- Fazlar öneridir; dükkan sadece 16–22 arası açıktır.
- 02:00'da uyumazsan karakter bayılır: ertesi sabah geç uyanır, −%10 para (bayıldığı yerden eve "taşıma ücreti").

---

## 5. Sistemler

### 5.1 Bitki
| Aşama | Gün | Etkileşim |
|---|---|---|
| Çimlenme | 1 | Ekim, nem |
| Fide | 2 | Sulama, hafif ışık |
| Vejetatif | 3–5 | Besin, budama, saksı büyütme |
| Çiçeklenme | 4–6 | Işık döngüsü, pH, zararlı kontrolü |
| Hasat | — | Zamanlama: erken = az verim, geç = kalite düşer |

- **Değişkenler:** Su, Işık, Besin, pH, Sıcaklık, Nem, Sağlık.
- Türün ideal aralığında geçen süre → **Kalite (0–100)**. Sağlık 0 → bitki ölür (kompost olur, gübre verir).
- **Zararlılar:** Yaprak biti, küf (nem yüksekse). Elle temizlenir ya da ilaçlanır.
- Görsel: Her aşamanın ayrı bir modeli var. Kalite, sağlık ve susuzluk yaprak rengine ve duruşuna yansır.

### 5.2 Genetik / Çaprazlama
- Özellikler: **Verim, Hız, Dayanıklılık, Aroma, Kalite Potansiyeli**, ayrıca görsel özellikler (yaprak tonu, boy).
- Çaprazlama: yavru özelliği ebeveyn ortalaması ± sapma; %5 mutasyon (nadir özellik).
- Başlangıçta 3 tür: **Pusu Kuşu**, **Ladin Duman**, **Çay Yaprağı**. Hikâye ödülü: **GAFTİ** türü.
- Yeni türlere oyuncu isim verir; **Tohum Defteri** koleksiyonu.

### 5.3 İşleme
Kurutma (3–7 saat, nem dengesi) → Kürleme (opsiyonel, 1–3 gün, +kalite) → Ürün:
- **Kavanoz** (gram satış)
- **Pre-roll** (joint sarma mini oyunu, ×1.6 değer)

### 5.4 Joint Sarma Mini Oyunu (yakın çekim, dokunsal)
| Adım | Etkileşim (fare / dokunmatik) | Kaliteye etkisi |
|---|---|---|
| 1. Öğüt | Grinder kapağını dairesel çevir | Az çevirirsen iri tane, çok çevirirsen toz olur |
| 2. Filtre | Kartonu zikzak katla (3 sürükleme) | Düzgün filtre olursa çekiş iyi olur |
| 3. Dağıt | Kağıda sürükleyerek serp | Eşit dağılım için ısı haritası göstergesi |
| 4. Sar | Yukarı-aşağı ritmik kaydırma, basınç çubuğu | Gevşek sararsan söner, sıkı sararsan çekmez |
| 5. Yapıştır | Kenar boyunca sürükle (yala) | Eksik bırakırsan açılır |
| 6. Bük | Ucu döndür | Bitiş |

- Sonuç **Sarma Skoru (0–100)**; ürün kalitesiyle çarpılır. Beceri arttıkça yardım çubukları azalır.
- Komedi: Çok kötü sarımlar "Muhtar'ın Kağıdı", "Kibrit Çöpü" gibi komik isimler alır ama yine satılabilir (ucuza).

### 5.5 Kova Bong Mini Oyunu (gravity bong, yakın çekim)
| Adım | Etkileşim |
|---|---|
| 1. Hazırla | Kesik pet şişeyi su dolu kovaya batır |
| 2. Doldur | Kaseyi doldur (miktar seçimi: az / orta / bol) |
| 3. Yak | Çakmağı çak (basılı tut) |
| 4. Kaldır | Şişeyi **yavaşça** yukarı kaldır; hızlı kaldırırsan duman kaçar |
| 5. Çek | Kaseyi çıkar, nefes çubuğunu doğru anda bırak |

- **Etki: "Gaftî Modu"** (süre miktara bağlı, 1–3 oyun saati):
  - Ekran: renk doygunluğu artar, hafif dalga efekti, yumuşak bulanıklık, müzik yavaşlar ve filtrelenir.
  - **Artı:** Müşteri sabrı +%30, bakım mini oyunlarında "sakin el" (sarma skoru +10).
  - **Eksi:** Hareket −%15, sulama miktarı rastgele ±%20 kayar, NPC diyalogları absürtleşir.
  - "Bol" doz: komik bayılma ihtimali (kanepede uyanırsın, 2 saat kaybedersin).
- Seradaki bong yükseltilebilir (kova → bidon → "Muhtar'ın Kazanı" süs görünümleri).

### 5.6 Dükkan
- Raf ve vitrin grid yerleşimi, ürün başına fiyat, gün sonu raporu.
- **Müşteri tipleri:**
  | Tip | Tercih | Bütçe |
  |---|---|---|
  | Yayla Köylüsü | Ucuz, kavanoz | Düşük |
  | Turist | Pre-roll, şık paket | Yüksek |
  | Tıbbi Hasta (Hayri Hoca vb.) | Yüksek kalite, aroma | Orta |
  | Uzman (şehirli) | Nadir tür, mutasyon | Çok yüksek |
- **Kimlik kontrolü:** Her müşteride hızlı kart kontrolü yapılır. Atlarsan denetimde ceza gelir. Komik sahte kimlikler de çıkar.
- Memnuniyet → **İtibar** → müşteri sayısı ve kalitesi.

### 5.7 Lisans & Denetim
- Kurgusal "Yayla Kenevir Lisansı", 5 seviye. Her seviye yeni saksı sayısı, ekipman, tür ve dükkan alanı açar.
- **Denetçi Nevzat Bey** habersiz gelir: kayıt defteri, etiket, kimlik kontrol geçmişi ve hijyen puanlanır.
- Düşük puan → para cezası; üst üste düşük puan → 1 gün dükkan kapalı.

### 5.8 İnşa & Yükseltme
Grid yerleşim: saksılar, LED lambalar, damla sulama, nemlendirici, ısıtıcı, jeneratör, kurutma rafı, dükkan rafları.
Otomasyon orta seviyede gelir; zevkli işler (sarma, bong, hasat) hiç otomatikleşmez.

### 5.9 Ekonomi (başlangıç dengesi)
- Başlangıç: 2.000 ₺, 6 saksı, 3 tohum türü × 2.
- Giderler: elektrik (günlük, lamba sayısına bağlı), su (dere deposu bedava ama taşıma gerekir), kış ısıtma, tohum, ekipman.
- Hedef: 3. günde kâra geçmek, 7. günde ilk lisans yükseltmesi.

### 5.10 Karakter Özelleştirme
Ten tonu (6), saç (6 model × renk), sakal/bıyık (5), Karadeniz giyimi: yağmurluk, örgü kazak, kasket,
lastik çizme (renkler). Ayna/dolap ile her zaman değiştirilebilir.

---

## 6. Karakterler & Komedi Görevleri

| NPC | Rol | Komedi |
|---|---|---|
| **Muhtar Rüstem** | Hikâye görevleri, borç | Her şeye "hallederuk" der, hiçbir şeyi halletmez |
| **Fadime Abla** | Kahvehane, hava tahmini, dedikodu | Radyo hava tahminleri hep tersi çıkar |
| **Hayri Hoca** | Emekli öğretmen, tıbbi müşteri | Her alışverişte ders verir |
| **Cemil** | Komşu, absürt görevler | İneği için "rahatlatıcı" ister (vermezsin) |
| **Hans** | Alman turist | Yaylaya yerleşmek ister, Türkçesi felaket |
| **Nevzat Bey** | Denetçi | Ciddi; Gaftî Modu'nda çok komik konuşur |

**Görev zinciri (örnek ilk hafta):** Serayı temizle → İlk hasat → Muhtar'a "numune" → Dükkanı aç →
Hans'ın ilk siparişi → İlk denetim → Lisans 2. Her görev 1–3 dk'lık bir skeçle biter.

---

## 7. Kamera & Kontroller

**Vadide:** 3. şahıs omuz üstü kamera. **Mini oyunlarda:** sabit yakın çekim kameraya yumuşak geçiş.

| Eylem | PC | Mobil |
|---|---|---|
| Hareket | WASD | Sol sanal joystick |
| Kamera | Fare | Sağ yarı ekran sürükleme |
| Etkileşim | E / Sol tık | Bağlamsal etkileşim butonu |
| Koş | Shift | Joystick'i sonuna kadar it |
| Envanter | Tab | Çanta ikonu |
| İnşa modu | B | Menü butonu |
| Mini oyun | Fare sürükle/çevir | Parmakla aynı hareketler |

---

## 8. Mağaza, Gelir & Derecelendirme

- **Gelir:** PC'de Steam ücretli + ayrı demo. Mobilde ücretsiz demo (İlkbahar, 7 gün) + tek seferlik "Tam Sürüm" satın alımı (Play Billing).
- **Derecelendirme:** 18+ (uyuşturucu kullanımı tasviri). IARC anketi dürüst doldurulacak.
- **Risk notu:** İçme sahneleri her platformda açık; bu Play Store'da red riskini yükseltir. Teknik sigorta olarak
  tüm içme içeriği tek bir `content_flags.consumption` bayrağına bağlıdır (varsayılan: açık). Red gelirse
  mobil derlemede bu bayrak kapatılıp joint "satılık pre-roll", bong "dekor" moduna düşer, ek iş gerekmez.
- Reklam yok. Gerçek marka/dispanser yok.

---

## 9. Teknik Mimari (Godot 4.7)

- **Renderer:** Mobile (PC'de "Yüksek" grafik ayarında ekstra sis/gölge kalitesi).
- **Dil:** GDScript, statik tipli. Tüm metinler `tr()` + `localization/strings.csv`.

**Autoload'lar:**
| Ad | Görev |
|---|---|
| `EventBus` | Sistemler arası sinyaller |
| `GameClock` | Saat, gün, faz, mevsim |
| `Weather` | Günlük hava, tahmin, ortam efektleri |
| `Economy` | Para, işlemler, gün sonu raporu |
| `Reputation` | İtibar, lisans seviyesi, uyum puanı |
| `Inventory` | Eşyalar, ürünler |
| `QuestManager` | Komedi görev zinciri, diyalog tetikleri |
| `SaveSystem` | Kayıt/yükleme (uyuyunca otomatik) |
| `Settings` | Grafik, ses, kontrol, gün süresi |
| `ContentFlags` | Platform/içerik bayrakları |
| `Effects` | Gaftî Modu ekran efektleri, post-process |

**Veri (Resource):** `StrainData`, `PlantState`, `ItemData`, `CustomerProfile`, `QuestData`, `DialogueData`, `BuildableData`.

**Klasör yapısı:**
```
res://
├── autoload/
├── data/            strains/ items/ customers/ quests/ dialogue/ buildables/
├── scenes/
│   ├── world/       valley.tscn, greenhouse/, town/, zones/
│   ├── player/      player.tscn, camera_rig.tscn, customization/
│   ├── plants/
│   ├── npc/
│   ├── minigames/   rolling/, gravity_bong/, care/, id_check/
│   ├── shop/
│   └── ui/          hud/, menus/, mobile_controls/, dialogue/
├── scripts/         systems/ components/
├── shaders/         toon.gdshader, foliage_wind, fog_layer, gafti_post
├── assets/          models/ textures/ audio/ fonts/ logo/
├── localization/
└── tests/
```

**Performans bütçesi (mobil, orta segment Android):** 60 FPS hedef (min 30), ekranda ≤150 draw call,
≤300k üçgen, bitki modelleri LOD0 ≤4k / LOD1 ≤1k üçgen, doku atlasları 2K.

---

## 10. Sanat Listesi (öncelik + üretici)

| Varlık | Detay | Üretici |
|---|---|---|
| **GAFTİ logosu** | Çizgi film tarzı, kalın yuvarlak harfler, İ noktası yaprak/duman; yeşil + sıcak turuncu. SVG + PNG + uygulama ikonu | Codex astra |
| **Bitki** | 5 aşama × sağlık varyasyonu, rüzgâr shader'ı | Codex astra |
| **Kova bong seti** | Kova, kesik şişe, kase, su, duman | Codex astra |
| **Joint seti** | Grinder, kağıt, filtre, joint (sarım aşamaları) | Codex astra |
| **Oyuncu karakteri** | Gövde + özelleştirme parçaları + temel animasyonlar | Codex astra |
| **Shader'lar** | Toon, foliage wind, sis katmanları, Gaftî post-process | Codex astra |
| Sera yapısı, ev | Ahşap/cam yayla serası | Codex astra |
| NPC'ler (6) | Karakter tabanından türetilmiş | Codex sol |
| Kasaba binaları, props | Kahvehane, muhtarlık, raflar, saksı, lamba, çit, ağaç | Codex sol |
| UI teması | İkonlar, paneller, font seçimi | Codex astra (yön) + sol (uygulama) |

---

## 11. MVP Kapsamı (bu geliştirme turunda)
Vadinin tamamı (blockout + ana modeller), 3. şahıs kontrol (PC + mobil), sera + dış tarla, bitki sistemi,
çaprazlama, kurutma, **joint sarma**, **kova bong + Gaftî Modu**, dükkan + 4 müşteri tipi + kimlik kontrolü,
gün/gece + mevsim + hava, lisans 1–3 + denetim, karakter özelleştirme, ilk hafta komedi görevleri (6 NPC),
kayıt/yükleme, ayarlar, logo + ana menü, CC0 sesler.

**MVP dışı (sonra):** Lisans 4–5, motosiklet, İngilizce, Steam/Play entegrasyonu, satın alma, tam 28 günlük görev zinciri.
