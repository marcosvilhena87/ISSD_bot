-- Passive comparison of estimated time-to-arrival at a short-horizon ball target.
-- ETA is a geometric proxy, not proof of an executable interception.
local M={}
function M.new(config,players)
 local c=config.BALL_CONTEST_FEASIBILITY
 local o={previous=nil,pending=nil}
 local function nearest(x,y,each)
  local best,dist=nil,math.huge
  each(function(base)
   local px,py=players.xy(base)
   local d=math.sqrt((px-x)^2+(py-y)^2)
   if d<dist then best,dist=base,d end
  end)
  return best,dist
 end
 function o.reset() o.previous=nil;o.pending=nil end
 function o.update(state,frame)
  if state.game_state~=0 or state.gameplay_active~=1 then
   local result=o.pending and {outcome="ABORTED",start=o.pending.frame} or nil
   o.reset()
   return nil,result
  end
  local team=players.valid_my_base(state.possession) and "MY"
   or players.valid_cpu_base(state.possession) and "CPU" or nil
  local result=nil
  if o.pending then
   if team then
    result={outcome=team,start=o.pending.frame,
      predicted=o.pending.predicted,elapsed=frame-o.pending.frame}
    o.pending=nil
   elseif frame-o.pending.frame>=c.outcome_frames then
    result={outcome="UNKNOWN",start=o.pending.frame,
      predicted=o.pending.predicted,elapsed=frame-o.pending.frame}
    o.pending=nil
   end
  end
  if state.possession~=0 then o.previous=nil;return nil,result end
  local vx,vy=state.ball_dx or 0,state.ball_dy or 0
  local speed=math.sqrt(vx*vx+vy*vy)
  local lead=math.min(c.max_lead_frames,
    math.floor(c.max_lead_distance/math.max(1,speed)))
  local tx=state.ball_x+vx*lead
  local ty=state.ball_y+vy*lead
  local my,md=nearest(tx,ty,players.each_my)
  local cpu,cd=nearest(tx,ty,players.each_cpu)
  local my_eta=md/c.estimated_my_speed
  local cpu_eta=cd/c.estimated_cpu_speed
  local advantage=cpu_eta-my_eta
  local predicted=math.abs(advantage)<=c.contested_eta_margin and "CONTESTED"
   or advantage>0 and "MY" or "CPU"
  local height=state.ball_height or 0
  local eligible=height<=c.max_contestable_height
    and math.min(md,cd)<=c.max_distance
  local class=eligible and predicted or "UNREACHABLE_OR_AERIAL"
  local key=class
  local changed=key~=o.previous
  o.previous=key
  if eligible and class=="CONTESTED" and not o.pending then
   o.pending={frame=frame,predicted=predicted}
  end
  return {changed=changed,class=class,predicted=predicted,
    target_x=tx,target_y=ty,lead=lead,height=height,
    my_base=my,cpu_base=cpu,my_distance=md,cpu_distance=cd,
    my_eta=my_eta,cpu_eta=cpu_eta,eta_advantage=advantage},result
 end
 return o
end
return M
