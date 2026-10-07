-- ISSD Bot - focal field-side watcher
--
-- Candidatos:
--   0x009B  LEFT=0 RIGHT=1
--   0x00CF  LEFT=1 RIGHT=0
--   0x00DD  LEFT=1 RIGHT=0
--
-- Objetivo:
-- validar qual candidato representa lado de campo de forma GLOBAL e estavel.
--
-- O script:
--   * mostra os 3 candidatos em tempo real;
--   * registra apenas transicoes;
--   * inclui contexto de gameplay, game state, posse e controles.
--
-- Hotkeys:
--   C = print snapshot atual
--   R = reset historico/transicoes

memory.usememorydomain("WRAM")

local ADDR = {
    cand_009B = 0x009B,
    cand_00CF = 0x00CF,
    cand_00DD = 0x00DD,

    gameplay_active = 0x0006,
    game_state = 0x00BA,
    player_possession = 0x00A6,
    team_possession = 0x104C,
    my_ctrl = 0x1ACC,
    cpu_ctrl = 0x1AFC,
    my_side_old = 0x056E,
    cpu_side_old = 0x106E,
}

local previous_keys = {}

local last = {
    cand_009B = nil,
    cand_00CF = nil,
    cand_00DD = nil,
}

local transitions = {
    cand_009B = 0,
    cand_00CF = 0,
    cand_00DD = 0,
}

local history = {}

local function pressed(keys, key)
    return keys[key] and not previous_keys[key]
end

local function u8(addr)
    return memory.read_u8(addr)
end

local function u16(addr)
    return memory.read_u16_le(addr)
end

local function snapshot()
    return {
        c009B = u8(ADDR.cand_009B),
        c00CF = u8(ADDR.cand_00CF),
        c00DD = u8(ADDR.cand_00DD),

        ga = u8(ADDR.gameplay_active),
        gs = u16(ADDR.game_state),
        pp = u16(ADDR.player_possession),
        tp = u8(ADDR.team_possession),
        myctrl = u16(ADDR.my_ctrl),
        cpuctrl = u16(ADDR.cpu_ctrl),

        old_my = u8(ADDR.my_side_old),
        old_cpu = u8(ADDR.cpu_side_old),
    }
end

local function context_text(s)
    return string.format(
        "GA=%02X GS=%d P=$%04X TP=%02X MyCtrl=$%04X CPUCtrl=$%04X oldMY=%02X oldCPU=%02X",
        s.ga,
        s.gs,
        s.pp,
        s.tp,
        s.myctrl,
        s.cpuctrl,
        s.old_my,
        s.old_cpu
    )
end

local function push_history(label, old_value, new_value, s)
    table.insert(history, 1, {
        label = label,
        old_value = old_value,
        new_value = new_value,
        context = context_text(s),
    })

    while #history > 8 do
        table.remove(history)
    end
end

local function log_transition(label, old_value, new_value, s)
    console.log(string.format(
        "[FIELD_SIDE_WATCH] %s %02X->%02X | %s",
        label,
        old_value,
        new_value,
        context_text(s)
    ))
end

local function check(label, key, value, s)
    local old = last[key]

    if old == nil then
        last[key] = value
        return
    end

    if value ~= old then
        transitions[key] = transitions[key] + 1
        push_history(label, old, value, s)
        log_transition(label, old, value, s)
        last[key] = value
    end
end

local function print_snapshot(s)
    console.log(string.format(
        "[FIELD_SIDE_WATCH] 009B=%02X 00CF=%02X 00DD=%02X | %s",
        s.c009B,
        s.c00CF,
        s.c00DD,
        context_text(s)
    ))
end

local function reset()
    last.cand_009B = nil
    last.cand_00CF = nil
    last.cand_00DD = nil

    transitions.cand_009B = 0
    transitions.cand_00CF = 0
    transitions.cand_00DD = 0

    history = {}

    console.log("[FIELD_SIDE_WATCH] reset")
end

console.log("[FIELD_SIDE_WATCH] started")
console.log("[FIELD_SIDE_WATCH] candidates: 009B / 00CF / 00DD")
console.log("[FIELD_SIDE_WATCH] C=snapshot | R=reset")
console.log("[FIELD_SIDE_WATCH] test live, GK, restarts, replay/pause, side switch")

while true do
    local s = snapshot()

    check("009B", "cand_009B", s.c009B, s)
    check("00CF", "cand_00CF", s.c00CF, s)
    check("00DD", "cand_00DD", s.c00DD, s)

    gui.text(8, 8, "FIELD SIDE WATCH")
    gui.text(8, 22, string.format(
        "009B=%02X  00CF=%02X  00DD=%02X",
        s.c009B,
        s.c00CF,
        s.c00DD
    ))
    gui.text(8, 36, string.format(
        "Transitions: 009B=%d 00CF=%d 00DD=%d",
        transitions.cand_009B,
        transitions.cand_00CF,
        transitions.cand_00DD
    ))
    gui.text(8, 50, string.format(
        "GA=%02X GS=%d P=$%04X TP=%02X",
        s.ga,
        s.gs,
        s.pp,
        s.tp
    ))
    gui.text(8, 64, string.format(
        "MyCtrl=$%04X CPUCtrl=$%04X",
        s.myctrl,
        s.cpuctrl
    ))
    gui.text(8, 78, string.format(
        "old MySide=%02X CPU=%02X",
        s.old_my,
        s.old_cpu
    ))

    local y = 96
    for i = 1, math.min(5, #history) do
        local h = history[i]
        gui.text(8, y, string.format(
            "%s %02X->%02X",
            h.label,
            h.old_value,
            h.new_value
        ))
        y = y + 14
    end

    local keys = input.get()

    if pressed(keys, "C") then
        print_snapshot(s)
    end

    if pressed(keys, "R") then
        reset()
    end

    previous_keys = keys
    emu.frameadvance()
end
