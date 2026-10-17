-- ISSD_bot Radar v0.15.4 | BizHawk SNES | read-only calibration
local DOMAIN = "WRAM"
local BASE_BALL, BASE_MY, BASE_CPU = 0x042A, 0x052A, 0x102A
local STRIDE, XY_DELTA = 0x0100, 2
local STADIUM, FIELD_LENGTH, FIELD_WIDTH = 0x0086, 0x12A2, 0x12A4
local GAME_STATE, GAMEPLAY_ACTIVE = 0x00BA, 0x0006
local CENTER_FIELD_X, CENTER_FIELD_Y = 0x12F2, 0x12D8

-- ETAPA 1: ajuste estes valores para enquadrar o radar nativo.
local FX, FY, FW, FH = 88, 161, 79, 54
local SHOW_CORNERS = true   -- quatro cantos MAGENTA, independentes dos offsets
local AUTO_HIDE_CORNERS = true -- exige geometria conhecida (original ou variante)
-- ETAPA 2: alinhe jogadores e bola, sem mover os quatro cantos.
local ORIGIN_X, ORIGIN_Y = 0, 0
local SCALE_X, SCALE_Y = 1, 1
local INVERT_X, INVERT_Y = false, false
local OFFSET_X, OFFSET_Y = 0, 0  -- apenas entidades; pixels logicos
local SHOW_ENTITIES = true
local SHOW_NUMBERS = false -- numeros ao lado de cada jogador (polui o radar)
local SHOW_BALL = true
local SHOW_OVERLAY = true   -- false: somente CSV; sem cantos nem entidades
-- Limites observados da bola nos quatro escanteios, POR estadio.
-- Sao hipoteses empiricas, NAO validacao contra pixels nativos.
-- Modelos: "field_dimensions", "empirical", "geometric".
-- O padrao preserva o comportamento da v0.8.
local PROJECTION_MODEL = "empirical"
assert(PROJECTION_MODEL == "field_dimensions" or
       PROJECTION_MODEL == "empirical" or
       PROJECTION_MODEL == "geometric", "PROJECTION_MODEL invalido")
local STADIUM_CALIBRATION = {
    [0] = {min_x=4, max_x=1788, min_y=4, max_y=572, validated=false},
    [1] = {min_x=4, max_x=1852, min_y=4, max_y=636, validated=false},
    [2] = {min_x=4, max_x=1980, min_y=4, max_y=700, validated=false},
    [3] = {min_x=4, max_x=2044, min_y=4, max_y=636, validated=false},
    [4] = {min_x=4, max_x=1916, min_y=4, max_y=636, validated=false},
    [5] = {min_x=4, max_x=1916, min_y=4, max_y=572, validated=false},
    [6] = {min_x=4, max_x=1788, min_y=4, max_y=700, validated=false},
    [7] = {min_x=4, max_x=2172, min_y=4, max_y=700, validated=false},
}
-- Rotulos alinhados com tools/bizhawk/issd/state/game_state.lua do ISSD_bot.v0.
-- Game_State=6 indica fim de periodo; dimensoes zeradas foram observadas nesse estado.
local GAME_STATE_KIND = {
    [0]="LIVE", [1]="ENDLINE_RESTART", [2]="THROW_IN",
    [3]="FOUL_RESTART_SEQUENCE", [4]="OFFSIDE_SEQUENCE",
    [5]="POST_GOAL", [6]="PERIOD_TIME_UP"
}
-- Medidas de cada estadio derivadas dos perfis empiricos observados.
-- Classificacao conservadora: nao desenhar objetos com geometria suspeita.
local function geometry_status(stadium, length, width, game_state)
    if stadium == 8 then return "PRE_MATCH_COIN_TOSS", nil, nil end
    if length == 0 or width == 0 then
        if game_state == 6 then
            return "PERIOD_ENDED", nil, nil
        end
        return "ZERO_DIMENSIONS_UNEXPECTED", nil, nil
    end
    local profile = STADIUM_CALIBRATION[stadium]
    if not profile then return "UNKNOWN_STADIUM", nil, nil end
    local expected_length = profile.max_x - profile.min_x + 8
    local expected_width = profile.max_y - profile.min_y + 8
    if length ~= expected_length or width ~= expected_width then
        return "DIMENSION_MISMATCH", expected_length, expected_width
    end
    return "VALID", expected_length, expected_width
