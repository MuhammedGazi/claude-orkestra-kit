---
name: orkestra-baslat
description: Bir projede çalışmaya başlarken orkestrayı (ajanlar, kota kontrolü, skill'ler, MCP'ler, proje haritası, STATE.md) hazırlar. Kullanıcı /orkestra-baslat yazdığında, "projeye başlayalım", "yeni proje", "bu projede çalışacağız", "devam" dediğinde veya oturumun ilk işi bir projede kod yazmak olduğunda kullan.
---

# Orkestra başlatma

Önce `agent-model-routing` skill'ini oku; bu ritüel onun kurallarına göre çalışır. **Opus burada da yalnızca şeftir** (routing §0): tarama, harita yazma, komut çalıştırma ve belge metni alt kademeye gider; Opus yalnızca karar verir ve kısa raporları okur. Her adımı kısa tut, ham çıktıyı bağlama basma. Sonda tek bir başlangıç raporu ver.

`S=~/.claude/skills/agent-model-routing/scripts`

## 1. Mod tespiti
- `.claude/orchestra/STATE.md` varsa → **DEVAM modu**: STATE.md'yi oku, 2. ve 3. adımı yap, `git status` + `git log --oneline -5` ile STATE'i doğrula, 7. adıma atla.
- Yoksa: depo boş ya da neredeyse boşsa (kaynak dosya yok) → **YENİ PROJE**, değilse → **MEVCUT PROJE**.
- MEVCUT PROJE'de kökte `AGENTS.md` **ve** `docs/AI_WORKFLOW.md` varsa proje kullanıcının .NET şablonlarından (`my-onion` / `my-ntier`) üretilmiştir → **ŞABLON PROJESİ** olarak işaretle ve `dotnet-sablonlar` skill'ini oku. YENİ PROJE'de backend .NET ise de bu skill okunur.

