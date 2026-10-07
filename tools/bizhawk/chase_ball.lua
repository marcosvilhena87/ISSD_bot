-- ISSD Bot - Chase Ball
-- Controle hibrido: perseguição normal + controle manual com posse +
-- comportamento defensivo inteligente em reposicoes, usando Game_State.
--
-- Teclas:
--   K = liga/desliga o bot
--   L = alterna stop_on_possession
--
-- Estados:
--   CHASING            -> persegue a bola em jogo normal
--   POSSESSION_MANUAL  -> jogador tem a bola; controle 100% manual
--   RESTART_ATTACK     -> reposicao a favor; controle 100% manual
--   RESTART_DEFENSE    -> reposicao contra; marca adversario sem bola
--
-- Estrutura RAM validada:
--   bola world X/Y:       0x042A / 0x042C
--   possession:           0x00A6
--   MyCtrl:               0x1ACC
--   jogadores MY:         0x0500..0x0F00, stride 0x100
--   jogadores CPU:        0x1000..0x1A00, stride 0x100
--   player world X/Y:     base + 0x2A / base + 0x2C
--   Game_State:             0x00BA
--       0 = bola em jogo
--       1 = reposicao pela linha de fundo (goal kick ou corner)
--       2 = reposicao pela lateral

local DOMAIN = "WRAM"
local PLAYER = 1

local ADDR = {
    ball_x = 0x042A,
    ball_y = 0x042C,
    possession = 0x00A6,
    game_state = 0x00BA,
    my_ctrl = 0x1ACC,
}

local OFFSET = {
    world_x = 0x2A,
    world_y = 0x2C,
}

local MY_FIRST = 0x0500
local MY_LAST  = 0x0F00
local CPU_FIRST = 0x1000
local CPU_LAST  = 0x1A00
local PLAYER_STRIDE = 0x100

local enabled = false
local stop_on_possession = true
local previous_keys = {}

local DEADZONE_X = 8
local DEADZONE_Y = 8

-- Game_State e a fonte primaria para detectar reposicoes.
-- A geometria e usada apenas para identificar o provavel cobrador e,
-- em reposicao contra, escolher quem marcar.
local restart_taker = nil
local restart_taker_team = nil
local restart_mark_target = nil

local function s16(addr)
    return memory.read_s16_le(addr, DOMAIN)
end

local function u16(addr)
    return memory.read_u16_le(addr, DOMAIN)
end

local function pressed(keys, key)
    return keys[key] and not previous_keys[key]
end

local function valid_my_player_base(base)
    return base >= MY_FIRST
       and base <= MY_LAST
       and base % PLAYER_STRIDE == 0
end

local function valid_cpu_player_base(base)
    return base >= CPU_FIRST
       and base <= CPU_LAST
       and base % PLAYER_STRIDE == 0
end

local function decode_my_player(base)
    if base == 0x0D00 then return "Beranco" end
    if base == 0x0E00 then return "Gomez" end
    if base == 0x0F00 then return "Allejo" end
    if base == 0x0500 then return "GK" end
    return string.format("$%04X", base)
end

local function decode_any_player(base)
    if base == nil then return "none" end

    if valid_my_player_base(base) then
        return "MY " .. decode_my_player(base)
    end

    if valid_cpu_player_base(base) then
        local slot = math.floor((base - CPU_FIRST) / PLAYER_STRIDE)
        if slot == 0 then
            return "CPU GK"
        end
        return string.format("CPU slot %d", slot + 1)
    end

    return string.format("$%04X", base)
end

local function player_xy(base)
    return s16(base + OFFSET.world_x), s16(base + OFFSET.world_y)
end

