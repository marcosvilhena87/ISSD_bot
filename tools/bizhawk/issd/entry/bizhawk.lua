-- ISSD Bot - official BizHawk entry point
--
-- Open this file in BizHawk:
--   Tools -> Lua Console -> Open Script -> tools/bizhawk/issd/entry/bizhawk.lua

local function script_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return source:match("^(.*[\\/])") or "./"
end

dofile(script_dir() .. "../app/main.lua")
