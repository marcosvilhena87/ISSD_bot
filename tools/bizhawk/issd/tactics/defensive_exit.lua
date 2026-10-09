local M={}
function M.new(config,players,field_side,mem)
 local c=config.DEFENSIVE_EXIT
 local o={carrier=nil,age=0,start_x=nil,start_y=nil,clearance_used=false,limit_age=0,
  total_start_x=nil,total_start_y=nil,reassessments=0,pending_frames=0,hold_streak=0,clear_attempts=0}
 local function d(x,y,a,b) return math.sqrt((x-a)^2+(y-b)^2) end
 local function space(x,y)
  local nearest=99999
  players.each_cpu(function(base)
   local a,b=players.xy(base);nearest=math.min(nearest,d(x,y,a,b))
  end)
  return nearest
 end
 function o.reset() o.carrier=nil;o.age=0;o.start_x=nil;o.start_y=nil;o.clearance_used=false
  o.limit_age=0;o.total_start_x=nil;o.total_start_y=nil
  o.reassessments=0;o.pending_frames=0;o.hold_streak=0;o.clear_attempts=0 end
 function o.on_pass() o.pending_frames=c.action_settle_frames;o.hold_streak=0 end
 local function hold(reason,threat,total)
  o.hold_streak=o.hold_streak+1
  if threat<=c.pressure_radius and o.hold_streak>=c.hold_timeout_frames then
   if o.clear_attempts<c.max_clear_attempts then
    o.clear_attempts=o.clear_attempts+1
    o.hold_streak=0
    o.pending_frames=c.action_settle_frames
    return {mode="CLEAR",button=c.clear_buttons[o.clear_attempts],
      direction=field_side.attack_direction()==1 and "Right" or "Left",
      reason="HOLD_TIMEOUT_RETRY",age=o.age,threat=threat,
      clear_attempts=o.clear_attempts}
   end
   return {mode="EXHAUSTED",reason="CLEAR_FAILED_HOLD_TIMEOUT",
     age=o.age,threat=threat,total=total,
     clear_attempts=o.clear_attempts}
  end
  return {mode="HOLD",reason=reason,age=o.age,threat=threat,total=total,
    hold_streak=o.hold_streak,clear_attempts=o.clear_attempts}
 end
 function o.plan(carrier,pass_cooldown)
  if o.carrier~=carrier then o.reset();o.carrier=carrier end
  o.age=o.age+1
  local x,y=players.xy(carrier)
  if not o.total_start_x then o.total_start_x,o.total_start_y=x,y end
  local threat=space(x,y)
  local pressured=threat<=c.pressure_radius
  local width=mem.u16(config.ADDR.field_width)
  local center=mem.u16(config.ADDR.center_field_y)
  local dir=field_side.attack_direction()
  if width<200 or width>2000 or dir==0 then return {mode="HOLD",reason="BAD_FIELD",threat=threat,age=o.age} end
  local low,high=center-width/2+c.field_margin,center+width/2-c.field_margin
  local best=nil
  -- A pass just commanded is not yet confirmed. Do not spam another B pulse
  -- while the game is still resolving it, even if cooldown is zero.
  if o.pending_frames==0 and pass_cooldown==0 then
   players.each_my(function(base)
    if base~=carrier and base~=config.MY_FIRST then
     local rx,ry=players.xy(base)
     local dx,dy=rx-x,ry-y
     local dst=d(x,y,rx,ry)
     if math.abs(dx)<=c.max_horizontal and math.abs(dy)>=c.lateral_min
       and math.abs(dy)<=c.lateral_max and dst<=c.max_pass_distance
       and ry>=low and ry<=high then
      local rc=space(rx,ry)
      local lane=99999
      players.each_cpu(function(cpu)
       local ex,ey=players.xy(cpu)
       local t=((ex-x)*dx+(ey-y)*dy)/(dst*dst)
       if t>0.05 and t<1.05 then
        local q=math.max(0,math.min(1,t))
        lane=math.min(lane,d(ex,ey,x+q*dx,y+q*dy))
       end
      end)
      if rc>=c.receiver_clearance and lane>=c.lane_clearance then
       -- Reward the receiver having a safe next step towards midfield.
       -- Penalize passing into the touchline even when the immediate
       -- receiving point is nominally clear.
       local rx_forward=rx+dir*c.outlet_next_step
       local next_space=space(rx_forward,ry)
       local next_safe=math.min(rc,next_space)
       local line_room=math.min(ry-low,high-ry)
       local score=math.min(rc,180)+math.min(lane,180)-dst*0.2
        +c.outlet_forward_space_weight*math.min(next_safe,180)
        +c.outlet_touchline_weight*math.min(line_room,120)
        +c.outlet_progress_weight*math.max(0,dx*dir)
       if not best or score>best.score then
        best={mode="PASS",button="B",direction=dy<0 and "Up" or "Down",
         receiver=base,distance=dst,receiver_clearance=rc,
         lane_clearance=lane,score=score,age=o.age,
         forward=dx*dir,lateral=math.abs(dy),
         next_clearance=next_safe,line_room=line_room,
         intent="DEFENSIVE_LATERAL"}
       end
      end
     end
    end
   end)
  end
  if best then o.hold_streak=0;best.threat=threat;return best end
  if o.pending_frames>0 then
   o.pending_frames=o.pending_frames-1
   return {mode="HOLD",reason="ACTION_SETTLING",age=o.age,threat=threat}
  end
  if not pressured and o.age<c.hold_before_move then return hold("WAIT_OUTLET",threat) end
  if not o.start_x then o.start_x,o.start_y=x,y end
  if d(x,y,o.start_x,o.start_y)>=c.max_advance then
   o.limit_age=o.limit_age+1
   -- Never allow indefinite stationary possession, but cap overall travel.
   local total=d(x,y,o.total_start_x,o.total_start_y)
   -- Renew a short escape segment only after real forward progress and
   -- only when the carrier remains unpressured with room directly ahead.
   -- plan() is called solely for a confirmed, controlled MY carrier.
   local forward_progress=(x-o.total_start_x)*dir
   local forward_clearance=space(x+dir*c.reassess_forward_probe,y)
   local can_continue=forward_progress>=c.reassess_min_forward_progress
      and forward_clearance>=c.reassess_min_clearance
      and threat>=c.reassess_min_pressure_distance
   if o.limit_age>=c.reassessment_frames
      and total<c.total_advance_limit
      and o.reassessments<c.max_reassessments
      and can_continue then
    o.limit_age=0;o.start_x,o.start_y=x,y
    o.reassessments=o.reassessments+1
    return {mode="REASSESS",reason="SAFE_FORWARD_CONTINUATION",age=o.age,
      threat=threat,reassessments=o.reassessments,total=total,
      forward_progress=forward_progress,forward_clearance=forward_clearance}
   end
   if threat<=c.emergency_radius and not o.clearance_used then
    o.clearance_used=true;o.clear_attempts=o.clear_attempts+1
    o.hold_streak=0;o.pending_frames=c.action_settle_frames
    return {mode="CLEAR",button="A",
      direction=dir==1 and "Right" or "Left",
      reason="PRESSURE_ESCAPE_LIMIT",age=o.age,threat=threat}
   end
   return hold("ESCAPE_LIMIT",threat,total)
  end
  o.limit_age=0
  -- Probe actual destinations, rather than moving sideways whenever a
  -- progressive, safe lane exists. This is dribbling, NOT an unverified
  -- diagonal B pass. Score combines safety, forward gain and sideline room.
  local length=mem.u16(config.ADDR.field_length)
  local center_x=mem.u16(config.ADDR.center_field_x)
  local best_move=nil
  if length>=500 and length<=4000 and center_x>=100 then
   local start_x=center_x-dir*length/2+c.field_margin
   local end_x=center_x+dir*length/2-c.field_margin
   local options={
    {dx=dir*c.forward_step,dy=0,kind="FORWARD"},
    {dx=dir*c.forward_step,dy=-c.step,kind="DIAGONAL_UP"},
    {dx=dir*c.forward_step,dy=c.step,kind="DIAGONAL_DOWN"},
    {dx=0,dy=-c.step,kind="LATERAL_UP"},
    {dx=0,dy=c.step,kind="LATERAL_DOWN"},
   }
   for _,v in ipairs(options) do
    local tx,ty=x+v.dx,y+v.dy
    local progress=(tx-start_x)*dir
    if progress>=0 and progress<=length-2*c.field_margin
       and ty>=low and ty<=high then
     local safe=space(tx,ty)
     if safe>=c.min_escape_clearance then
      local forward=v.dx*dir
      local score=math.min(safe,c.escape_space_cap)
        +c.escape_forward_weight*forward
        -c.escape_lateral_penalty*math.abs(v.dy)
      if not best_move or score>best_move.score then
       best_move={mode="MOVE",dx=v.dx,dy=v.dy,
        reason="SAFE_"..v.kind,score=score,clearance=safe,
        age=o.age,threat=threat}
      end
     end
    end
   end
  end
  if not best_move then
   if threat<=c.emergency_radius and not o.clearance_used then
    o.clearance_used=true;o.pending_frames=c.action_settle_frames
    return {mode="CLEAR",button="A",direction=dir==1 and "Right" or "Left",reason="PRESSURE_NO_SAFE_SPACE",age=o.age,threat=threat}
   end
   return hold("NO_SAFE_SPACE",threat)
  end
  o.hold_streak=0
  return best_move
 end
 return o
end
return M
