-- ISSD Bot - application orchestrator

local function script_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return source:match("^(.*[\\/])") or "./"
end

local DIR = script_dir()

local config = dofile(DIR .. "../core/config.lua")
local Memory = dofile(DIR .. "../core/memory.lua")
local Players = dofile(DIR .. "../state/players.lua")
local Ball = dofile(DIR .. "../state/ball.lua")
local AerialContact = dofile(DIR .. "../state/aerial_contact.lua")
local BallFlightContext = dofile(DIR .. "../state/ball_flight_context.lua")
local OwnershipProbe = dofile(DIR .. "../state/ownership_probe.lua")
local BallContestFeasibility = dofile(DIR .. "../state/ball_contest_feasibility.lua")
local GameState = dofile(DIR .. "../state/game_state.lua")
local GameplayActive = dofile(DIR .. "../state/gameplay_active.lua")
local FieldSide = dofile(DIR .. "../state/field_side.lua")
local Movement = dofile(DIR .. "../control/movement.lua")
local Geometry = dofile(DIR .. "../core/geometry.lua")
local Defense = dofile(DIR .. "../tactics/defense.lua")
local LiveDefense = dofile(DIR .. "../tactics/live_defense.lua")
local ActiveTackle = dofile(DIR .. "../tactics/active_tackle.lua")
local LiveAttack = dofile(DIR .. "../tactics/live_attack.lua")
local FieldBoundary = dofile(DIR .. "../tactics/field_boundary.lua")
local Shoot = dofile(DIR .. "../tactics/shoot.lua")
local ForwardPass = dofile(DIR .. "../tactics/forward_pass.lua")
local DefensiveExit = dofile(DIR .. "../tactics/defensive_exit.lua")
local GKDistribution = dofile(DIR .. "../tactics/gk_distribution.lua")
local GoalKick = dofile(DIR .. "../tactics/goal_kick.lua")
local CornerKick = dofile(DIR .. "../tactics/corner_kick.lua")
local FreeKick = dofile(DIR .. "../tactics/free_kick.lua")
local Interception = dofile(DIR .. "../tactics/interception.lua")
local DefenseInterception = dofile(DIR .. "../tactics/defense_interception.lua")
local PlayerSwitch = dofile(DIR .. "../control/player_switch.lua")
local TeamPossession = dofile(DIR .. "../state/team_possession.lua")
local PossessionContext = dofile(DIR .. "../state/possession_context.lua")
local Restart = dofile(DIR .. "../tactics/restart.lua")
local ThrowIn = dofile(DIR .. "../tactics/throw_in.lua")
local Overlay = dofile(DIR .. "../ui/overlay.lua")
local Report = dofile(DIR .. "../core/report.lua")
local GoalTrace = dofile(DIR .. "../core/goal_trace.lua")

local mem = Memory.new(config)
local players = Players.new(config, mem)
local ball = Ball.new(config, mem)
local aerial_contact = AerialContact.new(config, mem, players)
local flight_context = BallFlightContext.new(config, mem, players)
local ownership_probe = OwnershipProbe.new(config, mem, players)
local contest_feasibility = BallContestFeasibility.new(config, players)
local game_state = GameState.new(config, mem)
local gameplay_active = GameplayActive.new(config, mem)
local field_side = FieldSide.new(config, mem)
local movement = Movement.new(config)
local defense = Defense.new(config, players, Geometry, field_side)
local live_defense = LiveDefense.new(config, players, field_side)
local active_tackle = ActiveTackle.new(config, players)
local live_attack = LiveAttack.new(config, players, field_side)
local field_boundary = FieldBoundary.new(config, mem)
local shoot = Shoot.new(config, players, field_side)
local forward_pass = ForwardPass.new(config, players, field_side, mem)
local defensive_exit = DefensiveExit.new(config, players, field_side, mem)
local gk_distribution = GKDistribution.new(config, players, field_side)
local goal_kick = GoalKick.new(config, players, field_side)
local corner_kick = CornerKick.new(config, players, field_side, mem)
local free_kick = FreeKick.new(config, players, field_side)
local interception = Interception.new(config)
local defense_interception = DefenseInterception.new(config, players)
local player_switch = PlayerSwitch.new(config, players)
local team_possession = TeamPossession.new(config, mem)
local possession_context = PossessionContext.new(config, players)
local restart = Restart.new(config, players, Geometry, defense)
local throw_in = ThrowIn.new(config, players, field_side, mem)
local overlay = Overlay.new(players, game_state)

local report = Report.new(DIR .. "../issd_report.csv")
local goal_trace = GoalTrace.new(report, 600, 3)
local enabled = false
local stop_on_possession = true
local previous_keys = {}
local escape_cooldown = 0
local dash_frames = 0
local dash_carrier = nil
local gk_pending = nil
local defensive_carrier = nil
local defensive_hold_age = 0
local rebound_lock_base=nil
local rebound_lock_frames=0
local last_flight_discrepancy=false
local flight_interception_pending=nil
local danger_lock=nil
-- Defensive sprint is deliberately separate from attack dash.
local defensive_dash={remaining=0,cooldown=0,base=nil,start_distance=nil,mode=nil,
    start_x=nil,start_y=nil,target_x=nil,target_y=nil}
local function defensive_dash_step(state)
    local cfg=config.DEFENSIVE_DASH
    local eligible={
        LIVE_DEFENSE=true, BOX_ATTACKER_PRESSURE=true,
        BOX_REBOUND_PRESSURE=true, CPU_DANGER_INTERCEPT=true,
        CPU_BALL_INTERCEPT=true, CPU_BALL_INTERCEPT_FALLBACK=true,
        MY_FLIGHT_BOX_DANGER=true, LIVE_FALLBACK_CHASE=true,
    }
    local active=state.game_state==0
        and gameplay_active.is_active(state.gameplay_active)
        and eligible[state.status]
        and players.valid_my_base(state.my_base)
        and state.my_base~=config.MY_FIRST
        and type(state.dx)=="number" and type(state.dy)=="number"
    local d=active and math.sqrt(state.dx^2+state.dy^2) or nil
    local command=movement.last_command or ""
    local directional=command:find("Left",1,true) or command:find("Right",1,true)
        or command:find("Up",1,true) or command:find("Down",1,true)
    if defensive_dash.cooldown>0 then
        defensive_dash.cooldown=defensive_dash.cooldown-1
    end
    if defensive_dash.remaining>0 then
        local ending=not active or not directional
            or defensive_dash.base~=state.my_base or d<=cfg.stop_distance
            or defensive_dash.remaining<=1
        if ending then
            local px,py=nil,nil
            if players.valid_my_base(defensive_dash.base) then
                px,py=players.xy(defensive_dash.base)
            end
            local displacement=px and math.sqrt(
                (px-defensive_dash.start_x)^2+(py-defensive_dash.start_y)^2) or nil
            local fixed_end=px and math.sqrt(
                (px-defensive_dash.target_x)^2+(py-defensive_dash.target_y)^2) or nil
            report:write("DEFENSIVE_DASH_END",true,state,"Y",
                "mode="..tostring(defensive_dash.mode)
                ..";player_displacement="..tostring(displacement)
                ..";fixed_target_end_distance="..tostring(fixed_end)
                ..";fixed_target_gain="..tostring(fixed_end
                    and defensive_dash.start_distance-fixed_end or nil)
                ..";start_distance="..tostring(defensive_dash.start_distance)
                ..";end_distance="..tostring(d)
                ..";gain="..tostring(d and defensive_dash.start_distance
                    and (defensive_dash.start_distance-d) or nil))
            defensive_dash.remaining=0
            defensive_dash.cooldown=cfg.cooldown_frames
        else
            defensive_dash.remaining=defensive_dash.remaining-1
        end
    end
    if active and directional and d>=cfg.start_distance
        and (defensive_dash.remaining>0 or defensive_dash.cooldown==0) then
        if defensive_dash.remaining==0 then
            defensive_dash.remaining=cfg.burst_frames
            defensive_dash.base=state.my_base
            defensive_dash.start_distance=d
            defensive_dash.mode=state.status
            defensive_dash.start_x,defensive_dash.start_y=players.xy(state.my_base)
            defensive_dash.target_x=defensive_dash.start_x+state.dx
            defensive_dash.target_y=defensive_dash.start_y+state.dy
            report:write("DEFENSIVE_DASH_START",true,state,"Y",
                "mode="..tostring(state.status)..";distance="..tostring(d)
                ..";burst_frames="..tostring(cfg.burst_frames))
        end
        -- Preserve B tackle and R switch commands: only override movement.
        movement.move_toward_button(state.dx,state.dy,cfg.button)
        defensive_dash.remaining=defensive_dash.remaining-1
        state.defensive_dash=true
    end
end


local function pressed(keys, key)
    return keys[key] and not previous_keys[key]
end

local function read_my_base()
    return mem.u16(config.ADDR.my_ctrl)
end

local function make_state(my_base, dx, dy, status, possession, gs)
    return {
        my_base = my_base,
        gameplay_active = gameplay_active.read(),
        gameplay_active_kind = gameplay_active.kind(gameplay_active.read()),
        dx = dx,
        dy = dy,
        status = status,
        possession = possession,
        game_state = gs,
        restart_taker = restart.taker,
        mark_target = restart.mark_target,
        mark_score = restart.mark_score,
        mark_dist_to_me = restart.mark_dist_to_me,
        mark_dist_to_ball = restart.mark_dist_to_ball,
        mark_goal_cost = restart.mark_goal_cost,
        mark_norm_me = restart.mark_norm_me,
        mark_norm_ball = restart.mark_norm_ball,
        mark_norm_goal = restart.mark_norm_goal,
        my_side = restart.my_side,
        ranking = restart.ranking,
        lock_frames = restart.lock_frames,
        switch_delta = restart.switch_delta,
        switch_blocked = restart.switch_blocked,
        last_switch_from = restart.last_switch_from,
        last_switch_to = restart.last_switch_to,
        last_switch_delta = restart.last_switch_delta,
        last_switch_age = restart.last_switch_age,
        live_carrier = nil,
        live_target_x = nil,
        live_target_y = nil,
        live_my_side = nil,
        attack_target_x = nil,
        attack_target_y = nil,
        attack_direction = nil,
        attack_my_side = nil,
        attack_advance_distance = nil,
        attack_mode = nil,
        attack_lane_direction = nil,
        attack_lane_lock_frames = 0,
        attack_blocker_base = nil,
        attack_blocker_forward = nil,
        attack_blocker_lateral = nil,
        attack_up_clearance = nil,
        attack_down_clearance = nil,
        gk_dist_mode = nil,
        gk_dist_direction = nil,
        gk_dist_button = nil,
        gk_dist_receiver = nil,
        gk_dist_receiver_distance = nil,
        gk_dist_receiver_clearance = nil,
        gk_dist_receiver_forward = nil,
        gk_dist_receiver_score = nil,
        gk_dist_wait_frames = 0,
        gk_distance = nil,
        gk_press_threshold = nil,
        gk_should_press = nil,
        team_possession = nil,
        team_possession_kind = nil,
        team_possession_source = nil,
        possession_class = nil,
        context_last_team = nil,
        context_last_owner = nil,
        context_frames_without = 0,
        ball_dx = 0,
        ball_dy = 0,
        ball_speed = 0,
        intercept_target_x = nil,
        intercept_target_y = nil,
        intercept_lead_frames = 0,
        intercept_lead_x = 0,
        intercept_lead_y = 0,
        intercept_predictive = false,
        intercept_player_ball_distance = nil,
        intercept_clipped = false,
        switch_best_base = nil,
        switch_current_distance = nil,
        switch_best_distance = nil,
        switch_improvement = nil,
        switch_cooldown = 0,
        switch_button = nil,
    }
