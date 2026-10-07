local M = {}

function M.new(config)
    local obj = { last_command = "NONE" }

    local function send(pad)
        local keys = {}
        for key, value in pairs(pad) do if value then keys[#keys + 1] = key end end
        table.sort(keys)
        obj.last_command = #keys > 0 and table.concat(keys, "+") or "NONE"
        joypad.set(pad, config.PLAYER)
    end

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
        send(obj.direction_pad(dx, dy))
    end

    function obj.press_button(button)
        local pad = {}
        pad[button] = true
        send(pad)
    end

    function obj.press_direction_button(direction, button)
        local pad = {}
        if direction ~= nil then
            pad[direction] = true
        end
        if button ~= nil then
            pad[button] = true
        end
        send(pad)
    end

    function obj.stop()
        send({})
    end

    return obj
end

return M
