-- Persistent CSV telemetry for ISSD Bot (BizHawk Lua).
local M = {}
M.__index = M

local function csv(value)
    if value == nil then return "" end
    local str = tostring(value)
    return '"' .. str:gsub('"', '""') .. '"'
end

local function timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

function M.new(path)
    local handle, err = io.open(path, "w")
    if not handle then
        console.log("[ISSD] CSV indisponivel: " .. tostring(err))
        return setmetatable({handle = nil}, M)
    end
    do
        handle:write("timestamp,session,frame,event,enabled,status,game_state,gameplay_active,player_possession,team_possession,controlled_player,ball_dx,ball_dy,ball_speed,action,detail,ball_x,ball_y,player_x,player_y,target_x,target_y,target_distance,controller_command,attack_mode,lane_direction,blocker_base,blocker_forward,blocker_lateral,up_clearance,down_clearance,restart_taker,restart_taker_team,mark_target,team_possession_source\n")
    end
    local session = os.date("%Y%m%d_%H%M%S")
    local self = setmetatable({handle = handle, session = session, frame = 0, previous = nil}, M)
    self:write("SESSION_START", false, nil, "", "main.lua")
    console.log("[ISSD] Relatorio CSV: " .. path)
    return self
end

function M:write(event, enabled, state, action, detail)
    if not self.handle then return end
    state = state or {}
    local telemetry = {
        state.ball_x, state.ball_y, state.player_x, state.player_y,
        state.target_x, state.target_y, state.target_distance,
        state.controller_command, state.attack_mode, state.attack_lane_direction,
        state.attack_blocker_base, state.attack_blocker_forward,
        state.attack_blocker_lateral, state.attack_up_clearance,
        state.attack_down_clearance, state.restart_taker,
        state.restart_taker_team, state.mark_target,
        state.team_possession_source
    }
    local values = {
        timestamp(), self.session or "", self.frame or 0, event,
        enabled and 1 or 0, state.status, state.game_state,
        state.gameplay_active, state.possession, state.team_possession,
        state.my_base, state.ball_dx, state.ball_dy, state.ball_speed,
        action, detail
    }
    for i = 1, 19 do values[16 + i] = telemetry[i] end
    local cells = {}
    for i = 1, 35 do cells[i] = csv(values[i]) end
    local ok, err = pcall(function()
        self.handle:write(table.concat(cells, ",") .. "\n")
        self.handle:flush()
    end)
    if not ok then
        console.log("[ISSD] Erro ao gravar CSV: " .. tostring(err))
        pcall(function() self.handle:close() end)
        self.handle = nil
    end
end

function M:observe(enabled, state)
    self.frame = self.frame + 1
    if not enabled then
        self.previous = nil
        return
    end
    local status = state and state.status or "UNKNOWN"
    local previous = self.previous
    if status ~= previous then
        local detail = "previous=" .. tostring(previous or "NONE")
        if status == "ATTACK_LANE" then
            detail = detail .. ";reason=blocker_detected"
        elseif status == "ATTACK_ADVANCE" and previous == "ATTACK_LANE" then
            detail = detail .. ";reason=blocker_no_longer_detected"
        elseif status == "RESTART_MANUAL" then
            detail = detail .. ";reason=no_confirmed_restart_target"
        end
        self:write("STATE_CHANGE", true, state, status, detail)
    elseif self.frame % 300 == 0 then
        self:write("HEARTBEAT", true, state, status, "periodic")
    end
    self.previous = status
end

return M
