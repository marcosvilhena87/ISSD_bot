package.path="./lua/?.lua;"..package.path
local GK=require("goalkeeper_distribution")
local s={active=true,possession="my",ownership_source="PLAYER_BALL_POSSESSION",
 carrier_id=1,ball={x=100,y=280},
 my_players={{id=1,x=88,y=280,is_goalkeeper=true},{id=4,x=440,y=280},
 {id=3,x=460,y=290},{id=5,x=530,y=310},{id=6,x=900,y=360}},
 cpu_players={{id=2,x=360,y=280},{id=3,x=800,y=300}}}
local p=assert(GK.plan(s))
assert(p.mode=="GK_DISTRIBUTION" and #p.options==3)
assert(p.options[1].id==4 and p.options[2].id==3 and p.options[3].id==5)
assert(p.options[1].distance>320)
assert(p.options[1].status=="UNCALIBRATED")
s.carrier_id=4
assert(GK.plan(s)==nil)
s.carrier_id=1;s.ownership_source="LOGICAL_UNVERIFIED"
assert(GK.plan(s)==nil)
print("goalkeeper distribution tests passed")
