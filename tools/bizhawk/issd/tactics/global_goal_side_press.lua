-- Global goal-side interposition and progressive press.
-- Player selection remains unchanged; only the selected outfielder is driven.
local M={}
function M.new(config,players)
 local cfg=config.GLOBAL_GOAL_SIDE_PRESS
 local o={carrier=nil,defender=nil,phase="INTERPOSE"}
 function o.reset() o.carrier=nil;o.defender=nil;o.phase="INTERPOSE" end
 function o.plan(defender,carrier)
  if not cfg.enabled or not players.valid_my_base(defender)
      or defender==config.MY_FIRST or not players.valid_cpu_base(carrier)
      or carrier==config.CPU_FIRST then o.reset();return nil end
  if o.carrier~=carrier or o.defender~=defender then
   o.phase="INTERPOSE";o.carrier=carrier;o.defender=defender
  end
  local px,py=players.xy(defender)
  local cx,cy=players.xy(carrier)
  local gx,gy=players.xy(config.MY_FIRST)
  local vx,vy=gx-cx,gy-cy
  local length=math.sqrt(vx*vx+vy*vy)
  if length<cfg.min_goal_distance then o.reset();return nil end
  local dx,dy=px-cx,py-cy
  local along=(dx*vx+dy*vy)/length
  local lateral=math.abs(dx*vy-dy*vx)/length
  local distance=math.sqrt(dx*dx+dy*dy)
  -- Close to our goal the established v51 shot-blocking routine has priority.
  local sector=length<=cfg.defense_radius and "DEFENSE"
      or length<=cfg.midfield_radius and "MIDFIELD" or "ATTACK"
  if sector=="DEFENSE" then o.phase="INTERPOSE";return nil end
  local width=sector=="MIDFIELD" and cfg.midfield_width or cfg.attack_width
  local enter=width*cfg.enter_fraction
  local safe=along>=cfg.min_along and along<=length-cfg.goal_margin
     and lateral<=width
  if o.phase=="PRESS" and not safe then o.phase="INTERPOSE" end
  if o.phase=="INTERPOSE" and safe and lateral<=enter then
   o.phase="PRESS"
  end
  local target_along=math.min(cfg.cover_offset,length*cfg.max_fraction)
  local tx,ty
  if o.phase=="PRESS" then
   target_along=sector=="MIDFIELD" and cfg.midfield_press_offset
       or cfg.attack_press_offset
   target_along=math.min(target_along,length-cfg.goal_margin)
  end
  tx=cx+vx/length*target_along
  ty=cy+vy/length*target_along
  local target_distance=math.sqrt((tx-px)^2+(ty-py)^2)
  if target_distance<=cfg.deadzone then
   return {phase=o.phase,sector=sector,lateral=lateral,along=along,
    distance=distance,hold=true,target_x=tx,target_y=ty}
  end
  return {phase=o.phase,sector=sector,lateral=lateral,along=along,
    distance=distance,target_x=tx,target_y=ty,hold=false}
 end
 return o
end
return M
