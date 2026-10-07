-- ISSD Bot - launcher
-- Mantido por compatibilidade: a implementacao vive em tools/bizhawk/issd/.

local function script_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return source:match("^(.*[\\/])") or "./"
end

dofile(script_dir() .. "issd/main.lua")
