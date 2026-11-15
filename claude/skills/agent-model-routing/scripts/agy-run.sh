#!/usr/bin/env bash
# agy-run.sh v2: Claude Code'dan agy'yi güvenli çağırır ve her çağrıyı kayda geçirir.
#
# Kullanım:
#   agy-run.sh run <tier> <task-file>        # dosya yazar (accept-edits), temiz ağaç şart
#   agy-run.sh run --worktree <tier> <task>  # geçici worktree'de çalışır; sonuç yama olarak ana ağaca
#                                            # uygulanır (ana ağaç kirli olabilir; paralel iş için)
#   agy-run.sh consult <task-file> [tier]    # danışma; dosya değiştirmemeli (varsayılan argon-high)
#   agy-run.sh rollback <task-file> [--yes]  # yalnızca bu görevin dokunduğu dosyaları geri alır; --yes olmadan
#                                            # kuru çalışma (listeler). git clean yok; HEAD ilerlemişse reddeder.
#                                            # worktree modunda yalnızca uygulanan yamayı geri alır.
#   agy-run.sh usage                         # agy kota durumu (agent turu başlatmaz), önbelleğe yazar
#   agy-run.sh permcheck                     # headless izin testi (git grep, dotnet); permcheck.txt'ye yazar
#   agy-run.sh which                         # kullanılacak agy yolunu yazdırır (kurulum kontrolü)
#
# tier: hydrogen-xhigh | hydrogen-high | hydrogen-medium | hydrogen-low
#       argon-high | argon-medium | argon-low
#       flash-high | flash-medium | flash-low
#       sonnet-high | sonnet-medium | sonnet-low   (claude-sonnet-5-5-*, Google kotasından)
#       opus-high | opus-medium | opus-low         (claude-opus-5-5-*, Google kotasından)
#       gpt-oss                                    (gpt-oss-120b-medium, Claude/GPT kovasından)
#   Kısayollar: hydrogen = hydrogen-high, argon = argon-high, flash = flash-medium, sonnet = sonnet-medium, opus = opus-high
#
# usage-log.tsv sütunları: ts | cmd | tier | slug | secs | rc | exit | task | class
#
# Çıkış kodları:
#   0 başarılı | 1 başarısız/timeout | 2 kullanım/ön koşul hatası
#   3 belirsiz (boş çıktı ya da consult dosya değiştirdi: git diff ile kontrol et)
#   4 KOTA/KAPASİTE (bu tier'ı fallback zincirine göre atla; aynı komutu tekrarlama)
#
# Not: agy'de effort slug'ın parçasıdır (ör. gemini-4-argon-high); --effort bayrağı yok.
# Claude Code Bash çağrıları arasında ortam değişkenleri korunmaz; gerekirse aynı satırda ver:
#   AGY_TIMEOUT=1500 agy-run.sh run argon-high /tmp/agy-tasks/T1.md
set -uo pipefail

# Windows Git Bash: "/usage" gibi argümanların yola çevrilmesini engelle
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"
# agy yolu: önce AGY_BIN, sonra PATH, sonra bilinen kurulum yerleri.
# (Windows'ta winget PATH'i günceller ama zaten açık uygulamalar eski PATH'le çalışmaya devam eder.)
resolve_agy() {
  if [ -n "${AGY_BIN:-}" ]; then echo "$AGY_BIN"; return; fi
  if command -v agy >/dev/null 2>&1; then echo "agy"; return; fi
  local c
  for c in "${LOCALAPPDATA:-$HOME/AppData/Local}"/Microsoft/WinGet/Packages/Google.AntigravityCLI_*/agy.exe \
           "${LOCALAPPDATA:-$HOME/AppData/Local}"/Microsoft/WinGet/Links/agy.exe \
           "${LOCALAPPDATA:-$HOME/AppData/Local}"/agy/bin/agy.exe \
           "$HOME/.local/bin/agy" /usr/local/bin/agy /opt/homebrew/bin/agy; do
    [ -x "$c" ] && { echo "$c"; return; }
  done
  echo "agy"
}
AGY_BIN="$(resolve_agy)"
TIMEOUT_SECS="${AGY_TIMEOUT:-900}"
MAX_REPLY_BYTES=3000
STATE_DIR="${ORCH_STATE_DIR:-$HOME/.claude/orchestra}"
LOG="$STATE_DIR/usage-log.tsv"
USAGE_CACHE="$STATE_DIR/agy-usage.txt"
QUOTA_RE='quota|exhausted|RESOURCE_EXHAUSTED|MODEL_CAPACITY|rate.?limit|(^|[^0-9])429([^0-9]|$)|resume using this model|baseline quota'

