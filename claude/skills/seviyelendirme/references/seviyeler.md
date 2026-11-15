# Seviyeler: tablo, taban ve şablon eşlemesi

> Kaynak: `<şablon-deposu>/docs/SEVIYE_TANIMLARI.md` (şablon deposunda, kite dahil değil; ayrıntı ve gerekçe orada). Bu dosya skill'in hızlı başvurusudur.

## Seviye kriterleri (en yüksek kriter kazanır)

| Seviye | Kullanıcı | Rol | Tipik | Mimari / şablon başlangıcı |
|---|---|---|---|---|
| **S1 Vitrin** | 1-3 admin, ziyaretçi anonim | 1 | Tanıtım sitesi + admin paneli, randevu/iletişim formu | `my-ntier` (şablon tabanı) |
| **S2 Küçük ekip** | 3-20 giriş yapan | 1-2 | Küçük ofis, kuaför, atölye takibi | `my-ntier` + `recipes/S1-S2` |
| **S3 Kurum içi** | 20-300 | 3-5 | Yurt/okul/kurum yönetimi, dosya ve bildirim | `my-ntier` + `S1-S2` + `S2-S3` **veya** `my-onion` (şablon tabanı) |
| **S4 Ürün** | 300-5000, birden fazla kurum | çok | Dış entegrasyonlu ürün | `my-onion` + `recipes/S3-S4` |
| **S5 Ölçekli ürün** | binlerce, çok kiracı | çok | Cache/kuyruk gerektiren ürün | `my-onion` + `S3-S4` + `S4-S5` |

S3'te seçim: 1-2 yıl içinde büyüme/çok kurum/dış entegrasyon ihtimali yüksekse Onion, değilse N-Tier.

## Seviyede neler var (eklemeli)

| Seviye | Eklenen (bir alttakine göre) |
|---|---|
| S1 | Admin girişi (JWT, 120 dk, security stamp ile iptal, giriş logu, admin şifre kurtarma), şifre değiştirme, lockout, tek global rate limit, Feature-Service, örnek katalog modülü, Created/Updated |
| S2 | Kullanıcı kaydı (`Registration:AllowPublic`: varsayılan yalnızca Admin, ayarla herkese açık), refresh token (hash'li, rotasyon), logout, şifre sıfırlama (e-posta), profil, auth rate limit |
| S3 | Kullanıcı bazlı audit alanları, soft delete, RowVersion/409, e-posta değiştirme, hesap silme, korelasyon kimliği, sıkı Production açılış kontrolleri, wiki + SYSTEM_AUDIT; Onion'da 4 proje, varlığa özel repository |
| S4 | Domain event + in-memory bus, API versiyonlama (`/api/v1`) |
| S5 | Önbellek; ihtiyaçta Redis/HybridCache, outbox/dış kuyruk, çok kiracılık, OpenTelemetry |

Seviyeden bağımsız erken eklenenler: **RowVersion** aynı kaydı iki kişi düzenleyebiliyorsa (S1-S2'de bile);
  **API versiyonlama** bağımsız istemci (mobil, üçüncü taraf) varsa. **Çok kurum (tenant)** veri modelini etkiler,
  S4'e geçmeden tasarlanır. **Önbellek** ölçülmüş performans sorunu olmadan eklenmez.

## Güvenlik tabanı (hiçbir seviyede düşmez)
HTTPS · şifre hash · gizli anahtarlar repoda değil · girdi doğrulama · yedek.

## Sonradan değiştirmesi pahalı (S1'de bile baştan doğru)
Gerçek veritabanı · temiz veri modeli · bilinen framework · hazır kimlik kütüphanesi.

## Yapmayacaklarımız için hazır maddeler
- S1 projesi: refresh token, kullanıcı self-servisi, soft delete, RowVersion, audit kullanıcı alanları, API versiyonlama, önbellek, event bus, Dapper, generic repository.
- S2 projesi: soft delete, RowVersion, e-posta değiştirme/hesap silme, korelasyon kimliği, versiyonlama, önbellek, event bus.
- S3 projesi: API versiyonlama, event bus, önbellek, çok kiracılık, mikroservis.
