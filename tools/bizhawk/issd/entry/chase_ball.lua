-- Deprecated compatibility launcher.
-- Prefer: tools/bizhawk/issd/entry/main.lua

local function script_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return source:match("^(.*[\\/])") or "./"
end

console.log("[ISSD] chase_ball.lua is deprecated; use tools/bizhawk/issd/entry/main.lua")
dofile(script_dir() .. "main.lua")
