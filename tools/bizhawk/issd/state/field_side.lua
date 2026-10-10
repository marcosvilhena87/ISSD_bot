local M = {}

function M.new(config, mem)
    local obj = {}

    function obj.cpu_side()
        local value = mem.u8(config.ADDR.cpu_side)

        if value == 0 or value == 1 then
            return value
        end

        return nil
    end

    function obj.my_side()
        local my_side = mem.u8(config.ADDR.my_side)
        local cpu_side = obj.cpu_side()
        local valid_my = my_side == 0 or my_side == 1
        if valid_my and cpu_side ~= nil and my_side == 1 - cpu_side then
            return my_side
        end
        -- Preserve the existing CPU-derived fallback when the new flag
        -- disagrees or is unavailable; investigate discrepancies via logs.
        if cpu_side ~= nil then return 1 - cpu_side end
        if valid_my then return my_side end
        return nil
    end

    function obj.attack_direction()
        local my_side = obj.my_side()

        if my_side == 0 then
            return 1
        elseif my_side == 1 then
            return -1
        end

        return 0
    end

    function obj.goal_direction()
        local my_side = obj.my_side()

        if my_side == 0 then
            return -1
        elseif my_side == 1 then
            return 1
        end

        return 0
    end

    return obj
end

return M
