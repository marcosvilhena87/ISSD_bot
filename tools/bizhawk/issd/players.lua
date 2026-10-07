local M = {}

function M.new(config, mem)
    local obj = {}

    function obj.valid_my_base(base)
        return base >= config.MY_FIRST
           and base <= config.MY_LAST
           and base % config.PLAYER_STRIDE == 0
    end

    function obj.valid_cpu_base(base)
        return base >= config.CPU_FIRST
           and base <= config.CPU_LAST
           and base % config.PLAYER_STRIDE == 0
    end

    function obj.xy(base)
        return mem.s16(base + config.OFFSET.world_x),
               mem.s16(base + config.OFFSET.world_y)
    end

    function obj.cam_xy(base)
        return mem.s16(base + config.OFFSET.cam_x),
               mem.s16(base + config.OFFSET.cam_y)
    end

    function obj.decode_my(base)
        if base == 0x0D00 then return "Beranco" end
        if base == 0x0E00 then return "Gomez" end
        if base == 0x0F00 then return "Allejo" end
        if base == 0x0500 then return "GK" end
        return string.format("$%04X", base)
    end

    function obj.decode_any(base)
        if base == nil then return "none" end

        if obj.valid_my_base(base) then
            return "MY " .. obj.decode_my(base)
        end

        if obj.valid_cpu_base(base) then
            local slot = math.floor((base - config.CPU_FIRST) / config.PLAYER_STRIDE)
            if slot == 0 then return "CPU GK" end
            return string.format("CPU slot %d", slot + 1)
        end

        return string.format("$%04X", base)
    end

    function obj.each_my(fn)
        for base = config.MY_FIRST, config.MY_LAST, config.PLAYER_STRIDE do
            fn(base)
        end
    end

    function obj.each_cpu(fn)
        for base = config.CPU_FIRST, config.CPU_LAST, config.PLAYER_STRIDE do
            fn(base)
        end
    end

    return obj
end

return M
