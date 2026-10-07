local M = {}

function M.new(config, mem)
    local obj = {}

    function obj.read()
        return mem.u8(config.ADDR.team_possession)
    end

    function obj.kind(value)
        if value == 0 then
            return "MY"
        elseif value == 1 then
            return "CPU"
        end
        return "UNKNOWN"
    end

    function obj.is_my(value)
        return value == 0
    end

    function obj.is_cpu(value)
        return value == 1
    end

    function obj.is_valid(value)
        return value == 0 or value == 1
    end

    return obj
end

return M
