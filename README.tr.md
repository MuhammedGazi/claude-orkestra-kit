# claude-orkestra-kit

Claude Code (Opus şef) ve Antigravity CLI `agy` (Gemini Hydrogen/Argon/Flash) arasında iş bölümü yapan, çok modelli orkestra kuralları, alt ajan tanımları ve Windows kurulum/yürütme betikleri kitidir. Amaç, pahalı Opus kotasını yalnızca planlama, görev yazımı ve karar için koruyup uygulama, tarama, test ve çapraz incelemeyi `agy` ile Claude alt ajanlarına dağıtmaktır.

## Kadro

| Rol / Kod | Model | Havuz | Görev |
|---|---|---|---|
| **Opus (Şef)** | Opus 5.5 ana oturum | Claude | Plan, mimari karar, görev dosyası, kabul/ret, `STATE.md`, commit (kod yazmaz) |
| **hydrogen-xhigh/high/medium/low** | Gemini 4 Hydrogen | Google Gemini | Ana işçi: zor/kritik backend (`xhigh`), orta özellikler (`medium`/`high`), düzeltme turları |
| **argon-high/medium** | Gemini 4 Argon | Google premium | Danışma, mimari ikinci görüş, Hydrogen diff çapraz incelemesi |
| **flash-high/medium/low** | Gemini 3.8 Flash | Google Flash | Ayak işi: CRUD, DTO, validator, unit test, tarama, harita, mekanik değişiklik |
| **runner (`wave-runner`)** | Haiku 5.5 alt ajan (`low`) | Claude | `agy` görevlerini çalıştırır, `diff --stat` ve build/test sonucunu özetler |
| **haiku-scout** | Haiku 5.5 alt ajan (`low`) | Claude | Repo tarama, log/hata özeti, komut çalıştırma, mekanik düzenleme |
| **sonnet-dev / sonnet-dev-medium** | Sonnet 5.5 alt ajan (`high`/`medium`) | Claude | Claude tarafı uygulayıcı: hassas yama, `agy` düzeltme, `agy` kotası bitince devralma |
| **opus-dev** | Opus 5.5 alt ajan (`high`) | Claude | Yalnızca `KRİTİK` işin çekirdeği için kısa gir-çık (diğerleri yapamadıysa) |

## Gereksinimler

- **Zorunlu:** Windows 10/11 (PowerShell 5.1), Claude Code, Git for Windows (Git Bash)
- **İsteğe bağlı:** Antigravity CLI (`agy`), Node.js

## Kurulum

Önce `-DryRun` ile neyin değişeceğini görün, ardından kurulumu çalıştırın:

```powershell
# 1. Deneme modu (dosya yazmaz, yedek almaz)
.\install.ps1 -DryRun

# 2. Gerçek kurulum
.\install.ps1
```

Diğer seçenekler:

```powershell
# Yalnızca seçili bileşenleri kur (geçerli değerler: skills, agents, claudemd, settings, gemini)
.\install.ps1 -Only skills,agents

# Mevcut settings.json içindeki yalnızca statusLine ayarını değiştir
.\install.ps1 -Force

# Test/izolasyon için farklı bir hedef kullanıcı klasörüne kur (varsayılan: $env:USERPROFILE)
.\install.ps1 -TargetHome "D:\test-home" -DryRun
```

Sistemde `agy` (Antigravity CLI) kuruluysa, Windows'ta kurulum sonrası Gemini skill eşitleme betiğini `--copy` ile çalıştırın:

```bash
bash ~/.claude/skills/agent-model-routing/scripts/sync-gemini-skills.sh --copy
```

## Ne Kurulur / Neye Dokunur?

- `skills`: `~/.claude/skills/` altına kit skill'lerini kopyalar (`agent-model-routing`, `orkestra-baslat`, `seviyelendirme`, `dotnet-sablonlar`).
- `agents`: `~/.claude/agents/` altına alt ajan tanımlarını kopyalar (`haiku-scout`, `sonnet-dev`, `sonnet-dev-medium`, `opus-dev`, `wave-runner`).
- `claudemd`: `~/.claude/CLAUDE.md` içine `<!-- orkestra-kit:start --> ... <!-- orkestra-kit:end -->` işaretli bölümü ekler veya günceller; dosya dışındaki satırlarınıza dokunmaz.
- `gemini`: `~/.gemini/GEMINI.md` içine aynı işaretli bölümü ekler veya günceller.
- `settings`: `~/.claude/settings.json` içine `permissions.allow` kurallarını yinelemesiz birleştirir; `statusLine` yoksa ekler (varsa yalnızca `-Force` ile değiştirir).
- **Yedekleme:** Değiştirilen mevcut dosyalar kurulum öncesi `~/.claude/backups/orkestra-kit-<zaman>/` altına yedeklenir.

## Geri Alma

Önce `-DryRun` ile neyin geri yükleneceğini/silineceğini önizleyin, ardından kurulum sırasında oluşturulan yedek klasörüyle `-Restore` çalıştırın (`manifest.json` üzerinden yeni oluşturulanları siler, değiştirilenleri geri yükler; içeriği aynı olan dosyalara dokunmaz):

```powershell
# 1. Geri alınacak değişiklikleri listele
.\install.ps1 -Restore "$env:USERPROFILE\.claude\backups\orkestra-kit-<zaman>" -DryRun

# 2. Geri yüklemeyi uygula
.\install.ps1 -Restore "$env:USERPROFILE\.claude\backups\orkestra-kit-<zaman>"
```

## Kullanım

- Bir projeye başlarken Claude Code oturumunda `/orkestra-baslat` yazın; proje haritası (`.claude/orchestra/PROJECT.md`), `STATE.md` ve `CLAUDE.md` orkestra bölümü hazırlanır.
- Projede `Seviye:` satırı yoksa `seviyelendirme` skill'i projenin ölçeğini (`S1`–`S5`) ve risk etiketlerini belirler.
- Her dalga sonunda `.claude/orchestra/STATE.md` güncellenir; yeni oturum açıp `devam` yazarak kaldığınız yerden sürdürebilirsiniz.

## Yalnızca Claude Modu

Sistemde `agy` kurulu değilse `install.ps1` uyarı verir ve kurulum yine tamamlanır. Çalışma sırasında orkestra otomatik olarak **Yalnızca Claude modu**na geçer; işler `sonnet-dev`, `sonnet-dev-medium` ve `haiku-scout` alt ajanlarıyla yürütülür.

## Önerilen 3. Taraf Eklentiler

Üçüncü taraf skill ve plugin'ler bu kite dahil değildir. İnceleme notları ve resmi kurulum yolları için [THIRD_PARTY.md](THIRD_PARTY.md) dosyasına bakın.

> **.NET şablonları notu:** `my-onion` ve `my-ntier` .NET şablonları bu kite **dahil değildir**. `dotnet-sablonlar` skill'i bu şablonların ayrıca kurulmuş olduğunu varsayar.

## Lisans

[MIT](LICENSE) — Yazar: MuhammedGazi ([github.com/MuhammedGazi](https://github.com/MuhammedGazi))
