local M = {}

function M.new(config, mem)
    local obj = {}

    function obj.read()
        return mem.u16(config.ADDR.game_state)
    end

    function obj.kind(value)
        if value == 0 then return "LIVE" end
        if value == 1 then return "ENDLINE" end
        if value == 2 then return "THROW_IN" end
        return "UNKNOWN"
    end

    function obj.is_live(value)
        return value == 0
    end

    function obj.is_restart(value)
        return value == 1 or value == 2
    end

    return obj
end

return M
