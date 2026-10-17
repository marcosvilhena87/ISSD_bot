package.path="./lua/?.lua;"..package.path
local radar=require("tactical_radar")
local s={active=true,possession="my",carrier_id=2,ball={x=800,y=200},
 my_players={{id=2,x=800,y=200},{id=3,x=900,y=240}},
 cpu_players={{id=1,x=1100,y=300}}}
local d={phase="ATTACK",decision={candidates={{id=3,score=12}}}}
local p,reason=radar.plan(s,d,5,1920,576)
assert(p and #p.links==1 and p.links[1].id==3)
assert(radar.plan(s,d,5,1920,640)==nil)
s.possession="cpu"
assert(radar.plan(s,d,5,1920,576)==nil)
s.possession="my"
local calls=0
local api={drawPixel=function() calls=calls+1 end,
 drawLine=function() calls=calls+1 end,
 drawText=function() calls=calls+1 end,
 drawBox=function() calls=calls+1 end}
assert(radar.draw(p,api) and calls>0)
print("tactical radar tests passed")
