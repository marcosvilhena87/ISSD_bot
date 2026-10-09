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

-- Observational detection only; candidate height addresses from BizHawk traces.
-- Observational only: do not press X until headers are calibrated.
-- Experimental emergency header; success must be verified in BizHawk.
M.AERIAL_CONTEST_LOCK = {
    min_height=21, max_height=120,
    goal_radius=330,
    approach_distance=85,
    max_frames=28,
}

M.DEFENSIVE_HEADER = {
    goal_radius=330,
    min_height=21,
    max_height=80,
    contact_distance=38,
    forward_contact_distance=24, -- prioritize opposing half only near contact
    cooldown_frames=24,
}

M.AERIAL_DEFENSIVE_CONTACT = {
    min_height=21,
    max_height=80,
    max_distance=100,
    max_rising_delta=0,
    confirm_frames=3,
    cooldown_frames=30,
}

-- Bounded final-third angle correction; never force a shot.
M.FINAL_THIRD_RESET = {
    failed_attempts=2,
    stall_window_frames=360,
    max_frames=280, -- hard safety cap; each reset has a distance-derived deadline
    estimated_units_per_frame=1.7,
    deadline_slack_frames=35,
    min_deadline_frames=105,
    progress_window_frames=35,
    min_window_progress=18,
    pressure_abort_radius=33,
    retreat_distance=210,
    min_retreat_progress=35,
    min_goal_distance=320,
    cooldown_frames=210,
    arrive_distance=28,
    midfield_margin=35,
    rebuild_window_frames=240,
    reposition_block_frames=160,
}

M.FINAL_THIRD_ATTACK_DECISION = {
    window_frames=24,
    advance_step=32,
    max_advance_frames=12,
}

M.FINAL_THIRD_REPOSITION_LOCK = {
    max_frames=42,
    max_retreat=28,
    min_angle_gain=2.0,
    progress_check_frames=16,
    cooldown_frames=65,
    arrive_distance=16,
}

M.AERIAL_CONTACT = {
    height_addr=0x0410,
    height_reference_addr=0x19E8,
    min_height=20,
    min_vertical_speed=2,
    min_horizontal_speed=2,
    near_player_radius=110,
}

M.DEADZONE_X = 8
M.DEADZONE_Y = 8

-- Defesa em jogo corrido:
-- ponto-alvo fica goal_side_offset unidades do lado do nosso gol
-- em relacao ao portador da CPU.
-- Ataque em jogo corrido.
-- Primeiro baseline: conduzir reto na direcao do gol adversario.
M.FIELD_BOUNDARY = {
    margin_x=40, margin_y=40,
    risk_zone=30, inward_step=48,
}

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

M.DEFENSIVE_MIDFIELD_TRANSITION = {
    stable_frames=12,
    max_frames=240,
}

M.DEFENSIVE_PASS_OUTCOME = {
    max_frames=75, -- a commanded pass is not a confirmed reception
}

M.DEFENSIVE_PASS_ALIGNMENT = {
    confirm_frames=2, -- consecutive observations of ball ahead
    min_forward_offset=3, max_ball_offset=45,
    max_lateral_offset=23, dominance_ratio=1.15,
    max_window_frames=12,
    retry_block_frames=45, -- avoid endless start/abort loop
}

M.DEFENSIVE_EXIT = {
    lateral_min=65, lateral_max=190, max_horizontal=30,
    max_pass_distance=210, receiver_clearance=80,
    lane_clearance=60, hold_before_move=45,
    outlet_next_step=60, outlet_forward_space_weight=0.35,
    outlet_touchline_weight=0.2, outlet_progress_weight=0.15,
    max_advance=70, field_margin=40, step=35,
    forward_step=12, min_escape_clearance=60,
    escape_space_cap=180, escape_forward_weight=2.0,
    escape_lateral_penalty=0.15,
    pressure_radius=95, emergency_radius=38,
    reassessment_frames=18, max_reassessments=3,
    reassess_forward_probe=48, reassess_min_forward_progress=35,
    reassess_min_clearance=90, reassess_min_pressure_distance=100,
    total_advance_limit=210, action_settle_frames=20,
    hold_timeout_frames=75,
    guard_stall_log_frames=35,
    guard_outcome_frames=36,
    guard_min_ball_travel=20,
    max_clear_attempts=3,
    clear_buttons={"A","X","A"}, -- alternate when a clearance was not accepted
}

