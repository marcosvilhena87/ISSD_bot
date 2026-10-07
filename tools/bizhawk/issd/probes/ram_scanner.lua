-- ISSD Bot - BizHawk RAM Scanner
-- Scanner inicial para localizar variáveis dinâmicas como Ball X/Y.
--
-- Uso:
-- 1. Abra a ROM alvo no BizHawk.
-- 2. Tools -> Lua Console.
-- 3. Carregue este script.
-- 4. Pressione P para capturar um snapshot.
-- 5. Mude apenas o estado desejado no jogo.
-- 6. Pressione F para manter apenas endereços que mudaram.
-- 7. Repita o processo até reduzir os candidatos.
-- 8. Pressione R para reiniciar o conjunto.

local DOMAIN = "WRAM"
local snapshot = {}
local candidates = {}
local initialized = false
local previous_keys = {}

local function count_candidates()
    local n = 0
    for _, keep in pairs(candidates) do
        if keep then n = n + 1 end
    end
    return n
end

local function read_wram()
    local size = memory.getmemorydomainsize(DOMAIN)
    local out = {}
    for addr = 0, size - 1 do
        out[addr] = memory.read_u8(addr, DOMAIN)
    end
    return out
end

local function init_candidates(state)
    candidates = {}
    for addr, _ in pairs(state) do
        candidates[addr] = true
    end
    initialized = true
end

local function capture_snapshot()
    snapshot = read_wram()
    if not initialized then
        init_candidates(snapshot)
    end
    console.log(string.format("[ISSD] Snapshot capturado. Candidatos: %d", count_candidates()))
end

local function print_candidates(state)
    local shown = 0
    for addr, keep in pairs(candidates) do
        if keep then
            console.log(string.format("  $%04X = %02X", addr, state[addr]))
            shown = shown + 1
            if shown >= 100 then
                console.log("  ... mostrando somente os primeiros 100 candidatos")
                break
            end
        end
    end
end

local function filter_changed()
    if next(snapshot) == nil then
        console.log("[ISSD] Capture um snapshot primeiro com P.")
        return
    end

    local current = read_wram()

    for addr, keep in pairs(candidates) do
        if keep and current[addr] == snapshot[addr] then
            candidates[addr] = false
        end
    end

    snapshot = current
    console.log(string.format("[ISSD] Filtro CHANGED aplicado. Restantes: %d", count_candidates()))
    print_candidates(current)
end

local function reset_candidates()
    snapshot = read_wram()
    init_candidates(snapshot)
    console.log(string.format("[ISSD] Reset. Candidatos: %d", count_candidates()))
end

local function pressed(keys, key)
    return keys[key] and not previous_keys[key]
end

console.log("[ISSD] RAM Scanner iniciado")
console.log("[ISSD] P = snapshot | F = changed filter | R = reset")

while true do
    local keys = input.get()

    if pressed(keys, "P") then
        capture_snapshot()
    elseif pressed(keys, "F") then
        filter_changed()
    elseif pressed(keys, "R") then
        reset_candidates()
    end

    previous_keys = keys
    emu.frameadvance()
end
