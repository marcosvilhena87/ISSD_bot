-- Observational outcomes for commanded ground-ball interception episodes.
-- A single player possession frame is provisional; confirmation requires two.
local M={}
function M.new(config,players)
 local o={episode=nil,sequence=0,pending_owner=nil,pending_frames=0}
 local function owned(base)
  if players.valid_my_base(base) then return "MY" end
  if players.valid_cpu_base(base) then return "CPU" end
  return nil
 end
 function o.update(frame,active,gs,owner,bx,by)
  local e=o.episode
  if not e then return nil end
  local reason=nil
  local kind=nil
  local team=owned(owner)
  if not active or gs~=0 then
   kind="GROUND_BALL_INTERCEPT_ABORT";reason="STOPPAGE"
  elseif team then
   if owner==o.pending_owner then o.pending_frames=o.pending_frames+1
   else o.pending_owner=owner;o.pending_frames=1 end
   if o.pending_frames>=2 then
    kind=team=="MY" and "GROUND_BALL_INTERCEPT_SUCCESS"
        or "GROUND_BALL_INTERCEPT_CPU_WON"
    reason="INDIVIDUAL_CONTROL_CONFIRMED"
   end
  else
   o.pending_owner=nil;o.pending_frames=0
  end
  if not kind and frame-e.last_command>10 then
   kind="GROUND_BALL_INTERCEPT_ABORT";reason="COMMAND_ENDED"
  end
  if not kind and frame-e.start>=180 then
   kind="GROUND_BALL_INTERCEPT_ABORT";reason="TIMEOUT"
  end
  if not kind then return nil end
  o.episode=nil;o.pending_owner=nil;o.pending_frames=0
  return {kind=kind,sequence=e.sequence,team=e.team,base=e.base,
      receiver=team and owner or nil,start=e.start,age=frame-e.start,
      start_x=e.start_x,start_y=e.start_y,target_x=e.target_x,
      target_y=e.target_y,end_x=bx,end_y=by,reason=reason}
 end
 function o.command(frame,team,base,bx,by,tx,ty)
  local e=o.episode
  if e and (e.team~=team or e.base~=base) then return nil end
  if not e then
   o.sequence=o.sequence+1
   e={sequence=o.sequence,team=team,base=base,start=frame,
      start_x=bx,start_y=by,target_x=tx,target_y=ty}
   o.episode=e
  end
  e.last_command=frame
  if e.start==frame then
   return {kind="GROUND_BALL_INTERCEPT_START",sequence=e.sequence,
      team=team,base=base,start=frame,target_x=tx,target_y=ty,
      start_x=bx,start_y=by}
  end
  return nil
 end
 function o.active_sequence()
  return o.episode and o.episode.sequence or nil
 end
 return o
end
return M
