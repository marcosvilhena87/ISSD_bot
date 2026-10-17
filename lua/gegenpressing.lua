-- Gegenpressing tactical planner for ISSD (pure logic; no joypad writes).
-- Coordinates must share the same field scale. Possession must be supplied
-- by a separately validated detector ("my", "cpu" or "loose").
local M = {}
local DEFAULT = {window=90, radius=260, max_pressers=2,
                 cover_offset=110, cooldown=30, hysteresis=20}
local function distance(a,b)
    local dx,dy=a.x-b.x,a.y-b.y
    return math.sqrt(dx*dx+dy*dy)
end
local function valid(p)
    return type(p)=="table" and type(p.x)=="number" and
        type(p.y)=="number" and p.x==p.x and p.y==p.y
end
local function copy_options(opts)
    local o={}
    for k,v in pairs(DEFAULT) do o[k]=v end
    for k,v in pairs(opts or {}) do
        if o[k]~=nil then assert(type(v)=="number" and v>=0,k.." invalid");o[k]=v end
    end
    assert(o.max_pressers>=1 and o.max_pressers%1==0,"max_pressers invalid")
    return o
end
function M.new(opts)
    local config=copy_options(opts)
    local state={previous=nil, lost_at=nil, cooldown_until=-1, last_frame=nil}
    local function reset()
        state.previous=nil;state.lost_at=nil;state.cooldown_until=-1;state.last_frame=nil
    end
    local function update(input)
        assert(type(input)=="table" and type(input.frame)=="number","frame required")
        local frame=input.frame
        if state.last_frame and frame<state.last_frame then reset() end
        state.last_frame=frame
        -- Inactive/restart/unknown ownership must not trigger false transitions.
        if input.active~=true or not valid(input.ball) or
           (input.possession~="my" and input.possession~="cpu"
            and input.possession~="loose") then
            reset()
            return {mode="INACTIVE",pressers={},reason="unvalidated_state"}
        end
        local possession=input.possession
        if state.previous=="my" and possession~="my" and
           frame>=state.cooldown_until then
            state.lost_at=frame
        end
        if possession=="my" then
            state.lost_at=nil
        end
        state.previous=possession
        if not state.lost_at then return {mode="NORMAL",pressers={}} end
        local elapsed=frame-state.lost_at
        if elapsed>config.window then
            state.lost_at=nil
            state.cooldown_until=frame+config.cooldown
            return {mode="RECOVER_SHAPE",pressers={},reason="window_expired"}
        end
        local candidates={}
        for _,p in ipairs(input.my_players or {}) do
            if valid(p) and p.id~=nil and p.is_goalkeeper~=true then
                local d=distance(p,input.ball)
                if d<=config.radius then
                    candidates[#candidates+1]={id=p.id,distance=d,x=p.x,y=p.y}
                end
            end
        end
        table.sort(candidates,function(a,b)
            if a.distance==b.distance then return tostring(a.id)<tostring(b.id) end
            return a.distance<b.distance
        end)
        local selected={}
        for i=1,math.min(config.max_pressers,#candidates) do
            local p=candidates[i]
            selected[#selected+1]={id=p.id,role=i==1 and "PRESS" or "COVER",
                target_x=input.ball.x,target_y=input.ball.y,
                distance=p.distance}
            if i>1 then
                -- Cover the lane between the ball and our goal, not the same point.
                if valid(input.own_goal) then
                    local dx=input.own_goal.x-input.ball.x
                    local dy=input.own_goal.y-input.ball.y
                    local len=math.sqrt(dx*dx+dy*dy)
                    if len>0 then
                        local step=math.min(config.cover_offset,len)
                        selected[i].target_x=input.ball.x+dx/len*step
                        selected[i].target_y=input.ball.y+dy/len*step
                    end
                end
            end
        end
        if #selected==0 then
            return {mode="RECOVER_SHAPE",pressers={},elapsed=elapsed,reason="no_near_players"}
        end
        return {mode="GEGENPRESS",pressers=selected,elapsed=elapsed,
                reason="recent_possession_loss"}
    end
    return {update=update,reset=reset,config=config}
end
return M
