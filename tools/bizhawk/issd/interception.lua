local M = {}

function M.new(config)
    local obj = {}

    local function clamp_lead(dx, dy)
        local dist = math.sqrt(dx * dx + dy * dy)
        local max_dist = config.INTERCEPTION.max_lead_distance

        if dist <= max_dist or dist == 0 then
            return dx, dy
        end

        local scale = max_dist / dist
        return dx * scale, dy * scale
    end

    function obj.target(ball_x, ball_y, ball_dx, ball_dy, ball_speed)
        if ball_speed < config.INTERCEPTION.min_ball_speed then
            return {
                x = ball_x,
                y = ball_y,
                lead_frames = 0,
                lead_x = 0,
                lead_y = 0,
                predictive = false,
            }
        end

        local raw_x = ball_dx * config.INTERCEPTION.lead_frames
        local raw_y = ball_dy * config.INTERCEPTION.lead_frames
        local lead_x, lead_y = clamp_lead(raw_x, raw_y)

        return {
            x = math.floor(ball_x + lead_x + 0.5),
            y = math.floor(ball_y + lead_y + 0.5),
            lead_frames = config.INTERCEPTION.lead_frames,
            lead_x = lead_x,
            lead_y = lead_y,
            predictive = true,
        }
    end

    return obj
end

return M
