-- ISSD Bot - Focused Team Possession Watch
--
-- Valida o candidato WRAM 0x104C como posse lógica por equipe.
--
-- HUD em tempo real:
--   TeamCandidate 0x104C
--   PlayerPoss    0x00A6
--   Game_State    0x00BA
--   Ball X/Y
--   MyCtrl / CPUCtrl
--
-- O console registra toda mudança de 0x104C com o contexto do frame.

local DOMAIN = "WRAM"

local ADDR = {
    team_candidate = 0x104C,
    player_possession = 0x00A6,
    game_state = 0x00BA,
    ball_x = 0x042A,
    ball_y = 0x042C,
    my_ctrl = 0x1ACC,
    cpu_ctrl = 0x1AFC,
    my_side = 0x056E,
    cpu_side = 0x106E,
}

local previous_candidate = nil
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

local function decode_team(value)
    if value == 0 then
        return "MY?"
    elseif value == 1 then
        return "CPU?"
    end
    return "OTHER"
end

local function snapshot()
    return {
        candidate = u8(ADDR.team_candidate),
        possession = u16(ADDR.player_possession),
        game_state = u16(ADDR.game_state),
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
        "%d->%d P=$%04X GS=%d Ball=(%d,%d)",
        old_value,
        state.candidate,
        state.possession,
        state.game_state,
        state.ball_x,
        state.ball_y
    )

    console.log(string.format(
        "[TEAM_WATCH] #%d 0x104C %d -> %d | P=$%04X GS=%d Ball=(%d,%d) MyCtrl=$%04X CPUCtrl=$%04X Side=%d/%d",
        transition_count,
        old_value,
        state.candidate,
        state.possession,
        state.game_state,
        state.ball_x,
        state.ball_y,
        state.my_ctrl,
        state.cpu_ctrl,
        state.my_side,
        state.cpu_side
    ))
end

local function draw(state)
    gui.text(8, 8, "TEAM POSSESSION WATCH 0x104C")
    gui.text(8, 22, string.format(
        "TeamCandidate=$%02X (%s)",
        state.candidate,
        decode_team(state.candidate)
    ))
    gui.text(8, 36, string.format(
        "PlayerPoss=$%04X  Game_State=%d",
        state.possession,
        state.game_state
    ))
    gui.text(8, 50, string.format(
        "Ball=(%d,%d)",
        state.ball_x,
        state.ball_y
    ))
    gui.text(8, 64, string.format(
        "MyCtrl=$%04X CPUCtrl=$%04X",
        state.my_ctrl,
        state.cpu_ctrl
    ))
    gui.text(8, 78, string.format(
        "Side MY=%d CPU=%d",
        state.my_side,
        state.cpu_side
    ))
    gui.text(8, 92, string.format(
        "Transitions=%d",
        transition_count
    ))
    gui.text(8, 106, string.format(
        "Last[%d]: %s",
        last_transition_age,
        last_transition_text
    ))
end

console.log("[TEAM_WATCH] focused probe started")
console.log("[TEAM_WATCH] candidate: WRAM 0x104C (u8)")
console.log("[TEAM_WATCH] hypothesis: 0=MY, 1=CPU")

while true do
    local state = snapshot()

    if previous_candidate == nil then
        previous_candidate = state.candidate
        console.log(string.format(
            "[TEAM_WATCH] initial 0x104C=%d (%s)",
            state.candidate,
            decode_team(state.candidate)
        ))
    elseif state.candidate ~= previous_candidate then
        log_transition(previous_candidate, state)
        previous_candidate = state.candidate
    else
        last_transition_age = last_transition_age + 1
    end

    draw(state)
    emu.frameadvance()
end
