local M = {}

function M.new(config, players, geometry, mem)
    local obj = {}

    local function distance(ax, ay, bx, by)
        return math.sqrt(geometry.dist2(ax, ay, bx, by))
    end

    -- Quanto menor, mais perto do nosso lado defensivo.
    -- My_Side = 0 -> defendemos a esquerda -> X menor e mais perigoso.
    -- My_Side = 1 -> defendemos a direita  -> X maior e mais perigoso.
    --
    -- Para o lado direito usamos -X. Isso e suficiente para ranking:
    -- somar uma constante comum a todos os candidatos nao mudaria o alvo.
    local function goal_axis_cost(player_x, my_side)
        if my_side == 0 then
            return player_x
        elseif my_side == 1 then
            return -player_x
        end

        return 0
    end

    -- Menor score = maior prioridade defensiva.
    function obj.marking_score(my_base, cpu_base, ball_x, ball_y)
        local mx, my = players.xy(my_base)
        local px, py = players.xy(cpu_base)
        local my_side = mem.u8(config.ADDR.my_side)

        local dist_to_me = distance(mx, my, px, py)
        local dist_to_ball = distance(ball_x, ball_y, px, py)
        local goal_cost = goal_axis_cost(px, my_side)

        local score =
            config.DEFENSE.weight_to_me * dist_to_me
          + config.DEFENSE.weight_to_ball * dist_to_ball
          + config.DEFENSE.weight_to_goal * goal_cost

        return score, dist_to_me, dist_to_ball, goal_cost, my_side
    end

    function obj.select_mark_target(my_base, excluded_base, ball_x, ball_y)
        local best_base = nil
        local best_score = nil
        local best_to_me = nil
        local best_to_ball = nil
        local best_goal_cost = nil
        local best_my_side = nil

        players.each_cpu(function(base)
            if base ~= excluded_base then
                local score, to_me, to_ball, goal_cost, my_side =
                    obj.marking_score(my_base, base, ball_x, ball_y)

                if best_score == nil or score < best_score then
                    best_base = base
                    best_score = score
                    best_to_me = to_me
                    best_to_ball = to_ball
                    best_goal_cost = goal_cost
                    best_my_side = my_side
                end
            end
        end)

        return best_base,
               best_score,
               best_to_me,
               best_to_ball,
               best_goal_cost,
               best_my_side
    end

    return obj
end

return M
