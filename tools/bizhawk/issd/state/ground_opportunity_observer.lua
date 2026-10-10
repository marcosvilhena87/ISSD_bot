-- Passive diagnostic: estimate a favorable ground-ball arrival and check
-- what the selected controller actually did. ETA is distance-only (provisional).
local M={}
function M.new(config,players)
 local c=config.GROUND_OPPORTUNITY_OBSERVER
 local o={episode=nil,seq=0,streak=0,owner_last=nil}
 local function distance(base,x,y)
  local px,py=players.xy(base)
  return math.sqrt((px-x)^2+(py-y)^2)
 end
 local function nearest(iterator,excluded,x,y)
  local best=nil
  iterator(function(base)
   if base~=excluded then
    local d=distance(base,x,y)
    if not best or d<best.distance then best={base=base,distance=d} end
   end
  end)
  return best
 end
 function o.observe(frame,active,gs,owner,bx,by,height,class,selected,status)
  local events={}
  local function emit(kind,e,reason,receiver)
   events[#events+1]={kind=kind,sequence=e.id,team=e.team,
    start=e.start,age=frame-e.start,best=e.best,selected=e.selected,
    best_eta=e.best_eta,cpu_eta=e.cpu_eta,margin=e.margin,
    target_x=e.x,target_y=e.y,action=e.action or "NONE",
    acted=e.acted,reason=reason,receiver=receiver}
  end
  local previous=o.episode
  if previous then
   local end_reason=nil
   local receiver=nil
   if not active or gs~=0 then end_reason="STOPPAGE"
   elseif players.valid_my_base(owner) then end_reason="MY_CONTROL";receiver=owner
   elseif players.valid_cpu_base(owner) then end_reason="CPU_CONTROL";receiver=owner
   elseif frame-previous.start>=c.max_episode_frames then end_reason="TIMEOUT"
   elseif height>c.max_height then end_reason="AIRBORNE"
   elseif class~="MY_UNOWNED_BALL" and class~="CPU_UNOWNED_BALL" then
    end_reason="CLASS_CHANGED" end
   if end_reason then
    if not previous.acted then emit("GROUND_OPPORTUNITY_MISSED",previous,end_reason,receiver) end
    emit("GROUND_OPPORTUNITY_OUTCOME",previous,end_reason,receiver)
    o.episode=nil;o.streak=0
   end
  end
  if not active or gs~=0 or owner~=0 or height>c.max_height
    or (class~="MY_UNOWNED_BALL" and class~="CPU_UNOWNED_BALL") then
   return events
  end
  local my=nearest(players.each_my,config.MY_FIRST,bx,by)
  local cpu=nearest(players.each_cpu,config.CPU_FIRST,bx,by)
  if not my or not cpu then return events end
  local my_eta=my.distance/c.my_speed
  local cpu_eta=cpu.distance/c.cpu_speed
  local margin=cpu_eta-my_eta
  local favorable=margin>=c.min_advantage and my.distance<=c.max_my_distance
  if not o.episode then
   if favorable then o.streak=o.streak+1 else o.streak=0 end
   if o.streak>=c.stability_frames then
    o.seq=o.seq+1
    o.episode={id=o.seq,team=class,best=my.base,selected=selected,
       best_eta=my_eta,cpu_eta=cpu_eta,margin=margin,x=bx,y=by,
       start=frame,acted=false}
    emit("GROUND_OPPORTUNITY_DETECTED",o.episode,"FAVORABLE_ETA")
   end
  end
  local e=o.episode
  if e and not e.acted then
   local known=(status or ""):find("INTERCEPT",1,true)
     or (status or ""):find("RECOVERY",1,true)
     or (status or ""):find("CONTEST",1,true)
   if known then
    e.acted=true;e.action=status
    emit("GROUND_OPPORTUNITY_ACTED",e,"RECOVERY_COMMAND")
   end
  end
  return events
 end
 return o
end
return M
