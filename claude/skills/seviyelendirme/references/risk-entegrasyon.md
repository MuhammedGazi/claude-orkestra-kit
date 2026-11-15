# Risk etiketi: Dış entegrasyon

Seviyeyi yükseltmez; dış sisteme bağlanan kodu izole eder. Kimlik bilgisi veya para taşıyan entegrasyon KRİTİK'tir.

## Asgari kontrol listesi (her seviyede)
1. **Tek sınıf arkasında:** dış sistem bir arayüz + tek uygulama (`I<Sistem>Client`) arkasında; servisler HTTP detayını bilmez. Onion'da arayüz Application/Contracts'ta, uygulama Infrastructure'da; N-Tier'de Services/Common altında.
2. **`HttpClient` fabrikası** (`AddHttpClient<T>`), sabit `BaseAddress`, **timeout** (varsayılan 100 sn çok uzun; 10-30 sn).
3. **Yeniden deneme yalnızca idempotent çağrıda** (`Microsoft.Extensions.Http.Resilience` standart handler); para/kayıt oluşturan POST'ta otomatik retry yok.
4. **Hata izolasyonu:** dış sistem çökerse kendi uygulaman 500 yerine anlaşılır `ServiceResult.Fail` döner; kritik değilse işlem kuyruğa/yeniden denemeye bırakılır (S4+).
5. **Gizli bilgiler** (API anahtarı, sertifika) ortam değişkeninde; loglarda yok.
6. **Gelen çağrılar (webhook):** imza doğrulaması, IP kısıtı mümkünse, idempotency (aynı olay iki kez).
7. **Sözleşme testi:** dış sistemin yanıtları için sahte (`HttpMessageHandler` stub) ile birim testi; gerçek test ortamı varsa ayrı, manuel çalıştırılan entegrasyon testi.
8. **Sürüm/değişiklik:** dış API sürümü ve dokümantasyon linki PROJECT.md'de.
