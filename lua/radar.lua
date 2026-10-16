-- ISSD_bot Radar v0.6.0 | BizHawk SNES | read-only calibration
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
-- Foco: "ball"/0, "my"/1..11 ou "cpu"/1..11.
local TARGET_TEAM, TARGET_NUMBER = "ball", 0
local FOCUS_ONLY = true   -- ocultar outros marcadores, mas manter CSV completo
local SHOW_TARGET_CROSS = true
-- Referencia manual: pixel LOGICO do radar nativo observado no MESMO frame.
-- Use nil ate identificar a coordenada; nenhum alvo e detectado automaticamente.
local REFERENCE_X, REFERENCE_Y = nil, nil
local CSV_NAME = "issd_radar_calibration.csv"
local function valid_target()
    return (TARGET_TEAM == "ball" and TARGET_NUMBER == 0)
        or ((TARGET_TEAM == "my" or TARGET_TEAM == "cpu")
            and TARGET_NUMBER >= 1 and TARGET_NUMBER <= 11)
end
if not valid_target() then error("TARGET_TEAM/TARGET_NUMBER invalido") end
if (REFERENCE_X == nil) ~= (REFERENCE_Y == nil) then
    error("Defina ambas as coordenadas REFERENCE_X/Y ou ambas nil")
end

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
local function target_cross(px, py)
    -- Pequena mira somente no alvo; opcional para evitar cobrir radar nativo.
    gui.drawPixel(px - 2, py, "white")
    gui.drawPixel(px + 2, py, "white")
    gui.drawPixel(px, py - 2, "white")
    gui.drawPixel(px, py + 2, "white")
end
local csv, err = io.open(CSV_NAME, "w")
if not csv then error("Falha ao criar CSV: " .. tostring(err)) end
csv:write("frame,stadium_id,entity,number,raw_x,raw_y,field_length,field_width,norm_x,norm_y,pixel_x,pixel_y,inside_bounds,fx,fy,fw,fh,offset_x,offset_y,origin_x,origin_y,scale_x,scale_y,invert_x,invert_y,is_target,reference_x,reference_y,error_x,error_y,error_distance\n")
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
        local is_target = entity == TARGET_TEAM and index == TARGET_NUMBER
        if SHOW_OVERLAY and px and py and inside == 1 then
            local enabled = (entity == "ball" and SHOW_BALL)
                or (entity ~= "ball" and SHOW_ENTITIES)
            if enabled and (not FOCUS_ONLY or is_target) then
                gui.drawPixel(px, py, color)
            end
            if is_target and SHOW_TARGET_CROSS then
                target_cross(px, py)
            elseif enabled and SHOW_NUMBERS and entity ~= "ball"
                and not FOCUS_ONLY then
                gui.drawText(px + 2, py - 4, tostring(index), color)
            end
        end
        if sample then
            local has_reference = is_target and REFERENCE_X ~= nil
                and px ~= nil and py ~= nil
            local ex, ey, distance = nil, nil, nil
            if has_reference then
                ex, ey = px - REFERENCE_X, py - REFERENCE_Y
                distance = math.sqrt(ex * ex + ey * ey)
            end
            csv:write(table.concat({
                frame, stadium, entity, index, x, y, length, width,
                number(nx), number(ny), px or "", py or "", inside,
                FX, FY, FW, FH, OFFSET_X, OFFSET_Y,
                ORIGIN_X, ORIGIN_Y, SCALE_X, SCALE_Y,
                INVERT_X and 1 or 0, INVERT_Y and 1 or 0,
                is_target and 1 or 0,
                is_target and (REFERENCE_X or "") or "",
                is_target and (REFERENCE_Y or "") or "",
                number(ex), number(ey), number(distance)
            }, ",") .. "\\n")
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
