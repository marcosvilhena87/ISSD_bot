-- Experimental offensive throw-in. Do not send throw inputs unless the taker is controlled.
local M = {}
function M.new(config, players, field_side)
    local obj = { cooldown = 0, active_taker = nil, switch_cooldown = 0, last_control = nil, stationary_frames = 0 }
    local settings = config.THROW_IN
    local function dist(ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        return math.sqrt(dx * dx + dy * dy)
    end
    function obj.reset()
        obj.cooldown = 0
        obj.active_taker = nil
        obj.switch_cooldown = 0
        obj.last_control = nil
        obj.stationary_frames = 0
    end
    function obj.plan(taker, my_ctrl)
        if not players.valid_my_base(taker) then return nil end
        if obj.active_taker ~= taker then
            obj.active_taker = taker
            obj.cooldown = 0
            obj.switch_cooldown = 0
            obj.last_control = nil
            obj.stationary_frames = 0
        end
        if obj.switch_cooldown > 0 then obj.switch_cooldown = obj.switch_cooldown - 1 end
        local tx, ty = players.xy(taker)
        -- On throw-ins, MyCtrl may refer to an outfield receiver, not the thrower.
        if players.valid_my_base(my_ctrl) and my_ctrl ~= taker and my_ctrl ~= config.MY_FIRST then
            local px, py = players.xy(my_ctrl)
            local d = dist(px, py, tx, ty)
            local nearest, nearest_d = nil, math.huge
            players.each_my(function(base)
                if base ~= taker and base ~= config.MY_FIRST then
                    local x, y = players.xy(base)
                    local dd = dist(x, y, tx, ty)
                    if dd < nearest_d then nearest, nearest_d = base, dd end
                end
            end)
            local mode, direction
            if d > settings.receiver_ready_distance then
                if nearest ~= my_ctrl and d - nearest_d > settings.switch_margin
                    and obj.switch_cooldown == 0 then
                    mode = "SWITCH_RECEIVER"
                    obj.switch_cooldown = settings.switch_cooldown
                else
                    mode = "MOVE_RECEIVER"
                end
            else
                mode = "RECEIVER_POSITIONED"
            end
            if mode == "MOVE_RECEIVER" then
                -- Move toward the thrower's field position, stopping at a safe range.
                return {mode=mode, taker=taker, receiver=my_ctrl,
                    receiver_x=tx, receiver_y=ty, receiver_distance=d,
                    move_dx=tx-px, move_dy=ty-py, nearest=nearest,
                    nearest_distance=nearest_d}
            elseif mode == "SWITCH_RECEIVER" then
                return {mode=mode, taker=taker, receiver=my_ctrl,
                    receiver_distance=d, nearest=nearest,
                    nearest_distance=nearest_d}
            end
            -- Do not assume the throw-in button controls the thrower.
            -- The current receiver has been positioned; await manual calibration.
            return {mode=mode, taker=taker, receiver=my_ctrl,
                receiver_x=px, receiver_y=py, receiver_distance=d,
                nearest=nearest, nearest_distance=nearest_d}
        end
        local forward_direction = field_side.attack_direction()
        if forward_direction == nil or forward_direction == 0 then
            return { mode = "WAIT_SIDE", taker = taker }
        end
        local best = nil
        players.each_my(function(base)
            if base ~= taker and base ~= config.MY_FIRST then
                local x, y = players.xy(base)
                local d = dist(tx, ty, x, y)
                if d >= settings.min_distance and d <= settings.max_distance then
                    local clearance = math.huge
                    players.each_cpu(function(enemy)
                        local ex, ey = players.xy(enemy)
                        clearance = math.min(clearance, dist(x, y, ex, ey))
                    end)
                    local progress = (x - tx) * forward_direction
                    local score = clearance * settings.clearance_weight
                        + progress * settings.forward_weight - d * settings.distance_weight
                    if best == nil or score > best.score then
                        best = { base=base, x=x, y=y, distance=d,
                            clearance=clearance, progress=progress, score=score }
                    end
                end
            end
        end)
        if best == nil then
            return {mode="WAIT_RECEIVER", taker=taker}
        end
        -- Aiming is experimental and may require calibration against actual game controls.
        local dx, dy = best.x - tx, best.y - ty
        local direction
        if math.abs(dx) >= math.abs(dy) then
            direction = dx >= 0 and "Right" or "Left"
        else
            direction = dy >= 0 and "Down" or "Up"
        end
        local mode = my_ctrl == taker and "READY" or "WAIT_TAKER_CONTROL"
        if best.clearance < settings.min_clearance then mode = "WAIT_CLEARANCE" end
        return {mode=mode, taker=taker, receiver=best.base, receiver_x=best.x,
            receiver_y=best.y, receiver_distance=best.distance,
            receiver_clearance=best.clearance, receiver_score=best.score,
            direction=direction, button=settings.throw_button}
    end
    function obj.fire(plan, movement)
        if plan == nil or plan.mode ~= "READY" then return false end
        if obj.cooldown > 0 then
            obj.cooldown = obj.cooldown - 1
            return false
        end
        movement.press_direction_button(plan.direction, plan.button)
        obj.cooldown = settings.retry_frames
        return true
    end
    return obj
end
return M
