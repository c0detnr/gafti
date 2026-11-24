Beş büyüme aşamasının modelleri, üç shader ve [PlantVisual sahnesi](C:/Users/31/Documents/we2/scenes/plants/plant_visual.tscn) tamamlandı. Her modeli Blender Eevee’de 512 × 512 piksel olarak render edip inceledim. [Hasat önizlemesi](C:/Users/31/Documents/we2/tools/previews/plant_harvest.png)

Beş model de üçgen bütçesi içinde. En yoğun yakın görünüm 3.646, en yoğun LOD1 görünümü 820 üçgen. Dosyalardan model boylarını, düğüm adlarını, yaprak UV’lerini ve rüzgâr ağırlıklarını doğruladım.

Godot 4.7.2’de aşama geçişleri, sağlık, susuzluk ve kalite kontrolleri testten geçti. Üç shader Windows’ta Vulkan Mobile ile çizildi. Fiziksel Android cihazda performans ölçümü yapılmadı.

[Dosya listesi, model ölçüleri ve doğrulama raporu](C:/Users/31/Documents/we2/tools/codex_logs/astra_plants_report.md)