-- GS=1 attacking corner. The kick is executed by the confirmed taker;
-- do not chase the corner ball with directional movement.
local M={}
function M.new(config,players,field_side,mem)
 local c=config.CORNER_KICK
 local o={taker=nil,stable=0,attempts=0,cooldown=0,
          fired_x=nil,fired_y=nil,ball_moved=false,
          retry_cycle=0,cycle_wait=0,last_ball_x=nil,last_ball_y=nil}
 function o.reset()
  o.taker=nil;o.stable=0;o.attempts=0;o.cooldown=0
  o.fired_x=nil;o.fired_y=nil;o.ball_moved=false
  o.retry_cycle=0;o.cycle_wait=0;o.last_ball_x=nil;o.last_ball_y=nil
 end
 function o.plan(bx,by,taker,team)
  if o.cooldown>0 then o.cooldown=o.cooldown-1 end
  if o.cycle_wait>0 then o.cycle_wait=o.cycle_wait-1 end
  local displacement=0
  if o.fired_x~=nil then
   displacement=math.sqrt((bx-o.fired_x)^2+(by-o.fired_y)^2)
   if displacement>=c.ball_move_threshold then o.ball_moved=true end
  end
  local dir=field_side.attack_direction()
  if team~="MY" or not players.valid_my_base(taker)
     or taker==config.MY_FIRST or (dir~=1 and dir~=-1) then
   o.reset()
   return nil
  end
  local length=mem.u16(config.ADDR.field_length)
  local width=mem.u16(config.ADDR.field_width)
  local cx=mem.u16(config.ADDR.center_field_x)
  local cy=mem.u16(config.ADDR.center_field_y)
  if length<500 or length>4000 or width<200 or width>2000
     or cx<100 then return nil end
  local end_x=cx+dir*length/2
  local end_distance=math.abs(bx-end_x)
  local side_distance=math.abs(math.abs(by-cy)-width/2)
  local px,py=players.xy(taker)
  local taker_distance=math.sqrt((px-bx)^2+(py-by)^2)
  if end_distance>c.endline_tolerance
     or side_distance>c.sideline_tolerance
     or taker_distance>c.max_taker_distance then
   o.reset();return nil
  end
  if o.taker~=taker then
   o.reset()
   o.taker=taker
  end
  o.stable=o.stable+1
  local buttons={c.cross_button,c.short_button,c.cross_button}
  local index=math.min(o.attempts+1,#buttons)
  local button=buttons[index]
  -- Retry with plain A/B (no pad direction) first. This distinguishes
  -- restart acceptance from the direction modifier that could block it.
  local direction=nil
  if o.attempts==2 then direction=by>cy and "Up" or "Down" end
  local reason="READY"
  if o.ball_moved then reason="BALL_MOVED"
  elseif o.stable<c.stable_frames then reason="STABILIZING"
  elseif o.cooldown>0 then reason="COOLDOWN"
  elseif o.attempts>=c.max_attempts then reason="EXHAUSTED" end
  return {mode=index==1 and "HIGH_CROSS" or index==2 and "SHORT_PASS" or "AIMED_HIGH_CROSS",
    button=button,direction=direction,taker=taker,stable=o.stable,
    end_distance=end_distance,side_distance=side_distance,
    taker_distance=taker_distance,attempts=o.attempts,
    cooldown=o.cooldown,reason=reason,displacement=displacement,
    ball_x=bx,ball_y=by}
 end
 function o.fire(plan,movement)
  if not plan or plan.reason~="READY" then return false end
  movement.press_direction_button(plan.direction,plan.button)
  o.attempts=o.attempts+1
  o.cooldown=c.retry_frames
  o.fired_x,o.fired_y=plan.ball_x,plan.ball_y
  return true
 end
 return o
end
return M