-- Final-third rescue when the carrier reaches the opponent endline.
M.ATTACK_FINAL_THIRD = {
    endline_distance = 145, -- forward distance to opponent goalkeeper (proxy)
    min_lateral_offset = 75,
    retreat_step = 42,
    inward_step = 68,
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

M.POSSESSION_FALLBACK = {
    forward_step=48,
    lateral_step=16,
    min_goal_separation=120,
}

M.SHOOT = {
    button = "X",
    dash_shoot_calibration = true, -- alternate normal and Y+X shots
    max_distance = 310,
    min_forward_distance = 25,
    lane_half_width = 46,
    max_shot_angle = 30, -- degrees; provisional
    cooldown_frames = 90,
}

M.FREE_KICK = {
    pass_button = "B",
    shot_button = "X",
    long_button = "A",
    stable_frames = 18,
    offside_stable_frames = 30, -- allow offside animation to settle
    max_taker_distance = 115,
    team_margin = 16,
    shot_max_distance = 260,
    retry_frames = 75,
    max_attempts = 3,
    ball_move_threshold = 18,
    stationary_tolerance = 2,
    stationary_retry_frames = 60,
    moved_retry_delay = 90,
    switch_interval = 30,
    max_switch_attempts = 3,
}

M.GK_RELEASE_ORIGIN_LOCK = {
    release_grace_frames = 240, -- bridge the brief BOT_IDLE between hold and kick
    max_frames = 180, -- finite origin memory; not a claim of current possession
}

M.CORNER_KICK = {
    cross_button = "A",
    short_button = "B",
    shot_button = "X",
    hold_frames = 4,
    switch_interval = 22,
    max_switches = 5,
    exhausted_recovery_frames = 120,
    stable_frames = 3,
    retry_frames = 28,
    max_attempts = 3,
    ball_move_threshold = 8,
    endline_tolerance = 90,
    sideline_tolerance = 90,
    max_taker_distance = 120,
}

M.GOAL_KICK = {
    buttons = {"X", "X", "A"}, -- kick first; retries only if GS=1 persists
    directions = {"NONE", "FORWARD", "FORWARD"},
    ball_move_threshold = 18,
    initial_delay_frames = 10,
    retry_frames = 90, -- allow game-state transition before retry
    max_attempts = 3,
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
    lateral_lane_half_width = 32, -- B+Up/Down: receiver near vertical throw corridor
    min_lateral_throw = 48,

    -- Se o receptor estiver bem acima/abaixo do GK, usa UP/DOWN.
    -- Caso contrario, orienta para frente com LEFT/RIGHT relativo ao ataque.
    lateral_direction_threshold = 48,

    -- Score simples do receptor curto.
    weight_clearance = 1.00,
    weight_forward = 0.35,
    weight_distance = 0.25,

    -- Se o primeiro pulso nao for aceito pelo jogo, permite retry tardio.
    retry_frames = 40,
    press_frames = 6, -- hold the chosen GK action for multiple emulator frames
    max_attempts = 3, -- bounded alternative inputs if possession persists
}

-- Provisional world-unit thresholds; position of GK approximates goalmouth.
-- Emergency recovery of loose second balls in our penalty area.
-- Provisional world-unit distances; goalkeeper is used as goal anchor.
M.BOX_PRESSURE = {
    activation_radius = 340,
    attacker_goal_radius = 240,
    attacker_ball_radius = 130,
    unmarked_distance = 75,
}

-- Observational only. Player speed and ETA margin require calibration.
-- Conservative tactical gate; uses previous-frame stabilized ETA only.
M.BALL_CONTEST_DECISION_GATE = {
    max_height=20,
    max_my_distance=145,
    max_age_frames=2,
    min_cpu_eta_advantage=6,
    min_stability_frames=4,
    goal_proximity_radius=320,
    log_denied_every=60,
    lock_frames=12, -- keep interception through transient ETA changes
    lock_target_tolerance=65,
    lock_max_defender_eta=30,
    lock_max_eta_deficit=9,
    lock_stop_distance=22,
    abort_cooldown_frames=18,
}

M.BALL_CONTEST_FEASIBILITY = {
    estimated_my_speed=4.0,
    estimated_cpu_speed=4.0,
    contested_eta_margin=6,
    stability_frames=4, -- consecutive observations before scoring a prediction
    max_lead_frames=8,
    max_lead_distance=64,
    max_contestable_height=20,
    max_distance=180,
    outcome_frames=120,
}

M.BALL_PHYSICAL_CONTROL = {
    near_radius=48,
    min_speed=0.7,
    max_motion_error=5,
    error_weight=2,
    min_candidate_margin=8,
    max_dribble_height=8,
    max_ground_height=3,
    confirm_frames=5,
}

M.OWNERSHIP_PROBE = {
    max_contestable_height=20,
    contest_radius=75,
    max_distance_gap=38,
}

-- Conservative positive-ETA recovery for either logical team assignment.
-- Only wired to MY_UNOWNED_BALL; CPU_UNOWNED_BALL retains its existing chase.
-- World-unit thresholds are provisional pending CSV-based calibration.
M.MY_UNOWNED_RECOVERY = {
    max_age_frames=2,
    stability_frames=4,
    max_height=20,
    max_distance=130,
    min_eta_advantage=8,
    max_controlled_distance=180,
    lock_frames=12,
    lock_max_ball_drift=65,
    lock_max_height=20,
    lock_arrive_distance=22,
}

M.MY_FLIGHT_INTERCEPTION = {
    max_height = 20, -- ground / low bounce only until aerial control is calibrated
    max_my_distance = 155,
    min_cpu_advantage = 18, -- CPU must be clearly nearer to the target
    max_flight_age = 150,
    max_prediction_frames = 6,
    max_prediction_distance = 48,
}

-- Conservative inferred rebounds near Brazilian goalkeeper.
M.FIRST_REBOUND_RECOVERY = {
    goal_radius=330,
    max_height=20,
    max_my_distance=125,
    estimated_speed=4.0, -- provisional world units per frame
    min_eta_advantage=5,
    lock_frames=10,
    max_ball_drift=55,
}

M.BOX_SECOND_BALL = {
    window_frames=105,
    goal_radius=340,
    max_outfielder_distance=220,
    min_switch_gain=65,
    switch_min_remaining=24,
    max_switches=1,
}

M.GK_REBOUND_RECOVERY = {
    goal_radius=280,
    recent_cpu_frames=45,
    min_speed=2,
    max_direction_cosine=0.35,
    min_acceleration=7,
    candidate_cooldown_frames=9,
    max_height=80,
    window_frames=32,
    max_outfielder_distance=160,
    switch_margin=25,
    no_switch_last_frames=12,
}

M.BOX_RECOVERY = {
    goal_radius = 300,
    attacker_radius = 110,
    own_ball_protection_radius = 32, -- do not disrupt nearby Brazilian receiver
    max_ball_speed = 5.0,
    pressure_lock_frames = 10,
}

M.BOX_COVERAGE = {
    activation_radius = 340,
    threat_goal_radius = 220,
    threat_ball_radius = 260,
    unmarked_distance = 75,
    carrier_emergency_radius = 120,
}

-- Experimental defensive sprint; verified velocity benefit pending BizHawk test.
M.DEFENSIVE_DASH = {
    button = "Y",
    start_distance = 105,
    recovery_start_distance = 70, -- accelerate on viable loose-ball approaches
    stop_distance = 55,
    burst_frames = 10,
    cooldown_frames = 16,
}

M.ACTIVE_TACKLE = {
    button = "B",
    max_distance = 28, -- conservative close-contact charge
    max_ball_distance = 16, -- prevent premature B when the ball is out of reach
    max_carrier_ball_distance = 30, -- ensure the ball remains near the carrier
    cooldown_frames = 30,
    outcome_frames = 45,
}

M.SHOT_LANE = {
    activation_radius = 340,
    intercept_offset = 48,
    max_fraction = 0.60,
    block_width = 30,
    telemetry_frames = 15,
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
    danger_release_distance = 12, -- meaningful backward reversal
    danger_lateral_tolerance = 48, -- release on clear lateral deflection
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
    unhelpful_settle_frames = 60, -- avoid R thrashing after worse selection
    exclude_goalkeeper = true,
}

-- Contexto temporal de posse quando 0x00A6 volta para zero.
-- Evita tratar imediatamente passe/chute como bola neutra.
M.POSSESSION_CONTEXT = {
    speed_smoothing_alpha = 0.35, -- EMA dampens isolated zero-speed reads
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
    max_positioning_frames = 90, -- avoid indefinite MOVE_RECEIVER
    force_throw_after_frames = 120, -- fallback after rejected initial throw
    max_attempts = 6, -- bounded A/B retries before exposing EXHAUSTED
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
