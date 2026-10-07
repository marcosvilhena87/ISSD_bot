-- ISSD Bot - Team Possession Probe
--
-- Objetivo:
-- localizar uma flag de posse POR EQUIPE que continue valida durante passes,
-- mesmo quando Player_Ball_Possession (0x00A6) cai para 0.
--
-- Quatro classes:
--   Y = MY_CONTROLLED  (meu time conduzindo)
--   U = MY_PASS        (passe do meu time, bola desprendida)
--   I = CPU_CONTROLLED (CPU conduzindo)
--   O = CPU_PASS       (passe da CPU, bola desprendida)
--
-- Outros:
--   P = imprimir candidatos
--   R = resetar amostras
--
-- Melhor resultado: capture 3+ amostras de cada classe, em jogadores,
-- regioes do campo e momentos diferentes.
--
-- Regra procurada:
--   MY_CONTROLLED == MY_PASS
--   CPU_CONTROLLED == CPU_PASS
--   MY_* ~= CPU_*
--
-- O scanner testa candidatos u8 e u16 little-endian em toda a WRAM.

local DOMAIN = "WRAM"

local CLASS_ORDER = {
    "MY_CONTROLLED",
    "MY_PASS",
    "CPU_CONTROLLED",
    "CPU_PASS",
}

local HOTKEY = {
    Y = "MY_CONTROLLED",
    U = "MY_PASS",
    I = "CPU_CONTROLLED",
    O = "CPU_PASS",
}

local classes = {}
local previous_keys = {}
local last_candidate_count_u8 = 0
local last_candidate_count_u16 = 0

local function new_class()
    return {
        count = 0,
        reference = nil,
        stable = nil,
    }
end

local function reset()
    classes = {}
    for _, name in ipairs(CLASS_ORDER) do
        classes[name] = new_class()
    end
    last_candidate_count_u8 = 0
    last_candidate_count_u16 = 0
    console.log("[TEAM_POSSESSION] reset")
end

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
        "[TEAM_POSSESSION] %s sample #%d",
        name,
        class.count
    ))
end

local function ready()
    for _, name in ipairs(CLASS_ORDER) do
        if classes[name].count == 0 then
            return false
        end
    end
    return true
end

local function stable_at(class, addr)
    return class.stable ~= nil and class.stable[addr] == true
end

local function u16_from(ref, addr)
    local lo = ref[addr]
    local hi = ref[addr + 1]

    if lo == nil or hi == nil then
        return nil
    end

    return lo + hi * 256
end

local function collect_u8()
    local out = {}

    if not ready() then
        return out
    end

    local myc = classes.MY_CONTROLLED
    local myp = classes.MY_PASS
    local cpuc = classes.CPU_CONTROLLED
    local cpup = classes.CPU_PASS

    local size = memory.getmemorydomainsize(DOMAIN)

    for addr = 0, size - 1 do
        if stable_at(myc, addr)
           and stable_at(myp, addr)
           and stable_at(cpuc, addr)
           and stable_at(cpup, addr) then

            local a = myc.reference[addr]
            local b = myp.reference[addr]
            local c = cpuc.reference[addr]
            local d = cpup.reference[addr]

            if a == b and c == d and a ~= c then
                out[#out + 1] = {
                    addr = addr,
                    my_value = a,
                    cpu_value = c,
                }
            end
        end
    end

    return out
end

local function collect_u16()
    local out = {}

    if not ready() then
        return out
    end

    local myc = classes.MY_CONTROLLED
    local myp = classes.MY_PASS
    local cpuc = classes.CPU_CONTROLLED
    local cpup = classes.CPU_PASS

    local size = memory.getmemorydomainsize(DOMAIN)

    for addr = 0, size - 2 do
        local stable =
            stable_at(myc, addr)
            and stable_at(myc, addr + 1)
            and stable_at(myp, addr)
            and stable_at(myp, addr + 1)
            and stable_at(cpuc, addr)
            and stable_at(cpuc, addr + 1)
            and stable_at(cpup, addr)
            and stable_at(cpup, addr + 1)

        if stable then
            local a = u16_from(myc.reference, addr)
            local b = u16_from(myp.reference, addr)
            local c = u16_from(cpuc.reference, addr)
            local d = u16_from(cpup.reference, addr)

            if a == b and c == d and a ~= c then
                out[#out + 1] = {
                    addr = addr,
                    my_value = a,
                    cpu_value = c,
                }
            end
        end
    end

    return out
end

local function print_candidates()
    if not ready() then
        console.log("[TEAM_POSSESSION] faltam classes:")
        for _, name in ipairs(CLASS_ORDER) do
            console.log(string.format(
                "  %-14s samples=%d",
                name,
                classes[name].count
            ))
        end
        return
    end

    local u8 = collect_u8()
    local u16 = collect_u16()

    last_candidate_count_u8 = #u8
    last_candidate_count_u16 = #u16

    console.log(string.format(
        "[TEAM_POSSESSION] candidates: u8=%d u16=%d",
        #u8,
        #u16
    ))

    console.log("[TEAM_POSSESSION] --- u8 ---")
    for i = 1, math.min(#u8, 100) do
        local c = u8[i]
        console.log(string.format(
            "  $%04X  MY=%02X (%d)  CPU=%02X (%d)",
            c.addr,
            c.my_value,
            c.my_value,
            c.cpu_value,
            c.cpu_value
        ))
    end

    if #u8 > 100 then
        console.log("  ... u8 truncado em 100")
    end

    console.log("[TEAM_POSSESSION] --- u16 little-endian ---")
    for i = 1, math.min(#u16, 100) do
        local c = u16[i]
        console.log(string.format(
            "  $%04X  MY=%04X (%d)  CPU=%04X (%d)",
            c.addr,
            c.my_value,
            c.my_value,
            c.cpu_value,
            c.cpu_value
        ))
    end

    if #u16 > 100 then
        console.log("  ... u16 truncado em 100")
    end
end

local function draw_hud()
    gui.text(8, 8, "TEAM POSSESSION PROBE")

    local y = 22
    for _, name in ipairs(CLASS_ORDER) do
        gui.text(8, y, string.format(
            "%s: %d",
            name,
            classes[name].count
        ))
        y = y + 14
    end

    gui.text(8, y, "Y=my ctrl  U=my pass  I=cpu ctrl  O=cpu pass")
    y = y + 14
    gui.text(8, y, "P=print candidates  R=reset")
    y = y + 14

    if ready() then
        gui.text(8, y, string.format(
            "Last printed: u8=%d u16=%d",
            last_candidate_count_u8,
            last_candidate_count_u16
        ))
    else
        gui.text(8, y, "Capture all 4 classes")
    end
end

reset()

console.log("[TEAM_POSSESSION] iniciado")
console.log("[TEAM_POSSESSION] Y=MY_CONTROLLED")
console.log("[TEAM_POSSESSION] U=MY_PASS")
console.log("[TEAM_POSSESSION] I=CPU_CONTROLLED")
console.log("[TEAM_POSSESSION] O=CPU_PASS")
console.log("[TEAM_POSSESSION] P=print | R=reset")

while true do
    local keys = input.get()

    for key, name in pairs(HOTKEY) do
        if pressed(keys, key) then
            capture(name)
        end
    end

    if pressed(keys, "P") then
        print_candidates()
    end

    if pressed(keys, "R") then
        reset()
    end

    draw_hud()

    previous_keys = keys
    emu.frameadvance()
end
