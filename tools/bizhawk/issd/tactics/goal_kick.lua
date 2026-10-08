-- GS=1 goal kick, only when our goalkeeper is the confirmed taker.
local M={}
function M.new(config,players,field_side)
    local c=config.GOAL_KICK
    local obj={frames=0,attempts=0,cooldown=0}
    function obj.reset()
        obj.frames=0;obj.attempts=0;obj.cooldown=0
    end
    function obj.plan(taker,team)
        if team~="MY" or taker~=config.MY_FIRST then return nil end
        obj.frames=obj.frames+1
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
        local dir=field_side.attack_direction()
        if dir==0 then return {mode="WAIT_SIDE",taker=taker} end
        local gx,gy=players.xy(taker)
        local nearest=nil
        players.each_cpu(function(base)
            local x,y=players.xy(base)
            local dx,dy=x-gx,y-gy
            local distance=math.sqrt(dx*dx+dy*dy)
            if not nearest or distance<nearest then nearest=distance end
        end)
        local direction=dir==1 and "Right" or "Left"
        return {mode="READY",taker=taker,button=c.button,
            direction=direction,nearest_opponent=nearest,
            attempts=obj.attempts,elapsed=obj.frames}
    end
    function obj.fire(plan,movement)
        if not plan or plan.mode~="READY"
            or obj.attempts>=c.max_attempts or obj.cooldown>0
            or obj.frames<c.initial_delay_frames then return false end
        movement.press_direction_button(plan.direction,plan.button)
        obj.attempts=obj.attempts+1
        obj.cooldown=c.retry_frames
        return true
    end
    return obj
end
return M
