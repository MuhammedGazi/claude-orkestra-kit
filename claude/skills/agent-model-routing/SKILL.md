---
name: agent-model-routing
description: Orkestra kuralları - Opus 5.5 yalnızca şef (plan, görev dosyası, karar; kod yazmaz); işin çoğu agy tarafında (Gemini 4 Hydrogen, Gemini 4 Argon, Gemini 3.8 Flash), Claude tarafında Sonnet 5.5 (high) asıl uygulayıcı, Haiku 5.5 ayak işi, Opus 5.5 alt ajan yalnızca kritik noktada kısa gir-çık. Alt ajana iş devretmeden, `agy` çağırmadan, repo taramadan, review veya kota kararı vermeden önce MUTLAKA oku. "delege et", "agy", "Argon", "Hydrogen", "Flash", "swarm", "Haiku", "Sonnet", "alt ajan", "kota", "limit", "ikinci görüş", "kritik", "devam" dendiğinde veya 5+ dosyalık iş, CRUD/DTO/test, concurrency, refactoring, bug analizi geldiğinde tetikle.
---

# Agent Model Routing (Orkestra)

**Kullanıcı kararı (2026-11-14):** Claude kotası çok hızlı bitiyordu; kodu Hydrogen yazsa bile Opus düzeltmeleri kendisi yapıyor, her devirde diff/build/test turunu kendisi dönüyor, kota kontrolünü her devirden önce tekrarlıyordu. Büyük bağlamda **Opus'un her araç çağrısı tüm bağlamı yeniden okur**; asıl maliyet buydu. Yeni düzen:

- **Ağırlık agy tarafında** (Google kotası bol): Hydrogen ana işçi, Argon danışma/inceleme, Flash ayak işi.
- **Claude tarafında asıl işçi Sonnet 5.5 (high)**, ayak işi Haiku 5.5. Opus 5.5 alt ajan yalnızca kritik noktada kısa iş yapıp çıkar.
- **Opus 5.5 ana oturum = yalnızca şef.**

Seviye: projenin `CLAUDE.md` dosyasındaki `Seviye:` satırını oku ve `references/seviyeler.md` tablosunu uygula. Satır yoksa önce `seviyelendirme`; o zamana kadar S2 varsay.

Script'ler (`S=~/.claude/skills/agent-model-routing/scripts`, yol boşluk içerebilir: her zaman `"$S/..."` tırnaklı):
`quota-check.sh` (kota etiketleri) · `agy-run.sh` (run / consult / rollback / usage / permcheck) · `statusline.sh`.

## 0. Şefin sınırı (en önemli bölüm)

**Opus (ana oturum) YAPAR:** hedefi netleştirme, mimari karar, işi görevlere bölme, görev dosyası yazma (kalıptan türeterek), model/tier seçimi, kısa raporları okuyup kabul/ret, kullanıcıyla konuşma, STATE.md'yi güncelleme, commit.

**Opus YAPMAZ (kaç satır olursa olsun):**
- Kaynak kod, test, migration, config yazmak veya düzeltmek. "3 satırlık düzeltme" bile görev olur → hydrogen (normal) ya da sonnet-dev (hassas yama).
- Repo taramak, dosya okumak için Read/rg turu atmak → haiku-scout veya `consult flash-low`.
- agy görevlerini kendisi çalıştırıp diff/build/test turunu kendisi dönmek → **runner** (§5). Tek görev bile olsa.
- Build/test/curl/`dotnet new`/`dotnet ef` komutlarını kendisi çalıştırmak → runner veya haiku-scout.
- Review çıktısını tam okuyup ayıklamak → incelemeci zaten "önem sırasına göre ≤15 madde" yazar; Opus yalnızca o listeye karar verir.
- Uzun belge (design doc, plan, README bölümü) yazmak → Opus kararları madde madde verir, metni `run hydrogen-medium` yazar.
- Context7, playwright-cli, `/code-review`'ı kendisi çalıştırmak.

**Opus'un kendine izin verilenler:** STATE.md, görev dosyaları (`/tmp/agy-tasks`, `.claude/tasks`), proje `CLAUDE.md` orkestra bölümü, şablon projesinde `docs/wiki/log.md` dalga kaydı (≤5 satır), `git status --short` / `git diff --stat` / `git log --oneline -5`, rollback, commit. Bunun dışında bir dosyaya bakması gerekiyorsa yalnızca hedefli satır aralığı ve yalnızca karar için.

