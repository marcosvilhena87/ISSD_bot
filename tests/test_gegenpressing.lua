-- Run from repository root: lua tests/test_gegenpressing.lua
package.path="./lua/?.lua;"..package.path
local gp=require("gegenpressing")
local function step(b,frame,owner,players,extra)
    local s={frame=frame,possession=owner,active=true,ball={x=100,y=100},
             my_players=players or {{id=1,x=105,y=100},{id=2,x=150,y=100},
                                    {id=3,x=1000,y=100}},own_goal={x=0,y=100}}
    for k,v in pairs(extra or {}) do s[k]=v end
    return b.update(s)
end
local bot=gp.new({window=10,radius=100,max_pressers=2,cooldown=5})
assert(step(bot,1,"my").mode=="NORMAL")
local press=step(bot,2,"cpu")
assert(press.mode=="GEGENPRESS" and #press.pressers==2)
assert(press.pressers[1].id==1 and press.pressers[1].role=="PRESS")
assert(press.pressers[2].id==2 and press.pressers[2].role=="COVER")
assert(press.pressers[2].target_x<100)
assert(step(bot,12,"cpu").mode=="GEGENPRESS")
assert(step(bot,13,"cpu").mode=="RECOVER_SHAPE")
assert(step(bot,14,"cpu").mode=="NORMAL")
assert(step(bot,15,"my").mode=="NORMAL")
assert(step(bot,16,"cpu").mode=="NORMAL") -- cooldown
assert(step(bot,19,"my").mode=="NORMAL")
assert(step(bot,20,"loose").mode=="GEGENPRESS")
assert(step(bot,21,"cpu",nil,{active=false}).mode=="INACTIVE")
assert(step(bot,22,"cpu").mode=="NORMAL") -- cannot infer loss
assert(step(bot,1,"cpu").mode=="NORMAL") -- timeline reset
assert(step(bot,2,"my").mode=="NORMAL")
assert(step(bot,3,"cpu",{{id=1,x=999,y=999}}).mode=="RECOVER_SHAPE")
print("gegenpressing tests passed")
