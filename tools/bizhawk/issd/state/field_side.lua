-- Stable attacking direction derived from goalkeeper geometry.
-- Side flags are diagnostic only, because transient RAM values are unreliable.
local M={}
function M.new(config,mem)
 local obj={}
 local c=config.ORIENTATION_RESOLVER
 local stable=nil
 local candidate=nil
 local candidate_frames=0
 local source="UNKNOWN"
 local previous_gs=nil
 local restart_budget=0
 local pending_period_end=false
 local function direction_from_goalkeepers()
  local mx=mem.s16(config.MY_FIRST+config.OFFSET.world_x)
  local cx=mem.s16(config.CPU_FIRST+config.OFFSET.world_x)
  local sep=cx-mx
  local length=mem.u16(config.ADDR.field_length)
  local center=mem.u16(config.ADDR.center_field_x)
  local plausible=length>=c.min_field_length and length<=c.max_field_length
      and center>=c.min_center
      and math.abs(sep)>=c.min_gk_separation
      and mx>=center-length/2-c.margin
      and mx<=center+length/2+c.margin
      and cx>=center-length/2-c.margin
      and cx<=center+length/2+c.margin
  return plausible and (sep>0 and 1 or -1) or nil,mx,cx
 end
 function obj.tick(active,gs)
  -- State 6 ends a period (half-time OR full-time). Only arm fast
  -- confirmation after an actual 6 -> live transition, never while paused.
  if gs==6 then pending_period_end=true end
  if previous_gs~=gs and gs==0 and pending_period_end then
   restart_budget=c.restart_fast_window_frames
   pending_period_end=false
   candidate=nil
   candidate_frames=0
  end
  previous_gs=gs
  local geometry=active and gs==0 and select(1,direction_from_goalkeepers()) or nil
  if geometry then
   if geometry==stable then
    candidate=nil;candidate_frames=0
    source="GOALKEEPER_GEOMETRY"
   else
    if geometry~=candidate then candidate=geometry;candidate_frames=1
    else candidate_frames=candidate_frames+1 end
    local needed=stable and
        (restart_budget>0 and c.initial_confirm_frames or c.change_confirm_frames)
        or c.initial_confirm_frames
    if candidate_frames>=needed then
     stable=geometry;candidate=nil;candidate_frames=0
     source=restart_budget>0 and "PERIOD_RESTART_CONFIRMED" or "GOALKEEPER_GEOMETRY_CONFIRMED"
     restart_budget=0
    end
   end
  else
   candidate=nil;candidate_frames=0
   if stable then source="HELD_LAST_VALID" else source="UNKNOWN" end
  end
  if active and gs==0 and restart_budget>0 then
   restart_budget=restart_budget-1
  end
 end
 function obj.cpu_side()
  local v=mem.u8(config.ADDR.cpu_side)
  return (v==0 or v==1) and v or nil
 end
 function obj.my_side()
  if stable==1 then return 0 end
  if stable==-1 then return 1 end
  return nil
 end
 function obj.attack_direction() return stable or 0 end
 function obj.goal_direction() return stable and -stable or 0 end
 function obj.diagnostic()
  local geometric,mx,cx=direction_from_goalkeepers()
  return {direction=stable or 0,source=source,candidate=candidate,
      candidate_frames=candidate_frames,restart_budget=restart_budget,geometry=geometric,
      my_gk_x=mx,cpu_gk_x=cx,
      raw_my_side=mem.u8(config.ADDR.my_side),
      raw_cpu_side=mem.u8(config.ADDR.cpu_side)}
 end
 return obj
end
return M
