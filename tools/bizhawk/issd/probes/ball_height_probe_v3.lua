-- ISSD Ball Z probe v3: automatic temporal WRAM search (experimental).
-- Standalone BizHawk Lua Console script. Does not change emulated memory.
-- Controls: T=start/stop trace; H=mark visually observed apex; C=rank/export;
-- J=discard trace. Record launch from ground until after landing.
-- Saves full-WRAM snapshots to a temporary binary trace on disk (every 6 frames).
local DOMAIN="WRAM"
local STEP=6
local MAX_SAMPLES=130
local MAX_CANDIDATES=350
local prev={}
local running=false
local tick=0
local samples=0
local apex=nil
local path=nil
local handle=nil
local size=memory.getmemorydomainsize(DOMAIN)
local stamp=0
local function hit(k,key) return k[key] and not prev[key] end
local function trace_name(ext)
  return string.format("issd_ball_z_v3_%s_%03d.%s",os.date("%Y%m%d_%H%M%S"),stamp,ext)
end
local function capture()
  -- Chunked strings keep peak Lua RAM bounded. Cost: one WRAM read per byte.
  local chunks={}
  local chunk={}
  for addr=0,size-1 do
    chunk[#chunk+1]=string.char(memory.read_u8(addr,DOMAIN))
    if #chunk>=1024 then
      chunks[#chunks+1]=table.concat(chunk);chunk={}
    end
  end
  if #chunk>0 then chunks[#chunks+1]=table.concat(chunk) end
  handle:write(table.concat(chunks))
  samples=samples+1
end
local function close()
  if handle then handle:close();handle=nil end
  running=false
end
local function start()
  close()
  stamp=stamp+1
  path=trace_name("bin")
  local f,err=io.open(path,"wb")
  if not f then console.log("[BALL_Z v3] Cannot open trace: "..tostring(err));return end
  handle=f;samples=0;apex=nil;tick=0;running=true
  capture()
  console.log("[BALL_Z v3] Recording "..path.." WRAM bytes="..size)
end
local function discard()
  close()
  if path then os.remove(path) end
  path=nil;samples=0;apex=nil
  console.log("[BALL_Z v3] Recording discarded")
end
local function read_snapshot(f,index)
  f:seek("set",(index-1)*size)
  local s=f:read(size)
  if not s or #s~=size then return nil end
  return s
end
local function value(snapshot,address,width,signed)
  local lo=string.byte(snapshot,address+1)
  if not lo then return nil end
  local v=lo
  if width==2 then
    local hi=string.byte(snapshot,address+2)
    if not hi then return nil end
    v=v+hi*256
  end
  local limit=width==1 and 256 or 65536
  if signed and v>=limit/2 then v=v-limit end
  return v
end
local function is_excluded(addr,width)
  -- Known ball X/Y, possession and controller inputs are not height.
  local last=addr+width-1
  return (addr<=0x042D and last>=0x042A)
    or (addr<=0x00A7 and last>=0x00A6)
    or (addr<=0x1ACD and last>=0x1ACC)
end
local function first_pass(f)
  local first=read_snapshot(f,1)
  local peak=read_snapshot(f,apex)
  local last=read_snapshot(f,samples)
  if not first or not peak or not last then return {} end
  local candidates={}
  for _,width in ipairs({1,2}) do
    for addr=0,size-width do
      if not is_excluded(addr,width) then
        for _,signed in ipairs({false,true}) do
          local a=value(first,addr,width,signed)
          local b=value(peak,addr,width,signed)
          local c=value(last,addr,width,signed)
          local amplitude=math.abs(b-a)
          local drift=math.abs(c-a)
          if amplitude>=5 and drift<=math.max(4,amplitude*0.20) then
            candidates[#candidates+1]={
              addr=addr,width=width,signed=signed,
              amplitude=amplitude,drift=drift,
              rough=amplitude/(1+drift)
            }
          end
        end
      end
    end
  end
  table.sort(candidates,function(a,b) return a.rough>b.rough end)
  while #candidates>MAX_CANDIDATES do candidates[#candidates]=nil end
  return candidates
end
local function score_series(series,apex_index)
  local n=#series
  local baseline=series[1]
  local delta=series[apex_index]-baseline
  local direction=delta>0 and 1 or -1
  local amplitude=math.abs(delta)
  local drift=math.abs(series[n]-baseline)
  local correct,total,changes,positive=0,0,0,0
  local prior=series[1]
  local minv,maxv=prior,prior
  for i=2,n do
    local v=series[i]
    minv=math.min(minv,v);maxv=math.max(maxv,v)
    local movement=(v-prior)*direction
    if movement~=0 then
      changes=changes+1
      local expected=i<=apex_index and 1 or -1
      if movement*expected>0 then correct=correct+1 end
      total=total+1
    end
    if (v-baseline)*direction>=amplitude*0.20 then positive=positive+1 end
    prior=v
  end
  if total<6 or correct<4 then return nil end
  local coherence=correct/total
  local excursion=(maxv-minv)
  local shape=positive/n
  -- A real height curve should evolve repeatedly, peak, then come home;
  -- penalize static flags, wraparound and single large discontinuities.
  if coherence<0.66 or shape<0.07 or shape>0.92 then return nil end
  if excursion>amplitude*2.5 then return nil end
  local score=100*coherence+math.min(30,changes)*2
      +math.min(30,amplitude)/3-20*drift/(1+amplitude)
  return score,coherence,changes,drift
end
local function analyze()
  close()
  if not path or samples<12 then
    console.log("[BALL_Z v3] Need a trace with at least 12 samples");return
  end
  if not apex or apex<=3 or apex>=samples-3 then
    console.log("[BALL_Z v3] Mark apex with H during trace, well inside its duration");return
  end
  local f,err=io.open(path,"rb")
  if not f then console.log("[BALL_Z v3] "..tostring(err));return end
  local candidate=first_pass(f)
  console.log(string.format("[BALL_Z v3] shortlist=%d trace_samples=%d apex=%d",
    #candidate,samples,apex))
  for _,c in ipairs(candidate) do c.series={} end
  for i=1,samples do
    local snap=read_snapshot(f,i)
    if not snap then break end
    for _,c in ipairs(candidate) do
      c.series[#c.series+1]=value(snap,c.addr,c.width,c.signed)
    end
  end
  f:close()
  local ranked={}
  for _,c in ipairs(candidate) do
    if #c.series==samples then
      local score,coherence,changes,drift=score_series(c.series,apex)
      if score then
        c.score=score;c.coherence=coherence;c.changes=changes;c.drift=drift
        ranked[#ranked+1]=c
      end
    end
  end
  table.sort(ranked,function(a,b)
    if a.score==b.score then return a.addr<b.addr end
    return a.score>b.score
  end)
  console.log("[BALL_Z v3] ranked="..#ranked.." (no address validated yet)")
  for i=1,math.min(20,#ranked) do
    local c=ranked[i]
    console.log(string.format(" #%d $%05X %s%d score=%.1f coherence=%.2f changes=%d",
      i,c.addr,c.signed and "s" or "u",c.width*8,c.score,c.coherence,c.changes))
  end
  local csv=trace_name("csv")
  local out,e=io.open(csv,"w")
  if not out then console.log("[BALL_Z v3] CSV: "..tostring(e));return end
  out:write("sample,relative_frame,phase,address,type,value,score,coherence,changes\n")
  for j=1,math.min(20,#ranked) do
    local c=ranked[j]
    for i,v in ipairs(c.series) do
      out:write(string.format("%d,%d,%s,0x%05X,%s%d,%d,%.3f,%.3f,%d\n",
        i,(i-1)*STEP,i<=apex and "RISE" or "FALL",
        c.addr,c.signed and "s" or "u",c.width*8,v,c.score,c.coherence,c.changes))
    end
  end
  out:close()
  console.log("[BALL_Z v3] CSV: "..csv.." (top 20 temporal traces)")
end
console.log("[BALL_Z v3] T record/stop, H apex mark, C analyze+CSV, J discard")
console.log("[BALL_Z v3] Full WRAM scan every "..STEP.." frames; run alone.")
while true do
  local keys=input.get()
  if hit(keys,"J") then discard() end
  if hit(keys,"T") then
    if running then close();console.log("[BALL_Z v3] stopped samples="..samples)
    else start() end
  end
  if hit(keys,"H") and running then
    apex=samples
    console.log("[BALL_Z v3] marked apex sample="..apex)
  end
  if running then
    if tick%STEP==0 and tick>0 then capture() end
    tick=tick+1
    if samples>=MAX_SAMPLES then
      close();console.log("[BALL_Z v3] auto-stop at "..MAX_SAMPLES.." samples")
    end
  end
  if hit(keys,"C") then analyze() end
  gui.text(8,8,string.format("BALL Z v3 %s samples=%d apex=%s",
    running and "REC" or "STOP",samples,tostring(apex)))
  gui.text(8,22,"T trace H apex C rank/export J discard")
  prev=keys
  emu.frameadvance()
end
