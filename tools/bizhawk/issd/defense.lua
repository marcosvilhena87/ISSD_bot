local M = {}

function M.new(config, players, geometry)
    local obj = {}

    local function distance(ax, ay, bx, by)
        return math.sqrt(geometry.dist2(ax, ay, bx, by))
    end

    -- Menor score = maior prioridade defensiva.
    function obj.marking_score(my_base, cpu_base, ball_x, ball_y)
        local mx, my = players.xy(my_base)
        local px, py = players.xy(cpu_base)

        local dist_to_me = distance(mx, my, px, py)
        local dist_to_ball = distance(ball_x, ball_y, px, py)

        local score =
            config.DEFENSE.weight_to_me * dist_to_me
          + config.DEFENSE.weight_to_ball * dist_to_ball

        return score, dist_to_me, dist_to_ball
    end

    function obj.select_mark_target(my_base, excluded_base, ball_x, ball_y)
        local best_base = nil
        local best_score = nil
        local best_to_me = nil
        local best_to_ball = nil

        players.each_cpu(function(base)
            if base ~= excluded_base then
                local score, to_me, to_ball =
                    obj.marking_score(my_base, base, ball_x, ball_y)

                if best_score == nil or score < best_score then
                    best_base = base
                    best_score = score
                    best_to_me = to_me
                    best_to_ball = to_ball
                end
            end
        end)

        return best_base, best_score, best_to_me, best_to_ball
    end

    return obj
end

return M
