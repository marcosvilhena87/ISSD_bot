-- GS=3 foul or GS=4 offside free kick: validate Brazilian taker, settle, pulse and retry.
local M={}
function M.new(config,players,field_side)
 local c=config.FREE_KICK
 local o={candidate=nil,stable=0,attempts=0,cooldown=0,
          kick_x=nil,kick_y=nil,ball_moved=false,control_wait=0,switches=0}
 local function dist(ax,ay,bx,by)
  return math.sqrt((ax-bx)^2+(ay-by)^2)
 end
 function o.reset()
  o.candidate=nil;o.stable=0;o.attempts=0;o.cooldown=0
  o.kick_x=nil;o.kick_y=nil;o.ball_moved=false
  o.control_wait=0;o.switches=0
 end
 function o.plan(bx,by,controlled,gs)
  if o.cooldown>0 then o.cooldown=o.cooldown-1 end
  local displacement=0
  if o.kick_x~=nil then
   displacement=dist(bx,by,o.kick_x,o.kick_y)
   if displacement>=c.ball_move_threshold then o.ball_moved=true end
  end
  local my,md=nil,math.huge
  players.each_my(function(base)
   if base~=config.MY_FIRST then
    local x,y=players.xy(base)
    local d=dist(x,y,bx,by)
    if d<md then my,md=base,d end
   end
  end)
  local cd=math.huge
  players.each_cpu(function(base)
   local x,y=players.xy(base)
   cd=math.min(cd,dist(x,y,bx,by))
  end)
  local dir=field_side.attack_direction()
  local result={taker=my,my_distance=md,cpu_distance=cd,
    stable=o.stable,attempts=o.attempts,cooldown=o.cooldown,
    displacement=displacement}
  if not my or dir==0 or md>c.max_taker_distance
    or md+c.team_margin>=cd then
   o.candidate=nil;o.stable=0
   result.mode="WAIT_TAKER"
   return result
  end
  result.our_restart=true
  if o.candidate~=my then
   o.candidate=my;o.stable=0;o.control_wait=0;o.switches=0
  end
  o.stable=o.stable+1;result.stable=o.stable
  if o.ball_moved then result.mode="BALL_MOVED";return result end
  if controlled~=my then
   o.control_wait=o.control_wait+1
   if o.control_wait>=c.switch_interval and o.switches<c.max_switch_attempts then
    o.control_wait=0;o.switches=o.switches+1
    result.mode="SWITCH_TAKER";result.button="R"
   else
    result.mode="WAIT_CONTROL"
   end
   result.switches=o.switches
   return result
  end
  o.control_wait=0
  local min_stable=gs==4 and c.offside_stable_frames or c.stable_frames
  if o.stable<min_stable then result.mode="WAIT_STABLE";return result end
  if o.attempts>=c.max_attempts then result.mode="EXHAUSTED";return result end
  if o.cooldown>0 then result.mode="COOLDOWN";return result end
  local gx,gy=players.xy(config.CPU_FIRST)
  local mode="PASS"
  local button=c.pass_button
  if dist(bx,by,gx,gy)<=c.shot_max_distance
     and (gx-bx)*dir>0 then
   mode="SHOT";button=c.shot_button
  end
  if o.attempts>0 then mode="RETRY_LONG";button=c.long_button end
  result.mode=mode;result.button=button
  result.direction=dir==1 and "Right" or "Left"
  return result
 end
 function o.fire(plan,movement)
  if not plan then return false end
  if plan.mode=="SWITCH_TAKER" then
   movement.press_button("R")
   return true
  end
  if plan.mode~="PASS" and plan.mode~="SHOT"
     and plan.mode~="RETRY_LONG" then return false end
  if o.cooldown>0 or o.attempts>=c.max_attempts or o.ball_moved then return false end
  movement.press_direction_button(plan.direction,plan.button)
  o.attempts=o.attempts+1
  o.cooldown=c.retry_frames
  return true
 end
 function o.remember_ball(bx,by)
  o.kick_x=bx;o.kick_y=by
 end
 return o
end
return M
