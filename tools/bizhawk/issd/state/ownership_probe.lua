-- Passive ownership/dispute probe. Proximity is evidence, not confirmed contact.
local M={}
function M.new(config,mem,players)
 local o={previous_owner=nil,previous_class=nil,age=0}
 local c=config.OWNERSHIP_PROBE
 local function nearest(x,y,each)
  local best,dist=nil,math.huge
  each(function(base)
   local px,py=players.xy(base)
   local d=math.sqrt((px-x)^2+(py-y)^2)
   if d<dist then dist=d;best=base end
  end)
  return best,dist
 end
 function o.reset()
  o.previous_owner=nil;o.previous_class=nil;o.age=0
 end
 function o.update(state)
  if state.game_state~=0 or state.gameplay_active~=1 then
   o.reset();return nil
  end
  local bx,by=state.ball_x,state.ball_y
  local owner=state.possession
  local team=players.valid_my_base(owner) and "MY"
   or players.valid_cpu_base(owner) and "CPU" or nil
  local my,md=nearest(bx,by,players.each_my)
  local cpu,cd=nearest(bx,by,players.each_cpu)
  local height=state.ball_height or 0
  local age=team and 0 or o.age+1
  local classification
  if team then classification=team.."_CONTROLLED"
  elseif owner~=0 then classification="UNKNOWN_OWNER"
  elseif height<=c.max_contestable_height
   and md<=c.contest_radius and cd<=c.contest_radius
   and math.abs(md-cd)<=c.max_distance_gap then
   classification="CONTESTED_CANDIDATE"
  elseif math.min(md,cd)<=c.contest_radius then
   classification="ONE_SIDE_NEARBY"
  else classification="FREE_FLIGHT" end
  local changed=classification~=o.previous_class or owner~=o.previous_owner
  o.previous_owner=owner;o.previous_class=classification;o.age=age
  return {class=classification,changed=changed,owner=owner,
   nearest_my=my,nearest_cpu=cpu,my_distance=md,cpu_distance=cd,
   age=age,height=height,logical_team=mem.u8(config.ADDR.team_possession)}
 end
 return o
end
return M
