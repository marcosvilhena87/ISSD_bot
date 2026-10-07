local M = {}

function M.new(config)
    local obj = {}

    local function clamp(value, low, high)
        if value < low then return low end
        if value > high then return high end
        return value
    end

    local function clamp_lead(dx, dy)
        local dist = math.sqrt(dx * dx + dy * dy)
        local max_dist = config.INTERCEPTION.max_lead_distance

        if dist <= max_dist or dist == 0 then
            return dx, dy, false
        end

        local scale = max_dist / dist
        return dx * scale, dy * scale, true
    end

    local function dynamic_lead_frames(player_x, player_y, ball_x, ball_y)
        local dx = ball_x - player_x
        local dy = ball_y - player_y
        local distance = math.sqrt(dx * dx + dy * dy)

        local frames =
            config.INTERCEPTION.min_lead_frames
            + math.floor(
                distance / config.INTERCEPTION.distance_per_lead_frame
            )

        frames = clamp(
            frames,
            config.INTERCEPTION.min_lead_frames,
            config.INTERCEPTION.max_lead_frames
        )

        return frames, distance
    end

    function obj.target(
        player_x,
        player_y,
        ball_x,
        ball_y,
        ball_dx,
        ball_dy,
        ball_speed
    )
        local lead_frames, player_ball_distance =
            dynamic_lead_frames(player_x, player_y, ball_x, ball_y)

        if ball_speed < config.INTERCEPTION.min_ball_speed then
            return {
                x = ball_x,
                y = ball_y,
                lead_frames = 0,
                lead_x = 0,
                lead_y = 0,
                predictive = false,
                player_ball_distance = player_ball_distance,
                clipped = false,
            }
        end

        local raw_x = ball_dx * lead_frames
        local raw_y = ball_dy * lead_frames
        local lead_x, lead_y, clipped = clamp_lead(raw_x, raw_y)

        return {
            x = math.floor(ball_x + lead_x + 0.5),
            y = math.floor(ball_y + lead_y + 0.5),
            lead_frames = lead_frames,
            lead_x = lead_x,
            lead_y = lead_y,
            predictive = true,
            player_ball_distance = player_ball_distance,
            clipped = clipped,
        }
    end

    return obj
end

return M
