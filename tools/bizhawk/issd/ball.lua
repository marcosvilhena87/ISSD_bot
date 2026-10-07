local M = {}

function M.new(config, mem)
    local obj = {}

    function obj.world_xy()
        return mem.s16(config.ADDR.ball_x),
               mem.s16(config.ADDR.ball_y)
    end

    function obj.possession()
        return mem.u16(config.ADDR.possession)
    end

    return obj
end

return M
