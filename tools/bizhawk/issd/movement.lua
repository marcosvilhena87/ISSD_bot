local M = {}

function M.new(config)
    local obj = {}

    function obj.direction_pad(dx, dy)
        local pad = {}

        if dx > config.DEADZONE_X then
            pad.Right = true
        elseif dx < -config.DEADZONE_X then
            pad.Left = true
        end

        if dy > config.DEADZONE_Y then
            pad.Down = true
        elseif dy < -config.DEADZONE_Y then
            pad.Up = true
        end

        return pad
    end

    function obj.move_toward(dx, dy)
        joypad.set(obj.direction_pad(dx, dy), config.PLAYER)
    end

    function obj.press_button(button)
        local pad = {}
        pad[button] = true
        joypad.set(pad, config.PLAYER)
    end

    function obj.stop()
        joypad.set({}, config.PLAYER)
    end

    return obj
end

return M
