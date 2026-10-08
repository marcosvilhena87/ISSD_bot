-- Offensive throw-in: restart.taker throws; MyCtrl moves as receiver.
local M = {}
function M.new(config, players, field_side)
    local c = config.THROW_IN or {}
    local defaults = {
        throw_button="B", long_throw_button="A",
        min_distance=24, max_distance=280, min_clearance=40,
        clearance_weight=1, forward_weight=0.25, distance_weight=0.35,
        retry_frames=45, switch_margin=80, switch_cooldown=45,
        target_lock_frames=20, target_tolerance=16,
        max_attempts=2, long_fallback_frames=180,
        recovery_switch_interval=30, max_recovery_switches=3
    }
    for key, value in pairs(defaults) do
        if c[key] == nil then c[key] = value end
    end
    local obj = {taker=nil, frames=0, switch_cd=0, throw_cd=0,
        attempts=0, target_x=nil, target_y=nil, lock=0,
        recovery_switches=0, last_receiver=nil}
    local function dist(x,y,a,b)
        local dx,dy=x-a,y-b
        return math.sqrt(dx*dx+dy*dy)
    end
    local function clearance(x,y)
        local best=99999
        players.each_cpu(function(base)
            local ex,ey=players.xy(base)
            local d=dist(x,y,ex,ey)
            if d<best then best=d end
        end)
        return best
    end
    function obj.reset()
        obj.taker=nil; obj.frames=0; obj.switch_cd=0
        obj.throw_cd=0; obj.attempts=0
        obj.target_x=nil; obj.target_y=nil; obj.lock=0
        obj.recovery_switches=0; obj.last_receiver=nil
    end
    function obj.plan(taker, receiver)
        if not players.valid_my_base(taker) then return nil end
        if obj.taker~=taker then obj.reset(); obj.taker=taker end
        obj.frames=obj.frames+1
        obj.switch_cd=math.max(0,obj.switch_cd-1)
        obj.throw_cd=math.max(0,obj.throw_cd-1)
        local valid = players.valid_my_base(receiver)
            and receiver ~= taker and receiver ~= config.MY_FIRST
        if not valid then
            obj.last_receiver = nil
            obj.target_x, obj.target_y, obj.lock = nil, nil, 0
            if obj.frames >= c.long_fallback_frames and obj.attempts == 0 then
                return {mode="READY_LONG", taker=taker, receiver=receiver,
                    button=c.long_throw_button, recovery_switches=obj.recovery_switches}
            end
            if obj.switch_cd == 0 and obj.recovery_switches < c.max_recovery_switches then
                obj.switch_cd = c.recovery_switch_interval
                obj.recovery_switches = obj.recovery_switches + 1
                return {mode="SWITCH_RECEIVER", taker=taker, receiver=receiver,
                    recovery_switches=obj.recovery_switches}
            end
            return {mode="WAIT_RECEIVER", taker=taker, receiver=receiver,
                recovery_switches=obj.recovery_switches}
        end
        if receiver ~= obj.last_receiver then
            obj.target_x, obj.target_y, obj.lock = nil, nil, 0
            obj.last_receiver = receiver
        end
        local tx,ty=players.xy(taker)
        local px,py=players.xy(receiver)
        local dir=field_side.attack_direction()
        if dir==0 then return {mode="WAIT_SIDE",taker=taker,receiver=receiver} end
        local current_distance=dist(px,py,tx,ty)
        local nearest,nearest_d=nil,99999
        players.each_my(function(base)
            if base~=taker and base~=config.MY_FIRST then
                local x,y=players.xy(base)
                local d=dist(x,y,tx,ty)
                if d<nearest_d then nearest,nearest_d=base,d end
            end
        end)
        if nearest ~= nil and current_distance-nearest_d>c.switch_margin
            and obj.switch_cd==0 and obj.recovery_switches<c.max_recovery_switches then
            obj.switch_cd=c.switch_cooldown
            obj.recovery_switches=obj.recovery_switches+1
            return {mode="SWITCH_RECEIVER",taker=taker,receiver=receiver,
                nearest=nearest,nearest_distance=nearest_d,
                receiver_distance=current_distance}
        end
        -- Choose a safe reception point infield near the thrower, not on top of him.
        local best=nil
        for _,forward in ipairs({0,40,80}) do
            for _,lateral in ipairs({-80,-40,40,80}) do
                local x=tx+dir*forward
                local y=ty+lateral
                local d=dist(x,y,tx,ty)
                if d>=c.min_distance and d<=c.max_distance then
                    local space=clearance(x,y)
                    local travel=dist(px,py,x,y)
                    local score=math.min(space,180)*c.clearance_weight
                        +forward*c.forward_weight
                        -travel*c.distance_weight
                    if best==nil or score>best.score then
                        best={x=x,y=y,space=space,score=score,travel=travel}
                    end
                end
            end
        end
        if not best then return {mode="WAIT_RECEIVER",taker=taker,receiver=receiver} end
        if obj.lock>0 and obj.target_x and obj.target_y then
            obj.lock=obj.lock-1
            best.x,best.y=obj.target_x,obj.target_y
            best.space=clearance(best.x,best.y)
            best.travel=dist(px,py,best.x,best.y)
        else
            obj.target_x,obj.target_y=best.x,best.y
            obj.lock=c.target_lock_frames
        end
        local mode="MOVE_RECEIVER"
        if best.travel ~= nil and best.space ~= nil
            and best.travel <= c.target_tolerance
            and best.space >= c.min_clearance then
            mode="READY"
        elseif obj.frames>=c.long_fallback_frames and obj.attempts==0 then
            mode="READY_LONG"
        end
        return {mode=mode,taker=taker,receiver=receiver,
            receiver_x=best.x,receiver_y=best.y,
            receiver_distance=current_distance,receiver_clearance=best.space,
            receiver_score=best.score,move_dx=best.x-px,move_dy=best.y-py,
            nearest=nearest,nearest_distance=nearest_d,
            button=mode=="READY_LONG" and c.long_throw_button or c.throw_button}
    end
    function obj.fire(plan,movement)
        if not plan or (plan.mode~="READY" and plan.mode~="READY_LONG") then return false end
        if obj.throw_cd>0 or obj.attempts>=c.max_attempts then return false end
        movement.press_button(plan.button)
        obj.throw_cd=c.retry_frames
        obj.attempts=obj.attempts+1
        return true
    end
    return obj
end
return M
