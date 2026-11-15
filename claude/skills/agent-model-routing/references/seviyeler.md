# Orkestra seviye profilleri (agent-model-routing eki)

> Dayanak: `docs/SEVIYELENDIRME_KARARLARI.md` §4.8 ve `docs/SEVIYE_TANIMLARI.md` (şablon deposunda, kite dahil değil).
> Bu dosya SKILL.md'nin yerini tutmaz; **yalnızca seviyeye göre değişen ayarları** listeler.
> Burada yazmayan her kural (kota, zincir, görev dosyası formatı, exit kodları) tüm seviyelerde aynıdır.

## Seviye nereden okunur

Projenin `CLAUDE.md` dosyasındaki satır: `Seviye: S2 (N-Tier) · Risk: ödeme`.
Satır yoksa önce `seviyelendirme` skill'i çalıştırılır; o zamana kadar **S2** varsayılır
(en sık durum ve yanlış tahminin maliyeti iki yönde de düşük).

## Değişmeyenler (her seviyede)

- **Şef her seviyede Opus 5.5'tir ve yalnızca şeftir** (SKILL.md §0): plan, görev bölme, karar, kabul/ret. Kod, düzeltme, tarama, komut çalıştırma hiçbir seviyede Opus'ta değildir.
- **Küçük diff kuralı:** Diff ≤20 satır, yalnızca belge/config ve KRİTİK değilse ayrı `consult` çağrılmaz; runner raporundaki diff --stat ve doğrulama yeterlidir.
- **Hydrogen/Flash ana işçidir** (orta ve zor işler Hydrogen, basit işler Flash; inceleme ve danışma Argon; SKILL.md §3). Görev dosyası her seviyede §6 formatında, REFERANS'lı ve KABUL'lüdür
  (uygulayıcının isabeti seviyeye değil görev tanımına bağlıdır).
- **Yazan incelemez.** Flash'ın (ve her uygulayıcının) diff'i başka bir model tarafından incelenir.
  Seviye yalnızca incelemenin **derinliğini** belirler.
- **KRİTİK tanımı** (§4: ödeme, kimlik/yetki, veri kaybı riski taşıyan migration, güvenlik düzeltmesi)
  seviyeden bağımsızdır. Risk etiketi taşıyan proje S1 olsa bile o yol KRİTİK zinciriyle yapılır.
- Kota ritüeli (§2-§3), doğrulama kuralı ("geçmeden tamam yok"), geri alınamaz adımın kullanıcıya sorulması.

## Seviyeye göre değişenler

| Ayar | S1 Vitrin | S2 Küçük ekip | S3 Kurum içi | S4 Ürün | S5 Ölçekli |
|---|---|---|---|---|---|
| **Proje dosyaları** | Proje `CLAUDE.md` (seviye + kapsam + Yapmayacaklarımız). STATE.md yalnızca iş birden fazla oturuma yayılırsa, 10 satırı geçmez | Hafif STATE.md (HEDEF, GÖREVLER, SONRAKİ ADIM) | Tam STATE.md (§7) + PROJECT.md | S3 + KARARLAR bölümü her mimari kararda güncellenir | S4 ile aynı |
| **Plan onayı** | İşin başında tek liste, sonra onaysız devir | Dalga planı tek mesajda onay | Dalga başına onay + review bulguları ayrıca (`dotnet-sablonlar` §7 A1) | S3 ile aynı | S3 + KRİTİK görevlerde görev başına onay |
| **Diff incelemesi** | runner raporu + KRİTİK değilse inceleme yok; dalga sonunda tek `consult flash-high` hızlı kontrol | Dalga başına tek inceleme: Hydrogen yazdıysa `consult argon-high`, değilse `consult hydrogen-xhigh` (§3) | S2 + risk tabanlı kapı "Orta" satırı | + auth/dış girdi/dosya içeren diff'te güvenlik kontrol listesi; modül bazlı inceleme | + her dalgada bağımsız güvenlik incelemesi; büyük PR'da `/code-review` yalnızca kullanıcı isterse |
| **Test (uygulayıcının KABUL'ü)** | `dotnet build` + mevcut testler + değişen servise 1 birim test | S1 + yeni uca happy-path entegrasyon testi | S2 + negatif testler (401/403/409) | S3 + olay/versiyon (RowVersion, domain event) testi | S4 + önbellek geçersizleştirme testi |
| **KRİTİK zinciri** | hydrogen-xhigh → argon-high → sonnet-dev (opus-dev yok) | S1 ile aynı; opus-dev yalnızca ≤3 dosyalık çekirdek, pencere başına 1 | Tam §4 zinciri | Tam §4 | Tam §4 + insan onayı gereken adımlar açıkça işaretli |
| **Wiki / log** | Yok; README güncel tutulur | Yok | `docs/wiki` + `log.md` dalga sonunda (Opus) | S3 + modül sayfaları | S4 + mimari karar kayıtları (ADR) |
| **runner (wave-runner, Haiku)** | Her agy görevi runner'la | Her agy görevi runner'la | Her agy görevi runner'la | aynı | aynı |
| **İkinci görüş (consult argon-high)** | Kullanılmaz: kararı seviye tablosu verir | Yalnızca seviye sınırındaki kararda | Mimari yol ayrımında | aynı | aynı |
| **Opus derinliği** | medium | medium | medium; mimari kararda high | aynı | aynı |
| **Oturum başına dalga** | 1-2, sonra yeni oturum | 1-2 | 1-2 | 1-2 | 1-2 |

## Uyarı kuralları (Opus, plan ve review sırasında)

- **Seviye üstü öneri:** Görev dosyası, plan veya review bulgusu bir üst seviyenin öğesini getiriyorsa
  (`SEVIYE_TANIMLARI.md` tablosu) Opus devretmeden önce kullanıcıya tek satır yazar:
  "Bu S{n+1} işi; müşteri istedi mi?" Onay yoksa görevden çıkarılır.
- **Taban altı kestirme:** Güvenlik tabanını (HTTPS, şifre hash, gizli anahtarlar repoda değil,
  girdi doğrulama, yedek) veya "sonradan değiştirmesi pahalı" maddeleri delen öneri reddedilir.
- **Reçete önceliği:** Seviye atlama, şablonun `recipes/` klasöründeki reçeteyle yapılır
  (REFERANS dosyalı, Flash'a uygun). Aynı işi sıfırdan yazdırmak yasaktır.
