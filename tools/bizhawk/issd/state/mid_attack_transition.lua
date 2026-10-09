-- Observation-only midfield-to-attack progression with timeout diagnostics.
local M={}
function M.new(config,mem,players,field_side)
 local c=config.MID_ATTACK_TRANSITION
 local o={pending=nil,sequence=0,last_owner=nil}
 local function position(x,dir)
  local len=mem.u16(config.ADDR.field_length)
  local ctr=mem.u16(config.ADDR.center_field_x)
  if len<500 or len>4000 or ctr<100 or (dir~=1 and dir~=-1) then return nil end
  local progress=(x-(ctr-dir*len/2))*dir
  if progress<0 or progress>len then return nil end
  return progress,(progress<len/3 and 1 or progress<2*len/3 and 2 or 3),2*len/3
 end
 function o.update(s,frame)
  local out={}
  local dir=field_side.attack_direction()
  local valid=s.game_state==0 and s.gameplay_active==1
  local owner=s.possession
  local my=players.valid_my_base(owner)
  local cpu=players.valid_cpu_base(owner)
  local x=my and players.xy(owner) or nil
  local progress,z,boundary=nil,nil,nil
  if x then progress,z,boundary=position(x,dir) end
  local p=o.pending
  local function emit(kind,reason,a)
   out[#out+1]={kind=kind,reason=reason,sequence=a.sequence,
    age=frame-a.start,route=a.route,start_progress=a.start_progress,
    max_progress=a.max_progress,net_progress=a.last_progress-a.start_progress,
    progress_gain=a.max_progress-a.start_progress,
    remaining=math.max(0,a.boundary-a.max_progress),
    first_cross_age=a.first_cross and a.first_cross-a.start or nil,
    entries=a.entries,returns=a.returns,retreats=a.retreats,
    unowned_frames=a.unowned_frames,deadline=a.deadline,
    extensions=a.extensions,recent_gain=a.recent_gain or 0}
  end
  if p then
   if my and progress then
    p.history[#p.history+1]={frame=frame,progress=progress}
    while #p.history>0 and frame-p.history[1].frame>c.progress_window_frames do
     table.remove(p.history,1)
    end
    p.last_progress=progress
    p.max_progress=math.max(p.max_progress,progress)
    if p.previous_progress and p.previous_progress-progress>=c.retreat_delta then
     p.retreats=p.retreats+1
    end
    p.previous_progress=progress
   elseif owner==0 then p.unowned_frames=p.unowned_frames+1 end
   if not valid or dir~=p.dir then
    emit("FAILED","STOPPAGE_OR_SIDE_CHANGE",p);o.pending=nil
   elseif cpu then emit("FAILED","CPU_TURNOVER",p);o.pending=nil
   elseif frame-p.start>=p.deadline then
    local baseline=p.history[1] and p.history[1].progress or p.last_progress
    p.recent_gain=p.max_progress-baseline
    if p.deadline<c.absolute_max_frames
       and my and progress and p.recent_gain>=c.min_recent_progress then
     p.deadline=math.min(c.absolute_max_frames,
         p.deadline+c.extension_frames)
     p.extensions=p.extensions+1
     emit("EXTENDED","RECENT_TERRITORIAL_PROGRESS",p)
    else
     emit("FAILED",p.deadline>=c.absolute_max_frames
        and "ABSOLUTE_TIMEOUT" or "NO_RECENT_PROGRESS",p)
     o.pending=nil
    end
   elseif my and z==3 then
    if not p.entered then
     p.entered=frame;p.entries=p.entries+1
     if not p.first_cross then
      p.first_cross=frame;emit("CROSSED","FIRST_MY_FINAL_THIRD_POSSESSION",p)
     else emit("REENTERED","MY_FINAL_THIRD_AGAIN",p) end
    end
    if frame-p.entered>=c.stable_frames then
     emit("ESTABLISHED","STABLE_MY_FINAL_THIRD_POSSESSION",p);o.pending=nil
    end
   else
    if p.entered then
     p.returns=p.returns+1
     emit("STABILITY_RESET",my and "RETURNED_TO_MIDFIELD" or "POSSESSION_UNOWNED",p)
     p.entered=nil
    end
   end
   if o.pending and s.shot_fired then emit("SHOT","SHOT_COMMANDED",p) end
  end
  if valid and my and z==2 and not o.pending and o.last_owner~=owner then
   o.sequence=o.sequence+1
   o.pending={sequence=o.sequence,start=frame,dir=dir,route="CARRY",
    start_progress=progress,last_progress=progress,max_progress=progress,
    previous_progress=progress,boundary=boundary,entries=0,returns=0,
    retreats=0,unowned_frames=0,entered=nil,first_cross=nil,
    deadline=c.max_frames,extensions=0,recent_gain=0,
    history={{frame=frame,progress=progress}}}
   emit("START","CONFIRMED_MIDFIELD_POSSESSION",o.pending)
  end
  if o.pending and s.forward_pass_fired then
   o.pending.route="PASS";emit("PASS","PASS_COMMANDED",o.pending)
  end
  o.last_owner=owner
  return out
 end
 function o.reset() o.pending=nil;o.last_owner=nil end
 return o
end
return M
