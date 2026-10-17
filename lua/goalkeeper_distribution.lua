-- Read-only goalkeeper distribution planner. No generic pass range assumptions.
local M={}
local Direction=require("directional_pass_calibration")
-- One associated GK -> receiver 4 event in 2026-10-17 report, frame 6245 -> 6314.
-- B edge was observed, directional input was NOT observed. Keep this provisional.
local SAMPLE={dx=343,dy=39,distance=345.2100809652,clearance=272.24437551582}
local function similar(o)
 return o.id==4 and o.direction=="Right" and
   math.abs(o.dx-SAMPLE.dx)<=35 and math.abs(o.dy-SAMPLE.dy)<=25 and
   math.abs(o.distance-SAMPLE.distance)<=40 and
   o.clearance>=240
end
-- Frame 6381 -> 6478: B, then team possession by ID 5.
-- GK option ID5: dx=410 dy=148 distance=435.89 clearance=250.19.
-- Input was RELEASED_THEN_B: direction at B is unverified.
local SAMPLE5={dx=410,dy=148,distance=435.8944826446}
local function similar5(o)
 return o.id==5 and o.direction=="Right" and
   math.abs(o.dx-SAMPLE5.dx)<=30 and math.abs(o.dy-SAMPLE5.dy)<=25 and
   math.abs(o.distance-SAMPLE5.distance)<=35 and o.clearance>=235
end
local function finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
local function point(p) return type(p)=="table" and finite(p.x) and finite(p.y) end
local function distance(a,b)
 local x,y=a.x-b.x,a.y-b.y
 return math.sqrt(x*x+y*y)
end
local function line_clearance(a,b,e)
 local dx,dy=b.x-a.x,b.y-a.y
 local den=dx*dx+dy*dy
 local t=den>0 and ((e.x-a.x)*dx+(e.y-a.y)*dy)/den or 0
 t=math.max(0,math.min(1,t))
 return distance(e,{x=a.x+t*dx,y=a.y+t*dy})
end
function M.plan(s)
 if type(s)~="table" or s.active~=true or s.possession~="my"
     or s.ownership_source~="PLAYER_BALL_POSSESSION"
     or type(s.my_players)~="table" or type(s.cpu_players)~="table"
     or not point(s.ball) then return nil,"unconfirmed_possession" end
 local keeper
 for _,p in ipairs(s.my_players) do
  if p.id==s.carrier_id and p.is_goalkeeper==true and point(p) then keeper=p;break end
 end
 if not keeper then return nil,"not_goalkeeper" end
 local options={}
 for _,p in ipairs(s.my_players) do
  if p.id~=keeper.id and not p.is_goalkeeper and point(p) then
   local clearance=math.huge
   local blocker
   for _,enemy in ipairs(s.cpu_players) do
    if point(enemy) then
     local d=line_clearance(s.ball,p,enemy)
     if d<clearance then clearance=d;blocker=enemy.id end
    end
   end
   local vector=Direction.direction(s.ball,p)
   options[#options+1]={id=p.id,direction=vector and vector.direction,
      command=vector and vector.command,dx=vector and vector.dx,dy=vector and vector.dy,
      input_sequence=vector and Direction.input_sequence(vector.direction,1,false),
      distance=distance(s.ball,p),
      keeper_distance=distance(keeper,p),clearance=clearance,
      blocker_id=blocker,status="UNCALIBRATED"}
  end
 end
 table.sort(options,function(a,b)
  if a.distance==b.distance then return tostring(a.id)<tostring(b.id) end
  return a.distance<b.distance
 end)
 local nearest={}
 for i=1,math.min(3,#options) do nearest[i]=options[i] end
 local selected
 -- Give the new observed ID5 profile precedence when both profiles match:
 -- a previous GK4 recommendation in this exact geometry was received by ID5.
 for _,o in ipairs(nearest) do
  if similar5(o) then selected=o;break end
 end
 if not selected then
  for _,o in ipairs(nearest) do
   if similar(o) then selected=o;break end
  end
 end
 if selected then selected.status="PROVISIONAL_OBSERVED" end
 local reason=selected and
   (selected.id==5 and "provisional_gk5_geometry_match" or "provisional_gk4_geometry_match")
   or "distribution_requires_calibration"
 return {mode="GK_DISTRIBUTION",
   reason=reason,
   target_id=selected and selected.id or nil,
   calibration_status=selected and "PROVISIONAL_OBSERVED" or "UNCALIBRATED",
   options=nearest,option_count=#options,source={x=s.ball.x,y=s.ball.y}}
end
return M
