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
    score_my = 0x0DA2, -- u16 LE; user-supplied WCH candidate
    score_cpu = 0x0EA2, -- u16 LE; user-supplied WCH candidate
    shots_my = 0x0DAA, -- u16 LE; candidate
    shots_cpu = 0x0EAA, -- u16 LE; candidate
    stadium_id = 0x0086,
    field_length = 0x12A2,
    field_width = 0x12A4,
    center_field_x = 0x12F2,
    center_field_y = 0x12D8,
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
    lane_progress_window = 45,
    lane_min_progress = 24,
    lane_abort_frames = 80,
    escape_button = "Y",
    escape_cooldown_frames = 24,
    escape_max_blocker_distance = 72,
    feint_max_blocker_distance = 28,
    dash_duration_frames = 12,
    feint_cooldown_frames = 32,
}

-- First-third defensive possession is handled by the field-third geometry
-- and existing FORWARD_PASS safety thresholds.

M.DEFENSIVE_EXIT = {
    lateral_min=65, lateral_max=190, max_horizontal=30,
    max_pass_distance=210, receiver_clearance=80,
    lane_clearance=60, hold_before_move=45,
    max_advance=70, field_margin=40, step=35,
    forward_step=12, min_escape_clearance=60,
    pressure_radius=95, emergency_radius=38,
}

M.FORWARD_PASS = {
    button = "B",
    min_forward = 75,
    max_forward = 260,
    max_distance = 270,
    max_lateral = 24, -- progressive passes aligned with B+Right/Left
    lateral_min = 65,
    lateral_max = 220,
    lateral_max_forward = 28,
    lateral_max_distance = 230,
    lateral_receiver_clearance = 82,
    lateral_lane_clearance = 62,
    min_receiver_clearance = 72,
    min_lane_clearance = 52,
    cooldown_frames = 75,
    weight_progress = 0.30,
    weight_clearance = 0.50,
    weight_lane = 0.65,
    weight_lateral = 1.0,
}

M.SHOOT = {
    button = "X",
    max_distance = 310,
    min_forward_distance = 25,
    lane_half_width = 46,
    cooldown_frames = 90,
}

M.FREE_KICK = {
    pass_button = "B",
    shot_button = "X",
    long_button = "A",
    stable_frames = 18,
    max_taker_distance = 115,
    team_margin = 16,
    shot_max_distance = 260,
    retry_frames = 75,
    max_attempts = 2,
}

M.CORNER_KICK = {
    cross_button = "A",
    short_button = "B",
    stable_frames = 12,
    retry_frames = 65,
    max_attempts = 2,
    ball_move_threshold = 18,
    endline_tolerance = 90,
    sideline_tolerance = 90,
    max_taker_distance = 120,
}

M.GOAL_KICK = {
    button = "A", -- high kick, to be validated in GS=1
    initial_delay_frames = 10,
    retry_frames = 60,
    max_attempts = 2,
}

M.GK_DISTRIBUTION = {
    throw_button = "B",
    long_kick_button = "A",

    -- Saida curta so e tentada para companheiro relativamente proximo
    -- e com folga minima para o adversario mais proximo.
    max_throw_distance = 360,
    min_receiver_clearance = 72,
    min_lane_clearance = 56, -- experimental: opponents near pass segment
    min_forward = 48, -- require meaningful forward progress
    forward_lane_half_width = 32, -- B+Right/Left: receiver must be aligned with forward path

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

-- Provisional world-unit thresholds; position of GK approximates goalmouth.
M.BOX_COVERAGE = {
    activation_radius = 340,
    threat_goal_radius = 220,
    threat_ball_radius = 260,
    unmarked_distance = 75,
    carrier_emergency_radius = 120,
}

M.ACTIVE_TACKLE = {
    button = "B",
    max_distance = 40,
    cooldown_frames = 30,
    outcome_frames = 45,
}

M.GOAL_SIDE = {
    offset = 65, -- from carrier toward Brazilian GK
    max_fraction = 0.65,
    emergency_radius = 125,
    measure_every_frames = 30,
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
    danger_min_speed = 3.0,
    danger_min_x_speed = 2.0,
    danger_max_goal_distance = 300,
    danger_max_frames = 28,
    danger_min_lead_frames = 3,
    danger_max_lead_frames = 16,
    estimated_defender_speed = 4.0, -- world units/frame, provisional
    feasibility_margin_frames = 2,
    danger_lock_frames = 8,
    danger_release_frames = 5,
}

-- Troca automatica do jogador controlado em defesa.
-- Usa um pulso curto de R apenas quando outro jogador de linha esta
-- significativamente mais perto do alvo defensivo/interceptacao.
M.PLAYER_SWITCH = {
    button = "R",
    improvement_margin = 80,
    cooldown_frames = 12,
    verify_frames = 8,
    settle_frames = 24,
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
    long_throw_button = "A",
    long_fallback_frames = 180,
    min_distance = 24,
    max_distance = 280,
    min_clearance = 40,
    clearance_weight = 1.0,
    forward_weight = 0.25,
    distance_weight = 0.35,
    retry_frames = 45,
    receiver_ready_distance = 80,
    switch_margin = 80,
    switch_cooldown = 45,
    target_lock_frames = 20,
    target_tolerance = 16,
    max_attempts = 2,
    recovery_switch_interval = 30,
    max_recovery_switches = 3,
    field_margin = 40,
    receiver_max_taker_distance = 160,
    receiver_switch_improvement = 32,
    switch_verify_frames = 12,
    long_min_distance = 150,
    long_max_distance = 500,
    long_min_clearance = 55,
    long_ready_frames = 12,
}

return M
