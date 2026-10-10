local M = {}

function M.new(config, mem)
    local obj = {}

    function obj.read()
        return mem.u16(config.ADDR.game_state)
    end

    function obj.kind(value)
        if value == 0 then return "LIVE" end
        if value == 1 then return "ENDLINE_RESTART" end
        if value == 2 then return "THROW_IN" end
        if value == 3 then return "FOUL_RESTART_SEQUENCE" end
        if value == 4 then return "OFFSIDE_SEQUENCE" end
        if value == 5 then return "POST_GOAL" end
        if value == 6 then return "PERIOD_TIME_UP" end
        return "UNKNOWN"
    end

    function obj.is_live(value)
        return value == 0
    end

    function obj.is_restart(value)
        return value == 1 or value == 2
    end

    function obj.is_stoppage(value)
        return value == 3 or value == 4 or value == 5 or value == 6
    end

    return obj
end

return M
