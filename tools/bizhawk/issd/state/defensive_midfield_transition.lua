-- Observation-only continuity of the first-to-second-third transition.
-- Confirmed individual Brazilian possession is required for success.
local M={}
function M.new(config,mem,players,field_side)
 local c=config.DEFENSIVE_MIDFIELD_TRANSITION
 local o={pending=nil,sequence=0,last_owner=nil}
 function o.reset() o.pending=nil;o.last_owner=nil end
 local function zone(x,dir)
  local length=mem.u16(config.ADDR.field_length)
  local center=mem.u16(config.ADDR.center_field_x)
  if length<500 or length>4000 or center<100 or (dir~=1 and dir~=-1)
    then return nil,nil end
  local start=center-dir*length/2
  local progress=(x-start)*dir
  if progress<0 or progress>length then return nil,nil end
  return (progress<length/3 and 1 or progress<2*length/3 and 2 or 3),
    start+dir*length/3
 end
 function o.update(state,frame)
  local events={}
  local owner=state.possession
  local dir=field_side.attack_direction()
  local x=nil
  local z=nil
  local function emit(kind,reason,p)
   events[#events+1]={kind=kind,reason=reason,
     sequence=p and p.sequence,age=p and frame-p.start,
     route=p and p.route,boundary=p and p.boundary,
     game_state=state.game_state,gameplay_active=state.gameplay_active,
     possession=owner,selected=state.my_base,status=state.status,
     direction=dir,zone=z,first_middle=p and p.first_middle,
     owner_changes=p and p.owner_changes,
     loose_frames=p and p.loose_frames,
     last_owner=p and p.last_owner}
  end
  local valid=state.game_state==0 -- 0x00BA authoritative for transition observation
  local my=players.valid_my_base(owner)
  local cpu=players.valid_cpu_base(owner)
  if my then x=players.xy(owner) end
  local boundary=nil
  if x then z,boundary=zone(x,dir) end
  local pending=o.pending
  if pending then
   if not valid or dir~=pending.dir then
    local reason=state.game_state~=0 and "GAME_STATE_STOPPAGE"
      or dir~=pending.dir and "ATTACK_DIRECTION_CHANGED"
      or "INVALID_CONTEXT"
    emit("FAILED",reason,pending);o.pending=nil
   elseif cpu then
    emit("FAILED","CPU_TURNOVER",pending);o.pending=nil
   elseif frame-pending.start>=c.max_frames then
    emit("FAILED","TIMEOUT",pending);o.pending=nil
   elseif my and z==2 then
    if pending.first_middle==nil then
     pending.first_middle=frame
     emit("CROSSED","INDIVIDUAL_MY_POSSESSION",pending)
    end
    if frame-pending.first_middle>=c.stable_frames then
     emit("ESTABLISHED","STABLE_MY_POSSESSION",pending);o.pending=nil
    end
   else
    pending.first_middle=nil
   end
  end
  if o.pending then
   if owner==0 then o.pending.loose_frames=o.pending.loose_frames+1 end
   if owner~=o.pending.last_owner then
    o.pending.owner_changes=o.pending.owner_changes+1
    o.pending.last_owner=owner
   end
  end
  if valid and my and z==1 and not o.pending then
   -- Avoid repeatedly reopening a transition with the same stalled owner.
   if o.last_owner~=owner then
    o.sequence=o.sequence+1
    o.pending={start=frame,sequence=o.sequence,dir=dir,
      boundary=boundary,route="CARRY",first_middle=nil,
      owner_changes=0,loose_frames=0,last_owner=owner}
    emit("START","CONFIRMED_FIRST_THIRD_POSSESSION",o.pending)
   end
  end
  if o.pending and state.forward_pass_fired then
   o.pending.route="PASS"
   emit("PASS","PASS_COMMANDED_NOT_CONFIRMED",o.pending)
  end
  if o.pending and state.defensive_clear_fired then
   o.pending.route="CLEAR"
   emit("CLEAR","CLEARANCE_NOT_CONFIRMED",o.pending)
  end
  o.last_owner=owner
  return events
 end
 return o
end
return M
