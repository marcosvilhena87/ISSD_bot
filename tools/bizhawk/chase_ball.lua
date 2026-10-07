-- ISSD Bot - Chase Ball
-- Primeiro bot deterministico do projeto.
--
-- Objetivo:
--   mover o jogador controlado em direcao a bola usando coordenadas de mundo.
--
-- IMPORTANTE:
--   use inicialmente em uma partida de teste/savestate.
--   Este script assume Player 1 como o time humano.
--
-- Teclas:
--   K = liga/desliga o bot
--   L = alterna stop_on_possession
--
-- O bot para de perseguir quando o jogador controlado conquista a posse,
-- caso stop_on_possession esteja habilitado.

local DOMAIN = "WRAM"
local PLAYER = 1

local ADDR = {
    ball_x = 0x042A,
    ball_y = 0x042C,
    possession = 0x00A6,
    my_ctrl = 0x1ACC,
}

local OFFSET = {
    world_x = 0x2A,
    world_y = 0x2C,
}

local enabled = false
local stop_on_possession = true
local previous_keys = {}

-- Zona morta em unidades de coordenada de mundo.
-- Evita oscilar excessivamente quando jogador e bola estao quase alinhados.
local DEADZONE_X = 8
local DEADZONE_Y = 8

local function s16(addr)
    return memory.read_s16_le(addr, DOMAIN)
end

local function u16(addr)
    return memory.read_u16_le(addr, DOMAIN)
end

local function pressed(keys, key)
    return keys[key] and not previous_keys[key]
end

local function valid_player_base(base)
    return base >= 0x0500
       and base <= 0x0F00
       and base % 0x100 == 0
end

local function decode_my_player(base)
    if base == 0x0D00 then return "Beranco" end
    if base == 0x0E00 then return "Gomez" end
    if base == 0x0F00 then return "Allejo" end
    if base == 0x0500 then return "GK" end
    return string.format("$%04X", base)
end

local function clear_pad()
    joypad.set({
        Up = false,
        Down = false,
        Left = false,
        Right = false,
        A = false,
        B = false,
        X = false,
        Y = false,
        L = false,
        R = false,
        Start = false,
        Select = false,
    }, PLAYER)
end

local function chase()
    local base = u16(ADDR.my_ctrl)

    if not valid_player_base(base) then
        clear_pad()
        return nil, nil, nil, "invalid MyCtrl"
    end

    local possession = u16(ADDR.possession)

    if stop_on_possession and possession == base then
        clear_pad()
        return 0, 0, base, "possession acquired"
    end

    local px = s16(base + OFFSET.world_x)
    local py = s16(base + OFFSET.world_y)

    local bx = s16(ADDR.ball_x)
    local by = s16(ADDR.ball_y)

    local dx = bx - px
    local dy = by - py

    local pad = {
        Up = false,
        Down = false,
        Left = false,
        Right = false,
    }

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

    joypad.set(pad, PLAYER)

    return dx, dy, base, "chasing"
end

console.log("[ISSD] Chase Ball carregado")
console.log("[ISSD] K = bot ON/OFF")
console.log("[ISSD] L = stop_on_possession ON/OFF")

while true do
    local keys = input.get()

    if pressed(keys, "K") then
        enabled = not enabled
        clear_pad()
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
        local dx, dy, base, status = chase()

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
    else
        clear_pad()
        gui.text(8, 8, "ISSD CHASE BOT: OFF (K)")
    end

    previous_keys = keys
    emu.frameadvance()
end