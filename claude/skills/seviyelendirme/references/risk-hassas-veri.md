# Risk etiketi: Hassas kişisel veri (KVKK, sağlık, çocuk)

Seviyeyi yükseltmez. Hassas veriye dokunan iş **KRİTİK** sayılır (`agent-model-routing` §4).

## Asgari kontrol listesi (her seviyede)
1. **Veri envanteri:** hangi alan hassas (TC kimlik, sağlık, çocuk bilgisi, adres, telefon) — PROJECT/CLAUDE.md'de tek liste.
2. **En az veri:** işin gerektirmediği alan toplanmaz (ör. TC kimlik yerine öğrenci numarası).
3. **Erişim:** hassas alanı yalnızca ilgili rol görür; liste uçlarında maskelenir; IDOR kuralı (kimlik yalnızca `ICurrentUserService`).
4. **Aydınlatma ve açık rıza** metni (frontend'de) ve rızanın kaydı (tarih, metin sürümü).
5. **Saklama ve silme:** saklama süresi tanımlı; silme talebinde anonimleştirme (şablonun S3 hesap silme akışındaki anonimleştirme örnek alınır).
6. **Şifreleme:** HTTPS zorunlu; çok hassas alanlar (sağlık) için alan bazlı şifreleme (ASP.NET Data Protection) değerlendirilir; yedekler şifreli.
7. **Erişim logu:** hassas kaydı kimin ne zaman görüntülediği/değiştirdiği (S3 audit alanları yetmez, ayrı log).
8. **Loglarda hassas veri yok:** Serilog'a istek gövdesi yazılmaz; hata mesajları kişisel veri içermez.
9. **Yedek ve dışa aktarma** da aynı erişim kurallarına tabidir.

## Çocuk verisi ek
Veli onayı, fotoğraf/görsel yayımında ayrı izin, yetişkin kullanıcıyla aynı tabloda olsa bile ayrı rol.
