-- ISSD Bot - modular main loop

local function script_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return source:match("^(.*[\\/])") or "./"
end

local DIR = script_dir()

local config = dofile(DIR .. "config.lua")
local Memory = dofile(DIR .. "memory.lua")
local Players = dofile(DIR .. "players.lua")
local Ball = dofile(DIR .. "ball.lua")
local GameState = dofile(DIR .. "game_state.lua")
local GameplayActive = dofile(DIR .. "gameplay_active.lua")
local Movement = dofile(DIR .. "movement.lua")
local Geometry = dofile(DIR .. "geometry.lua")
local Defense = dofile(DIR .. "defense.lua")
local LiveDefense = dofile(DIR .. "live_defense.lua")
local Interception = dofile(DIR .. "interception.lua")
local PlayerSwitch = dofile(DIR .. "player_switch.lua")
local TeamPossession = dofile(DIR .. "team_possession.lua")
local PossessionContext = dofile(DIR .. "possession_context.lua")
local Restart = dofile(DIR .. "restart.lua")
local Overlay = dofile(DIR .. "overlay.lua")

local mem = Memory.new(config)
local players = Players.new(config, mem)
local ball = Ball.new(config, mem)
local game_state = GameState.new(config, mem)
local gameplay_active = GameplayActive.new(config, mem)
local movement = Movement.new(config)
local defense = Defense.new(config, players, Geometry, mem)
local live_defense = LiveDefense.new(config, players, mem)
local interception = Interception.new(config)
local player_switch = PlayerSwitch.new(config, players)
local team_possession = TeamPossession.new(config, mem)
local possession_context = PossessionContext.new(config, players)
local restart = Restart.new(config, players, Geometry, defense)
local overlay = Overlay.new(players, game_state)

local enabled = false
local stop_on_possession = true
local previous_keys = {}

local function pressed(keys, key)
    return keys[key] and not previous_keys[key]
end

local function read_my_base()
    return mem.u16(config.ADDR.my_ctrl)
end

local function make_state(my_base, dx, dy, status, possession, gs)
    return {
        my_base = my_base,
        gameplay_active = gameplay_active.read(),
        gameplay_active_kind = gameplay_active.kind(gameplay_active.read()),
        dx = dx,
        dy = dy,
        status = status,
        possession = possession,
        game_state = gs,
        restart_taker = restart.taker,
        mark_target = restart.mark_target,
        mark_score = restart.mark_score,
        mark_dist_to_me = restart.mark_dist_to_me,
        mark_dist_to_ball = restart.mark_dist_to_ball,
        mark_goal_cost = restart.mark_goal_cost,
        mark_norm_me = restart.mark_norm_me,
        mark_norm_ball = restart.mark_norm_ball,
        mark_norm_goal = restart.mark_norm_goal,
        my_side = restart.my_side,
        ranking = restart.ranking,
        lock_frames = restart.lock_frames,
        switch_delta = restart.switch_delta,
        switch_blocked = restart.switch_blocked,
        last_switch_from = restart.last_switch_from,
        last_switch_to = restart.last_switch_to,
        last_switch_delta = restart.last_switch_delta,
        last_switch_age = restart.last_switch_age,
        live_carrier = nil,
        live_target_x = nil,
        live_target_y = nil,
        live_my_side = nil,
        gk_distance = nil,
        gk_press_threshold = nil,
        gk_should_press = nil,
        team_possession = nil,
        team_possession_kind = nil,
        team_possession_source = nil,
        possession_class = nil,
        context_last_team = nil,
        context_last_owner = nil,
        context_frames_without = 0,
        ball_dx = 0,
        ball_dy = 0,
        ball_speed = 0,
        intercept_target_x = nil,
        intercept_target_y = nil,
        intercept_lead_frames = 0,
        intercept_lead_x = 0,
        intercept_lead_y = 0,
        intercept_predictive = false,
        intercept_player_ball_distance = nil,
        intercept_clipped = false,
        switch_best_base = nil,
        switch_current_distance = nil,
        switch_best_distance = nil,
        switch_improvement = nil,
        switch_cooldown = 0,
        switch_button = nil,
    }
end

