local M = {}

function M.new(config, players, field_side)
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

    -- Minimum separation from opponents along the entire passing corridor.
    local function lane_clearance(gx, gy, rx, ry)
        local dx,dy=rx-gx,ry-gy
        local length2=dx*dx+dy*dy
        if length2<1 then return 0 end
        local best=99999
        players.each_cpu(function(base)
            local ox,oy=players.xy(base)
            local projection=((ox-gx)*dx+(oy-gy)*dy)/length2
            if projection>0.08 and projection<1.08 then
                local t=math.max(0,math.min(1,projection))
                local cx,cy=gx+t*dx,gy+t*dy
                local d=distance(ox,oy,cx,cy)
                if d<best then best=d end
            end
        end)
        return best
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
                local lateral_offset = math.abs(py-gy)
                -- B+Right/Left travels forward: evaluate the real straight corridor,
                -- not an imaginary diagonal toward the selected teammate.
                local corridor = lane_clearance(gx,gy,px,gy)

                if dist <= config.GK_DISTRIBUTION.max_throw_distance
                   and lateral_offset <= config.GK_DISTRIBUTION.forward_lane_half_width
                   and clearance >=
                       config.GK_DISTRIBUTION.min_receiver_clearance
                   and corridor >= config.GK_DISTRIBUTION.min_lane_clearance
                   and forward >= config.GK_DISTRIBUTION.min_forward then

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
                            lane_clearance = corridor,
                            lateral_offset = lateral_offset,
                            forward = forward,
                            score = score,
                            direction = attack_dir == 1 and "Right" or "Left",
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
        local my_side = field_side.my_side()
        local dir = field_side.attack_direction()

        if my_side == nil or dir == 0 then
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
                lane_clearance = receiver.lane_clearance,
                decision_reason = "SAFE_STRAIGHT_FORWARD_B",
                receiver_lateral_offset = receiver.lateral_offset,
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
            lane_clearance = nil,
            decision_reason = "NO_SAFE_STRAIGHT_FORWARD_B",
            receiver_lateral_offset = nil,
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
