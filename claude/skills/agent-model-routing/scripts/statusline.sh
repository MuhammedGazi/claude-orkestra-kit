#!/usr/bin/env bash
# statusline.sh: Claude Code status line'ı. Claude Code, kota bilgisini (rate_limits)
# YALNIZCA status line'a verir; bu script onu ~/.claude/orchestra/claude-quota.json'a
# yansıtır, böylece Opus kota durumunu quota-check.sh ile okuyabilir.
#
# ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "~/.claude/skills/agent-model-routing/scripts/statusline.sh" }
#
# Not: rate_limits yalnızca Pro/Max'ta ve oturumdaki ilk yanıttan sonra gelir.
STATE_DIR="${ORCH_STATE_DIR:-$HOME/.claude/orchestra}"
mkdir -p "$STATE_DIR" 2>/dev/null
node -e '
const fs=require("fs"),path=require("path");
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  let d={};try{d=JSON.parse(s)}catch(e){}
  const rl=d.rate_limits, now=Math.floor(Date.now()/1000);
  const ep=v=>v==null?null:(typeof v==="number"?v:Math.floor(Date.parse(v)/1000));
  if(rl&&(rl.five_hour||rl.seven_day)){
    const w=k=>rl[k]?{used_percentage:Number(rl[k].used_percentage),resets_at:ep(rl[k].resets_at)}:null;
    const o={updated_at:now,five_hour:w("five_hour"),seven_day:w("seven_day")};
    const f=path.join(process.argv[1],"claude-quota.json");
    try{fs.writeFileSync(f+".tmp",JSON.stringify(o));fs.renameSync(f+".tmp",f)}catch(e){}
  }
  const left=t=>{if(!t)return"";const m=Math.max(0,Math.round((t-now)/60));return m>=1440?Math.floor(m/1440)+"g":m>=60?Math.floor(m/60)+"s"+(m%60)+"d":m+"d"};
  const parts=[(d.model&&d.model.display_name)||"Claude"];
  if(rl&&rl.five_hour)parts.push("5s "+Math.round(rl.five_hour.used_percentage)+"% ("+left(ep(rl.five_hour.resets_at))+")");
  if(rl&&rl.seven_day)parts.push("7g "+Math.round(rl.seven_day.used_percentage)+"% ("+left(ep(rl.seven_day.resets_at))+")");
  if(d.context_window&&d.context_window.used_percentage!=null)parts.push("ctx "+Math.round(d.context_window.used_percentage)+"%");
  process.stdout.write(parts.join(" | "));
});' "$STATE_DIR"