local function step_bot()
    player_switch.tick()

    local gameplay_value = gameplay_active.read()
    local my_base = read_my_base()
    local possession = ball.possession()
    local gs = game_state.read()

    if not gameplay_active.is_active(gameplay_value) then
        restart.clear()
        possession_context.reset()
        player_switch.reset()
        movement.stop()

        local state = make_state(
            my_base, 0, 0, "BOT_IDLE", possession, gs
        )
        state.gameplay_active = gameplay_value
        state.gameplay_active_kind = gameplay_active.kind(gameplay_value)
        return state
    end

    if game_state.is_stoppage(gs) then
        restart.clear()
        possession_context.reset()
        player_switch.reset()
        movement.stop()

        local state = make_state(
            my_base, 0, 0, game_state.kind(gs), possession, gs
        )
        state.gameplay_active = gameplay_value
        state.gameplay_active_kind = gameplay_active.kind(gameplay_value)
        return state
    end

    if not players.valid_my_base(my_base) then
        restart.clear()
        possession_context.reset()
        player_switch.reset()
        movement.stop()

        local state = make_state(
            my_base, nil, nil, "BOT_IDLE_NO_PLAYER", possession, gs
        )
        state.gameplay_active = gameplay_value
        state.gameplay_active_kind = gameplay_active.kind(gameplay_value)
        return state
    end

    local bx, by = ball.world_xy()

    if game_state.is_live(gs) then
        restart.clear()

        -- Mantem a heuristica temporal aquecida apenas como fallback.
        local fallback_class =
            possession_context.update(possession, bx, by)

        local team_value = team_possession.read()
        local team_kind = team_possession.kind(team_value)

        local function attach_live_state(state, source, class)
            state.team_possession = team_value
            state.team_possession_kind = team_kind
            state.team_possession_source = source
            state.possession_class = class or fallback_class
            state.context_last_team = possession_context.last_team
            state.context_last_owner = possession_context.last_owner
            state.context_frames_without =
                possession_context.frames_without_possession
            state.ball_dx = possession_context.ball_dx
            state.ball_dy = possession_context.ball_dy
            state.ball_speed = possession_context.ball_speed
            return state
        end


        local function maybe_switch_player(target_x, target_y, class)
            local decision =
                player_switch.consider(my_base, target_x, target_y)

            if not decision.should_switch then
                return nil
            end

            movement.press_button(decision.button)

            local state = make_state(
                my_base, 0, 0, "PLAYER_SWITCH", possession, gs
            )
            state.switch_best_base = decision.best_base
            state.switch_current_distance = decision.current_distance
            state.switch_best_distance = decision.best_distance
            state.switch_improvement = decision.improvement
            state.switch_cooldown = decision.cooldown
            state.switch_button = decision.button

            return attach_live_state(
                state,
                "PLAYER_SWITCH",
                class
            )
        end

        -- 0x00A6 continua sendo a fonte autoritativa para o jogador
        -- fisicamente ligado a bola.
        if players.valid_my_base(possession) then
            return attach_live_state(
                make_state(
                    my_base, 0, 0, "POSSESSION_MANUAL", possession, gs
                ),
                "PLAYER_POSSESSION",
                "MY_CONTROLLED"
            )
        end

        if players.valid_cpu_base(possession) then
            local gk_policy =
                live_defense.goalkeeper_policy(my_base, possession)

            if gk_policy ~= nil and not gk_policy.should_press then
                movement.stop()

                local state = make_state(
                    my_base, 0, 0, "CPU_GK_HOLD", possession, gs
                )
                state.live_carrier = possession
                state.gk_distance = gk_policy.distance
                state.gk_press_threshold = gk_policy.threshold
                state.gk_should_press = false

                return attach_live_state(
                    state,
                    "PLAYER_POSSESSION",
                    "CPU_CONTROLLED"
                )
            end

            local live = live_defense.target_for_carrier(possession)

            if live ~= nil then
                local switch_state = maybe_switch_player(
                    live.target_x,
                    live.target_y,
                    "CPU_CONTROLLED"
                )
                if switch_state ~= nil then
                    return switch_state
                end

                local px, py = players.xy(my_base)
                local dx = live.target_x - px
                local dy = live.target_y - py

                movement.move_toward(dx, dy)

                local state = make_state(
                    my_base, dx, dy, "LIVE_DEFENSE", possession, gs
                )
                state.live_carrier = live.carrier
                state.live_target_x = live.target_x
                state.live_target_y = live.target_y
                state.live_my_side = live.my_side

                if gk_policy ~= nil then
                    state.gk_distance = gk_policy.distance
                    state.gk_press_threshold = gk_policy.threshold
                    state.gk_should_press = true
                end

                return attach_live_state(
                    state,
                    "PLAYER_POSSESSION",
                    "CPU_CONTROLLED"
                )
            end
        end

        -- Quando nenhum jogador esta fisicamente ligado a bola,
        -- 0x104C passa a ser a fonte primaria para o lado da posse.
        if possession == 0 and team_possession.is_cpu(team_value) then
            local px, py = players.xy(my_base)
            local target = interception.target(
                px,
                py,
                bx,
                by,
                possession_context.ball_dx,
                possession_context.ball_dy,
                possession_context.ball_speed
            )

            local switch_state = maybe_switch_player(
                target.x,
                target.y,
                "CPU_BALL_IN_FLIGHT"
            )
            if switch_state ~= nil then
                return switch_state
            end

            local switch_state = maybe_switch_player(
                target.x,
                target.y,
                "CPU_BALL_IN_FLIGHT"
            )
            if switch_state ~= nil then
                return switch_state
            end

            local dx = target.x - px
            local dy = target.y - py
            movement.move_toward(dx, dy)

            local state = make_state(
                my_base, dx, dy, "CPU_BALL_INTERCEPT", possession, gs
            )
            state.intercept_target_x = target.x
            state.intercept_target_y = target.y
            state.intercept_lead_frames = target.lead_frames
            state.intercept_lead_x = target.lead_x
            state.intercept_lead_y = target.lead_y
            state.intercept_predictive = target.predictive
            state.intercept_player_ball_distance =
                target.player_ball_distance
            state.intercept_clipped = target.clipped

            return attach_live_state(
                state,
                "TEAM_POSSESSION_RAM",
                "CPU_BALL_IN_FLIGHT"
            )
        end

        if possession == 0 and team_possession.is_my(team_value) then
            return attach_live_state(
                make_state(
                    my_base, 0, 0, "MY_BALL_IN_FLIGHT", possession, gs
                ),
                "TEAM_POSSESSION_RAM",
                "MY_BALL_IN_FLIGHT"
            )
        end

        -- Fallback temporal somente se 0x104C sair do dominio validado 0/1.
        if fallback_class == "CPU_BALL_IN_FLIGHT" then
            local px, py = players.xy(my_base)
            local target = interception.target(
                px,
                py,
                bx,
                by,
                possession_context.ball_dx,
                possession_context.ball_dy,
                possession_context.ball_speed
            )

            local dx = target.x - px
            local dy = target.y - py
            movement.move_toward(dx, dy)

            local state = make_state(
                my_base, dx, dy, "CPU_BALL_INTERCEPT_FALLBACK",
                possession, gs
            )
            state.intercept_target_x = target.x
            state.intercept_target_y = target.y
            state.intercept_lead_frames = target.lead_frames
            state.intercept_lead_x = target.lead_x
            state.intercept_lead_y = target.lead_y
            state.intercept_predictive = target.predictive
            state.intercept_player_ball_distance =
                target.player_ball_distance
            state.intercept_clipped = target.clipped

            return attach_live_state(
                state,
                "TEMPORAL_FALLBACK",
                fallback_class
            )
        end

        if fallback_class == "MY_BALL_IN_FLIGHT" then
            return attach_live_state(
                make_state(
                    my_base, 0, 0, "MY_BALL_IN_FLIGHT_FALLBACK",
                    possession, gs
                ),
                "TEMPORAL_FALLBACK",
                fallback_class
            )
        end

        local px, py = players.xy(my_base)
        local dx = bx - px
        local dy = by - py
        movement.move_toward(dx, dy)

        return attach_live_state(
            make_state(
                my_base, dx, dy, "LIVE_FALLBACK_CHASE", possession, gs
            ),
            "TEMPORAL_FALLBACK",
            fallback_class
        )
    end

    possession_context.reset()

    if game_state.is_restart(gs) then
        restart.assign(bx, by, my_base)

        if restart.taker_team == "MY" then
            return make_state(
                my_base, nil, nil, "RESTART_ATTACK", possession, gs
            )
        end

        if restart.taker_team == "CPU" and restart.mark_target ~= nil then
            local mx, my = players.xy(my_base)
            local tx, ty = players.xy(restart.mark_target)
            local dx = tx - mx
            local dy = ty - my

            movement.move_toward(dx, dy)

            return make_state(
                my_base, dx, dy, "RESTART_DEFENSE", possession, gs
            )
        end

        return make_state(
            my_base, nil, nil, "RESTART_MANUAL", possession, gs
        )
    end

    restart.clear()
    movement.stop()
    return make_state(
        my_base, nil, nil, "UNKNOWN_GAME_STATE", possession, gs
    )
