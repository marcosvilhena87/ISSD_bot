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
-- Calibrated against a single observed GK-to-4 association, not a proven
-- direction command. Only allow the geometrically similar ID 4 proposal.
local sample={active=true,possession="my",ownership_source="PLAYER_BALL_POSSESSION",
 carrier_id=1,ball={x=28,y=347},
 my_players={{id=1,x=20,y=347,is_goalkeeper=true},{id=4,x=371,y=386},
 {id=3,x=375,y=260},{id=5,x=440,y=505}},
 cpu_players={}}
local matched=assert(GK.plan(sample))
assert(matched.target_id==4)
assert(matched.reason=="provisional_gk4_geometry_match")
assert(matched.options[1].status=="PROVISIONAL_OBSERVED")
sample.my_players[2].y=440
local shifted=assert(GK.plan(sample))
assert(shifted.target_id==nil)
sample.my_players[2].y=386
sample.cpu_players={{id=99,x=180,y=365}}
local blocked=assert(GK.plan(sample))
assert(blocked.target_id==nil)
sample.cpu_players={}
sample.my_players[2].id=6
local wrong_id=assert(GK.plan(sample))
assert(wrong_id.target_id==nil)
-- GK5: reproduce the measured 6381 geometry from the CSV.
local s5={active=true,possession="my",ownership_source="PLAYER_BALL_POSSESSION",
 carrier_id=1,ball={x=25,y=349},
 my_players={{id=1,x=20,y=349,is_goalkeeper=true},
 {id=4,x=371,y=386},{id=3,x=372,y=259},{id=5,x=435,y=497}},
 cpu_players={}}
local p5=assert(GK.plan(s5))
assert(p5.target_id==5 and p5.reason=="provisional_gk5_geometry_match")
assert(p5.calibration_status=="PROVISIONAL_OBSERVED")
assert(p5.options[3].id==5 and p5.options[3].status=="PROVISIONAL_OBSERVED")
s5.my_players[4].x=520
assert(GK.plan(s5).target_id==4) -- existing GK4 profile preserved
s5.my_players[4].x=435
s5.cpu_players={{id=99,x=210,y=415}}
assert(GK.plan(s5).target_id~=5) -- blocked GK5 corridor
s5.cpu_players={}
s5.my_players[4].id=6
assert(GK.plan(s5).target_id~=5)
print("goalkeeper distribution tests passed")
