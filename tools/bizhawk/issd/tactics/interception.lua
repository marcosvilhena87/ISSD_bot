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

    -- Emergency defense: intercept ahead of a fast ball approaching our GK.
    -- Goalkeeper coordinates anchor the defended end, avoiding fixed field constants.
    function obj.danger_target(ball_x, ball_y, vx, vy, speed, gk_x, gk_y, goal_dir)
        local c = config.INTERCEPTION
        if goal_dir == 0 or speed < c.danger_min_speed
            or vx * goal_dir < c.danger_min_x_speed then return nil end
        local remaining = (gk_x - ball_x) * goal_dir
        if remaining <= 0 or remaining > c.danger_max_goal_distance then return nil end
        local frames_to_gk = remaining / math.max(math.abs(vx), 0.01)
        if frames_to_gk > c.danger_max_frames then return nil end
        local lead = math.min(c.danger_max_lead_frames,
            math.max(c.danger_min_lead_frames, math.floor(frames_to_gk * 0.65)))
        local x = ball_x + vx * lead
        local y = ball_y + vy * lead
        -- Do not run past the goalkeeper/goal line.
        if (x - gk_x) * goal_dir > 0 then x = gk_x end
        return {x=math.floor(x+0.5), y=math.floor(y+0.5),
            lead_frames=lead, lead_x=x-ball_x, lead_y=y-ball_y,
            predictive=true, clipped=false, danger=true,
            frames_to_goal=frames_to_gk}
    end

    return obj
end

return M
