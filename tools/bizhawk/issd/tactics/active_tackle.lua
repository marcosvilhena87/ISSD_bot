-- Conservative active B charge against the CPU ball carrier.
local M={}
function M.new(config,players)
    local c=config.ACTIVE_TACKLE
    local obj={cooldown=0,pending=nil}
    function obj.tick()
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
    end
    function obj.reset()
        obj.cooldown=0;obj.pending=nil
    end
    function obj.plan(defender,carrier,ball_x,ball_y)
        if obj.cooldown>0 or not players.valid_my_base(defender)
            or defender==config.MY_FIRST
            or not players.valid_cpu_base(carrier)
            or carrier==config.CPU_FIRST then return nil end
        local x,y=players.xy(defender)
        local cx,cy=players.xy(carrier)
        local d=math.sqrt((cx-x)^2+(cy-y)^2)
        local db=math.sqrt((ball_x-x)^2+(ball_y-y)^2)
        local cb=math.sqrt((ball_x-cx)^2+(ball_y-cy)^2)
        if d>c.max_distance or db>c.max_ball_distance
            or cb>c.max_carrier_ball_distance then return nil end
        return {defender=defender,carrier=carrier,distance=d,
            defender_ball_distance=db,carrier_ball_distance=cb,button=c.button}
    end
    function obj.fire(plan,movement)
        if not plan or obj.cooldown>0 then return false end
        movement.press_button(plan.button)
        obj.cooldown=c.cooldown_frames
        obj.pending={defender=plan.defender,carrier=plan.carrier,
            age=0,distance=plan.distance,
            defender_ball_distance=plan.defender_ball_distance,
            carrier_ball_distance=plan.carrier_ball_distance}
        return true
    end
    function obj.observe(possession)
        local pending=obj.pending
        if not pending then return nil end
        pending.age=pending.age+1
        local outcome=nil
        if players.valid_my_base(possession) then
            outcome="TACKLE_SUCCESS"
        elseif players.valid_cpu_base(possession)
            and possession~=pending.carrier then
            outcome="TACKLE_FAILED"
        elseif pending.age>=c.outcome_frames then
            outcome="TACKLE_UNKNOWN"
        end
        if not outcome then return nil end
        obj.pending=nil
        return {kind=outcome,defender=pending.defender,
            carrier=pending.carrier,age=pending.age,
            distance=pending.distance,holder=possession,
            defender_ball_distance=pending.defender_ball_distance,
            carrier_ball_distance=pending.carrier_ball_distance}
    end
    return obj
end
return M
