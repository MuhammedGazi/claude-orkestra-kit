# Üçüncü Taraf Bileşenler (Third-Party)

Bu kit **üçüncü taraf skill veya plugin içermez ve kurmaz**. Aşağıdaki bileşenler orkestra düzeninde isteğe bağlı olarak kullanılabilir; her biri kendi resmi kaynağından kullanıcı tarafından kurulur.

## Güvenli (Kurulum Önerilen)

| Bileşen | Resmi Kaynak | Lisans | Kurulum Yolu | Dikkat Notu |
|---|---|---|---|---|
| `dotnet-patterns` | `affaan-m/ECC` (`v2.2.3`, commit `c05b2d66`) | MIT | `git clone --depth 1 --filter=blob:none --sparse --branch v2.2.3 https://github.com/affaan-m/ECC.git` ardından `sparse-checkout set skills/dotnet-patterns` | Tam ECC plugin'i (`ecc@ecc`, `npx ecc-universal`) 314 skill ve hook kurar; yalnızca skill klasörü alınmalı, MIT telif notu korunmalıdır. |
| `api-design` | `affaan-m/ECC` (`v2.2.3`) | MIT | Aynı sparse-checkout komutuyla `skills/api-design` | Aynı şekilde tam plugin yerine yalnızca skill klasörü alınmalıdır. |
| `security-review` | `affaan-m/ECC` (`v2.2.3`) | MIT | Aynı sparse-checkout komutuyla `skills/security-review` | Aynı şekilde tam plugin yerine yalnızca skill klasörü alınmalıdır. |
| `angular-developer` | `angular/skills` (commit `c86b20dc9233ecdb52928b336c2b2b87be9d2692`) | Lisans doğrulanmadı, resmi depodan kontrol edin (`SKILL.md` frontmatter'da MIT geçer, repo kök `LICENSE` doğrulanamadı) | Resmi README'yi izleyin veya `git clone --depth 1 https://github.com/angular/skills.git` ile `angular-developer` klasörünü kopyalayın | ECC'deki eski kopya yerine upstream `angular/skills` kullanılmalıdır. `npx skills add` önerilmez. Yeni Angular sürümlerini (Signal Forms v22 vb.) varsayar. |
| `superpowers` (`7.0.2`) | `obra/superpowers` (`claude-plugins-official`, sha `22f0b463`) | MIT | `claude plugin marketplace add anthropics/claude-plugins-official` ve `claude plugin install superpowers@claude-plugins-official` | `SessionStart` hook'u içerir (ağ çağrısı yok). Orkestra düzeninde `subagent-driven-development`, `dispatching-parallel-agents`, `executing-plans`, `requesting-code-review` kullanılmaz. |
| `code-review` (`1.0.1`) | `anthropics/claude-plugins-official` (`plugins/code-review`) | Lisans doğrulanmadı, resmi depodan kontrol edin | `claude plugin install code-review@claude-plugins-official` | Hook/betik içermez. 5 paralel Sonnet çalıştırdığı için yalnızca kullanıcı istediğinde kullanılır. |

## Dikkatli (İsteğe Bağlı / Ek Riskli)

| Bileşen | Resmi Kaynak | Lisans | Kurulum Yolu | Dikkat Notu |
|---|---|---|---|---|
| `impeccable` | `pbakaus/impeccable` (tag `skill-v4.9.1`, commit `acb4cfe1`) | Apache-2.0 (`LICENSE` + `NOTICE.md`) | Resmi README'yi izleyin (en dar yol: sabit tag'den yalnızca `.claude/skills/impeccable` kopyalama; plugin yolu: `claude plugin marketplace add pbakaus/impeccable` + `claude plugin install impeccable@impeccable`) | Plugin kurulumu `SessionStart`/`PostToolUse`/`Stop` hook'ları kurar. İlk kullanımda ~20 MB Rust `engine` binary'sini sha256 doğrulamalı indirir. Varsayılan açık telemetri içerir; `DO_NOT_TRACK=1` veya `IMPECCABLE_NO_TELEMETRY=1` ile kapatılır. |
| `playwright-cli` | `microsoft/playwright-cli` (tag `v0.5.2`, commit `b2172488`) | Apache-2.0 | Resmi README'yi izleyin (`npm install -g @playwright/cli@<sürüm>` + `playwright-cli install --skills` veya repodan `skills/playwright-cli` kopyalama) | `SKILL.md` içindeki `allowed-tools` satırı `playwright-cli` ve `npx playwright` komutlarına izin verir. Tarayıcı oturum/cookie erişimi ve npm sürüm pinlemesi dikkate alınmalıdır. |
| `hookify` (`0.1.1`) | `anthropics/claude-plugins-official` (`plugins/hookify`) | Lisans doğrulanmadı, resmi depodan kontrol edin | `claude plugin install hookify@claude-plugins-official` | 4 olayda (`PreToolUse`, `PostToolUse`, `Stop`, `UserPromptSubmit`) `python3 hooks/*.py` çalıştırır. Python gerektirir; yalnızca ihtiyaç duyulduğunda kurulmalıdır. |
| `security-guidance` (`2.0.20`) | `anthropics/claude-plugins-official` (`plugins/security-guidance`, sha `f75f5b25`) | Lisans doğrulanmadı, resmi depodan kontrol edin | `claude plugin install security-guidance@claude-plugins-official` | Geniş hook yüzeyi: `SessionStart`'ta `venv` + `pip install` yapar; commit/push sonrası ve `Stop`'ta kod diff'lerini `ANTHROPIC_API_KEY`/`ANTHROPIC_AUTH_TOKEN` ile LLM API'ye gönderir. |
| `andrej-karpathy-skills` (`1.0.0`) | `forrestchang/andrej-karpathy-skills` (sha `2c60614`) | Lisans doğrulanmadı, resmi depodan kontrol edin (README'de MIT belirtilmiş, repo kök `LICENSE` dosyası yok) | `claude plugin marketplace add forrestchang/andrej-karpathy-skills` ve `claude plugin install andrej-karpathy-skills@karpathy-skills` | Resmi Karpathy reposu değildir. Repo kökünde `LICENSE` dosyası yoktur ve marketplace kurulumu güncel `main` dalına göre çözülür. |