**Bağlam disiplini:** Her dalga sonunda STATE.md güncellenir ve kullanıcıya **"yeni oturum açıp `devam` yaz"** önerilir. Bir oturumda en fazla 1-2 dalga. Ana oturum effort'u medium; yalnızca mimari yol ayrımında high.

## 1. Kadro

| Kod | Model | Havuz | Görev |
|---|---|---|---|
| **Opus** | Opus 5.5 ana oturum | Claude | Yalnızca şef (§0) |
| **hydrogen-xhigh/high/medium/low** | Gemini 4 Hydrogen | Google "Gemini Models" (Flash ile ortak, bol) | **Ana işçi.** Zor backend ve KRİTİK: xhigh · orta özellik: medium/high · düzeltme turları |
| **argon-high/medium** | Gemini 4 Argon | Google premium (kıt) | **Danışma ve inceleme:** mimari ikinci görüş, Hydrogen'in diff'ini çapraz inceleme, Hydrogen'in iki kez kaldığı iş |
| **flash-high/medium/low** | Gemini 3.8 Flash | Google Flash (bol) | **Ayak işi:** CRUD, DTO, mapping, validator, unit test, Angular iskelet, tarama, harita, mekanik değişiklik |
| **runner** | `wave-runner`: Haiku 5.5 alt ajan (low) | Claude (en ucuz) | agy görevlerini çalıştırır, diff --stat + build/test, görev başına ≤6 satır rapor (§5). Karar vermez |
| **haiku-scout** | Haiku 5.5 alt ajan (low) | Claude (ucuz) | Tarama, log/hata özeti, Context7 özeti, playwright, mekanik düzenleme, komut çalıştırma |
| **sonnet-dev** | Sonnet 5.5 alt ajan (**high**, varsayılan) | Claude | Claude tarafının asıl uygulayıcısı: hassas yama, agy'nin bozduğunu düzeltme, agy kotası bitince devralma |
| **sonnet-dev-medium** | Sonnet 5.5 alt ajan (medium) | Claude | High'ın gereksiz olduğu küçük/net yamalar; Claude KIT iken |
| **opus-dev** | Opus 5.5 alt ajan (high) | Claude (en pahalı) | Yalnızca KRİTİK işin **çekirdeği**, diğerleri yapamadıysa; kısa gir-çık (§4) |

