-- Directional pass calibration: nominal commands only, never actuates buttons.
local M={}
-- Describes button states per frame; never calls joypad.set.
-- The directional pad may be held before B is pressed.
local valid_directions={
 Up=true,Down=true,Left=true,Right=true,
 ["Up+Left"]=true,["Up+Right"]=true,
 ["Down+Left"]=true,["Down+Right"]=true
}
function M.input_sequence(direction,lead_frames,release_before_b)
 if not valid_directions[direction] then return nil,"invalid_direction" end
 if type(lead_frames)~="number" or lead_frames%1~=0
     or lead_frames<0 or lead_frames>120 then return nil,"invalid_lead_frames" end
 if type(release_before_b)~="boolean" then return nil,"invalid_release_mode" end
 local steps={}
 if lead_frames>0 then
  steps[#steps+1]={frames=lead_frames,buttons=direction,phase="AIM"}
 end
 if release_before_b then
  -- Experimental: direction retention after release is NOT verified.
  if lead_frames==0 then return nil,"no_direction_to_release" end
  steps[#steps+1]={frames=1,buttons="",phase="RELEASE"}
 end
 steps[#steps+1]={frames=1,
   buttons=release_before_b and "B" or (direction.."+B"),phase="PASS"}
 return {direction=direction,lead_frames=lead_frames,
   release_before_b=release_before_b,steps=steps,
   status="UNVERIFIED",read_only=true}
end
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
