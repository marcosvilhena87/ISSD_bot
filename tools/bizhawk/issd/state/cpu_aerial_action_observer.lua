-- Passive CPU aerial-window observer, with no inferred jump animation.
-- Ball height is known; player jump height/state is NOT calibrated.
local M={}
function M.new(config,mem,players)
 local o={previous=nil,window=nil,sequence=0}
 local WINDOW=65
 local NEAR=90
 local MIN_HEIGHT=20
 local SPEED_CHANGE=7
 local function nearest_cpu(x,y)
  local best=nil;local distance=math.huge
  players.each_cpu(function(base)
   if base~=config.CPU_FIRST then
    local px,py=players.xy(base)
    local d=math.sqrt((px-x)^2+(py-y)^2)
    if d<distance then best=base;distance=d end
   end
  end)
  return best,distance
 end
 local function emit(events,kind,reason,w,frame,owner,x,y,h,px,py)
  events[#events+1]={kind=kind,reason=reason,sequence=w.sequence,
   age=frame-w.start,nearest=w.player,distance=w.distance,
   ball_x=x,ball_y=y,height=h,owner=owner,
   dx=px and x-px or nil,dy=py and y-py or nil,
   min_distance=w.min_distance,max_height=w.max_height,
   trajectory_changes=w.trajectory_changes}
 end
 function o.reset()
  o.previous=nil;o.window=nil
 end
 function o.update(frame,active,gs,owner)
  local events={}
  if not active or gs~=0 then
   if o.window then
    local w=o.window
    emit(events,"CPU_AERIAL_WINDOW_END","STOPPAGE",w,frame,owner,
     w.last_x,w.last_y,w.last_height)
   end
   o.reset()
   return events
  end
  local x=mem.s16(config.ADDR.ball_x)
  local y=mem.s16(config.ADDR.ball_y)
  local raw=mem.s16(config.AERIAL_CONTACT.height_addr)
  local height=math.max(0,-raw)
  local player,distance=nearest_cpu(x,y)
  local prev=o.previous
  local w=o.window
  if not w and height>=MIN_HEIGHT and player and distance<=NEAR then
   o.sequence=o.sequence+1
   w={sequence=o.sequence,start=frame,player=player,distance=distance,
    min_distance=distance,max_height=height,trajectory_changes=0}
   o.window=w
   emit(events,"CPU_AERIAL_WINDOW_START","CPU_NEAR_AIRBORNE_BALL",w,
    frame,owner,x,y,height)
  end
  if w then
   w.last_x=x;w.last_y=y;w.last_height=height
   w.min_distance=math.min(w.min_distance,distance)
   w.max_height=math.max(w.max_height,height)
   -- A sudden velocity change is only a possible ball contact.
   if prev and prev.vx and owner==0 then
    local vx=x-prev.x;local vy=y-prev.y
    local change=math.sqrt((vx-prev.vx)^2+(vy-prev.vy)^2)
    if change>=SPEED_CHANGE and height>=MIN_HEIGHT then
     w.trajectory_changes=w.trajectory_changes+1
     emit(events,"CPU_AERIAL_TRAJECTORY_CHANGE",
      "BALL_ACCELERATION_NEAR_CPU_NOT_CONFIRMED_CONTACT",
      w,frame,owner,x,y,height,prev.x,prev.y)
    end
   end
   if height<MIN_HEIGHT or frame-w.start>=WINDOW
       or (distance>NEAR*2 and frame-w.start>6) then
    local reason=height<MIN_HEIGHT and "BALL_DESCENDED"
        or frame-w.start>=WINDOW and "TIMEOUT" or "CPU_FAR_FROM_BALL"
    emit(events,"CPU_AERIAL_WINDOW_END",reason,w,frame,owner,x,y,height)
    o.window=nil
   end
  end
  local vx=prev and x-prev.x or nil
  local vy=prev and y-prev.y or nil
  o.previous={x=x,y=y,vx=vx,vy=vy}
  return events
 end
 return o
end
return M
