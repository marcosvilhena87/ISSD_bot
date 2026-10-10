-- Conservative ground-ball interception for logically unowned possession.
-- Higher-priority shots, headers and rebounds are handled before this policy.
local M={}
function M.new(config,players,field_boundary)
 local c=config.GROUND_BALL_INTERCEPTION
 local o={lock=nil}
 function o.reset() o.lock=nil end
 function o.plan(frame,base,team,bx,by,vx,vy,height)
  if not c.enabled or (team~="MY" and team~="CPU")
     or not players.valid_my_base(base) or base==config.MY_FIRST
     or height>c.max_height or bx==0 or by==0 then
   o.reset();return nil
  end
  local px,py=players.xy(base)
  local dist=math.sqrt((bx-px)^2+(by-py)^2)
  if dist>c.max_player_distance then o.reset();return nil end
  local speed=math.sqrt(vx*vx+vy*vy)
  if speed>c.max_ball_speed then o.reset();return nil end
  local lead=math.min(c.max_lead_frames,math.floor(dist/c.estimated_player_speed))
  if speed<c.min_ball_speed then lead=0 end
  local tx,ty=bx+vx*lead,by+vy*lead
  local corrected=field_boundary.correct(px,py,tx,ty)
  tx,ty=corrected.x,corrected.y
  if o.lock and o.lock.team==team and o.lock.base==base
      and frame-o.lock.start<c.lock_frames
      and (bx-o.lock.bx)^2+(by-o.lock.by)^2<=c.max_ball_drift^2
      and (tx-o.lock.x)^2+(ty-o.lock.y)^2<=c.max_target_drift^2 then
    tx,ty=o.lock.x,o.lock.y
  else
    o.lock={team=team,base=base,start=frame,x=tx,y=ty,bx=bx,by=by}
  end
  return {x=tx,y=ty,lead=lead,speed=speed,distance=dist,team=team,height=height}
 end
 return o
end
return M
