-- Passive defender/header opportunity monitor. Never sends controller input.
local M={}
function M.new(config,players)
 local c=config.AERIAL_DEFENSIVE_CONTACT
 local o={prev_height=nil,active=false,age=0,cooldown=0}
 function o.reset()
  o.prev_height=nil;o.active=false;o.age=0;o.cooldown=0
 end
 function o.update(state)
  if state.game_state~=0 or state.gameplay_active~=1 or state.possession~=0 then
   o.reset();return nil
  end
  local height=state.ball_height
  if height==nil then return nil end
  local delta=o.prev_height and height-o.prev_height or 0
  o.prev_height=height
  if o.cooldown>0 then o.cooldown=o.cooldown-1 end
  local best,dist=nil,math.huge
  players.each_my(function(base)
   if base~=config.MY_FIRST then
    local x,y=players.xy(base)
    local d=math.sqrt((state.ball_x-x)^2+(state.ball_y-y)^2)
    if d<dist then best,dist=base,d end
   end
  end)
  local candidate=height>=c.min_height and height<=c.max_height
    and dist<=c.max_distance and delta<=c.max_rising_delta
    and (state.ball_situation_class=="CPU_BALL_AERIAL"
      or state.ball_situation_class=="MY_BALL_AERIAL")
  if candidate then
   o.age=o.age+1
  else
   if o.active then
    o.active=false;o.age=0
    return {kind="END",reason=height<c.min_height and "LOW_HEIGHT"
       or height>c.max_height and "HIGH_HEIGHT"
       or dist>c.max_distance and "OUT_OF_RANGE" or "OTHER",
       height=height,distance=dist,nearest_base=best}
   end
   o.age=0
  end
  if candidate and not o.active and o.age>=c.confirm_frames and o.cooldown==0 then
   o.active=true;o.cooldown=c.cooldown_frames
   return {kind="START",height=height,delta=delta,distance=dist,
      nearest_base=best,ball_x=state.ball_x,ball_y=state.ball_y,
      classification=state.ball_situation_class}
  end
  return nil
 end
 return o
end
return M
