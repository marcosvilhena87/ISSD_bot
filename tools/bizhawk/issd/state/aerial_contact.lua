-- Observational aerial contact detector; no control outputs.
local M={}
function M.new(config,mem,players)
 local c=config.AERIAL_CONTACT
 local obj={prev=nil,prev2=nil}
 local function nearest(x,y)
  local best,side,dist=nil,nil,math.huge
  local function scan(base,team)
   local px,py=players.xy(base)
   local d=math.sqrt((px-x)^2+(py-y)^2)
   if d<dist then best,side,dist=base,team,d end
  end
  players.each_my(function(base) scan(base,"MY") end)
  players.each_cpu(function(base) scan(base,"CPU") end)
  return best,side,dist
 end
 function obj.reset() obj.prev=nil;obj.prev2=nil end
 function obj.update(active,gs,owner)
  if not active or gs~=0 then obj.reset();return nil end
  local x,y=mem.s16(config.ADDR.ball_x),mem.s16(config.ADDR.ball_y)
  local z=mem.s16(c.height_addr)
  local comparison=mem.s16(c.height_reference_addr)
  local sample={x=x,y=y,z=z,height=math.max(0,-z),reference=comparison}
  local prior=obj.prev
  local older=obj.prev2
  local event=nil
  if prior and older and owner==0 then
   local vx_before=prior.x-older.x
   local vx_after=x-prior.x
   local vy_before=prior.y-older.y
   local vy_after=y-prior.y
   local vertical_before=-(prior.z-older.z)
   local vertical_after=-(z-prior.z)
   local horizontal_reversal=(vx_before*vx_after<0
      and math.abs(vx_before)>=c.min_horizontal_speed
      and math.abs(vx_after)>=c.min_horizontal_speed)
      or (vy_before*vy_after<0
      and math.abs(vy_before)>=c.min_horizontal_speed
      and math.abs(vy_after)>=c.min_horizontal_speed)
   local vertical_reversal=vertical_before<=-c.min_vertical_speed
      and vertical_after>=c.min_vertical_speed
   if prior.height>=c.min_height
      and vertical_reversal and horizontal_reversal then
    local base,side,d=nearest(prior.x,prior.y)
    event={height=prior.height,x=prior.x,y=prior.y,
      before_vx=vx_before,after_vx=vx_after,
      before_vy=vy_before,after_vy=vy_after,
      before_vz=vertical_before,after_vz=vertical_after,
      z_reference=prior.reference,nearest_base=base,
      nearest_team=side,nearest_distance=d,
      plausible_near_player=d<=c.near_player_radius}
   end
  end
  obj.prev2=prior;obj.prev=sample
  return event
 end
 return obj
end
return M
