-- Observe actual territorial outcome after charged defensive clearances.
local M={}
function M.new(config,players,field_side)
 local c=config.DEFENSIVE_CLEARANCE_OUTCOME
 local o={pending=nil,sequence=0}
 function o.start(frame,x,y,carrier,frames,dir)
  o.sequence=o.sequence+1
  o.pending={frame=frame,x=x,y=y,carrier=carrier,frames=frames,
    dir=dir,sequence=o.sequence, inactive_frames=0, first_receiver=nil}
  return o.pending.sequence
 end
 function o.update(state,frame)
  local p=o.pending
  if not p then return nil end
  local age=frame-p.frame
  local dir=field_side.attack_direction()
  local progress=dir*(state.ball_x-p.x)
  local kind,reason=nil,nil
  if state.gameplay_active~=1 then p.inactive_frames=p.inactive_frames+1 end
  if state.game_state~=0 then
   kind="UNRESOLVED";reason="GAME_STATE_STOPPAGE"
  elseif dir~=p.dir then
   kind="UNRESOLVED";reason="ATTACK_DIRECTION_CHANGED"
  elseif age>0 and players.valid_my_base(state.possession)
       and state.possession~=p.carrier then
   kind="RECEIVED";reason="MY_POSSESSION"
  elseif age>0 and players.valid_cpu_base(state.possession) then
   kind="INTERCEPTED";reason="CPU_POSSESSION"
  elseif age>=c.max_frames then
   kind="UNRESOLVED";reason="TIMEOUT"
  end
  if kind then
   o.pending=nil
   return {kind=kind,reason=reason,sequence=p.sequence,age=age,
    progress=progress,start_x=p.x,end_x=state.ball_x,
    frames=p.frames,owner=state.possession,
    receiver=kind=="RECEIVED" and state.possession or nil,
    receiver_x=kind=="RECEIVED" and players.xy(state.possession) or nil,
    inactive_frames=p.inactive_frames,game_state=state.game_state,
    gameplay_active=state.gameplay_active}
  end
 end
 return o
end
return M
