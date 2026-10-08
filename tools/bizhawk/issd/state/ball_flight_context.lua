-- Observational ball flight metadata; TeamPoss is not evidence of the kicker.
local M={}
function M.new(config,mem,players)
 local o={previous_height=nil,previous_owner=nil,origin="UNKNOWN",age=0}
 function o.reset()
  o.previous_height=nil;o.previous_owner=nil;o.origin="UNKNOWN";o.age=0
 end
 function o.update(active,game_state,owner,team_possession)
  if not active or game_state~=0 then o.reset();return nil end
  local z=mem.s16(config.AERIAL_CONTACT.height_addr)
  local reference=mem.s16(config.AERIAL_CONTACT.height_reference_addr)
  local height=math.max(0,-z)
  local dh=o.previous_height and height-o.previous_height or 0
  local phase
  if height<=3 then phase="GROUND"
  elseif dh>=2 then phase="RISING"
  elseif dh<=-2 then phase="FALLING"
  else phase="STABLE_OR_APEX" end
  local physical=height<=3 and "GROUND_CONTACT"
      or height<=20 and "LOW_BOUNCING" or "HIGH_AIRBORNE"
  local team=nil
  if players.valid_my_base(owner) then team="MY"
  elseif players.valid_cpu_base(owner) then team="CPU" end
  if team then
   o.previous_owner=team;o.origin=team;o.age=0
  elseif owner==0 then
   o.age=o.age+1
   if o.age==1 then o.origin=o.previous_owner or "UNKNOWN" end
  else
   o.origin="UNKNOWN";o.age=0
  end
  o.previous_height=height
  return {height=height,reference_height=math.max(0,-reference),
    vertical_delta=dh,phase=phase,physical=physical,
    origin=o.origin,age=o.age,logical_team=team_possession,
    discrepancy=(owner==0 and ((team_possession==0 and o.origin=="CPU")
      or (team_possession==1 and o.origin=="MY"))) or false}
 end
 return o
end
return M
