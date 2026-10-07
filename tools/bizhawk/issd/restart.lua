local M = {}

function M.new(config, players, geometry, defense)
    local obj = {
        taker = nil,
        taker_team = nil,
        mark_target = nil,
        mark_score = nil,
        mark_dist_to_me = nil,
        mark_dist_to_ball = nil,
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
        obj.mark_score = nil
        obj.mark_dist_to_me = nil
        obj.mark_dist_to_ball = nil
    end

    function obj.assign(ball_x, ball_y, my_base)
        local taker, team = nearest_player_to_point(ball_x, ball_y)
        obj.taker = taker
        obj.taker_team = team

        if team == "CPU" and taker ~= nil then
            local target, score, to_me, to_ball =
                defense.select_mark_target(
                    my_base,
                    taker,
                    ball_x,
                    ball_y
                )

            obj.mark_target = target
            obj.mark_score = score
            obj.mark_dist_to_me = to_me
            obj.mark_dist_to_ball = to_ball
        else
            obj.mark_target = nil
            obj.mark_score = nil
            obj.mark_dist_to_me = nil
            obj.mark_dist_to_ball = nil
        end
    end

    return obj
end

return M
