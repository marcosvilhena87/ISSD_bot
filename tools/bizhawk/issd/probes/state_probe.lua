-- ISSD Bot - State Probe
-- Enderecos candidatos derivados dos arquivos .wch fornecidos.
-- Status: ainda precisam ser validados em execucao na ROM-alvo.

local DOMAIN = "WRAM"

local ADDR = {
    ball_x_world = 0x042A,
    ball_y_world = 0x042C,
    ball_x_cam   = 0x1FFA6,
    ball_y_cam   = 0x1FFA8,

    possession   = 0x00A6,
    game_state   = 0x00BA,

    my_side      = 0x056E,
    cpu_side     = 0x106E,

    my_ctrl      = 0x1ACC,
    cpu_ctrl     = 0x1AFC,

    my_ctrl_x_cam  = 0x1AA8,
    my_ctrl_y_cam  = 0x1AAC,
    cpu_ctrl_x_cam = 0x1AD8,
    cpu_ctrl_y_cam = 0x1ADC,
}

local function s16(addr)
    return memory.read_s16_le(addr, DOMAIN)
end

local function u16(addr)
    return memory.read_u16_le(addr, DOMAIN)
end

local function u8(addr)
    return memory.read_u8(addr, DOMAIN)
end

while true do
    local bx = s16(ADDR.ball_x_world)
    local by = s16(ADDR.ball_y_world)
    local bcx = s16(ADDR.ball_x_cam)
    local bcy = s16(ADDR.ball_y_cam)

    local possession = u16(ADDR.possession)
    local game_state = u16(ADDR.game_state)

    local my_ctrl = u16(ADDR.my_ctrl)
    local cpu_ctrl = u16(ADDR.cpu_ctrl)

    gui.text(8, 8,  string.format("Ball world: X=%d Y=%d", bx, by))
    gui.text(8, 22, string.format("Ball cam:   X=%d Y=%d", bcx, bcy))
    gui.text(8, 36, string.format("Possession=%d GameState=%d", possession, game_state))
    gui.text(8, 50, string.format("MyCtrl=%d CPUCtrl=%d", my_ctrl, cpu_ctrl))
    gui.text(8, 64, string.format("Side my=%d cpu=%d", u8(ADDR.my_side), u8(ADDR.cpu_side)))
    gui.text(8, 78, string.format(
        "MyCtrl cam=(%d,%d)",
        s16(ADDR.my_ctrl_x_cam),
        s16(ADDR.my_ctrl_y_cam)
    ))

    emu.frameadvance()
end
