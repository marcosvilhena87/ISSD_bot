local M = {}

function M.new(config, players, mem)
    local obj = {
        wait_frames = 0,
        last_action = nil,
    }

    local function attack_direction(my_side)
        if my_side == 0 then
            return 1
        elseif my_side == 1 then
            return -1
        end
        return 0
    end

    local function distance(ax, ay, bx, by)
        local dx = bx - ax
        local dy = by - ay
        return math.sqrt(dx * dx + dy * dy)
    end

    local function nearest_cpu_clearance(x, y)
        local best = nil

        players.each_cpu(function(base)
            local ox, oy = players.xy(base)
            local d = distance(x, y, ox, oy)

            if best == nil or d < best then
                best = d
            end
        end)

        return best or 9999
    end

    local function direction_name(gx, gy, rx, ry, attack_dir)
        local dy = ry - gy

        if dy <= -config.GK_DISTRIBUTION.lateral_direction_threshold then
            return "Up"
        elseif dy >= config.GK_DISTRIBUTION.lateral_direction_threshold then
            return "Down"
        end

        return attack_dir == 1 and "Right" or "Left"
    end

    local function best_short_receiver(gk_base, attack_dir)
        local gx, gy = players.xy(gk_base)
        local best = nil

        players.each_my(function(base)
            if base ~= gk_base then
                local px, py = players.xy(base)
                local dist = distance(gx, gy, px, py)
                local clearance = nearest_cpu_clearance(px, py)
                local forward = (px - gx) * attack_dir

                if dist <= config.GK_DISTRIBUTION.max_throw_distance
                   and clearance >=
                       config.GK_DISTRIBUTION.min_receiver_clearance then

                    local score =
                        config.GK_DISTRIBUTION.weight_clearance * clearance
                        + config.GK_DISTRIBUTION.weight_forward * forward
                        - config.GK_DISTRIBUTION.weight_distance * dist

                    if best == nil or score > best.score then
                        best = {
                            base = base,
                            x = px,
                            y = py,
                            distance = dist,
                            clearance = clearance,
                            forward = forward,
                            score = score,
                            direction =
                                direction_name(
                                    gx, gy, px, py, attack_dir
                                ),
                        }
                    end
                end
            end
        end)

        return best
    end

    function obj.reset()
        obj.wait_frames = 0
        obj.last_action = nil
    end

    function obj.tick()
        if obj.wait_frames > 0 then
            obj.wait_frames = obj.wait_frames - 1
        end
    end

    function obj.plan(gk_base)
        local my_side = mem.u8(config.ADDR.my_side)
        local dir = attack_direction(my_side)

        if dir == 0 then
            return nil
        end

        local receiver = best_short_receiver(gk_base, dir)

        if receiver ~= nil then
            return {
                mode = "THROW",
                button = config.GK_DISTRIBUTION.throw_button,
                direction = receiver.direction,
                receiver = receiver.base,
                receiver_distance = receiver.distance,
                receiver_clearance = receiver.clearance,
                receiver_forward = receiver.forward,
                receiver_score = receiver.score,
                my_side = my_side,
            }
        end

        return {
            mode = "LONG_KICK",
            button = config.GK_DISTRIBUTION.long_kick_button,
            direction = dir == 1 and "Right" or "Left",
            receiver = nil,
            receiver_distance = nil,
            receiver_clearance = nil,
            receiver_forward = nil,
            receiver_score = nil,
            my_side = my_side,
        }
    end

    function obj.should_fire()
        return obj.wait_frames == 0
    end

    function obj.mark_fired(action)
        obj.last_action = action
        obj.wait_frames = config.GK_DISTRIBUTION.retry_frames
    end

    return obj
end

return M
