-- ISSD Ball Height Watch: validate candidate vertical state in live BizHawk.
-- Run standalone. Read-only WRAM; optional CSV written to local working dir.
-- T = start/stop recording; V = export recorded CSV; J = clear recordings.
-- Candidate s16 reads: 0x0410 (primary), 0x19E8 (comparison).
local DOMAIN="WRAM"
local A=0x0410
local B=0x19E8
local ZERO_TOL=3
local MOVE_TOL=2
local MAX_ROWS=3600
local previous={}
local recording=false
local rows={}
local frame=0
local previous_a=nil
local previous_b=nil
local last_phase="UNKNOWN"
local events={}
local function edge(keys,key) return keys[key] and not previous[key] end
local function s16(addr) return memory.read_s16_le(addr,DOMAIN) end
local function u16(addr) return memory.read_u16_le(addr,DOMAIN) end
local function classify(z,prior)
  local height=math.max(0,-z)
  if height<=ZERO_TOL then return "GROUND" end
  if prior==nil then return "AIR_UNKNOWN" end
  local delta=-(z-prior)
  if delta>MOVE_TOL then return "RISING" end
  if delta< -MOVE_TOL then return "FALLING" end
  return "APEX_OR_STABLE"
end
local function export()
  if #rows==0 then console.log("[BALL_HEIGHT] No samples");return end
  local filename=os.date("issd_ball_height_watch_%Y%m%d_%H%M%S.csv")
  local f,e=io.open(filename,"w")
  if not f then console.log("[BALL_HEIGHT] CSV error: "..tostring(e));return end
  f:write("frame,ball_x,ball_y,possession,z_0410,z_19e8,height_0410,height_19e8,delta_0410,delta_19e8,difference,phase_0410,phase_19e8,event\n")
  for _,r in ipairs(rows) do
    f:write(table.concat(r,",").."\n")
  end
  f:close()
  console.log(string.format("[BALL_HEIGHT] Exported %d frames to %s",#rows,filename))
end
local function update()
  local a,b=s16(A),s16(B)
  local da=previous_a and (a-previous_a) or 0
  local db=previous_b and (b-previous_b) or 0
  local pa=classify(a,previous_a)
  local pb=classify(b,previous_b)
  local event=""
  if pa~=last_phase then
    event=last_phase.."->"..pa
    events[#events+1]={frame=frame,phase=pa}
    if #events>25 then table.remove(events,1) end
  end
  -- Ground->Rising after prior airborne passage is only a bounce hypothesis.
  if recording and #rows<MAX_ROWS then
    rows[#rows+1]={
      frame,s16(0x042A),s16(0x042C),u16(0x00A6),
      a,b,math.max(0,-a),math.max(0,-b),da,db,
      a-b,pa,pb,event
    }
  elseif recording and #rows>=MAX_ROWS then
    recording=false
    console.log("[BALL_HEIGHT] Auto-stop at "..MAX_ROWS.." rows")
  end
  if event~="" then
    console.log(string.format("[BALL_HEIGHT] frame=%d %s zA=%d zB=%d deltaA=%d deltaB=%d diff=%d",
      frame,event,a,b,da,db,a-b))
  end
  previous_a,previous_b=a,b
  last_phase=pa
  gui.text(8,8,string.format("BALL Z WATCH %s frame=%d",recording and "REC" or "IDLE",frame))
  gui.text(8,22,string.format("0410=%d h=%d d=%d %s",a,math.max(0,-a),da,pa))
  gui.text(8,36,string.format("19E8=%d h=%d d=%d %s",b,math.max(0,-b),db,pb))
  gui.text(8,50,string.format("difference=%d samples=%d/%d",a-b,#rows,MAX_ROWS))
  gui.text(8,64,"T record/stop V export J clear")
end
console.log("[BALL_HEIGHT] Read-only watch; 0410/19E8 are unvalidated candidates.")
console.log("[BALL_HEIGHT] T=record/stop V=CSV J=clear")
while true do
  local keys=input.get()
  if edge(keys,"J") then
    recording=false;rows={};events={}
    console.log("[BALL_HEIGHT] Samples cleared")
  end
  if edge(keys,"T") then
    recording=not recording
    console.log("[BALL_HEIGHT] recording="..tostring(recording))
  end
  update()
  if edge(keys,"V") then export() end
  previous=keys
  frame=frame+1
  emu.frameadvance()
end