die() { echo "HATA: $*" >&2; exit 2; }
mkdir -p "$STATE_DIR" || die "$STATE_DIR oluşturulamadı."
[ -f "$LOG" ] || printf 'ts\tcmd\ttier\tslug\tsecs\trc\texit\ttask\n' > "$LOG"

slug_for() {
  case "$1" in
    argon) echo "gemini-4-argon-high" ;;
    flash) echo "gemini-3.8-flash-medium" ;;
    argon-high|argon-medium|argon-low) echo "gemini-4-$1" ;;
    flash-high|flash-medium|flash-low) echo "gemini-3.8-$1" ;;
    hydrogen) echo "gemini-4-hydrogen-high" ;;
    hydrogen-xhigh|hydrogen-high|hydrogen-medium|hydrogen-low) echo "gemini-4-$1" ;;
    sonnet) echo "claude-sonnet-5-5-medium" ;;
    opus)   echo "claude-opus-5-5-high" ;;
    sonnet-high|sonnet-medium|sonnet-low) echo "claude-sonnet-5-5-${1#sonnet-}" ;;
    opus-high|opus-medium|opus-low)       echo "claude-opus-5-5-${1#opus-}" ;;
    gpt-oss) echo "gpt-oss-120b-medium" ;;
    *) return 1 ;;
  esac
}

# timeout aracı (Windows timeout.exe sahte olduğu için sınanır)
TO=""
if command -v timeout >/dev/null 2>&1; then TO="timeout"
elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout"; fi
if [ -n "$TO" ] && ! "$TO" 1 true >/dev/null 2>&1; then TO=""; fi

run_agy() { # $1=out $2=err, gerisi agy argümanları
  local out="$1" err="$2"; shift 2
  if [ -n "$TO" ]; then "$TO" "$TIMEOUT_SECS" "$AGY_BIN" "$@" </dev/null >"$out" 2>"$err"
  else "$AGY_BIN" "$@" </dev/null >"$out" 2>"$err"; fi
}

strip_ansi() { sed -E 's/\x1B\[[0-9;?]*[A-Za-z]//g; s/\r//g'; }
# Ekrana basılan çıktıda olası sırları maskele (token, anahtar, Authorization, bağlantı şifresi).
redact() { sed -E 's/(Bearer|Authorization:)[[:space:]]+[^[:space:]]+/\1 ***/Ig; s/((api[_-]?key|token|secret|password|pwd)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?)[^"'"'"'[:space:];,]+/\1***/Ig; s/(AIza|sk-|ghp_|xox[bp]-)[A-Za-z0-9_-]{8,}/\1***/g'; }

cmd="${1:-}"; shift || true
if [ "$cmd" = "which" ]; then
  if command -v "$AGY_BIN" >/dev/null 2>&1 || [ -x "$AGY_BIN" ]; then echo "$AGY_BIN"; exit 0; fi
  echo "agy bulunamadı" >&2; exit 2
fi
{ command -v "$AGY_BIN" >/dev/null 2>&1 || [ -x "$AGY_BIN" ]; } || die "agy bulunamadı (PATH ve bilinen kurulum yerleri denendi; AGY_BIN ile yol verebilirsin)."

# ---------- usage (git gerekmez) ----------
if [ "$cmd" = "usage" ]; then
  tmp_out="$(mktemp)"; tmp_err="$(mktemp)"
  run_agy "$tmp_out" "$tmp_err" -p "/usage"; rc=$?
  now_ts="$(date +%s)"
  echo "$now_ts $rc" > "$STATE_DIR/agy-usage.attempt"     # last_attempt_at + rc (her denemede)
  # Önbellek yalnızca başarılı ve yüzde içeren veride güncellenir; başarısızlıkta son iyi veri korunur.
  if [ "$rc" -eq 0 ] && strip_ansi < "$tmp_out" | grep -q '[0-9]%'; then
    { echo "# fetched_at=$now_ts rc=0"; strip_ansi < "$tmp_out"; } > "$USAGE_CACHE.tmp" && mv -f "$USAGE_CACHE.tmp" "$USAGE_CACHE"
    rm -f "$tmp_out" "$tmp_err"; head -n 60 "$USAGE_CACHE"; exit 0
  fi
  echo "UYARI: /usage alınamadı (rc=$rc); önbellek DEĞİŞTİRİLMEDİ." >&2
  strip_ansi < "$tmp_err" | redact | tail -n 5 >&2
  rm -f "$tmp_out" "$tmp_err"; exit 1
fi

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "Git deposu içinde değilsin."
cd "$root" || die "Depo köküne geçilemedi."