end
-- Apenas diagnostico: o bloqueio depende exclusivamente de geometry_status.
local PENDING_MAX_FRAMES = 1200
local PERSISTENT_LIVE_FRAMES = 120
local previous_classification_frame, previous_classification_stadium = nil, nil
local pending, mismatch_live_since = nil, nil
local function classify_transition(frame, stadium, length, width, game_state, integrity)
    if previous_classification_frame and frame <= previous_classification_frame then
        pending, mismatch_live_since = nil, nil
        previous_classification_stadium = nil
    end
    if previous_classification_stadium ~= nil
        and stadium ~= previous_classification_stadium then
        local old = STADIUM_CALIBRATION[previous_classification_stadium]
        if old and integrity == "DIMENSION_MISMATCH"
            and length == old.max_x-old.min_x+8
            and width == old.max_y-old.min_y+8 then
            pending = {since=frame, from=previous_classification_stadium,
                to=stadium, length=length, width=width}
        else
            pending = nil
        end
        mismatch_live_since = nil
    end
    local classification, age = integrity, nil
    if integrity ~= "DIMENSION_MISMATCH" then
        pending, mismatch_live_since = nil, nil
    else
        if pending and (stadium ~= pending.to
            or length ~= pending.length or width ~= pending.width) then
            pending = nil
        end
        if pending then
            age = frame-pending.since
            if age <= PENDING_MAX_FRAMES then
                classification = "STADIUM_CHANGE_PENDING"
            else
                pending = nil
            end
        end
        if not pending then
            if game_state == 0 then
                if not mismatch_live_since then mismatch_live_since = frame end
                age = frame-mismatch_live_since
                if age >= PERSISTENT_LIVE_FRAMES then
                    classification = "PERSISTENT_DIMENSION_MISMATCH"
                end
            else
                mismatch_live_since = nil
            end
        else
            mismatch_live_since = nil
        end
    end
    previous_classification_frame = frame
    previous_classification_stadium = stadium
    return classification, age, pending
end
-- Discovery-only geometric variants: no automatic recalibration.
local STADIUM_VARIANT_CANDIDATES = {
    [7] = {{length=2176, width=704, validated=false}},
}
local VARIANT_MIN_LIVE_FRAMES = 120
local variant_run = nil
local variant_session = {}
local function observe_variant(frame, stadium, length, width, game_state, integrity, transition_status)
    if variant_run and frame <= variant_run.last_frame then variant_run = nil end
    local eligible = game_state == 0 and integrity == "DIMENSION_MISMATCH"
        and transition_status ~= "STADIUM_CHANGE_PENDING"
        and STADIUM_CALIBRATION[stadium] ~= nil
    local key = tostring(stadium) .. ":" .. tostring(length) .. ":" .. tostring(width)
    if not eligible then variant_run = nil; return nil end
    if not variant_run or variant_run.key ~= key or frame ~= variant_run.last_frame+1 then
        variant_run = {key=key, since=frame, last_frame=frame}
    else
        variant_run.last_frame = frame
    end
    local age = frame-variant_run.since+1
    if age < VARIANT_MIN_LIVE_FRAMES then return nil end
    if variant_run.reported then return nil end
    variant_run.reported = true
    local p = STADIUM_VARIANT_CANDIDATES[stadium]
    local predefined = false
    if p then
        for _, candidate in ipairs(p) do
            if candidate.length == length and candidate.width == width then
                predefined = true
                break
            end
        end
    end
    variant_session[key] = true
    return {stadium=stadium, length=length, width=width,
        first_frame=variant_run.since, confirmed_frame=frame,
        live_frames=age, predefined=predefined}
