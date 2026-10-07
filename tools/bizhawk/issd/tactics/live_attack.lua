local M = {}

function M.new(config, players, field_side)
    local obj = { lane_direction = nil, lane_lock_frames = 0 }

    local function distance(ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        return math.sqrt(dx * dx + dy * dy)
    end

    local function clearance_at(x, y)
        local nearest = math.huge
        players.each_cpu(function(base)
            -- Exclude goalkeeper from route obstruction; he is the destination.
            if base ~= config.CPU_FIRST then
                local ox, oy = players.xy(base)
                nearest = math.min(nearest, distance(x, y, ox, oy))
            end
        end)
        return nearest
    end

    local function blocker_along(px, py, ux, uy)
        local best = nil
        players.each_cpu(function(base)
            if base ~= config.CPU_FIRST then
                local x, y = players.xy(base)
                local dx, dy = x - px, y - py
                local along = dx * ux + dy * uy
                local lateral = math.abs(dx * uy - dy * ux)
                if along > 0 and along <= config.ATTACK.blocker_forward_distance
                    and lateral <= config.ATTACK.blocker_lateral_half_width
                    and (best == nil or along < best.forward) then
                    best = {base=base, x=x, y=y, forward=along, lateral=lateral}
                end
            end
        end)
        return best
    end

    function obj.reset()
        obj.lane_direction, obj.lane_lock_frames = nil, 0
    end

    function obj.target_for_carrier(carrier_base)
        if not players.valid_my_base(carrier_base) then obj.reset(); return nil end
        local px, py = players.xy(carrier_base)
        local my_side, dir = field_side.my_side(), field_side.attack_direction()
        if my_side == nil or dir == 0 then obj.reset(); return nil end

        local gx, gy = players.xy(config.CPU_FIRST)
        local vx, vy = gx - px, gy - py
        local d = distance(px, py, gx, gy)
        -- Prevent moving backwards if the goalkeeper position is invalid or behind us.
        if d < 1 or vx * dir <= 0 then
            vx, vy = dir, 0
            d = 1
        end
        local ux, uy = vx / d, vy / d
        local blocker = blocker_along(px, py, ux, uy)
        local mode, target_x, target_y = "ADVANCE", nil, nil
        local lane_dir, up_clearance, down_clearance = nil, nil, nil
        local step = config.ATTACK.advance_distance

        if blocker then
            mode = "LANE"
            step = config.ATTACK.lane_forward_distance
            -- Side-step is perpendicular to the direct path toward CPU GK.
            local forward_x, forward_y = px + ux * step, py + uy * step
            local offset = config.ATTACK.lane_offset_y
            local up_x, up_y = forward_x - uy * offset, forward_y + ux * offset
            local down_x, down_y = forward_x + uy * offset, forward_y - ux * offset
            up_clearance, down_clearance =
                clearance_at(up_x, up_y), clearance_at(down_x, down_y)

            if obj.lane_direction ~= nil and obj.lane_lock_frames > 0 then
                lane_dir = obj.lane_direction
                obj.lane_lock_frames = obj.lane_lock_frames - 1
            else
                -- Prefer an open route that does not sacrifice goalkeeper progress.
                local up_progress = d - distance(up_x, up_y, gx, gy)
                local down_progress = d - distance(down_x, down_y, gx, gy)
                local up_score = up_clearance + 0.5 * up_progress
                local down_score = down_clearance + 0.5 * down_progress
                lane_dir = up_score >= down_score and 1 or -1
                obj.lane_direction = lane_dir
                obj.lane_lock_frames = config.ATTACK.lane_lock_frames
            end
            target_x = lane_dir == 1 and up_x or down_x
            target_y = lane_dir == 1 and up_y or down_y
        else
            obj.reset()
            target_x, target_y = px + ux * step, py + uy * step
        end

        return {
            mode=mode, carrier=carrier_base, player_x=px, player_y=py,
            target_x=target_x, target_y=target_y,
            direction=dir, my_side=my_side, advance_distance=step,
            lane_direction=lane_dir, lane_lock_frames=obj.lane_lock_frames,
            blocker_base=blocker and blocker.base or nil,
            blocker_forward=blocker and blocker.forward or nil,
            blocker_lateral=blocker and blocker.lateral or nil,
            up_clearance=up_clearance, down_clearance=down_clearance,
            goal_target_x=gx, goal_target_y=gy,
            goal_distance=distance(px, py, gx, gy),
        }
    end
    return obj
end

return M
