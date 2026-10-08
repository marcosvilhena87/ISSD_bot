-- Conservative shooting policy for SNES ISS Deluxe (X = shoot).
local M = {}
function M.new(config, players, field_side)
    local obj={cooldown=0, last_carrier=nil}
    function obj.tick()
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
    end
    function obj.reset()
        obj.cooldown=0
        obj.last_carrier=nil
    end
    function obj.plan(carrier)
        local c=config.SHOOT
        if not players.valid_my_base(carrier) or carrier==config.MY_FIRST then return nil end
        if obj.cooldown>0 then return nil end
        local dir=field_side.attack_direction()
        if dir==0 then return nil end
        local px,py=players.xy(carrier)
        local gx,gy=players.xy(config.CPU_FIRST)
        local fx=(gx-px)*dir
        local dx,dy=gx-px,gy-py
        local d=math.sqrt(dx*dx+dy*dy)
        if fx<c.min_forward_distance or d>c.max_distance then return nil end
        -- Check whether a defender obstructs the segment to goal.
        local blocked=false
        players.each_cpu(function(base)
            if base~=config.CPU_FIRST then
                local ex,ey=players.xy(base)
                local exr,eyr=ex-px,ey-py
                local along=(exr*dx+eyr*dy)/(d*d)
                local lateral=math.abs(exr*dy-eyr*dx)/d
                if along>0 and along<1 and lateral<c.lane_half_width then
                    blocked=true
                end
            end
        end)
        if blocked then return nil end
        local direction=dir==1 and "Right" or "Left"
        return {button=c.button,direction=direction,distance=d,
            goal_x=gx,goal_y=gy,carrier=carrier}
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
