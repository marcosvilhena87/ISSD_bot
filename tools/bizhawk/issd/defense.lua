local M = {}

function M.new(config, players, geometry)
    local obj = {}

    function obj.nearest_cpu_mark_target(my_base, excluded_base)
        local mx, my = players.xy(my_base)
        local best_base = nil
        local best_d2 = nil

        players.each_cpu(function(base)
            if base ~= excluded_base then
                local px, py = players.xy(base)
                local d2 = geometry.dist2(mx, my, px, py)
                if best_d2 == nil or d2 < best_d2 then
                    best_d2 = d2
                    best_base = base
                end
            end
        end)

        return best_base, best_d2
    end

    return obj
end

return M
