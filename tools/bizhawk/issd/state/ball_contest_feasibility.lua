-- Passive ball contest calibration with debounced predictions and scored outcomes.
local M={}
function M.new(config,players)
 local c=config.BALL_CONTEST_FEASIBILITY
 local o={previous=nil,pending=nil,candidate=nil,candidate_age=0,stable=nil,episode_scored=false}
 local function nearest(x,y,each)
  local base,dist=nil,math.huge
  each(function(id)
   local px,py=players.xy(id)
   local d=math.sqrt((px-x)^2+(py-y)^2)
   if d<dist then base,dist=id,d end
  end)
  return base,dist
 end
 function o.reset()
  o.previous=nil;o.pending=nil;o.candidate=nil;o.candidate_age=0;o.stable=nil;o.episode_scored=false
 end
 local function finish(p,outcome,frame)
  local correct=nil
  if outcome=="MY" or outcome=="CPU" then correct=(p.predicted==outcome) end
  return {outcome=outcome,start=p.frame,predicted=p.predicted,
   elapsed=frame-p.frame,correct=correct,
   my_eta=p.my_eta,cpu_eta=p.cpu_eta,advantage=p.advantage,
   height=p.height,confidence=p.confidence}
 end
 function o.update(state,frame)
  local active=state.game_state==0 and state.gameplay_active==1
  if not active then
   local result=o.pending and finish(o.pending,"ABORTED",frame) or nil
   o.reset();return nil,result
  end
  local team=players.valid_my_base(state.possession) and "MY"
   or players.valid_cpu_base(state.possession) and "CPU" or nil
  local result=nil
  if o.pending then
   if team then
    result=finish(o.pending,team,frame);o.pending=nil
   elseif frame-o.pending.frame>=c.outcome_frames then
    result=finish(o.pending,"UNKNOWN",frame);o.pending=nil
   end
  end
  if state.possession~=0 then
   o.previous=nil;o.candidate=nil;o.candidate_age=0;o.stable=nil;o.episode_scored=false
   return nil,result
  end
  local vx,vy=state.ball_dx or 0,state.ball_dy or 0
  local speed=math.sqrt(vx*vx+vy*vy)
  local lead=math.min(c.max_lead_frames,
   math.floor(c.max_lead_distance/math.max(1,speed)))
  local tx,ty=state.ball_x+vx*lead,state.ball_y+vy*lead
  local my,md=nearest(tx,ty,players.each_my)
  local cpu,cd=nearest(tx,ty,players.each_cpu)
  local my_eta,cpu_eta=md/c.estimated_my_speed,cd/c.estimated_cpu_speed
  local advantage=cpu_eta-my_eta
  local height=state.ball_height or 0
  local eligible=height<=c.max_contestable_height
   and math.min(md,cd)<=c.max_distance
  local raw=not eligible and "UNREACHABLE_OR_AERIAL"
   or math.abs(advantage)<=c.contested_eta_margin and "CONTESTED"
   or advantage>0 and "MY" or "CPU"
  if raw==o.candidate then o.candidate_age=o.candidate_age+1
  else o.candidate=raw;o.candidate_age=1 end
  if o.stable==nil or (raw~=o.stable
   and o.candidate_age>=c.stability_frames) then o.stable=raw end
  local class=o.stable
  local changed=class~=o.previous
  o.previous=class
  -- Capture one scored prediction per free-ball episode, only after stability.
  if not o.pending and not o.episode_scored and eligible and (class=="MY" or class=="CPU")
   and o.candidate_age>=c.stability_frames then
    o.episode_scored=true
    o.pending={frame=frame,predicted=class,my_eta=my_eta,cpu_eta=cpu_eta,
      advantage=advantage,height=height,
      confidence=math.abs(advantage)}
  end
  return {changed=changed,class=class,raw_class=raw,predicted=class,
   stability=o.candidate_age,pending=o.pending~=nil,
   target_x=tx,target_y=ty,lead=lead,height=height,
   my_base=my,cpu_base=cpu,my_distance=md,cpu_distance=cd,
   my_eta=my_eta,cpu_eta=cpu_eta,eta_advantage=advantage},result
 end
 return o
end
return M
