#!/usr/bin/env bash
# quota-check.sh: iki tarafın kota durumunu tek ekranda özetler (Opus oturum başında ve
# her büyük devirden önce çalıştırır).
#
# Kullanım: quota-check.sh [--refresh] [--no-agy] [--session-start]
#          quota-check.sh --set-claude <5s_%> <5s_yenilenme_ISO> <7g_%> <7g_yenilenme_ISO>
#          quota-check.sh --log-subagent <opus-dev|sonnet-dev|sonnet-dev-medium|haiku-scout|wave-runner> <görev>
#   --session-start  Argon oturum bütçesinin başlangıç noktasını kaydeder (oturum başında bir kez)
#   --log-subagent   Claude alt ajan çağrısını kayda geçirir (opus-dev 5s sınırı bundan sayılır)
#   --refresh  agy kotasını önbellek taze olsa bile yeniden çek
#   --no-agy   agy'yi hiç çağırma (yalnızca Claude + log özeti)
#   --set-claude  Claude kotasını elle kaydet. Masaüstü uygulamasında status line çalışmadığı için
#                 Opus kotayı uygulamanın get_usage aracıyla okur ve bu komutla dosyaya yazar.
#                 Ör: quota-check.sh --set-claude 35 2026-11-08T03:09:59Z 37 2026-11-11T17:59:59Z
#
# Kaynaklar:
#   Claude: ~/.claude/orchestra/claude-quota.json (CLI'da statusline.sh, masaüstünde --set-claude yazar)
#   agy:    `agy -p /usage` (agent turu başlatmaz, kota harcamaz) → agy-usage.txt önbelleği
#   Log:    usage-log.tsv (agy-run.sh yazar)
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="${ORCH_STATE_DIR:-$HOME/.claude/orchestra}"
CACHE="$STATE_DIR/agy-usage.txt"
MAX_AGE="${AGY_USAGE_MAX_AGE:-900}"
export OPUS_DEV_MAX="${OPUS_DEV_MAX:-1}"   # 5s penceresi başına opus-dev sınırı
ARGON_SESSION_BUDGET="${ARGON_SESSION_BUDGET:-5}"  # oturum başına Argon haftalık % bütçesi
refresh=0; no_agy=0; session_start=0
for a in "$@"; do case "$a" in --refresh) refresh=1 ;; --no-agy) no_agy=1 ;; --session-start) session_start=1; refresh=1 ;; esac; done
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/usage-log.tsv"
[ -f "$LOG" ] || printf 'ts\tcmd\ttier\tslug\tsecs\trc\texit\ttask\n' > "$LOG"

