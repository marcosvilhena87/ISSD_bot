-- Tiki-taka v1.13.0: hypothetical spatial support and two-pass triangles.
-- Pure geometry; suggestions do not imply movement or controller commands.
local M={}
local function distance(a,b)
 local dx,dy=a.x-b.x,a.y-b.y
 return math.sqrt(dx*dx+dy*dy)
end
local function lane(enemy,a,b)
 local dx,dy=b.x-a.x,b.y-a.y
 local q=dx*dx+dy*dy
 if q==0 then return distance(enemy,a) end
 local t=math.max(0,math.min(1,((enemy.x-a.x)*dx+(enemy.y-a.y)*dy)/q))
 return distance(enemy,{x=a.x+t*dx,y=a.y+t*dy})
end
local function clearance(enemies,a,b)
 local best=math.huge
 for _,e in ipairs(enemies) do
  if type(e.x)=="number" and type(e.y)=="number" then
   best=math.min(best,lane(e,a,b))
  end
 end
 return best
end
local function eligible(a,b,enemies,cfg)
 local d=distance(a,b)
 return d>=cfg.min_pass_distance and d<=cfg.max_pass_distance
    and clearance(enemies,a,b)>=cfg.opponent_clearance
end
local function inside(p,field)
 if not field then return true end
 return p.x>=4 and p.y>=4 and p.x<=field.length-4 and p.y<=field.width-4
end
function M.analyze(s,carrier,cfg)
 local nearest=math.huge
 local move,bestscore=nil,-math.huge
 local field=nil
 if s.field_length and s.field_width and s.field_length>8 and s.field_width>8 then
  field={length=s.field_length,width=s.field_width}
 end
 local others={}
 for _,p in ipairs(s.my_players) do
  if p.id~=carrier.id and p.id~=nil and not p.is_goalkeeper and type(p.x)=="number" and type(p.y)=="number" then
    others[#others+1]=p
    nearest=math.min(nearest,distance(carrier,p))
  end
 end
 -- Approach along the current carrier-receiver vector, with a lateral offset
 -- to escape blocked lanes; rank projected receiver positions, not commands.
 for _,p in ipairs(others) do
  local d=distance(carrier,p)
  if d>0 then
   local ux,uy=(p.x-carrier.x)/d,(p.y-carrier.y)/d
   local advance=math.max(0,d-math.min(cfg.max_pass_distance*0.75,240))
   local bx,by=p.x-ux*advance,p.y-uy*advance
   for _,side in ipairs({0,1,-1,2,-2}) do
    local offset=side*55
    local point={x=bx-uy*offset,y=by+ux*offset}
    local travel=distance(p,point)
    local gap=clearance(s.cpu_players,carrier,point)
    if travel>=25 and travel<=500 and inside(point,field) and
       eligible(carrier,point,s.cpu_players,cfg) then
      local score=math.min(gap,180)*2-travel*0.22+
        (point.x-carrier.x)*((s.opponent_goal.x-s.own_goal.x)>=0 and 1 or -1)*0.1
      if score>bestscore then
       bestscore=score
       move={id=p.id,x=point.x,y=point.y,reason="APPROACH_UNMARKED",
         clearance=gap,travel=travel,score=score}
      end
    end
   end
  end
 end
 -- A triangle requires BOTH passes safe in current positions, with three
 -- distinct players: carrier -> receiver A -> receiver B.
 local triangle,tri_score=nil,-math.huge
 for _,a in ipairs(others) do
  if eligible(carrier,a,s.cpu_players,cfg) then
   for _,b in ipairs(others) do
    if b.id~=a.id and eligible(a,b,s.cpu_players,cfg) then
     local gap=math.min(clearance(s.cpu_players,carrier,a),
                        clearance(s.cpu_players,a,b))
     local score=gap*1.5-distance(carrier,a)*0.12-distance(a,b)*0.12
     if score>tri_score then
      tri_score=score
      triangle={first_id=a.id,second_id=b.id,score=score,
         first_clearance=clearance(s.cpu_players,carrier,a),
         second_clearance=clearance(s.cpu_players,a,b)}
     end
    end
   end
  end
 end
 return {nearest_teammate_distance=nearest<math.huge and nearest or nil,
   support_move=move,triangle=triangle,triangle_score=triangle and triangle.score or nil}
end
return M
