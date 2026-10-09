-- GS=1 corner restart. A single frame pulse may not start the animation.
-- Observe the selected player, hold each kick briefly, and never deadlock exhausted.
local M={}
function M.new(config,players,field_side,mem)
 local c=config.CORNER_KICK
 local o={taker=nil,stable=0,attempts=0,cooldown=0,
          fired_x=nil,fired_y=nil,ball_moved=false,held=0,
          control_wait=0,switches=0,recovery=0}
 function o.reset()
  o.taker=nil;o.stable=0;o.attempts=0;o.cooldown=0
  o.fired_x=nil;o.fired_y=nil;o.ball_moved=false;o.held=0
  o.control_wait=0;o.switches=0;o.recovery=0
 end
 function o.plan(bx,by,taker,team,controlled)
  local dir=field_side.attack_direction()
  if team~="MY" or not players.valid_my_base(taker)
    or taker==config.MY_FIRST or (dir~=1 and dir~=-1) then o.reset();return nil end
  local len=mem.u16(config.ADDR.field_length)
  local width=mem.u16(config.ADDR.field_width)
  local cx=mem.u16(config.ADDR.center_field_x)
  local cy=mem.u16(config.ADDR.center_field_y)
  if len<500 or len>4000 or width<200 or width>2000 or cx<100 then return nil end
  local ed=math.abs(bx-(cx+dir*len/2))
  local sd=math.abs(math.abs(by-cy)-width/2)
  local px,py=players.xy(taker)
  local td=math.sqrt((px-bx)^2+(py-by)^2)
  if ed>c.endline_tolerance or sd>c.sideline_tolerance
    or td>c.max_taker_distance then o.reset();return nil end
  if o.taker~=taker then o.reset();o.taker=taker end
  o.stable=o.stable+1
  if o.cooldown>0 then o.cooldown=o.cooldown-1 end
  local displacement=0
  if o.fired_x then
   displacement=math.sqrt((bx-o.fired_x)^2+(by-o.fired_y)^2)
   if displacement>=c.ball_move_threshold then o.ball_moved=true end
  end
  local reason="READY"
  if o.ball_moved then reason="BALL_MOVED"
  elseif controlled~=taker then
   o.control_wait=o.control_wait+1
   if o.control_wait>=c.switch_interval and o.switches<c.max_switches then
    o.control_wait=0;o.switches=o.switches+1;reason="SWITCH_TAKER"
   else reason="WAIT_CONTROL" end
  elseif o.held>0 then reason="HOLD_BUTTON"
  elseif o.stable<c.stable_frames then reason="STABILIZING"
  elseif o.cooldown>0 then reason="COOLDOWN"
  elseif o.attempts>=c.max_attempts then
   o.recovery=o.recovery+1
   if o.recovery>=c.exhausted_recovery_frames then
    o.attempts=0;o.recovery=0;reason="RECOVERY_RETRY"
   else reason="EXHAUSTED_WAIT" end
  else o.control_wait=0 end
  local buttons={c.cross_button,c.short_button,c.shot_button}
  local n=math.min(o.attempts+1,#buttons)
  local button=buttons[n]
  local direction=nil
  if n==3 then direction=by>cy and "Up" or "Down" end
  return {reason=reason,mode=n==1 and "CROSS" or n==2 and "SHORT" or "SHOT_RETRY",
    taker=taker,controlled=controlled,button=button,direction=direction,
    attempts=o.attempts,stable=o.stable,cooldown=o.cooldown,
    end_distance=ed,side_distance=sd,taker_distance=td,
    displacement=displacement,ball_x=bx,ball_y=by,switches=o.switches}
 end
 function o.fire(plan,movement)
  if not plan then return false end
  if plan.reason=="SWITCH_TAKER" then
   movement.press_button("R");return false
  end
  if plan.reason=="HOLD_BUTTON" then
   movement.press_direction_button(plan.direction,plan.button)
   o.held=o.held-1;return false
  end
  if plan.reason~="READY" and plan.reason~="RECOVERY_RETRY" then return false end
  movement.press_direction_button(plan.direction,plan.button)
  o.attempts=o.attempts+1
  o.held=c.hold_frames-1
  o.cooldown=c.retry_frames
  o.fired_x,o.fired_y=plan.ball_x,plan.ball_y
  return true
 end
 return o
end
return M
