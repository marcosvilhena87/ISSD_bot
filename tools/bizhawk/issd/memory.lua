local M = {}

function M.new(config)
    local obj = {}

    function obj.s16(addr)
        return memory.read_s16_le(addr, config.DOMAIN)
    end

    function obj.u16(addr)
        return memory.read_u16_le(addr, config.DOMAIN)
    end

    function obj.u8(addr)
        return memory.read_u8(addr, config.DOMAIN)
    end

    return obj
end

return M
