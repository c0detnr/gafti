GOREV=astra_buildings
İŞ: Oyunun ana mekanları.
1. tools\blender\buildings_hero.py → assets\models\hero\greenhouse.glb: dededen kalma ahşap + cam Karadeniz yayla serası, iç ölçü ~12×6 m (uzun kenar X ekseninde), kapı +Z yönünde ve ≥1.6 m genişlikte. İçeride X boyunca iki uzun saksı tezgahı (tezgah yüksekliği 0.8 m; her tezgahta 6 saksı yuvası için düz yüzey; tezgah üst yüzey merkezlerini raporda koordinat olarak ver). Yosunlu taş temel, hafif eğik çatı, bazı camlar bantlı/kırık (komik). Glass düğümü ayrı (yarı saydam). Çarpışma: duvar ve tezgahlar için "-col" son ekli basit kutu mesh'leri (Godot import convention).
2. assets\models\hero\house.glb: dedenin Karadeniz evi (taş zemin kat + ahşap üst kat, geniş saçak, balkon). Girilebilir tek oda, kapı +Z; iç zemin düz. "-col" çarpışma mesh'leri.
3. Bütçe ≤8k üçgen her biri. Önizleme render et.