- **agy:sonnet / agy:opus / gpt-oss zincirlerde yoktur** (Google'ın "Claude and GPT" kovası çok düşük). Kullanıcı açıkça isterse istisna.
- **agy `/swarm` kullanılmaz** (kota ağır, ikinci şef yaratır, DOSYALAR/rollback düzenini atlar).
- **Argon bütçesi:** oturum başına haftalık kotanın en fazla %5'i (`ARGON_SESSION_BUDGET`); quota-check "BÜTÇE DOLDU" derse Argon'un yerine `consult hydrogen-xhigh` geçer. Argon ≥%90 ise yalnızca KRİTİK incelemeye. Antigravity'de AI Credit Overages = Never.
- **Claude havuzu tek:** Opus, opus-dev, sonnet-dev, haiku-scout, runner ve claude.ai sohbeti aynı limiti paylaşır. Maliyet: Opus > Sonnet > Haiku.

## 2. Kota kontrolü (seyrek)

Yalnızca şu anlarda (her devirden önce DEĞİL):
1. Oturum başında: `"$S/quota-check.sh" --session-start` (+ bir kez `"$S/agy-run.sh" permcheck`). Masaüstünde önce `mcp__ccd_session_mgmt__get_usage` → `--set-claude <5s_%> <5s_resetsAt> <7g_%> <7g_resetsAt>`.
2. Her **dalga** başında bir kez (aynı yöntem).
3. Exit 4 (kota) sonrası: `--refresh`.

Etiketler (her havuz ayrı; STALE/UNKNOWN/ERROR olan havuz en fazla NORMAL sayılır):

| Etiket | Koşul | Davranış |
|---|---|---|
| **DUR** | 5s ≥ %90 veya 7g ≥ %97 | Havuzu kullanma. Claude ise §7 duraklat |
| **KIT** | 5s ≥ %75 veya tempo > +10 | Claude KIT: opus-dev yok, sonnet-dev yerine sonnet-dev-medium, mümkün olan her şey agy'ye. Argon KIT: Argon yerine hydrogen-xhigh |
| **NORMAL** | diğer | §3 zincirleri |
| **BOL** | tempo < −15 veya hafta < 24 saatte bitiyor ve 7g < %70 | Claude BOL bile olsa **Opus kod yazmaz**; yalnızca sonnet-dev zincirde bir basamak öne geçebilir |

Tempo = haftalık kullanılan % − haftanın geçen %'si. Claude 5s penceresinin son %15'i şefliğe ayrılmıştır: alt ajanlar %75'te durur.

## 3. Yönlendirme zincirleri

Soldan sağa, DUR/KIT olmayan ve son 5 saatte exit 4 vermemiş ilk aday. **Hiçbir zincirin sonunda "Opus kendisi yapar" yoktur**; zincir tükenirse görev bölünür veya §7'ye göre durulur.

| İş türü | Zincir |
|---|---|
| Mimari, plan, görev bölme, karar | Opus (metni gerekiyorsa hydrogen-medium yazar) |
| **KRİTİK** (§4) | hydrogen-xhigh → argon-high → sonnet-dev → opus-dev (yalnızca çekirdek) |
| Zor backend: concurrency, EF transaction, algoritma, derin bug, zor refactor | hydrogen-xhigh → argon-high → sonnet-dev |
| Orta: çok dosyalı özellik (servis + controller + test) | hydrogen-medium → hydrogen-high → flash-high → sonnet-dev |
| Basit: CRUD, DTO, validator, unit test, Angular form/servis iskeleti | flash-medium → flash-high → hydrogen-low → sonnet-dev-medium |
| Çok mekanik: rename, yorum, boilerplate | flash-low → haiku-scout |
| Tarama/özet/harita, "nerede kullanılıyor", log, build hatası analizi | consult flash-low → haiku-scout → consult flash-medium |
| Hassas yama, agy çıktısını düzeltme, review bulgusunu uygulama | hydrogen-medium (düzeltme görevi) → sonnet-dev → sonnet-dev-medium |
| İkinci görüş / mimari danışma | consult argon-high → consult hydrogen-xhigh |
| Diff incelemesi (her dalga) | Hydrogen yazdıysa **consult argon-high**; Flash/Argon/Claude yazdıysa **consult hydrogen-xhigh**; Argon bütçesi doluysa Hydrogen'in işine consult flash-high |
| Düzeltme turu incelemesi | consult flash-high → consult hydrogen-medium (yazan değilse) |
| Uzun belge (design doc, plan metni, README) | run hydrogen-medium (Opus'un karar maddeleriyle) |
| UI/tasarım uygulaması (Impeccable uygulama komutları, Stitch) | flash-high → hydrogen-medium → sonnet-dev |
| Tarayıcı/E2E (playwright-cli) | flash-low (§5b) → haiku-scout |
| Komut çalıştırma | build/test/curl: runner · dosya üreten komut (`dotnet new`, `dotnet ef migrations add`): haiku-scout |

Kalite kuralları:
- Bir agy modeli aynı görevde **2 kez** doğrulamadan kalırsa → rollback, zincirde sonraki. Hydrogen iki kez kaldıysa Argon'a, Argon da kalırsa sonnet-dev'e.
- sonnet-dev-medium kalırsa bir kez sonnet-dev (high); o da kalırsa görev bölünür. opus-dev'e yükseltme yalnızca KRİTİK çekirdekte.
- Belirsizse: küçük ve net → Flash; orta → hydrogen-medium; zor/riskli → hydrogen-xhigh; tek dosya ve çok hassas → sonnet-dev.

## 4. Kritik görevler

**Kritik:** ödeme, yetkilendirme/kimlik doğrulama, veri kaybı riski taşıyan migration veya toplu veri işlemi, karmaşık concurrency, güvenlik açığı düzeltmesi, geri alınması zor her şey. Görev dosyasının başına `KRİTİK: evet`.

1. **Zincir:** hydrogen-xhigh → argon-high → sonnet-dev → opus-dev. Claude KIT/DUR iken sonnet-dev ve opus-dev atlanır; zincir tükenirse §7.
2. **opus-dev = kısa gir-çık:** Yalnızca agy zinciri ve sonnet-dev bu işi yapamadıysa ya da Opus "bu çekirdek çok ince" diye karar verip gerekçesini STATE.md'ye yazdıysa. Görev dosyası **tek çekirdek** içerir (≤3 dosya: sözleşme veya kritik metot); mekanik yayılım ayrı Flash/Hydrogen görevidir. 5s penceresinde en fazla 1 opus-dev (`OPUS_DEV_MAX=1`). Çağrıdan sonra `"$S/quota-check.sh" --log-subagent opus-dev <görev>`.
3. **Çapraz inceleme zorunlu, yazan incelemez:** Hydrogen yazdıysa → `consult argon-high` (bütçe doluysa sonnet-dev salt okuma inceleme); Argon veya Claude ajanı yazdıysa → `consult hydrogen-xhigh`. Düzeltme turunun incelemesi: `consult hydrogen-medium` veya `consult flash-high` (yazan değilse).
4. İnceleme görevi: diff + görevin HEDEF/KABUL'ü + iki kontrol listesi (uygulama: IDOR/rol, girdi doğrulama, veri erişimi, hata sızıntısı, config; migration/test: drop/rename, nullable, index/FK, `Down`, testler davranışı gerçekten doğruluyor mu). "Bul, düzeltme yazma; önem sırasına göre en fazla 15 madde, her madde tek satır + dosya:satır." `*.Designer.cs`, `*ModelSnapshot.cs`, `package-lock.json`, `bin/obj/dist` dışlanır; migration ve testler dışlanmaz. 1.000 satırı aşan diff modül başına bölünür.
5. Bulgular kullanıcıya kısa özetlenir, onaylananlar **düzeltme görevi** olarak Hydrogen'e gider (Opus düzeltmez).
6. Geri alınamaz adım (migration uygulama, veri silme) yalnızca kullanıcı onayıyla; komutu runner/haiku-scout çalıştırır.
7. Flash'a kritik iş verilmez, alt parçası bile.

## 5. Yürütme döngüsü: runner

Opus agy'yi kendisi çalıştırmaz. Bir dalgadaki agy görevleri (tek görev dahil) **runner**'a verilir:

- **Çağrı:** Agent `wave-runner` (Haiku). Prompt: sıralı liste `<görev dosyası> <tier> [--worktree]`, DOĞRULAMA komutları, "hepsi geçerse devam et" ya da "her görevden sonra dur". Bağımsız consult'lar (inceleme) aynı çağrıda listelenebilir.
- **Runner yapar:** `agy-run.sh run/consult`, `git diff --stat`, DOSYALAR dışı dosya kontrolü, build/test (`| tail -n 15`), görev başına ≤6 satır rapor. consult çıktısından yalnızca bulgu satırlarını taşır.
- **Runner yapmaz:** kabul/ret, rollback, tier değiştirme, dosya düzenleme, commit. exit ≠ 0, doğrulama hatası veya plan dışı durumda durur ve raporlar.
- **Opus raporu okur ve karar verir:** kabul → commit (proje kuralına göre) · ret → `"$S/agy-run.sh" rollback <görev>` (kuru) → `--yes` → zincirde sonraki tier ile runner'a yeniden verir. Opus diff'in kendisine yalnızca rapordaki "riskli hunk" satırları için hedefli bakar.
- Alt ajan (sonnet-dev / opus-dev / haiku-scout) görevlerini Opus doğrudan Agent ile çağırır (runner alt ajan açamaz). Alt ajanlar için de önce temiz ağaç; başarısızlıkta körlemesine `git reset --hard`/`git clean` yok, yalnızca görevin dosyaları `git restore --source=<base>` ile.

### 5a. agy çağrısı (runner ve Opus için başvuru)

```bash
S=~/.claude/skills/agent-model-routing/scripts
"$S/agy-run.sh" run hydrogen-xhigh /tmp/agy-tasks/T1.md
"$S/agy-run.sh" run --worktree flash-medium /tmp/agy-tasks/T4.md   # paralel iş varken
"$S/agy-run.sh" consult /tmp/agy-tasks/R1.md argon-high           # salt okuma: inceleme/danışma
"$S/agy-run.sh" rollback /tmp/agy-tasks/T1.md                     # kuru; sonra --yes
AGY_TIMEOUT=1500 "$S/agy-run.sh" run hydrogen-xhigh ...           # uzun iş
```
Tier'lar: `hydrogen-xhigh|high|medium|low`, `argon-high|medium|low`, `flash-high|medium|low` (kısayol: `hydrogen`=high, `argon`=argon-high, `flash`=flash-medium).

| Çıkış | Anlam | Yapılacak |
|---|---|---|
| 0 | Başarılı | diff --stat → doğrulama → Opus kabul/ret |
| 1 | Hata/timeout | rollback, zincirde sonraki (timeout bir kez uzun `AGY_TIMEOUT` ile denenebilir) |
| 2 | Ön koşul (kirli ağaç, geçersiz tier) | düzelt, tekrar |
| 3 | Belirsiz (boş çıktı, worktree yaması uygulanamadı) | `git status`/diff; izin reddiyse görev dosyasına izinli komut bloğu |
| 4 | Kota | aynı tier'ı TEKRARLAMA; rollback → `quota-check.sh --refresh` → sonraki |

agy kuralları (öğrenilmiş tuzaklar):
- `--dangerously-skip-permissions` YOK. İzinler dar: salt okuma + build/test; silme ve proje dışı okuma kapalı. İzin listesine ekleme kullanıcıya sorulur.
- Her agy görev dosyasında **İZİNLİ KOMUTLAR** bloğu: "Yalnızca dotnet build/test, npx ng build/test, git status/diff/grep; zincirleme (`&&`, `;`, `|`) yok, `git ls-files` yok, MCP yok. Dosya silme yok: silinecekleri ÇIKTI'da listele."
- agy görevlerinde `SKILL:` satırı yazılmaz ve görev metninde skill adı (ör. "security-review") geçmez: headless agy `~/.gemini/skills` okuyamaz, okumaya çalışıp boş döner. Kontrol listesini görev dosyasına yaz. REFERANS dosyaları proje içinde olmalı.
- consult dosyası ~30 KB'ı aşarsa rc 126: diff'i `.claude/tasks/<id>.diff` dosyasına yaz, görevde "read_file ile oku" de.
- Devirden önce temiz ağaç (script zorlar). Paralel yazma: `--worktree` (Angular'da worktree'de `npm ci` gerekir; yalnızca gerçekten paralelken). Aynı anda en fazla 3 agy görevi, 1 yazan Claude alt ajanı; DOSYALAR kesişen görevler sıraya. Devirdeki görevler STATE.md'de `[~]`.
- Windows Git Bash: betiklerde `python` yok (node/awk). `/tmp/agy-tasks` = `C:\Users\<KISA~1>\AppData\Local\Temp\agy-tasks`; alt ajanlara Windows yolunu ver.

### 5b. agy ile E2E (playwright-cli)
Headless agy kendi açtığı tarayıcıyı korumaz. runner/haiku-scout önce `playwright-cli -s=<ad> open http://localhost:<port>` açar; agy görevi yalnızca `playwright-cli -s=<ad> <komut>` kullanır (open/close yok, `goto` adresi tırnaksız, ekran görüntüsü `--filename=.playwright-cli/<ad>/x.png`, komutlar tek tek, şifre yalnızca proje içi seed dosyasından ve ÇIKTI'ya yazılmaz); sonda runner `close` eder. `eval/upload/state-*/cookie-*/localstorage-*` kapalı.

## 6. Görev dosyası (isabet buna bağlı)

Repo dışında: `/tmp/agy-tasks/<id>.md`. Benzer görevler kalıptan `sed` ile türetilir; Opus uzun görev dosyasını bağlamda tekrar tekrar yazmaz.

```
KRİTİK: evet|hayır
HEDEF: <tek cümle>
BAĞLAM: <neden; ilgili karar 1-3 satır>
REFERANS: <taklit edilecek proje içi dosya>
DOSYALAR: <dokunulabilecek yollar; yeni dosyaların tam yolu>
ADIMLAR: 1. <sınıf/metot/alan adlarıyla somut adım> 2. ...
KISITLAR: <proje kuralları, yasak paketler, public API değiştirme yok>
İZİNLİ KOMUTLAR: <§5a bloğu>
KABUL: <gözlemlenebilir kriterler; KRİTİK'te hata/yarış senaryoları>
DOĞRULAMA: <komutlar>
ÇIKTI: En fazla 15 satır: değişen dosyalar, doğrulama sonucu, açık riskler, silinecek dosyalar. Kod yapıştırma.
```
- Flash: ≤5 dosya, ≤1 yeni kavram, REFERANS şart, ADIMLAR eksiksiz.
- Hydrogen/Argon: daha geniş olabilir; HEDEF ve KABUL kesin, ADIMLAR yerine yaklaşım yeterli.
- Alt ajan görevlerinde `SKILL:` satırı yazılabilir (Claude skill'lerini okuyabilirler).
- Şablon projelerinde (`AGENTS.md` + `docs/AI_WORKFLOW.md`): `dotnet-sablonlar` §6 ekleri (REFERANS, KISITLAR, KABUL); doğrulama `dotnet build/test <Ad>.slnx`.

**Danışma:** gerçek mimari yol ayrımında sorun + seçenekler ≤20 satır → `consult argon-high`. Görüş bağlayıcı değil; kararı Opus verir, STATE.md KARARLAR'a tek satır.

## 7. STATE.md, duraklatma, devam

`.claude/orchestra/STATE.md` (`.git/info/exclude` içinde; ağırlığı seviyeye göre, `references/seviyeler.md`). Opus her dalga sonunda günceller:
```
# STATE — <proje> — <tarih saat>
HEDEF: ...
KARARLAR: <karar, tek satır gerekçe>
GÖREVLER:
- [x] T1 <özet> (hydrogen-medium, doğrulandı, commit abc123)
- [~] T2 <özet> (hydrogen-xhigh, devirde) görev: /tmp/agy-tasks/T2.md
- [ ] T3 <özet> → önerilen: flash-medium
SONRAKİ ADIM: <tek cümle>
KOTA: Claude 5s %.. / 7g %.. | Gemini .. | Argon .. (saat)
```
`/tmp` silinebilir: devirdeki görevi STATE.md'de kısaca özetle. STATE.md 80 satırı aşarsa tamamlanan dalgalar tek satıra sıkıştırılır (her oturum bunu baştan okur).

**Claude DUR (5s ≥ %90 veya 7g ≥ %97):** yeni devir yok; süren agy işini bekle; commit veya rollback; STATE.md; kullanıcıya "Duruyorum. Claude kotası HH:MM'de yenileniyor. Devam için yeni oturumda `devam` yaz." (saat kullanıcının diliminde).
**Tüm agy havuzları DUR:** sonnet-dev(-medium) + haiku-scout ile devam, kullanıcıya bir satır.
**Devam:** STATE.md → quota-check → `git status` + `git log --oneline -3` → SONRAKİ ADIM.

Doğrulama geçmeden iş "tamam" sayılmaz; çalıştırılamadıysa "DOĞRULANAMADI". Sessizce iş atlama yok.

**Doğrulama kapısı:** Düşük risk: build + hedefli test + diff --stat. Orta: build + ilgili test paketi + bağımsız model incelemesi (§3). KRİTİK: build + tam test + §4 çapraz inceleme + insan onayı gereken adımlar işaretli.

## 8. Skill, plugin, MCP dağılımı

Temel kural: **token yiyen araç, onu en ucuza çalıştırabilecek ajana.** Bu skill'in kuralları Superpowers'tan önceliklidir.

| Araç | Kimde |
|---|---|
| Superpowers `brainstorming`, `writing-plans` | Opus, yalnızca yeni büyük özellikte; çıktı = karar maddeleri, metni hydrogen-medium yazar. Küçük işte atlanır |
| Superpowers `subagent-driven-development`, `dispatching-parallel-agents`, `executing-plans`, `requesting-code-review` | **KULLANILMAZ** (kota bilmeden Claude alt ajanı açar) |
| Superpowers `systematic-debugging` / `test-driven-development` | Hydrogen-xhigh / Flash görevine kontrol listesi olarak yazılır |
| `/code-review` (5 paralel Sonnet) | Yalnızca kullanıcı isterse. Normal inceleme §3 |
| `security-review` | Kontrol listesi inceleme görev dosyasına yazılır (agy'ye skill adıyla değil) |
| Context7, playwright-cli | haiku-scout veya agy uygulayıcı; Opus yalnızca ≤15 satır özet okur |
| Impeccable `shape`, `init`, `document` | Opus karar verir; dosya metnini hydrogen-medium yazar |
| Impeccable uygulama komutları, Stitch | flash-high → hydrogen-medium |
| `dotnet-sablonlar` | Opus (hafif) |
| ECC `dotnet-patterns`, `angular-developer` | Uygulayıcı; şablon projelerinde `dotnet-patterns` yüklenmez |
| hookify | Yalnızca kullanıcı isteyince |

Claude tarafına yeni skill kurulunca `"$S/sync-gemini-skills.sh"`.
