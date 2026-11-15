# Katkıda Bulunma

Bu depoya hata bildirimi (issue) veya Pull Request (PR) ile katkıda bulunabilirsiniz.

## Kurallar

- **Dil:** Skill, ajan ve kural içerikleri Türkçe kalır. Yalnızca `README.en.md` İngilizce özet/karşılık olarak tutulur.
- **Gizlilik:** Kişisel dosya yolları (`C:\Users\...`), e-posta adresi, API anahtarı veya herhangi bir gizli bilgi eklemeyin.
- **Doğrulama:** `install.ps1` değişikliklerinde mutlaka sahte bir hedef klasörle `-DryRun` testi çalıştırın:

```powershell
.\install.ps1 -TargetHome "$env:TEMP\orkestra-test" -DryRun
```

- **Üçüncü taraf bileşenler:** Harici skill veya plugin dosyalarını doğrudan depoya kopyalamayın; gerekirse yalnızca kaynak ve inceleme notunu `THIRD_PARTY.md` önerisi olarak ekleyin.
