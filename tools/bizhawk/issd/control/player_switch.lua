local M = {}

function M.new(config, players)
    local obj = {
        cooldown = 0,
        last_requested_from = nil,
        last_best = nil,
        last_current_distance = nil,
        last_best_distance = nil,
        last_improvement = nil,
        pending = nil,
        event = nil,
        settle = 0,
    }

    local function distance(ax, ay, bx, by)
        local dx = bx - ax
        local dy = by - ay
        return math.sqrt(dx * dx + dy * dy)
    end

    local function best_my_player(target_x, target_y)
        local best_base = nil
        local best_distance = nil

        players.each_my(function(base)
            if not (config.PLAYER_SWITCH.exclude_goalkeeper
                    and base == config.MY_FIRST) then
                local px, py = players.xy(base)
                local d = distance(px, py, target_x, target_y)

                if best_distance == nil or d < best_distance then
                    best_base = base
                    best_distance = d
                end
            end
        end)

        return best_base, best_distance
    end

    function obj.observe_control(actual)
        local pending=obj.pending
        if not pending then return end
        pending.age=pending.age+1
        if actual~=pending.from and players.valid_my_base(actual) then
            -- R cycles through players; the closest candidate is not
            -- necessarily the next player selected by the game.
            local ax,ay=players.xy(actual)
            local actual_distance=distance(ax,ay,pending.target_x,pending.target_y)
            local gain=pending.current_distance-actual_distance
            obj.event={kind=actual==pending.best and "SWITCH_CONFIRMED" or
                (gain>0 and "SWITCH_IMPROVED" or "SWITCH_WORSENED"),
                from=pending.from, expected=pending.best, actual=actual,
                age=pending.age,actual_distance=actual_distance,
                previous_distance=pending.current_distance,actual_gain=gain}
            obj.pending=nil
            obj.settle=config.PLAYER_SWITCH.settle_frames
        elseif pending.age>=config.PLAYER_SWITCH.verify_frames then
            obj.event={kind="SWITCH_UNCHANGED",from=pending.from,
                expected=pending.best,actual=actual,age=pending.age}
            obj.pending=nil
            obj.settle=config.PLAYER_SWITCH.settle_frames
        end
    end

    function obj.take_event()
        local event=obj.event
        obj.event=nil
        return event
    end

    function obj.tick()
        if obj.settle>0 then obj.settle=obj.settle-1 end
        if obj.cooldown > 0 then
            obj.cooldown = obj.cooldown - 1
        end
    end

    function obj.reset()
        obj.cooldown = 0
        obj.last_requested_from = nil
        obj.last_best = nil
        obj.last_current_distance = nil
        obj.last_best_distance = nil
        obj.last_improvement = nil
        obj.pending=nil; obj.event=nil; obj.settle=0
    end

    function obj.consider(my_base, target_x, target_y)
        if not players.valid_my_base(my_base) then
            return {should_switch=false,pending=obj.pending~=nil,
                button=config.PLAYER_SWITCH.button}
        end
        local px, py = players.xy(my_base)
        local current_distance = distance(px, py, target_x, target_y)
        local best_base, best_distance = best_my_player(target_x, target_y)

        local improvement = 0
        if best_distance ~= nil then
            improvement = current_distance - best_distance
        end

        local should_switch =
            obj.cooldown == 0 and obj.settle == 0 and obj.pending == nil
            and best_base ~= nil
            and best_base ~= my_base
            and improvement > config.PLAYER_SWITCH.improvement_margin

        if should_switch then
            obj.cooldown = config.PLAYER_SWITCH.cooldown_frames
            obj.pending={from=my_base,best=best_base,age=0,
                target_x=target_x,target_y=target_y,current_distance=current_distance}
            obj.last_requested_from = my_base
            obj.last_best = best_base
            obj.last_current_distance = current_distance
            obj.last_best_distance = best_distance
            obj.last_improvement = improvement
        end

        return {
            should_switch = should_switch,
            current_base = my_base,
            best_base = best_base,
            current_distance = current_distance,
            best_distance = best_distance,
            improvement = improvement,
            cooldown = obj.cooldown,
            pending = obj.pending~=nil,
            button = config.PLAYER_SWITCH.button,
        }
    end

    return obj
end

return M
