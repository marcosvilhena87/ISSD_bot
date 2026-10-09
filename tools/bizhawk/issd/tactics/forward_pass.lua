-- Zone-aware ground B passes: progressive in thirds 1/2, lateral in third 3.
-- World field coordinates are candidates; fail closed on invalid geometry.
local M={}
function M.new(config,players,field_side,mem)
    local obj={cooldown=0,last_carrier=nil}
    local c=config.FORWARD_PASS
    local function distance(x,y,a,b)
        return math.sqrt((x-a)^2+(y-b)^2)
    end
    local function zone_for(x,dir)
        local len=mem.u16(config.ADDR.field_length)
        local center=mem.u16(config.ADDR.center_field_x)
        if len<500 or len>4000 or center<100 or dir==0 then return nil end
        local start=center-dir*len/2
        local forward=(x-start)*dir
        if forward<0 or forward>len then return nil end
        return math.min(3,1+math.floor(forward/(len/3)))
    end
    local function deep_lateral_safe(px,py,rx,ry,dir,receiver_clearance)
     local cfg=config.DEEP_DEFENSIVE_LATERAL
     local length=mem.u16(config.ADDR.field_length)
     local center=mem.u16(config.ADDR.center_field_x)
     if length<500 or length>4000 or center<100 then return false end
     local own_goal=center-dir*length/2
     if (px-own_goal)*dir>cfg.max_own_goal_distance then return true end
     -- Direction+B follows the cardinal vertical lane at the passer's X,
     -- not the diagonal segment to a teammate offset horizontally.
     if math.abs(rx-px)>cfg.max_receiver_axis_offset
        or receiver_clearance<cfg.min_receiver_clearance then return false end
     local lane=math.huge
     local cpu_landing=math.huge
     local bx,by=px,ry
     players.each_cpu(function(base)
      local ex,ey=players.xy(base)
      local t=(ey-py)/(ry-py)
      if t>=0 and t<=1 then
       lane=math.min(lane,math.abs(ex-px))
      end
      cpu_landing=math.min(cpu_landing,distance(ex,ey,bx,by))
     end)
     local my_landing=distance(rx,ry,bx,by)
     return lane>=cfg.min_lane_clearance
        and cpu_landing-my_landing>=cfg.min_cpu_arrival_margin
    end
    function obj.tick()
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
    end
    function obj.reset()
        obj.cooldown=0;obj.last_carrier=nil
    end
    function obj.plan(carrier, prefer_central)
        if obj.cooldown>0 or not players.valid_my_base(carrier)
            or carrier==config.MY_FIRST then return nil end
        local dir=field_side.attack_direction()
        if dir~=1 and dir~=-1 then return nil end
        local px,py=players.xy(carrier)
        local _,goal_y=players.xy(config.CPU_FIRST)
        local zone=zone_for(px,dir)
        if not zone then return nil end
        local best=nil
        players.each_my(function(base)
            if base~=carrier and base~=config.MY_FIRST then
                local rx,ry=players.xy(base)
                local forward=(rx-px)*dir
                local vertical=ry-py
                local lateral=math.abs(vertical)
                local d=distance(px,py,rx,ry)
                local suitable=false
                local direction=nil
                local intent=nil
                if zone<3 then
                    suitable=forward>=c.min_forward
                        and forward<=c.max_forward
                        and lateral<=c.max_lateral and d<=c.max_distance
                    direction=dir==1 and "Right" or "Left"
                    intent="PROGRESSIVE"
                else
                    suitable=lateral>=c.lateral_min
                        and lateral<=c.lateral_max
                        and math.abs(forward)<=c.lateral_max_forward
                        and d<=c.lateral_max_distance
                    direction=vertical<0 and "Up" or "Down"
                    intent="LATERAL"
                end
                -- In the final third, a centralizing lateral outlet must
                -- move the ball closer to the goalkeeper's lateral coordinate.
                if prefer_central then
                    suitable=suitable and zone==3
                        and math.abs(ry-goal_y)+20<math.abs(py-goal_y)
                end
                if suitable and zone_for(rx,dir)~=nil then
                    local receiver_clearance=99999
                    local corridor=99999
                    local dx,dy=rx-px,ry-py
                    players.each_cpu(function(cpu)
                        local ex,ey=players.xy(cpu)
                        receiver_clearance=math.min(receiver_clearance,
                            distance(rx,ry,ex,ey))
                        local t=((ex-px)*dx+(ey-py)*dy)/(d*d)
                        if t>0.05 and t<1.1 then
                            local q=math.max(0,math.min(1,t))
                            corridor=math.min(corridor,
                                distance(ex,ey,px+q*dx,py+q*dy))
                        end
                    end)
                    local min_rc=zone==3 and c.lateral_receiver_clearance
                        or c.min_receiver_clearance
                    local min_lc=zone==3 and c.lateral_lane_clearance
                        or c.min_lane_clearance
                    if receiver_clearance>=min_rc and corridor>=min_lc
                        and (intent~="LATERAL" or deep_lateral_safe(px,py,rx,ry,dir,receiver_clearance)) then
                        local score=math.min(receiver_clearance,180)*c.weight_clearance
                            +math.min(corridor,180)*c.weight_lane
                        if zone<3 then
                            score=score+forward*c.weight_progress-lateral*c.weight_lateral
                        else
                            score=score+0.2*math.max(forward,0)
                                -0.5*math.abs(forward)
                                -0.1*lateral
                        end
                        if prefer_central then
                            score=score+0.7*(math.abs(py-goal_y)-math.abs(ry-goal_y))
                        end
                        if not best or score>best.score then
                            best={receiver=base,distance=d,forward=forward,
                                lateral=lateral,receiver_clearance=receiver_clearance,
                                lane_clearance=corridor,score=score,
                                direction=direction,button=c.button,
                                carrier=carrier,zone=zone,intent=intent}
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