end
-- Alternative per-stadium bounds observed from four corners; never auto-authorized.
local STADIUM_VARIANT_PROFILES = {
    [7] = {
        {id="7_2176x704", length=2176, width=704,
         min_x=4, max_x=2172, min_y=4, max_y=700,
         geometry_observed=true, projection_validated=false}
    }
}
local function match_variant_profile(stadium, length, width)
    for _, p in ipairs(STADIUM_VARIANT_PROFILES[stadium] or {}) do
        if p.length == length and p.width == width then return p end
    end
    return nil
end
local SAMPLE_EVERY = 10
-- Foco: "ball"/0, "my"/1..11 ou "cpu"/1..11.
local TARGET_TEAM, TARGET_NUMBER = "ball", 0
local FOCUS_ONLY = true   -- ocultar outros marcadores, mas manter CSV completo
local SHOW_TARGET_CROSS = true
-- Referencias MANUAIS sincronizadas: um registro por frame/alvo.
-- Substitua pelos frames exatos de savestates e pixels logicos observados.
-- Ex.: {frame=123456, entity="my", number=1, x=90, y=188}
local REFERENCES = {
}
-- Cada frame listado no REFERENCES e exportado mesmo fora do SAMPLE_EVERY.
local CSV_NAME = "issd_radar_calibration.csv"
-- Eventos independentes da cadencia SAMPLE_EVERY: uma linha por alteracao/frame.
local TRANSITIONS_CSV_NAME = "issd_radar_geometry_transitions.csv"
local VARIANTS_CSV_NAME = "issd_radar_geometry_variants.csv"
local function valid_target()
    return (TARGET_TEAM == "ball" and TARGET_NUMBER == 0)
        or ((TARGET_TEAM == "my" or TARGET_TEAM == "cpu")
            and TARGET_NUMBER >= 1 and TARGET_NUMBER <= 11)
end
if not valid_target() then error("TARGET_TEAM/TARGET_NUMBER invalido") end
local reference_by_frame = {}
for i, ref in ipairs(REFERENCES) do
    assert(type(ref.frame) == "number" and ref.frame >= 0 and ref.frame % 1 == 0,
        "REFERENCES[" .. i .. "]: frame invalido")
    assert((ref.entity == "ball" and ref.number == 0) or
        ((ref.entity == "my" or ref.entity == "cpu") and
         type(ref.number) == "number" and ref.number >= 1 and
         ref.number <= 11 and ref.number % 1 == 0), "REFERENCES: entidade invalida")
    assert(type(ref.x) == "number" and type(ref.y) == "number",
        "REFERENCES: coordenadas invalidas")
    local key = ref.entity .. ":" .. ref.number
    reference_by_frame[ref.frame] = reference_by_frame[ref.frame] or {}
    assert(reference_by_frame[ref.frame][key] == nil,
        "REFERENCES: duplicidade frame/entidade: " .. ref.frame .. "/" .. key)
    reference_by_frame[ref.frame][key] = ref
end

local function s16(address) return memory.read_s16_le(address, DOMAIN) end
local function u16(address) return memory.read_u16_le(address, DOMAIN) end
local function xy(address) return s16(address), s16(address + XY_DELTA) end
local function rounded(value) return math.floor(value + 0.5) end
local function project(nx, ny)
    if nx == nil or ny == nil then return nil, nil, 0 end
    if INVERT_X then nx = 1 - nx end
    if INVERT_Y then ny = 1 - ny end
    local px = rounded(FX + nx * FW + OFFSET_X)
    local py = rounded(FY + ny * FH + OFFSET_Y)
    local inside = nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1
    return px, py, inside and 1 or 0
end
local function geometric_bounds(length, width)
    if length <= 8 or width <= 8 then return nil end
    return {min_x=4, max_x=length-4, min_y=4, max_y=width-4}
end
local function normalize_bounds(x, y, b)
    if not b or b.max_x <= b.min_x or b.max_y <= b.min_y then
        return nil, nil
    end
    return (x-b.min_x)/(b.max_x-b.min_x),
           (y-b.min_y)/(b.max_y-b.min_y)
