-- ISSD Ball Z Probe v2: temporal evidence, NOT a validated Z address.
-- Run alone in BizHawk Lua Console. Reads WRAM; does not modify game memory.
-- Capture labels: G=ground R=rolling A=air H=apex; C=class rank K=clear samples.
-- Temporal recording: T=start/stop, V=export CSV, J=clear recording.
-- T before a high kick; T after landing. Export and inspect the CSV.
local DOMAIN="WRAM"
local LABEL={G="GROUND",R="ROLLING",A="AIR",H="APEX"}
local ORDER={"GROUND","ROLLING","AIR","APEX"}
local WATCH={0x1040B,0x1476B,0x11B4B,0x1498A,0x14959}
local MAX_FRAMES=900
local samples,previous,frames={}, {}, {}
local frame=0
local recording=false
for _,name in ipairs(ORDER) do samples[name]={} end
local function edge(k,key) return k[key] and not previous[key] end
local function read_all()
  local n=memory.getmemorydomainsize(DOMAIN)
  local a={}
  for i=0,n-1 do a[i]=memory.read_u8(i,DOMAIN) end
  return a,n
end
local function val(a,addr,width,signed)
  local lo=a[addr]
  if lo==nil then return nil end
  local v=lo
  if width==2 then
    local hi=a[addr+1]
    if hi==nil then return nil end
    v=v+256*hi
  end
  local limit=width==1 and 256 or 65536
  if signed and v>=limit/2 then v=v-limit end
  return v
end
local function capture(name)
  local a=read_all()
  samples[name][#samples[name]+1]=a
  console.log(string.format("[BALL_Z] %s #%d at frame %d",name,#samples[name],frame))
end
local function rank_classes()
  for _,name in ipairs(ORDER) do
    if #samples[name]<3 then
      console.log("[BALL_Z] Need >=3 samples for "..name)
      return
    end
  end
  local _,size=read_all()
  for _,width in ipairs({1,2}) do
    local scores={}
    for addr=0,size-width do
      if not (addr>=0x0429 and addr<=0x042D) then
        local bmin,bmax,amin,amax,pmin,pmax
        local ok=true
        for _,name in ipairs(ORDER) do
          for _,a in ipairs(samples[name]) do
            local v=val(a,addr,width,true)
            if v==nil then ok=false;break end
            if name=="GROUND" or name=="ROLLING" then
              bmin=math.min(bmin or v,v);bmax=math.max(bmax or v,v)
            elseif name=="AIR" then
              amin=math.min(amin or v,v);amax=math.max(amax or v,v)
            else pmin=math.min(pmin or v,v);pmax=math.max(pmax or v,v) end
          end
        end
        if ok then
          local spread=bmax-bmin
          local gap=0
          if amin>bmax and pmin>bmax then gap=math.min(amin,pmin)-bmax
          elseif amax<bmin and pmax<bmin then gap=bmin-math.max(amax,pmax) end
          if spread<=8 and gap>0 then
            scores[#scores+1]={addr=addr,score=gap/(1+spread)}
          end
        end
      end
    end
    table.sort(scores,function(a,b)
      if a.score==b.score then return a.addr<b.addr end
      return a.score>b.score
    end)
    console.log(string.format("[BALL_Z] s%d candidates=%d top 15",width*8,#scores))
    for i=1,math.min(15,#scores) do
      local c=scores[i]
      console.log(string.format("  $%05X score=%.2f",c.addr,c.score))
    end
  end
end
local function row_values(a,addr)
  return val(a,addr,1,false),val(a,addr,1,true),
         val(a,addr,2,false),val(a,addr,2,true)
end
local function export_csv()
  if #frames==0 then console.log("[BALL_Z] No frames. Press T to record.");return end
  local filename=os.date("issd_ball_z_%Y%m%d_%H%M%S.csv")
  local file,err=io.open(filename,"w")
  if not file then console.log("[BALL_Z] CSV error: "..tostring(err));return end
  local header={"frame","ball_x","ball_y","possession"}
  for _,addr in ipairs(WATCH) do
    for _,typ in ipairs({"u8","s8","u16","s16"}) do
      header[#header+1]=string.format("addr_%05X_%s",addr,typ)
    end
  end
  file:write(table.concat(header,",").."\n")
  for _,r in ipairs(frames) do
    local line={r.frame,r.ball_x,r.ball_y,r.possession}
    for _,addr in ipairs(WATCH) do
      local u8,s8,u16,s16=row_values(r.bytes,addr)
      line[#line+1]=u8 or ""
      line[#line+1]=s8 or ""
      line[#line+1]=u16 or ""
      line[#line+1]=s16 or ""
    end
    for i=1,#line do line[i]=tostring(line[i]) end
    file:write(table.concat(line,",").."\n")
  end
  file:close()
  console.log(string.format("[BALL_Z] exported %d frames to %s",#frames,filename))
end
local function sample_frame()
  if #frames>=MAX_FRAMES then
    recording=false;console.log("[BALL_Z] auto-stopped at frame limit")
    return
  end
  local a=read_all()
  frames[#frames+1]={
    frame=frame,bytes=a,
    ball_x=val(a,0x042A,2,true),
    ball_y=val(a,0x042C,2,true),
    possession=val(a,0x00A6,2,false)
  }
end
console.log("[BALL_Z v2] G ground R rolling A air H apex C rank K clear")
console.log("[BALL_Z v2] T record/stop V CSV export J clear recording")
while true do
  local keys=input.get()
  if edge(keys,"K") then
    for _,name in ipairs(ORDER) do samples[name]={} end
    console.log("[BALL_Z] class samples cleared")
  end
  if edge(keys,"J") then
    recording=false;frames={}
    console.log("[BALL_Z] recording cleared")
  end
  for key,name in pairs(LABEL) do
    if edge(keys,key) then capture(name) end
  end
  if edge(keys,"C") then rank_classes() end
  if edge(keys,"T") then
    recording=not recording
    console.log("[BALL_Z] recording="..tostring(recording)..", frames="..#frames)
  end
  if recording then sample_frame() end
  if edge(keys,"V") then export_csv() end
  gui.text(8,8,string.format("BALL Z v2 rec=%s frames=%d/%d",
    recording and "ON" or "OFF",#frames,MAX_FRAMES))
  gui.text(8,22,"T record V export J clear / G R A H C K")
  previous=keys
  frame=frame+1
  emu.frameadvance()
end
