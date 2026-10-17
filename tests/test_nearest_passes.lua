package.path="./lua/?.lua;"..package.path
local T=require("tiki_taka")
local t=T.new()
local s={frame=1,active=true,possession="my",carrier_id=2,ball={x=490,y=200},
 own_goal={x=0,y=200},opponent_goal={x=1800,y=200},
 my_players={{id=1,x=0,y=200,is_goalkeeper=true},{id=2,x=500,y=200},
 {id=3,x=650,y=200},{id=4,x=700,y=280},{id=5,x=1100,y=220}},
 cpu_players={{id=7,x=570,y=200},{id=8,x=1300,y=200}}}
local d=t.update(s)
local nearest=assert(d.diagnostics.nearest)
assert(#nearest==3)
assert(nearest[1].id==3 and nearest[2].id==4 and nearest[3].id==5)
assert(nearest[1].distance<nearest[1].ball_distance)
assert(nearest[1].blocking_enemy_id==7)
assert(nearest[1].reason=="BLOCKED")
assert(nearest[3].reason=="TOO_FAR")
print("nearest teammate diagnostics passed")
