local M = {}

function M.new(config, players)
    local obj = {
        cooldown = 0,
        last_requested_from = nil,
        last_best = nil,
        last_current_distance = nil,
        last_best_distance = nil,
        last_improvement = nil,
    }

    local function distance(ax, ay, bx, by)
        local dx = bx - ax
        local dy = by - ay
        return math.sqrt(dx * dx + dy * dy)
    end

    local function best_my_player(target_x, target_y)
        local best_base = nil
        local best_distance = nil

        players.each_my(function(base)
            if not (config.PLAYER_SWITCH.exclude_goalkeeper
                    and base == config.MY_FIRST) then
                local px, py = players.xy(base)
                local d = distance(px, py, target_x, target_y)

                if best_distance == nil or d < best_distance then
                    best_base = base
                    best_distance = d
                end
            end
        end)

        return best_base, best_distance
    end

    function obj.tick()
        if obj.cooldown > 0 then
            obj.cooldown = obj.cooldown - 1
        end
    end

    function obj.reset()
        obj.cooldown = 0
        obj.last_requested_from = nil
        obj.last_best = nil
        obj.last_current_distance = nil
        obj.last_best_distance = nil
        obj.last_improvement = nil
    end

    function obj.consider(my_base, target_x, target_y)
        local px, py = players.xy(my_base)
        local current_distance = distance(px, py, target_x, target_y)
        local best_base, best_distance = best_my_player(target_x, target_y)

        local improvement = 0
        if best_distance ~= nil then
            improvement = current_distance - best_distance
        end

        local should_switch =
            obj.cooldown == 0
            and best_base ~= nil
            and best_base ~= my_base
            and improvement > config.PLAYER_SWITCH.improvement_margin

        if should_switch then
            obj.cooldown = config.PLAYER_SWITCH.cooldown_frames
            obj.last_requested_from = my_base
            obj.last_best = best_base
            obj.last_current_distance = current_distance
            obj.last_best_distance = best_distance
            obj.last_improvement = improvement
        end

        return {
            should_switch = should_switch,
            current_base = my_base,
            best_base = best_base,
            current_distance = current_distance,
            best_distance = best_distance,
            improvement = improvement,
            cooldown = obj.cooldown,
            button = config.PLAYER_SWITCH.button,
        }
    end

    return obj
end

return M