end

local function step_bot()
    player_switch.tick()
    active_tackle.tick()
    gk_distribution.tick()
    shoot.tick()
    forward_pass.tick()
    defense_interception.tick()
    if escape_cooldown > 0 then escape_cooldown = escape_cooldown - 1 end

    local gameplay_value = gameplay_active.read()
    local my_base = read_my_base()
    player_switch.observe_control(my_base)
    local switch_event = player_switch.take_event()
    if switch_event then
        report:write(switch_event.kind, true,
            {my_base=my_base,game_state=game_state.read(),
             gameplay_active=gameplay_active.read(),
             controller_command="OBSERVE_MYCTRL"},
            "MYCTRL",
            "from="..tostring(switch_event.from)
            ..";expected="..tostring(switch_event.expected)
            ..";actual="..tostring(switch_event.actual)
            ..";age="..tostring(switch_event.age)
            ..";previous_distance="..tostring(switch_event.previous_distance)
            ..";actual_distance="..tostring(switch_event.actual_distance)
            ..";actual_gain="..tostring(switch_event.actual_gain))
    end
    local possession = ball.possession()
    local gs = game_state.read()

    if not gameplay_active.is_active(gameplay_value) then
        restart.clear()
        throw_in.reset()
        possession_context.reset()
        player_switch.reset()
        live_attack.reset()
        gk_distribution.reset()
        movement.stop()

        local state = make_state(
            my_base, 0, 0, "BOT_IDLE", possession, gs
        )
        state.gameplay_active = gameplay_value
        state.gameplay_active_kind = gameplay_active.kind(gameplay_value)
        return state
    end

    -- Both fouls (GS=3) and offside (GS=4) can produce a free kick.
    -- The planner validates Brazilian ownership before sending a kick.
    if gs == 3 or gs == 4 then
        corner_kick.reset()
        goal_kick.reset()
        throw_in.reset()
        restart.clear()
        possession_context.reset()
        local bx,by=ball.world_xy()
        local plan=free_kick.plan(bx,by,my_base,gs)
        -- Only advertise a confirmed Brazilian restart; never infer ownership
        -- from the nearest Brazilian when a CPU taker is closer.
        restart.taker=plan and plan.our_restart and plan.taker or nil
        restart.taker_team=plan and plan.our_restart and "MY" or nil
        local fired=free_kick.fire(plan,movement)
        local switching=plan and plan.mode=="SWITCH_TAKER"
        if fired and not switching then free_kick.remember_ball(bx,by)
        elseif not fired then movement.stop() end
        local prefix=gs==4 and "OFFSIDE_FREE_KICK_" or "FREE_KICK_"
        local state=make_state(my_base,nil,nil,
            fired and (switching and prefix.."SWITCH_TAKER" or prefix.."ATTEMPT")
            or (prefix..(plan and plan.mode or "WAIT")),possession,gs)
        state.free_kick_fired=fired and not switching
        state.free_kick_switch_fired=fired and switching
        state.free_kick_mode=plan and plan.mode
        state.free_kick_button=plan and plan.button
        state.free_kick_direction=plan and plan.direction
        state.free_kick_taker=plan and plan.taker
        state.free_kick_my_distance=plan and plan.my_distance
        state.free_kick_cpu_distance=plan and plan.cpu_distance
        state.free_kick_stable=plan and plan.stable
        state.free_kick_attempts=plan and plan.attempts
        state.free_kick_cooldown=plan and plan.cooldown
        state.free_kick_displacement=plan and plan.displacement
        return state
    end
    free_kick.reset()
    if game_state.is_stoppage(gs) then
        corner_kick.reset()
        goal_kick.reset()
        restart.clear()
        throw_in.reset()
        possession_context.reset()
        player_switch.reset()
        live_attack.reset()
        gk_distribution.reset()
        movement.stop()

        local state = make_state(
            my_base, 0, 0, game_state.kind(gs), possession, gs
        )
        state.gameplay_active = gameplay_value
        state.gameplay_active_kind = gameplay_active.kind(gameplay_value)
        return state
    end

    if not players.valid_my_base(my_base) then
        restart.clear()
        possession_context.reset()
        player_switch.reset()
        live_attack.reset()
        gk_distribution.reset()
        movement.stop()

        local state = make_state(
            my_base, nil, nil, "BOT_IDLE_NO_PLAYER", possession, gs
        )
        state.gameplay_active = gameplay_value
        state.gameplay_active_kind = gameplay_active.kind(gameplay_value)
        return state
    end

    local bx, by = ball.world_xy()

    -- First third is determined from actual field geometry and attack orientation.
    local function in_defensive_third(base)
        local len=mem.u16(config.ADDR.field_length)
        local center=mem.u16(config.ADDR.center_field_x)
        local dir=field_side.attack_direction()
        if len<500 or len>4000 or center<100 or dir==0 then return false end
        local x=players.xy(base)
        local start=center-dir*len/2
        local progress=(x-start)*dir
        return progress>=0 and progress<=len/3
    end

    if game_state.is_live(gs) then
        if possession~=my_base then defensive_exit.reset(); defensive_carrier=nil end
        corner_kick.reset()
        goal_kick.reset()
        throw_in.reset()
        restart.clear()

        -- Mantem a heuristica temporal aquecida apenas como fallback.
        local fallback_class =
            possession_context.update(possession, bx, by)

        local team_value = team_possession.read()
        local team_kind = team_possession.kind(team_value)

        local function attach_live_state(state, source, class)
            state.team_possession = team_value
            state.team_possession_kind = team_kind
            state.team_possession_source = source
            state.possession_class = class or fallback_class
            state.context_last_team = possession_context.last_team
            state.context_last_owner = possession_context.last_owner
            state.context_frames_without =
                possession_context.frames_without_possession
            state.ball_dx = possession_context.ball_dx
            state.ball_dy = possession_context.ball_dy
            state.ball_speed = possession_context.ball_speed
            return state
        end


        local function maybe_switch_player(target_x, target_y, class)
            local decision =
                player_switch.consider(my_base, target_x, target_y)

            if not decision.should_switch then
                return nil
            end

            movement.press_button(decision.button)
            report:write("SWITCH_REQUEST", true,
                {my_base=my_base,game_state=gs,
                 controller_command=movement.last_command},
                decision.button,
                "from="..tostring(my_base)
                ..";expected="..tostring(decision.best_base)
                ..";target_x="..tostring(target_x)
                ..";target_y="..tostring(target_y)
                ..";improvement="..tostring(decision.improvement))

            local state = make_state(
                my_base, 0, 0, "PLAYER_SWITCH", possession, gs
            )
            state.switch_best_base = decision.best_base
            state.switch_current_distance = decision.current_distance
            state.switch_best_distance = decision.best_distance
            state.switch_improvement = decision.improvement
            state.switch_cooldown = decision.cooldown
            state.switch_button = decision.button

            return attach_live_state(
                state,
                "PLAYER_SWITCH",
                class
            )
        end

        -- 0x00A6 continua sendo a fonte autoritativa para o jogador
        -- fisicamente ligado a bola.
        if players.valid_my_base(possession) then
            defense_interception.reset()
            -- So automatiza a progressao se o jogador controlado
            -- for exatamente o possuidor. Evita mover um companheiro
            -- sem bola quando a posse esta em outra struct MY.
            if possession == my_base and my_base ~= config.MY_FIRST then
                if in_defensive_third(my_base) then
                    if defensive_carrier~=my_base then
                        defensive_carrier=my_base
                        defensive_hold_age=0
                    end
                    defensive_hold_age=defensive_hold_age+1
                    -- No forward dribble or Y dash while holding the defensive line.
                    local outlet=forward_pass.plan(my_base)
                    if outlet and forward_pass.fire(outlet,movement) then
                        defensive_exit.on_pass()
                        local state=make_state(my_base,0,0,
                            "DEFENSIVE_OUTLET_PASS",possession,gs)
                        state.defensive_recovery=true
                        state.defensive_hold_age=defensive_hold_age
                        state.defensive_outlet_fired=true
                        state.forward_pass_fired=true
                        state.forward_pass_zone=outlet.zone
                        state.forward_pass_intent=outlet.intent
                        state.forward_pass_receiver=outlet.receiver
                        state.forward_pass_distance=outlet.distance
                        state.forward_pass_forward=outlet.forward
                        state.forward_pass_lateral=outlet.lateral
                        state.forward_pass_clearance=outlet.receiver_clearance
                        state.forward_pass_lane_clearance=outlet.lane_clearance
                        state.forward_pass_score=outlet.score
                        state.forward_pass_button=outlet.button
                        state.forward_pass_direction=outlet.direction
                        return attach_live_state(state,"DEFENSIVE_TRANSITION","MY_CONTROLLED")
                    end
                    local exit=defensive_exit.plan(my_base,forward_pass.cooldown)
                    if exit.mode=="PASS" and forward_pass.fire(exit,movement) then
                        defensive_exit.on_pass()
                        local state=make_state(my_base,0,0,
                            "DEFENSIVE_LATERAL_PASS",possession,gs)
                        state.defensive_recovery=true
                        state.defensive_outlet_fired=true
                        state.defensive_hold_age=defensive_hold_age
                        state.forward_pass_fired=true
                        state.forward_pass_zone=1
                        state.forward_pass_intent="DEFENSIVE_LATERAL"
                        state.forward_pass_receiver=exit.receiver
                        state.forward_pass_distance=exit.distance
                        state.forward_pass_forward=0
                        state.forward_pass_lateral=exit.distance
                        state.forward_pass_clearance=exit.receiver_clearance
                        state.forward_pass_lane_clearance=exit.lane_clearance
                        state.forward_pass_score=exit.score
                        state.forward_pass_button=exit.button
                        state.forward_pass_direction=exit.direction
                        return attach_live_state(state,"DEFENSIVE_TRANSITION","MY_CONTROLLED")
                    end
                    if exit.mode=="REASSESS" then
                        movement.stop()
                        local state=make_state(my_base,0,0,
                            "DEFENSIVE_HOLD_REASSESSMENT",possession,gs)
                        state.defensive_recovery=true
                        state.defensive_hold_age=defensive_hold_age
                        state.defensive_pressure_distance=exit.threat
                        state.defensive_reassessments=exit.reassessments
                        state.defensive_total_distance=exit.total
                        return attach_live_state(state,"DEFENSIVE_TRANSITION","MY_CONTROLLED")
                    end
                    if exit.mode=="EXHAUSTED" then
                        movement.stop()
                        local state=make_state(my_base,0,0,
                            "DEFENSIVE_EXIT_EXHAUSTED",possession,gs)
                        state.defensive_recovery=true
                        state.defensive_hold_age=defensive_hold_age
                        state.defensive_exit_reason=exit.reason
                        state.defensive_pressure_distance=exit.threat
                        state.defensive_clear_attempts=exit.clear_attempts
                        return attach_live_state(state,"DEFENSIVE_TRANSITION","MY_CONTROLLED")
                    end
                    if exit.mode=="CLEAR" then
                        movement.press_direction_button(exit.direction,exit.button)
                        local state=make_state(my_base,0,0,
                            "DEFENSIVE_PRESSURE_CLEAR",possession,gs)
                        state.defensive_recovery=true
                        state.defensive_hold_age=defensive_hold_age
                        state.defensive_pressure_distance=exit.threat
                        state.defensive_exit_reason=exit.reason
                        state.defensive_clear_attempts=exit.clear_attempts
                        state.defensive_clear_fired=true
                        state.defensive_clear_button=exit.button
                        state.defensive_clear_direction=exit.direction
                        return attach_live_state(state,"DEFENSIVE_TRANSITION","MY_CONTROLLED")
                    end
                    local exit_guard=nil
                    if exit.mode=="MOVE" then
                        local mx,my=players.xy(my_base)
                        exit_guard=field_boundary.correct(mx,my,
                            mx+exit.dx,my+exit.dy)
                        movement.move_toward(exit_guard.x-mx,exit_guard.y-my)
                    else
                        movement.stop()
                    end
                    local status=exit.mode=="MOVE" and "DEFENSIVE_SHORT_ESCAPE" or "DEFENSIVE_HOLD"
                    local state=make_state(my_base,exit.dx or 0,exit.dy or 0,
                        status,possession,gs)
                    state.defensive_recovery=true
                    state.defensive_hold_age=defensive_hold_age
                    state.defensive_exit_reason=exit.reason
                    state.defensive_pressure_distance=exit.threat
                    state.boundary_risk=exit_guard and exit_guard.risk
                    state.boundary_changed=exit_guard and exit_guard.changed
                    state.boundary_original_x=exit_guard and exit_guard.original_x
                    state.boundary_original_y=exit_guard and exit_guard.original_y
                    return attach_live_state(state,"DEFENSIVE_TRANSITION","MY_CONTROLLED")
                end
                defensive_carrier=nil; defensive_hold_age=0
                defensive_exit.reset()
                local shot = shoot.plan(my_base)
                local shoot_diag = shoot.last_diagnostic
                if shot and shoot.fire(shot, movement) then
                    local state = make_state(
                        my_base, 0, 0, "ATTACK_SHOOT", possession, gs
                    )
                    state.shot_reason = shoot_diag and shoot_diag.reason
                    state.shot_fired = true
                    state.shot_button = shot.button
                    state.shot_distance = shot.distance
                    state.shot_angle = shot.shot_angle
                    state.shot_lateral_offset = shot.lateral_offset
                    state.shot_nearest_defender = shot.nearest_defender
                    state.shot_goal_x = shot.goal_x
                    state.shot_goal_y = shot.goal_y
                    state.controller_command = movement.last_command
                    return attach_live_state(
                        state, "PLAYER_POSSESSION", "MY_CONTROLLED"
                    )
                end
                local poor_angle=shoot_diag and
                    shoot_diag.reason=="BAD_SHOT_ANGLE"
                local pass=forward_pass.plan(my_base,poor_angle)
                if pass and forward_pass.fire(pass,movement) then
                    local state=make_state(my_base,0,0,"ATTACK_FORWARD_PASS",possession,gs)
                    state.forward_pass_fired=true
                    state.centralizing_pass=poor_angle and true or false
                    state.forward_pass_zone=pass.zone
                    state.forward_pass_intent=pass.intent
                    state.forward_pass_receiver=pass.receiver
                    state.forward_pass_distance=pass.distance
                    state.forward_pass_forward=pass.forward
                    state.forward_pass_lateral=pass.lateral
                    state.forward_pass_clearance=pass.receiver_clearance
                    state.forward_pass_lane_clearance=pass.lane_clearance
                    state.forward_pass_score=pass.score
                    state.forward_pass_button=pass.button
                    state.forward_pass_direction=pass.direction
                    return attach_live_state(state,"PLAYER_POSSESSION","MY_CONTROLLED")
                end
                -- If an angle is unsuitable and no safe central outlet exists,
                -- retain regular guarded movement rather than forcing a shot.
                local attack = live_attack.target_for_carrier(my_base, shoot_diag)
                local lane_progress_event = live_attack.take_progress_event()

                if attack ~= nil then
                    local px, py = players.xy(my_base)
                    local guarded=field_boundary.correct(px,py,attack.target_x,attack.target_y)
                    local dx=guarded.x-px
                    local dy=guarded.y-py
                    local boundary_correction=guarded.changed
                    local boundary_risk=guarded.risk

                    local lane_action = nil
                    local escape_fired = false
                    if attack.mode ~= "LANE" or dash_carrier ~= my_base then
                        dash_frames = 0
                        dash_carrier = my_base
                    end
                    if not boundary_risk and not boundary_correction
                        and attack.mode == "LANE" and attack.blocker_base ~= nil then
                        if dash_frames > 0 then
                            movement.move_toward_button(dx, dy, config.ATTACK.escape_button)
                            dash_frames = dash_frames - 1
                            lane_action = "DASH"
                        elseif escape_cooldown == 0 then
                            if attack.blocker_forward ~= nil
                                and attack.blocker_forward <= config.ATTACK.feint_max_blocker_distance then
                                -- One-frame Y tap for feint; release on following frame.
                                movement.move_toward_button(dx, dy, config.ATTACK.escape_button)
                                escape_cooldown = config.ATTACK.feint_cooldown_frames
                                lane_action = "FEINT"
                                escape_fired = true
                            else
                                movement.move_toward_button(dx, dy, config.ATTACK.escape_button)
                                dash_frames = config.ATTACK.dash_duration_frames - 1
                                escape_cooldown = config.ATTACK.escape_cooldown_frames
                                lane_action = "DASH"
                                escape_fired = true
                            end
                        else
                            movement.move_toward(dx, dy)
                        end
                    else
                        movement.move_toward(dx, dy)
                    end

                    local status =
                        attack.mode == "FINAL_THIRD_REPOSITION"
                        and "ATTACK_FINAL_THIRD_REPOSITION"
                        or (attack.mode == "LANE" and "ATTACK_LANE" or "ATTACK_ADVANCE")

                    local state = make_state(
                        my_base, dx, dy, status, possession, gs
                    )
                    state.shot_reason = shoot_diag and shoot_diag.reason
                    state.shot_distance = shoot_diag and shoot_diag.distance
                    state.shot_forward = shoot_diag and shoot_diag.forward
                    state.shot_blocker = shoot_diag and shoot_diag.blocker
                    state.shot_cooldown = shoot_diag and shoot_diag.cooldown
                    state.lane_progress_event = lane_progress_event
                    state.lane_abort_remaining = attack.abort_remaining
                    state.lane_action = lane_action
                    state.escape_fired = escape_fired
                    state.escape_blocker = attack.blocker_base
                    state.attack_goal_x = attack.goal_target_x
                    state.attack_goal_y = attack.goal_target_y
                    state.attack_goal_distance = attack.goal_distance
                    state.attack_target_x = guarded.x
                    state.attack_target_y = guarded.y
                    state.boundary_risk=boundary_risk
                    state.boundary_changed=boundary_correction
                    state.boundary_original_x=guarded.original_x
                    state.boundary_original_y=guarded.original_y
                    state.attack_direction = attack.direction
                    state.attack_my_side = attack.my_side
                    state.attack_advance_distance =
                        attack.advance_distance
                    state.attack_mode = attack.mode
                    state.attack_goal_forward = attack.goal_forward
                    state.attack_lateral_offset = attack.lateral_offset
                    state.attack_lane_direction =
                        attack.lane_direction
                    state.attack_lane_lock_frames =
                        attack.lane_lock_frames or 0
                    state.attack_blocker_base =
                        attack.blocker_base
                    state.attack_blocker_forward =
                        attack.blocker_forward
                    state.attack_blocker_lateral =
                        attack.blocker_lateral
                    state.attack_up_clearance =
                        attack.up_clearance
                    state.attack_down_clearance =
                        attack.down_clearance

                    return attach_live_state(
                        state,
                        "PLAYER_POSSESSION",
                        "MY_CONTROLLED"
                    )
                end
            end

            live_attack.reset()

            if possession == my_base and my_base == config.MY_FIRST then
                local plan = gk_distribution.plan(my_base)

                if plan ~= nil then
                    if gk_distribution.should_fire() then
                        movement.press_direction_button(
                            plan.direction,
                            plan.button
                        )
                        gk_distribution.mark_fired(plan)

                    else
                        movement.stop()
                    end

                    local state = make_state(
                        my_base, 0, 0, "GK_DISTRIBUTE", possession, gs
                    )
                    state.gk_dist_fired = gk_distribution.wait_frames == config.GK_DISTRIBUTION.retry_frames
                    state.gk_dist_lane_clearance = plan.lane_clearance
                    state.gk_dist_decision_reason = plan.decision_reason
                    state.gk_dist_mode = plan.mode
                    state.gk_dist_direction = plan.direction
                    state.gk_dist_button = plan.button
                    state.gk_dist_receiver = plan.receiver
                    state.gk_dist_receiver_distance =
                        plan.receiver_distance
                    state.gk_dist_receiver_clearance =
                        plan.receiver_clearance
                    state.gk_dist_receiver_forward =
                        plan.receiver_forward
                    state.gk_dist_receiver_score =
                        plan.receiver_score
                    state.gk_dist_wait_frames =
                        gk_distribution.wait_frames

                    return attach_live_state(
                        state,
                        "PLAYER_POSSESSION",
                        "MY_CONTROLLED"
                    )
                end
            end

            gk_distribution.reset()
            movement.stop()

            local status = "POSSESSION_MANUAL"
            if possession ~= my_base then
                status = "MY_TEAMMATE_POSSESSION"
            end

            return attach_live_state(
                make_state(
                    my_base, 0, 0, status, possession, gs
                ),
                "PLAYER_POSSESSION",
                "MY_CONTROLLED"
            )
        end

        if players.valid_cpu_base(possession) then
            defense_interception.reset()
            live_attack.reset()
            gk_distribution.reset()
            local gk_policy =
                live_defense.goalkeeper_policy(my_base, possession)

            if gk_policy ~= nil and not gk_policy.should_press then
                movement.stop()

                local state = make_state(
                    my_base, 0, 0, "CPU_GK_HOLD", possession, gs
                )
                state.live_carrier = possession
                state.gk_distance = gk_policy.distance
                state.gk_press_threshold = gk_policy.threshold
                state.gk_should_press = false

                return attach_live_state(
                    state,
                    "PLAYER_POSSESSION",
                    "CPU_CONTROLLED"
                )
            end

            -- First priority: prevent an unmarked attacker from receiving and shooting.
            local urgent=live_defense.box_pressure(possession,bx,by,false)
            if urgent then
                local switch_state=maybe_switch_player(urgent.x,urgent.y,"BOX_ATTACKER_PRESSURE")
                if switch_state then return switch_state end
                local px,py=players.xy(my_base)
                local dx,dy=urgent.x-px,urgent.y-py
                movement.move_toward(dx,dy)
                local state=make_state(my_base,dx,dy,"BOX_ATTACKER_PRESSURE",possession,gs)
                state.box_threat=urgent.base
                state.box_threat_nearest_defender=urgent.nearest_defender
                state.box_threat_ball_distance=urgent.attacker_ball_distance
                return attach_live_state(state,"BOX_PRESSURE","CPU_CONTROLLED")
            end

            local tackle=active_tackle.plan(my_base,possession,bx,by)
            if tackle and active_tackle.fire(tackle,movement) then
                local state=make_state(my_base,0,0,"DEFENSE_ACTIVE_TACKLE",possession,gs)
                state.tackle_fired=true
                state.tackle_carrier=tackle.carrier
                state.tackle_defender=tackle.defender
                state.tackle_distance=tackle.distance
                state.tackle_defender_ball_distance=tackle.defender_ball_distance
                state.tackle_carrier_ball_distance=tackle.carrier_ball_distance
                return attach_live_state(state,"ACTIVE_TACKLE","CPU_CONTROLLED")
            end

            local lane=live_defense.shot_lane(possession,my_base)
            if lane then
                local switch_state=maybe_switch_player(
                    lane.target_x,lane.target_y,"SHOT_LANE_BLOCK")
                if switch_state then
                    switch_state.shot_lane_exposed=lane.exposed
                    return switch_state
                end
                local px,py=players.xy(my_base)
                local dx,dy=lane.target_x-px,lane.target_y-py
                movement.move_toward(dx,dy)
                local state=make_state(my_base,dx,dy,
                    "DEFENSE_SHOT_LANE_BLOCK",possession,gs)
                state.shot_lane_lateral=lane.lateral
                state.shot_lane_along=lane.along
                state.shot_lane_exposed=lane.exposed
                state.shot_lane_distance=lane.distance
                state.live_target_x=lane.target_x
                state.live_target_y=lane.target_y
                state.live_carrier=possession
                return attach_live_state(state,"SHOT_LANE_BLOCK","CPU_CONTROLLED")
            end

            -- Prefer closing down an unmarked secondary attacker in the box.
            -- The selected human-controlled defender is the only movable unit.
            local box = live_defense.box_threat(possession, bx, by)
            if box then
                local switch_state = maybe_switch_player(box.x, box.y, "BOX_COVERAGE")
                if switch_state then
                    switch_state.box_threat=box.base
                    return switch_state
                end
                local px,py=players.xy(my_base)
                local dx,dy=box.x-px,box.y-py
                movement.move_toward(dx,dy)
                local state=make_state(my_base,dx,dy,"DEFENSE_BOX_COVERAGE",possession,gs)
                state.box_threat=box.base
                state.box_threat_goal_distance=box.goal_distance
                state.box_threat_ball_distance=box.ball_distance
                state.box_threat_nearest_defender=box.nearest_defender
                state.live_target_x=box.x
                state.live_target_y=box.y
                state.live_carrier=possession
                return attach_live_state(state,"BOX_COVERAGE","CPU_CONTROLLED")
            end

            local live = live_defense.target_for_carrier(possession)

            if live ~= nil then
                local switch_state = maybe_switch_player(
                    live.target_x,
                    live.target_y,
                    "CPU_CONTROLLED"
                )
                if switch_state ~= nil then
                    return switch_state
                end

                local px, py = players.xy(my_base)
                local dx = live.target_x - px
                local dy = live.target_y - py

                movement.move_toward(dx, dy)

                local state = make_state(
                    my_base, dx, dy, "LIVE_DEFENSE", possession, gs
                )
                state.live_carrier = live.carrier
                state.live_target_x = live.target_x
                state.live_target_y = live.target_y
                state.live_my_side = live.my_side
                state.goal_side_distance = live.goal_distance
                state.goal_side_emergency = live.goal_side_emergency
                -- Projection of the actual defender onto the carrier-to-GK segment.
                local cx,cy=live.carrier_x,live.carrier_y
                local gx,gy=live.goalkeeper_x,live.goalkeeper_y
                local vx,vy=gx-cx,gy-cy
                local length2=vx*vx+vy*vy
                if length2>1 then
                    local t=((px-cx)*vx+(py-cy)*vy)/length2
                    local lateral=math.abs((px-cx)*vy-(py-cy)*vx)/math.sqrt(length2)
                    state.goal_side_between=t>0 and t<1
                        and lateral<=config.GOAL_SIDE.offset
                    state.goal_side_lateral=lateral
                    state.goal_side_projection=t
                end

                if gk_policy ~= nil then
                    state.gk_distance = gk_policy.distance
                    state.gk_press_threshold = gk_policy.threshold
                    state.gk_should_press = true
                end

                return attach_live_state(
                    state,
                    "PLAYER_POSSESSION",
                    "CPU_CONTROLLED"
                )
            end
        end

        -- Quando nenhum jogador esta fisicamente ligado a bola,
        -- 0x104C passa a ser a fonte primaria para o lado da posse.
        if possession == 0 and team_possession.is_cpu(team_value) then
            live_attack.reset()
            gk_distribution.reset()
            -- Contest an attacker who can collect a rebound before aiming at
            -- the ball itself. Keep the standard interception as fallback.
            local rebound=live_defense.box_pressure(nil,bx,by,true)
            local gkx,gky=players.xy(config.MY_FIRST)
            local danger=interception.danger_target(bx,by,
                possession_context.ball_dx,possession_context.ball_dy,
                possession_context.ball_speed,gkx,gky,field_side.goal_direction())
            -- Keep danger classification through isolated zero-velocity samples.
            -- The locked point remains fixed unless the ball genuinely changes course.
            if danger then
                danger_lock={target=danger,frames=config.INTERCEPTION.danger_lock_frames,
                    bx=bx,by=by}
            elseif danger_lock then
                local lock=danger_lock
                local goal_dir=field_side.goal_direction()
                local progressed=(bx-lock.bx)*goal_dir
                local changed_course=progressed< -config.INTERCEPTION.danger_release_distance
                    or math.abs(by-lock.by)>config.INTERCEPTION.danger_lateral_tolerance
                if changed_course or (bx-gkx)*goal_dir>=0 then
                    danger_lock=nil
                else
                    lock.frames=lock.frames-1
                    if lock.frames<=0 then danger_lock=nil
                    else
                        lock.bx=bx;lock.by=by
                        danger=lock.target
                    end
                end
            end
            -- A genuine fast shot toward goal outranks chasing a rebound.
            -- Zero-speed samples alone must not trigger a tactical reversal.
            if rebound_lock_frames>0 then
                rebound_lock_frames=rebound_lock_frames-1
            end
            if danger then
                rebound_lock_base=nil;rebound_lock_frames=0
            elseif rebound_lock_base and rebound_lock_frames>0
                and players.valid_cpu_base(rebound_lock_base) then
                local ax,ay=players.xy(rebound_lock_base)
                local gx,gy=players.xy(config.MY_FIRST)
                if (ax-gx)^2+(ay-gy)^2<=config.BOX_PRESSURE.attacker_goal_radius^2
                    and (ax-bx)^2+(ay-by)^2<=config.BOX_PRESSURE.attacker_ball_radius^2 then
                    local nearest=math.huge
                    players.each_my(function(base)
                        if base~=config.MY_FIRST then
                            local mx,my=players.xy(base)
                            nearest=math.min(nearest,math.sqrt((mx-ax)^2+(my-ay)^2))
                        end
                    end)
                    rebound={base=rebound_lock_base,x=ax,y=ay,
                        nearest_defender=nearest,
                        attacker_ball_distance=math.sqrt((ax-bx)^2+(ay-by)^2)}
                else
                    rebound_lock_base=nil;rebound_lock_frames=0
                end
            end
            if rebound and not danger and
                (rebound_lock_frames>0 or
                possession_context.smoothed_ball_speed<=config.BOX_RECOVERY.max_ball_speed) then
                rebound_lock_base=rebound.base
                rebound_lock_frames=config.BOX_RECOVERY.pressure_lock_frames
                local switch_state=maybe_switch_player(rebound.x,rebound.y,
                    "BOX_REBOUND_PRESSURE")
                if switch_state then return switch_state end
                local px,py=players.xy(my_base)
                local dx,dy=rebound.x-px,rebound.y-py
                movement.move_toward(dx,dy)
                local state=make_state(my_base,dx,dy,
                    "BOX_REBOUND_PRESSURE",possession,gs)
                state.box_threat=rebound.base
                state.box_threat_nearest_defender=rebound.nearest_defender
                state.box_threat_ball_distance=rebound.attacker_ball_distance
                state.intercept_player_ball_distance=math.sqrt((bx-px)^2+(by-py)^2)
                return attach_live_state(state,"BOX_PRESSURE","CPU_BALL_IN_FLIGHT")
            end
            local px, py = players.xy(my_base)
            local target = interception.target(
                px,
                py,
                bx,
                by,
                possession_context.ball_dx,
                possession_context.ball_dy,
                possession_context.ball_speed
            )

            -- Reuse the same locked danger decision used by rebound arbitration.
            local feasible
            target, feasible = defense_interception.choose(
                my_base, bx, by, possession_context.ball_dx,
                possession_context.ball_dy, danger, target
            )
            if danger and danger_lock then
                -- Pin intercept location briefly while velocity samples jitter.
                target.x=danger_lock.target.x
                target.y=danger_lock.target.y
                target.danger=true
                target.frames_to_goal=danger_lock.target.frames_to_goal
            end
            target.player_ball_distance = target.player_ball_distance
                or math.sqrt((bx-px)^2+(by-py)^2)

            local switch_state = maybe_switch_player(
                target.x,
                target.y,
                "CPU_BALL_IN_FLIGHT"
            )
            if switch_state ~= nil then
                return switch_state
            end

            local dx = target.x - px
            local dy = target.y - py
            movement.move_toward(dx, dy)

            local state = make_state(
                my_base, dx, dy, target.danger and "CPU_DANGER_INTERCEPT" or "CPU_BALL_INTERCEPT", possession, gs
            )
            state.intercept_target_x = target.x
            state.intercept_target_y = target.y
            state.intercept_lead_frames = target.lead_frames
            state.intercept_lead_x = target.lead_x
            state.intercept_lead_y = target.lead_y
            state.intercept_predictive = target.predictive
            state.intercept_player_ball_distance =
                target.player_ball_distance
            state.intercept_clipped = target.clipped
            state.intercept_danger = target.danger
            state.intercept_frames_to_goal = target.frames_to_goal
            if feasible then
                state.feasibility_eta = feasible.eta
                state.feasibility_slack = feasible.slack
                state.feasibility_reachable = feasible.reachable
                state.feasibility_best_base = feasible.best_base
                state.feasibility_preferred_base = feasible.preferred_base
            end

            return attach_live_state(
                state,
                "TEAM_POSSESSION_RAM",
                "CPU_BALL_IN_FLIGHT"
            )
        end

        if possession == 0 and team_possession.is_my(team_value) then
            live_attack.reset()
            gk_distribution.reset()
            -- Team possession RAM can remain MY during a dangerous rebound.
            -- Intervene only near our keeper when a CPU outfielder can contest
            -- the ball and no Brazilian outfielder is already close to it.
            local guard=config.BOX_RECOVERY
            local gx,gy=players.xy(config.MY_FIRST)
            local gd2=(bx-gx)^2+(by-gy)^2
            local nearest_cpu=math.huge
            local nearest_my=math.huge
            if gd2<=guard.goal_radius^2 and bx~=0 and by~=0 then
                players.each_cpu(function(base)
                    if base~=config.CPU_FIRST then
                        local x,y=players.xy(base)
                        nearest_cpu=math.min(nearest_cpu,math.sqrt((bx-x)^2+(by-y)^2))
                    end
                end)
                players.each_my(function(base)
                    if base~=config.MY_FIRST then
                        local x,y=players.xy(base)
                        nearest_my=math.min(nearest_my,math.sqrt((bx-x)^2+(by-y)^2))
                    end
                end)
            end
            if nearest_cpu<=guard.attacker_radius
                and nearest_my>guard.own_ball_protection_radius then
                local threat=live_defense.box_pressure(nil,bx,by,true)
                local tx,ty=bx,by
                if threat then tx,ty=threat.x,threat.y end
                local switch_state=maybe_switch_player(tx,ty,"MY_FLIGHT_BOX_DANGER")
                if switch_state then return switch_state end
                local px,py=players.xy(my_base)
                local dx,dy=tx-px,ty-py
                movement.move_toward(dx,dy)
                local state=make_state(my_base,dx,dy,"MY_FLIGHT_BOX_DANGER",possession,gs)
                state.box_threat=threat and threat.base or nil
                state.box_recovery_attacker_distance=nearest_cpu
                state.box_recovery_own_distance=nearest_my
                state.intercept_target_x=tx
                state.intercept_target_y=ty
                return attach_live_state(state,"DANGER_OVERRIDE","MY_BALL_IN_FLIGHT")
            end
            -- A logical MY flight can originate from a confirmed CPU carrier.
            -- Only contest low balls when CPU is materially closer, and a
            -- Brazilian outfielder is still within a reasonable chase range.
            local fc=config.MY_FLIGHT_INTERCEPTION
            if flight_context.origin=="CPU"
                and flight_context.age>0 and flight_context.age<=fc.max_flight_age
                and math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))<=fc.max_height then
                local vx,vy=possession_context.ball_dx,possession_context.ball_dy
                local lead=math.min(fc.max_prediction_frames,
                    math.floor(fc.max_prediction_distance/math.max(
                        1,math.sqrt(vx*vx+vy*vy))))
                local tx,ty=bx+vx*lead,by+vy*lead
                local my_nearest,cpu_nearest=math.huge,math.huge
                players.each_my(function(base)
                    if base~=config.MY_FIRST then
                        local x,y=players.xy(base)
                        my_nearest=math.min(my_nearest,math.sqrt((tx-x)^2+(ty-y)^2))
                    end
                end)
                players.each_cpu(function(base)
                    if base~=config.CPU_FIRST then
                        local x,y=players.xy(base)
                        cpu_nearest=math.min(cpu_nearest,math.sqrt((tx-x)^2+(ty-y)^2))
                    end
                end)
                if my_nearest<=fc.max_my_distance
                    and cpu_nearest+fc.min_cpu_advantage<my_nearest then
                    local switch_state=maybe_switch_player(tx,ty,"MY_FLIGHT_INTERCEPTION")
                    if switch_state then return switch_state end
                    local px,py=players.xy(my_base)
                    local dx,dy=tx-px,ty-py
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,"MY_FLIGHT_INTERCEPTION",possession,gs)
                    state.intercept_target_x=tx
                    state.intercept_target_y=ty
                    state.flight_my_distance=my_nearest
                    state.flight_cpu_distance=cpu_nearest
                    return attach_live_state(state,"ORIGIN_OVERRIDE","MY_BALL_IN_FLIGHT")
                end
            end
            movement.stop()
            return attach_live_state(
                make_state(my_base,0,0,"MY_BALL_IN_FLIGHT",possession,gs),
                "TEAM_POSSESSION_RAM","MY_BALL_IN_FLIGHT")
        end

        -- Fallback temporal somente se 0x104C sair do dominio validado 0/1.
        if fallback_class == "CPU_BALL_IN_FLIGHT" then
            local px, py = players.xy(my_base)
            local target = interception.target(
                px,
                py,
                bx,
                by,
                possession_context.ball_dx,
                possession_context.ball_dy,
                possession_context.ball_speed
            )

            local dx = target.x - px
            local dy = target.y - py
            movement.move_toward(dx, dy)

            local state = make_state(
                my_base, dx, dy, "CPU_BALL_INTERCEPT_FALLBACK",
                possession, gs
            )
            state.intercept_target_x = target.x
            state.intercept_target_y = target.y
            state.intercept_lead_frames = target.lead_frames
            state.intercept_lead_x = target.lead_x
            state.intercept_lead_y = target.lead_y
            state.intercept_predictive = target.predictive
            state.intercept_player_ball_distance =
                target.player_ball_distance
            state.intercept_clipped = target.clipped

            return attach_live_state(
                state,
                "TEMPORAL_FALLBACK",
                fallback_class
            )
        end

        if fallback_class == "MY_BALL_IN_FLIGHT" then
            return attach_live_state(
                make_state(
                    my_base, 0, 0, "MY_BALL_IN_FLIGHT_FALLBACK",
                    possession, gs
                ),
                "TEMPORAL_FALLBACK",
                fallback_class
            )
        end

        local px, py = players.xy(my_base)
        local dx = bx - px
        local dy = by - py
        movement.move_toward(dx, dy)

        return attach_live_state(
            make_state(
                my_base, dx, dy, "LIVE_FALLBACK_CHASE", possession, gs
            ),
            "TEMPORAL_FALLBACK",
            fallback_class
        )
    end

    possession_context.reset()
    defense_interception.reset()

    if game_state.is_restart(gs) then
        restart.assign(bx, by, my_base)
        if gs ~= 2 or restart.taker_team ~= "MY" then throw_in.reset() end

        if gs ~= 1 then goal_kick.reset(); corner_kick.reset() end
        if restart.taker_team ~= "MY" then corner_kick.reset() end
        if restart.taker_team == "MY" then
            if gs == 1 and restart.taker ~= config.MY_FIRST then
                local plan=corner_kick.plan(bx,by,restart.taker,restart.taker_team)
                if plan then
                    local fired=corner_kick.fire(plan,movement)
                    if not fired then movement.stop() end
                    local state=make_state(my_base,nil,nil,
                        fired and "CORNER_KICK_ATTEMPT" or ("CORNER_KICK_"..tostring(plan.reason)),
                        possession,gs)
                    state.corner_fired=fired
                    state.corner_button=plan.button
                    state.corner_direction=plan.direction
                    state.corner_taker=plan.taker
                    state.corner_mode=plan.mode
                    state.corner_end_distance=plan.end_distance
                    state.corner_side_distance=plan.side_distance
                    state.corner_taker_distance=plan.taker_distance
                    state.corner_stable=plan.stable
                    state.corner_attempts=plan.attempts
                    state.corner_reason=plan.reason
                    state.corner_cooldown=plan.cooldown
                    state.corner_displacement=plan.displacement
                    return state
                end
            end
            if gs == 1 and restart.taker == config.MY_FIRST then
                local plan = goal_kick.plan(restart.taker,restart.taker_team,bx,by,my_base)
                local fired = goal_kick.fire(plan,movement)
                if fired then goal_kick.remember_ball(bx,by)
                else movement.stop() end
                local state=make_state(my_base,0,0,
                    fired and "GOAL_KICK_ATTEMPT"
                    or ("GOAL_KICK_"..(plan and plan.mode or "WAIT")),possession,gs)
                state.goal_kick_fired=fired
                state.goal_kick_mode=plan and plan.mode
                state.goal_kick_displacement=plan and plan.displacement
                state.goal_kick_direction=plan and plan.direction
                state.goal_kick_button=plan and plan.button
                state.goal_kick_attempts=plan and plan.attempts
                return state
            end
            if gs == 2 then
                local plan = throw_in.plan(restart.taker, my_base)
                local fired = false
                if plan and plan.mode == "SWITCH_RECEIVER" then
                    movement.press_button("R")
                elseif plan and plan.mode == "MOVE_RECEIVER" then
                    movement.move_toward(plan.move_dx, plan.move_dy)
                else
                    fired = throw_in.fire(plan, movement)
                    if not fired then movement.stop() end
                end
                local state = make_state(my_base, nil, nil,
                    plan and ("THROW_IN_" .. plan.mode) or "THROW_IN_WAIT",
                    possession, gs)
                if plan then
                    state.throw_taker = plan.taker
                    state.throw_receiver = plan.receiver
                    state.throw_mode = plan.mode
                    state.throw_reason = plan.reason
                    state.throw_positioning_frames = plan.positioning_frames
                    state.throw_fired = fired
                    state.throw_direction = plan.direction
                    state.throw_button = plan.button
                    state.throw_receiver_distance = plan.receiver_distance
                    state.throw_receiver_to_target = plan.receiver_to_target
                    state.throw_near_taker = plan.receiver_near_taker
                    state.throw_clearance = plan.receiver_clearance
                    state.throw_score = plan.receiver_score
                    state.throw_field_x1 = plan.field_x1
                    state.throw_field_x2 = plan.field_x2
                    state.throw_field_y1 = plan.field_y1
                    state.throw_field_y2 = plan.field_y2
                    state.throw_stadium = plan.stadium
                    state.throw_receiver_x = plan.receiver_x
                    state.throw_receiver_y = plan.receiver_y
                    state.throw_nearest = plan.nearest
                    state.throw_nearest_distance = plan.nearest_distance
                    state.throw_recovery_switches = plan.recovery_switches
                end
                return state
            end
            throw_in.reset()
            movement.stop()
            return make_state(
                my_base, nil, nil, "RESTART_ATTACK", possession, gs
            )
        end

        if restart.taker_team == "CPU" and restart.mark_target ~= nil then
            local mx, my = players.xy(my_base)
            local tx, ty = players.xy(restart.mark_target)
            local dx = tx - mx
            local dy = ty - my

            movement.move_toward(dx, dy)

            return make_state(
                my_base, dx, dy, "RESTART_DEFENSE", possession, gs
            )
        end

        return make_state(
            my_base, nil, nil, "RESTART_MANUAL", possession, gs
        )
    end

    restart.clear()
    movement.stop()
    return make_state(
        my_base, nil, nil, "UNKNOWN_GAME_STATE", possession, gs
    )
