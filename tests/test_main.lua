-- Run from repository root: lua tests/test_main.lua
local Main=dofile("main.lua")
local bot=Main.new({gegenpressing={window=10,radius=200}})
local function state(frame,owner)
    return {frame=frame,active=true,possession=owner,carrier_id=1,
      ball={x=100,y=100},own_goal={x=0,y=100},opponent_goal={x=1000,y=100},
      my_players={{id=1,x=105,y=100},{id=2,x=200,y=180}},
      cpu_players={{id=5,x=450,y=400}}}
end
assert(bot.update(state(1,"my")).mode=="TIKI_TAKA")
local lost=bot.update(state(2,"cpu"))
assert(lost.mode=="GEGENPRESS" and lost.phase=="TRANSITION")
assert(#lost.decision.pressers>0)
assert(bot.update(state(3,"my")).phase=="ATTACK")
assert(bot.update(state(4,"cpu")).mode=="GEGENPRESS")
assert(bot.update(state(15,"cpu")).mode=="RECOVER_SHAPE")
assert(bot.update(state(16,"cpu")).mode=="DEFEND")
local bad=state(17,"my");bad.carrier_id=nil
assert(bot.update(bad).mode=="INACTIVE")
assert(bot.update(state(18,"cpu")).mode=="DEFEND")
assert(bot.update({frame=19}).mode=="INACTIVE")
assert(bot.update(state(20,"my")).phase=="ATTACK")
assert(bot.update(state(1,"cpu")).mode=="DEFEND")
bot.reset()
assert(bot.update(state(2,"cpu")).mode=="DEFEND")
print("main coordinator tests passed")
