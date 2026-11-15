# İşin ihtiyaçları: en basit çalışan çözümler

Analist görüşmesinin ilk sorusu. Gerçek projelerde (ÖrnekVitrin, ÖrnekTakip) güvenlik fazlaydı ama
bunlar eksikti. Her seviyede önce bunlar yapılır, sonra "güzelleştirme".

| İhtiyaç | S1-S2 önerisi (en basit) | S3+ ek | Not |
|---|---|---|---|
| **Bildirim (e-posta)** | `IEmailService` için SMTP uygulaması (MailKit veya hosting sağlayıcının SMTP'si); ayarlar ortam değişkeninden | Şablonlu e-posta, başarısız gönderimi loglama/yeniden deneme | Şablondaki `LoggingEmailService` yalnızca geliştirme içindir; canlıda e-posta GİTMEZ. "Şifremi unuttum" ve "yeni mesaj bildirimi" buna bağlı |
| **İçerik/görsel yükleme** | Yerel diske (`wwwroot/uploads`), uzantı + boyut + içerik türü kontrolü, rastgele dosya adı | Nesne depolama (S3/Blob), resim boyutlandırma | Admin'in URL yapıştırması çözüm değildir. Yüklenen dosya yedeğe dahil edilir |
| **Deploy** | Tek sunucu: `dotnet publish` + systemd/IIS + reverse proxy (Caddy/nginx), tek betik veya GitHub Actions | Ortamlar (staging/prod), migration adımı ayrı | Production config'i ortam değişkeniyle; `Production` kontrol listesi şablon README'sinde |
| **Yedek** | Günlük veritabanı yedeği (SQL Server bakım planı veya `sqlcmd BACKUP`) + yüklenen dosyalar, 7-30 gün saklama, **bir kez geri yükleme denemesi** | Uzak konum, şifreli yedek, düzenli geri yükleme testi | Güvenlik tabanının parçasıdır, hiçbir seviyede atlanmaz |
| **Spam koruması** | Public formda honeypot alanı + mevcut rate limit | Cloudflare Turnstile / hCaptcha | Yalnızca anonim form varsa |
| **Frontend CSP** | Angular build çıktısı için sıkı CSP başlığı (reverse proxy'de) | Nonce/hash tabanlı CSP | API'nin CSP'si şablonda var; frontend'inki ayrı verilir |

Kural: Bu tablodaki bir ihtiyaç müşteride varsa ve çözülmemişse, yeni özellik yazılmadan önce o çözülür.
