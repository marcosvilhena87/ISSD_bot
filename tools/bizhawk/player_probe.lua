-- ISSD Bot - Player Structure Probe
-- Valida a estrutura generica dos jogadores a partir de MyCtrl/CPUCtrl.
--
-- Hipoteses atuais:
--   base + 0x08 -> camera X
--   base + 0x0C -> camera Y
--   base + 0x2A -> world X
--   base + 0x2C -> world Y
--
-- MyCtrl   WRAM 0x1ACC
-- CPUCtrl  WRAM 0x1AFC
-- Possess. WRAM 0x00A6
-- Ball X/Y WRAM 0x042A / 0x042C

local DOMAIN = "WRAM"

local ADDR = {
    ball_x = 0x042A,
    ball_y = 0x042C,
    ball_cam_x = 0x1FFA6,
    ball_cam_y = 0x1FFA8,

    possession = 0x00A6,
    my_ctrl = 0x1ACC,
    cpu_ctrl = 0x1AFC,
}

local OFFSET = {
    cam_x = 0x08,
    cam_y = 0x0C,
    world_x = 0x2A,
    world_y = 0x2C,
}

local function s16(addr)
    return memory.read_s16_le(addr, DOMAIN)
end

local function u16(addr)
    return memory.read_u16_le(addr, DOMAIN)
end

local function decode_player_base(base)
    if base >= 0x0500 and base <= 0x0F00 and base % 0x100 == 0 then
        local slot = math.floor((base - 0x0500) / 0x100)
        if base == 0x0D00 then return "MY Beranco" end
        if base == 0x0E00 then return "MY Gomez" end
        if base == 0x0F00 then return "MY Allejo" end
        if slot == 0 then return "MY GK" end
        return string.format("MY slot %d", slot + 1)
    end

    if base >= 0x1000 and base <= 0x1A00 and base % 0x100 == 0 then
        local slot = math.floor((base - 0x1000) / 0x100)
        if slot == 0 then return "CPU GK" end
        return string.format("CPU slot %d", slot + 1)
    end

    if base == 0 then
        return "FREE/NONE"
    end

    return string.format("UNKNOWN $%04X", base)
end

local function read_player(base)
    return {
        base = base,
        cam_x = s16(base + OFFSET.cam_x),
        cam_y = s16(base + OFFSET.cam_y),
        world_x = s16(base + OFFSET.world_x),
        world_y = s16(base + OFFSET.world_y),
    }
end

while true do
    local my_base = u16(ADDR.my_ctrl)
    local cpu_base = u16(ADDR.cpu_ctrl)
    local possession = u16(ADDR.possession)

    local my = read_player(my_base)
    local cpu = read_player(cpu_base)

    local bx = s16(ADDR.ball_x)
    local by = s16(ADDR.ball_y)
    local bcx = s16(ADDR.ball_cam_x)
    local bcy = s16(ADDR.ball_cam_y)

    local dx = bx - my.world_x
    local dy = by - my.world_y

    gui.text(8, 8, string.format("Ball world=(%d,%d)", bx, by))
    gui.text(8, 22, string.format("Ball cam=(%d,%d)", bcx, bcy))

    gui.text(8, 40, string.format(
        "MyCtrl=$%04X %s",
        my_base,
        decode_player_base(my_base)
    ))
    gui.text(8, 54, string.format(
        "My world=(%d,%d) cam=(%d,%d)",
        my.world_x, my.world_y, my.cam_x, my.cam_y
    ))
    gui.text(8, 68, string.format(
        "Delta ball-my=(%d,%d)",
        dx, dy
    ))

    gui.text(8, 86, string.format(
        "CPUCtrl=$%04X %s",
        cpu_base,
        decode_player_base(cpu_base)
    ))
    gui.text(8, 100, string.format(
        "CPU world=(%d,%d) cam=(%d,%d)",
        cpu.world_x, cpu.world_y, cpu.cam_x, cpu.cam_y
    ))

    gui.text(8, 118, string.format(
        "Possession=$%04X %s",
        possession,
        decode_player_base(possession)
    ))

    emu.frameadvance()
end
