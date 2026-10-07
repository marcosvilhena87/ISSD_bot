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
    local handle, err = io.open(path, "a+")
    if not handle then
        console.log("[ISSD] CSV indisponivel: " .. tostring(err))
        return setmetatable({handle = nil}, M)
    end
    local size = handle:seek("end")
    if size == 0 then
        handle:write("timestamp,session,frame,event,enabled,status,game_state,gameplay_active,player_possession,team_possession,controlled_player,ball_dx,ball_dy,ball_speed,action,detail\n")
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
    local values = {
        timestamp(), self.session or "", self.frame or 0, event,
        enabled and 1 or 0, state.status, state.game_state,
        state.gameplay_active, state.possession, state.team_possession,
        state.my_base, state.ball_dx, state.ball_dy, state.ball_speed,
        action, detail
    }
    local cells = {}
    for i = 1, 16 do cells[i] = csv(values[i]) end
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
        self:write("STATE_CHANGE", true, state, status, "previous=" .. tostring(previous or "NONE"))
    elseif self.frame % 300 == 0 then
        self:write("HEARTBEAT", true, state, status, "periodic")
    end
    self.previous = status
end

return M