# ---------- permcheck (salt okuma; dosya yazmaz/silmez) ----------
# Headless agy'nin izin listesinde gerekli salt okuma komutları açık mı? Flash-low kullanır (bol kova).
if [ "$cmd" = "permcheck" ]; then
  pc_out="$(mktemp)"; pc_err="$(mktemp)"
  pc_prompt='İZİN TESTİ. Dosya yazma, silme yok. Sırayla şu iki komutu çalıştır:
1) git grep -c -e "a" -- README.md
2) dotnet --version
Her komut için tek satır yaz: "git_grep=OK" ya da "git_grep=DENIED", "dotnet=OK" ya da "dotnet=DENIED". Başka bir şey yazma.'
  run_agy "$pc_out" "$pc_err" -p "$pc_prompt" --model "$(slug_for flash-low)"; rc=$?
  res="$(strip_ansi < "$pc_out" | grep -Eo '(git_grep|dotnet)=(OK|DENIED)' | sort -u | tr '\n' ' ')"
  [ -n "$res" ] || res="belirsiz (rc=$rc)"
  echo "$(date +%s) $res" > "$STATE_DIR/permcheck.txt"
  printf '%s\tpermcheck\tflash-low\t%s\t0\t%s\t%s\t-\n' "$(date +%s)" "$(slug_for flash-low)" "$rc" "$rc" >> "$LOG"
  rm -f "$pc_out" "$pc_err"
  echo "== permcheck: $res"
  case "$res" in *DENIED*|belirsiz*) exit 1 ;; esac
  exit 0
fi

