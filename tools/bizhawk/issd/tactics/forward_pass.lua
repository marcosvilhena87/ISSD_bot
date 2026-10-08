-- Conservative forward B passes for controlled outfield carriers.
-- Directional B accuracy is experimental: target must align with attack axis.
local M={}
function M.new(config,players,field_side)
    local obj={cooldown=0,last_carrier=nil}
    local c=config.FORWARD_PASS
    local function distance(x,y,a,b)
        return math.sqrt((x-a)^2+(y-b)^2)
    end
    function obj.tick()
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
    end
    function obj.reset()
        obj.cooldown=0
        obj.last_carrier=nil
    end
    function obj.plan(carrier)
        if obj.cooldown>0 or not players.valid_my_base(carrier)
            or carrier==config.MY_FIRST then return nil end
        local dir=field_side.attack_direction()
        if dir~=1 and dir~=-1 then return nil end
        local px,py=players.xy(carrier)
        local best=nil
        players.each_my(function(base)
            if base~=carrier and base~=config.MY_FIRST then
                local rx,ry=players.xy(base)
                local forward=(rx-px)*dir
                local lateral=math.abs(ry-py)
                local d=distance(px,py,rx,ry)
                if forward>=c.min_forward and forward<=c.max_forward
                    and lateral<=c.max_lateral and d<=c.max_distance then
                    local receiver_clearance=99999
                    local corridor=99999
                    players.each_cpu(function(cpu)
                        local ex,ey=players.xy(cpu)
                        receiver_clearance=math.min(receiver_clearance,
                            distance(rx,ry,ex,ey))
                        -- Segment projection; ignore opponents behind passer.
                        local dx,dy=rx-px,ry-py
                        local t=((ex-px)*dx+(ey-py)*dy)/(d*d)
                        if t>0.05 and t<1.1 then
                            local q=math.max(0,math.min(1,t))
                            corridor=math.min(corridor,
                                distance(ex,ey,px+q*dx,py+q*dy))
                        end
                    end)
                    if receiver_clearance>=c.min_receiver_clearance
                        and corridor>=c.min_lane_clearance then
                        local score=forward*c.weight_progress
                            +math.min(receiver_clearance,180)*c.weight_clearance
                            +math.min(corridor,180)*c.weight_lane
                            -lateral*c.weight_lateral
                        if not best or score>best.score then
                            best={receiver=base,distance=d,forward=forward,
                                lateral=lateral,receiver_clearance=receiver_clearance,
                                lane_clearance=corridor,score=score,
                                direction=dir==1 and "Right" or "Left",
                                button=c.button,carrier=carrier}
                        end
                    end
                end
            end
        end)
        return best
    end
    function obj.fire(plan,movement)
        if not plan or obj.cooldown>0 then return false end
        movement.press_direction_button(plan.direction,plan.button)
        obj.cooldown=c.cooldown_frames
        obj.last_carrier=plan.carrier
        return true
    end
    return obj
end
return M
