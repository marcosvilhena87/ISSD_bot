-- Keep controlled dribbling inside calibrated field bounds.
local M={}
function M.new(config,mem)
 local c=config.FIELD_BOUNDARY
 local o={}
 function o.correct(px,py,tx,ty)
  local length=mem.u16(config.ADDR.field_length)
  local width=mem.u16(config.ADDR.field_width)
  local cx=mem.u16(config.ADDR.center_field_x)
  local cy=mem.u16(config.ADDR.center_field_y)
  if length<500 or length>4000 or width<200 or width>2000 then
   return {x=tx,y=ty,valid=false,changed=false,risk=false}
  end
  local minx=cx-length/2+c.margin_x
  local maxx=cx+length/2-c.margin_x
  local miny=cy-width/2+c.margin_y
  local maxy=cy+width/2-c.margin_y
  local x=math.max(minx,math.min(maxx,tx))
  local y=math.max(miny,math.min(maxy,ty))
  -- When already close to a touchline or endline, never keep pressing outward.
  if px<=minx+c.risk_zone and x<=px then x=math.min(maxx,px+c.inward_step) end
  if px>=maxx-c.risk_zone and x>=px then x=math.max(minx,px-c.inward_step) end
  if py<=miny+c.risk_zone and y<=py then y=math.min(maxy,py+c.inward_step) end
  if py>=maxy-c.risk_zone and y>=py then y=math.max(miny,py-c.inward_step) end
  return {x=x,y=y,valid=true,changed=x~=tx or y~=ty,
   risk=px<=minx+c.risk_zone or px>=maxx-c.risk_zone
    or py<=miny+c.risk_zone or py>=maxy-c.risk_zone,
   original_x=tx,original_y=ty}
 end
 return o
end
return M
