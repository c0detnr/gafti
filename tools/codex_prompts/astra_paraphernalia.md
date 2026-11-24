GOREV=astra_paraphernalia
İŞ: Kova bong seti ve joint sarma seti. Yakın çekimde görünecekler; detay, sevimlilik ve komik "ev yapımı" hissi çok önemli.
1. tools\blender\paraphernalia.py → assets\models\hero\:
   - bong_bucket.glb: çizik, hafif ezik renkli plastik kova (Bucket), ayrı yarı saydam su yüzeyi (Water).
   - bong_bottle.glb: kesik 2L pet şişe, etiket kalıntısı; kapakta folyo-kase (Bottle, Cap, Bowl). Orijin şişenin altı.
   - lighter.glb (Body, Wheel)
   - grinder.glb: metal, dişli iç (Base, Lid; Lid kendi merkezinde döner)
   - rolling_paper.glb: Paper, ≥24 enine segment, ince yarı saydam kağıt
   - filter_tip.glb: Filter, zikzak katlanmış karton
   - joint.glb: bitmiş konik joint, bükülmüş uç (Joint)
   - rolling_tray.glb: Karadeniz motifli boyalı metal tepsi (Tray)
   PBR materyaller glb içinde. Her biri ≤2k üçgen.
2. shaders\smoke.gdshader: yumuşak stilize duman (billboard, gürültülü kenar, color/alpha uniform'ları).
3. scenes\minigames\gravity_bong\smoke_fx.tscn: şişe içini dolduran duman GPUParticles3D sahnesi (emitting açılıp kapanabilir, amount ≤64, kök düğüm adı SmokeFX). Ayrıca scenes\minigames\gravity_bong\exhale_fx.tscn: ağızdan çıkan büyük komik duman bulutu.
