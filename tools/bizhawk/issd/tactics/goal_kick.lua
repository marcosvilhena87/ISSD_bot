-- GS=1: goalkeeper approaches the restart ball before attempting a goal kick.
local M={}
function M.new(config,players,field_side)
    local c=config.GOAL_KICK
    local obj={frames=0,attempts=0,cooldown=0,kick_x=nil,kick_y=nil,ball_moved=false}
    function obj.reset()
        obj.frames=0;obj.attempts=0;obj.cooldown=0
        obj.kick_x=nil;obj.kick_y=nil;obj.ball_moved=false
    end
    function obj.plan(taker,team,bx,by,controlled)
        if team~="MY" or taker~=config.MY_FIRST then return nil end
        obj.frames=obj.frames+1
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
        local dir=field_side.attack_direction()
        if dir==0 then return {mode="WAIT_SIDE",taker=taker,elapsed=obj.frames} end
        local gx,gy=players.xy(taker)
        local dx,dy=bx-gx,by-gy
        local distance=math.sqrt(dx*dx+dy*dy)
        local displacement=0
        if obj.kick_x~=nil then
            displacement=math.sqrt((bx-obj.kick_x)^2+(by-obj.kick_y)^2)
            if displacement>=c.ball_move_threshold then obj.ball_moved=true end
        end
        local plan={taker=taker,button=c.button,
            direction=dir==1 and "Right" or "Left",
            distance=distance,dx=dx,dy=dy,displacement=displacement,
            controlled=controlled,attempts=obj.attempts,elapsed=obj.frames,
            cooldown=obj.cooldown}
        if obj.ball_moved then plan.mode="BALL_MOVED"
        elseif controlled~=taker then plan.mode="WAIT_CONTROL"
        elseif distance>c.kick_distance then plan.mode="APPROACH"
        elseif obj.frames<c.initial_delay_frames then plan.mode="STABILIZING"
        elseif obj.attempts>=c.max_attempts then plan.mode="EXHAUSTED"
        elseif obj.cooldown>0 then plan.mode="COOLDOWN"
        else plan.mode="READY" end
        return plan
    end
    function obj.fire(plan,movement)
        if not plan or plan.mode~="READY" then return false end
        movement.press_direction_button(plan.direction,plan.button)
        obj.attempts=obj.attempts+1
        obj.cooldown=c.retry_frames
        return true
    end
    function obj.remember_ball(bx,by)
        obj.kick_x,obj.kick_y=bx,by
    end
    return obj
end
return M
