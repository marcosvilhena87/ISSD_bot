local M = {}

function M.new(config, players, field_side)
    local obj = { lane_direction = nil, lane_lock_frames = 0,
        carrier=nil, anchor_x=nil, anchor_y=nil, lane_frames=0,
        abort_frames=0, stalled_events=0, progress_event=nil }

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
        obj.carrier=nil; obj.anchor_x=nil; obj.anchor_y=nil
        obj.lane_frames=0; obj.abort_frames=0; obj.stalled_events=0
        obj.progress_event=nil
    end

    function obj.take_progress_event()
        local event=obj.progress_event
        obj.progress_event=nil
        return event
    end

    local function monitor_lane(carrier,px,py,dir)
        local c=config.ATTACK
        if obj.carrier~=carrier then
            obj.reset()
            obj.carrier=carrier
        end
        if obj.abort_frames>0 then obj.abort_frames=obj.abort_frames-1 end
        if obj.abort_frames>0 then return true end
        if obj.anchor_x==nil then
            obj.anchor_x,obj.anchor_y=px,py
            obj.lane_frames=0
        end
        obj.lane_frames=obj.lane_frames+1
        if obj.lane_frames>=c.lane_progress_window then
            local advance=(px-obj.anchor_x)*dir
            if advance<c.lane_min_progress then
                obj.stalled_events=obj.stalled_events+1
                obj.abort_frames=c.lane_abort_frames
                obj.progress_event={kind="LANE_STALLED",carrier=carrier,
                    progress=advance,elapsed=obj.lane_frames,
                    stalled=obj.stalled_events}
                obj.lane_direction=nil
                obj.lane_lock_frames=0
                obj.anchor_x,obj.anchor_y=nil,nil
                obj.lane_frames=0
                return true
            else
                obj.progress_event={kind="LANE_PROGRESS",carrier=carrier,
                    progress=advance,elapsed=obj.lane_frames}
                obj.anchor_x,obj.anchor_y=px,py
                obj.lane_frames=0
            end
        end
        return false
    end

    local function reset_lane_window()
        obj.anchor_x,obj.anchor_y=nil,nil
        obj.lane_frames=0
    end

    function obj.target_for_carrier(carrier_base, shot_diag)
        if not players.valid_my_base(carrier_base) then obj.reset(); return nil end
        local px, py = players.xy(carrier_base)
        local my_side, dir = field_side.my_side(), field_side.attack_direction()
        if my_side == nil or dir == 0 then obj.reset(); return nil end

        local gx, gy = players.xy(config.CPU_FIRST)
        if monitor_lane(carrier_base,px,py,dir) then
            -- After stalled zigzags, progress directly without restarting Y.
            return {mode="RECOVER",carrier=carrier_base,
                player_x=px,player_y=py,
                target_x=px+dir*config.ATTACK.advance_distance,
                target_y=py,direction=dir,my_side=my_side,
                goal_target_x=gx,goal_target_y=gy,
                goal_distance=distance(px,py,gx,gy),
                abort_remaining=obj.abort_frames}
        end
        if shot_diag and shot_diag.reason == "BLOCKED_LANE" then
            local offset = config.ATTACK.lane_offset_y
            local up_y, down_y = py - offset, py + offset
            local up_clearance = clearance_at(px, up_y)
            local down_clearance = clearance_at(px, down_y)
            local lane_dir
            if obj.lane_direction ~= nil and obj.lane_lock_frames > 0 then
                lane_dir = obj.lane_direction
                obj.lane_lock_frames = obj.lane_lock_frames - 1
            else
                local up_score = up_clearance - 0.25 * distance(px, up_y, gx, gy)
                local down_score = down_clearance - 0.25 * distance(px, down_y, gx, gy)
                lane_dir = up_score >= down_score and -1 or 1
                obj.lane_direction = lane_dir
                obj.lane_lock_frames = config.ATTACK.lane_lock_frames
            end
            return {
                mode="LANE", carrier=carrier_base, player_x=px, player_y=py,
                target_x=px, target_y=py + lane_dir * offset,
                direction=dir, my_side=my_side, advance_distance=0,
                lane_direction=lane_dir, lane_lock_frames=obj.lane_lock_frames,
                blocker_base=shot_diag.blocker, blocker_forward=nil,
                blocker_lateral=nil, up_clearance=up_clearance,
                down_clearance=down_clearance, lane_reason="SHOT_BLOCKED",
                goal_target_x=gx, goal_target_y=gy,
                goal_distance=distance(px, py, gx, gy)
            }
        end
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
