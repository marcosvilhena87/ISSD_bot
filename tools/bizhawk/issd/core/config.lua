local M = {}

M.DOMAIN = "WRAM"
M.PLAYER = 1

M.ADDR = {
    gameplay_active = 0x0006,
    ball_x = 0x042A,
    ball_y = 0x042C,
    possession = 0x00A6,
    team_possession = 0x104C,
    game_state = 0x00BA,
    -- Legacy/unstable: 0x056E changes with player state (e.g. GK possession).
    -- Do not use for orientation decisions.
    my_side = 0x056E,

    -- Validated operational source for field orientation.
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
-- Ataque em jogo corrido.
-- Primeiro baseline: conduzir reto na direcao do gol adversario.
M.ATTACK = {
    advance_distance = 96,

    -- Corredor frontal: se houver CPU dentro desta janela, desviar.
    blocker_forward_distance = 72,
    blocker_lateral_half_width = 32,

    -- Alvo diagonal para contornar o primeiro bloqueador.
    lane_forward_distance = 80,
    lane_offset_y = 56,

    -- Evita oscilacao UP/DOWN enquanto contorna.
    lane_lock_frames = 12,
}

M.GK_DISTRIBUTION = {
    throw_button = "B",
    long_kick_button = "A",

    -- Saida curta so e tentada para companheiro relativamente proximo
    -- e com folga minima para o adversario mais proximo.
    max_throw_distance = 360,
    min_receiver_clearance = 72,

    -- Se o receptor estiver bem acima/abaixo do GK, usa UP/DOWN.
    -- Caso contrario, orienta para frente com LEFT/RIGHT relativo ao ataque.
    lateral_direction_threshold = 48,

    -- Score simples do receptor curto.
    weight_clearance = 1.00,
    weight_forward = 0.35,
    weight_distance = 0.25,

    -- Se o primeiro pulso nao for aceito pelo jogo, permite retry tardio.
    retry_frames = 30,
}

M.LIVE_DEFENSE = {
    goal_side_offset = 48,

    -- Evita que um defensor atravesse o campo para pressionar o GK rival.
    -- Se ja estiver perto, a pressao normal continua permitida.
    gk_press_distance = 160,
}

-- Interceptacao de bola em movimento.
-- O primeiro baseline projeta alguns frames a frente usando a velocidade
-- observada da bola e limita o deslocamento previsto para evitar overshoot.
M.INTERCEPTION = {
    min_lead_frames = 3,
    max_lead_frames = 12,
    distance_per_lead_frame = 24,
    max_lead_distance = 96,
    min_ball_speed = 1.0,
}

-- Troca automatica do jogador controlado em defesa.
-- Usa um pulso curto de R apenas quando outro jogador de linha esta
-- significativamente mais perto do alvo defensivo/interceptacao.
M.PLAYER_SWITCH = {
    button = "R",
    improvement_margin = 80,
    cooldown_frames = 12,
    exclude_goalkeeper = true,
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

-- Initial experimental throw-in parameters; validate button mapping in BizHawk.
M.THROW_IN = {
    throw_button = "B",
    min_distance = 24,
    max_distance = 280,
    min_clearance = 40,
    clearance_weight = 1.0,
    forward_weight = 0.25,
    distance_weight = 0.35,
    retry_frames = 45,
}

return M
