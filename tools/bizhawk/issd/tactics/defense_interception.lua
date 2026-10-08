-- Select reachable points on the ball path and stabilize emergency mode.
-- Speed is estimated until player motion can be measured in WRAM.
local M = {}
function M.new(config, players)
    local c=config.INTERCEPTION
    local obj={danger_active=false, release=0, lock=0, locked_base=nil}
    local function distance(x,y,a,b)
        local dx=x-a; local dy=y-b
        return math.sqrt(dx*dx+dy*dy)
    end
    function obj.reset()
        obj.danger_active=false
        obj.release=0
        obj.lock=0
        obj.locked_base=nil
    end
    function obj.tick()
        if obj.lock>0 then obj.lock=obj.lock-1 end
    end
    function obj.choose(my_base,bx,by,vx,vy,danger,fallback)
        if danger then
            obj.danger_active=true
            obj.release=c.danger_release_frames
        elseif obj.danger_active then
            obj.release=obj.release-1
            if obj.release<=0 then obj.reset() end
        end
        if not obj.danger_active then return fallback,nil end
        -- Continue from the last reasonable lead for brief danger dropouts.
        local budget=danger and danger.frames_to_goal or c.danger_max_frames
        local speed=c.estimated_defender_speed
        local best=nil
        local n=math.max(1, math.floor(math.min(budget,c.danger_max_frames)))
        for t=3,n,3 do
            local tx,ty=bx+vx*t,by+vy*t
            local player=nil
            local arrival=math.huge
            players.each_my(function(base)
                if base~=config.MY_FIRST then
                    local x,y=players.xy(base)
                    local eta=distance(x,y,tx,ty)/speed
                    if eta<arrival then arrival=eta; player=base end
                end
            end)
            local slack=t-arrival
            -- Prefer earliest reachable point; otherwise the least late point.
            local score=(slack>=c.feasibility_margin_frames and 1000-t or slack)
            if not best or score>best.score then
                best={x=math.floor(tx+0.5),y=math.floor(ty+0.5),
                    lead_frames=t,best_base=player,eta=arrival,
                    slack=slack,reachable=slack>=c.feasibility_margin_frames,
                    score=score}
            end
        end
        if not best then return fallback,nil end
        -- Lock only the preferred defender identity, not a stale coordinate.
        if obj.locked_base and obj.lock>0 then
            best.preferred_base=obj.locked_base
        else
            obj.locked_base=best.best_base
            obj.lock=c.danger_lock_frames
            best.preferred_base=best.best_base
        end
        best.danger=true
        best.frames_to_goal=budget
        best.predictive=true
        best.lead_x=best.x-bx
        best.lead_y=best.y-by
        return best,best
    end
    return obj
end
return M
