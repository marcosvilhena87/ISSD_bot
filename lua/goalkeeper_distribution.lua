-- Read-only goalkeeper distribution planner. No generic pass range assumptions.
local M={}
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
   options[#options+1]={id=p.id,distance=distance(s.ball,p),
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
 return {mode="GK_DISTRIBUTION",reason="distribution_requires_calibration",
   options=nearest,option_count=#options,source={x=s.ball.x,y=s.ball.y}}
end
return M
