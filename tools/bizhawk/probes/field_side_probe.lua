-- ISSD Bot - field side RAM probe
--
-- Objetivo:
-- encontrar uma flag GLOBAL de lado de campo / direcao de ataque que:
--   * seja estavel enquanto MY esta no lado esquerdo;
--   * seja estavel enquanto MY esta no lado direito;
--   * mude entre as duas classes;
--   * de preferencia fique fora das structs de jogadores.
--
-- Hotkeys:
--   Y = capturar MY_LEFT
--   U = capturar MY_RIGHT
--   C = imprimir candidatos
--   R = reset
--
-- Observacao:
-- "MY_LEFT" significa nosso time ocupando/defendendo o lado esquerdo.
-- "MY_RIGHT" significa nosso time ocupando/defendendo o lado direito.

memory.usememorydomain("WRAM")

local WRAM_SIZE = 0x20000
local PLAYER_STRUCT_FIRST = 0x0500
local PLAYER_STRUCT_LAST = 0x1AFF

local previous_keys = {}
local samples = {
    LEFT = {},
    RIGHT = {},
}

local counts = {
    LEFT = 0,
    RIGHT = 0,
}

local function pressed(keys, key)
    return keys[key] and not previous_keys[key]
end

local function read_u8_snapshot()
    local t = {}
    for addr = 0, WRAM_SIZE - 1 do
        t[addr] = memory.read_u8(addr)
    end
    return t
end

local function read_u16_le(snapshot, addr)
    local lo = snapshot[addr] or 0
    local hi = snapshot[addr + 1] or 0
    return lo + hi * 256
end

local function stable_value(class_name, addr, width)
    local list = samples[class_name]
    if #list == 0 then
        return nil
    end

    local first
    if width == 1 then
        first = list[1][addr]
    else
        first = read_u16_le(list[1], addr)
    end

    for i = 2, #list do
        local value
        if width == 1 then
            value = list[i][addr]
        else
            value = read_u16_le(list[i], addr)
        end

        if value ~= first then
            return nil
        end
    end

    return first
end

local function is_player_struct(addr)
    return addr >= PLAYER_STRUCT_FIRST
       and addr <= PLAYER_STRUCT_LAST
end

local function candidate_score(addr, left_value, right_value, width)
    local score = 0

    -- Maior prioridade para enderecos fora de structs de jogador.
    if not is_player_struct(addr) then
        score = score + 1000
    end

    -- Flags pequenas / enums costumam ser melhores candidatos.
    if left_value <= 3 and right_value <= 3 then
        score = score + 300
    elseif left_value <= 15 and right_value <= 15 then
        score = score + 150
    end

    -- Padrões binarios 0/1 sao especialmente interessantes.
    if (left_value == 0 and right_value == 1)
       or (left_value == 1 and right_value == 0) then
        score = score + 500
    end

    -- Pequena preferencia por byte simples.
    if width == 1 then
        score = score + 25
    end

    return score
end

local function collect(width)
    local out = {}
    local max_addr = WRAM_SIZE - width

    for addr = 0, max_addr do
        local lv = stable_value("LEFT", addr, width)
        local rv = stable_value("RIGHT", addr, width)

        if lv ~= nil and rv ~= nil and lv ~= rv then
            table.insert(out, {
                addr = addr,
                left = lv,
                right = rv,
                width = width,
                score = candidate_score(addr, lv, rv, width),
                player_struct = is_player_struct(addr),
            })
        end
    end

    table.sort(out, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.addr < b.addr
    end)

    return out
end

local function print_candidates()
    if counts.LEFT < 2 or counts.RIGHT < 2 then
        console.log(string.format(
            "[FIELD_SIDE] capture mais amostras | LEFT=%d RIGHT=%d",
            counts.LEFT,
            counts.RIGHT
        ))
        return
    end

    local u8 = collect(1)
    local u16 = collect(2)

    console.log(string.format(
        "[FIELD_SIDE] candidates u8=%d u16=%d | LEFT=%d RIGHT=%d",
        #u8, #u16, counts.LEFT, counts.RIGHT
    ))

    console.log("[FIELD_SIDE] --- TOP u8 ---")
    local n8 = math.min(40, #u8)
    for i = 1, n8 do
        local c = u8[i]
        console.log(string.format(
            "  #%02d $%05X LEFT=%02X (%d) RIGHT=%02X (%d) score=%d %s",
            i,
            c.addr,
            c.left,
            c.left,
            c.right,
            c.right,
            c.score,
            c.player_struct and "[PLAYER_STRUCT]" or "[GLOBAL]"
        ))
    end

    console.log("[FIELD_SIDE] --- TOP u16 little-endian ---")
    local n16 = math.min(30, #u16)
    for i = 1, n16 do
        local c = u16[i]
        console.log(string.format(
            "  #%02d $%05X LEFT=%04X (%d) RIGHT=%04X (%d) score=%d %s",
            i,
            c.addr,
            c.left,
            c.left,
            c.right,
            c.right,
            c.score,
            c.player_struct and "[PLAYER_STRUCT]" or "[GLOBAL]"
        ))
    end
end

local function capture(class_name)
    table.insert(samples[class_name], read_u8_snapshot())
    counts[class_name] = counts[class_name] + 1

    console.log(string.format(
        "[FIELD_SIDE] %s sample #%d",
        class_name,
        counts[class_name]
    ))
end

local function reset()
    samples.LEFT = {}
    samples.RIGHT = {}
    counts.LEFT = 0
    counts.RIGHT = 0
    console.log("[FIELD_SIDE] reset")
end

console.log("[FIELD_SIDE] started")
console.log("[FIELD_SIDE] Y=MY_LEFT | U=MY_RIGHT | C=print | R=reset")
console.log("[FIELD_SIDE] capture 5+ samples of each side, including GK possession if possible")

while true do
    local keys = input.get()

    if pressed(keys, "Y") then
        capture("LEFT")
    end

    if pressed(keys, "U") then
        capture("RIGHT")
    end

    if pressed(keys, "C") then
        print_candidates()
    end

    if pressed(keys, "R") then
        reset()
    end

    previous_keys = keys
    emu.frameadvance()
end
