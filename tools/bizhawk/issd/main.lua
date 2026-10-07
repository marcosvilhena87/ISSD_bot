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
local Movement = dofile(DIR .. "movement.lua")
local Geometry = dofile(DIR .. "geometry.lua")
local Defense = dofile(DIR .. "defense.lua")
local LiveDefense = dofile(DIR .. "live_defense.lua")
local Restart = dofile(DIR .. "restart.lua")
local Overlay = dofile(DIR .. "overlay.lua")

local mem = Memory.new(config)
local players = Players.new(config, mem)
local ball = Ball.new(config, mem)
local game_state = GameState.new(config, mem)
local movement = Movement.new(config)
local defense = Defense.new(config, players, Geometry, mem)
local live_defense = LiveDefense.new(config, players, mem)
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
    }
end

local function step_bot()
    local my_base = read_my_base()

    if not players.valid_my_base(my_base) then
        restart.clear()
        return make_state(my_base, nil, nil, "INVALID_MYCTRL", 0, 0)
    end

    local possession = ball.possession()
    local gs = game_state.read()
    local bx, by = ball.world_xy()

    if game_state.is_live(gs) then
        restart.clear()

        -- Posse de qualquer jogador do nosso time:
        -- nao perseguir o proprio companheiro; devolve controle ao humano.
        if players.valid_my_base(possession) then
            return make_state(
                my_base, 0, 0, "POSSESSION_MANUAL", possession, gs
            )
        end

        -- Bola livre: perseguicao direta continua sendo o baseline.
        if possession == 0 then
            local px, py = players.xy(my_base)
            local dx = bx - px
            local dy = by - py
            movement.move_toward(dx, dy)

            return make_state(
                my_base, dx, dy, "LOOSE_BALL_CHASE", possession, gs
            )
        end

        -- CPU com posse: defender do lado do nosso gol em vez de
        -- perseguir cegamente a posicao atual da bola.
        if players.valid_cpu_base(possession) then
            local live = live_defense.target_for_carrier(possession)

            if live ~= nil then
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
                return state
            end
        end

        -- Fallback conservador para valores de posse ainda nao mapeados.
        local px, py = players.xy(my_base)
        local dx = bx - px
        local dy = by - py
        movement.move_toward(dx, dy)

        return make_state(
            my_base, dx, dy, "LIVE_FALLBACK_CHASE", possession, gs
        )
    end

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
    return make_state(
        my_base, nil, nil, "UNKNOWN_GAME_STATE", possession, gs
    )
end

console.log("[ISSD] Modular bot carregado")
console.log("[ISSD] K = bot ON/OFF")
console.log("[ISSD] L = stop_on_possession ON/OFF")
console.log("[ISSD] Game_State: 0=live, 1=endline, 2=throw-in")
console.log("[ISSD] marking_score normalized: 35% me + 25% ball + 40% goal-axis")
console.log("[ISSD] target lock: 10 frames, switch margin=0.05")
console.log("[ISSD] switch event HUD: 60 frames")
console.log("[ISSD] live: possession 0=LOOSE_BALL_CHASE, CPU=LIVE_DEFENSE")

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
