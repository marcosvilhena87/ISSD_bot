package.path="./lua/?.lua;"..package.path
local Sequential=require("sequential_tiki_taka")
local p=Sequential.new()
local function state(frame,owner,carrier)
 return {frame=frame,active=true,possession=owner,carrier_id=carrier,
  raw_owner=owner=="my" and 0x0600 or 0x1100,
  field_length=1920,field_width=576,
  ball={x=400,y=200},own_goal={x=30,y=288},opponent_goal={x=1800,y=288},
  my_players={{id=1,x=30,y=288,is_goalkeeper=true},
   {id=2,x=400,y=200},{id=3,x=900,y=200},{id=4,x=1200,y=200}},
  cpu_players={{id=1,x=1750,y=288},{id=2,x=1500,y=100}}}
end
local d=p.update(state(1,"my",2))
assert(d.mode=="DRIBBLE" and d.dribble and d.dribble.open_passes==0)
local near=state(2,"my",2);near.my_players[3].x=600
local pass=p.update(near)
assert(pass.mode=="PASS_READY" and pass.target_id==3)
assert(p.confirm_pass(3,2))
local flight=state(3,"my",nil);flight.active=false;flight.raw_owner=0
assert(p.update(flight).mode=="WAIT_RECEIVE")
assert(p.update(state(4,"my",3)).mode=="REPLAN")
local next=p.update(state(5,"my",3))
assert(next.mode=="PASS_READY" or next.mode=="DRIBBLE" or next.mode=="HOLD")
print("sequential tiki-taka tests passed")
