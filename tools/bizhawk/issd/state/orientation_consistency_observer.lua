-- Passive orientation consistency monitor. Does not influence field_side.
local M={}
function M.new(config,mem,players)
 local o={last_key=nil,last_report=-99999,last_cpu=nil,progress=0,samples=0}
 local function flag(addr)
  local v=mem.u8(addr)
  return (v==0 or v==1) and v or nil
 end
 function o.update(frame,gs,active,owner)
  local my=flag(config.ADDR.my_side)
  local cpu=flag(config.ADDR.cpu_side)
  local mx=players.xy(config.MY_FIRST)
  local cx=players.xy(config.CPU_FIRST)
  local sep=cx-mx
  local geom=nil
  if math.abs(sep)>=120 then geom=sep>0 and 1 or -1 end
  local flags=(my~=nil and cpu~=nil and my~=cpu)
  local flag_dir=my~=nil and (my==0 and 1 or -1) or nil
  local cpu_dir=cpu~=nil and (cpu==0 and -1 or 1) or nil
  local status=not flags and "FLAG_CONFLICT" or
      (geom and flag_dir~=geom and "GEOMETRY_CONFLICT" or "CONSISTENT")
  local bx=mem.s16(config.ADDR.ball_x)
  local sample=active and gs==0 and owner~=config.CPU_FIRST
     and players.valid_cpu_base(owner)
  if sample and o.last_cpu and o.last_cpu.owner==owner
      and frame-o.last_cpu.frame==1 then
   local delta=bx-o.last_cpu.x
   if math.abs(delta)>=1 and math.abs(delta)<=25 then
    o.progress=o.progress+delta;o.samples=o.samples+1
   end
  end
  o.last_cpu=sample and {owner=owner,x=bx,frame=frame} or nil
  local key=tostring(my)..":"..tostring(cpu)..":"..tostring(geom)..":"..status
  if key~=o.last_key or frame-o.last_report>=300 then
   o.last_key=key;o.last_report=frame
   local event={kind="ORIENTATION_CONSISTENCY",status=status,
    my_side=my,cpu_side=cpu,flag_attack=flag_dir,
    cpu_flag_attack=cpu_dir,geometry_attack=geom,
    my_gk_x=mx,cpu_gk_x=cx,gk_separation=sep,
    cpu_ball_progress=o.progress,cpu_motion_samples=o.samples}
   o.progress=0;o.samples=0
   return event
  end
  return nil
 end
 return o
end
return M
