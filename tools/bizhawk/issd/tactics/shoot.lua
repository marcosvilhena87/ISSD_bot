-- Conservative shooting policy for SNES ISS Deluxe (X = shoot).
local M = {}
function M.new(config, players, field_side)
    local obj={cooldown=0, last_carrier=nil, last_diagnostic=nil}
    function obj.tick()
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
    end
    function obj.reset()
        obj.cooldown=0
        obj.last_carrier=nil
        obj.last_diagnostic=nil
    end
    function obj.plan(carrier)
        local c=config.SHOOT
        local diag={reason="UNKNOWN", cooldown=obj.cooldown}
        obj.last_diagnostic=diag
        if not players.valid_my_base(carrier) or carrier==config.MY_FIRST then
            diag.reason="INVALID_CARRIER"; return nil
        end
        local dir=field_side.attack_direction()
        if dir==0 then diag.reason="INVALID_SIDE"; return nil end
        local px,py=players.xy(carrier)
        local gx,gy=players.xy(config.CPU_FIRST)
        local fx=(gx-px)*dir
        local dx,dy=gx-px,gy-py
        local d=math.sqrt(dx*dx+dy*dy)
        local nearest=99999
        players.each_cpu(function(base)
            if base~=config.CPU_FIRST then
                local ex,ey=players.xy(base)
                local dd=math.sqrt((ex-px)^2+(ey-py)^2)
                if dd<nearest then nearest=dd end
            end
        end)
        local lateral=math.abs(dy)
        local angle=math.deg(math.atan(lateral/math.max(math.abs(dx),0.001)))
        diag.shot_angle=angle
        diag.lateral_offset=lateral
        diag.distance=d
        diag.forward=fx
        diag.goal_x,diag.goal_y=gx,gy
        if obj.cooldown>0 then diag.reason="COOLDOWN"; return nil end
        if fx<c.min_forward_distance then
            diag.reason="GOAL_BEHIND"; return nil
        end
        if d>c.max_distance then diag.reason="TOO_FAR"; return nil end
        if d<1 then diag.reason="GOAL_TOO_CLOSE"; return nil end
        if angle>c.max_shot_angle then
            diag.reason="BAD_SHOT_ANGLE"; return nil
        end
        -- Check whether a defender obstructs the segment to goal.
        local blocked=false
        local blocker=nil
        local blocker_distance=nil
        players.each_cpu(function(base)
            if base~=config.CPU_FIRST then
                local ex,ey=players.xy(base)
                local exr,eyr=ex-px,ey-py
                local along=(exr*dx+eyr*dy)/(d*d)
                local lateral=math.abs(exr*dy-eyr*dx)/d
                if along>0 and along<1 and lateral<c.lane_half_width then
                    blocked=true
                    if blocker_distance==nil or along<blocker_distance then
                        blocker=base; blocker_distance=along
                    end
                end
            end
        end)
        if blocked then
            diag.reason="BLOCKED_LANE"
            diag.blocker=blocker
            diag.blocker_fraction=blocker_distance
            return nil
        end
        diag.reason="READY"
        local direction=dir==1 and "Right" or "Left"
        return {button=c.button,direction=direction,distance=d,
            goal_x=gx,goal_y=gy,carrier=carrier,
            lateral_offset=lateral, shot_angle=angle,
            nearest_defender=nearest}
    end
    function obj.fire(plan,movement)
        if not plan or obj.cooldown>0 then return false end
        movement.press_direction_button(plan.direction,plan.button)
        obj.cooldown=config.SHOOT.cooldown_frames
        obj.last_carrier=plan.carrier
        return true
    end
    return obj
end
return M
