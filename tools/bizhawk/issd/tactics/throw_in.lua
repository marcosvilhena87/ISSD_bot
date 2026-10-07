-- Experimental offensive throw-in. Do not send throw inputs unless the taker is controlled.
local M = {}
function M.new(config, players, field_side)
    local obj = { cooldown = 0, active_taker = nil }
    local settings = config.THROW_IN
    local function dist(ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        return math.sqrt(dx * dx + dy * dy)
    end
    function obj.reset()
        obj.cooldown = 0
        obj.active_taker = nil
    end
    function obj.plan(taker, my_ctrl)
        if not players.valid_my_base(taker) then return nil end
        if obj.active_taker ~= taker then
            obj.active_taker = taker
            obj.cooldown = 0
        end
        local tx, ty = players.xy(taker)
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
