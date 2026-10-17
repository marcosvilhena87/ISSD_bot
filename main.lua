-- ISSD main diagnostic bootstrap (runs before module imports).
print("[ISSD] main.lua: inicio do carregamento")
if type(gui)=="table" and type(gui.addmessage)=="function" then
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
local TikiTaka = require("tiki_taka")
local Gegenpressing = require("gegenpressing")
local Possession = require("possession")
print("[ISSD] main.lua: modulos carregados")
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
    local tiki = TikiTaka.new(config.tiki_taka)
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
            reset()
            return {mode="INACTIVE",reason="unvalidated_state"}
        end
        -- Always update gegenpressing; otherwise it misses the my -> cpu transition.
        local pressure = gegen.update(s)
        if s.possession == "my" then
            local attack = tiki.update(s)
            return {mode=attack.mode=="PASS" and "TIKI_TAKA" or "KEEP_POSSESSION",
                phase="ATTACK",decision=attack,pressure=pressure}
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
    assert(type(emu)=="table" and type(emu.frameadvance)=="function"
        and type(emu.framecount)=="function","BizHawk emu API required")
    local bot=M.new(config)
    print("[ISSD] main.lua: loop iniciado")
    if provider ~= nil then assert(type(provider)=="function","provider must be a function") end
    local previous_mode
    local last_error
    while true do
        local frame=emu.framecount()
        local s
        local ok, result = pcall(function()
            if provider then return provider(frame) end
            if type(memory)=="table" then return Possession.bizhawk() end
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
        if type(gui)=="table" and type(gui.text)=="function" then
            gui.text(4,4,"ISSD main: "..tostring(decision.mode))
        end
        if decision.mode~=previous_mode then
            print(string.format("[ISSD][%d] %s",frame,decision.mode))
            previous_mode=decision.mode
        end
        if type(ISSD_TACTICAL_OBSERVER)=="function" then
            ISSD_TACTICAL_OBSERVER(decision,s)
        end
        emu.frameadvance()
    end
end
if type(emu)=="table" and type(emu.frameadvance)=="function" and
   type(emu.framecount)=="function" then
    print("[ISSD] main.lua: API emu detectada")
    M.run(type(ISSD_STATE_PROVIDER)=="function" and ISSD_STATE_PROVIDER or nil)
else
    print("[ISSD] main.lua: sem API emu; modulo carregado, loop nao iniciado")
end
return M
