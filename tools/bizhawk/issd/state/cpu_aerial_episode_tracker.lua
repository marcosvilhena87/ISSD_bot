-- Passive correlation of CPU aerial trajectory changes with shot/goal counters.
-- Correlation is temporal evidence only; it does not prove a header or jump.
local M={}
function M.new()
 local o={episodes={},shots=nil,goals=nil}
 local SHOT_WINDOW=15
 local GOAL_WINDOW=35
 local EXPIRE=45
 local function emit(out,kind,e,frame,reason)
  out[#out+1]={kind=kind,reason=reason,sequence=e.sequence,
   contact_frame=e.contact_frame,age=frame-e.contact_frame,
   player=e.player,distance=e.distance,height=e.height,
   velocity_change=e.velocity_change,ball_x=e.ball_x,ball_y=e.ball_y,
   shot_frame=e.shot_frame,shot_age=e.shot_frame and
     e.shot_frame-e.contact_frame or nil,
   source=e.source,merged_sources=e.merged_sources,
   goal_frame=e.goal_frame,goal_age=e.goal_frame and
     e.goal_frame-e.contact_frame or nil}
 end
 function o.update(frame,aerial_events,shots_cpu,score_cpu)
  local out={}
  if o.shots==nil or shots_cpu<o.shots or o.goals==nil
      or score_cpu<o.goals then
   o.episodes={};o.shots=shots_cpu;o.goals=score_cpu
  end
  -- Merge distinct detector signals within a short space-time window.
  -- Physical reversal events are only used when the nearest player is CPU.
  for _,v in ipairs(aerial_events) do
   if v.kind=="CPU_AERIAL_TRAJECTORY_CHANGE"
      or v.kind=="CPU_AERIAL_PHYSICAL_CANDIDATE" then
    local source=v.kind=="CPU_AERIAL_TRAJECTORY_CHANGE"
       and "NORMALIZED_VELOCITY" or "PHYSICAL_REVERSAL"
    local x=v.ball_x or v.x
    local y=v.ball_y or v.y
    local player=v.nearest or v.nearest_base
    local d=v.distance or v.nearest_distance
    local h=v.height
    local matched=nil
    for _,e in ipairs(o.episodes) do
     local dt=frame-e.contact_frame
     local dx=x-e.ball_x
     local dy=y-e.ball_y
     if dt>=0 and dt<=8 and dx*dx+dy*dy<=50*50
         and e.player==player then
      matched=e
      break
     end
    end
    if matched then
     if not matched.sources[source] then
      matched.sources[source]=true
      matched.merged_sources=matched.merged_sources.. "+"..source
      emit(out,"CPU_AERIAL_EPISODE_EVIDENCE_MERGED",matched,frame,
       "INDEPENDENT_DETECTOR_WITHIN_SPACETIME_WINDOW")
     end
    else
     local e={sequence=v.sequence or ("physical-"..frame),
       contact_frame=frame,player=player,distance=d,height=h,
       velocity_change=v.delta_velocity,ball_x=x,ball_y=y,
       source=source,merged_sources=source,sources={[source]=true}}
     o.episodes[#o.episodes+1]=e
     emit(out,"CPU_AERIAL_EPISODE_CANDIDATE",e,frame,
      "CONTACT_CANDIDATE_NOT_CONFIRMED_HEADER")
    end
   end
  end
  if shots_cpu>o.shots then
   local selected=nil
   for _,e in ipairs(o.episodes) do
    local age=frame-e.contact_frame
    if not e.shot_frame and age>=0 and age<=SHOT_WINDOW
        and (not selected or e.contact_frame>selected.contact_frame) then
     selected=e
    end
   end
   if selected then
    selected.shot_frame=frame
    emit(out,"CPU_AERIAL_EPISODE_SHOT_LINK",selected,frame,
     "SHOT_COUNTER_TEMPORAL_ASSOCIATION")
   end
  end
  if score_cpu>o.goals then
   local selected=nil
   for _,e in ipairs(o.episodes) do
    local age=frame-e.contact_frame
    if age>=0 and age<=GOAL_WINDOW
        and (not selected or
             (e.shot_frame and not selected.shot_frame) or
             ((e.shot_frame~=nil)==(selected.shot_frame~=nil)
              and e.contact_frame>selected.contact_frame)) then
     selected=e
    end
   end
   if selected then
    selected.goal_frame=frame
    emit(out,"CPU_AERIAL_EPISODE_GOAL_LINK",selected,frame,
     "GOAL_COUNTER_TEMPORAL_ASSOCIATION")
   end
  end
  o.shots=shots_cpu;o.goals=score_cpu
  for i=#o.episodes,1,-1 do
   local e=o.episodes[i]
   if frame-e.contact_frame>=EXPIRE or e.goal_frame then
    emit(out,"CPU_AERIAL_EPISODE_END",e,frame,
     e.goal_frame and "GOAL_LINKED" or
       e.shot_frame and "SHOT_LINKED_NO_GOAL" or "NO_SHOT_OR_GOAL_LINK")
    table.remove(o.episodes,i)
   end
  end
  return out
 end
 return o
end
return M