end

console.log("[ISSD] Modular bot carregado")
console.log("[ISSD] K = bot ON/OFF")
console.log("[ISSD] L = stop_on_possession ON/OFF")
console.log("[ISSD] GameplayActive 0x0006: 1=active, other=BOT_IDLE")
console.log("[ISSD] Game_State: 0=live, 1=endline, 2=throw-in, 3=foul, 4=offside, 5=post-goal")
console.log("[ISSD] marking_score normalized: 35% me + 25% ball + 40% goal-axis")
console.log("[ISSD] target lock: 10 frames, switch margin=0.05")
console.log("[ISSD] switch event HUD: 60 frames")
console.log("[ISSD] live: player switch + GK press gate + predictive interception")

while true do
    local keys = input.get()

    if pressed(keys, "K") then
        enabled = not enabled
        restart.clear()
        console.log(string.format(
            "[ISSD] bot %s",
            enabled and "ON" or "OFF"
        ))
    end

    if pressed(keys, "L") then
        stop_on_possession = not stop_on_possession
        console.log(string.format(
            "[ISSD] stop_on_possession %s",
            stop_on_possession and "ON" or "OFF"
        ))
    end

    if enabled then
        overlay.draw(step_bot())
    else
        restart.clear()
        overlay.draw_off()
    end

    previous_keys = keys
    emu.frameadvance()
end
