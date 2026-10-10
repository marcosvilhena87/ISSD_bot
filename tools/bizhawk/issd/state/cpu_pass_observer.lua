-- Passive CPU pass observer. A change of owner is not automatically a pass.
local M={}
function M.new(config,players,field_side)
 local o={previous=nil,pending=nil,sequence=0}
 local MAX_FRAMES=75
 local MIN_TRAVEL=25
 local function dist(x,y,a,b) return math.sqrt((x-a)^2+(y-b)^2) end
 local function clearance(x,y)
  local nearest=math.huge
  players.each_my(function(base)
   local px,py=players.xy(base)
   nearest=math.min(nearest,dist(x,y,px,py))
  end)
  return nearest
 end
 local function zone(x,dir)
  local len=config and o.field_length
  local center=o.field_center
  if not len or len<500 or len>4000 or not center or center<100 or dir==0 then return nil end
  local progress=(x-(center-dir*len/2))*dir
  if progress<0 or progress>len then return nil end
  return progress<len/3 and 1 or progress<2*len/3 and 2 or 3
 end
 function o.update(frame,owner,bx,by,gs,active,field_length,field_center)
  o.field_length=field_length;o.field_center=field_center
  local events={}
  local dir=field_side.attack_direction()
  local valid=gs==0 and active and (dir==1 or dir==-1)
  local previous=o.previous
  local p=o.pending
  local function emit(kind,reason,p,receiver)
   local rx,ry
   if receiver and players.valid_cpu_base(receiver) then rx,ry=players.xy(receiver) end
   events[#events+1]={kind=kind,reason=reason,sequence=p.id,age=frame-p.start,
    passer=p.passer,receiver=receiver,origin_x=p.x,origin_y=p.y,
    ball_x=bx,ball_y=by,travel=dist(p.x,p.y,bx,by),
    forward=rx and (rx-p.px)*p.dir or nil,
    lateral=ry and math.abs(ry-p.py) or nil,
    receiver_distance=rx and dist(p.px,p.py,rx,ry) or nil,
    receiver_clearance=rx and clearance(rx,ry) or nil,
    passer_pressure=p.pressure,start_zone=p.zone,
    receiver_zone=rx and zone(rx,p.dir) or nil,
    loose_frames=p.loose_frames,game_state=gs}
  end
  if p then
   if not valid then
    emit("CPU_PASS_UNRESOLVED","GAME_STOPPAGE",p)
    o.pending=nil
   elseif players.valid_my_base(owner) then
    emit("CPU_PASS_UNRESOLVED","MY_POSSESSION",p)
    o.pending=nil
   elseif players.valid_cpu_base(owner) and owner~=p.passer then
    -- Observable teammate reception after an individually controlled release,
    -- not proof of an intentional pass; label as candidate.
    if p.loose_frames>0 and dist(p.x,p.y,bx,by)>=MIN_TRAVEL then
     emit("CPU_PASS_RECEPTION_CANDIDATE","OTHER_CPU_AFTER_LOOSE",p,owner)
    else
     emit("CPU_PASS_UNRESOLVED","OWNER_CHANGE_WITHOUT_FLIGHT",p,owner)
    end
    o.pending=nil
   elseif frame-p.start>=MAX_FRAMES then
    emit("CPU_PASS_UNRESOLVED","TIMEOUT",p)
    o.pending=nil
   elseif owner==0 then
    p.loose_frames=p.loose_frames+1
   elseif owner==p.passer and p.loose_frames>0 then
    emit("CPU_PASS_UNRESOLVED","SAME_OWNER_RECOVERY",p)
    o.pending=nil
   end
  end
  if valid and not o.pending and previous
      and players.valid_cpu_base(previous.owner)
      and previous.owner~=config.CPU_FIRST
      and owner==0 then
   -- Release from an actual prior individual CPU carrier.
   local px,py=players.xy(previous.owner)
   if dist(previous.x,previous.y,px,py)<=65 then
    o.sequence=o.sequence+1
    local entry={id=o.sequence,start=frame,passer=previous.owner,
     x=previous.x,y=previous.y,px=px,py=py,dir=dir,
     pressure=clearance(px,py),zone=zone(px,dir),loose_frames=1}
    o.pending=entry
    emit("CPU_PASS_CANDIDATE","CPU_RELEASE_OBSERVED",entry)
   end
  end
  o.previous={owner=owner,x=bx,y=by}
  return events
 end
 return o
end
return M
