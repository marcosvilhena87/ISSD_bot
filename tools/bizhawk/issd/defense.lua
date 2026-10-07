local M = {}

function M.new(config, players, geometry, mem)
    local obj = {}

    local function distance(ax, ay, bx, by)
        return math.sqrt(geometry.dist2(ax, ay, bx, by))
    end

    local function goal_axis_cost(player_x, my_side)
        if my_side == 0 then
            return player_x
        elseif my_side == 1 then
            return -player_x
        end

        return 0
    end

    local function normalize(value, min_value, max_value)
        if max_value == min_value then
            return 0
        end

        return (value - min_value) / (max_value - min_value)
    end

    local function build_candidates(my_base, excluded_base, ball_x, ball_y)
        local mx, my = players.xy(my_base)
        local my_side = mem.u8(config.ADDR.my_side)
        local candidates = {}

        players.each_cpu(function(base)
            if base ~= excluded_base then
                local px, py = players.xy(base)

                candidates[#candidates + 1] = {
                    base = base,
                    dist_to_me = distance(mx, my, px, py),
                    dist_to_ball = distance(ball_x, ball_y, px, py),
                    goal_cost = goal_axis_cost(px, my_side),
                    my_side = my_side,
                }
            end
        end)

        return candidates
    end

    local function bounds(candidates, key)
        local min_value = nil
        local max_value = nil

        for _, candidate in ipairs(candidates) do
            local value = candidate[key]

            if min_value == nil or value < min_value then
                min_value = value
            end

            if max_value == nil or value > max_value then
                max_value = value
            end
        end

        return min_value, max_value
    end

    -- Componentes sao normalizados por min-max entre os candidatos
    -- da propria reposicao. Assim 0.35 / 0.25 / 0.40 representam
    -- pesos comparaveis, independentemente da escala original.
    function obj.select_mark_target(my_base, excluded_base, ball_x, ball_y)
        local candidates =
            build_candidates(my_base, excluded_base, ball_x, ball_y)

        if #candidates == 0 then
            return nil
        end

        local min_me, max_me = bounds(candidates, "dist_to_me")
        local min_ball, max_ball = bounds(candidates, "dist_to_ball")
        local min_goal, max_goal = bounds(candidates, "goal_cost")

        local best = nil

        for _, candidate in ipairs(candidates) do
            candidate.norm_me =
                normalize(candidate.dist_to_me, min_me, max_me)
            candidate.norm_ball =
                normalize(candidate.dist_to_ball, min_ball, max_ball)
            candidate.norm_goal =
                normalize(candidate.goal_cost, min_goal, max_goal)

            candidate.score =
                config.DEFENSE.weight_to_me * candidate.norm_me
              + config.DEFENSE.weight_to_ball * candidate.norm_ball
              + config.DEFENSE.weight_to_goal * candidate.norm_goal

            if best == nil or candidate.score < best.score then
                best = candidate
            end
        end

        return best.base,
               best.score,
               best.dist_to_me,
               best.dist_to_ball,
               best.goal_cost,
               best.my_side,
               best.norm_me,
               best.norm_ball,
               best.norm_goal
    end

    return obj
end

return M
