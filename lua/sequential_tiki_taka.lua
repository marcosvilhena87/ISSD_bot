-- Sequential one-player tiki-taka planner. Pure recommendations, no joypad.
local Tiki=require("tiki_taka")
local M={}
local function distance(a,b)
 local x,y=a.x-b.x,a.y-b.y
 return math.sqrt(x*x+y*y)
end
local function lane(a,b,enemies)
 local best=math.huge
 local dx,dy=b.x-a.x,b.y-a.y
 local den=dx*dx+dy*dy
 for _,e in ipairs(enemies) do
  if type(e.x)=="number" and type(e.y)=="number" then
   local t=den>0 and ((e.x-a.x)*dx+(e.y-a.y)*dy)/den or 0
   t=math.max(0,math.min(1,t))
   local d=distance(e,{x=a.x+t*dx,y=a.y+t*dy})
   if d<best then best=d end
  end
 end
 return best
end
local DIRECTIONS={{1,0},{1,1},{0,1},{-1,1},{-1,0},{-1,-1},{0,-1},{1,-1}}
local function find(list,id)
 for _,p in ipairs(list or {}) do if p.id==id then return p end end
end
function M.new(config)
 config=config or {}
 local pass=Tiki.new(config.tiki_taka)
 local step=config.dribble_step or 65
 local min_clear=config.dribble_clearance or 75
 local max_pass=(config.tiki_taka and config.tiki_taka.max_pass_distance) or 320
 local min_pass=(config.tiki_taka and config.tiki_taka.min_pass_distance) or 35
 local pass_clear=(config.tiki_taka and config.tiki_taka.opponent_clearance) or 65
 local pending=nil
 local last_frame=nil
 local function reset() pending=nil;last_frame=nil;pass.reset() end
 local function update(s)
  if type(s)~="table" or type(s.frame)~="number" then reset();return {mode="HOLD",reason="invalid_state"} end
  if last_frame and s.frame<last_frame then reset() end
  last_frame=s.frame
  if s.active~=true or s.possession~="my" then
   if pending and s.raw_owner==0 then return {mode="WAIT_RECEIVE",reason="unconfirmed_ball_flight",target_id=pending} end
   reset();return {mode="HOLD",reason="possession_unconfirmed"}
  end
  if pending then
   if s.carrier_id==pending then
    pending=nil
    pass.reset()
    return {mode="REPLAN",reason="reception_confirmed"}
   elseif s.carrier_id~=nil then
    pending=nil
    pass.reset()
    return {mode="REPLAN",reason="different_carrier"}
   end
  end
  local base=pass.update(s)
  if base.mode=="PASS" then
   local triangle=nil
   local receiver=find(s.my_players,base.target_id)
   if receiver then
    local best=-math.huge
    for _,third in ipairs(s.my_players) do
     if third.id~=receiver.id and third.id~=s.carrier_id and not third.is_goalkeeper then
      local d=distance(receiver,third)
      local clear=lane(receiver,third,s.cpu_players)
      if d>=min_pass and d<=max_pass and clear>=pass_clear then
       local score=clear-d*0.18
       if score>best then best=score;triangle={via=receiver.id,next_id=third.id,score=score} end
      end
     end
    end
   end
   base.triangle=triangle
   return {mode="PASS_READY",target_id=base.target_id,pass_type=base.pass_type,
     pass_score=base.pass_score,pass_clearance=base.pass_clearance,
     pass_progression=base.pass_progression,reason=base.reason,
     base=base,triangle=triangle}
  end
  local carrier=find(s.my_players,s.carrier_id)
  if not carrier then return {mode="HOLD",reason="carrier_missing",base=base} end
  local best=nil
  local best_score=-math.huge
  for _,v in ipairs(DIRECTIONS) do
   local norm=math.sqrt(v[1]*v[1]+v[2]*v[2])
   local p={x=carrier.x+v[1]*step/norm,y=carrier.y+v[2]*step/norm}
   local valid=true
   -- Conservative field dimensions, when provided by the state provider.
   if s.field_length and (p.x<4 or p.x>s.field_length-4) then valid=false end
   if s.field_width and (p.y<4 or p.y>s.field_width-4) then valid=false end
   local min_enemy=math.huge
   for _,e in ipairs(s.cpu_players) do
    min_enemy=math.min(min_enemy,distance(p,e))
   end
   if min_enemy<min_clear then valid=false end
   local count=0
   local closest=math.huge
   for _,mate in ipairs(s.my_players) do
    if mate.id~=s.carrier_id and not mate.is_goalkeeper then
     local d=distance(p,mate)
     if d<closest then closest=d end
     if d>=min_pass and d<=max_pass and lane(p,mate,s.cpu_players)>=pass_clear then count=count+1 end
    end
   end
   local goal_dx=s.opponent_goal.x-s.own_goal.x
   local goal_dy=s.opponent_goal.y-s.own_goal.y
   local projected=v[1]*goal_dx+v[2]*goal_dy
   -- When everybody is too far, safely approach the nearest teammate.
   local score=count*10000-closest+math.min(min_enemy,400)*0.01+projected*0.0001
   if valid and closest<math.huge and score>best_score then
    best_score=score;best={x=p.x,y=p.y,score=score,open_passes=count}
   end
  end
  if best then return {mode="DRIBBLE",reason=best.open_passes>0 and "open_short_pass" or "approach_support",dribble=best,base=base} end
  return {mode="HOLD",reason="no_safe_dribble",base=base}
 end
 -- A controller can call this ONLY after confirming that an actual pass began.
 local function confirm_pass(target_id,frame)
  if target_id==nil or type(frame)~="number" then return false end
  pending=target_id
  pass.confirm_pass(target_id,frame)
  return true
 end
 return {update=update,reset=reset,confirm_pass=confirm_pass}
end
return M
