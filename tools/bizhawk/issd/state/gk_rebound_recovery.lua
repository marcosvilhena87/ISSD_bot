-- Conservative goalkeeper-rebound inference. TeamPoss alone is never a save.
local M={}
function M.new(config,players)
 local c=config.GK_REBOUND_RECOVERY
 local o={last_cpu_frame=nil,last_ball_x=nil,last_ball_y=nil,
          previous_dx=nil,window_until=-1,start_frame=nil}
 function o.reset()
  o.last_cpu_frame=nil;o.last_ball_x=nil;o.last_ball_y=nil
  o.previous_dx=nil;o.window_until=-1;o.start_frame=nil
 end
 function o.update(state,frame)
  if state.game_state~=0 or state.gameplay_active~=1 then
   local was=o.window_until>=frame
   o.reset()
   return was and {kind="END",reason="STOPPAGE"} or nil
  end
  local gx,gy=players.xy(config.MY_FIRST)
  local bx,by=state.ball_x,state.ball_y
  local near=(bx-gx)^2+(by-gy)^2<=c.goal_radius*c.goal_radius
  local cpu=players.valid_cpu_base(state.possession)
  local my=players.valid_my_base(state.possession)
  local event=nil
  if cpu and near then o.last_cpu_frame=frame end
  local dx=o.last_ball_x and bx-o.last_ball_x or nil
  -- Rebound candidate: recent CPU carrier, ball reaches keeper area, then
  -- reverses substantial horizontal direction while individually unowned.
  if state.possession==0 and near and o.last_cpu_frame
   and frame-o.last_cpu_frame<=c.recent_cpu_frames
   and dx and o.previous_dx and dx*o.previous_dx<0
   and math.abs(dx)>=c.min_reversal_speed
   and math.abs(o.previous_dx)>=c.min_reversal_speed
   and state.ball_height and state.ball_height<=c.max_height then
    o.window_until=frame+c.window_frames
    o.start_frame=frame
    event={kind="CANDIDATE",reason="CPU_SHOT_REVERSED_NEAR_GK"}
  end
  if o.window_until>=frame then
   if cpu or my then
    event={kind="END",reason=cpu and "CPU_RECOVERED" or "MY_RECOVERED",
           elapsed=frame-(o.start_frame or frame)}
    o.window_until=-1
   elseif not near then
    event={kind="END",reason="LEFT_GK_AREA",
           elapsed=frame-(o.start_frame or frame)}
    o.window_until=-1
   end
  elseif o.window_until>=0 then
   event={kind="END",reason="TIMEOUT",elapsed=frame-(o.start_frame or frame)}
   o.window_until=-1
  end
  o.previous_dx=dx
  o.last_ball_x,o.last_ball_y=bx,by
  return event
 end
 function o.active(frame)
  return o.window_until>=frame
 end
 return o
end
return M