if [ "${1:-}" = "--log-subagent" ]; then
  [ $# -ge 2 ] || { echo "Kullanım: quota-check.sh --log-subagent <ajan> [görev]" >&2; exit 2; }
  printf '%s\tsubagent\t%s\t-\t0\t0\t0\t%s\n' "$(date +%s)" "$2" "${3:--}" >> "$LOG"
  echo "Kaydedildi: $2"; exit 0
fi

if [ "${1:-}" = "--set-claude" ]; then
  [ $# -ge 5 ] || { echo "Kullanım: quota-check.sh --set-claude <5s_%> <5s_yenilenme_ISO> <7g_%> <7g_yenilenme_ISO>" >&2; exit 2; }
  node -e '
const fs=require("fs"),path=require("path");
const [dir,f5,r5,f7,r7]=process.argv.slice(1);
const ep=v=>/^[0-9]+$/.test(v)?Number(v):Math.floor(Date.parse(v)/1000);
const o={updated_at:Math.floor(Date.now()/1000),source:"get_usage",
  five_hour:{used_percentage:Number(f5),resets_at:ep(r5)},seven_day:{used_percentage:Number(f7),resets_at:ep(r7)}};
if([o.five_hour.used_percentage,o.five_hour.resets_at,o.seven_day.used_percentage,o.seven_day.resets_at].some(Number.isNaN)){console.error("Geçersiz değer");process.exit(2)}
const f=path.join(dir,"claude-quota.json");fs.writeFileSync(f+".tmp",JSON.stringify(o));fs.renameSync(f+".tmp",f);
console.log("Claude kotası kaydedildi.");' "$STATE_DIR" "$2" "$3" "$4" "$5" || exit 2
  shift 5
fi

node -e '
const fs=require("fs"),path=require("path");
const dir=process.argv[1], now=Math.floor(Date.now()/1000), WEEK=7*86400;
const fmt=s=>{s=Math.max(0,s);const m=Math.round(s/60);return m>=1440?(m/1440).toFixed(1)+"g":m>=60?Math.floor(m/60)+"s"+(m%60)+"d":m+"d"};
console.log("=== CLAUDE (Opus/Sonnet/Haiku alt ajanlar tek havuz) ===");
let q=null;try{q=JSON.parse(fs.readFileSync(path.join(dir,"claude-quota.json"),"utf8"))}catch(e){}
const okNum=v=>typeof v==="number"&&Number.isFinite(v);
const okWin=x=>x&&okNum(x.used_percentage)&&okNum(x.resets_at);
if(q&&!(okNum(q.updated_at)&&(okWin(q.five_hour)||okWin(q.seven_day)))){console.log("VERİ: UNKNOWN (claude-quota.json bozuk ya da alanlar eksik)");q=null;}
else if(!q){console.log("VERİ: UNKNOWN. CLI: status line ilk yanıttan sonra yazar. Masaüstü uygulaması: get_usage ile oku, quota-check.sh --set-claude ile kaydet.");}
if(q){
  const age=now-q.updated_at, f=okWin(q.five_hour)?q.five_hour:null, w=okWin(q.seven_day)?q.seven_day:null;
  const stale=age>1800;
  console.log("VERİ: "+(stale?"STALE ("+fmt(age)+" önce; get_usage + --set-claude ile tazele)":"FRESH ("+fmt(age)+" önce)"));
  let label="NORMAL", why=[];
  if(f)console.log("5 saat : %"+f.used_percentage.toFixed(0)+" kullanıldı, yenilenme "+fmt(f.resets_at-now));
  let pace=null;
  if(w){
    const elapsed=100*(1-(w.resets_at-now)/WEEK); pace=w.used_percentage-elapsed;
    console.log("7 gün  : %"+w.used_percentage.toFixed(0)+" kullanıldı, haftanın %"+elapsed.toFixed(0)+"ü geçti, tempo "+(pace>=0?"+":"")+pace.toFixed(0)+", yenilenme "+fmt(w.resets_at-now));
  }
  if((f&&f.used_percentage>=90)||(w&&w.used_percentage>=97)){label="DUR";why.push("limit eşiği");}
  else if((f&&f.used_percentage>=75)||(pace!=null&&pace>10)){label="KIT";why.push(f&&f.used_percentage>=75?"5s yüksek":"haftalık tempo önde");}
  else if((pace!=null&&pace< -15)||(w&&w.resets_at-now<86400&&w.used_percentage<70)||(f&&f.resets_at-now<3600&&f.used_percentage<50)){label="BOL";
    why.push(pace!=null&&pace< -15?"haftalık tempo geride":(w&&w.resets_at-now<86400)?"hafta bitiyor, kalan yanacak":"5s penceresi bitiyor, kalan yanacak");}
  if(stale&&label==="BOL"){label="NORMAL";why=["veri STALE, BOL sayılmaz"];}
  console.log("ETİKET : "+label+(why.length?" ("+why.join(", ")+")":""));
  // opus-dev: BOL olsa bile yalnızca 5s < %40 iken zincirin başına geçer; pencere başına en fazla OPUS_DEV_MAX.
  let od=0;try{const winStart=f?f.resets_at-5*3600:now-5*3600;
    for(const l of fs.readFileSync(path.join(dir,"usage-log.tsv"),"utf8").trim().split("\n").slice(1)){
      const c=l.split("\t");if(c[1]==="subagent"&&c[2]==="opus-dev"&&Number(c[0])>=winStart)od++;}}catch(e){}
  const odMax=Number(process.env.OPUS_DEV_MAX||1);
  let odOk=label!=="DUR"&&label!=="KIT"&&od<odMax, odLead=odOk&&label==="BOL"&&f&&f.used_percentage<40;
  console.log("opus-dev: bu 5s penceresinde "+od+"/"+odMax+" → "+(!odOk?"KULLANMA (zincir: hydrogen-xhigh → argon-high → sonnet-dev)":"yalnızca KRİTİK çekirdek, zincirin sonunda (hydrogen-xhigh → argon-high → sonnet-dev → opus-dev)"));
}
console.log("\n=== agy LOG (son 5 saat / son 7 gün) ===");
let rows=[];try{rows=fs.readFileSync(path.join(dir,"usage-log.tsv"),"utf8").trim().split("\n").slice(1).map(l=>l.split("\t"))}catch(e){}
const by={};
for(const r of rows){const [ts,cmd,tier,,secs,,ex]=r;if(cmd==="rollback"||cmd==="subagent")continue;const t=Number(ts);if(now-t>WEEK)continue;
  const b=by[tier]||(by[tier]={n7:0,s7:0,n5:0,quota5:0,fail5:0});b.n7++;b.s7+=Number(secs);
  if(now-t<5*3600){b.n5++;if(ex==="4")b.quota5++;if(ex==="1")b.fail5++;}}
const tiers=Object.keys(by);
if(!tiers.length)console.log("Kayıt yok.");
for(const t of tiers){const b=by[t];console.log(t.padEnd(13)+" 7g: "+b.n7+" çağrı/"+Math.round(b.s7/60)+"dk | 5s: "+b.n5+" çağrı"+(b.quota5?" | KOTA DOLU x"+b.quota5:"")+(b.fail5?" | hata x"+b.fail5:""));}
' "$STATE_DIR"

[ "$no_agy" -eq 1 ] && exit 0
echo; echo "=== agy KOTA (/usage) ==="
# Önbellek: agy-usage.txt yalnızca BAŞARILI çekimde yazılır (fetched_at = son başarılı veri);
# agy-usage.attempt her denemede yazılır ("<last_attempt_at> <rc>").
ATTEMPT="$STATE_DIR/agy-usage.attempt"
cache_fetched() { [ -f "$CACHE" ] && sed -n '1s/.*fetched_at=\([0-9]*\).*/\1/p' "$CACHE"; }
cache_rc() { [ -f "$CACHE" ] && sed -n '1s/.*rc=\([0-9]*\).*/\1/p' "$CACHE"; }
fetched="$(cache_fetched)"; age=$(( $(date +%s) - ${fetched:-0} ))
fetch_err=0
if [ "$refresh" -eq 1 ] || [ "$age" -gt "$MAX_AGE" ]; then
  "$DIR/agy-run.sh" usage >/dev/null 2>&1 || fetch_err=1
  fetched="$(cache_fetched)"; age=$(( $(date +%s) - ${fetched:-0} ))
fi
# Eski sürüm agy-run.sh başarısız çekimi de önbelleğe yazıyordu (rc!=0): onu geçerli veri sayma.
if [ -f "$CACHE" ] && [ "$(cache_rc)" != "0" ]; then valid_cache=0; else valid_cache=1; fi
if [ ! -f "$CACHE" ] || [ "$valid_cache" -eq 0 ] || ! grep -q '[0-9]%' "$CACHE"; then
  if [ "$fetch_err" -eq 1 ]; then echo "VERİ: ERROR (son çekim başarısız, geçerli önbellek yok) → agy havuzlarını BOL sayma"
  else echo "VERİ: UNKNOWN (geçerli agy kota verisi yok) → agy havuzlarını BOL sayma"; fi
elif [ "$fetch_err" -eq 1 ]; then
  echo "VERİ: ERROR (son çekim başarısız; aşağıdaki veri $(( age / 60 )) dk önceki son başarılı çekimden) → BOL sayma"
elif [ "$age" -gt "$MAX_AGE" ]; then
  echo "VERİ: STALE ($(( age / 60 )) dk önce) → BOL sayma, --refresh ile tazele"
else
  echo "VERİ: FRESH ($(( age / 60 )) dk önce)"
fi
if [ -f "$CACHE" ] && [ "$valid_cache" -eq 1 ]; then
  sed -n '2,45p' "$CACHE" | grep -v '^[[:space:]]*$'
  # Argon oturum bütçesi: oturum başındaki "kalan %" ile şimdiki farkı.
  argon_now="$(grep -i 'Argon.*Weekly' "$CACHE" | grep -Eo '[0-9]+%' | head -n1 | tr -d '%')"
  if [ -n "$argon_now" ]; then
    [ "$session_start" -eq 1 ] && echo "$(date +%s) $argon_now" > "$STATE_DIR/argon-session.txt"
    if [ -f "$STATE_DIR/argon-session.txt" ]; then
      argon_start="$(cut -d' ' -f2 "$STATE_DIR/argon-session.txt")"
      spent=$(( argon_start - argon_now ))
      if [ "$spent" -ge "$ARGON_SESSION_BUDGET" ]; then
        echo "ARGON OTURUM BÜTÇESİ DOLDU: bu oturumda %$spent harcandı (bütçe %$ARGON_SESSION_BUDGET) → Argon'u KIT say, zincirde sonrakine geç."
      else
        echo "Argon oturum bütçesi: %$spent / %$ARGON_SESSION_BUDGET harcandı (kalan haftalık %$argon_now)."
      fi
    else
      echo "Argon oturum bütçesi başlatılmadı: oturum başında quota-check.sh --session-start çalıştır."
    fi
  fi
else
  echo "Veri yok."
fi

echo; echo "=== agy İZİN TESTİ ==="
if [ -f "$STATE_DIR/permcheck.txt" ]; then
  pc_ts="$(cut -d' ' -f1 "$STATE_DIR/permcheck.txt")"
  echo "$(cut -d' ' -f2- "$STATE_DIR/permcheck.txt") ($(( ($(date +%s) - pc_ts) / 3600 )) saat önce)"
else
  echo "Yapılmadı: agy-run.sh permcheck (oturum başında bir kez)."
fi