# ---------- rollback ----------
if [ "$cmd" = "rollback" ]; then
  task="${1:-}"; yes="${2:-}"
  [ -n "$task" ] || die "Kullanım: agy-run.sh rollback <görev> [--yes]"
  [ -z "$yes" ] || [ "$yes" = "--yes" ] || die "Bilinmeyen argüman: $yes (yalnızca --yes)"
  [ -f "$task" ] || die "Görev dosyası yok: $task"
  task="$(cd "$(dirname "$task")" && { pwd -W 2>/dev/null || pwd; })/$(basename "$task")"
  rb_log() { printf '%s\trollback\t-\t-\t0\t0\t%s\t%s\n' "$(date +%s)" "$1" "$(basename "$task")" >> "$LOG"; }
  if [ -f "$task.patch.applied" ]; then
    echo "== Worktree modu: yalnızca bu görevin yaması geri alınacak ($task.patch):"
    git apply --stat "$task.patch"
    [ "$yes" = "--yes" ] || { echo "== KURU ÇALIŞMA. Uygulamak için: rollback <görev> --yes"; exit 0; }
    git apply -R --check --whitespace=nowarn "$task.patch" 2>/dev/null \
      || die "Yama temiz geri alınamıyor (dosyalar sonradan değişmiş). Hiçbir şey yapılmadı; elle incele."
    git apply -R --whitespace=nowarn "$task.patch" && rm -f "$task.patch.applied"
    rb_log yama; git status --short; exit 0
  fi
  if [ ! -f "$task.base" ] && [ -f "$task.patch" ]; then
    echo "== Worktree modu: ana ağaca uygulanmış yama yok; geri alınacak bir şey yok."; exit 0
  fi
  [ -f "$task.base" ] || die "$task.base yok; rollback noktası bilinmiyor."
  base="$(cat "$task.base")"
  [ "$(git rev-parse HEAD)" = "$base" ] || die "HEAD görev başından beri ilerlemiş ($base → $(git rev-parse --short HEAD)); araya commit girmiş. Otomatik geri alma yok: git log $base..HEAD ile incele."
  # Envanter: koşu sonunda kaydedilen, bu görevin değiştirdiği/oluşturduğu dosyalar.
  if [ -f "$task.files" ]; then inv="$(cat "$task.files")"
  else inv="$(git status --porcelain -- . ':(exclude).claude')"; echo "UYARI: envanter yok ($task.files); mevcut değişikliklerin hepsi listeleniyor, dikkatle incele."; fi
  [ -n "$inv" ] || { echo "== Geri alınacak değişiklik yok."; exit 0; }
  echo "== Geri alınacak dosyalar (yalnızca bu görevinkiler; diğer değişiklikler korunur):"
  printf '%s\n' "$inv"
  [ "$yes" = "--yes" ] || { echo "== KURU ÇALIŞMA. Uygulamak için: rollback <görev> --yes"; exit 0; }
  printf '%s\n' "$inv" | while IFS= read -r line; do
    st="${line:0:2}"; f="${line:3}"; f="${f#\"}"; f="${f%\"}"
    [ -n "$f" ] || continue
    case "$f" in /*|*..*|*' -> '*) echo "ATLANDI (güvensiz/yeniden adlandırma; elle bak): $f"; continue ;; esac
    if [ "$st" = "??" ]; then
      [ -f "$f" ] && rm -f -- "$f" && echo "silindi (görevin oluşturduğu): $f"
    elif git cat-file -e "$base:$f" 2>/dev/null; then
      git restore --source="$base" --staged --worktree -- "$f" && echo "geri alındı: $f"
    else
      git rm -q -f --cached -- "$f" 2>/dev/null; rm -f -- "$f"; echo "silindi (görevin eklediği): $f"
    fi
  done
  rm -f "$task.files"; rb_log envanter
  echo "== Tamam. Durum:"; git status --short
  exit 0
fi

# ---------- run / consult ----------
use_wt=0
case "$cmd" in
  run)     [ "${1:-}" = "--worktree" ] && { use_wt=1; shift; }
           tier="${1:-}"; task="${2:-}"; mode="accept-edits" ;;
  consult) task="${1:-}"; tier="${2:-argon-high}"; mode="consult" ;;
  *) die "Kullanım: agy-run.sh run [--worktree] <tier> <task> | consult <task> [tier] | rollback <task> | usage | permcheck" ;;
esac
[ -f "$task" ] || die "Görev dosyası yok: $task"
# MSYS_NO_PATHCONV açık olduğu için git.exe'ye giden yollar Windows biçiminde olmalı (pwd -W).
winpath() { (cd "$1" && { pwd -W 2>/dev/null || pwd; }); }
task="$(winpath "$(dirname "$task")")/$(basename "$task")"
slug="$(slug_for "$tier")" || die "Geçersiz tier: $tier"

# Dosya başına özet (yol + içerik özeti). consult yalnızca kendi süresince DEĞİŞEN dosyaları raporlar.
file_snapshot() {
  git status --porcelain -- . ':(exclude).claude' | cut -c4- | sed 's/.* -> //' | while IFS= read -r f; do
    if [ -f "$f" ]; then printf '%s %s\n' "$(cksum < "$f" | cut -d' ' -f1)" "$f"; else printf 'yok %s\n' "$f"; fi
  done | sort
}

wt=""
if [ "$mode" = "accept-edits" ] && [ "$use_wt" -eq 1 ]; then
  rm -f "$task.patch" "$task.patch.applied"
  mkdir -p "$STATE_DIR/wt"
  wt="$(winpath "$STATE_DIR/wt")/$(basename "$task" .md)-$$"
  git worktree add --detach "$wt" HEAD >/dev/null 2>&1 || die "Worktree açılamadı: $wt"
  rm -f "$task.base"   # worktree modunda ana ağaç asla reset edilmez; rollback yalnızca yamayı geri alır
  cd "$wt" || die "Worktree'ye geçilemedi."
  agy_mode=( --mode accept-edits )
elif [ "$mode" = "accept-edits" ]; then
  if git status --porcelain -- . ':(exclude).claude' | grep -q .; then
    die "Çalışma ağacı kirli. Önce commit veya stash yap, ya da run --worktree kullan."
  fi
  git rev-parse HEAD > "$task.base" || die "HEAD okunamadı."
  rm -f "$task.patch" "$task.patch.applied" "$task.files"
  agy_mode=( --mode accept-edits )
else
  before="$(file_snapshot)"
  # Bilerek --mode verilmez (default mod: headless'ta onay isteyen düzenlemeler reddedilir).
  # plan modu headless'ta plan onayını otomatik geçip uygulamaya başlayabildiği için kullanılmaz.
  agy_mode=()
fi

out="$task.out.txt"; err="$task.err.log"
prompt="$(cat "$task")"
[ "$mode" = "consult" ] && prompt="SADECE DANIŞMA: Hiçbir dosyayı değiştirme, komut çalıştırma. Yalnızca görüşünü yaz.

$prompt"

start=$(date +%s)
run_agy "$out" "$err" -p "$prompt" --model "$slug" ${agy_mode[@]+"${agy_mode[@]}"}; rc=$?
secs=$(( $(date +%s) - start ))

result=1
if grep -Eiq "$QUOTA_RE" "$err" 2>/dev/null || { [ "$rc" -ne 0 ] && grep -Eiq "$QUOTA_RE" "$out" 2>/dev/null; }; then
  result=4
elif [ "$rc" -eq 0 ] && [ -s "$out" ]; then
  result=0
elif [ "$rc" -eq 0 ]; then
  result=3
fi
changed=""
if [ "$mode" = "consult" ] && [ "$result" -eq 0 ]; then
  changed="$(comm -13 <(printf '%s\n' "$before") <(file_snapshot) | cut -d' ' -f2-)"
  [ -n "$changed" ] && result=3
fi

# Worktree modu: sonucu yama olarak al, ana ağaca uygula, worktree'yi kaldır.
wt_note=""
if [ -n "$wt" ]; then
  git add -A -- . ':(exclude).claude' >/dev/null 2>&1
  git diff --cached --binary HEAD -- . ':(exclude).claude' > "$task.patch"
  cd "$root" || die "Depo köküne dönülemedi."
  if [ "$result" -eq 0 ] && [ -s "$task.patch" ]; then
    if git apply --check --whitespace=nowarn "$task.patch" 2>/dev/null && git apply --whitespace=nowarn "$task.patch"; then
      touch "$task.patch.applied"; wt_note="yama ana ağaca uygulandı"
    else
      wt_note="YAMA UYGULANAMADI (çakışma). Yama: $task.patch — elle uygula ya da yeniden devret"; result=3
    fi
  else
    wt_note="yama uygulanmadı (sonuç $result); yama dosyası: $task.patch"
  fi
  git worktree remove --force "$wt" >/dev/null 2>&1 || echo "UYARI: worktree kaldırılamadı: $wt"
fi

# Normal run: rollback envanteri (ağaç başta temizdi; bu liste görevin dokunduğu dosyalardır).
if [ "$mode" = "accept-edits" ] && [ -z "$wt" ]; then
  git status --porcelain -- . ':(exclude).claude' > "$task.files"
fi

# Hata sınıfı (tekrar kararı için; SKILL.md §5a)
if [ "$result" -eq 4 ]; then class=RATE_LIMIT
elif [ "$rc" -eq 124 ]; then class=TIMEOUT
elif [ "$result" -eq 0 ]; then class=OK
elif grep -Eiq 'permission denied|not allowed|denied by|requires approval|is not permitted' "$err" "$out" 2>/dev/null; then class=PERMISSION
elif [ "$result" -eq 3 ]; then class=UNKNOWN
else class=EXECUTION; fi

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$start" "$cmd" "$tier" "$slug" "$secs" "$rc" "$result" "$(basename "$task")" "$class" >> "$LOG"

echo "== agy-run: $cmd tier=$tier model=$slug rc=$rc exit=$result sınıf=$class süre=${secs}s"
[ "$class" = PERMISSION ] && echo "== İZİN REDDİ: tekrar deneme; izin listesini kendiliğinden genişletme, kullanıcıya sor ya da görevi izin gerektirmeyecek şekilde yeniden yaz."
echo "== çıktı: $out | hata günlüğü: $err"
[ -n "$wt_note" ] && echo "== worktree: $wt_note"

case "$result" in
  0)
    strip_ansi < "$out" | redact | tail -c "$MAX_REPLY_BYTES"; echo
    [ "$mode" = "accept-edits" ] && { echo "== git diff --stat"; git diff --stat; git status --short; }
    ;;
  3)
    if [ "$mode" = "consult" ] && [ -s "$out" ]; then
      echo "== UYARI: consult süresince şu dosyalar değişti (paralel bir iş de olabilir; kontrol et):"
      printf '%s\n' "$changed"
      strip_ansi < "$out" | redact | tail -c "$MAX_REPLY_BYTES"; echo
    else
      echo "== BELİRSİZ: çıkış 0 ama çıktı boş (bilinen non-TTY sorunu olabilir; agy update)."
      echo "== Transcript: ~/.gemini/antigravity-cli/brain/<conversation-id>/"
      [ "$mode" = "accept-edits" ] && { echo "== git status"; git status --short; }
    fi
    ;;
  4)
    echo "== KOTA/KAPASİTE: $tier kullanılamıyor. Aynı komutu TEKRARLAMA; fallback zincirine geç."
    strip_ansi < "$err" | redact | tail -n 3
    [ "$mode" = "accept-edits" ] && { echo "== Yarım değişiklik varsa: agy-run.sh rollback $task (önce kuru çalışma, sonra --yes)"; git status --short; }
    ;;
  *)
    [ "$rc" -eq 124 ] && echo "== ZAMAN AŞIMI (${TIMEOUT_SECS}s)."
    echo "== BAŞARISIZ. stderr sonu:"; strip_ansi < "$err" | redact | tail -n 5
    [ "$mode" = "accept-edits" ] && { echo "== Yarım değişiklikler:"; git status --short; echo "== Geri almak için: agy-run.sh rollback $task (önce kuru çalışma, sonra --yes)"; }
    ;;
esac
exit "$result"
