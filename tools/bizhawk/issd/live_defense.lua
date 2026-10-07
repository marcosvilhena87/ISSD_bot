local M = {}

function M.new(config, players, mem)
    local obj = {}

    local function goal_direction(my_side)
        if my_side == 0 then
            return -1
        elseif my_side == 1 then
            return 1
        end
        return 0
    end

    function obj.goalkeeper_policy(my_base, carrier_base)
        if carrier_base ~= config.CPU_FIRST then
            return nil
        end

        local px, py = players.xy(my_base)
        local gx, gy = players.xy(carrier_base)
        local dx = gx - px
        local dy = gy - py
        local distance = math.sqrt(dx * dx + dy * dy)
        local threshold = config.LIVE_DEFENSE.gk_press_distance

        return {
            distance = distance,
            threshold = threshold,
            should_press = distance <= threshold,
        }
    end

    function obj.target_for_carrier(carrier_base)
        if not players.valid_cpu_base(carrier_base) then
            return nil
        end

        local cx, cy = players.xy(carrier_base)
        local my_side = mem.u8(config.ADDR.my_side)
        local dir = goal_direction(my_side)

        local tx = cx + dir * config.LIVE_DEFENSE.goal_side_offset
        local ty = cy

        return {
            carrier = carrier_base,
            carrier_x = cx,
            carrier_y = cy,
            target_x = tx,
            target_y = ty,
            my_side = my_side,
        }
    end

    return obj
end

return M
