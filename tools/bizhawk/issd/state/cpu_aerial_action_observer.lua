-- Passive CPU aerial observer. Samples distinct ball positions to avoid
-- treating repeated coordinate frames as acceleration/contact.
-- Neither proximity nor a trajectory change proves a jump or header.
local M={}
function M.new(config,mem,players)
 local o={sequence=0,window=nil,last_motion=nil,prior_motion=nil,
          last_x=nil,last_y=nil,last_frame=nil,rearm=true}
 local MIN_HEIGHT=20
 local NEAR=90
 local MAX_AGE=130
 local CHANGE_THRESHOLD=5
 local MIN_SPEED=3
 local COOLDOWN=10
 local function nearest_cpu(x,y)
  local best,nearest=nil,math.huge
  players.each_cpu(function(base)
   if base~=config.CPU_FIRST then
    local px,py=players.xy(base)
    local d=math.sqrt((px-x)^2+(py-y)^2)
    if d<nearest then best,nearest=base,d end
   end
  end)
  return best,nearest
 end
 local function event(events,kind,reason,w,frame,owner,x,y,h,base,d,extra)
  local e={kind=kind,reason=reason,sequence=w.sequence,
   age=frame-w.start,nearest=base,distance=d,
   ball_x=x,ball_y=y,height=h,owner=owner,
   min_distance=w.min_distance,max_height=w.max_height,
   trajectory_changes=w.trajectory_changes}
  for k,v in pairs(extra or {}) do e[k]=v end
  events[#events+1]=e
 end
 function o.reset()
  o.window=nil;o.last_motion=nil;o.prior_motion=nil
  o.last_x=nil;o.last_y=nil;o.last_frame=nil;o.rearm=true
 end
 function o.update(frame,active,gs,owner)
  local events={}
  if not active or gs~=0 then
   if o.window then
    local w=o.window
    event(events,"CPU_AERIAL_WINDOW_END","STOPPAGE",w,frame,owner,
     w.last_x,w.last_y,w.last_height,w.nearest,w.nearest_distance)
   end
   o.reset()
   return events
  end
  local x=mem.s16(config.ADDR.ball_x)
  local y=mem.s16(config.ADDR.ball_y)
  local height=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
  local nearest,distance=nearest_cpu(x,y)
  local w=o.window
  if height<MIN_HEIGHT then o.rearm=true end
  if not w and o.rearm and height>=MIN_HEIGHT and distance<=NEAR then
   o.sequence=o.sequence+1
   w={sequence=o.sequence,start=frame,min_distance=distance,
      max_height=height,trajectory_changes=0,last_event=-10000}
   o.window=w;o.rearm=false
   event(events,"CPU_AERIAL_WINDOW_START","CPU_NEAR_AIRBORNE_BALL",
    w,frame,owner,x,y,height,nearest,distance)
  end
  if w then
   w.last_x=x;w.last_y=y;w.last_height=height
   w.nearest=nearest;w.nearest_distance=distance
   w.min_distance=math.min(w.min_distance,distance)
   w.max_height=math.max(w.max_height,height)
  end
  -- Velocity is estimated only between distinct coordinate samples;
  -- dt normalizes SNES/BizHawk repeated-position frames.
  local moved=o.last_x and (x~=o.last_x or y~=o.last_y)
  if moved then
   local dt=frame-o.last_frame
   if dt>0 then
    local vx=(x-o.last_x)/dt
    local vy=(y-o.last_y)/dt
    local previous=o.last_motion
    if w and previous and owner==0 and height>=MIN_HEIGHT
        and distance<=NEAR and frame-w.last_event>=COOLDOWN then
     local speed=math.sqrt(vx*vx+vy*vy)
     local previous_speed=math.sqrt(previous.vx^2+previous.vy^2)
     local change=math.sqrt((vx-previous.vx)^2+(vy-previous.vy)^2)
     if speed>=MIN_SPEED and previous_speed>=MIN_SPEED
         and change>=CHANGE_THRESHOLD then
      w.trajectory_changes=w.trajectory_changes+1
      w.last_event=frame
      event(events,"CPU_AERIAL_TRAJECTORY_CHANGE",
       "DISTINCT_SAMPLE_VELOCITY_CHANGE_NOT_CONFIRMED_CONTACT",
       w,frame,owner,x,y,height,nearest,distance,
       {before_vx=previous.vx,before_vy=previous.vy,
        after_vx=vx,after_vy=vy,delta_velocity=change,
        sample_dt=dt,previous_sample_dt=previous.dt})
     end
    end
    o.prior_motion=previous
    o.last_motion={vx=vx,vy=vy,dt=dt}
   end
  end
  if not o.last_x or moved then
   o.last_x=x;o.last_y=y;o.last_frame=frame
  end
  if w and (height<MIN_HEIGHT or frame-w.start>=MAX_AGE
     or (distance>NEAR*2 and frame-w.start>6)) then
   local reason=height<MIN_HEIGHT and "BALL_DESCENDED"
      or frame-w.start>=MAX_AGE and "TIMEOUT" or "CPU_FAR_FROM_BALL"
   event(events,"CPU_AERIAL_WINDOW_END",reason,w,frame,owner,x,y,height,
     nearest,distance)
   o.window=nil
  end
  return events
 end
 return o
end
return M
