-- ISSD Bot - State Probe
-- Preencha os endereços abaixo depois que RAM_MAP.md tiver candidatos confirmados.

local DOMAIN = "WRAM"

local ADDR = {
    ball_x = nil,
    ball_y = nil,
}

while true do
    if ADDR.ball_x and ADDR.ball_y then
        local x = memory.read_u8(ADDR.ball_x, DOMAIN)
        local y = memory.read_u8(ADDR.ball_y, DOMAIN)
        gui.text(10, 10, string.format("Ball X=%d Y=%d", x, y))
    else
        gui.text(10, 10, "ISSD Bot: Ball X/Y ainda nao mapeados")
    end

    emu.frameadvance()
end
