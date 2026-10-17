-- Tiki-taka planner for ISSD. Pure tactics: never writes joypad inputs.
-- Requires independently validated possession, carrier, field coordinates.
local M={}
local DEFAULT={max_pass_distance=320,min_pass_distance=35,opponent_clearance=65,
    progress_weight=0.35,open_weight=2.0,distance_weight=0.18,
    repeat_penalty=45,pass_cooldown=8,support_radius=420}
local function finite(x) return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge end
local function valid(p) return type(p)=="table" and finite(p.x) and finite(p.y) end
local function dist(a,b)
    local x,y=a.x-b.x,a.y-b.y
    return math.sqrt(x*x+y*y)
end
local function segment_distance(p,a,b)
    local dx,dy=b.x-a.x,b.y-a.y
    local denom=dx*dx+dy*dy
    if denom==0 then return dist(p,a) end
    local t=((p.x-a.x)*dx+(p.y-a.y)*dy)/denom
    t=math.max(0,math.min(1,t))
    local x,y=a.x+t*dx,a.y+t*dy
    return dist(p,{x=x,y=y})
end
local function options(cfg)
    local c={}
    for k,v in pairs(DEFAULT) do c[k]=v end
    for k,v in pairs(cfg or {}) do
        assert(c[k]~=nil,"unknown option: "..tostring(k))
        assert(finite(v) and v>=0,"invalid option: "..k)
        c[k]=v
    end
    assert(c.max_pass_distance>c.min_pass_distance,"invalid pass distances")
    return c
end
function M.new(config)
    local cfg=options(config)
    local last_target,last_pass_frame,last_frame=nil,-math.huge,nil
    local function reset() last_target=nil;last_pass_frame=-math.huge;last_frame=nil end
    local function update(s)
        assert(type(s)=="table" and finite(s.frame),"frame required")
        if last_frame and s.frame<last_frame then reset() end
        last_frame=s.frame
        if s.active~=true or s.possession~="my" or
           not valid(s.ball) or not valid(s.own_goal) or
           not valid(s.opponent_goal) or type(s.my_players)~="table" or
           type(s.cpu_players)~="table" or s.carrier_id==nil then
            reset()
            return {mode="INACTIVE",reason="unvalidated_state",candidates={},support={}}
        end
        local carrier
        for _,p in ipairs(s.my_players) do
            if p.id==s.carrier_id and valid(p) then carrier=p;break end
        end
        if not carrier then
            return {mode="HOLD",reason="carrier_missing",candidates={},support={}}
        end
        local axis_x=s.opponent_goal.x-s.own_goal.x
        local axis_y=s.opponent_goal.y-s.own_goal.y
        local axis_len=math.sqrt(axis_x*axis_x+axis_y*axis_y)
        if axis_len==0 then return {mode="HOLD",reason="invalid_goal_axis",candidates={},support={}} end
        local ux,uy=axis_x/axis_len,axis_y/axis_len
        local candidates,support,evaluations={},{},{}
        for _,p in ipairs(s.my_players) do
            if p.id~=nil and p.id~=s.carrier_id and valid(p) and not p.is_goalkeeper then
                local d=dist(carrier,p)
                if d<=cfg.support_radius then
                    support[#support+1]={id=p.id,distance=d,role="SUPPORT"}
                end
                local clearance=math.huge
                for _,enemy in ipairs(s.cpu_players) do
                    if valid(enemy) then
                        clearance=math.min(clearance,segment_distance(enemy,carrier,p))
                    end
                end
                local progression=(p.x-carrier.x)*ux+(p.y-carrier.y)*uy
                local score=math.min(clearance,180)*cfg.open_weight+
                    progression*cfg.progress_weight-d*cfg.distance_weight
                if last_target==p.id then score=score-cfg.repeat_penalty end
                local reason="SAFE"
                if d<cfg.min_pass_distance then reason="TOO_CLOSE"
                elseif d>cfg.max_pass_distance then reason="TOO_FAR"
                elseif clearance<cfg.opponent_clearance then reason="BLOCKED" end
                local item={id=p.id,distance=d,clearance=clearance,
                    progression=progression,score=score,reason=reason}
                evaluations[#evaluations+1]=item
                if reason=="SAFE" then candidates[#candidates+1]=item end
            end
        end
        local function order(a,b)
            if a.score==b.score then return tostring(a.id)<tostring(b.id) end
            return a.score>b.score
        end
        table.sort(candidates,order)
        table.sort(evaluations,order)
        table.sort(support,function(a,b)
            if a.distance==b.distance then return tostring(a.id)<tostring(b.id) end
            return a.distance<b.distance
        end)
        local counts={SAFE=0,TOO_CLOSE=0,TOO_FAR=0,BLOCKED=0}
        local best_rejected=nil
        for _,e in ipairs(evaluations) do
            counts[e.reason]=counts[e.reason]+1
            if e.reason~="SAFE" and not best_rejected then best_rejected=e end
        end
        -- Experimental supporting move: lateral offset from the best rejected
        -- receiver. Never interpreted as a player-control instruction.
        local support_move=nil
        if best_rejected then
            local receiver
            for _,p in ipairs(s.my_players) do
                if p.id==best_rejected.id then receiver=p;break end
            end
            if receiver then
                local side=(receiver.y<=carrier.y) and 1 or -1
                local proposed={x=receiver.x,y=receiver.y+side*80}
                local safety=math.huge
                for _,enemy in ipairs(s.cpu_players) do
                    if valid(enemy) then
                        safety=math.min(safety,segment_distance(enemy,carrier,proposed))
                    end
                end
                if safety>best_rejected.clearance and dist(carrier,proposed)<=cfg.max_pass_distance then
                    support_move={id=receiver.id,x=proposed.x,y=proposed.y,
                        clearance=safety,reason="IMPROVE_PASS_LANE"}
                end
            end
        end
        local diagnostics={evaluations=evaluations,counts=counts,
            best_rejected=best_rejected,support_move=support_move}
        if s.frame-last_pass_frame<cfg.pass_cooldown then
            return {mode="HOLD",reason="pass_cooldown",candidates=candidates,support=support,diagnostics=diagnostics}
        end
        if #candidates==0 then
            return {mode="HOLD",reason="no_safe_pass",candidates={},support=support,diagnostics=diagnostics}
        end
        return {mode="PASS",target_id=candidates[1].id,
            reason="safe_short_pass",candidates=candidates,support=support,diagnostics=diagnostics}
    end
    -- Call only after the controller has verified an actual pass initiation.
    local function confirm_pass(target_id,frame)
        assert(target_id~=nil and finite(frame),"confirmed pass requires target and frame")
        last_target=target_id;last_pass_frame=frame
    end
    return {update=update,confirm_pass=confirm_pass,reset=reset,config=cfg}
end
return M
