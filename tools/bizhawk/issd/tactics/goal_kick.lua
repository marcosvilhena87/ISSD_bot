-- GS=1 goalkeeper restart. Ball motion alone does NOT mean the restart ended.
local M={}
function M.new(config,players,field_side)
    local c=config.GOAL_KICK
    local obj={frames=0,attempts=0,cooldown=0,kick_x=nil,kick_y=nil,
        moved_age=0,moved=false,last_displacement=0}
    function obj.reset()
        obj.frames=0;obj.attempts=0;obj.cooldown=0
        obj.kick_x=nil;obj.kick_y=nil;obj.moved_age=0
        obj.moved=false;obj.last_displacement=0
    end
    function obj.plan(taker,team,bx,by,controlled)
        if team~="MY" or taker~=config.MY_FIRST then return nil end
        obj.frames=obj.frames+1
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
        local dir=field_side.attack_direction()
        if dir==0 then return {mode="WAIT_SIDE",taker=taker,elapsed=obj.frames} end
        local displacement=0
        if obj.kick_x~=nil then
            displacement=math.sqrt((bx-obj.kick_x)^2+(by-obj.kick_y)^2)
            if displacement>=c.ball_move_threshold then obj.moved=true end
        end
        if obj.moved then obj.moved_age=obj.moved_age+1 end
        local attempt=math.min(obj.attempts+1,#c.buttons)
        local button=c.buttons[attempt]
        local direction=c.directions[attempt]=="FORWARD"
            and (dir==1 and "Right" or "Left") or nil
        local plan={taker=taker,button=button,direction=direction,
            displacement=displacement,controlled=controlled,
            attempts=obj.attempts,elapsed=obj.frames,cooldown=obj.cooldown,
            moved_age=obj.moved_age}
        if obj.frames<c.initial_delay_frames then plan.mode="STABILIZING"
        elseif obj.attempts>=c.max_attempts then plan.mode="EXHAUSTED"
        elseif obj.cooldown>0 then plan.mode=obj.moved and "WAIT_PLAY_RESUME" or "COOLDOWN"
        else plan.mode=obj.moved and "RETRY_STILL_RESTART" or "READY" end
        return plan
    end
    function obj.fire(plan,movement)
        if not plan or (plan.mode~="READY" and plan.mode~="RETRY_STILL_RESTART") then
            return false
        end
        -- Avoid moving the keeper while he takes the goal kick.
        movement.press_direction_button(plan.direction,plan.button)
        obj.attempts=obj.attempts+1
        obj.cooldown=c.retry_frames
        obj.moved=false;obj.moved_age=0
        return true
    end
    function obj.remember_ball(bx,by)
        obj.kick_x,obj.kick_y=bx,by
    end
    return obj
end
return M
