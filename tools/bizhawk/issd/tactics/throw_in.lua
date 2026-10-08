-- Offensive throw-in: restart.taker throws; MyCtrl moves as receiver.
local M = {}
function M.new(config, players, field_side, mem)
    local c = config.THROW_IN or {}
    local defaults = {
        throw_button="B", long_throw_button="A",
        min_distance=24, max_distance=280, min_clearance=40,
        clearance_weight=1, forward_weight=0.25, distance_weight=0.35,
        retry_frames=45, switch_margin=80, switch_cooldown=45,
        target_lock_frames=20, target_tolerance=16,
        max_attempts=2, long_fallback_frames=180,
        recovery_switch_interval=30, max_recovery_switches=3,
        field_margin=40, receiver_max_taker_distance=160,
        receiver_switch_improvement=32, switch_verify_frames=12,
        long_min_distance=150, long_max_distance=500,
        long_min_clearance=55, long_ready_frames=12
    }
    for key, value in pairs(defaults) do
        if c[key] == nil then c[key] = value end
    end
    local obj = {taker=nil, frames=0, switch_cd=0, throw_cd=0,
        attempts=0, target_x=nil, target_y=nil, lock=0,
        recovery_switches=0, last_receiver=nil,
        pending_switch=nil, switch_wait=0, positioning_frames=0}
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
    local function field_bounds()
        if not mem then return nil end
        local length=mem.u16(config.ADDR.field_length)
        local width=mem.u16(config.ADDR.field_width)
        local cx=mem.u16(config.ADDR.center_field_x)
        local cy=mem.u16(config.ADDR.center_field_y)
        local margin=c.field_margin
        -- Candidate WRAM map. Reject inconsistent dimensions safely.
        if length<300 or length>4000 or width<200 or width>2000
            or cx<1 or cy<1 then return nil end
        local x1=cx-length/2+margin
        local x2=cx+length/2-margin
        local y1=cy-width/2+margin
        local y2=cy+width/2-margin
        if x1>=x2 or y1>=y2 then return nil end
        return {x1=x1,x2=x2,y1=y1,y2=y2,
            stadium=mem.u8(config.ADDR.stadium_id)}
    end
    local function inside(x,y,b)
        return b and x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2
    end
    function obj.reset()
        obj.taker=nil; obj.frames=0; obj.switch_cd=0
        obj.throw_cd=0; obj.attempts=0
        obj.target_x=nil; obj.target_y=nil; obj.lock=0
        obj.recovery_switches=0; obj.last_receiver=nil
        obj.pending_switch=nil; obj.switch_wait=0
        obj.positioning_frames=0
    end
    function obj.plan(taker, receiver)
        if not players.valid_my_base(taker) then return nil end
        if obj.taker~=taker then obj.reset(); obj.taker=taker end
        obj.frames=obj.frames+1
        obj.switch_cd=math.max(0,obj.switch_cd-1)
        obj.throw_cd=math.max(0,obj.throw_cd-1)
        if obj.switch_wait>0 then obj.switch_wait=obj.switch_wait-1 end
        if obj.pending_switch~=nil then
            if receiver~=obj.pending_switch then
                obj.pending_switch=nil
                obj.switch_wait=c.switch_verify_frames
            elseif obj.switch_wait>0 then
                return {mode="VERIFY_RECEIVER",taker=taker,receiver=receiver,
                    recovery_switches=obj.recovery_switches}
            else
                obj.pending_switch=nil
            end
        end
        local valid = players.valid_my_base(receiver)
            and receiver ~= taker and receiver ~= config.MY_FIRST
        if not valid then
            obj.last_receiver = nil
            obj.target_x, obj.target_y, obj.lock = nil, nil, 0

            if obj.switch_cd == 0 and obj.recovery_switches < c.max_recovery_switches then
                obj.switch_cd = c.recovery_switch_interval
                obj.recovery_switches = obj.recovery_switches + 1
                obj.pending_switch=receiver
                obj.switch_wait=c.switch_verify_frames
                return {mode="SWITCH_RECEIVER", taker=taker, receiver=receiver,
                    recovery_switches=obj.recovery_switches}
            end
            return {mode="WAIT_RECEIVER", taker=taker, receiver=receiver,
                recovery_switches=obj.recovery_switches}
        end
        if receiver ~= obj.last_receiver then
            obj.target_x, obj.target_y, obj.lock = nil, nil, 0
            obj.last_receiver = receiver
            obj.positioning_frames=0
        end
        local tx,ty=players.xy(taker)
        local px,py=players.xy(receiver)
        local dir=field_side.attack_direction()
        if dir==0 then return {mode="WAIT_SIDE",taker=taker,receiver=receiver} end
        local bounds=field_bounds()
        local current_distance=dist(px,py,tx,ty)
        -- Decide A actively for a safe distant receiver, independently of B.
        local receiver_space=clearance(px,py)
        if inside(px,py,bounds)
            and current_distance>=c.long_min_distance
            and current_distance<=c.long_max_distance
            and receiver_space>=c.long_min_clearance
            and obj.frames>=c.long_ready_frames then
            return {mode="READY_LONG",taker=taker,receiver=receiver,
                button=c.long_throw_button,receiver_distance=current_distance,
                receiver_to_target=0,receiver_clearance=receiver_space,
                receiver_x=px,receiver_y=py,
                receiver_near_taker=false,
                field_x1=bounds.x1,field_x2=bounds.x2,
                field_y1=bounds.y1,field_y2=bounds.y2,
                stadium=bounds.stadium,reason="LONG_RECEIVER_CLEAR"}
        end
        local nearest,nearest_d=nil,99999
        players.each_my(function(base)
            if base~=taker and base~=config.MY_FIRST then
                local x,y=players.xy(base)
                local d=dist(x,y,tx,ty)
                if d<nearest_d then nearest,nearest_d=base,d end
            end
        end)
        if nearest ~= nil and current_distance-nearest_d>c.receiver_switch_improvement
            and obj.switch_cd==0 and obj.recovery_switches<c.max_recovery_switches then
            obj.switch_cd=c.switch_cooldown
            obj.recovery_switches=obj.recovery_switches+1
            obj.pending_switch=receiver
            obj.switch_wait=c.switch_verify_frames
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
                if inside(x,y,bounds)
                    and d>=c.min_distance and d<=c.max_distance then
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
        if not best then return {mode="WAIT_FIELD_BOUNDS",taker=taker,receiver=receiver} end
        if obj.lock>0 and inside(obj.target_x,obj.target_y,bounds) then
            obj.lock=obj.lock-1
            best.x,best.y=obj.target_x,obj.target_y
            best.space=clearance(best.x,best.y)
            best.travel=dist(px,py,best.x,best.y)
        else
            obj.target_x,obj.target_y=best.x,best.y
            obj.lock=c.target_lock_frames
        end
        local mode="MOVE_RECEIVER"
        obj.positioning_frames=obj.positioning_frames+1
        if current_distance<=c.receiver_max_taker_distance
            and best.travel ~= nil and best.space ~= nil
            and best.travel <= c.target_tolerance
            and best.space >= c.min_clearance then
            mode="READY"
        elseif obj.positioning_frames>=c.max_positioning_frames
            and current_distance>=c.min_distance
            and current_distance<=c.max_distance
            and inside(px,py,bounds)
            and receiver_space>=c.min_clearance then
            mode="READY"
        end
        return {mode=mode,taker=taker,receiver=receiver,
            receiver_x=best.x,receiver_y=best.y,
            receiver_distance=current_distance,receiver_to_target=best.travel,
            receiver_clearance=receiver_space,
            receiver_score=best.score,move_dx=best.x-px,move_dy=best.y-py,
            nearest=nearest,nearest_distance=nearest_d,
            receiver_near_taker=current_distance<=c.receiver_max_taker_distance,
            field_x1=bounds.x1,field_x2=bounds.x2,
            field_y1=bounds.y1,field_y2=bounds.y2,
            stadium=bounds.stadium,
            positioning_frames=obj.positioning_frames,
            button=c.throw_button,reason=mode=="READY" and
                (best.travel<=c.target_tolerance and "SHORT_READY" or "POSITION_TIMEOUT")
                or "POSITIONING"}
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