end
local function transform(x, y, length, width, stadium, geometry_valid)
    -- Invalid frame: no projection is trusted, even with a stored profile.
    if not geometry_valid then
        return nil, nil, nil, nil, 0, "blocked", nil, nil, nil, nil,
            nil, nil, nil, nil, nil, nil, STADIUM_CALIBRATION[stadium],
            nil, nil, nil, nil, nil, nil, nil
    end
    local b = STADIUM_CALIBRATION[stadium]
    local g = geometric_bounds(length, width)
    local raw_nx, raw_ny
    if length > 0 and width > 0 then
        raw_nx = (x-ORIGIN_X)*SCALE_X/length
        raw_ny = (y-ORIGIN_Y)*SCALE_Y/width
    end
    local emp_nx, emp_ny = normalize_bounds(x, y, b)
    local geo_nx, geo_ny = normalize_bounds(x, y, g)
    local raw_px, raw_py = project(raw_nx, raw_ny)
    local emp_px, emp_py = project(emp_nx, emp_ny)
    local geo_px, geo_py = project(geo_nx, geo_ny)
    local model, nx, ny = "field_dimensions", raw_nx, raw_ny
    if length > 0 and width > 0 then
        if PROJECTION_MODEL == "empirical" and emp_nx ~= nil then
            model, nx, ny = "empirical", emp_nx, emp_ny
        elseif PROJECTION_MODEL == "geometric" and geo_nx ~= nil then
            model, nx, ny = "geometric", geo_nx, geo_ny
        end
    end
    local px, py, inside = project(nx, ny)
    return nx, ny, px, py, inside, model,
        raw_nx, raw_ny, raw_px, raw_py, emp_nx, emp_ny, emp_px, emp_py,
        (raw_px and emp_px) and (emp_px-raw_px) or nil,
        (raw_py and emp_py) and (emp_py-raw_py) or nil,
        b, geo_nx, geo_ny, geo_px, geo_py, g,
        (emp_px and geo_px) and (geo_px-emp_px) or nil,
        (emp_py and geo_py) and (geo_py-emp_py) or nil
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
csv:write("frame,stadium_id,entity,number,raw_x,raw_y,field_length,field_width,norm_x,norm_y,pixel_x,pixel_y,inside_bounds,fx,fy,fw,fh,offset_x,offset_y,origin_x,origin_y,scale_x,scale_y,invert_x,invert_y,is_target,reference_x,reference_y,error_x,error_y,error_distance,calibration_status,projection_model,raw_norm_x,raw_norm_y,raw_pixel_x,raw_pixel_y,empirical_norm_x,empirical_norm_y,empirical_pixel_x,empirical_pixel_y,delta_pixel_x,delta_pixel_y,empirical_min_x,empirical_max_x,empirical_min_y,empirical_max_y,empirical_validated,geometric_norm_x,geometric_norm_y,geometric_pixel_x,geometric_pixel_y,geometric_min_x,geometric_max_x,geometric_min_y,geometric_max_y,geometric_minus_empirical_pixel_x,geometric_minus_empirical_pixel_y,geometry_status,geometry_valid,expected_field_length,expected_field_width,game_state,game_state_kind,gameplay_active,transition_status,transition_age_frames,pending_from_stadium,pending_to_stadium,variant_id,variant_geometry_observed,variant_projection_validated,variant_pixel_x,variant_pixel_y,variant_norm_x,variant_norm_y,corners_visible,corner_visibility_mode\n")
local function number(value)
    if value == nil then return "" end
    return string.format("%.6f", value)
