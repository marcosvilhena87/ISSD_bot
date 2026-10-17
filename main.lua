-- ISSD main diagnostic bootstrap (runs before module imports).
print("[ISSD] main.lua: inicio do carregamento")
if gui ~= nil and (type(gui.addmessage)=="function" or type(gui.addmessage)=="userdata") then
    pcall(gui.addmessage,"ISSD main.lua: carregando")
end
-- ISSD_bot tactical coordinator: tiki-taka + gegenpressing.
-- Safe by default: no unvalidated possession inference or joypad writes.
-- Resolve modules relative to THIS script rather than BizHawk's working directory.
local source = ""
if type(debug)=="table" and type(debug.getinfo)=="function" then
    local info=debug.getinfo(1,"S")
    source=info and info.source or ""
end
local script_dir = source:sub(1,1) == "@" and
    source:sub(2):match("^(.*[/\\])") or nil
if script_dir then
    package.path = script_dir .. "lua/?.lua;" .. package.path
else
    package.path = "./lua/?.lua;lua/?.lua;" .. package.path
end
local SequentialTiki = require("sequential_tiki_taka")
local GoalkeeperDistribution = require("goalkeeper_distribution")
local Gegenpressing = require("gegenpressing")
local Possession = require("possession")
local Telemetry = require("tactical_telemetry")
local TacticalRadar = require("tactical_radar")
print("[ISSD] main.lua: modulos carregados")
print(string.format("[ISSD] versao=%s | telemetria_schema=%s | colunas=%d",Telemetry.VERSION,Telemetry.SCHEMA_VERSION,Telemetry.COLUMN_COUNT))
local function callable_api(v)
    local t=type(v)
    return t=="function" or t=="userdata"
end
local M = {}
local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
local function point(p)
    return type(p) == "table" and finite(p.x) and finite(p.y)
end
local function valid_input(s)
    if type(s) ~= "table" or not finite(s.frame) or s.active ~= true
        or not point(s.ball) or not point(s.own_goal)
        or not point(s.opponent_goal)
        or type(s.my_players) ~= "table" or type(s.cpu_players) ~= "table" then
        return false
    end
    if s.possession ~= "my" and s.possession ~= "cpu" and s.possession ~= "loose" then
        return false
    end
    if s.possession == "my" and s.carrier_id == nil then return false end
    return true
end
function M.new(config)
    config = config or {}
    local tiki = SequentialTiki.new({tiki_taka=config.tiki_taka,dribble_step=config.dribble_step,dribble_clearance=config.dribble_clearance})
    local gegen = Gegenpressing.new(config.gegenpressing)
    local last_frame = nil
    local function reset()
        tiki.reset()
        gegen.reset()
        last_frame = nil
    end
    local function update(s)
        if type(s) ~= "table" or not finite(s.frame) then
            reset()
            return {mode="INACTIVE",reason="invalid_frame"}
        end
        if last_frame and s.frame < last_frame then reset() end
        last_frame = s.frame
        if not valid_input(s) then
            local waiting=tiki.update(s)
            if waiting.mode=="WAIT_RECEIVE" then
                return {mode="WAIT_RECEIVE",phase="TRANSITION",decision=waiting,reason=waiting.reason}
            end
            reset()
            return {mode="INACTIVE",reason=s.reason or "unvalidated_state"}
        end
        -- Always update gegenpressing; otherwise it misses the my -> cpu transition.
        local pressure = gegen.update(s)
        if s.possession == "my" then
            local goalkeeper=GoalkeeperDistribution.plan(s)
            if goalkeeper then
                tiki.reset()
                return {mode="GK_DISTRIBUTION",phase="ATTACK",
                    decision=goalkeeper,tactical_action="GK_DISTRIBUTION",pressure=pressure}
            end
            local attack = tiki.update(s)
            local mode=attack.mode=="PASS_READY" and "TIKI_TAKA" or
                attack.mode=="DRIBBLE" and "DRIBBLE" or
                attack.mode=="REPLAN" and "REPLAN" or "KEEP_POSSESSION"
            return {mode=mode,phase="ATTACK",decision=attack,
                tactical_action=attack.mode,pressure=pressure}
        end
        -- Tiki-taka deliberately resets whenever we lose possession.
        tiki.reset()
        if pressure.mode == "GEGENPRESS" then
            return {mode="GEGENPRESS",phase="TRANSITION",decision=pressure}
        end
        return {mode=pressure.mode=="RECOVER_SHAPE" and "RECOVER_SHAPE" or "DEFEND",
            phase="DEFENSE",decision=pressure}
    end
    local function confirm_pass(target_id, frame)
        tiki.confirm_pass(target_id,frame)
    end
    return {update=update,reset=reset,confirm_pass=confirm_pass}
