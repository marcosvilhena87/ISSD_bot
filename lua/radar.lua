-- ISSD_bot Radar v0.1.0 - BizHawk / SNES / somente leitura
-- Usa memory.read_* no dominio WRAM. Nao envia comandos ao jogo.
local DOMAIN = "WRAM"
local ADDR = {
    ball_x = 0x042A, ball_y = 0x042C, stadium = 0x0086,
    field_length = 0x12A2, field_width = 0x12A4
}
local ORIGIN_X, ORIGIN_Y = 0, 0 -- calibrar com observacoes
local SCALE_X, SCALE_Y = 1, 1   -- calibrar com observacoes
local SAMPLE_EVERY = 10
local FIELD_X, FIELD_Y, FIELD_W, FIELD_H = 12, 30, 220, 118
local output_path = "issd_radar_ball.csv"

local function u16(addr)
    return memory.read_u16_le(addr, DOMAIN)
end
local function s16(addr)
    return memory.read_s16_le(addr, DOMAIN)
end
local function clamp(value, lo, hi)
    return math.max(lo, math.min(hi, value))
end
local function projection(x, y, length, width)
    if length <= 0 or width <= 0 then return nil, nil end
    local nx = (x - ORIGIN_X) * SCALE_X / length
    local ny = (y - ORIGIN_Y) * SCALE_Y / width
    if nx ~= nx or ny ~= ny then return nil, nil end
    return FIELD_X + nx * FIELD_W, FIELD_Y + ny * FIELD_H
end

local csv, err = io.open(output_path, "w")
if not csv then error("Nao foi possivel criar o CSV: " .. tostring(err)) end
csv:write("frame,stadium_id,ball_x,ball_y,field_length,field_width,normalized_x,normalized_y,inside_bounds\n")
csv:flush()

local frame_count = 0
while true do
    local x, y = u16(ADDR.ball_x), u16(ADDR.ball_y)
    local stadium = s16(ADDR.stadium)
    local length, width = u16(ADDR.field_length), u16(ADDR.field_width)
    local px, py = projection(x, y, length, width)
    local nx = length > 0 and (x - ORIGIN_X) * SCALE_X / length or nil
    local ny = width > 0 and (y - ORIGIN_Y) * SCALE_Y / width or nil
    local inside = nx and ny and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 or false

    gui.drawBox(FIELD_X, FIELD_Y, FIELD_X + FIELD_W, FIELD_Y + FIELD_H, "white", 0x50000000)
    gui.drawLine(FIELD_X + FIELD_W / 2, FIELD_Y, FIELD_X + FIELD_W / 2, FIELD_Y + FIELD_H, "white")
    gui.drawText(FIELD_X, 10, string.format("RADAR v0.1 | estadio=%d | bola=(%d,%d)", stadium, x, y), "white")
    if px and py then
        if inside then
            gui.drawBox(px - 3, py - 3, px + 3, py + 3, "yellow", "yellow")
        else
            gui.drawText(FIELD_X, FIELD_Y + FIELD_H + 3, "Bola fora da area normalizada: calibrar", "orange")
        end
    else
        gui.drawText(FIELD_X, FIELD_Y + FIELD_H + 3, "Dimensoes indisponiveis na WRAM", "red")
    end
    if frame_count % SAMPLE_EVERY == 0 then
        csv:write(string.format("%d,%d,%d,%d,%d,%d,%s,%s,%d\n",
            emu.framecount(), stadium, x, y, length, width,
            nx and string.format("%.6f", nx) or "",
            ny and string.format("%.6f", ny) or "",
            inside and 1 or 0))
        csv:flush()
    end
    frame_count = frame_count + 1
    emu.frameadvance()
end
