local M = {}

function M.new(config, players, geometry, defense)
    local obj = {
        taker = nil,
        taker_team = nil,

        mark_target = nil,
        mark_score = nil,
        mark_dist_to_me = nil,
        mark_dist_to_ball = nil,
        mark_goal_cost = nil,
        mark_norm_me = nil,
        mark_norm_ball = nil,
        mark_norm_goal = nil,
        my_side = nil,
        ranking = {},

        lock_frames = 0,
        switch_delta = nil,
        switch_blocked = false,

        last_switch_from = nil,
        last_switch_to = nil,
        last_switch_delta = nil,
        last_switch_age = nil,
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

    local function clear_switch_event()
        obj.last_switch_from = nil
        obj.last_switch_to = nil
        obj.last_switch_delta = nil
        obj.last_switch_age = nil
    end

    local function tick_switch_event()
        if obj.last_switch_age == nil then
            return
        end

        obj.last_switch_age = obj.last_switch_age + 1

        if obj.last_switch_age > config.DEFENSE.switch_event_frames then
            clear_switch_event()
        end
    end

    local function record_switch_event(from_base, to_base, delta)
        obj.last_switch_from = from_base
        obj.last_switch_to = to_base
        obj.last_switch_delta = delta
        obj.last_switch_age = 0
    end

    local function clear_mark_lock()
        obj.mark_target = nil
        obj.mark_score = nil
        obj.mark_dist_to_me = nil
        obj.mark_dist_to_ball = nil
        obj.mark_goal_cost = nil
        obj.mark_norm_me = nil
        obj.mark_norm_ball = nil
        obj.mark_norm_goal = nil
        obj.my_side = nil
        obj.ranking = {}

        obj.lock_frames = 0
        obj.switch_delta = nil
        obj.switch_blocked = false
    end

    local function find_candidate(ranking, base)
        for _, candidate in ipairs(ranking or {}) do
            if candidate.base == base then
                return candidate
            end
        end
        return nil
    end

    local function apply_candidate(candidate)
        if candidate == nil then
            clear_mark_lock()
            return
        end

        obj.mark_target = candidate.base
        obj.mark_score = candidate.score
        obj.mark_dist_to_me = candidate.dist_to_me
        obj.mark_dist_to_ball = candidate.dist_to_ball
        obj.mark_goal_cost = candidate.goal_cost
        obj.mark_norm_me = candidate.norm_me
        obj.mark_norm_ball = candidate.norm_ball
        obj.mark_norm_goal = candidate.norm_goal
        obj.my_side = candidate.my_side
    end

    function obj.clear()
        obj.taker = nil
        obj.taker_team = nil
        clear_mark_lock()
        clear_switch_event()
    end

    function obj.assign(ball_x, ball_y, my_base)
        tick_switch_event()

        local previous_taker = obj.taker
        local taker, team = nearest_player_to_point(ball_x, ball_y)

        obj.taker = taker
        obj.taker_team = team

        if team ~= "CPU" or taker == nil then
            clear_mark_lock()
            clear_switch_event()
            return
        end

        -- Se o cobrador mudou, o contexto da reposicao mudou:
        -- reiniciamos o lock para nao carregar uma decisao antiga.
        if previous_taker ~= nil and previous_taker ~= taker then
            clear_mark_lock()
            clear_switch_event()
        end

        local _, _, _, _, _, _, _, _, _, ranking =
            defense.select_mark_target(
                my_base,
                taker,
                ball_x,
                ball_y
            )

        obj.ranking = ranking or {}

        local best = obj.ranking[1]
        if best == nil then
            clear_mark_lock()
            return
        end

        -- Primeira escolha da reposicao.
        if obj.mark_target == nil then
            apply_candidate(best)
            obj.lock_frames = 1
            obj.switch_delta = nil
            obj.switch_blocked = false
            return
        end

        local current = find_candidate(obj.ranking, obj.mark_target)

        -- Se o alvo atual desapareceu da lista (ex.: virou cobrador),
        -- trocamos imediatamente para o melhor candidato valido.
        if current == nil then
            clear_switch_event()
            apply_candidate(best)
            obj.lock_frames = 1
            obj.switch_delta = nil
            obj.switch_blocked = false
            return
        end

        -- Mantemos as metricas do alvo travado atualizadas a cada frame.
        apply_candidate(current)
        obj.lock_frames = obj.lock_frames + 1

        -- Nenhuma decisao de troca se o melhor instantaneo ja e o alvo atual.
        if best.base == obj.mark_target then
            obj.switch_delta = 0
            obj.switch_blocked = false
            return
        end

        -- Quanto o novo #1 e melhor que o alvo atual.
        -- Positivo = novo candidato tem score menor.
        local delta = current.score - best.score
        obj.switch_delta = delta

        -- Compromisso minimo: nao troca nos primeiros N frames.
        if obj.lock_frames < config.DEFENSE.target_lock_frames then
            obj.switch_blocked = true
            return
        end

        -- Depois do lock minimo, so troca se houver vantagem relevante.
        if delta > config.DEFENSE.switch_margin then
            local old_target = obj.mark_target
            record_switch_event(old_target, best.base, delta)

            apply_candidate(best)
            obj.lock_frames = 1
            obj.switch_blocked = false
        else
            obj.switch_blocked = true
        end
    end

    return obj
end

return M
