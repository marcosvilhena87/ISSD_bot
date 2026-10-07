-- Circular pre-goal trace with score-delta classification.
local M = {}
function M.new(report, window_frames, sample_step)
    local obj = {history={}, frame=0, last_gs=nil, last_my=nil,
        last_cpu=nil, report=report, window=window_frames or 600,
        step=sample_step or 3, last_trigger=-999999}
    local function snapshot(state)
        local out = {}
        for k, v in pairs(state or {}) do
            if type(v) == "number" or type(v) == "string"
                or type(v) == "boolean" then out[k] = v end
        end
        return out
    end
    local function dump(event, enabled, state, detail)
        obj.last_trigger = obj.frame
        obj.report:write(event, enabled, state, "SCORE", detail)
        for _, item in ipairs(obj.history) do
            obj.report:write("PRE_GOAL_TRACE", item.enabled, item.state,
                item.state.controller_command,
                "trigger_frame=" .. obj.frame .. ";" .. detail, item.frame)
        end
    end
    function obj.observe(enabled, state)
        obj.frame = obj.frame + 1
        state = state or {}
        local gs, my, cpu = state.game_state, state.score_my, state.score_cpu
        -- Save current frame before handling score change, so the trace includes it.
        if obj.frame % obj.step == 0 then
            obj.history[#obj.history + 1] = {
                frame=obj.frame, enabled=enabled, state=snapshot(state)}
        end
        while #obj.history > math.ceil(obj.window / obj.step) do
            table.remove(obj.history, 1)
        end
        local have_score = type(my) == "number" and type(cpu) == "number"
        local have_previous = type(obj.last_my) == "number"
            and type(obj.last_cpu) == "number"
        local changed = false
        if have_score and have_previous and (my ~= obj.last_my or cpu ~= obj.last_cpu) then
            local dm, dc = my - obj.last_my, cpu - obj.last_cpu
            local detail = "before=" .. obj.last_my .. "-" .. obj.last_cpu
                .. ";after=" .. my .. "-" .. cpu
                .. ";delta_my=" .. dm .. ";delta_cpu=" .. dc
            changed = true
            if dm == 1 and dc == 0 then
                dump("GOAL_FOR", enabled, state, detail)
            elseif dc == 1 and dm == 0 then
                dump("GOAL_AGAINST", enabled, state, detail)
            elseif dm < 0 or dc < 0 then
                obj.report:write("SCORE_RESET", enabled, state, "SCORE", detail)
                obj.history = {}
            else
                obj.report:write("SCORE_JUMP", enabled, state, "SCORE", detail)
                obj.history = {}
            end
        end
        -- GS=5 is a diagnostic hint only; never claim a scored goal from GS alone.
        if gs == 5 and obj.last_gs ~= 5 and not changed then
            obj.report:write("POST_GOAL_UNVERIFIED", enabled, state,
                "GS_5", "score_delta=NOT_OBSERVED")
        end
        if have_score then
            obj.last_my, obj.last_cpu = my, cpu
        else
            obj.last_my, obj.last_cpu = nil, nil
        end
        if gs ~= nil then obj.last_gs = gs end
    end
    return obj
end
return M