end
-- Registra somente alteracoes, com snapshot inicial para dar contexto.
local transitions, transitions_err = io.open(TRANSITIONS_CSV_NAME, "w")
if not transitions then error("Falha ao criar CSV de transicoes: " .. tostring(transitions_err)) end
transitions:write("frame,event,changed_fields,previous_frame,previous_stadium_id,stadium_id,previous_game_state,game_state,previous_field_length,field_length,previous_field_width,field_width,previous_geometry_status,geometry_status,previous_game_state_kind,game_state_kind,previous_gameplay_active,gameplay_active,previous_transition_status,transition_status,transition_age_frames,pending_from_stadium,pending_to_stadium\n")
transitions:flush()
local previous_geometry = nil
local function track_geometry(current)
    local prev = previous_geometry
    local changed = {}
    local event
    if not prev then
        event = "INITIAL"
        changed = {"stadium_id", "game_state", "field_length", "field_width"}
    elseif current.frame <= prev.frame then
        -- Savestate/rewind: nao interpretar diferencas como fluxo temporal continuo.
        event = "TIMELINE_RESET"
        changed = {"stadium_id", "game_state", "field_length", "field_width"}
    else
        for _, field in ipairs({"stadium_id", "game_state", "field_length", "field_width"}) do
            if current[field] ~= prev[field] then
                changed[#changed + 1] = field
            end
        end
        if #changed > 0 then
            event = "CHANGE"
        elseif current.transition_status ~= prev.transition_status then
            event = "CLASSIFICATION_CHANGE"
        end
    end
    if event then
        transitions:write(table.concat({
            current.frame, event, table.concat(changed, ";"),
            prev and prev.frame or "",
            prev and prev.stadium_id or "", current.stadium_id,
            prev and prev.game_state or "", current.game_state,
            prev and prev.field_length or "", current.field_length,
            prev and prev.field_width or "", current.field_width,
            prev and prev.geometry_status or "", current.geometry_status,
            prev and prev.game_state_kind or "", current.game_state_kind,
            prev and prev.gameplay_active or "", current.gameplay_active,
            prev and prev.transition_status or "", current.transition_status,
            current.transition_age_frames or "",
            current.pending_from_stadium or "", current.pending_to_stadium or ""
        }, ",") .. "\n")
        transitions:flush()
    end
    previous_geometry = current
end
local variants, variants_err = io.open(VARIANTS_CSV_NAME, "w")
if not variants then error("Falha ao criar CSV de variantes: " .. tostring(variants_err)) end
variants:write("stadium_id,field_length,field_width,first_frame,confirmed_frame,consecutive_live_frames,predefined_candidate,validated,status\n")
variants:flush()
local count = 0
while true do
    local frame = emu.framecount()
    local stadium = s16(STADIUM)
    local length, width = u16(FIELD_LENGTH), u16(FIELD_WIDTH)
    local game_state = u16(GAME_STATE)
    local game_state_kind = GAME_STATE_KIND[game_state] or "UNKNOWN"
    local gameplay_active = memory.read_u8(GAMEPLAY_ACTIVE, DOMAIN)
    local integrity, expected_length, expected_width = geometry_status(stadium, length, width, game_state)
    local valid_geometry = integrity == "VALID"
    local variant_profile = match_variant_profile(stadium, length, width)
    local transition_status, transition_age, pending_info =
        classify_transition(frame, stadium, length, width, game_state, integrity)
    local variant = observe_variant(frame, stadium, length, width, game_state,
        integrity, transition_status)
    if variant then
        variants:write(table.concat({
            variant.stadium, variant.length, variant.width,
            variant.first_frame, variant.confirmed_frame,
            variant.live_frames, variant.predefined and 1 or 0,
            0, "OBSERVED_UNVALIDATED"
        }, ",") .. "\\n")
        variants:flush()
    end
    track_geometry({
        frame=frame, stadium_id=stadium, game_state=game_state,
        field_length=length, field_width=width,
        geometry_status=integrity, game_state_kind=game_state_kind,
        gameplay_active=gameplay_active,
        transition_status=transition_status,
        transition_age_frames=transition_age,
        pending_from_stadium=pending_info and pending_info.from or nil,
        pending_to_stadium=pending_info and pending_info.to or nil
    })
    local sample = count % SAMPLE_EVERY == 0 or reference_by_frame[frame] ~= nil
    -- Centros devem estar dentro das dimensoes carregadas.
    -- Independente de profile VALID, Game_State ou Gameplay_Active.
    local center_x, center_y = u16(CENTER_FIELD_X), u16(CENTER_FIELD_Y)
    local field_loaded = length > 8 and width > 8
        and center_x > 0 and center_x < length
        and center_y > 0 and center_y < width
    -- As cruzes aceitam variantes observadas, mas nao liberam entidades.
    local corners_geometry_known = stadium ~= 8 and (valid_geometry
        or (variant_profile ~= nil and variant_profile.geometry_observed == true))
    local corners_visible = SHOW_OVERLAY and SHOW_CORNERS
        and stadium ~= 8
        and (not AUTO_HIDE_CORNERS or (field_loaded and corners_geometry_known))
    if corners_visible then
        corner(FX, FY)
        corner(FX + FW, FY)
        corner(FX, FY + FH)
        corner(FX + FW, FY + FH)
    end
    local function observe(entity, index, x, y, color)
        local nx, ny, px, py, inside, model, raw_nx, raw_ny, raw_px, raw_py, emp_nx, emp_ny, emp_px, emp_py, delta_x, delta_y, bounds, geo_nx, geo_ny, geo_px, geo_py, geometry, geo_delta_x, geo_delta_y = transform(x, y, length, width, stadium, valid_geometry)
        -- Experimental coordinates are exported separately and never rendered.
        local variant_nx, variant_ny = nil, nil
        if variant_profile then
            variant_nx, variant_ny = normalize_bounds(x, y, variant_profile)
        end
        local variant_px, variant_py = project(variant_nx, variant_ny)
        local is_target = entity == TARGET_TEAM and index == TARGET_NUMBER
        if SHOW_OVERLAY and valid_geometry and px and py and inside == 1 then
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
            local key = entity .. ":" .. index
            local ref = reference_by_frame[frame] and reference_by_frame[frame][key]
            local status = "NO_REFERENCE"
            local ex, ey, distance = nil, nil, nil
            if not valid_geometry then
                status = integrity
            elseif ref then
                if inside == 1 and px ~= nil and py ~= nil then
                    ex, ey = px - ref.x, py - ref.y
                    distance = math.sqrt(ex * ex + ey * ey)
                    status = "MATCHED"
                else
                    status = "OUTSIDE_BOUNDS"
                end
            end
            csv:write(table.concat({
                frame, stadium, entity, index, x, y, length, width,
                number(nx), number(ny), px or "", py or "", inside,
                FX, FY, FW, FH, OFFSET_X, OFFSET_Y,
                ORIGIN_X, ORIGIN_Y, SCALE_X, SCALE_Y,
                INVERT_X and 1 or 0, INVERT_Y and 1 or 0,
                is_target and 1 or 0,
                ref and ref.x or "",
                ref and ref.y or "",
                number(ex), number(ey), number(distance), status,
                model, number(raw_nx), number(raw_ny), raw_px or "", raw_py or "",
                number(emp_nx), number(emp_ny), emp_px or "", emp_py or "",
                number(delta_x), number(delta_y),
                bounds and bounds.min_x or "", bounds and bounds.max_x or "",
                bounds and bounds.min_y or "", bounds and bounds.max_y or "",
                bounds and (bounds.validated and 1 or 0) or "",
                number(geo_nx), number(geo_ny), geo_px or "", geo_py or "",
                geometry and geometry.min_x or "", geometry and geometry.max_x or "",
                geometry and geometry.min_y or "", geometry and geometry.max_y or "",
                number(geo_delta_x), number(geo_delta_y),
                integrity, valid_geometry and 1 or 0,
                expected_length or "", expected_width or "",
                game_state, game_state_kind, gameplay_active,
                transition_status, transition_age or "",
                pending_info and pending_info.from or "",
                pending_info and pending_info.to or "",
                variant_profile and variant_profile.id or "",
                variant_profile and (variant_profile.geometry_observed and 1 or 0) or "",
                variant_profile and (variant_profile.projection_validated and 1 or 0) or "",
                variant_px or "", variant_py or "",
                number(variant_nx), number(variant_ny),
                corners_visible and 1 or 0, "known_geometry"
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
