local M = {}

function M.new(config, players)
    local obj = {
        last_team = nil,
        last_owner = nil,
        frames_without_possession = 0,
        prev_ball_x = nil,
        prev_ball_y = nil,
        ball_dx = 0,
        ball_dy = 0,
        ball_speed = 0,
        smoothed_ball_speed = 0,
        classification = "UNKNOWN",
    }

    local function team_for_possession(possession)
        if players.valid_my_base(possession) then
            return "MY"
        end

        if players.valid_cpu_base(possession) then
            return "CPU"
        end

        return nil
    end

    function obj.reset()
        obj.last_team = nil
        obj.last_owner = nil
        obj.frames_without_possession = 0
        obj.prev_ball_x = nil
        obj.prev_ball_y = nil
        obj.ball_dx = 0
        obj.ball_dy = 0
        obj.ball_speed = 0
        obj.smoothed_ball_speed = 0
        obj.classification = "UNKNOWN"
    end

    function obj.update(possession, ball_x, ball_y)
        if obj.prev_ball_x ~= nil and obj.prev_ball_y ~= nil then
            obj.ball_dx = ball_x - obj.prev_ball_x
            obj.ball_dy = ball_y - obj.prev_ball_y
            obj.ball_speed = math.sqrt(
                obj.ball_dx * obj.ball_dx
              + obj.ball_dy * obj.ball_dy
            )
        else
            obj.ball_dx = 0
            obj.ball_dy = 0
            obj.ball_speed = 0
        end

        -- Hold velocity through isolated zero-delta samples that arise from
        -- the RAM update cadence; decay instead of toggling instantly to zero.
        local alpha=config.POSSESSION_CONTEXT.speed_smoothing_alpha
        obj.smoothed_ball_speed=alpha*obj.ball_speed
            +(1-alpha)*obj.smoothed_ball_speed
        obj.prev_ball_x = ball_x
        obj.prev_ball_y = ball_y

        local direct_team = team_for_possession(possession)

        if direct_team ~= nil then
            obj.last_team = direct_team
            obj.last_owner = possession
            obj.frames_without_possession = 0
            obj.classification =
                direct_team == "CPU" and "CPU_CONTROLLED" or "MY_CONTROLLED"
            return obj.classification
        end

        if possession ~= 0 then
            obj.frames_without_possession = 0
            obj.classification = "UNKNOWN_POSSESSION"
            return obj.classification
        end

        obj.frames_without_possession =
            obj.frames_without_possession + 1

        local within_grace =
            obj.frames_without_possession <=
            config.POSSESSION_CONTEXT.grace_frames

        local moving =
            obj.ball_speed >=
            config.POSSESSION_CONTEXT.moving_threshold

        local initial_grace =
            obj.frames_without_possession <=
            config.POSSESSION_CONTEXT.initial_grace_frames

        if within_grace and (moving or initial_grace) then
            if obj.last_team == "CPU" then
                obj.classification = "CPU_UNOWNED_BALL"
                return obj.classification
            elseif obj.last_team == "MY" then
                obj.classification = "MY_UNOWNED_BALL"
                return obj.classification
            end
        end

        obj.classification = "TRUE_LOOSE_BALL"
        return obj.classification
    end

    return obj
end

return M
