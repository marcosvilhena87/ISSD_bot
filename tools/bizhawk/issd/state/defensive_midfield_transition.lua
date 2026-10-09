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
  local function emit(kind,reason,p)
   events[#events+1]={kind=kind,reason=reason,
     sequence=p and p.sequence,age=p and frame-p.start,
     route=p and p.route,boundary=p and p.boundary}
  end
  local dir=field_side.attack_direction()
  local valid=state.game_state==0 and state.gameplay_active==1
  local owner=state.possession
  local my=players.valid_my_base(owner)
  local cpu=players.valid_cpu_base(owner)
  local x=nil
  if my then x=players.xy(owner) end
  local z,boundary=x and zone(x,dir) or nil,nil
  if x then z,boundary=zone(x,dir) end
  local pending=o.pending
  if pending then
   if not valid or dir~=pending.dir then
    emit("FAILED","STOPPAGE_OR_SIDE_CHANGE",pending);o.pending=nil
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
  if valid and my and z==1 and not o.pending then
   -- Avoid repeatedly reopening a transition with the same stalled owner.
   if o.last_owner~=owner then
    o.sequence=o.sequence+1
    o.pending={start=frame,sequence=o.sequence,dir=dir,
      boundary=boundary,route="CARRY",first_middle=nil}
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
