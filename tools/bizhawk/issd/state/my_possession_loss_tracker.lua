-- Passive tracker: release is not a confirmed loss until CPU owns the ball.
local M={}
function M.new(config,players)
 local o={previous=nil,episode=nil,sequence=0,cpu_streak=0}
 local min_cpu=2
 local timeout=240
 function o.update(frame,active,gs,owner,bx,by)
  local out={}
  local function emit(kind,e,extra)
   local event={kind=kind,sequence=e.sequence,origin=e.origin,
     start=e.start,age=frame-e.start,from_x=e.x,from_y=e.y,
     end_x=bx,end_y=by,owner=owner}
   if extra then for k,v in pairs(extra) do event[k]=v end end
   out[#out+1]=event
  end
  if not active or gs~=0 then
   if o.episode then emit("MY_POSSESSION_UNRESOLVED",o.episode,
      {reason="GAME_STOPPAGE"}) end
   o.episode=nil;o.previous=nil;o.cpu_streak=0
   return out
  end
  local mine=players.valid_my_base(owner)
  local cpu=players.valid_cpu_base(owner)
  if o.episode then
   local e=o.episode
   if mine then
    emit(owner==e.origin and "MY_DRIBBLE_CONTINUITY"
       or "MY_TEAM_POSSESSION_RETAINED",e,{receiver=owner,
         reason=owner==e.origin and "SAME_PLAYER" or "TEAMMATE"})
    o.episode=nil;o.cpu_streak=0
   elseif cpu then
    if e.cpu_candidate~=owner then
     e.cpu_candidate=owner;o.cpu_streak=1
    else o.cpu_streak=o.cpu_streak+1 end
    if o.cpu_streak>=min_cpu then
     emit("MY_POSSESSION_LOSS_CONFIRMED",e,
          {receiver=owner,confirmation_frames=o.cpu_streak})
     o.episode=nil;o.cpu_streak=0
    end
   else
    e.cpu_candidate=nil;o.cpu_streak=0
    if frame-e.start>=timeout then
     emit("MY_POSSESSION_UNRESOLVED",e,{reason="TIMEOUT"})
     o.episode=nil
    end
   end
  end
  if not o.episode and o.previous and players.valid_my_base(o.previous)
      and not mine and not cpu and owner==0 then
   o.sequence=o.sequence+1
   o.episode={sequence=o.sequence,origin=o.previous,
      start=frame,x=bx,y=by}
   emit("MY_POSSESSION_RELEASE",o.episode)
  end
  o.previous=owner
  return out
 end
 return o
end
return M