local function dist2(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return dx * dx + dy * dy
end

local function direction_pad(dx, dy)
    local pad = {}

    if dx > DEADZONE_X then
        pad.Right = true
    elseif dx < -DEADZONE_X then
        pad.Left = true
    end

    if dy > DEADZONE_Y then
        pad.Down = true
    elseif dy < -DEADZONE_Y then
        pad.Up = true
    end

    return pad
end

-- Retorna o jogador (MY ou CPU) mais proximo de um ponto do campo.
local function nearest_player_to_point(x, y)
    local best_base = nil
    local best_team = nil
    local best_d2 = nil

    for base = MY_FIRST, MY_LAST, PLAYER_STRIDE do
        local px, py = player_xy(base)
        local d2 = dist2(px, py, x, y)
        if best_d2 == nil or d2 < best_d2 then
            best_d2 = d2
            best_base = base
            best_team = "MY"
        end
    end

    for base = CPU_FIRST, CPU_LAST, PLAYER_STRIDE do
        local px, py = player_xy(base)
        local d2 = dist2(px, py, x, y)
        if best_d2 == nil or d2 < best_d2 then
            best_d2 = d2
            best_base = base
            best_team = "CPU"
        end
    end

    return best_base, best_team, best_d2
end

-- Em reposicao contra, escolhe o adversario sem bola mais proximo
-- do jogador que estamos controlando. O cobrador e excluido.
local function nearest_cpu_mark_target(my_base, excluded_base)
    local mx, my = player_xy(my_base)
    local best_base = nil
    local best_d2 = nil

    for base = CPU_FIRST, CPU_LAST, PLAYER_STRIDE do
        if base ~= excluded_base then
            local px, py = player_xy(base)
            local d2 = dist2(mx, my, px, py)
            if best_d2 == nil or d2 < best_d2 then
                best_d2 = d2
                best_base = base
            end
        end
    end

    return best_base, best_d2
end

local function clear_restart_assignment()
    restart_taker = nil
    restart_taker_team = nil
    restart_mark_target = nil
end

local function assign_restart_roles(ball_x, ball_y, my_base)
    local taker, team = nearest_player_to_point(ball_x, ball_y)

    restart_taker = taker
    restart_taker_team = team

    if team == "CPU" and taker ~= nil then
        restart_mark_target = nearest_cpu_mark_target(my_base, taker)
    else
        restart_mark_target = nil
    end
end

local function restart_kind(game_state)
    if game_state == 1 then
        return "ENDLINE"
    elseif game_state == 2 then
        return "THROW_IN"
    end
    return "NONE"
end

local function step_bot()
    local my_base = u16(ADDR.my_ctrl)

    if not valid_my_player_base(my_base) then
        clear_restart_assignment()
        return nil, nil, nil, "INVALID_MYCTRL", 0, 0
    end

    local possession = u16(ADDR.possession)
    local game_state = u16(ADDR.game_state)

    local bx = s16(ADDR.ball_x)
    local by = s16(ADDR.ball_y)

    -- Game_State == 0: bola em jogo.
    if game_state == 0 then
        clear_restart_assignment()

        if stop_on_possession and possession == my_base then
            return 0, 0, my_base, "POSSESSION_MANUAL",
                   possession, game_state
        end

        local px, py = player_xy(my_base)
        local dx = bx - px
        local dy = by - py

        joypad.set(direction_pad(dx, dy), PLAYER)

        return dx, dy, my_base, "CHASING",
               possession, game_state
    end

    -- Game_State 1 ou 2: reposicao confirmada pela RAM.
    -- A geometria agora serve apenas para identificar o cobrador.
    assign_restart_roles(bx, by, my_base)

    if restart_taker_team == "MY" then
        return nil, nil, my_base, "RESTART_ATTACK",
               possession, game_state
    end

    if restart_taker_team == "CPU"
       and restart_mark_target ~= nil then

        local mx, my = player_xy(my_base)
        local tx, ty = player_xy(restart_mark_target)
        local dx = tx - mx
        local dy = ty - my

        joypad.set(direction_pad(dx, dy), PLAYER)

        return dx, dy, my_base, "RESTART_DEFENSE",
               possession, game_state
    end

    return nil, nil, my_base, "RESTART_MANUAL",
           possession, game_state
end

console.log("[ISSD] Chase Ball carregado")
console.log("[ISSD] K = bot ON/OFF")
console.log("[ISSD] L = stop_on_possession ON/OFF")
console.log("[ISSD] restart detector: Game_State @ WRAM 0x00BA")
console.log("[ISSD] Game_State: 0=live, 1=endline, 2=throw-in")

while true do
    local keys = input.get()

    if pressed(keys, "K") then
        enabled = not enabled
        clear_restart_assignment()
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
        local dx, dy, base, status, possession, game_state = step_bot()

        gui.text(8, 8, "ISSD CHASE BOT: ON")
        gui.text(8, 22, string.format(
            "Player: %s",
            base and decode_my_player(base) or "?"
        ))
        gui.text(8, 36, string.format(
            "Delta: (%s,%s)",
            tostring(dx),
            tostring(dy)
        ))
        gui.text(8, 50, string.format(
            "Status: %s",
            status or "?"
        ))
        gui.text(8, 64, string.format(
            "Game_State=%d (%s) Possession=$%04X",
            game_state or -1,
            restart_kind(game_state or -1),
            possession or 0
        ))

        if game_state ~= nil and game_state ~= 0 then
            gui.text(8, 78, string.format(
                "Restart taker: %s",
                decode_any_player(restart_taker)
            ))

            if restart_mark_target ~= nil then
                gui.text(8, 92, string.format(
                    "Mark target: %s",
                    decode_any_player(restart_mark_target)
                ))
            end
        end
    else
        gui.text(8, 8, "ISSD CHASE BOT: OFF (K) - manual control")
    end

    previous_keys = keys
    emu.frameadvance()
end
