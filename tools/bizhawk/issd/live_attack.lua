local M = {}

function M.new(config, players, field_side)
    local obj = {
        lane_direction = nil,
        lane_lock_frames = 0,
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

    local function nearest_blocker(px, py, dir)
        local best = nil

        players.each_cpu(function(base)
            local ox, oy = players.xy(base)
            local forward = (ox - px) * dir
            local lateral = math.abs(oy - py)

            if forward > 0
               and forward <= config.ATTACK.blocker_forward_distance
               and lateral <= config.ATTACK.blocker_lateral_half_width then
                if best == nil or forward < best.forward then
                    best = {
                        base = base,
                        x = ox,
                        y = oy,
                        forward = forward,
                        lateral = lateral,
                    }
                end
            end
        end)

        return best
    end

    local function clearance_at(tx, ty)
        local nearest = nil

        players.each_cpu(function(base)
            local ox, oy = players.xy(base)
            local d = distance(tx, ty, ox, oy)

            if nearest == nil or d < nearest then
                nearest = d
            end
        end)

        return nearest or 9999
    end

    local function choose_lane(px, py, dir, blocker)
        if obj.lane_direction ~= nil and obj.lane_lock_frames > 0 then
            obj.lane_lock_frames = obj.lane_lock_frames - 1
            return obj.lane_direction, nil, nil
        end

        local tx =
            px + dir * config.ATTACK.lane_forward_distance
        local up_y = py - config.ATTACK.lane_offset_y
        local down_y = py + config.ATTACK.lane_offset_y

        local up_clearance = clearance_at(tx, up_y)
        local down_clearance = clearance_at(tx, down_y)

        local lane_direction
        if up_clearance > down_clearance then
            lane_direction = -1
        elseif down_clearance > up_clearance then
            lane_direction = 1
        else
            -- Empate: desvia para longe do bloqueador.
            lane_direction = blocker.y >= py and -1 or 1
        end

        obj.lane_direction = lane_direction
        obj.lane_lock_frames = config.ATTACK.lane_lock_frames

        return lane_direction, up_clearance, down_clearance
    end

    function obj.reset()
        obj.lane_direction = nil
        obj.lane_lock_frames = 0
    end

    function obj.target_for_carrier(carrier_base)
        if not players.valid_my_base(carrier_base) then
            obj.reset()
            return nil
        end

        local px, py = players.xy(carrier_base)
        local my_side = field_side.my_side()
        local dir = field_side.attack_direction()

        if my_side == nil or dir == 0 then
            obj.reset()
            return nil
        end

        local blocker = nearest_blocker(px, py, dir)

        if blocker ~= nil then
            local lane_dir, up_clearance, down_clearance =
                choose_lane(px, py, dir, blocker)

            return {
                mode = "LANE",
                carrier = carrier_base,
                player_x = px,
                player_y = py,
                target_x =
                    px + dir * config.ATTACK.lane_forward_distance,
                target_y =
                    py + lane_dir * config.ATTACK.lane_offset_y,
                direction = dir,
                my_side = my_side,
                advance_distance = config.ATTACK.lane_forward_distance,
                lane_direction = lane_dir,
                lane_lock_frames = obj.lane_lock_frames,
                blocker_base = blocker.base,
                blocker_forward = blocker.forward,
                blocker_lateral = blocker.lateral,
                up_clearance = up_clearance,
                down_clearance = down_clearance,
            }
        end

        obj.reset()

        return {
            mode = "ADVANCE",
            carrier = carrier_base,
            player_x = px,
            player_y = py,
            target_x = px + dir * config.ATTACK.advance_distance,
            target_y = py,
            direction = dir,
            my_side = my_side,
            advance_distance = config.ATTACK.advance_distance,
            lane_direction = nil,
            lane_lock_frames = 0,
            blocker_base = nil,
            blocker_forward = nil,
            blocker_lateral = nil,
            up_clearance = nil,
            down_clearance = nil,
        }
    end

    return obj
end

return M
