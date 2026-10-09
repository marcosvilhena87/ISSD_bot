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
  if pass_cooldown==0 then
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
       local score=math.min(rc,180)+math.min(lane,180)-dst*0.2
       if not best or score>best.score then
        best={mode="PASS",button="B",direction=dy<0 and "Up" or "Down",
         receiver=base,distance=dst,receiver_clearance=rc,
         lane_clearance=lane,score=score,age=o.age}
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
   if o.limit_age>=c.reassessment_frames
      and total<c.total_advance_limit
      and o.reassessments<c.max_reassessments then
    o.limit_age=0;o.start_x,o.start_y=x,y
    o.reassessments=o.reassessments+1
    return {mode="REASSESS",reason="NEW_ESCAPE_WINDOW",age=o.age,
      threat=threat,reassessments=o.reassessments,total=total}
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
  local up=y-c.step>=low and space(x,y-c.step) or -1
  local down=y+c.step<=high and space(x,y+c.step) or -1
  if math.max(up,down)<c.min_escape_clearance then
   if threat<=c.emergency_radius and not o.clearance_used then
    o.clearance_used=true;o.pending_frames=c.action_settle_frames
    return {mode="CLEAR",button="A",direction=dir==1 and "Right" or "Left",reason="PRESSURE_NO_SAFE_SPACE",age=o.age,threat=threat}
   end
   return hold("NO_SAFE_SPACE",threat)
  end
  o.hold_streak=0
  return {mode="MOVE",dx=dir*c.forward_step,
   dy=up>=down and -c.step or c.step,age=o.age,
   threat=threat,reason=pressured and "PRESSURE_SHORT_ESCAPE" or "SHORT_ESCAPE"}
 end
 return o
end
return M
