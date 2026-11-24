[Karakter modeli](C:/Users/31/Documents/we2/assets/models/hero/character_base.glb) hazır. Gövde ve 17 özelleştirme parçası aynı 19 kemikli iskelete bağlı. Tüm parçalar birlikte **11.910 üçgen** tutuyor.

Godot 4.7.2’de modeli içe aktarıp dokuz animasyonu doğruladım. `idle`, `walk` ve `run` döngüsel oynuyor. Model **+Z ileri** bakıyor. Oyuncu denetleyicisi −Z ileri kullanıyorsa görsel kökü Y ekseninde 180° döndürmek gerekiyor.

Üç kombinasyonun 512 × 512 Blender önizlemelerini inceledim. Görsel kontrol dinlenme pozunu kapsıyor. [Yağmurluk ve kasket](C:/Users/31/Documents/we2/tools/previews/character_raincoat.png) · [Örgü kazak](C:/Users/31/Documents/we2/tools/previews/character_sweater.png) · [Gömlek ve topuz](C:/Users/31/Documents/we2/tools/previews/character_shirt.png)

[Blender üretim betiği](C:/Users/31/Documents/we2/tools/blender/character.py) · [Düğüm listesi, entegrasyon notları ve bilinen eksikler](C:/Users/31/Documents/we2/tools/codex_logs/astra_character_report.md)