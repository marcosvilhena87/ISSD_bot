local M = {}

M.DOMAIN = "WRAM"
M.PLAYER = 1

M.ADDR = {
    ball_x = 0x042A,
    ball_y = 0x042C,
    possession = 0x00A6,
    game_state = 0x00BA,
    my_side = 0x056E,
    cpu_side = 0x106E,
    my_ctrl = 0x1ACC,
    cpu_ctrl = 0x1AFC,
}

M.OFFSET = {
    cam_x = 0x08,
    cam_y = 0x0C,
    world_x = 0x2A,
    world_y = 0x2C,
}

M.MY_FIRST = 0x0500
M.MY_LAST = 0x0F00
M.CPU_FIRST = 0x1000
M.CPU_LAST = 0x1A00
M.PLAYER_STRIDE = 0x100

M.DEADZONE_X = 8
M.DEADZONE_Y = 8

-- Defesa em jogo corrido:
-- ponto-alvo fica goal_side_offset unidades do lado do nosso gol
-- em relacao ao portador da CPU.
M.LIVE_DEFENSE = {
    goal_side_offset = 48,
}

-- Contexto temporal de posse quando 0x00A6 volta para zero.
-- Evita tratar imediatamente passe/chute como bola neutra.
M.POSSESSION_CONTEXT = {
    grace_frames = 18,
    initial_grace_frames = 2,
    moving_threshold = 2.0,
}

-- Menor score = alvo defensivo mais prioritario.
M.DEFENSE = {
    weight_to_me = 0.35,
    weight_to_ball = 0.25,
    weight_to_goal = 0.40,

    -- Histerese da marcacao durante RESTART_DEFENSE.
    target_lock_frames = 10,
    switch_margin = 0.05,
    switch_event_frames = 60,
}

return M
