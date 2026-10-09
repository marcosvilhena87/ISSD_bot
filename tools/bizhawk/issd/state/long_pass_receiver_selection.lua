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
    distance=0,sequence=sequence,previous=base,initial_owner=base,switches=0}
 end
 function o.update(state,frame)
  local p=o.pending
  if not p then return nil end
  local events={}
  local x,y=state.ball_x,state.ball_y
  if x and y then
   local dx,dy=x-p.last_x,y-p.last_y
   p.distance=p.distance+math.sqrt(dx*dx+dy*dy)
   p.last_x=x;p.last_y=y
  end
  local selected=state.my_base
  if selected and p.previous and selected~=p.previous then
   p.switches=p.switches+1
   local px,py=players.xy(selected)
   local requested=o.last_request and frame-o.last_request>=0
       and frame-o.last_request<=c.request_window_frames
   events[#events+1]={kind="SWITCH",sequence=p.sequence,age=frame-p.start,
    previous=p.previous,current=selected,travel=p.distance,
    straight=math.sqrt((x-p.x)^2+(y-p.y)^2),
    ball_distance=math.sqrt((x-px)^2+(y-py)^2),
    height=state.ball_height,source=requested and "BOT_REQUEST_NEARBY"
        or "UNKNOWN_NO_RECENT_BOT_REQUEST"}
  end
  p.previous=selected
  local reason=nil
  if state.game_state~=0 or state.gameplay_active~=1 then reason="STOPPAGE"
  elseif frame-p.start>=c.max_frames then reason="TIMEOUT"
  elseif frame>p.start and players.valid_cpu_base(state.possession) then reason="CPU_POSSESSION"
  elseif frame>p.start and players.valid_my_base(state.possession)
     and state.possession~=p.initial_owner then reason="MY_POSSESSION" end
  if reason then
   events[#events+1]={kind="END",sequence=p.sequence,age=frame-p.start,
    travel=p.distance,straight=math.sqrt((x-p.x)^2+(y-p.y)^2),
    switches=p.switches,source=reason}
   o.pending=nil
  end
  return events
 end
 return o
end
return M
