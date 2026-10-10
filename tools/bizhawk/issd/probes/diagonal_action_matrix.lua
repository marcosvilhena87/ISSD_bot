-- Controlled 4x4 directional action matrix for ISS Deluxe / BizHawk.
-- Run this script ALONE (not alongside main.lua) with a live match,
-- ball under MY individual control, and a reproducible starting position.
-- Each test reloads an in-memory savestate; no tactical behavior is changed.
local function script_dir()
 local src=debug.getinfo(1,"S").source
 if src:sub(1,1)=="@" then src=src:sub(2) end
 return src:match("^(.*[\\/])") or "./"
end
local DIR=script_dir()
local config=dofile(DIR.."../core/config.lua")
local Memory=dofile(DIR.."../core/memory.lua")
local mem=Memory.new(config)
local directions={
 {"Right","Up"},{"Right","Down"},{"Left","Up"},{"Left","Down"}
}
local actions={"A","B","X","Y"} -- requested order
local OBSERVE_FRAMES=30
local SETTLE_FRAMES=3
local OUTFILE=DIR.."../diagonal_action_matrix.csv"
local function sample()
 return {
  x=mem.s16(config.ADDR.ball_x),
  y=mem.s16(config.ADDR.ball_y),
  owner=mem.u16(config.ADDR.possession),
  team=mem.u16(config.ADDR.team_possession),
  game_state=mem.u16(config.ADDR.game_state),
  selected=mem.u16(config.ADDR.my_ctrl)
 }
end
local function csv(v)
 if v==nil then return "" end
 local s=tostring(v)
 if s:find('[,\\"\n]') then return '"'..s:gsub('"','""')..'"' end
 return s
end
local function write(file,fields)
 local out={}
 for _,v in ipairs(fields) do out[#out+1]=csv(v) end
 file:write(table.concat(out,",").."\n")
end
local function tick(pad)
 joypad.set(pad or {},config.PLAYER)
 emu.frameadvance()
end
local function run()
 if not savestate or not savestate.create or not savestate.save or not savestate.load then
  error("BizHawk in-memory savestate API unavailable; aborting")
 end
 local initial=sample()
 if initial.game_state~=0 or initial.owner<config.MY_FIRST
    or initial.owner>config.MY_LAST then
  error("Start with active play and ball held by MY player; no actions sent")
 end
 local ss=savestate.create()
 savestate.save(ss)
 local f=assert(io.open(OUTFILE,"w"))
 write(f,{"index","horizontal","vertical","button","command",
  "base_ball_x","base_ball_y","base_owner","base_team","base_selected",
  "action_dx","action_dy","action_owner","action_team",
  "end_dx","end_dy","end_owner","end_team","end_game_state",
  "max_displacement","first_owner_change_frame","first_ball_change_frame",
  "note"})
 local index=0
 for _,d in ipairs(directions) do
  for _,button in ipairs(actions) do
   index=index+1
   savestate.load(ss)
   for i=1,SETTLE_FRAMES do tick({}) end
   local before=sample()
   local pad={[d[1]]=true,[d[2]]=true,[button]=true}
   tick(pad)
   local after=sample()
   local max_distance=math.sqrt((after.x-before.x)^2+(after.y-before.y)^2)
   local first_owner_change=after.owner~=before.owner and 0 or nil
   local first_ball_change=(after.x~=before.x or after.y~=before.y) and 0 or nil
   local final=after
   for n=1,OBSERVE_FRAMES do
    tick({})
    final=sample()
    local distance=math.sqrt((final.x-before.x)^2+(final.y-before.y)^2)
    max_distance=math.max(max_distance,distance)
    if not first_owner_change and final.owner~=before.owner then first_owner_change=n end
    if not first_ball_change and
       (final.x~=before.x or final.y~=before.y) then first_ball_change=n end
   end
   write(f,{index,d[1],d[2],button,
    d[1].."+"..d[2].."+"..button,
    before.x,before.y,before.owner,before.team,before.selected,
    after.x-before.x,after.y-before.y,after.owner,after.team,
    final.x-before.x,final.y-before.y,final.owner,final.team,
    final.game_state,string.format("%.2f",max_distance),
    first_owner_change,first_ball_change,
    "OBSERVATION_ONLY_NOT_CONFIRMED_ACTION"})
   f:flush()
   print(string.format("Diagonal probe %d/16: %s+%s+%s",index,d[1],d[2],button))
  end
 end
 savestate.load(ss)
 joypad.set({},config.PLAYER)
 f:close()
 print("Diagonal matrix CSV: "..OUTFILE)
end
run()
