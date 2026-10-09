-- Observation-only second-to-final-third transition.
local M={}
function M.new(config,mem,players,field_side)
 local c=config.MID_ATTACK_TRANSITION
 local o={pending=nil,sequence=0,last_owner=nil}
 local function zone(x,dir)
  local len=mem.u16(config.ADDR.field_length)
  local ctr=mem.u16(config.ADDR.center_field_x)
  if len<500 or len>4000 or ctr<100 or (dir~=1 and dir~=-1) then return nil end
  local prog=(x-(ctr-dir*len/2))*dir
  if prog<0 or prog>len then return nil end
  return prog<len/3 and 1 or prog<2*len/3 and 2 or 3
 end
 function o.update(s,frame)
  local out={}
  local dir=field_side.attack_direction()
  local valid=s.game_state==0 and s.gameplay_active==1
  local owner=s.possession
  local my=players.valid_my_base(owner)
  local cpu=players.valid_cpu_base(owner)
  local x=my and players.xy(owner) or nil
  local z=x and zone(x,dir) or nil
  local p=o.pending
  local function emit(kind,reason,p)
   out[#out+1]={kind=kind,reason=reason,sequence=p.sequence,
    age=frame-p.start,route=p.route}
  end
  if p then
   if not valid or dir~=p.dir then emit("FAILED","STOPPAGE_OR_SIDE_CHANGE",p);o.pending=nil
   elseif cpu then emit("FAILED","CPU_TURNOVER",p);o.pending=nil
   elseif frame-p.start>=c.max_frames then emit("FAILED","TIMEOUT",p);o.pending=nil
   elseif my and z==3 then
    if not p.entered then p.entered=frame;emit("CROSSED","MY_FINAL_THIRD_POSSESSION",p) end
    if frame-p.entered>=c.stable_frames then
     emit("ESTABLISHED","STABLE_MY_FINAL_THIRD_POSSESSION",p);o.pending=nil
    end
   else p.entered=nil end
   if o.pending and s.shot_fired then emit("SHOT","SHOT_COMMANDED",p) end
  end
  if valid and my and z==2 and not o.pending and o.last_owner~=owner then
   o.sequence=o.sequence+1
   o.pending={sequence=o.sequence,start=frame,dir=dir,route="CARRY"}
   emit("START","CONFIRMED_MIDFIELD_POSSESSION",o.pending)
  end
  if o.pending and s.forward_pass_fired then
   o.pending.route="PASS"
   emit("PASS","PASS_COMMANDED",o.pending)
  end
  o.last_owner=owner
  return out
 end
 function o.reset() o.pending=nil;o.last_owner=nil end
 return o
end
return M
