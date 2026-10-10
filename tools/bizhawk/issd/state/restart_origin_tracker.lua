-- Passive restart origin observer: evidence of taker is not evidence of
-- individual ownership after release. No class or control overrides.
local M={}
function M.new(config,players)
 local o={pending=nil,sequence=0}
 function o.update(frame,gs,taker_team,taker,owner,fallback,logical,effective)
  local out={}
  local function emit(kind,p,reason)
   out[#out+1]={kind=kind,sequence=p.sequence,team=p.team,
      taker=p.taker,age=frame-p.start,reason=reason,owner=owner,
      fallback=fallback,logical=logical,effective=effective}
  end
  if gs==2 then
   if taker_team=="CPU" or taker_team=="MY" then
    if not o.pending or o.pending.team~=taker_team or o.pending.taker~=taker
       or o.pending.released then
     o.sequence=o.sequence+1
     o.pending={sequence=o.sequence,team=taker_team,taker=taker,start=frame}
     emit("THROW_IN_ORIGIN",o.pending,"TAKER_INFERRED")
    end
   end
   return out
  end
  local p=o.pending
  if not p then return out end
  if gs~=0 then
   emit("THROW_IN_ORIGIN_END",p,"OTHER_GAME_STATE");o.pending=nil
   return out
  end
  if not p.released then
   p.released=frame
   emit("THROW_IN_RELEASE",p,"PLAY_RESUMED")
  end
  if players.valid_my_base(owner) or players.valid_cpu_base(owner) then
   emit("THROW_IN_ORIGIN_END",p,"INDIVIDUAL_CONTROL");o.pending=nil
  elseif frame-p.released>=90 then
   emit("THROW_IN_ORIGIN_END",p,"TIMEOUT");o.pending=nil
  elseif fallback and p.team=="CPU" and fallback=="MY_UNOWNED_BALL" then
   if not p.conflict_logged then
    p.conflict_logged=true
    emit("THROW_IN_CLASSIFICATION_CONFLICT",p,"CPU_THROW_MY_TEMPORAL_CLASS")
   end
  end
  return out
 end
 return o
end
return M
