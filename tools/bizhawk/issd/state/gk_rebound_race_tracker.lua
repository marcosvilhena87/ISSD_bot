-- Observational shot/second-ball race, NOT proof of a goalkeeper save.
local M={}
function M.new(config,players)
 local o={sequence=nil,last_sample=-99999}
 local speed=config.BALL_CONTEST_FEASIBILITY.estimated_my_speed
 if not speed or speed<=0 then speed=5 end
 local function top_two_my(x,y)
  local best,second=nil,nil
  players.each_my(function(base)
   if base~=config.MY_FIRST then
    local px,py=players.xy(base)
    local d=math.sqrt((px-x)^2+(py-y)^2)
    local item={base=base,distance=d,eta=d/speed}
    if not best or d<best.distance then second=best;best=item
    elseif not second or d<second.distance then second=item end
   end
  end)
  return best,second
 end
 local function nearest_cpu(x,y)
  local best=nil
  players.each_cpu(function(base)
   if base~=config.CPU_FIRST then
    local px,py=players.xy(base)
    local d=math.sqrt((px-x)^2+(py-y)^2)
    if not best or d<best.distance then
     best={base=base,distance=d,eta=d/speed}
    end
   end
  end)
  return best
 end
 function o.update(frame,shot_sequence,owner,bx,by)
  if not shot_sequence then o.sequence=nil;return nil end
  if shot_sequence~=o.sequence then
   o.sequence=shot_sequence;o.last_sample=-99999
  end
  if owner~=0 or frame-o.last_sample<8 then return nil end
  o.last_sample=frame
  local first,second=top_two_my(bx,by)
  local cpu=nearest_cpu(bx,by)
  if not first or not cpu then return nil end
  return {kind="GK_REBOUND_RACE_SAMPLE",sequence=shot_sequence,
    ball_x=bx,ball_y=by,my1=first,my2=second,cpu=cpu,
    eta_gap=first.eta-cpu.eta,
    note="SHOT_SECOND_BALL_NOT_CONFIRMED_GK_SAVE"}
 end
 return o
end
return M
