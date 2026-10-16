-- ISSD_bot Radar v0.5.0 | BizHawk SNES | read-only calibration
local DOMAIN = "WRAM"
local BASE_BALL, BASE_MY, BASE_CPU = 0x042A, 0x052A, 0x102A
local STRIDE, XY_DELTA = 0x0100, 2
local STADIUM, FIELD_LENGTH, FIELD_WIDTH = 0x0086, 0x12A2, 0x12A4

-- ETAPA 1: ajuste estes valores para enquadrar o radar nativo.
local FX, FY, FW, FH = 88, 161, 79, 54
local SHOW_CORNERS = true   -- quatro cantos MAGENTA, independentes dos offsets
-- ETAPA 2: alinhe jogadores e bola, sem mover os quatro cantos.
local ORIGIN_X, ORIGIN_Y = 0, 0
local SCALE_X, SCALE_Y = 1, 1
local INVERT_X, INVERT_Y = false, false
local OFFSET_X, OFFSET_Y = 0, 0  -- apenas entidades; pixels logicos
local SHOW_ENTITIES = true
local SHOW_NUMBERS = false -- numeros ao lado de cada jogador (polui o radar)
local SHOW_BALL = true
local SHOW_OVERLAY = true   -- false: somente CSV; sem cantos nem entidades
local SAMPLE_EVERY = 10
local CSV_NAME = "issd_radar_calibration.csv"

local function s16(address) return memory.read_s16_le(address, DOMAIN) end
local function u16(address) return memory.read_u16_le(address, DOMAIN) end
local function xy(address) return s16(address), s16(address + XY_DELTA) end
local function rounded(value) return math.floor(value + 0.5) end
local function transform(x, y, length, width)
    if length <= 0 or width <= 0 then return nil, nil, nil, nil, 0 end
    local nx = (x - ORIGIN_X) * SCALE_X / length
    local ny = (y - ORIGIN_Y) * SCALE_Y / width
    if INVERT_X then nx = 1 - nx end
    if INVERT_Y then ny = 1 - ny end
    local px = rounded(FX + nx * FW + OFFSET_X)
    local py = rounded(FY + ny * FH + OFFSET_Y)
    local inside = nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1
    return nx, ny, px, py, inside and 1 or 0
end
local function corner(x, y)
    -- 3 pixels em formato de cruz; os pontos-guia sao independentes
    -- dos offsets de entidades, permitindo calibracao por etapas.
    gui.drawPixel(x, y, "magenta")
    gui.drawPixel(x - 1, y, "magenta")
    gui.drawPixel(x + 1, y, "magenta")
    gui.drawPixel(x, y - 1, "magenta")
    gui.drawPixel(x, y + 1, "magenta")
end
local csv, err = io.open(CSV_NAME, "w")
if not csv then error("Falha ao criar CSV: " .. tostring(err)) end
csv:write("frame,stadium_id,entity,number,raw_x,raw_y,field_length,field_width,norm_x,norm_y,pixel_x,pixel_y,inside_bounds,fx,fy,fw,fh,offset_x,offset_y,origin_x,origin_y,scale_x,scale_y,invert_x,invert_y\n")
local function number(value)
    if value == nil then return "" end
    return string.format("%.6f", value)
end
local count = 0
while true do
    local frame = emu.framecount()
    local stadium = s16(STADIUM)
    local length, width = u16(FIELD_LENGTH), u16(FIELD_WIDTH)
    local sample = count % SAMPLE_EVERY == 0
    if SHOW_OVERLAY and SHOW_CORNERS then
        corner(FX, FY)
        corner(FX + FW, FY)
        corner(FX, FY + FH)
        corner(FX + FW, FY + FH)
    end
    local function observe(entity, index, x, y, color)
        local nx, ny, px, py, inside = transform(x, y, length, width)
        if SHOW_OVERLAY and px and py and inside == 1 then
            if entity == "ball" then
                if SHOW_BALL then gui.drawPixel(px, py, color) end
            elseif SHOW_ENTITIES then
                gui.drawPixel(px, py, color)
                if SHOW_NUMBERS then
                    gui.drawText(px + 2, py - 4, tostring(index), color)
                end
            end
        end
        if sample then
            csv:write(table.concat({
                frame, stadium, entity, index, x, y, length, width,
                number(nx), number(ny), px or "", py or "", inside,
                FX, FY, FW, FH, OFFSET_X, OFFSET_Y,
                ORIGIN_X, ORIGIN_Y, SCALE_X, SCALE_Y,
                INVERT_X and 1 or 0, INVERT_Y and 1 or 0
            }, ",") .. "\n")
        end
    end
    for i = 0, 10 do
        local x, y = xy(BASE_MY + i * STRIDE)
        observe("my", i + 1, x, y, "cyan")
    end
    for i = 0, 10 do
        local x, y = xy(BASE_CPU + i * STRIDE)
        observe("cpu", i + 1, x, y, "red")
    end
    local bx, by = xy(BASE_BALL)
    observe("ball", 0, bx, by, "yellow")
    if sample then csv:flush() end
    count = count + 1
    emu.frameadvance()
end
