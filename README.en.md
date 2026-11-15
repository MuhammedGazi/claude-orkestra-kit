# claude-orkestra-kit

A multi-model orchestration kit of rules, subagents, and Windows scripts coordinating Claude Code (Opus as lead/conductor) and Antigravity CLI `agy` (Gemini Hydrogen/Argon/Flash).

[🇹🇷 Türkçe](README.md) | 🇬🇧 English

> Note: Skill and agent contents are in Turkish.

> [!WARNING]
> ⚠️ This kit was built for my personal and small-to-medium projects. It has not been tested on large-scale or enterprise projects. Installation modifies `~/.claude` and `~/.gemini` settings; back up before installing and review according to your own needs. The software is provided "as is" under the license without any warranty; use is at your own risk.

## 💡 Why?

This setup was created to use Claude Pro ($20) and Google Antigravity Pro subscriptions together efficiently. Because Claude quota runs out quickly, expensive Opus quota is reserved solely for the conductor role (planning, task authoring, and decisions), while most of the work is delegated to Gemini (`agy`) and to Sonnet/Haiku subagents on the Claude side.

## 📑 Table of Contents

- [Roster](#-roster)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [What Gets Installed / Modified](#-what-gets-installed--modified)
- [Rollback](#-rollback)
- [Usage](#-usage)
- [Claude-Only Mode](#-claude-only-mode)
- [Recommended Extensions](#-recommended-extensions)
- [Using Together](#-using-together)
- [Contributing](#-contributing)
- [License](#-license)

## 👥 Roster

| Role / Code | Model | Pool | Responsibility |
|---|---|---|---|
| **Opus (Conductor)** | Opus 5.5 main session | Claude | Planning, architecture decisions, task files, accept/reject, `STATE.md`, commits (writes no code) |
| **hydrogen-xhigh/high/medium/low** | Gemini 4 Hydrogen | Google Gemini | Primary worker: hard/critical backend (`xhigh`), medium features (`medium`/`high`), fix rounds |
| **argon-high/medium** | Gemini 4 Argon | Google premium | Consultation, architectural second opinion, cross-review of Hydrogen diffs |
| **flash-high/medium/low** | Gemini 3.8 Flash | Google Flash | Legwork: CRUD, DTOs, validators, unit tests, repo scans, maps, mechanical edits |
| **runner (`wave-runner`)** | Haiku 5.5 subagent (`low`) | Claude | Runs `agy` tasks, reports `diff --stat` and build/test summaries |
| **haiku-scout** | Haiku 5.5 subagent (`low`) | Claude | Codebase scanning, log/error summaries, command execution, mechanical edits |
| **sonnet-dev / sonnet-dev-medium** | Sonnet 5.5 subagent (`high`/`medium`) | Claude | Claude-side implementer: sensitive patches, fixing `agy` output, fallback when `agy` quota runs out |
| **opus-dev** | Opus 5.5 subagent (`high`) | Claude | Short in-and-out only for the core of `CRITICAL` tasks when others fail |

## 📋 Requirements

- **Required:** Windows 10/11 (PowerShell 5.1), Claude Code, Git for Windows (Git Bash)
- **Optional:** Antigravity CLI (`agy`), Node.js

## 🚀 Installation

Preview changes with `-DryRun` first, then run the installer:

```powershell
# 1. Dry run (writes no files, creates no backups)
.\install.ps1 -DryRun

# 2. Actual installation
.\install.ps1
```

Additional options:

```powershell
# Install only selected components (valid values: skills, agents, claudemd, settings, gemini)
.\install.ps1 -Only skills,agents

# Overwrite an existing statusLine entry in settings.json (only replaces statusLine)
.\install.ps1 -Force

# Target a custom home directory, e.g. for testing/isolation (default: $env:USERPROFILE)
.\install.ps1 -TargetHome "D:\test-home" -DryRun
```

If `agy` (Antigravity CLI) is installed on Windows, run the Gemini skill sync script once after installation:

```bash
bash ~/.claude/skills/agent-model-routing/scripts/sync-gemini-skills.sh --copy
```

## 📦 What Gets Installed / Modified

- `skills`: Copies kit skills into `~/.claude/skills/` (`agent-model-routing`, `orkestra-baslat`, `seviyelendirme`, `dotnet-sablonlar`).
- `agents`: Copies subagent definitions into `~/.claude/agents/` (`haiku-scout`, `sonnet-dev`, `sonnet-dev-medium`, `opus-dev`, `wave-runner`).
- `claudemd`: Inserts or updates the `<!-- orkestra-kit:start --> ... <!-- orkestra-kit:end -->` block in `~/.claude/CLAUDE.md` without touching your existing rules.
- `gemini`: Inserts or updates the same marked block in `~/.gemini/GEMINI.md`.
- `settings`: Merges `permissions.allow` entries into `~/.claude/settings.json` without duplicates; adds `statusLine` if missing (existing `statusLine` is only replaced with `-Force`).
- **Backups:** Existing files modified during installation are backed up to `~/.claude/backups/orkestra-kit-<timestamp>/`.

## ↩️ Rollback

Preview the rollback with `-DryRun` first, then run `-Restore` with the backup folder created during installation (`manifest.json` deletes newly created files and restores modified ones; files with identical content are left untouched):

```powershell
# 1. Preview what will be restored or removed
.\install.ps1 -Restore "$env:USERPROFILE\.claude\backups\orkestra-kit-<timestamp>" -DryRun

# 2. Perform the rollback
.\install.ps1 -Restore "$env:USERPROFILE\.claude\backups\orkestra-kit-<timestamp>"
```

## 🛠️ Usage

- Start a project session with `/orkestra-baslat` in Claude Code to generate `.claude/orchestra/PROJECT.md`, `STATE.md`, and the project `CLAUDE.md` orchestra section.
- If the project `CLAUDE.md` has no `Seviye:` line, `seviyelendirme` determines the project tier (`S1`–`S5`) and risk tags.
- At the end of each wave, `.claude/orchestra/STATE.md` is updated; open a fresh session and type `devam` to resume.

## 🔵 Claude-Only Mode

If `agy` is not installed, `install.ps1` prints a warning and completes normally. At runtime the workflow falls back to **Claude-only mode**, routing implementation and scanning to `sonnet-dev`, `sonnet-dev-medium`, and `haiku-scout`.

## 🧩 Recommended Extensions

Third-party skills and plugins are not bundled or installed by this kit. See [THIRD_PARTY.md](THIRD_PARTY.md) for audit notes and official installation instructions.

> **Note on .NET templates:** The `my-onion` and `my-ntier` .NET templates are **not** included in this kit. The `dotnet-sablonlar` skill assumes you have installed them separately from your own template repository.

## 🔗 Using Together

This kit works best when installed alongside the [.NET 10 templates](https://github.com/MuhammedGazi/DotNet10Templates) (`https://github.com/MuhammedGazi/DotNet10Templates`), though both repositories are independent and you can customize them to fit your own setup.

## 🤝 Contributing

For bug reports or suggestions, feel free to open an Issue or create a branch and submit a Pull Request—I will review and merge it. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

Let's build it together 🙌

## 📄 License

[MIT](LICENSE) — Author: MuhammedGazi ([github.com/MuhammedGazi](https://github.com/MuhammedGazi))
