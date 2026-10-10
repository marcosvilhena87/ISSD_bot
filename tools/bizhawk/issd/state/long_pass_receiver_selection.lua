-- Passive correlation between ball travel and selected-player changes.
-- An observed change without an R request is not proof of game AI selection.
local M={}
function M.new(config,players)
 local c=config.LONG_PASS_RECEIVER_SELECTION
 local o={pending=nil,last_request=nil}
 function o.request(frame)
  o.last_request=frame
 end
 function o.start(frame,x,y,sequence,base)
  o.pending={start=frame,x=x,y=y,last_x=x,last_y=y,
    distance=0,sequence=sequence,previous=base,initial_owner=base,switches=0,
    previous_sample=nil,neutral_frames=0,neutral_movement=0,
    direction_frames=0,direction_movement=0,last_band=-1,
    intervention_frames=0,intervention_movement=0}
 end
 function o.update(state,frame,command)
  local p=o.pending
  if not p then return nil end
  local events={}
  local x,y=state.ball_x,state.ball_y
  if x and y then
   local dx,dy=x-p.last_x,y-p.last_y
   p.distance=p.distance+math.sqrt(dx*dx+dy*dy)
   p.last_x=x;p.last_y=y
  end
  local function receiver_geometry(base)
   if not players.valid_my_base(base) then return nil end
   local mx,my=players.xy(base)
   return math.sqrt((x-mx)^2+(y-my)^2)
  end
  local closest=nil
  local closest_dist=math.huge
  local available=0
  players.each_my(function(base)
   if base~=config.MY_FIRST then
    local distance=receiver_geometry(base)
    if distance then
     available=available+1
     if distance<closest_dist then
      closest,closest_dist=base,distance
     end
    end
   end
  end)
  local selected=state.my_base
  local neutral=not tostring(command or "NONE"):find("Left",1,true)
    and not tostring(command or "NONE"):find("Right",1,true)
    and not tostring(command or "NONE"):find("Up",1,true)
    and not tostring(command or "NONE"):find("Down",1,true)
  local px,py=nil,nil
  if players.valid_my_base(selected) then px,py=players.xy(selected) end
  if p.previous_sample and px and p.previous_sample.base==selected then
   local previous=p.previous_sample
   local movement=math.sqrt((px-previous.x)^2+(py-previous.y)^2)
   if previous.intervention then
    p.intervention_frames=p.intervention_frames+1
    p.intervention_movement=p.intervention_movement+movement
   elseif previous.neutral then
    p.neutral_frames=p.neutral_frames+1
    p.neutral_movement=p.neutral_movement+movement
   else
    p.direction_frames=p.direction_frames+1
    p.direction_movement=p.direction_movement+movement
   end
  end
  p.previous_sample=px and {base=selected,x=px,y=py,neutral=neutral,
    intervention=state.status=="DEF_CLEAR_SECOND_BALL_APPROACH"} or nil
  local band=math.floor(p.distance/100)
  if band>p.last_band then
   p.last_band=band
   events[#events+1]={kind="DISTANCE_BAND",sequence=p.sequence,
    age=frame-p.start,travel=p.distance,band=band,
    selected=selected,gameplay_active=state.gameplay_active,
    game_state=state.game_state,ball_distance=px
      and math.sqrt((x-px)^2+(y-py)^2) or nil,
    neutral_frames=p.neutral_frames,neutral_movement=p.neutral_movement,
    direction_frames=p.direction_frames,direction_movement=p.direction_movement,
    intervention_frames=p.intervention_frames,
    intervention_movement=p.intervention_movement,
    closest=closest,closest_distance=closest_dist,
    selected_distance=receiver_geometry(selected),available=available,
    straight=math.sqrt((x-p.x)^2+(y-p.y)^2)}
  end
  if selected and p.previous and selected~=p.previous then
   p.switches=p.switches+1
   local px,py=players.xy(selected)
   local requested=o.last_request and frame-o.last_request>=0
       and frame-o.last_request<=c.request_window_frames
   events[#events+1]={kind="SWITCH",sequence=p.sequence,age=frame-p.start,
    previous=p.previous,current=selected,travel=p.distance,
    straight=math.sqrt((x-p.x)^2+(y-p.y)^2),
    ball_distance=math.sqrt((x-px)^2+(y-py)^2),
    height=state.ball_height,gameplay_active=state.gameplay_active,
    game_state=state.game_state,band=band,
    closest=closest,closest_distance=closest_dist,
    previous_distance=receiver_geometry(p.previous),
    selected_distance=receiver_geometry(selected),available=available,
    intervention_frames=p.intervention_frames,
    intervention_movement=p.intervention_movement,
    neutral_frames=p.neutral_frames,neutral_movement=p.neutral_movement,
    direction_frames=p.direction_frames,direction_movement=p.direction_movement,
    source=requested and "BOT_REQUEST_NEARBY"
        or "UNKNOWN_NO_RECENT_BOT_REQUEST"}
  end
  p.previous=selected
  local reason=nil
  if state.game_state~=0 then reason="GAME_STATE_STOPPAGE"
  elseif frame-p.start>=c.max_frames then reason="TIMEOUT"
  elseif frame>p.start and players.valid_cpu_base(state.possession) then reason="CPU_POSSESSION"
  elseif frame>p.start and players.valid_my_base(state.possession)
     and state.possession~=p.initial_owner then reason="MY_POSSESSION" end
  if reason then
   events[#events+1]={kind="END",sequence=p.sequence,age=frame-p.start,
    travel=p.distance,straight=math.sqrt((x-p.x)^2+(y-p.y)^2),
    switches=p.switches,source=reason,
    gameplay_active=state.gameplay_active,game_state=state.game_state,
    neutral_frames=p.neutral_frames,neutral_movement=p.neutral_movement,
    direction_frames=p.direction_frames,direction_movement=p.direction_movement,
    intervention_frames=p.intervention_frames,
    intervention_movement=p.intervention_movement,
    closest=closest,closest_distance=closest_dist,
    selected_distance=receiver_geometry(selected),available=available}
   o.pending=nil
  end
  return events
 end
 return o
end
return M
