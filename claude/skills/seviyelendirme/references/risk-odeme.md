# Risk etiketi: Ödeme

Seviyeyi yükseltmez; yalnızca ödeme yolunu sağlamlaştırır. Bu yoldaki her iş `agent-model-routing`
§4'e göre **KRİTİK**tir (Flash'a verilmez, çapraz security-review zorunlu).

## Asgari kontrol listesi (her seviyede)
1. **Kart verisi sende durmaz.** Ödeme sağlayıcının barındırılan sayfası / iframe / SDK'sı (iyzico, PayTR, Stripe Checkout). Kart numarası API'ye hiç gelmez.
2. **Tutar sunucuda hesaplanır.** İstemciden gelen fiyat/indirim kullanılmaz; sipariş kalemleri DB'den okunur.
3. **Webhook/callback doğrulanır.** Sağlayıcının imzası (HMAC) doğrulanmadan sipariş "ödendi" yapılmaz; tarayıcı dönüş sayfası tek başına kanıt değildir.
4. **İdempotency.** Aynı ödeme bildirimi iki kez gelirse sipariş iki kez işlenmez (sağlayıcı işlem kimliği üzerinde unique index).
5. **Durum makinesi.** Sipariş durumu (Beklemede → Ödendi → İade) yalnızca izin verilen geçişlerle değişir; eşzamanlı bildirimlerde RowVersion veya koşullu UPDATE.
6. **Gizli anahtarlar** ortam değişkeninde; test ve canlı anahtarı ayrı; canlı anahtar repoda/loglarda yok.
7. **Loglama:** işlem kimliği ve durum loglanır; kart/kimlik bilgisi loglanmaz.
8. **Test:** sağlayıcının test modu + test kartlarıyla başarılı, başarısız, iade, çift webhook senaryoları entegrasyon testinde.
9. **Mutabakat:** günlük sağlayıcı raporu ile sipariş tablosu karşılaştırılabilir olmalı (en azından elle).

## Yapılmayacaklar
- Kart saklama, kendi 3D Secure akışını yazma, ödeme sağlayıcısı olmadan havale "otomatik onay".
