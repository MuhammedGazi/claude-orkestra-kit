---
name: seviyelendirme
description: Yeni veya mevcut bir projenin seviyesini (S1 Vitrin … S5 Ölçekli ürün) ve risk etiketlerini belirleyen analist görüşmesi; sonucu proje CLAUDE.md'sine yazar ve geliştirme boyunca seviye üstü/taban altı önerilere karşı uyarır. Projenin CLAUDE.md'sinde "Seviye:" satırı yoksa, yeni proje başlarken, "seviye", "S1", "S2", "S3", "kapsam", "over engineering", "abartma", "yapmayacaklarımız", "müşteri projesi", "arkadaş için site" dendiğinde, ya da bir öneri projenin seviyesini aşıyor görünüyorsa MUTLAKA oku.
---

# Seviyelendirme

**Amaç:** "Nerede durmalıyım?" kararı kod yazarken değil, projenin başında **bir kez** verilir ve
proje `CLAUDE.md`'sine yazılır. Sonraki oturumlar soruları tekrar sormaz, yalnızca o satırı okur.

Kaynaklar (bu skill'in `references/` klasörü):
- `seviyeler.md`: seviye tablosu (eklemeli), güvenlik tabanı, şablon/reçete eşlemesi
- `risk-odeme.md`, `risk-hassas-veri.md`, `risk-entegrasyon.md`: risk etiketi kontrol listeleri
- `ihtiyaclar.md`: işin ihtiyaçları (bildirim, yükleme, deploy, yedek, spam) için önerilen en basit çözümler

## 1. Ne zaman çalışır

1. Projenin kökündeki `CLAUDE.md`'de `Seviye:` satırı yoksa → bu skill, başka iş yapmadan önce.
2. Kullanıcı kapsamın değiştiğini söylerse (yeni rol, yeni kurum, ödeme eklendi) → §3 yeniden, yalnızca değişen sorular.
3. Geliştirme sırasında bir öneri seviyeyi aşıyorsa → yalnızca §5 uyarısı (görüşme tekrarlanmaz).

## 2. Analist görüşmesi (teknolojiden ÖNCE)

Soruları **tek mesajda** sor (AskUserQuestion uygunsa onu kullan). Cevabı kodda/dosyalarda bulabildiğin
soruyu sorma (ör. mevcut projede rol sayısı koddan okunur).

1. **İşin ihtiyaçları:** Bildirim (e-posta) gerekiyor mu? İçerik/görsel yükleme? Nereye deploy edilecek? Yedek kim alacak? Public form var mı (spam)?
2. Kaç kişi giriş yapacak, kaç admin var?
3. Kaç farklı rol/yetki türü var?
4. Para veya hassas kişisel veri (KVKK, sağlık, çocuk) var mı?
5. Dış sistemle entegrasyon var mı (ödeme sağlayıcı, e-Devlet, muhasebe, harici API)?
6. Bütçe ve süre ne? Bozulursa ne kaybedilir?
7. (Yalnızca S3 çıkarsa) Önümüzdeki 1-2 yılda büyüme ihtimali nedir? → N-Tier mı Onion mı.

## 3. Seviyeyi hesapla

- Kullanıcı sayısı, rol sayısı ve modül sayısı için `references/seviyeler.md` tablosuna bak; **en yüksek** kriter kazanır.
- Risk etiketleri seviyeyi yükseltmez; yalnızca ilgili `risk-*.md` listesini ekler.
- Mimari: S1-S2 → `my-ntier`. S3 → büyüme ihtimali düşükse `my-ntier`, yüksekse `my-onion`. S4-S5 → `my-onion`.
- Sınırdaki durumda **düşük seviyeyi** seç ve gerekçesini yaz (yükseltmek reçeteyle kolay, kırpmak zor).

## 4. Proje CLAUDE.md'sine yaz

Kullanıcıya önce göster, onaydan sonra `CLAUDE.md`'nin en üstüne ekle (dosya yoksa oluştur):

```markdown
## Seviye
Seviye: S2 (N-Tier) · Risk: yok
Gerekçe: 8 kullanıcı, 2 rol (Admin, Personel); büyüme beklenmiyor.
Kapsam: <müşterinin asıl ihtiyacı, 1-3 madde>
İşin ihtiyaçları: e-posta bildirimi (SMTP) · görsel yükleme (yerel disk) · deploy: <hedef> · yedek: <plan> · spam: honeypot
Yapmayacaklarımız: <seviye üstü öğeler, ör. "API versiyonlama yok", "çok kiracılık yok", "self-servis hesap silme yok">
Seviye atlama: şablonun recipes/ klasöründeki reçeteyle (ör. recipes/S2-S3); sıfırdan yazılmaz.
```

- "Yapmayacaklarımız" listesi `references/seviyeler.md`'de bir üst seviyenin öğelerinden seçilir; müşterinin
  açıkça istemediği her şey buraya girer.
- Şablondan yeni proje üretiliyorsa (`dotnet-sablonlar`), üretimden sonra bu blok eklenir.

## 5. Geliştirme boyunca uyarılar (iki yönlü)

Her plan, görev dosyası ve review bulgusunda:
- **Seviye üstü:** Öneri `references/seviyeler.md`'de projenin seviyesinden yüksek bir hücredeyse veya
  "Yapmayacaklarımız"da geçiyorsa, uygulamadan önce kullanıcıya tek satır sor:
  *"Bu S{n} işi, projenin seviyesi S{m}. Müşteri mi istedi, yoksa biz mi istiyoruz?"*
- **Taban altı:** Güvenlik tabanını (HTTPS, şifre hash, gizli anahtar repoda değil, girdi doğrulama, yedek)
  veya "sonradan değiştirmesi pahalı" maddeleri (gerçek DB, temiz veri modeli, bilinen framework, hazır
  kimlik kütüphanesi) delen kestirmeyi reddet: *"Bu ileride kapıyı kilitler."*
- Review bulgusu seviye üstüyse "bulgu" değil "seviye atlama önerisi" olarak raporlanır.

## 6. Orkestra bağlantısı

Seviye, `agent-model-routing` skill'inin `references/seviyeler.md` tablosunu seçer (STATE ağırlığı, plan
onayı, inceleme derinliği, KRİTİK zinciri, wiki). Risk etiketi olan yol her seviyede KRİTİK sayılır.
