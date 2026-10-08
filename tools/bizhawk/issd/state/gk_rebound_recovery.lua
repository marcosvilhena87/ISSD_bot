-- GK rebound candidates: ball kinematics + recent CPU contact near our GK.
-- A candidate is not proof of a save; TeamPoss is never proof of control.
local M={}
function M.new(config,players)
 local c=config.GK_REBOUND_RECOVERY
 local o={last_cpu_frame=nil,last_x=nil,last_y=nil,last_dx=nil,last_dy=nil,
          last_height=nil,window_until=-1,start_frame=nil,sequence=0,
          candidate_frame=-9999,last_reason=nil}
 function o.reset()
  o.last_cpu_frame=nil;o.last_x=nil;o.last_y=nil
  o.last_dx=nil;o.last_dy=nil;o.last_height=nil
  o.window_until=-1;o.start_frame=nil;o.sequence=0
  o.candidate_frame=-9999;o.last_reason=nil
 end
 function o.active(frame) return o.window_until>=frame end
 function o.remaining(frame) return math.max(0,o.window_until-frame) end
 function o.update(state,frame)
  if state.game_state~=0 or state.gameplay_active~=1 then
   local was=o.active(frame)
   o.reset()
   return was and {kind="END",reason="STOPPAGE"} or nil
  end
  local gx,gy=players.xy(config.MY_FIRST)
  local bx,by=state.ball_x,state.ball_y
  if not bx or not by then return nil end
  local near=(bx-gx)^2+(by-gy)^2<=c.goal_radius*c.goal_radius
  local cpu=players.valid_cpu_base(state.possession)
  local my=players.valid_my_base(state.possession)
  local dx=o.last_x and bx-o.last_x or nil
  local dy=o.last_y and by-o.last_y or nil
  local speed=dx and math.sqrt(dx*dx+dy*dy) or 0
  local previous_speed=o.last_dx and math.sqrt(o.last_dx^2+o.last_dy^2) or 0
  local turn=false
  if dx and o.last_dx and speed>=c.min_speed and previous_speed>=c.min_speed then
   local dot=dx*o.last_dx+dy*o.last_dy
   local cos=dot/(speed*previous_speed)
   turn=cos<=c.max_direction_cosine
  end
  local acceleration=dx and o.last_dx and
      math.sqrt((dx-o.last_dx)^2+(dy-o.last_dy)^2) or 0
  local height=state.ball_height
  local height_change=height and o.last_height and height-o.last_height or 0
  -- A rapid trajectory change is stronger evidence than TeamPoss=MY.
  local deflection=turn or (acceleration>=c.min_acceleration and
      speed>=c.min_speed and previous_speed>=c.min_speed)
  local recent=o.last_cpu_frame and frame-o.last_cpu_frame<=c.recent_cpu_frames
  local event=nil
  if state.possession==0 and near and recent and deflection
     and height and height<=c.max_height
     and frame-o.candidate_frame>=c.candidate_cooldown_frames then
   o.sequence=o.sequence+1
   o.candidate_frame=frame
   o.window_until=frame+c.window_frames
   o.start_frame=frame
   o.last_reason=turn and "DIRECTION_CHANGE" or "SPEED_CHANGE"
   event={kind="CANDIDATE",reason=o.last_reason,sequence=o.sequence,
          speed=speed,acceleration=acceleration,height_change=height_change}
  end
  if o.active(frame) and not event then
   if cpu or my then
    event={kind="END",reason=cpu and "CPU_RECOVERED" or "MY_RECOVERED",
           sequence=o.sequence,elapsed=frame-(o.start_frame or frame)}
    o.window_until=-1
   elseif not near then
    event={kind="END",reason="LEFT_GK_AREA",sequence=o.sequence,
           elapsed=frame-(o.start_frame or frame)}
    o.window_until=-1
   end
  elseif o.window_until>=0 and not event then
   event={kind="END",reason="TIMEOUT",sequence=o.sequence,
          elapsed=frame-(o.start_frame or frame)}
   o.window_until=-1
  end
  if cpu and near then o.last_cpu_frame=frame end
  o.last_x,o.last_y=bx,by
  o.last_dx,o.last_dy=dx,dy
  o.last_height=height
  return event
 end
 return o
end
return M
