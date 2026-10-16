-- ISSD_bot Radar v0.2.0 | BizHawk SNES | somente leitura
-- 22 jogadores + bola; leituras i16 little-endian na WRAM.
local DOMAIN = "WRAM"
local BASE_BALL = 0x042A
local BASE_MY = 0x052A
local BASE_CPU = 0x102A
local STRIDE = 0x0100
local X_Y_OFFSET = 2
local ADDR_STADIUM = 0x0086
local ADDR_LENGTH = 0x12A2
local ADDR_WIDTH = 0x12A4

-- Valores de calibracao: origem e escala devem ser confirmados em partida.
local ORIGIN_X, ORIGIN_Y = 0, 0
local SCALE_X, SCALE_Y = 1, 1
local SAMPLE_EVERY = 10
local FX, FY, FW, FH = 12, 32, 220, 120
local CSV_NAME = "issd_radar_entities.csv"

local function s16(addr)
    return memory.read_s16_le(addr, DOMAIN)
end
local function u16(addr)
    return memory.read_u16_le(addr, DOMAIN)
end
local function read_xy(addr)
    return s16(addr), s16(addr + X_Y_OFFSET)
end
local function normalized(x, y, length, width)
    if length <= 0 or width <= 0 then return nil, nil end
    return (x - ORIGIN_X) * SCALE_X / length,
           (y - ORIGIN_Y) * SCALE_Y / width
end
local function render_entity(x, y, length, width, color, label)
    local nx, ny = normalized(x, y, length, width)
    local inside = nx and ny and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1
    if inside then
        local px = math.floor(FX + nx * FW + 0.5)
        local py = math.floor(FY + ny * FH + 0.5)
        gui.drawBox(px - 2, py - 2, px + 2, py + 2, color, color)
        if label then gui.drawText(px + 3, py - 5, label, color) end
    end
    return nx, ny, inside and 1 or 0
end
local csv, err = io.open(CSV_NAME, "w")
if not csv then error("Nao foi possivel abrir CSV: " .. tostring(err)) end
csv:write("frame,stadium_id,entity,number,raw_x,raw_y,field_length,field_width,norm_x,norm_y,inside_bounds\n")
csv:flush()
local function write_entity(frame, stadium, entity, number, x, y, length, width, nx, ny, inside)
    csv:write(string.format("%d,%d,%s,%d,%d,%d,%d,%d,%s,%s,%d\n",
        frame, stadium, entity, number, x, y, length, width,
        nx and string.format("%.6f", nx) or "",
        ny and string.format("%.6f", ny) or "", inside))
end
local frames = 0
while true do
    local frame = emu.framecount()
    local stadium = s16(ADDR_STADIUM)
    local length, width = u16(ADDR_LENGTH), u16(ADDR_WIDTH)
    local ball_x, ball_y = read_xy(BASE_BALL)
    gui.drawBox(FX, FY, FX + FW, FY + FH, "white", 0x50000000)
    gui.drawLine(FX + FW / 2, FY, FX + FW / 2, FY + FH, "white")
    gui.drawText(FX, 10, string.format("ISSD RADAR 0.2 | Estadio %d", stadium), "white")
    local sample = frames % SAMPLE_EVERY == 0

    local function observe(entity, number, x, y, color, label)
        local nx, ny, inside = render_entity(x, y, length, width, color, label)
        if sample then
            write_entity(frame, stadium, entity, number, x, y, length, width, nx, ny, inside)
        end
    end
    for i = 0, 10 do
        local x, y = read_xy(BASE_MY + i * STRIDE)
        observe("my", i + 1, x, y, "cyan", nil)
    end
    for i = 0, 10 do
        local x, y = read_xy(BASE_CPU + i * STRIDE)
        observe("cpu", i + 1, x, y, "red", nil)
    end
    observe("ball", 0, ball_x, ball_y, "yellow", "B")
    gui.drawText(FX, FY + FH + 4, "Azul: meu time | Vermelho: CPU | Amarelo: bola", "white")
    if length == 0 or width == 0 then
        gui.drawText(FX, FY + FH + 16, "Dimensoes zeradas: aguarde partida", "orange")
    end
    if sample then csv:flush() end
    frames = frames + 1
    emu.frameadvance()
end
