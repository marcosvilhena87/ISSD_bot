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
     last_owner=p and p.last_owner,
     action_count=p and p.action_count,
     action_age=p and p.action_frame and frame-p.action_frame,
     action_kind=p and p.action_kind,
     action_owner=p and p.action_owner,
     action_saw_loose=p and p.action_saw_loose,
     first_receiver=p and p.first_receiver,
     receive_age=p and p.receive_frame and frame-p.receive_frame,
     received_zone=p and p.received_zone,
     progress_after_receive=p and p.receive_progress and x
       and (x-p.receive_progress)*dir or nil,
     max_progress_after_receive=p and p.max_progress_after_receive,
     source=p and p.source,
     reception_kind=p and p.reception_kind,
     grace_deadline=p and p.grace_deadline,
     grace_granted=p and p.grace_granted}
  end
  local valid=state.game_state==0 -- 0x00BA authoritative for transition observation
  local my=players.valid_my_base(owner)
  local cpu=players.valid_cpu_base(owner)
  if my then x=players.xy(owner) end
  local boundary=nil
  if x then z,boundary=zone(x,dir) end
  local pending=o.pending
  if pending then
   -- Link the first individually confirmed reception after an action.
   -- The command itself never counts as a successful pass or clearance.
   if valid and pending.action_frame and owner==0 then
    pending.action_saw_loose=true
   end
   if valid and pending.action_frame and not pending.first_receiver
      and frame>pending.action_frame and my
      and (owner~=pending.action_owner or pending.action_saw_loose) then
    pending.first_receiver=owner
    pending.receive_frame=frame
    pending.receive_progress=x
    pending.received_zone=z
    pending.reception_kind=owner~=pending.action_owner
      and "OTHER_PLAYER" or "SAME_PLAYER_RECOVERY"
    pending.max_progress_after_receive=0
    emit("RECEIVED",pending.reception_kind,pending)
   end
   if pending.receive_progress and my and x then
    pending.max_progress_after_receive=math.max(
      pending.max_progress_after_receive or 0,
      (x-pending.receive_progress)*dir)
   end
   if not valid or dir~=pending.dir then
    local reason=state.game_state~=0 and "GAME_STATE_STOPPAGE"
      or dir~=pending.dir and "ATTACK_DIRECTION_CHANGED"
      or "INVALID_CONTEXT"
    emit("FAILED",reason,pending);o.pending=nil
   elseif cpu then
    emit("FAILED","CPU_TURNOVER",pending);o.pending=nil
   elseif frame-pending.start>=c.max_frames
      and not (pending.grace_deadline and frame<=pending.grace_deadline) then
    -- Only a currently confirmed midfield carrier can earn a short grace.
    if my and z==2 and pending.first_middle
       and not pending.grace_granted
       and frame-pending.first_middle<c.stable_frames then
      pending.grace_granted=true
      pending.grace_deadline=c.max_frames+pending.start
        +(c.stability_grace_frames or c.stable_frames)
      emit("GRACE","MIDFIELD_STABILITY_PENDING",pending)
    else
      emit("FAILED","TIMEOUT",pending);o.pending=nil
    end
   end
   if o.pending and my and z==2 then
    if pending.first_middle==nil then
     pending.first_middle=frame
     emit("CROSSED","INDIVIDUAL_MY_POSSESSION",pending)
    end
    if frame-pending.first_middle>=c.stable_frames then
     emit("ESTABLISHED","STABLE_MY_POSSESSION",pending);o.pending=nil
    end
   elseif o.pending then
    -- Stability must be consecutive; losing control cancels the grace.
    if pending.grace_granted then
      emit("FAILED","GRACE_INTERRUPTED",pending);o.pending=nil
    else
      pending.first_middle=nil
    end
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
      owner_changes=0,loose_frames=0,last_owner=owner,
      source=owner==config.MY_FIRST and "GOALKEEPER" or "OUTFIELD",
      action_count=0,action_frame=nil,action_kind=nil,
      action_owner=nil,action_saw_loose=false,
      first_receiver=nil,receive_frame=nil,
      receive_progress=nil,received_zone=nil,max_progress_after_receive=0,
      reception_kind=nil,grace_deadline=nil,grace_granted=false}
    emit("START","CONFIRMED_FIRST_THIRD_POSSESSION",o.pending)
   end
  end
  local action=nil
  if state.forward_pass_fired then action="PASS"
  elseif state.defensive_clear_fired then action="CLEAR" end
  if o.pending and action then
   local p=o.pending
   -- A new kick supersedes the preceding reception window.
   if p.action_frame and not p.first_receiver then
    emit("UNRESOLVED","ACTION_SUPERSEDED",p)
   end
   p.route=action
   p.action_count=p.action_count+1
   p.action_frame=frame
   p.action_kind=action
   p.action_owner=owner
   p.action_saw_loose=false
   p.first_receiver=nil
   p.receive_frame=nil
   p.receive_progress=nil
   p.received_zone=nil
   p.reception_kind=nil
   p.max_progress_after_receive=0
   emit(action,action=="PASS" and "PASS_COMMANDED_NOT_CONFIRMED"
     or "CLEARANCE_NOT_CONFIRMED",p)
  end
  o.last_owner=owner
  return events
 end
 return o
end
return M
