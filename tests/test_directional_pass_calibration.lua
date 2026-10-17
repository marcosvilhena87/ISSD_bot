package.path="./lua/?.lua;"..package.path
local Direction=require("directional_pass_calibration")
local tests={
 {{x=0,y=0},{x=100,y=0},"Right+B"},
 {{x=0,y=0},{x=-100,y=0},"Left+B"},
 {{x=0,y=0},{x=0,y=-100},"Up+B"},
 {{x=0,y=0},{x=0,y=100},"Down+B"},
 {{x=0,y=0},{x=100,y=-100},"Up+Right+B"},
 {{x=0,y=0},{x=-100,y=-100},"Up+Left+B"},
 {{x=0,y=0},{x=100,y=100},"Down+Right+B"},
 {{x=0,y=0},{x=-100,y=100},"Down+Left+B"}
}
for _,t in ipairs(tests) do
 assert(Direction.direction(t[1],t[2]).command==t[3])
end
assert(Direction.direction({x=3,y=4},{x=3,y=4})==nil)
for _,case in ipairs(tests) do
 local direction=Direction.direction(case[1],case[2]).direction
 local simultaneous=assert(Direction.input_sequence(direction,0,false))
 assert(#simultaneous.steps==1 and simultaneous.steps[1].buttons==case[3])
 local sequential=assert(Direction.input_sequence(direction,3,false))
 assert(#sequential.steps==2 and sequential.steps[1].buttons==direction)
 assert(sequential.steps[1].frames==3)
 assert(sequential.steps[2].buttons==case[3] and sequential.read_only)
 local released=assert(Direction.input_sequence(direction,2,true))
 assert(#released.steps==3 and released.steps[2].phase=="RELEASE")
 assert(released.steps[3].buttons=="B" and released.status=="UNVERIFIED")
end
assert(Direction.input_sequence("Center",1,false)==nil)
assert(Direction.input_sequence("Right",-1,false)==nil)
assert(Direction.input_sequence("Right",1.5,false)==nil)
assert(Direction.input_sequence("Right",0,true)==nil)

local GK=require("goalkeeper_distribution")
local plan=assert(GK.plan({active=true,possession="my",ownership_source="PLAYER_BALL_POSSESSION",
 carrier_id=1,ball={x=100,y=200},
 my_players={{id=1,x=100,y=200,is_goalkeeper=true},{id=2,x=500,y=200},{id=3,x=450,y=150},{id=4,x=450,y=250}},
 cpu_players={}}))
assert(plan.options[1].command~=nil)
for _,p in ipairs(plan.options) do
 assert(p.status=="UNCALIBRATED")
 assert(p.input_sequence.read_only and p.input_sequence.steps[1].phase=="AIM")
end
print("directional pass calibration tests passed")
