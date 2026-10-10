-- Passive five-direction outlet evaluation. No controller actions.
local M={}
function M.new(config,players,field_side)
 local c=config.FIVE_DIRECTION_PASS_OBSERVER
 local o={last_frame=-99999}
 local function clearance(ax,ay,bx,by)
  local dx,dy=bx-ax,by-ay
  local length2=dx*dx+dy*dy
  local nearest=math.huge
  players.each_cpu(function(base)
   if base~=config.CPU_FIRST then
    local cx,cy=players.xy(base)
    local t=length2>0 and math.max(0,math.min(1,
        ((cx-ax)*dx+(cy-ay)*dy)/length2)) or 0
    local d=math.sqrt((cx-ax-t*dx)^2+(cy-ay-t*dy)^2)
    nearest=math.min(nearest,d)
   end
  end)
  return nearest
 end
 function o.evaluate(frame,carrier,actual)
  if frame-o.last_frame<c.sample_frames then return nil end
  if not players.valid_my_base(carrier) or carrier==config.MY_FIRST then return nil end
  local dir=field_side.attack_direction()
  if dir~=1 and dir~=-1 then return nil end
  o.last_frame=frame
  local x,y=players.xy(carrier)
  local sectors={FRONT=nil,LEFT=nil,RIGHT=nil,DIAG_LEFT=nil,DIAG_RIGHT=nil}
  local counts={FRONT=0,LEFT=0,RIGHT=0,DIAG_LEFT=0,DIAG_RIGHT=0}
  players.each_my(function(base)
   if base~=carrier and base~=config.MY_FIRST then
    local tx,ty=players.xy(base)
    local forward=(tx-x)*dir
    local lateral=ty-y
    local dist=math.sqrt((tx-x)^2+lateral*lateral)
    if dist>=c.min_distance and dist<=c.max_distance and forward>=-c.max_backward then
     local sector
     if forward>=c.min_forward and math.abs(lateral)<=forward*c.front_ratio then
      sector="FRONT"
     elseif forward>=c.min_forward then
      sector=lateral<0 and "DIAG_LEFT" or "DIAG_RIGHT"
     else sector=lateral<0 and "LEFT" or "RIGHT" end
     local lane=clearance(x,y,tx,ty)
     local receiver=math.huge
     players.each_cpu(function(cpu)
      if cpu~=config.CPU_FIRST then
       local cx,cy=players.xy(cpu)
       receiver=math.min(receiver,math.sqrt((cx-tx)^2+(cy-ty)^2))
      end
     end)
     local score=0.45*math.min(1,lane/c.safe_lane)
       +0.35*math.min(1,receiver/c.safe_receiver)
       +0.20*math.min(1,math.max(0,forward)/c.good_progress)
     counts[sector]=counts[sector]+1
     if not sectors[sector] or score>sectors[sector].score then
      sectors[sector]={base=base,score=score,distance=dist,
       lane=lane,receiver_clearance=receiver,progress=forward}
     end
    end
   end
  end)
  local best_sector,best=nil,nil
  for _,name in ipairs({"FRONT","LEFT","RIGHT","DIAG_LEFT","DIAG_RIGHT"}) do
   local candidate=sectors[name]
   if candidate and (not best or candidate.score>best.score) then
    best=candidate;best_sector=name
   end
  end
  return {kind="FIVE_DIRECTION_PASS_EVALUATION",best=best,
   best_sector=best_sector,sectors=sectors,counts=counts,actual=actual}
 end
 return o
end
return M
