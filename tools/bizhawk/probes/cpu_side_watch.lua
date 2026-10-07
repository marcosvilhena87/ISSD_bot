-- ISSD Bot - CPU_Side focal validation watcher
--
-- Objetivo:
-- validar WRAM 0x106E como fonte estavel de orientacao do campo.
--
-- Hipotese:
--   CPU_Side = 0 -> CPU ocupa/defende esquerda -> MY ataca esquerda? validar visualmente
--   CPU_Side = 1 -> CPU ocupa/defende direita
--
-- Para o bot, se 0x106E for estavel em 0/1:
--   My_Side = 1 - CPU_Side
--
-- Comparacoes:
--   0x106E = candidato principal
--   0x009B = candidato global correlacionado, mas com FF transitorio
--   0x056E = candidato antigo instavel
--
-- Hotkeys:
--   C = snapshot atual
--   R = reset contadores/historico

memory.usememorydomain("WRAM")

local ADDR = {
    cpu_side = 0x106E,
    cand_009B = 0x009B,
    old_my_side = 0x056E,

    gameplay_active = 0x0006,
    game_state = 0x00BA,
    player_possession = 0x00A6,
    team_possession = 0x104C,
    my_ctrl = 0x1ACC,
    cpu_ctrl = 0x1AFC,
}

local previous_keys = {}

local last = {
    cpu_side = nil,
    cand_009B = nil,
    old_my_side = nil,
}

local transitions = {
    cpu_side = 0,
    cand_009B = 0,
    old_my_side = 0,
}

local invalid_cpu_side_frames = 0
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
        cpu_side = u8(ADDR.cpu_side),
        cand_009B = u8(ADDR.cand_009B),
        old_my_side = u8(ADDR.old_my_side),

        ga = u8(ADDR.gameplay_active),
        gs = u16(ADDR.game_state),
        pp = u16(ADDR.player_possession),
        tp = u8(ADDR.team_possession),
        myctrl = u16(ADDR.my_ctrl),
        cpuctrl = u16(ADDR.cpu_ctrl),
    }
end

local function derived_my_side(cpu_side)
    if cpu_side == 0 then return 1 end
    if cpu_side == 1 then return 0 end
    return nil
end

local function context_text(s)
    return string.format(
        "GA=%02X GS=%d P=$%04X TP=%02X MyCtrl=$%04X CPUCtrl=$%04X",
        s.ga,
        s.gs,
        s.pp,
        s.tp,
        s.myctrl,
        s.cpuctrl
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

local function check(label, key, value, s)
    local old = last[key]

    if old == nil then
        last[key] = value
        return
    end

    if value ~= old then
        transitions[key] = transitions[key] + 1
        push_history(label, old, value, s)

        console.log(string.format(
            "[CPU_SIDE_WATCH] %s %02X->%02X | %s",
            label,
            old,
            value,
            context_text(s)
        ))

        last[key] = value
    end
end

local function print_snapshot(s)
    local my_side = derived_my_side(s.cpu_side)

    console.log(string.format(
        "[CPU_SIDE_WATCH] CPU=%02X derivedMY=%s 009B=%02X oldMY=%02X | %s",
        s.cpu_side,
        my_side == nil and "INVALID" or tostring(my_side),
        s.cand_009B,
        s.old_my_side,
        context_text(s)
    ))
end

local function reset()
    last.cpu_side = nil
    last.cand_009B = nil
    last.old_my_side = nil

    transitions.cpu_side = 0
    transitions.cand_009B = 0
    transitions.old_my_side = 0

    invalid_cpu_side_frames = 0
    history = {}

    console.log("[CPU_SIDE_WATCH] reset")
end

console.log("[CPU_SIDE_WATCH] started")
console.log("[CPU_SIDE_WATCH] primary=0x106E | compare=0x009B oldMY=0x056E")
console.log("[CPU_SIDE_WATCH] C=snapshot | R=reset")
console.log("[CPU_SIDE_WATCH] test LIVE/GK/restarts/replay/halftime/side switch")

while true do
    local s = snapshot()

    check("CPU_SIDE", "cpu_side", s.cpu_side, s)
    check("009B", "cand_009B", s.cand_009B, s)
    check("OLD_MY", "old_my_side", s.old_my_side, s)

    if s.cpu_side ~= 0 and s.cpu_side ~= 1 then
        invalid_cpu_side_frames = invalid_cpu_side_frames + 1
    end

    local derived = derived_my_side(s.cpu_side)

    gui.text(8, 8, "CPU SIDE WATCH 0x106E")
    gui.text(8, 22, string.format(
        "CPU=%02X  derived MY=%s",
        s.cpu_side,
        derived == nil and "INVALID" or tostring(derived)
    ))
    gui.text(8, 36, string.format(
        "009B=%02X  oldMY=%02X",
        s.cand_009B,
        s.old_my_side
    ))
    gui.text(8, 50, string.format(
        "Transitions CPU=%d 009B=%d oldMY=%d",
        transitions.cpu_side,
        transitions.cand_009B,
        transitions.old_my_side
    ))
    gui.text(8, 64, string.format(
        "Invalid CPU_Side frames=%d",
        invalid_cpu_side_frames
    ))
    gui.text(8, 78, string.format(
        "GA=%02X GS=%d P=$%04X TP=%02X",
        s.ga,
        s.gs,
        s.pp,
        s.tp
    ))
    gui.text(8, 92, string.format(
        "MyCtrl=$%04X CPUCtrl=$%04X",
        s.myctrl,
        s.cpuctrl
    ))

    local y = 110
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
