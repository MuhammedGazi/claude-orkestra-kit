---
name: dotnet-sablonlar
description: Kullanıcının kendi .NET 10 backend şablonları (my-onion, my-ntier) için orkestra bilgisi - şablon seçimi, projeyi şablondan üretme, şablon projesini tanıma, referans dosyalar, kritik alanlar, doğrulama komutları, görev dosyası kısıtları ve tuzaklar. Yeni bir .NET backend başlatırken, mevcut bir projede AGENTS.md + docs/AI_WORKFLOW.md bulunduğunda, PROJECT.md yazarken veya bu projeler için görev dosyası hazırlarken MUTLAKA oku. "şablon", "template", "my-onion", "my-ntier", "Onion", "NTier", "yeni proje", "backend başlat" dendiğinde tetikle.
---

# .NET şablonları (my-onion / my-ntier)

`agent-model-routing` kurallarının şablon projelerindeki uzantısıdır. Çelişkide **projenin kendi `README.md` / `AGENTS.md` / `docs/AI_WORKFLOW.md` kuralları** bu dosyadan ve ECC skill'lerinden önceliklidir; orkestra kuralları (kota, zincir, devir) ise iş dağıtımında geçerliliğini korur.

## 1. Şablon kataloğu ve seçim

| Kısa ad | Mimari | Başlangıç seviyesi | Reçeteler | Ne zaman |
|---|---|---|---|---|
| `my-ntier` | N-Tier (3 katman: `<Ad>.API` → `<Ad>.Services` → `<Ad>.Repositories`), servisler `AppDbContext`'i doğrudan kullanır, rota `/api/...` | **S1** (admin girişi, katalog örneği) | `recipes/S1-S2`, `recipes/S2-S3` | S1-S3, büyüme ihtimali düşük |
| `my-onion` | Onion (4 proje: `Core/<Ad>.Domain`, `Core/<Ad>.Application`, `Infrastructure/<Ad>.Infrastructure` (Persistence/, Identity/, Services/), `Presentation/<Ad>.WebAPI`), varlığa özel repository + UoW, rota `/api/...` (S4+: `/api/v1/...`) | **S3** (kullanıcı oturumları, audit, soft delete, RowVersion) | `recipes/S3-S4`, `recipes/S4-S5` | S3 (büyüyecekse), S4-S5 |

Ortak: .NET 10, EF Core, Identity + JWT (security stamp ile anında iptal; refresh rotasyonu S2+), FluentValidation, Mapster, Serilog, rate limiting, health checks, Scalar UI, xUnit v3 (birim + SQLite entegrasyon). Dapper, önbellek/bus ve API versiyonlama reçetelerdedir. Şablonlar **yalnızca backend**; Angular ayrıca kurulur.

**Seviye kuralı:** Şablon, `seviyelendirme` skill'inin belirlediği seviyeye göre önerilir. Üretimden sonra hedef seviyeye
reçetelerle çıkılır (ör. S2 projesi = `my-ntier` + `recipes/S1-S2`).

**Seçim kuralı (karar):** Opus, kullanıcının hedefinden yukarıdaki tabloya göre bir şablon **önerir ve gerekçesini tek cümleyle söyler; kullanıcı onaylamadan üretmez.** Emin değilsen Onion'un getirdiği ek yükü (4 proje, repository + UoW) açıkça belirt.

## 2. Projeyi şablondan üretme (iskelet görevi Flash'a verilmez)

