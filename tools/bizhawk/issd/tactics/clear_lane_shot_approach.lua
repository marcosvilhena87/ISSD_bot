-- Bounded dribble before an otherwise valid, unobstructed shot.
-- Only the selected carrier moves; any new risk returns control to shoot.plan.
local M={}
function M.new(config,players,field_side)
 local c=config.CLEAR_LANE_SHOT_APPROACH
 local o={run=nil,done_carrier=nil,last_evaluation=nil}
 function o.evaluation() return o.last_evaluation end
 function o.reset() o.run=nil;o.done_carrier=nil end
 local function risk(carrier,gx,gy,px,py)
  local nearest=math.huge
  local blocked=false
  local nearest_ahead=math.huge
  local nearest_behind=math.huge
  local vx,vy=gx-px,gy-py
  local d=math.sqrt(vx*vx+vy*vy)
  players.each_cpu(function(base)
   if base~=config.CPU_FIRST then
    local ex,ey=players.xy(base)
    local dd=math.sqrt((ex-px)^2+(ey-py)^2)
    if dd<nearest then nearest=dd end
    local longitudinal=((ex-px)*vx+(ey-py)*vy)/d
    if longitudinal>=0 then nearest_ahead=math.min(nearest_ahead,dd)
    else nearest_behind=math.min(nearest_behind,dd) end
    local along=longitudinal/d
    local lateral=math.abs((ex-px)*vy-(ey-py)*vx)/d
    if along>0 and along<1 and lateral<c.lane_width then
     blocked=true
    end
   end
  end)
  return blocked,nearest,nearest_ahead,nearest_behind
 end
 function o.update(frame,carrier,shot)
  if not c.enabled or not players.valid_my_base(carrier) or
      carrier==config.MY_FIRST then o.reset();return nil end
  if o.run and o.run.carrier~=carrier then o.reset() end
  if o.done_carrier and o.done_carrier~=carrier then o.done_carrier=nil end
  local px,py=players.xy(carrier)
  local gx,gy=players.xy(config.CPU_FIRST)
  local dir=field_side.attack_direction()
  if dir==0 then
   o.last_evaluation={frame=frame,carrier=carrier,reason="INVALID_DIRECTION"}
   return nil
  end
  local forward=(gx-px)*dir
  local distance=math.sqrt((gx-px)^2+(gy-py)^2)
  local blocked,nearest,ahead,behind=risk(carrier,gx,gy,px,py)
  local function evaluate(reason)
   o.last_evaluation={frame=frame,carrier=carrier,reason=reason,blocked=blocked,
     nearest=nearest,nearest_ahead=ahead,nearest_behind=behind,
     distance=distance,forward=forward,shot_ready=shot~=nil}
  end
  local r=o.run
  if r then
   local reason=nil
   if frame-r.start>=c.max_frames then reason="TIMEOUT"
   elseif forward<=c.min_forward or distance<=c.target_distance then reason="TARGET_REACHED"
   elseif blocked then reason="LANE_BLOCKED"
   elseif nearest<c.min_defender_clearance then reason="DEFENDER_CLOSE"
   elseif math.abs(py-r.start_y)>c.max_lateral_drift then reason="LATERAL_DRIFT"
   elseif (px-r.start_x)*r.dir>=c.max_advance then reason="ADVANCE_LIMIT"
   elseif dir~=r.dir then reason="DIRECTION_CHANGED" end
   if reason then
    evaluate(reason)
    o.run=nil;o.done_carrier=carrier
    return {kind="END",reason=reason,distance=distance,nearest=nearest,
        gain=(px-r.start_x)*r.dir,carrier=carrier}
   end
   evaluate("APPROACH_ACTIVE")
   return {kind="MOVE",direction=dir==1 and "Right" or "Left",
       distance=distance,nearest=nearest,carrier=carrier,
       age=frame-r.start,gain=(px-r.start_x)*dir}
  end
  local reason="READY"
  if o.done_carrier==carrier then reason="ALREADY_ATTEMPTED"
  elseif not shot then reason="NO_VALID_SHOT"
  elseif blocked then reason="LANE_BLOCKED"
  elseif nearest<c.min_defender_clearance then reason="DEFENDER_CLOSE"
  elseif distance<=c.target_distance+c.start_margin then reason="ALREADY_CLOSE"
  elseif forward<=c.min_forward+c.start_margin then reason="GOAL_TOO_CLOSE" end
  evaluate(reason)
  if reason~="READY" then return nil end
  o.run={carrier=carrier,start=frame,start_x=px,start_y=py,dir=dir}
  return {kind="MOVE",direction=dir==1 and "Right" or "Left",
      distance=distance,nearest=nearest,carrier=carrier,age=0,gain=0,start=true}
 end
 return o
end
return M
