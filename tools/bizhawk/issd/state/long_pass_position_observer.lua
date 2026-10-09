-- Passive experiment: does the selected player's position change with neutral pad?
-- Movement is not proof of AI assistance (inertia/physics may also contribute).
local M={}
function M.new(config,players)
 local c=config.LONG_PASS_POSITION_OBSERVER
 local o={pending=nil,sequence=0}
 local function neutral(cmd)
  cmd=tostring(cmd or "NONE")
  return not cmd:find("Left",1,true)
     and not cmd:find("Right",1,true)
     and not cmd:find("Up",1,true)
     and not cmd:find("Down",1,true)
 end
 function o.start(frame,base)
  o.sequence=o.sequence+1
  o.pending={start=frame,base=base,sequence=o.sequence,
    prior=nil,neutral_frames=0,neutral_distance=0,
    directional_frames=0,directional_distance=0,switches=0,
    initial_ball_distance=nil,min_ball_distance=nil}
  return o.sequence
 end
 function o.update(s,frame,command)
  local p=o.pending
  if not p then return nil end
  local out={}
  local function emit(kind,reason)
   out[#out+1]={kind=kind,reason=reason,sequence=p.sequence,
    age=frame-p.start,neutral_frames=p.neutral_frames,
    neutral_distance=p.neutral_distance,
    directional_frames=p.directional_frames,
    directional_distance=p.directional_distance,
    switches=p.switches,
    initial_ball_distance=p.initial_ball_distance,
    min_ball_distance=p.min_ball_distance}
  end
  local owner=s.possession
  if s.game_state~=0 or s.gameplay_active~=1 then
   emit("END","STOPPAGE")
   o.pending=nil
   return out
  end
  local selected=s.my_base
  if not players.valid_my_base(selected) or selected==config.MY_FIRST then
   p.prior=nil
  else
   local px,py=players.xy(selected)
   local bx,by=s.ball_x,s.ball_y
   local bd=math.sqrt((px-bx)^2+(py-by)^2)
   if not p.initial_ball_distance then p.initial_ball_distance=bd end
   p.min_ball_distance=math.min(p.min_ball_distance or bd,bd)
   if p.prior and p.prior.base==selected then
    local move=math.sqrt((px-p.prior.x)^2+(py-p.prior.y)^2)
    -- The prior frame's command explains movement observed this frame.
    if neutral(p.prior.command) then
     p.neutral_frames=p.neutral_frames+1
     p.neutral_distance=p.neutral_distance+move
    else
     p.directional_frames=p.directional_frames+1
     p.directional_distance=p.directional_distance+move
    end
   elseif p.prior and p.prior.base~=selected then
    p.switches=p.switches+1
   end
   p.prior={base=selected,x=px,y=py,command=command}
  end
  if frame-p.start>=c.max_frames then
   emit("END","TIMEOUT");o.pending=nil
  elseif frame>p.start and players.valid_cpu_base(owner) then
   emit("END","CPU_POSSESSION");o.pending=nil
  elseif frame>p.start and players.valid_my_base(owner) and owner~=p.base then
   emit("END","MY_OTHER_PLAYER_POSSESSION");o.pending=nil
  end
  return out
 end
 return o
end
return M