end
-- Read-only BizHawk loop: built-in conservative WRAM provider by default.
-- An external validated state provider can override it.
-- Define ISSD_STATE_PROVIDER=function(frame) return validated_state end
-- before loading main.lua. No game buttons are emitted.
function M.run(provider, config)
    assert(emu ~= nil and callable_api(emu.frameadvance)
        and callable_api(emu.framecount),"BizHawk emu API required")
    local bot=M.new(config)
    print("[ISSD] main.lua: loop iniciado")
    if provider ~= nil then assert(type(provider)=="function","provider must be a function") end
    local previous_mode
    local last_error
    local report_path=(script_dir or "./").."issd_tactical_report.csv"
    print("[ISSD] arquivo principal: "..tostring(source))
    print("[ISSD] caminho CSV: "..report_path)
    local telemetry, telemetry_error=Telemetry.new(report_path, {flush_every=60})
    if telemetry then
        print(string.format("[ISSD] Telemetria ativa: %s | bot=%s | schema=%s | colunas=%d",report_path,Telemetry.VERSION,Telemetry.SCHEMA_VERSION,Telemetry.COLUMN_COUNT))
    else
        print("[ISSD] ERRO CSV: "..tostring(telemetry_error))
    end
    local last_csv_error
    while true do
        local frame=emu.framecount()
        local s
        local ok, result = pcall(function()
            if provider then return provider(frame) end
            if memory ~= nil then return Possession.bizhawk() end
            return nil
        end)
        if ok then
            s=result
            last_error=nil
        elseif result~=last_error then
            print("[ISSD] Falha na leitura do estado: "..tostring(result))
            last_error=result
        end
        local decision
        if type(s)=="table" then
            s.frame=frame
            decision=bot.update(s)
        else
            decision=bot.update({frame=frame})
        end
        -- Clear persistent Lua drawings on EVERY frame, including lost/unknown
        -- possession. Otherwise old pass lines remain visible on BizHawk.
        if gui~=nil and callable_api(gui.clearGraphics) then
            gui.clearGraphics()
        end
        if type(gui)=="table" and callable_api(gui.text) then
            gui.text(4,4,"ISSD main: "..tostring(decision.mode))
        end
        -- Tactical radar: same six-/eight-stadium empirical projection as radar.lua.
        -- Never draw during uncertain possession or invalid geometry.
        if gui ~= nil and callable_api(gui.drawPixel) and
           memory ~= nil and type(s)=="table" and s.active==true and
           s.possession=="my" and s.ownership_source=="PLAYER_BALL_POSSESSION" and
           s.carrier_id~=nil then
            local valid,plan=pcall(function()
                local stadium=memory.read_s16_le(0x0086,"WRAM")
                local length=memory.read_u16_le(0x12A2,"WRAM")
                local width=memory.read_u16_le(0x12A4,"WRAM")
                return TacticalRadar.plan(s,decision,stadium,length,width)
            end)
            if valid and plan then
                local drawn,draw_error=pcall(TacticalRadar.draw,plan,gui)
                if not drawn and draw_error~=last_error then
                    print("[ISSD] Radar tatico: "..tostring(draw_error))
                    last_error=draw_error
                end
            end
        end
        if telemetry then
            local wrote,write_error=telemetry.record(frame,s,decision)
            if not wrote and write_error~=last_csv_error then
                print("[ISSD] ERRO CSV: "..tostring(write_error))
                last_csv_error=write_error
            end
        end
        local mode_changed=decision.mode~=previous_mode
        if mode_changed then
            print(string.format("[ISSD][%d] %s",frame,decision.mode))
            previous_mode=decision.mode
        end
        if type(ISSD_TACTICAL_OBSERVER)=="function" then
            ISSD_TACTICAL_OBSERVER(decision,s)
        end
        if telemetry and mode_changed then telemetry.flush() end
        emu.frameadvance()
    end
end
if emu ~= nil and callable_api(emu.frameadvance) and
   callable_api(emu.framecount) then
    print("[ISSD] main.lua: API emu detectada")
    M.run(type(ISSD_STATE_PROVIDER)=="function" and ISSD_STATE_PROVIDER or nil)
else
    print("[ISSD] API detectada: emu="..type(emu).." frameadvance="..tostring(emu and type(emu.frameadvance)).." framecount="..tostring(emu and type(emu.framecount)).." memory="..type(memory))
    print("[ISSD] main.lua: sem API emu; modulo carregado, loop nao iniciado")
end
return M