## 2. Ortam kontrolü (sessiz; yalnızca sorun varsa raporla)
- Git: depo yoksa `git init` + ilk commit (kullanıcıya bildir). Çalışma ağacı kirliyse kullanıcıya sor: commit mi, stash mi?
- `.git/info/exclude` içinde `.claude/orchestra/` ve `.claude/tasks/` satırları yoksa ekle.
- `mkdir -p /tmp/agy-tasks .claude/orchestra`
- `$S/agy-run.sh which` agy yolunu buluyor mu? (PATH'te olmasa da bilinen kurulum yerlerine bakar.) Bulamazsa: "Yalnızca Claude modu" diye not et.
- Gemini skill köprüsü (oturum başına bir kez, agy varsa): `$S/sync-gemini-skills.sh --copy` çalıştır (Windows'ta --copy gerekir). Çıktıdaki `BULUNAMADI` satırları kurulmamış 3. taraf skill'leri gösterir, hata değildir; raporlama.

## 3. Kota
- `$S/quota-check.sh` → Claude etiketi + agy `/usage` özeti; her havuza DUR/KIT/NORMAL/BOL etiketi ver.
- Claude DUR ise: yalnızca STATE.md'yi hazırla, yenilenme saatini bildir ve dur.

## 4. Proje haritası (yalnızca YENİ/MEVCUT; DEVAM'da harita varsa atla)

**ŞABLON PROJESİ:** Depo taraması yapılmaz. `PROJECT.md`yi haiku-scout, `dotnet-sablonlar` §3–§4'e göre `AGENTS.md`, `docs/wiki/index.md` ve hazır REFERANS/KRİTİK listelerinden yazar (≤60 satır; Opus görev metninde §3–§4 maddelerini verir, sonucu yalnızca başlık düzeyinde kontrol eder). Ardından taban çizgisi (`dotnet build/test <Ad>.slnx`, çözüm kökünde).

**MEVCUT PROJE (şablon dışı):** Haritayı Opus çıkarmaz; ucuz ajana yaptır (zincir: flash-low → haiku-scout). Görev: depoyu tara ve `.claude/orchestra/PROJECT.md` dosyasını en fazla 60 satırla yaz:
```
STACK: .NET sürümü, Angular sürümü, ana paketler (EF Core, MediatR, FluentValidation, ...)
YAPI: çözüm/proje klasörleri ve sorumlulukları (tek satır)
DESENLER: katmanlar, DI, hata yönetimi, mapping, test çatısı
REFERANS DOSYALAR: her görev türü için taklit edilecek en iyi örnek (endpoint, DTO, validator, servis, unit test, Angular component/servis/form)
DOĞRULAMA: çalışan build/test komutları
DİKKAT: kırılgan alanlar, TODO'lar, eski kod
```
Flash'a verirken salt okuma `consult` kullanılır: runner `consult /tmp/agy-tasks/MAP.md flash-low` çalıştırır, haiku-scout çıktı dosyasını PROJECT.md'ye kopyalar (Opus metni yazmaz, yalnızca başlıklara göz atar). Haiku'ya verirken haiku-scout doğrudan dosyayı yazar.

Ardından **taban çizgisi**: DOĞRULAMA komutlarını haiku-scout (veya runner) çalıştırır, Opus yalnızca ≤5 satırlık sonucu okur. Kırmızıysa PROJECT.md'ye "BAŞLANGIÇTA KIRMIZI: ..." yaz; bunlar ajanların hatası sayılmaz.

**YENİ PROJE:** Kullanıcının hedefini al (bilinmiyorsa tek soru sor). Opus, Superpowers `brainstorming` ile mimariyi netleştirir (yalnızca sorular ve karar maddeleri; uzun design doc metnini `run hydrogen-medium` yazar); kararları PROJECT.md'ye (aynı başlıklar, REFERANS DOSYALAR boş) ve STATE.md KARARLAR bölümüne yazar. Gerekirse kritik yol ayrımında `consult argon-high` (bütçe doluysa `consult hydrogen-xhigh`).
- **.NET backend iskeleti Flash'a yazdırılmaz:** Opus `dotnet-sablonlar` §1'e göre `my-onion` veya `my-ntier` önerir (tek cümle gerekçe), kullanıcı onaylayınca §2'deki `dotnet new` komutunu ve taban çizgisini haiku-scout çalıştırır. Proje artık ŞABLON PROJESİ'dir; REFERANS DOSYALAR §4'ten hemen doldurulur.
- Şablonun karşılamadığı parçalar (Angular workspace, ek servisler) ilk görevler olur: Angular iskeleti flash-medium. İlk iskelet commit'inden sonra bu parçaların REFERANS DOSYALAR'ı eklenir.

**Arayüz varsa (her iki modda):** DESIGN.md yoksa Opus, Impeccable `init`/`shape` sorularıyla kararları verir; PRODUCT.md ve DESIGN.md metnini hydrogen-medium yazar. Stitch ekran üretimi Flash-high'a gider (Stitch yalnızca agy'de).

## 5. Proje kuralları
Projenin köküne `CLAUDE.md` yoksa oluştur, varsa sonuna ekle (en fazla 10 satır):
```
## Orkestra
- Proje haritası: .claude/orchestra/PROJECT.md (görev dosyalarında REFERANS buradan seçilir)
- Durum: .claude/orchestra/STATE.md (her görevden sonra güncellenir)
- Doğrulama: <PROJECT.md'deki komutlar>
- Kritik alanlar: <ödeme/auth/migration yolları; buralara dokunan iş KRİTİK sayılır>
```
Projeye özel ek kural olmadıkça başka bir şey yazma.

ŞABLON PROJESİ'nde şablonun getirdiği `CLAUDE.md` (`@AGENTS.md` içerir) korunur, orkestra bölümü sonuna eklenir; bölüme şu satır da girer: `- Şablon kuralları: dotnet-sablonlar skill'i (onay dalga başına, wiki log Opus'ta, commit Türkçe ve AI atıfsız, dotnet-patterns yüklenmez)`. Kritik alanlar `dotnet-sablonlar` §4 KRİTİK listesinden yazılır. Eski bir şablon projesinde `CLAUDE.md` yoksa önce `@AGENTS.md` satırıyla oluştur.

## 6. STATE.md
Yoksa `agent-model-routing` §7 şablonuyla oluştur: HEDEF, KARARLAR, GÖREVLER (henüz boş ya da ilk plan), SONRAKİ ADIM, KOTA.

## 7. Başlangıç raporu (en fazla 12 satır)
- Mod (YENİ / MEVCUT / ŞABLON PROJESİ / DEVAM) ve projenin tek satır özeti (şablon projesiyse: my-onion / my-ntier)
- Kota etiketleri: Claude …, Gemini (Hydrogen+Flash) …, Argon … (oturum bütçesi) (+ yenilenme saatleri, kullanıcının saat diliminde)
- Ortam sorunları (varsa)
- Taban çizgisi: build/test yeşil mi
- DEVAM ise: kalınan yer ve SONRAKİ ADIM; değilse: "Ne üzerinde çalışalım?" sorusu
- Hatırlatma (tek satır): "Her dalga sonunda yeni oturum + `devam` önereceğim; Opus kod yazmaz, işler Hydrogen/Flash/Argon'da, Claude tarafında Sonnet ve Haiku'da."
