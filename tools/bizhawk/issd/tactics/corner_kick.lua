-- GS=1 attacking corner, provisional WRAM field bounds.
-- Only acts for a Brazilian outfielder near a corner of the opponent's endline.
local M={}
function M.new(config,players,field_side,mem)
    local c=config.CORNER_KICK
    local obj={taker=nil,stable=0,attempts=0,cooldown=0}
    function obj.reset()
        obj.taker=nil;obj.stable=0;obj.attempts=0;obj.cooldown=0
    end
    function obj.plan(bx,by,taker,team)
        if obj.cooldown>0 then obj.cooldown=obj.cooldown-1 end
        local dir=field_side.attack_direction()
        if team~="MY" or not players.valid_my_base(taker)
            or taker==config.MY_FIRST or dir==0 then
            obj.taker=nil;obj.stable=0
            return nil
        end
        local length=mem.u16(config.ADDR.field_length)
        local width=mem.u16(config.ADDR.field_width)
        local cx=mem.u16(config.ADDR.center_field_x)
        local cy=mem.u16(config.ADDR.center_field_y)
        if length<500 or length>4000 or width<200 or width>2000 then return nil end
        local end_x=cx+dir*length/2
        local edge_y=width/2
        local end_distance=math.abs(bx-end_x)
        local side_distance=math.abs(math.abs(by-cy)-edge_y)
        local px,py=players.xy(taker)
        local taker_distance=math.sqrt((px-bx)^2+(py-by)^2)
        if end_distance>c.endline_tolerance
            or side_distance>c.sideline_tolerance
            or taker_distance>c.max_taker_distance then
            obj.taker=nil;obj.stable=0
            return nil
        end
        if obj.taker~=taker then
            obj.taker=taker;obj.stable=0;obj.attempts=0
        end
        obj.stable=obj.stable+1
        local direction=by>cy and "Up" or "Down"
        local mode=obj.attempts==0 and "CROSS" or "SHORT_RETRY"
        local reason="READY"
        if obj.stable<c.stable_frames then reason="STABILIZING"
        elseif obj.attempts>=c.max_attempts then reason="EXHAUSTED"
        elseif obj.cooldown>0 then reason="COOLDOWN" end
        return {mode=mode,button=obj.attempts==0 and c.cross_button or c.short_button,
            direction=direction,taker=taker,stable=obj.stable,
            end_distance=end_distance,side_distance=side_distance,
            taker_distance=taker_distance,attempts=obj.attempts,
            cooldown=obj.cooldown,reason=reason}
    end
    function obj.fire(plan,movement)
        if not plan or obj.stable<c.stable_frames
            or obj.cooldown>0 or obj.attempts>=c.max_attempts then return false end
        movement.press_direction_button(plan.direction,plan.button)
        obj.attempts=obj.attempts+1
        obj.cooldown=c.retry_frames
        return true
    end
    return obj
end
return M
