-- Passive temporal ball control classifier; never treats PlayerPoss=0 as proof of loose ball.
local M={}
function M.new(config,players)
 local c=config.BALL_PHYSICAL_CONTROL
 local o={last_bx=nil,last_by=nil,last_players={},candidate=nil,streak=0,last_class=nil}
 function o.reset()
  o.last_bx=nil;o.last_by=nil;o.last_players={}
  o.candidate=nil;o.streak=0;o.last_class=nil
 end
 function o.update(state)
  if state.game_state~=0 or state.gameplay_active~=1
      or not state.ball_x or not state.ball_y then
   o.reset();return nil
  end
  local bx,by=state.ball_x,state.ball_y
  local dx=o.last_bx and bx-o.last_bx or nil
  local dy=o.last_by and by-o.last_by or nil
  local height=state.ball_height
  local owner=state.possession
  local confirmed=players.valid_my_base(owner) and "MY"
       or players.valid_cpu_base(owner) and "CPU" or nil
  local candidates={}
  local next_positions={}
  local function examine(team,each)
   each(function(base)
    local x,y=players.xy(base)
    next_positions[base]={x=x,y=y}
    local dist=math.sqrt((x-bx)^2+(y-by)^2)
    local old=o.last_players[base]
    if old and dx and dist<=c.near_radius then
     local vx,vy=x-old.x,y-old.y
     local speed=math.sqrt(dx*dx+dy*dy)
     local pspeed=math.sqrt(vx*vx+vy*vy)
     local error=math.sqrt((dx-vx)^2+(dy-vy)^2)
     if speed>=c.min_speed and pspeed>=c.min_speed
       and error<=c.max_motion_error then
      candidates[#candidates+1]={team=team,base=base,
          dist=dist,error=error,score=dist+error*c.error_weight}
     end
    end
   end)
  end
  examine("MY",players.each_my)
  examine("CPU",players.each_cpu)
  table.sort(candidates,function(a,b)return a.score<b.score end)
  local best=candidates[1]
  local ambiguous=candidates[2] and best
      and candidates[2].score-best.score<c.min_candidate_margin
  if confirmed or not best or ambiguous or height==nil or height>c.max_dribble_height then
   o.candidate=nil;o.streak=0
  elseif o.candidate==best.base then
   o.streak=o.streak+1
  else o.candidate=best.base;o.streak=1 end
  local classification
  local confidence="LOW"
  if confirmed then
   classification=confirmed.."_CONTROLLED_CONFIRMED"
   confidence="CONFIRMED"
  elseif best and not ambiguous and o.streak>=c.confirm_frames
      and height and height<=c.max_dribble_height then
   classification=best.team.."_DRIBBLE_INFERRED"
   confidence="TEMPORAL"
  elseif height and height<=c.max_ground_height and not best then
   classification="LOOSE_GROUND_CANDIDATE"
  elseif height and height>c.max_ground_height then
   classification="BALL_IN_FLIGHT_CANDIDATE"
  else classification="CONTROL_UNKNOWN" end
  local changed=classification~=o.last_class
  o.last_class=classification
  o.last_bx,o.last_by=bx,by
  o.last_players=next_positions
  return {class=classification,changed=changed,confidence=confidence,
    candidate=best and best.base,team=best and best.team,
    distance=best and best.dist,error=best and best.error,
    streak=o.streak,ambiguous=not not ambiguous,height=height}
 end
 return o
end
return M
