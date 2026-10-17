-- Read-only tactical radar overlay. Projection mirrors radar.lua empirical
-- bounds; remains experimental until calibrated against native radar pixels.
local M={}
local profiles={
 [0]={1792,576},[1]={1856,640},[2]={1984,704},[3]={2048,640},
 [4]={1920,640},[5]={1920,576},[6]={1792,704},[7]={2176,704}
}
local FX,FY,FW,FH=88,161,79,54
local function pos(p,length,width)
 if type(p)~="table" or type(p.x)~="number" or type(p.y)~="number" then return nil end
 local nx=(p.x-4)/(length-8)
 local ny=(p.y-4)/(width-8)
 if nx<0 or nx>1 or ny<0 or ny>1 then return nil end
 return math.floor(FX+nx*FW+0.5),math.floor(FY+ny*FH+0.5)
end
function M.plan(s,decision,stadium,length,width)
 if not s or not decision or not s.ball or not s.my_players or not s.cpu_players then
    return nil,"state_unavailable"
 end
 local dims=profiles[stadium]
 if not dims or dims[1]~=length or dims[2]~=width then return nil,"geometry_unverified" end
 if s.active~=true or s.possession~="my" then return nil,"not_confirmed_my_possession" end
 local by_id={}
 for _,p in ipairs(s.my_players) do by_id[p.id]=p end
 local carrier=by_id[s.carrier_id]
 if not carrier then return nil,"carrier_missing" end
 local ax,ay=pos(carrier,length,width)
 if not ax then return nil,"carrier_outside" end
 local result={carrier={x=ax,y=ay},links={},players={},ball=nil}
 local bx,by=pos(s.ball,length,width)
 if bx then result.ball={x=bx,y=by} end
 for _,p in ipairs(s.my_players) do
    local x,y=pos(p,length,width)
    if x then result.players[#result.players+1]={x=x,y=y,team="my",id=p.id} end
 end
 for _,p in ipairs(s.cpu_players) do
    local x,y=pos(p,length,width)
    if x then result.players[#result.players+1]={x=x,y=y,team="cpu",id=p.id} end
 end
 local d=decision.decision or {}
 if decision.phase=="ATTACK" and type(d.candidates)=="table" then
    for i,p in ipairs(d.candidates) do
       if i>3 then break end
       local target=by_id[p.id]
       local x,y=pos(target,length,width)
       if x then result.links[#result.links+1]={x1=ax,y1=ay,x2=x,y2=y,
          id=p.id,priority=i} end
    end
 end
 return result
end
function M.draw(plan,gui_api)
 if not plan or not gui_api then return false end
 for _,p in ipairs(plan.players) do
   gui_api.drawPixel(p.x,p.y,p.team=="my" and "red" or "cyan")
 end
 if plan.ball then gui_api.drawPixel(plan.ball.x,plan.ball.y,"yellow") end
 for _,link in ipairs(plan.links) do
   local color=link.priority==1 and "lime" or "gray"
   if gui_api.drawLine then gui_api.drawLine(link.x1,link.y1,link.x2,link.y2,color) end
   if gui_api.drawText then gui_api.drawText(link.x2+2,link.y2-6,tostring(link.id),color) end
 end
 if gui_api.drawBox then gui_api.drawBox(plan.carrier.x-2,plan.carrier.y-2,
       plan.carrier.x+2,plan.carrier.y+2,"white") end
 return true
end
return M
