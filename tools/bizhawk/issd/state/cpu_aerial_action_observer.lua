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
 local PRE_FRAMES=15
 local history={}
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
  history={}
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
  -- Buffer each frame; it is only emitted when a candidate contact appears.
  local prior=history[#history]
  local cpu_positions={}
  players.each_cpu(function(base)
   if base~=config.CPU_FIRST then
    local px,py=players.xy(base)
    cpu_positions[base]={x=px,y=py}
   end
  end)
  history[#history+1]={frame=frame,x=x,y=y,height=height,
      cpu_positions=cpu_positions,
      owner=owner,nearest=nearest,distance=distance,
      horizontal_dx=prior and x-prior.x or nil,
      horizontal_dy=prior and y-prior.y or nil,
      vertical_delta=prior and height-prior.height or nil}
  while #history>PRE_FRAMES+1 do table.remove(history,1) end
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
      -- Freeze the CPU player's identity at the candidate instant.
      -- Past positions are read from stored frames, never from current RAM.
      local contact_player=nearest
      local contact_position=cpu_positions[contact_player]
      for i=1,#history-1 do
       local h=history[i]
       if frame-h.frame<=PRE_FRAMES then
        local fixed=h.cpu_positions[contact_player]
        local prior_fixed=i>1 and history[i-1].cpu_positions[contact_player] or nil
        local fixed_distance=fixed and math.sqrt(
         (h.x-fixed.x)^2+(h.y-fixed.y)^2) or nil
        event(events,"CPU_AERIAL_PRECONTACT_SAMPLE",
         "RETROSPECTIVE_SAME_CPU_PLAYER",w,h.frame,
         h.owner,h.x,h.y,h.height,h.nearest,h.distance,
         {contact_frame=frame,frames_before_contact=frame-h.frame,
          horizontal_dx=h.horizontal_dx,horizontal_dy=h.horizontal_dy,
          vertical_delta=h.vertical_delta,
          contact_player=contact_player,
          contact_player_x=contact_position and contact_position.x or nil,
          contact_player_y=contact_position and contact_position.y or nil,
          fixed_player_x=fixed and fixed.x or nil,
          fixed_player_y=fixed and fixed.y or nil,
          fixed_player_distance=fixed_distance,
          fixed_player_dx=prior_fixed and fixed.x-prior_fixed.x or nil,
          fixed_player_dy=prior_fixed and fixed.y-prior_fixed.y or nil,
          relative_dx=prior_fixed and h.horizontal_dx and
              h.horizontal_dx-(fixed.x-prior_fixed.x) or nil,
          relative_dy=prior_fixed and h.horizontal_dy and
              h.horizontal_dy-(fixed.y-prior_fixed.y) or nil})
       end
      end
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
