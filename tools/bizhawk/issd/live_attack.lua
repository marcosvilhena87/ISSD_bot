local M = {}

function M.new(config, players, mem)
    local obj = {}

    local function attack_direction(my_side)
        if my_side == 0 then
            return 1
        elseif my_side == 1 then
            return -1
        end
        return 0
    end

    function obj.target_for_carrier(carrier_base)
        if not players.valid_my_base(carrier_base) then
            return nil
        end

        local px, py = players.xy(carrier_base)
        local my_side = mem.u8(config.ADDR.my_side)
        local dir = attack_direction(my_side)

        if dir == 0 then
            return nil
        end

        return {
            carrier = carrier_base,
            player_x = px,
            player_y = py,
            target_x = px + dir * config.ATTACK.advance_distance,
            target_y = py,
            direction = dir,
            my_side = my_side,
            advance_distance = config.ATTACK.advance_distance,
        }
    end

    return obj
end

return M
