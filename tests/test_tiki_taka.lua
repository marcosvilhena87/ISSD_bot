package.path="./lua/?.lua;"..package.path
local tiki=require("tiki_taka")
local bot=tiki.new({max_pass_distance=250,opponent_clearance=25,pass_cooldown=5})
local function state(frame)
    return {frame=frame,active=true,possession="my",carrier_id=1,
      ball={x=100,y=100},own_goal={x=0,y=100},opponent_goal={x=1000,y=100},
      my_players={{id=1,x=100,y=100},{id=2,x=200,y=100},
                  {id=3,x=100,y=230},{id=4,x=700,y=100}},
      cpu_players={{id=8,x=150,y=100}}}
end
local s=state(1)
local r=bot.update(s)
assert(r.mode=="PASS" and r.target_id==3,"must avoid intercepted lane")
assert(#r.support>=2)
bot.confirm_pass(3,1)
assert(bot.update(state(3)).reason=="pass_cooldown")
local next=bot.update(state(6))
assert(next.mode=="PASS" and next.target_id==3)
local blocked=state(7)
blocked.cpu_players={{id=8,x=150,y=100},{id=9,x=100,y=160}}
assert(bot.update(blocked).reason=="no_safe_pass")
local bad=state(8);bad.possession="cpu"
assert(bot.update(bad).mode=="INACTIVE")
assert(bot.update(state(9)).mode=="PASS")
local reset=state(1)
assert(bot.update(reset).mode=="PASS")
local missing=state(10);missing.carrier_id=99
assert(bot.update(missing).reason=="carrier_missing")
local invalid=state(11);invalid.opponent_goal={x=0,y=100}
assert(bot.update(invalid).reason=="invalid_goal_axis")
print("tiki-taka tests passed")
