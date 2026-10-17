package.path="./lua/?.lua;"..package.path
local T=require("tiki_taka")
local function state(enemy_y)
 return {frame=1,active=true,possession="my",carrier_id=2,
 ball={x=500,y=250},own_goal={x=100,y=250},opponent_goal={x=1700,y=250},
 my_players={{id=1,x=100,y=250,is_goalkeeper=true},{id=2,x=500,y=250},
 {id=3,x=700,y=250},{id=4,x=490,y=450},{id=5,x=350,y=250}},
 cpu_players={{id=1,x=1600,y=350},{id=2,x=650,y=enemy_y}}}
end
local planner=T.new({opponent_clearance=20,safety_override_margin=45})
local a=planner.update(state(400))
assert(a.mode=="PASS" and a.pass_type=="PROGRESSIVE" and a.target_id==3)
planner.reset()
local s=state(270)
local b=planner.update(s)
assert(b.mode=="PASS" and (b.pass_type=="LATERAL" or b.pass_type=="BACKWARD"))
assert(b.pass_clearance>=20)
print("pass priority tests passed")
