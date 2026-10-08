-- Experimental attacking free-kick in GS=3.
-- GS=3 may include foul animations; require a stable nearby Brazilian taker.
local M={}
function M.new(config,players,field_side)
    local c=config.FREE_KICK
    local obj={candidate=nil,stable=0,age=0,attempts=0,cooldown=0}
    local function distance(ax,ay,bx,by)
        return math.sqrt((ax-bx)^2+(ay-by)^2)
    end
    function obj.reset()
        obj.candidate=nil;obj.stable=0;obj.age=0
        obj.attempts=0;obj.cooldown=0
    end
    function obj.plan(bx,by)
        obj.age=obj.age+1
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
        local my,md=nil,math.huge
        players.each_my(function(base)
            if base~=config.MY_FIRST then
                local x,y=players.xy(base)
                local d=distance(x,y,bx,by)
                if d<md then my,md=base,d end
            end
        end)
        local cd=math.huge
        players.each_cpu(function(base)
            local x,y=players.xy(base)
            cd=math.min(cd,distance(x,y,bx,by))
        end)
        local dir=field_side.attack_direction()
        if not my or dir==0 or md>c.max_taker_distance or
            md+c.team_margin>=cd then
            obj.candidate=nil;obj.stable=0
            return {mode="WAIT_TAKER",nearest_my=my,my_distance=md,cpu_distance=cd}
        end
        if obj.candidate~=my then
            obj.candidate=my;obj.stable=0
        end
        obj.stable=obj.stable+1
        if obj.stable<c.stable_frames then
            return {mode="WAIT_STABLE",taker=my,stable=obj.stable,
                my_distance=md,cpu_distance=cd}
        end
        local gx,gy=players.xy(config.CPU_FIRST)
        local mode="PASS"
        local button=c.pass_button
        if distance(bx,by,gx,gy)<=c.shot_max_distance and
            (gx-bx)*dir>0 then
            mode="SHOT";button=c.shot_button
        end
        if obj.attempts>0 then mode="RETRY_LONG";button=c.long_button end
        return {mode=mode,taker=my,button=button,
            direction=dir==1 and "Right" or "Left",
            my_distance=md,cpu_distance=cd,stable=obj.stable,
            attempts=obj.attempts}
    end
    function obj.fire(plan,movement)
        if not plan or (plan.mode~="PASS" and plan.mode~="SHOT"
            and plan.mode~="RETRY_LONG") then return false end
        if obj.cooldown>0 or obj.attempts>=c.max_attempts then return false end
        movement.press_direction_button(plan.direction,plan.button)
        obj.attempts=obj.attempts+1
        obj.cooldown=c.retry_frames
        return true
    end
    return obj
end
return M
