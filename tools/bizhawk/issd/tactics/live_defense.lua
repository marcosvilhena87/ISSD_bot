local M = {}

function M.new(config, players, field_side)
    local obj = {}

    local function goal_direction(my_side)
        if my_side == 0 then
            return -1
        elseif my_side == 1 then
            return 1
        end
        return 0
    end

    function obj.goalkeeper_policy(my_base, carrier_base)
        if carrier_base ~= config.CPU_FIRST then
            return nil
        end

        local px, py = players.xy(my_base)
        local gx, gy = players.xy(carrier_base)
        local dx = gx - px
        local dy = gy - py
        local distance = math.sqrt(dx * dx + dy * dy)
        local threshold = config.LIVE_DEFENSE.gk_press_distance

        return {
            distance = distance,
            threshold = threshold,
            should_press = distance <= threshold,
        }
    end

    function obj.target_for_carrier(carrier_base)
        if not players.valid_cpu_base(carrier_base) then
            return nil
        end

        local cx, cy = players.xy(carrier_base)
        local my_side = field_side.my_side()
        local dir = field_side.goal_direction()

        if my_side == nil or dir == 0 then
            return nil
        end

        local tx = cx + dir * config.LIVE_DEFENSE.goal_side_offset
        local ty = cy

        return {
            carrier = carrier_base,
            carrier_x = cx,
            carrier_y = cy,
            target_x = tx,
            target_y = ty,
            my_side = my_side,
        }
    end

    -- Emergency box coverage: prioritize an unmarked second attacker near goal.
    -- GK world position is a provisional goalmouth anchor; calibrate in play.
    function obj.box_threat(carrier_base, ball_x, ball_y)
        local c=config.BOX_COVERAGE
        local gx,gy=players.xy(config.MY_FIRST)
        -- A carrier at the goalmouth is the immediate threat: never abandon it.
        if players.valid_cpu_base(carrier_base) then
            local cx,cy=players.xy(carrier_base)
            if (cx-gx)^2+(cy-gy)^2
                <=c.carrier_emergency_radius*c.carrier_emergency_radius then
                return nil
            end
        end
        local dx,dy=ball_x-gx,ball_y-gy
        if dx*dx+dy*dy>c.activation_radius*c.activation_radius then
            return nil
        end
        local best=nil
        players.each_cpu(function(base)
            if base~=config.CPU_FIRST and base~=carrier_base then
                local ex,ey=players.xy(base)
                local goal_distance=math.sqrt((ex-gx)^2+(ey-gy)^2)
                local ball_distance=math.sqrt((ex-ball_x)^2+(ey-ball_y)^2)
                if goal_distance<=c.threat_goal_radius
                    and ball_distance<=c.threat_ball_radius then
                    local defender_distance=99999
                    players.each_my(function(my)
                        if my~=config.MY_FIRST then
                            local mx,myy=players.xy(my)
                            local d=math.sqrt((mx-ex)^2+(myy-ey)^2)
                            if d<defender_distance then defender_distance=d end
                        end
                    end)
                    -- Highest danger: near goal, near loose ball, and unmarked.
                    local score=(c.threat_goal_radius-goal_distance)
                        +0.6*(c.threat_ball_radius-ball_distance)
                        +0.5*math.min(defender_distance,160)
                    if not best or score>best.score then
                        best={base=base,x=ex,y=ey,score=score,
                            goal_distance=goal_distance,
                            ball_distance=ball_distance,
                            nearest_defender=defender_distance,
                            goalkeeper_x=gx,goalkeeper_y=gy}
                    end
                end
            end
        end)
        if best and best.nearest_defender>=c.unmarked_distance then
            return best
        end
        return nil
    end

    return obj
end

return M