end

console.log("[ISSD] Modular bot carregado")
console.log("[ISSD] K = bot ON/OFF")
console.log("[ISSD] L = stop_on_possession ON/OFF")
console.log("[ISSD] GameplayActive 0x0006: 1=active, other=BOT_IDLE")
console.log("[ISSD] Game_State: 0=live, 1=endline, 2=throw-in, 3=foul, 4=offside, 5=post-goal, 6=half-time")
console.log("[ISSD] marking_score normalized: 35% me + 25% ball + 40% goal-axis")
console.log("[ISSD] target lock: 10 frames, switch margin=0.05")
console.log("[ISSD] switch event HUD: 60 frames")
console.log("[ISSD] field side: derived from CPU_Side 0x106E")
console.log("[ISSD] live: attack lanes + GK distribution + player switch + interception")

while true do
    local keys = input.get()

    if pressed(keys, "K") then
        enabled = not enabled
        restart.clear()
        report:write(enabled and "BOT_ON" or "BOT_OFF", enabled, nil, "K", "toggle")
        console.log(string.format(
            "[ISSD] bot %s",
            enabled and "ON" or "OFF"
        ))
    end

    if pressed(keys, "L") then
        stop_on_possession = not stop_on_possession
        report:write("SETTING_CHANGE", enabled, nil, "L", "stop_on_possession=" .. tostring(stop_on_possession))
        console.log(string.format(
            "[ISSD] stop_on_possession %s",
            stop_on_possession and "ON" or "OFF"
        ))
    end

    if enabled then
        local state = step_bot()
        if state.game_state~=0 or players.valid_my_base(state.possession)
            or players.valid_cpu_base(state.possession) then
            danger_lock=nil
        end
        if flight_interception_pending then
            local outcome=nil
            if players.valid_my_base(state.possession) then
                outcome="MY_FLIGHT_INTERCEPTION_RECOVERED"
            elseif players.valid_cpu_base(state.possession) then
                outcome="MY_FLIGHT_INTERCEPTION_LOST"
            elseif state.game_state~=0 or report.frame-flight_interception_pending.frame>=150 then
                outcome="MY_FLIGHT_INTERCEPTION_UNKNOWN"
            end
            if outcome then
                report:write(outcome,true,state,"OBSERVE_FLIGHT_RESULT",
                    "start_frame="..tostring(flight_interception_pending.frame))
                flight_interception_pending=nil
            end
        end
        if state.status=="MY_FLIGHT_INTERCEPTION" and not flight_interception_pending then
            flight_interception_pending={frame=report.frame}
        end
        defensive_dash_step(state)
        -- Snapshot after the tactical decision, before the next emulated frame.
        state.ball_x, state.ball_y = ball.world_xy()
        local flight=flight_context.update(
            gameplay_active.is_active(state.gameplay_active),
            state.game_state,state.possession,mem.u8(config.ADDR.team_possession))
        if flight then
            state.ball_height=flight.height
            state.ball_height_reference=flight.reference_height
            state.ball_vertical_delta=flight.vertical_delta
            state.ball_vertical_phase=flight.phase
            state.ball_physical_class=flight.physical
            state.ball_flight_origin=flight.origin
            state.ball_flight_age=flight.age
            state.ball_flight_discrepancy=flight.discrepancy
            if flight.discrepancy and not last_flight_discrepancy then
                report:write("BALL_FLIGHT_POSSESSION_MISMATCH",true,state,
                    "OBSERVE_FLIGHT",
                    "origin="..tostring(flight.origin)
                    ..";logical_team="..tostring(flight.logical_team)
                    ..";height="..tostring(flight.height)
                    ..";age="..tostring(flight.age))
            end
            last_flight_discrepancy=flight.discrepancy
        else
            last_flight_discrepancy=false
        end
        if players.valid_my_base(state.my_base) then
            state.player_x, state.player_y = players.xy(state.my_base)
        end
        state.target_x = state.attack_target_x or state.intercept_target_x or state.live_target_x
        state.target_y = state.attack_target_y or state.intercept_target_y or state.live_target_y
        if state.status == "RESTART_DEFENSE" and state.mark_target ~= nil then
            state.target_x, state.target_y = players.xy(state.mark_target)
        end
        if state.status == "LIVE_FALLBACK_CHASE" then
            state.target_x, state.target_y = state.ball_x, state.ball_y
        end
        if state.player_x ~= nil and state.target_x ~= nil and state.target_y ~= nil then
            local dx = state.target_x - state.player_x
            local dy = state.target_y - state.player_y
            state.target_distance = math.sqrt(dx * dx + dy * dy)
        end
        if state.throw_receiver_x ~= nil then
            state.target_x, state.target_y = state.throw_receiver_x, state.throw_receiver_y
            if state.player_x ~= nil then
                local dx = state.target_x - state.player_x
                local dy = state.target_y - state.player_y
                state.target_distance = math.sqrt(dx * dx + dy * dy)
            end
        end
        state.restart_taker_team = restart.taker_team
        state.controller_command = movement.last_command
        state.report_detail = state.throw_mode and ("taker=" .. tostring(state.throw_taker) .. ";receiver=" .. tostring(state.throw_receiver) .. ";mode=" .. state.throw_mode .. ";fired=" .. tostring(state.throw_fired) .. ";direction=" .. tostring(state.throw_direction) .. ";clearance=" .. tostring(state.throw_clearance) .. ";score=" .. tostring(state.throw_score) .. ";nearest=" .. tostring(state.throw_nearest) .. ";nearest_distance=" .. tostring(state.throw_nearest_distance) .. ";receiver_distance_to_taker=" .. tostring(state.throw_receiver_distance)
            .. ";receiver_distance_to_target=" .. tostring(state.throw_receiver_to_target) .. ";positioning_frames=" .. tostring(state.throw_positioning_frames) .. ";reason=" .. tostring(state.throw_reason)
            .. ";near_taker=" .. tostring(state.throw_near_taker)
            .. ";recovery_switches=" .. tostring(state.throw_recovery_switches)
            .. ";field_x1=" .. tostring(state.throw_field_x1)
            .. ";field_x2=" .. tostring(state.throw_field_x2)
            .. ";field_y1=" .. tostring(state.throw_field_y1)
            .. ";field_y2=" .. tostring(state.throw_field_y2)
            .. ";stadium=" .. tostring(state.throw_stadium)) or nil
        state.score_my = mem.u16(config.ADDR.score_my)
        state.score_cpu = mem.u16(config.ADDR.score_cpu)
        state.shots_my = mem.u16(config.ADDR.shots_my)
        state.shots_cpu = mem.u16(config.ADDR.shots_cpu)
        if state.intercept_danger then
            state.report_detail = "danger_intercept=true;frames_to_goal="
                .. tostring(state.intercept_frames_to_goal)
                .. ";lead_frames=" .. tostring(state.intercept_lead_frames)
                .. ";eta=" .. tostring(state.feasibility_eta)
                .. ";slack=" .. tostring(state.feasibility_slack)
                .. ";reachable=" .. tostring(state.feasibility_reachable)
                .. ";best_base=" .. tostring(state.feasibility_best_base)
                .. ";preferred_base=" .. tostring(state.feasibility_preferred_base)
        end
        if state.shot_fired then
            state.report_detail = "button=" .. tostring(state.shot_button)
                .. ";distance=" .. tostring(state.shot_distance)
                .. ";goal_x=" .. tostring(state.shot_goal_x)
                .. ";goal_y=" .. tostring(state.shot_goal_y)
                .. ";angle_deg=" .. tostring(state.shot_angle)
                .. ";lateral_offset=" .. tostring(state.shot_lateral_offset)
                .. ";nearest_defender=" .. tostring(state.shot_nearest_defender)
        end
        if state.attack_goal_x ~= nil then
            state.report_detail = "goal_x=" .. tostring(state.attack_goal_x)
                .. ";goal_y=" .. tostring(state.attack_goal_y)
                .. ";goal_distance=" .. tostring(state.attack_goal_distance)
        end
        -- Observational telemetry: never changes the selected controller action.
        local contact=aerial_contact.update(
            gameplay_active.is_active(state.gameplay_active),
            state.game_state,state.possession)
        if contact then
            report:write("AERIAL_CONTACT_CANDIDATE",true,state,
                "OBSERVE_AERIAL_CONTACT",
                "height="..tostring(contact.height)
                ..";x="..tostring(contact.x)
                ..";y="..tostring(contact.y)
                ..";before_vx="..tostring(contact.before_vx)
                ..";after_vx="..tostring(contact.after_vx)
                ..";before_vy="..tostring(contact.before_vy)
                ..";after_vy="..tostring(contact.after_vy)
                ..";before_vz="..tostring(contact.before_vz)
                ..";after_vz="..tostring(contact.after_vz)
                ..";z_reference="..tostring(contact.z_reference)
                ..";nearest_base="..tostring(contact.nearest_base)
                ..";nearest_team="..tostring(contact.nearest_team)
                ..";nearest_distance="..tostring(contact.nearest_distance)
                ..";plausible_near_player="..tostring(contact.plausible_near_player))
        end
        local ownership=ownership_probe.update(state)
        if ownership and ownership.changed then
            report:write("BALL_OWNERSHIP_TRANSITION",true,state,
                "OBSERVE_OWNERSHIP",
                "class="..tostring(ownership.class)
                ..";owner="..tostring(ownership.owner)
                ..";team_ram="..tostring(ownership.logical_team)
                ..";height="..tostring(ownership.height)
                ..";flight_age="..tostring(ownership.age)
                ..";nearest_my="..tostring(ownership.nearest_my)
                ..";nearest_cpu="..tostring(ownership.nearest_cpu)
                ..";my_distance="..tostring(ownership.my_distance)
                ..";cpu_distance="..tostring(ownership.cpu_distance))
        end
        if ownership and report.frame%30==0 then
            report:write("BALL_OWNERSHIP_SAMPLE",true,state,
                "OBSERVE_OWNERSHIP",
                "class="..tostring(ownership.class)
                ..";owner="..tostring(ownership.owner)
                ..";height="..tostring(ownership.height)
                ..";my_distance="..tostring(ownership.my_distance)
                ..";cpu_distance="..tostring(ownership.cpu_distance)
                ..";logical_team="..tostring(ownership.logical_team))
        end
        local contest,contest_result=contest_feasibility.update(state,report.frame)
        if contest and (contest.changed or report.frame%30==0) then
            report:write(contest.changed and "BALL_CONTEST_ETA_CHANGE" or "BALL_CONTEST_ETA_SAMPLE",
                true,state,"OBSERVE_CONTEST_ETA",
                "class="..tostring(contest.class)
                ..";predicted="..tostring(contest.predicted)
                ..";my_eta="..tostring(contest.my_eta)
                ..";cpu_eta="..tostring(contest.cpu_eta)
                ..";eta_advantage="..tostring(contest.eta_advantage)
                ..";target_x="..tostring(contest.target_x)
                ..";target_y="..tostring(contest.target_y)
                ..";lead="..tostring(contest.lead)
                ..";height="..tostring(contest.height)
                ..";my_base="..tostring(contest.my_base)
                ..";cpu_base="..tostring(contest.cpu_base))
        end
        if contest_result then
            report:write("BALL_CONTEST_OUTCOME",true,state,
                "OBSERVE_CONTEST_OUTCOME",
                "outcome="..tostring(contest_result.outcome)
                ..";start_frame="..tostring(contest_result.start)
                ..";predicted="..tostring(contest_result.predicted)
                ..";elapsed="..tostring(contest_result.elapsed))
        end
        report:observe(true, state)
        -- Outcome monitoring only after an actual GK button pulse.
        if gk_pending and not state.gk_dist_fired then
            gk_pending.age=gk_pending.age+1
            local outcome=nil
            if players.valid_cpu_base(state.possession) then
                outcome="GK_TURNOVER"
            elseif players.valid_my_base(state.possession)
                and state.possession~=config.MY_FIRST then
                outcome="GK_SAFE"
            elseif gk_pending.age>=120 or state.game_state~=0 then
                outcome="GK_OUTCOME_UNKNOWN"
            end
            if outcome then
                report:write(outcome,true,state,state.controller_command,
                    "mode="..tostring(gk_pending.mode)
                    ..";age="..tostring(gk_pending.age)
                    ..";receiver="..tostring(gk_pending.receiver)
                    ..";possession="..tostring(state.possession))
                gk_pending=nil
            end
        end
        if state.gk_dist_fired then
            gk_pending={age=0,mode=state.gk_dist_mode,
                receiver=state.gk_dist_receiver}
        end
        if state.lane_progress_event then
            local event=state.lane_progress_event
            report:write(event.kind,true,state,state.controller_command,
                "carrier="..tostring(event.carrier)
                ..";progress="..tostring(event.progress)
                ..";elapsed="..tostring(event.elapsed)
                ..";stalled="..tostring(event.stalled))
            if event.kind=="LANE_STALLED" then
                report:write("LANE_ABORTED",true,state,state.controller_command,
                    "reason=NO_FORWARD_PROGRESS;duration="
                    ..tostring(state.lane_abort_remaining))
            end
        end
        if state.escape_fired then
            report:write(state.lane_action == "FEINT" and "LANE_FEINT" or "LANE_DASH_START", true, state,
                state.controller_command,
                "button=Y;action=" .. tostring(state.lane_action)
                .. ";blocker=" .. tostring(state.escape_blocker)
                .. ";target_x=" .. tostring(state.target_x)
                .. ";target_y=" .. tostring(state.target_y))
        end
        if state.status=="BOX_EMERGENCY_RECOVERY" and report.frame%15==0 then
            report:write("BOX_EMERGENCY_RECOVERY",true,state,state.controller_command,
                "attacker_distance="..tostring(state.box_recovery_attacker_distance)
                ..";goal_distance="..tostring(state.box_recovery_goal_distance)
                ..";defender_ball_distance="..tostring(state.intercept_player_ball_distance)
                ..";target_x="..tostring(state.intercept_target_x)
                ..";target_y="..tostring(state.intercept_target_y))
        end
        if (state.status=="BOX_REBOUND_PRESSURE" or state.status=="BOX_ATTACKER_PRESSURE")
            and report.frame%15==0 then
            report:write(state.status,true,state,state.controller_command,
                "attacker="..tostring(state.box_threat)
                ..";nearest_defender="..tostring(state.box_threat_nearest_defender)
                ..";attacker_ball_distance="..tostring(state.box_threat_ball_distance))
        end
        if state.status=="MY_FLIGHT_BOX_DANGER" and report.frame%15==0 then
            report:write("MY_FLIGHT_BOX_DANGER",true,state,state.controller_command,
                "cpu_ball="..tostring(state.box_recovery_attacker_distance)
                ..";my_ball="..tostring(state.box_recovery_own_distance)
                ..";target_x="..tostring(state.intercept_target_x)
                ..";target_y="..tostring(state.intercept_target_y))
        end
        if state.status=="ATTACK_FINAL_THIRD_REPOSITION" and report.frame%30==0 then
            report:write("ATTACK_FINAL_THIRD_REPOSITION",true,state,state.controller_command,
                "forward="..tostring(state.attack_goal_forward)
                ..";lateral="..tostring(state.attack_lateral_offset)
                ..";target_x="..tostring(state.attack_target_x)
                ..";target_y="..tostring(state.attack_target_y)
                ..";shot_reason="..tostring(state.shot_reason))
        end
        if state.status=="DEFENSE_BOX_COVERAGE" and report.frame%30==0 then
            report:write("BOX_THREAT",true,state,state.controller_command,
                "threat="..tostring(state.box_threat)
                ..";goal_distance="..tostring(state.box_threat_goal_distance)
                ..";ball_distance="..tostring(state.box_threat_ball_distance)
                ..";nearest_defender="..tostring(state.box_threat_nearest_defender))
        end
        if state.gk_dist_fired then
            report:write("GK_DISTRIBUTION_ATTEMPT", true, state,
                state.controller_command,
                "mode="..tostring(state.gk_dist_mode)
                ..";button="..tostring(state.gk_dist_button)
                ..";direction="..tostring(state.gk_dist_direction)
                ..";receiver="..tostring(state.gk_dist_receiver)
                ..";distance="..tostring(state.gk_dist_receiver_distance)
                ..";clearance="..tostring(state.gk_dist_receiver_clearance)
                ..";lane_clearance="..tostring(state.gk_dist_lane_clearance)
                ..";reason="..tostring(state.gk_dist_decision_reason))
        end
        if state.game_state==3 and state.free_kick_mode
            and report.frame%60==0 then
            report:write("FREE_KICK_DIAGNOSTIC",true,state,state.controller_command,
                "mode="..tostring(state.free_kick_mode)
                ..";taker="..tostring(state.free_kick_taker)
                ..";controlled="..tostring(state.my_base)
                ..";my_distance="..tostring(state.free_kick_my_distance)
                ..";cpu_distance="..tostring(state.free_kick_cpu_distance)
                ..";attempts="..tostring(state.free_kick_attempts)
                ..";cooldown="..tostring(state.free_kick_cooldown)
                ..";ball_displacement="..tostring(state.free_kick_displacement))
        end
        if state.free_kick_switch_fired then
            report:write("FREE_KICK_SWITCH_TAKER",true,state,state.controller_command,
                "candidate="..tostring(state.free_kick_taker)
                ..";controlled="..tostring(state.my_base))
        end
        if state.free_kick_fired then
            report:write("FREE_KICK_ATTEMPT",true,state,state.controller_command,
                "mode="..tostring(state.free_kick_mode)
                ..";button="..tostring(state.free_kick_button)
                ..";direction="..tostring(state.free_kick_direction)
                ..";taker="..tostring(state.free_kick_taker)
                ..";my_distance="..tostring(state.free_kick_my_distance)
                ..";cpu_distance="..tostring(state.free_kick_cpu_distance)
                ..";stable="..tostring(state.free_kick_stable)
                ..";attempts_before="..tostring(state.free_kick_attempts))
        end
        if state.corner_reason and
            (state.corner_reason=="EXHAUSTED" or state.corner_reason=="BALL_MOVED")
            and report.frame%60==0 then
            report:write("CORNER_KICK_DIAGNOSTIC",true,state,state.controller_command,
                "reason="..tostring(state.corner_reason)
                ..";attempts="..tostring(state.corner_attempts)
                ..";displacement="..tostring(state.corner_displacement))
        end
        if state.corner_fired then
            report:write("CORNER_KICK_ATTEMPT",true,state,state.controller_command,
                "mode="..tostring(state.corner_mode)
                ..";button="..tostring(state.corner_button)
                ..";direction="..tostring(state.corner_direction)
                ..";taker="..tostring(state.corner_taker)
                ..";end_distance="..tostring(state.corner_end_distance)
                ..";side_distance="..tostring(state.corner_side_distance)
                ..";taker_distance="..tostring(state.corner_taker_distance)
                ..";stable="..tostring(state.corner_stable)
                ..";attempts_before="..tostring(state.corner_attempts)
                ..";reason="..tostring(state.corner_reason)
                ..";cooldown="..tostring(state.corner_cooldown))
        end
        local tackle_outcome=active_tackle.observe(state.possession)
        if tackle_outcome then
            report:write(tackle_outcome.kind,true,state,state.controller_command,
                "defender="..tostring(tackle_outcome.defender)
                ..";carrier="..tostring(tackle_outcome.carrier)
                ..";holder="..tostring(tackle_outcome.holder)
                ..";distance="..tostring(tackle_outcome.distance)
                ..";defender_ball_distance="..tostring(tackle_outcome.defender_ball_distance)
                ..";carrier_ball_distance="..tostring(tackle_outcome.carrier_ball_distance)
                ..";age="..tostring(tackle_outcome.age))
        end
        if state.shot_lane_lateral~=nil
            and report.frame%config.SHOT_LANE.telemetry_frames==0 then
            report:write("SHOT_LANE_BLOCK_ATTEMPT",true,state,state.controller_command,
                "lateral="..tostring(state.shot_lane_lateral)
                ..";along="..tostring(state.shot_lane_along)
                ..";distance="..tostring(state.shot_lane_distance))
            if state.shot_lane_exposed then
                report:write("SHOT_LANE_EXPOSED",true,state,state.controller_command,
                    "lateral="..tostring(state.shot_lane_lateral)
                    ..";along="..tostring(state.shot_lane_along))
            end
        end
        if state.goal_side_between~=nil
            and report.frame%config.GOAL_SIDE.measure_every_frames==0 then
            report:write("GOAL_SIDE_POSITION",true,state,state.controller_command,
                "between="..tostring(state.goal_side_between)
                ..";lateral="..tostring(state.goal_side_lateral)
                ..";projection="..tostring(state.goal_side_projection)
                ..";goal_distance="..tostring(state.goal_side_distance)
                ..";emergency="..tostring(state.goal_side_emergency))
        end
        if state.tackle_fired then
            report:write("TACKLE_ATTEMPT",true,state,state.controller_command,
                "defender="..tostring(state.tackle_defender)
                ..";carrier="..tostring(state.tackle_carrier)
                ..";distance="..tostring(state.tackle_distance)
                ..";defender_ball_distance="..tostring(state.tackle_defender_ball_distance)
                ..";carrier_ball_distance="..tostring(state.tackle_carrier_ball_distance)
                ..";button=B")
        end
        if state.game_state==1 and state.goal_kick_mode and report.frame%30==0 then
            report:write("GOAL_KICK_DIAGNOSTIC",true,state,state.controller_command,
                "mode="..tostring(state.goal_kick_mode)
                ..";distance="..tostring(state.goal_kick_distance)
                ..";ball_displacement="..tostring(state.goal_kick_displacement)
                ..";attempts="..tostring(state.goal_kick_attempts))
        end
        if state.goal_kick_fired then
            report:write("GOAL_KICK_ATTEMPT",true,state,
                state.controller_command,
                "button="..tostring(state.goal_kick_button)
                ..";direction="..tostring(state.goal_kick_direction)
                ..";nearest_opponent="..tostring(state.goal_kick_nearest)
                ..";attempts_before="..tostring(state.goal_kick_attempts))
        end
        if state.defensive_recovery and state.defensive_hold_age==1 then
            report:write("DEFENSIVE_RECOVERY",true,state,state.controller_command,
                "carrier="..tostring(state.my_base)..";zone=1")
        end
        if state.defensive_outlet_fired then
            report:write("DEFENSIVE_OUTLET_PASS",true,state,state.controller_command,
                "carrier="..tostring(state.my_base)
                ..";receiver="..tostring(state.forward_pass_receiver)
                ..";distance="..tostring(state.forward_pass_distance)
                ..";clearance="..tostring(state.forward_pass_clearance)
                ..";lane_clearance="..tostring(state.forward_pass_lane_clearance))
        end
        if state.status=="DEFENSIVE_HOLD_REASSESSMENT" then
            report:write("DEFENSIVE_HOLD_REASSESSMENT",true,state,state.controller_command,
                "carrier="..tostring(state.my_base)
                ..";count="..tostring(state.defensive_reassessments)
                ..";total="..tostring(state.defensive_total_distance)
                ..";threat="..tostring(state.defensive_pressure_distance))
        end
        if state.defensive_clear_fired then
            report:write("DEFENSIVE_PRESSURE_CLEAR",true,state,state.controller_command,
                "distance="..tostring(state.defensive_pressure_distance)
                ..";reason="..tostring(state.defensive_exit_reason)
                ..";button="..tostring(state.defensive_clear_button)
                ..";direction="..tostring(state.defensive_clear_direction))
        end
        if state.status=="DEFENSIVE_HOLD" and report.frame%30==0 then
            report:write("DEFENSIVE_EXIT_DIAGNOSTIC",true,state,state.controller_command,
                "reason="..tostring(state.defensive_exit_reason)
                ..";threat_distance="..tostring(state.defensive_pressure_distance)
                ..";age="..tostring(state.defensive_hold_age))
        end
        if state.boundary_changed and report.frame%15==0 then
            report:write("BOUNDARY_TARGET_CLAMPED",true,state,state.controller_command,
                "original_x="..tostring(state.boundary_original_x)
                ..";original_y="..tostring(state.boundary_original_y)
                ..";target_x="..tostring(state.attack_target_x)
                ..";target_y="..tostring(state.attack_target_y))
        end
        if state.boundary_risk and report.frame%30==0 then
            report:write("BOUNDARY_RISK",true,state,state.controller_command,
                "status="..tostring(state.status)
                ..";corrected="..tostring(state.boundary_changed))
        end
        if state.status=="DEFENSIVE_SHORT_ESCAPE" and report.frame%30==0 then
            report:write("DEFENSIVE_SHORT_ESCAPE",true,state,state.controller_command,
                "carrier="..tostring(state.my_base)
                ..";reason="..tostring(state.defensive_exit_reason)
                ..";age="..tostring(state.defensive_hold_age))
        end
        if state.status=="DEFENSIVE_HOLD" and report.frame%60==0 then
            report:write("DEFENSIVE_HOLD",true,state,state.controller_command,
                "carrier="..tostring(state.my_base)
                ..";age="..tostring(state.defensive_hold_age))
        end
        if state.centralizing_pass then
            report:write("ATTACK_CENTRALIZING_PASS",true,state,state.controller_command,
                "receiver="..tostring(state.forward_pass_receiver)
                ..";clearance="..tostring(state.forward_pass_clearance)
                ..";lane_clearance="..tostring(state.forward_pass_lane_clearance))
        end
        if state.shot_reason=="BAD_SHOT_ANGLE" and report.frame%45==0 then
            report:write("ATTACK_SHOT_ANGLE_REJECTED",true,state,state.controller_command,
                "distance="..tostring(state.shot_distance)
                ..";forward="..tostring(state.shot_forward))
        end
        if state.forward_pass_fired then
            report:write("FORWARD_PASS_ATTEMPT",true,state,state.controller_command,
                "zone="..tostring(state.forward_pass_zone)
                ..";intent="..tostring(state.forward_pass_intent)
                ..";receiver="..tostring(state.forward_pass_receiver)
                ..";distance="..tostring(state.forward_pass_distance)
                ..";forward="..tostring(state.forward_pass_forward)
                ..";lateral="..tostring(state.forward_pass_lateral)
                ..";receiver_clearance="..tostring(state.forward_pass_clearance)
                ..";lane_clearance="..tostring(state.forward_pass_lane_clearance)
                ..";score="..tostring(state.forward_pass_score)
                ..";button="..tostring(state.forward_pass_button)
                ..";direction="..tostring(state.forward_pass_direction))
        end
        if state.shot_fired then
            report:write("SHOT_ATTEMPT", true, state,
                state.controller_command, state.report_detail)
        end
        if state.shot_reason and not state.shot_fired and report.frame % 60 == 0 then
            report:write("SHOT_EVALUATION", true, state, state.shot_reason,
                "reason=" .. tostring(state.shot_reason)
                .. ";distance=" .. tostring(state.shot_distance)
                .. ";forward=" .. tostring(state.shot_forward)
                .. ";blocker=" .. tostring(state.shot_blocker)
                .. ";cooldown=" .. tostring(state.shot_cooldown))
        end
        goal_trace.observe(true, state)
        overlay.draw(state)
    else
        gk_pending=nil
        restart.clear()
        report:observe(false, nil)
        local gs = game_state.read()
        goal_trace.observe(false, {
            game_state = gs,
            score_my = mem.u16(config.ADDR.score_my),
            score_cpu = mem.u16(config.ADDR.score_cpu),
            shots_my = mem.u16(config.ADDR.shots_my),
            shots_cpu = mem.u16(config.ADDR.shots_cpu),
            gameplay_active = gameplay_active.read(),
            possession = ball.possession(),
            my_base = read_my_base(),
            ball_x = mem.s16(config.ADDR.ball_x),
            ball_y = mem.s16(config.ADDR.ball_y),
            controller_command = "BOT_OFF",
            status = "BOT_OFF",
        })
        overlay.draw_off()
    end

    previous_keys = keys
    emu.frameadvance()
end
