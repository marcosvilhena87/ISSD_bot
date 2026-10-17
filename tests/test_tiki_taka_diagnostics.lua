package.path="./lua/?.lua;"..package.path
local T=require("tiki_taka")
local R=require("tactical_radar")
local planner=T.new()
local s={frame=1,active=true,possession="my",carrier_id=2,
 ball={x=400,y=240},own_goal={x=80,y=288},opponent_goal={x=1750,y=288},
 my_players={{id=1,x=80,y=288,is_goalkeeper=true},{id=2,x=400,y=240},
   {id=3,x=600,y=240},{id=4,x=900,y=250},{id=5,x=420,y=240}},
 cpu_players={{id=1,x=1750,y=288},{id=2,x=510,y=240}}}
local d=planner.update(s)
local diag=d.diagnostics
assert(diag and #diag.evaluations==3,"missing evaluations")
assert(diag.counts.BLOCKED==1,"blocked lane expected")
assert(diag.counts.TOO_FAR==1,"far receiver expected")
assert(diag.counts.TOO_CLOSE==1,"close receiver expected")
assert(diag.best_rejected and diag.best_rejected.reason,"best rejected expected")
local view=R.plan(s,{phase="ATTACK",decision=d},5,1920,576)
assert(view and view.rejected,"radar should expose rejected lane")
local calls=0
local gui={drawPixel=function() calls=calls+1 end,
 drawLine=function() calls=calls+1 end,
 drawBox=function() calls=calls+1 end,
 drawText=function() calls=calls+1 end}
assert(R.draw(view,gui) and calls>0)
print("tiki-taka diagnostic tests passed")
