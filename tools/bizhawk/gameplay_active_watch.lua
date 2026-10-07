-- ISSD Bot - Gameplay Active Watch
--
-- Valida WRAM 0x0006 como candidato a "gameplay realmente ativo".
--
-- Hipotese atual:
--   1 = gameplay ativo
--   0 = replay / pause / jogo nao ativo
--
-- O console registra somente transicoes de 0x0006.

local DOMAIN = "WRAM"

local ADDR = {
    gameplay_active = 0x0006,
    game_state = 0x00BA,
    team_possession = 0x104C,
    player_possession = 0x00A6,
    ball_x = 0x042A,
    ball_y = 0x042C,
    my_ctrl = 0x1ACC,
    cpu_ctrl = 0x1AFC,
    my_side = 0x056E,
    cpu_side = 0x106E,
}

local previous_value = nil
local transition_count = 0
local last_transition_text = "none"
local last_transition_age = 0

local function u8(addr)
    return memory.read_u8(addr, DOMAIN)
end

local function u16(addr)
    return memory.read_u16_le(addr, DOMAIN)
end

local function s16(addr)
    return memory.read_s16_le(addr, DOMAIN)
end

local function decode(value)
    if value == 1 then
        return "ACTIVE?"
    elseif value == 0 then
        return "INACTIVE?"
    end
    return "OTHER"
end

local function snapshot()
    return {
        gameplay_active = u8(ADDR.gameplay_active),
        game_state = u16(ADDR.game_state),
        team_possession = u8(ADDR.team_possession),
        player_possession = u16(ADDR.player_possession),
        ball_x = s16(ADDR.ball_x),
        ball_y = s16(ADDR.ball_y),
        my_ctrl = u16(ADDR.my_ctrl),
        cpu_ctrl = u16(ADDR.cpu_ctrl),
        my_side = u8(ADDR.my_side),
        cpu_side = u8(ADDR.cpu_side),
    }
end

local function log_transition(old_value, state)
    transition_count = transition_count + 1
    last_transition_age = 0

    last_transition_text = string.format(
        "%d->%d GS=%d TP=%d P=$%04X",
        old_value,
        state.gameplay_active,
        state.game_state,
        state.team_possession,
        state.player_possession
    )

    console.log(string.format(
        "[GAMEPLAY_WATCH] #%d 0x0006 %d -> %d | GS=%d TP=%d P=$%04X Ball=(%d,%d) MyCtrl=$%04X CPUCtrl=$%04X Side=%d/%d",
        transition_count,
        old_value,
        state.gameplay_active,
        state.game_state,
        state.team_possession,
        state.player_possession,
        state.ball_x,
        state.ball_y,
        state.my_ctrl,
        state.cpu_ctrl,
        state.my_side,
        state.cpu_side
    ))
end

local function draw(state)
    gui.text(8, 8, "GAMEPLAY ACTIVE WATCH 0x0006")
    gui.text(8, 22, string.format(
        "Gameplay=$%02X (%s)",
        state.gameplay_active,
        decode(state.gameplay_active)
    ))
    gui.text(8, 36, string.format(
        "Game_State=%d TeamPoss=$%02X",
        state.game_state,
        state.team_possession
    ))
    gui.text(8, 50, string.format(
        "PlayerPoss=$%04X",
        state.player_possession
    ))
    gui.text(8, 64, string.format(
        "Ball=(%d,%d)",
        state.ball_x,
        state.ball_y
    ))
    gui.text(8, 78, string.format(
        "MyCtrl=$%04X CPUCtrl=$%04X",
        state.my_ctrl,
        state.cpu_ctrl
    ))
    gui.text(8, 92, string.format(
        "Side MY=%d CPU=%d",
        state.my_side,
        state.cpu_side
    ))
    gui.text(8, 106, string.format(
        "Transitions=%d",
        transition_count
    ))
    gui.text(8, 120, string.format(
        "Last[%d]: %s",
        last_transition_age,
        last_transition_text
    ))
end

console.log("[GAMEPLAY_WATCH] focused probe started")
console.log("[GAMEPLAY_WATCH] candidate: WRAM 0x0006 (u8)")
console.log("[GAMEPLAY_WATCH] hypothesis: 1=ACTIVE, 0=INACTIVE")

while true do
    local state = snapshot()

    if previous_value == nil then
        previous_value = state.gameplay_active
        console.log(string.format(
            "[GAMEPLAY_WATCH] initial 0x0006=%d (%s)",
            state.gameplay_active,
            decode(state.gameplay_active)
        ))
    elseif state.gameplay_active ~= previous_value then
        log_transition(previous_value, state)
        previous_value = state.gameplay_active
    else
        last_transition_age = last_transition_age + 1
    end

    draw(state)
    emu.frameadvance()
end
