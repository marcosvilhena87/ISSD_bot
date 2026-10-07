local M = {}

function M.new(config, mem)
    local obj = {}

    function obj.read()
        return mem.u8(config.ADDR.gameplay_active)
    end

    function obj.is_active(value)
        return value == 1
    end

    function obj.kind(value)
        if value == 1 then
            return "ACTIVE"
        elseif value == 0 then
            return "INACTIVE"
        end
        return "UNKNOWN"
    end

    return obj
end

return M
