-- Directional pass calibration: nominal commands only, never actuates buttons.
local M={}
local function valid(p) return type(p)=="table" and type(p.x)=="number" and type(p.y)=="number" end
function M.direction(a,b)
 if not valid(a) or not valid(b) then return nil end
 local dx,dy=b.x-a.x,b.y-a.y
 if dx==0 and dy==0 then return nil end
 -- Eight compass sectors, split at 22.5 and 67.5 degrees.
 local ax,ay=math.abs(dx),math.abs(dy)
 local k=math.tan(math.pi/8)
 local horizontal=ax>0 and ay<=ax*k
 local vertical=ay>0 and ax<=ay*k
 local h=dx>0 and "Right" or "Left"
 local v=dy>0 and "Down" or "Up"
 local direction=horizontal and h or vertical and v or (v.."+"..h)
 return {direction=direction,command=direction.."+B",
   dx=dx,dy=dy,
   status="UNVERIFIED"}
end
return M
