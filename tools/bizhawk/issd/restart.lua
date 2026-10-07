local M = {}

function M.new(config, players, geometry, defense)
    local obj = {
        taker = nil,
        taker_team = nil,
        mark_target = nil,
    }

    local function nearest_player_to_point(x, y)
        local best_base = nil
        local best_team = nil
        local best_d2 = nil

        players.each_my(function(base)
            local px, py = players.xy(base)
            local d2 = geometry.dist2(px, py, x, y)
            if best_d2 == nil or d2 < best_d2 then
                best_base = base
                best_team = "MY"
                best_d2 = d2
            end
        end)

        players.each_cpu(function(base)
            local px, py = players.xy(base)
            local d2 = geometry.dist2(px, py, x, y)
            if best_d2 == nil or d2 < best_d2 then
                best_base = base
                best_team = "CPU"
                best_d2 = d2
            end
        end)

        return best_base, best_team, best_d2
    end

    function obj.clear()
        obj.taker = nil
        obj.taker_team = nil
        obj.mark_target = nil
    end

    function obj.assign(ball_x, ball_y, my_base)
        local taker, team = nearest_player_to_point(ball_x, ball_y)
        obj.taker = taker
        obj.taker_team = team

        if team == "CPU" and taker ~= nil then
            obj.mark_target = defense.nearest_cpu_mark_target(my_base, taker)
        else
            obj.mark_target = nil
        end
    end

    return obj
end

return M
