#!/usr/bin/env bash
# sync-gemini-skills.sh: Claude Code'a kurulu seçili skill'leri agy (Antigravity) ajanlarının
# görebileceği ~/.gemini/skills/ klasörüne sembolik link olarak bağlar.
# Claude tarafında plugin/skill güncellenince link sayesinde agy de güncel kalır.
#
# Kullanım: sync-gemini-skills.sh [--copy]   (--copy: link yerine kopyala; Windows Git Bash için)
# Kontrol: agy içinde /skills
set -uo pipefail
DEST="${GEMINI_SKILLS_DIR:-$HOME/.gemini/skills}"
mode="link"; [ "${1:-}" = "--copy" ] && mode="copy"

# agy'ye verilecek skill'ler (ağır uygulama/inceleme işini Gemini yapsın diye)
SKILLS=(
  dotnet-patterns          # ECC: .NET uygulama kalıpları (Flash/Argon)
  angular-developer        # ECC: Angular uygulama (Flash)
  api-design               # ECC: endpoint tasarımı uygulaması (Flash/Argon)
  security-review          # ECC: diff güvenlik incelemesi (Argon/agy:sonnet)
  test-driven-development  # Superpowers: test yazımı (Flash)
  systematic-debugging     # Superpowers: derin bug analizi (Argon)
  impeccable               # Impeccable: UI işleri (Flash-high)
  playwright-cli           # Playwright CLI: tarayıcı doğrulama (Flash)
)

ROOTS=( "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.claude/plugins" )
mkdir -p "$DEST"
ok=0; miss=()
for s in "${SKILLS[@]}"; do
  src=""
  for r in "${ROOTS[@]}"; do
    [ -d "$r" ] || continue
    f="$(find "$r" -type f -path "*/$s/SKILL.md" 2>/dev/null | sort | tail -n 1)"
    [ -n "$f" ] && { src="$(dirname "$f")"; break; }
  done
  if [ -z "$src" ]; then miss+=("$s"); continue; fi
  rm -rf "${DEST:?}/$s"
  if [ "$mode" = "copy" ]; then cp -R "$src" "$DEST/$s"; else ln -s "$src" "$DEST/$s"; fi
  echo "OK  $s <- $src"; ok=$((ok+1))
done
[ ${#miss[@]} -gt 0 ] && echo "BULUNAMADI: ${miss[*]} (kurulu mu? adı farklı olabilir: find ~/.claude ~/.agents -name SKILL.md)"
echo "== $ok skill $DEST altında. agy içinde /skills ile doğrula."
