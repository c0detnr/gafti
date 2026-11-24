# GAFTİ — Claude Kuralları

**Bağlayıcı kurallar ve mimari sözleşmesi: `AGENTS.md`** (her oturumda oku). Tasarım: `GDD.md`.

## En önemli kural
- Kullanıcı **Windows 11** kullanıyor. Sohbette **Linux/bash komutu yazma**; her komut örneği **PowerShell** olmalı.
- Kendi çalıştırdığın komutlarda da PowerShell kullan: `powershell -NoProfile -Command '...'` ya da `.ps1` dosyası.
- Görsel ağırlıklı işler Codex `gpt-6.2-astra` (medium) ile, ikincil işler Codex `gpt-6.2-sol` (medium) ya da Opus alt ajanlarıyla yapılır (token tasarrufu).
  Codex çağrısı: `codex exec -m gpt-6.2-astra -c model_reasoning_effort="medium" --skip-git-repo-check -C C:\Users\31\Documents\we2 "<görev>"`