```bash
dotnet new list my-                      # my-onion / my-ntier kurulu mu?
dotnet new my-onion -n <Ad> -o <klasör>  # veya my-ntier
```
- Kurulu değilse kullanıcıya şablon klasörünü sor (ör. `<şablon-deposu>/2-Onion-Template`) ve `dotnet new install <klasör>` çalıştır. Klasörden kurulum kaynağı canlı okur; şablon güncellenince yeniden kurulum gerekmez.
- `-n` değeri C# ad alanına dönüşür (`my-shop` → `my_shop`, boşluk → `_`). Kullanıcıya bunu söyle; alt çizgi uyarısı (CA1707) şablonda kapalıdır.
- Port ve geliştirme `Jwt:SigningKey` her projede rastgele üretilir; restore otomatik çalışır.
- Üretimden sonra `CLAUDE.md` "Seviye" bölümü `seviyelendirme` skill'inin sonucuyla doldurulur.
- Hedef seviye şablon tabanından yüksekse reçeteler sırayla uygulanır; her reçete sonrası build + test (reçete README'si).
  Reçete uygulaması mekaniktir → Flash (görev dosyasında REFERANS: `recipes/<ad>/README.md`).
- Üretimden sonra **taban çizgisi**: §5 doğrulama komutları. Bu Opus'un kendisinin çalıştıracağı tek mekanik adımdır (devir maliyeti daha yüksek).

## 3. Şablon projesini tanıma ve PROJECT.md

Kökte `AGENTS.md` **ve** `docs/AI_WORKFLOW.md` varsa proje bu şablonlardan üretilmiştir. Tür: `Core/` klasörü varsa Onion, `<Ad>.Repositories/` varsa NTier.

Bu durumda **depo taraması yapma** (Flash/Haiku harita görevi yok). `PROJECT.md` şu kaynaklardan Opus tarafından ≤60 satırla doldurulur: `AGENTS.md` (kurallar), `docs/wiki/index.md` (modül haritası), `git log --oneline -10`, ve aşağıdaki REFERANS / KRİTİK listeleri. `docs/wiki/index.md`'de şablon dışı modüller varsa REFERANS listesini onlardan en olgun olanla güncelle.

## 4. Referans dosyalar ve kritik alanlar

`<Ad>` yerine projenin ad alanını koy.

**REFERANS (görev türü → taklit edilecek dosya):**

| Görev | Onion | NTier |
|---|---|---|
| Entity + configuration | `Core/<Ad>.Domain/Entities/Product.cs`, `Infrastructure/<Ad>.Infrastructure/Persistence/Configurations/ProductConfiguration.cs` | `<Ad>.Repositories/Products/Product.cs`, `.../ProductConfiguration.cs` |
| Repository | `Core/<Ad>.Application/Contracts/Persistence/IProductRepository.cs`, `Infrastructure/<Ad>.Infrastructure/Persistence/Repositories/ProductRepository.cs` (yalnızca gereken metotlar; IGenericRepository yok) | — (S1-S3'te repository yok; servis `AppDbContext` kullanır) |
| Servis (Feature-Service + ServiceResult) | `Core/<Ad>.Application/Features/Products/ProductService.cs` | `<Ad>.Services/Features/Products/ProductService.cs` (DbContext doğrudan) |
| Request + validator | `.../Features/Products/Create/CreateProductRequest(Validator).cs` | aynı alt yol, `<Ad>.Services` altında |
| Mapster | `.../Features/Products/ProductMappingConfig.cs` | aynı |
| Controller | `Presentation/<Ad>.WebAPI/Controllers/ProductsController.cs` | `<Ad>.API/Controllers/ProductsController.cs` |
| DI kaydı | `Core/<Ad>.Application/ServiceRegistration.cs`, `Infrastructure/<Ad>.Infrastructure/ServiceRegistration.cs` | `<Ad>.Services/Extensions/ServiceExtensions.cs`, `<Ad>.Repositories/Extensions/RepositoryExtensions.cs` |
| Olay + handler (yalnız Onion S4+, `recipes/S3-S4`) | `Core/<Ad>.Domain/Events/ProductAddedEvent.cs`, `Infrastructure/<Ad>.Infrastructure/Messaging/Consumers/ProductAddedEventHandler.cs` | — |
| Birim testi | `tests/<Ad>.UnitTests/ProductServiceTests.cs`, `ValidatorTests.cs` | aynı + `TestDb.cs` (SQLite in-memory; repository mock'u yok) |
| Entegrasyon testi | `tests/<Ad>.IntegrationTests/CatalogEndpointsTests.cs` (yardımcılar: `TestHelpers.cs`, `CustomWebApplicationFactory.cs`) | aynı |

Yeni entity için sıra her iki şablonda da `AGENTS.md` "Yeni entity checklist" bölümündedir; görev dosyasının ADIMLAR'ı bu sırayı izler.

**KRİTİK (`agent-model-routing` §4; bu yollara dokunan iş KRİTİK sayılır, Flash'a verilmez):**
- Kimlik ve oturum: Onion `Infrastructure/<Ad>.Infrastructure/Identity/**`; NTier `<Ad>.Services/Features/Auth/**`, `<Ad>.Services/Features/Users/**`, `<Ad>.Services/Identity/**`
- Pipeline güvenliği: `**/Extensions/AuthenticationExtensions.cs`, `RateLimiterExtensions.cs`, `ForwardedHeadersExtensions.cs`, `CorsExtensions.cs`, `SecurityHeadersExtensions.cs`
- `**/Services/CurrentUser*.cs`, `**/Interceptors/AuditDbContextInterceptor.cs`, `**/Context/AppDbContext.cs` (soft delete filtresi)
- Migration'lar: Onion `Infrastructure/<Ad>.Infrastructure/Persistence/Migrations/`; NTier `<Ad>.Repositories/Migrations/`
- `appsettings.Production.json`
- `recipes/**/files/**` altındaki kimlik/pipeline dosyaları (özelleştirilmiş projede elle birleştirme gerekirse)

## 5. Doğrulama

```bash
dotnet build <Ad>.slnx --nologo -v q
dotnet test <Ad>.slnx --nologo -v q     # MUTLAKA çözüm kökünde (global.json → Microsoft.Testing.Platform)
```
- Başka klasörden `dotnet test` "VSTest target is no longer supported" hatası verir; ajan hatası değildir.
- Hedef: 0 hata, 0 uyarı (`AI_WORKFLOW.md` §5.1).
- Migration komutları (yalnızca kod üretir; veritabanına UYGULAMA kullanıcı onayıyla, `agent-model-routing` §4):
  - Onion: `dotnet ef migrations add <Ad> --project ./Infrastructure/<Ad>.Infrastructure --startup-project ./Presentation/<Ad>.WebAPI`
  - NTier: `dotnet ef migrations add <Ad> --project ./<Ad>.Repositories --startup-project ./<Ad>.API`
- Canlı uç nokta denemesi **Development** ortamında yapılır (`--launch-profile http`; admin `admin@admin.com` / `appsettings.Development.json` → `Seed:AdminPassword`). Production'da `ConnectionStrings`, `Jwt:SigningKey`, `Cors:AllowedOrigins`, `AllowedHosts` ve `ForwardedHeaders` (KnownProxies/KnownNetworks veya NoProxy) verilmezse uygulama bilinçli olarak açılmaz.

## 6. Görev dosyası eklemeleri (şablon projelerinde zorunlu)

`agent-model-routing` §6 formatına şunlar eklenir:

```
REFERANS: §4 tablosundan + AGENTS.md
SKILL: dotnet-patterns YÜKLENMEZ (şablonun yasakladığı MediatR/AutoMapper/FluentAssertions kalıplarını önerebilir).
       api-design / security-review / test-driven-development gerektiğinde kullanılabilir.
KISITLAR: AGENTS.md "Değişmez kurallar" geçerlidir. Özetle:
  - Yasaklı paketler: AutoMapper, MediatR, Swashbuckle, MassTransit, Finbuckle.MultiTenant, Ardalis.Specification,
    FluentValidation.AspNetCore, FluentAssertions. Paket sürümü yalnızca Directory.Packages.props'ta.
  - Servisler ServiceResult/ServiceResult<T> döner; iş hatası için exception yok.
  - Id Guid (Guid.CreateVersion7()); mapping yalnızca Mapster; her async metotta CancellationToken; zaman için TimeProvider.
  - Controller CustomBaseController'dan türer, tek satır CreateActionResult(...); Entity dışarı açılmaz.
  - Kullanıcı kimliği yalnızca ICurrentUserService.UserId; endpoint userId parametresi almaz (IDOR).
  - Onion: Application'a EF Core / ASP.NET Core paketi eklenmez; repository'ye genel IQueryable/Where eklenmez, amaca özel metot yazılır.
  - Testlerde xUnit Assert (FluentAssertions yok).
  - docs/wiki/ dosyalarına DOKUNMA (Opus yazar, §7).
KABUL: yeni modül ekleyen görevde "docs/wiki/index.md'ye tek satır" maddesi (yalnızca index; log.md Opus'ta).
DOĞRULAMA: §5 komutları.
```

**Test tuzakları (KABUL yazarken):**
- Entegrasyon testleri SQLite in-memory'de çalışır ve SQLite `rowversion` üretmez (`TestAppDbContext`). RowVersion/409 eşzamanlılık davranışını entegrasyon testinde isteme; birim testinde `SetOriginalRowVersion` çağrısıyla doğrula (`ProductServiceTests.UpdateStockAsync_...` örneği).
- N-Tier S1-S2'de RowVersion yoktur; S3'te (reçete sonrası) RowVersion birim testi `TestDb` + `IsConcurrencyToken(true).ValueGeneratedNever()` ile yazılır (`DbUpdateConcurrencyException`).
- Kimliği doğrulanmış uçları test ederken `CustomWebApplicationFactory.GetAdminAccessTokenAsync` ve `TestHelpers.RegisterAndLoginAsync` (S2+) / `factory.CreateUserAndLoginAsync` (S1) kullanılır.
- Register `Registration:AllowPublic` ayarına bağlıdır (varsayılan kapalı = yalnızca Admin); `TestHelpers` kapalı modda da çalışsın diye admin token'ıyla kayıt yapar.
- Security stamp değişen işlemlerden (logout, şifre/e-posta/kullanıcı adı değişikliği, hesap silme) sonra eski access token 401 döner; testte yeniden giriş yap.

## 7. Proje kurallarıyla orkestranın birleşimi (kullanıcı kararları)

1. **Onay (A1):** `AI_WORKFLOW.md`'deki plan modu ve "rapor → onay → uygula" **dalga başına bir kez** uygulanır: Opus dalganın planını ve görev listesini (her görevin modeli ve KRİTİK işareti dahil) kullanıcıya gösterir, onaydan sonra dalga içi görevler onaysız devredilir. Code review / audit bulguları ise uygulanmadan önce her zaman ayrıca onaylatılır.
2. **Wiki (B1):** `docs/wiki/log.md` kaydını dalga sonunda **Opus** yazar (en fazla 5 satır, `## [YYYY-AA-GG] [INGEST|REVIEW|LINT] | ...` biçiminde, dosyanın en üstüne) ve dalga commit'ine dahil eder. `index.md` satırı yeni modül ekleyen görevin KABUL'ündedir; Opus final review'da kontrol eder. `STATE.md` (geçici, git dışı) ile wiki (kalıcı) birbirinin yerine geçmez.
3. **Commit (C1):** Mesajlar Türkçe, Türkçe karakterler eksiksiz, kısa emir kipi özet satırı + madde madde gövde. **`Co-Authored-By`, "Generated with", 🤖 gibi yapay zeka referansları eklenmez** (Claude Code'un varsayılan atıf satırı dahil). Commit öncesi `git status` ile `bin/`, `obj/`, `logs/`, gerçek bağlantı şifreleri kontrol edilir.
4. **Skill (D1):** Şablon projelerinde ECC `dotnet-patterns` hiçbir ajana yüklenmez; desen kaynağı REFERANS dosyalar ve `AGENTS.md`'dir.
5. **Şablon seçimi (E1):** §1 seçim kuralı.

## 8. Sistem denetimi

Proje `docs/SYSTEM_AUDIT.md` içerir. Kullanıcı "denetim/audit" istediğinde rapor bu metodolojiye göre yazılır; ağır tarama kısmı ucuz ajana (flash-low → haiku-scout) "bulgu listesi + dosya:satır" görevi olarak verilir, önceliklendirme ve rapor Opus'tadır. Güvenlik bulguları KRİTİK alana düştüğünden düzeltmeleri `agent-model-routing` §4 zinciriyle yapılır ve çapraz incelenir.
