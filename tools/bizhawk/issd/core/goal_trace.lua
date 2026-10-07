-- Diagnostic trace: GS 0->5 indicates post-goal sequence, not who scored.
local M = {}
function M.new(report, window_frames, sample_step)
    local obj = { history={}, frame=0, last_gs=nil, report=report,
        window=window_frames or 600, step=sample_step or 3, last_trigger=-999999 }
    local function snapshot(state)
        local out = {}
        for k,v in pairs(state or {}) do
            if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
                out[k] = v
            end
        end
        return out
    end
    function obj.observe(enabled, state)
        obj.frame = obj.frame + 1
        local gs = state and state.game_state
        local prior = obj.last_gs
        -- Keep only the last 10 seconds at 60 fps (sampling every 3 frames).
        if obj.frame % obj.step == 0 and gs ~= nil then
            obj.history[#obj.history+1] = {frame=obj.frame, enabled=enabled,
                state=snapshot(state)}
        end
        while #obj.history > math.ceil(obj.window / obj.step) do
            table.remove(obj.history, 1)
        end
        if gs == 5 and prior ~= 5 and obj.frame - obj.last_trigger > obj.window then
            obj.last_trigger = obj.frame
            obj.report:write("POST_GOAL_CANDIDATE", enabled, state,
                "GS_5", "scoring_team=UNKNOWN;score_ram=UNMAPPED")
            for _, item in ipairs(obj.history) do
                obj.report:write("PRE_GOAL_TRACE", item.enabled, item.state,
                    item.state.controller_command, "trigger_frame=" .. obj.frame,
                    item.frame)
            end
        end
        if gs ~= nil then obj.last_gs = gs end
    end
    return obj
end
return M
