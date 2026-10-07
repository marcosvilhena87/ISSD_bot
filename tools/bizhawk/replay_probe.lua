-- ISSD Bot - Replay State Probe
--
-- Objetivo:
-- localizar uma flag WRAM que diferencie jogo realmente ativo de replay,
-- pois Game_State (0x00BA) permanece 0 durante RESUME REPLAY.
--
-- Hotkeys:
--   N = capturar gameplay normal (LIVE)
--   V = capturar replay (REPLAY)
--   C = imprimir candidatos ranqueados
--   R = resetar amostras
--
-- Recomendado:
--   5+ amostras LIVE e 5+ amostras REPLAY,
--   variando jogadores, campo e momentos do replay.

local DOMAIN = "WRAM"

local classes = {
    LIVE = { count = 0, reference = nil, stable = nil },
    REPLAY = { count = 0, reference = nil, stable = nil },
}

local previous_keys = {}

local function pressed(keys, key)
    return keys[key] and not previous_keys[key]
end

local function read_wram()
    local size = memory.getmemorydomainsize(DOMAIN)
    local out = {}

    for addr = 0, size - 1 do
        out[addr] = memory.read_u8(addr, DOMAIN)
    end

    return out
end

local function reset()
    classes = {
        LIVE = { count = 0, reference = nil, stable = nil },
        REPLAY = { count = 0, reference = nil, stable = nil },
    }
    console.log("[REPLAY_PROBE] reset")
end

local function capture(name)
    local state = read_wram()
    local class = classes[name]

    if class.count == 0 then
        class.reference = state
        class.stable = {}

        for addr = 0, #state do
            class.stable[addr] = true
        end
    else
        for addr, keep in pairs(class.stable) do
            if keep and state[addr] ~= class.reference[addr] then
                class.stable[addr] = false
            end
        end
    end

    class.count = class.count + 1

    console.log(string.format(
        "[REPLAY_PROBE] %s sample #%d",
        name,
        class.count
    ))
end

local function simple_score(live_value, replay_value, addr)
    local score = 0

    -- Flags binárias / boolean-like primeiro.
    local pair =
        (live_value == 0 and replay_value == 1)
        or (live_value == 1 and replay_value == 0)

    if pair then
        score = score + 1000
    end

    local ff_pair =
        (live_value == 0 and replay_value == 255)
        or (live_value == 255 and replay_value == 0)

    if ff_pair then
        score = score + 800
    end

    -- Valores pequenos costumam ser flags/modos.
    if live_value <= 7 and replay_value <= 7 then
        score = score + 300
    end

    -- Preferência leve por região baixa/global da WRAM.
    if addr < 0x0500 then
        score = score + 100
    elseif addr < 0x2000 then
        score = score + 30
    end

    return score
end

local function collect_candidates()
    local out = {}

    if classes.LIVE.count == 0 or classes.REPLAY.count == 0 then
        return out
    end

    local size = memory.getmemorydomainsize(DOMAIN)

    for addr = 0, size - 1 do
        local live_stable =
            classes.LIVE.stable ~= nil
            and classes.LIVE.stable[addr] == true

        local replay_stable =
            classes.REPLAY.stable ~= nil
            and classes.REPLAY.stable[addr] == true

        if live_stable and replay_stable then
            local a = classes.LIVE.reference[addr]
            local b = classes.REPLAY.reference[addr]

            if a ~= b then
                out[#out + 1] = {
                    addr = addr,
                    live = a,
                    replay = b,
                    score = simple_score(a, b, addr),
                }
            end
        end
    end

    table.sort(out, function(a, b)
        if a.score == b.score then
            return a.addr < b.addr
        end
        return a.score > b.score
    end)

    return out
end

local function print_candidates()
    if classes.LIVE.count == 0 or classes.REPLAY.count == 0 then
        console.log(string.format(
            "[REPLAY_PROBE] faltam amostras LIVE=%d REPLAY=%d",
            classes.LIVE.count,
            classes.REPLAY.count
        ))
        return
    end

    local candidates = collect_candidates()

    console.log(string.format(
        "[REPLAY_PROBE] candidates=%d | LIVE=%d REPLAY=%d",
        #candidates,
        classes.LIVE.count,
        classes.REPLAY.count
    ))

    local limit = math.min(30, #candidates)

    for i = 1, limit do
        local c = candidates[i]
        console.log(string.format(
            "  #%02d $%05X LIVE=%02X (%d) REPLAY=%02X (%d) score=%d",
            i,
            c.addr,
            c.live,
            c.live,
            c.replay,
            c.replay,
            c.score
        ))
    end

    if #candidates > limit then
        console.log(string.format(
            "  ... mostrando Top %d de %d; capture mais amostras para reduzir",
            limit,
            #candidates
        ))
    end
end

local function draw_hud()
    gui.text(8, 8, "REPLAY STATE PROBE")
    gui.text(8, 22, string.format(
        "LIVE samples: %d",
        classes.LIVE.count
    ))
    gui.text(8, 36, string.format(
        "REPLAY samples: %d",
        classes.REPLAY.count
    ))
    gui.text(8, 50, "N=LIVE  V=REPLAY  C=print  R=reset")
    gui.text(8, 64, "Goal: flag stable while Game_State=0 in replay")
end

console.log("[REPLAY_PROBE] started")
console.log("[REPLAY_PROBE] N=LIVE | V=REPLAY | C=print | R=reset")
console.log("[REPLAY_PROBE] capture 5+ samples of each class")

while true do
    local keys = input.get()

    if pressed(keys, "N") then
        capture("LIVE")
    end

    if pressed(keys, "V") then
        capture("REPLAY")
    end

    if pressed(keys, "C") then
        print_candidates()
    end

    if pressed(keys, "R") then
        reset()
    end

    draw_hud()

    previous_keys = keys
    emu.frameadvance()
end
