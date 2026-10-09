-- The individual ball-owner address is global and exclusive across both teams.
-- Logical team RAM is not authoritative when it contradicts a confirmed owner.
local M = {}
function M.new(config, mem, players)
    local obj = {}
    function obj.read()
        return mem.u8(config.ADDR.team_possession)
    end
    function obj.raw_kind(value)
        if value==0 then return "MY"
        elseif value==1 then return "CPU" end
        return "UNKNOWN"
    end
    function obj.owner_kind(owner)
        if players.valid_my_base(owner) then return "MY" end
        if players.valid_cpu_base(owner) then return "CPU" end
        return "NONE"
    end
    function obj.resolve(value,owner)
        local confirmed=obj.owner_kind(owner)
        local logical=obj.raw_kind(value)
        if confirmed~="NONE" then
            return confirmed,"PLAYER_BALL_POSSESSION",
                logical~="UNKNOWN" and logical~=confirmed
        end
        return logical,"LOGICAL_TEAM_UNVERIFIED",false
    end
    function obj.kind(value,owner)
        if owner~=nil then
            local resolved=obj.resolve(value,owner)
            return resolved
        end
        return obj.raw_kind(value)
    end
    -- These helpers refer to raw RAM only; use resolve() when a player owner exists.
    function obj.is_my(value) return value==0 end
    function obj.is_cpu(value) return value==1 end
    function obj.is_valid(value) return value==0 or value==1 end
    return obj
end
return M
