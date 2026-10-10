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
local AerialDefensiveContact = dofile(DIR .. "../state/aerial_defensive_contact.lua")
local GKReboundRecovery = dofile(DIR .. "../state/gk_rebound_recovery.lua")
local BallFlightContext = dofile(DIR .. "../state/ball_flight_context.lua")
local OwnershipProbe = dofile(DIR .. "../state/ownership_probe.lua")
local BallPhysicalControl = dofile(DIR .. "../state/ball_physical_control.lua")
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
local DefensiveMidfieldTransition = dofile(DIR .. "../state/defensive_midfield_transition.lua")
local MidAttackTransition = dofile(DIR .. "../state/mid_attack_transition.lua")
local DefensiveClearanceOutcome = dofile(DIR .. "../state/defensive_clearance_outcome.lua")
local LongPassPositionObserver = dofile(DIR .. "../state/long_pass_position_observer.lua")
local LongPassReceiverSelection = dofile(DIR .. "../state/long_pass_receiver_selection.lua")
local GKDistribution = dofile(DIR .. "../tactics/gk_distribution.lua")
local GoalKick = dofile(DIR .. "../tactics/goal_kick.lua")
local CornerKick = dofile(DIR .. "../tactics/corner_kick.lua")
local FreeKick = dofile(DIR .. "../tactics/free_kick.lua")
local Interception = dofile(DIR .. "../tactics/interception.lua")
local DefenseInterception = dofile(DIR .. "../tactics/defense_interception.lua")
local PlayerSwitch = dofile(DIR .. "../control/player_switch.lua")
local TeamPossession = dofile(DIR .. "../state/team_possession.lua")
local BallLogicalTeamTransition = dofile(DIR .. "../state/ball_logical_team_transition.lua")
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
local aerial_defensive_contact = AerialDefensiveContact.new(config, players)
local gk_rebound_recovery = GKReboundRecovery.new(config, players)
local flight_context = BallFlightContext.new(config, mem, players)
local ownership_probe = OwnershipProbe.new(config, mem, players)
local ball_physical_control = BallPhysicalControl.new(config,players)
local contest_feasibility = BallContestFeasibility.new(config, players)
local game_state = GameState.new(config, mem)
local gameplay_active = GameplayActive.new(config, mem)
local field_side = FieldSide.new(config, mem)
local defensive_midfield_transition = DefensiveMidfieldTransition.new(config,mem,players,field_side)
local mid_attack_transition = MidAttackTransition.new(config,mem,players,field_side)
local defensive_clearance_outcome = DefensiveClearanceOutcome.new(config,players,field_side)
local long_pass_position_observer = LongPassPositionObserver.new(config,players)
local long_pass_receiver_selection = LongPassReceiverSelection.new(config,players)
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
local team_possession = TeamPossession.new(config, mem, players)
local logical_team_transition = BallLogicalTeamTransition.new(config,mem,players)
local team_possession_conflict_active = false
local Last_Player_Ball_Possession = 0
local Last_Player_Ball_Possession_Frame = nil
local Last_Player_Ball_Possession_Team = nil
local gk_release_lock = nil
local gk_release_pending = nil
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
local cpu_carrier_continuity=nil
local defensive_hold_age = 0
local defensive_hold_guard=nil
local defensive_pass_alignment=nil
local defensive_pass_pending=nil
local defensive_pass_sequence=0
local defensive_alignment_blocks={}
local bot_build_logged=false
local BOT_BUILD_ID="long-pass-observers-game-state-20261010-v31"
local defensive_escape_pending=nil
local defensive_clear_charge=nil
local clearance_calibration_index=0
local rebound_lock_base=nil
local rebound_lock_frames=0
local latest_contest=nil
local latest_contest_frame=nil
local contest_intercept_lock=nil
local my_recovery_lock=nil
local contest_abort_until=0
local final_third_lock=nil
local final_third_decision=nil
local final_third_reset=nil
local final_third_failures={count=0,last=-99999}
local final_third_reset_cooldown=0
local midfield_rebuild=nil
local second_ball_last_shots_cpu=nil
local second_ball_lock=nil
local first_rebound_lock=nil
local second_ball_sequence=0
local final_third_cooldown_until=0
local last_flight_discrepancy=false
local flight_interception_pending=nil
local danger_lock=nil
local header_last_frame=-99999
local defensive_header_pending=nil
local header_last_height=nil
local aerial_contest_lock=nil
local long_pass_ai_lock=nil
local aerial_contact_previous_height=nil
local aerial_contact_last_frame=-99999
local aerial_contact_attempt_lock=nil
local natural_reception_pending=nil
-- Defensive sprint is deliberately separate from attack dash.
local defensive_dash={remaining=0,cooldown=0,base=nil,start_distance=nil,mode=nil,
    start_x=nil,start_y=nil,target_x=nil,target_y=nil,frames=0}
local function defensive_dash_step(state)
    local cfg=config.DEFENSIVE_DASH
    local eligible={
        LIVE_DEFENSE=true, CPU_CARRIER_CONTINUITY_PRESS=true,
        PRE_SHOT_DEFENSIVE_COVER=true, BOX_ATTACKER_PRESSURE=true,
        BOX_REBOUND_PRESSURE=true, CPU_DANGER_INTERCEPT=true,
        CPU_GROUND_INTERCEPT=true, CPU_LOW_INTERCEPT=true,
        CPU_AERIAL_INTERCEPT=true, CPU_BALL_INTERCEPT=true,
        CPU_BALL_INTERCEPT_FALLBACK=true,
        GK_REBOUND_RECOVERY=true, BOX_SECOND_BALL_CONTINUITY=true, MY_FLIGHT_BOX_DANGER=true, MY_BOX_GROUND_RECOVERY=true,
        MY_BOX_LOW_RECOVERY=true, MY_BOX_AERIAL_COVER=true,
        LIVE_FALLBACK_CHASE=true,
        GOAL_BOUND_INTERCEPT_PRIORITY=true,
        FIRST_REBOUND_RECOVERY=true,
        -- Interception uses Y only for approach, never to imply a tackle.
        MY_UNOWNED_RECOVERY=true, MY_UNOWNED_RECOVERY_LOCK=true,
        BALL_CONTEST_INTERCEPT=true, BALL_CONTEST_INTERCEPT_LOCK=true,
        MY_FLIGHT_INTERCEPTION=true,
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
    local reserved=command:find("B",1,true) or command:find("R",1,true)
        or command:find("A",1,true) or command:find("X",1,true)
    if defensive_dash.remaining>0 or defensive_dash.frames>0 then
        local reason=nil
        if not active then reason="TACTICAL_PREEMPTION"
        elseif reserved then reason="BUTTON_PRIORITY"
        elseif not directional then reason="NO_DIRECTION"
        elseif defensive_dash.base~=state.my_base then reason="PLAYER_CHANGED"
        elseif d<=cfg.stop_distance then reason="ARRIVED"
        elseif defensive_dash.remaining<=0 then reason="BURST_LIMIT" end
        local ending=reason~=nil
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
                "reason="..tostring(reason)..";frames="..tostring(defensive_dash.frames)
                ..";mode="..tostring(defensive_dash.mode)
                ..";player_displacement="..tostring(displacement)
                ..";fixed_target_end_distance="..tostring(fixed_end)
                ..";fixed_target_gain="..tostring(fixed_end
                    and defensive_dash.start_distance-fixed_end or nil)
                ..";start_distance="..tostring(defensive_dash.start_distance)
                ..";end_distance="..tostring(d)
                ..";gain="..tostring(d and defensive_dash.start_distance
                    and (defensive_dash.start_distance-d) or nil))
            defensive_dash.remaining=0
            defensive_dash.frames=0
            defensive_dash.cooldown=cfg.cooldown_frames
        end
    end
    local approach_threshold=cfg.start_distance
    if active and (state.status=="MY_UNOWNED_RECOVERY"
        or state.status=="MY_UNOWNED_RECOVERY_LOCK"
        or state.status=="BALL_CONTEST_INTERCEPT"
        or state.status=="BALL_CONTEST_INTERCEPT_LOCK"
        or state.status=="MY_FLIGHT_INTERCEPTION") then
        approach_threshold=cfg.recovery_start_distance
    end
    if active and directional and not reserved and d>=approach_threshold
        and (defensive_dash.remaining>0 or (defensive_dash.frames==0
            and defensive_dash.cooldown==0)) then
        if defensive_dash.remaining==0 then
            defensive_dash.remaining=cfg.burst_frames
            defensive_dash.frames=0
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
        -- Do not replace tackle/switch/contact commands with Y.
        movement.move_toward_button(state.dx,state.dy,cfg.button)
        defensive_dash.remaining=defensive_dash.remaining-1
        defensive_dash.frames=defensive_dash.frames+1
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
    if not bot_build_logged then
        report:write("BOT_BUILD",true,
            {my_base=my_base,game_state=game_state.read(),
             gameplay_active=gameplay_value},
            "BUILD",BOT_BUILD_ID)
        bot_build_logged=true
    end
    player_switch.observe_control(my_base)
    local control_change=player_switch.take_control_change()
    if control_change then
        local from,to=control_change.from,control_change.to
        local bx,by=ball.world_xy()
        local gx,gy=players.xy(config.MY_FIRST)
        local function measures(base)
            local px,py=players.xy(base)
            local ball_distance=math.sqrt((px-bx)^2+(py-by)^2)
            local nearest,attacker_distance=nil,math.huge
            players.each_cpu(function(cpu)
                if cpu~=config.CPU_FIRST then
                    local cx,cy=players.xy(cpu)
                    local d=math.sqrt((px-cx)^2+(py-cy)^2)
                    if d<attacker_distance then
                        nearest=cpu;attacker_distance=d
                    end
                end
            end)
            local covered=false
            if nearest then
                local cx,cy=players.xy(nearest)
                local vx,vy=gx-cx,gy-cy
                local length2=vx*vx+vy*vy
                if length2>1 then
                    local t=((px-cx)*vx+(py-cy)*vy)/length2
                    local lateral=math.abs((px-cx)*vy-(py-cy)*vx)/math.sqrt(length2)
                    covered=t>0 and t<1 and lateral<=config.GOAL_SIDE.offset
                end
            end
            return ball_distance,attacker_distance,nearest,covered
        end
        local fb,fa,fc,fg=measures(from)
        local tb,ta,tc,tg=measures(to)
        report:write("MY_CONTROL_CHANGED",true,
            {my_base=to,game_state=game_state.read(),
             gameplay_active=gameplay_value},
            "OBSERVE_MYCTRL",
            "from="..from..";to="..to
            ..";r_pending="..tostring(control_change.requested)
            ..";expected="..tostring(control_change.expected)
            ..";from_ball_distance="..fb..";to_ball_distance="..tb
            ..";from_attacker_distance="..fa
            ..";to_attacker_distance="..ta
            ..";from_nearest_cpu="..tostring(fc)
            ..";to_nearest_cpu="..tostring(tc)
            ..";from_goal_side="..tostring(fg)
            ..";to_goal_side="..tostring(tg))
        -- An interception lock belongs to a specific control context.
        contest_intercept_lock=nil
        danger_lock=nil
    end
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
    if defensive_clear_charge and
        (possession~=defensive_clear_charge.carrier or gs~=0
         or not gameplay_active.is_active(gameplay_value)) then
        report:write("DEF_CLEAR_CHARGE_ABORT",true,
            {possession=possession,game_state=gs,my_base=my_base},
            "OBSERVE_CHARGE",
            "reason=POSSESSION_OR_PLAY_CHANGED;frames="
            ..defensive_clear_charge.frames)
        defensive_clear_charge=nil
    end
    -- Observe actual individual ownership on every frame, independent of
    -- the control selection, logical team flag, and the pass command.
    if defensive_pass_pending then
        local p=defensive_pass_pending
        local age=report.frame-p.frame
        local reason=nil
        local kind=nil
        if gs~=0 or not gameplay_active.is_active(gameplay_value) then
            kind="PASS_UNRESOLVED";reason="STOPPAGE"
        elseif players.valid_cpu_base(possession) then
            kind="PASS_INTERCEPTED";reason="CPU_POSSESSION"
        elseif players.valid_my_base(possession) and possession~=p.passer then
            kind="PASS_RECEIVED"
            reason=possession==p.receiver and "EXPECTED_RECEIVER"
                or "OTHER_MY_RECEIVER"
        elseif age>=config.DEFENSIVE_PASS_OUTCOME.max_frames then
            kind="PASS_UNRESOLVED"
            reason=possession==p.passer and "PASSER_STILL_OWNS"
                or "NO_CONFIRMED_RECEIVER"
        end
        if kind then
            report:write("DEFENSIVE_"..kind,true,
                {possession=possession,game_state=gs,my_base=my_base},
                "OBSERVE_PASS_OUTCOME",
                "sequence="..p.sequence..";passer="..p.passer
                ..";expected_receiver="..tostring(p.receiver)
                ..";actual_owner="..tostring(possession)
                ..";age="..age..";reason="..reason
                ..";direction="..tostring(p.direction))
            defensive_pass_pending=nil
        end
    end
    -- Read the raw team flag on every bot step, including inactive gameplay.
    -- Log observed edges, not presumed player touches or recovered possession.
    local logical_edge=logical_team_transition.update(report.frame,
        gameplay_value,gs,possession,Last_Player_Ball_Possession,
        Last_Player_Ball_Possession_Frame)
    if logical_edge then
        report:write("BALL_LOGICAL_TEAM_TRANSITION",true,
            {possession=possession,game_state=gs,my_base=my_base,
             gameplay_active=gameplay_value},
            "OBSERVE_LOGICAL_EDGE",
            "from="..tostring(logical_edge.from)
            ..";to="..tostring(logical_edge.to)
            ..";frame_gap="..tostring(logical_edge.frame_gap)
            ..";owner="..tostring(logical_edge.owner)
            ..";last_owner="..tostring(logical_edge.last_owner)
            ..";frames_since_owner="..tostring(logical_edge.frames_since_owner)
            ..";height="..tostring(logical_edge.height)
            ..";dist_my_gk="..tostring(logical_edge.dist_my_gk)
            ..";dist_cpu_gk="..tostring(logical_edge.dist_cpu_gk)
            ..";shots_cpu="..tostring(logical_edge.shots_cpu)
            ..";shots_cpu_delta="..tostring(logical_edge.shots_cpu_delta)
            ..";shots_my="..tostring(logical_edge.shots_my)
            ..";shots_my_delta="..tostring(logical_edge.shots_my_delta)
            ..";gameplay="..tostring(logical_edge.gameplay)
            ..";gs="..tostring(logical_edge.game_state))
    end
    -- Universal last confirmed owner: zero and temporary BOT_IDLE never erase it.
    local confirmed_team=team_possession.owner_kind(possession)
    if confirmed_team~="NONE" then
        if Last_Player_Ball_Possession~=possession then
            report:write("LAST_PLAYER_BALL_POSSESSION_CHANGE",true,
                {possession=possession,game_state=gs,my_base=my_base},
                "OBSERVE_LAST_OWNER",
                "previous="..Last_Player_Ball_Possession..";current="..possession
                ..";team="..confirmed_team)
        end
        Last_Player_Ball_Possession=possession
        Last_Player_Ball_Possession_Frame=report.frame
        Last_Player_Ball_Possession_Team=confirmed_team
        if possession==config.CPU_FIRST then
            gk_release_pending={last_seen=report.frame}
        else
            gk_release_pending=nil
        end
    end
    -- A short non-gameplay animation between GK hold and release must not
    -- discard the last confirmed goalkeeper. Do not start a lock in BOT_IDLE.
    if gs~=0 and gs~=1 then
        gk_release_lock=nil
        gk_release_pending=nil
    elseif gk_release_pending and
        report.frame-gk_release_pending.last_seen>
            config.GK_RELEASE_ORIGIN_LOCK.release_grace_frames then
        gk_release_pending=nil
    end
    if gameplay_value==1 and gs==0 and possession==0
        and gk_release_pending and not gk_release_lock then
        gk_release_lock={start=report.frame,from=config.CPU_FIRST}
        gk_release_pending=nil
        report:write("GK_RELEASE_ORIGIN_START",true,
            {possession=possession,game_state=gs,my_base=my_base},
            "OBSERVE_GK_RELEASE",
            "origin=CPU_GK;last_owner="..Last_Player_Ball_Possession)
    end
    if gk_release_lock and (possession~=0 or
        report.frame-gk_release_lock.start>=config.GK_RELEASE_ORIGIN_LOCK.max_frames
        or (gs~=0 and gs~=1)) then
        local reason=possession~=0 and "NEW_CONFIRMED_OWNER"
            or (gs~=0 and gs~=1) and "STOPPAGE" or "TIMEOUT"
        report:write("GK_RELEASE_ORIGIN_END",true,
            {possession=possession,game_state=gs,my_base=my_base},
            "OBSERVE_GK_RELEASE",
            "reason="..reason..";age="..(report.frame-gk_release_lock.start))
        gk_release_lock=nil
    end
    if defensive_escape_pending then
        local p=defensive_escape_pending
        local bx,by=ball.world_xy()
        local travel=math.sqrt((bx-p.x)^2+(by-p.y)^2)
        local age=report.frame-p.start
        local result=nil
        if gs~=0 then result="STOPPAGE"
        elseif possession~=p.carrier then
            result=players.valid_my_base(possession)
                and "TEAMMATE_CONTROL" or (players.valid_cpu_base(possession)
                and "CPU_TURNOVER" or "BALL_RELEASED")
        elseif age>=config.DEFENSIVE_EXIT.guard_outcome_frames then
            result=travel>=config.DEFENSIVE_EXIT.guard_min_ball_travel
                and "BALL_MOVED" or "NO_BALL_MOVEMENT"
        end
        if result then
            report:write("DEFENSIVE_HOLD_OUTCOME",true,
                {possession=possession,game_state=gs,my_base=my_base},
                "OBSERVE_ESCAPE","result="..result..";age="..age
                ..";ball_travel="..travel..";attempt="..p.attempt)
            defensive_escape_pending=nil
        end
    end
    -- Shot counter is an event signal, not evidence of a keeper save.
    local shots_cpu=mem.u16(config.ADDR.shots_cpu)
    if second_ball_last_shots_cpu and shots_cpu==second_ball_last_shots_cpu+1
        and gs==0 then
        local bx0,by0=ball.world_xy()
        local gx0,gy0=players.xy(config.MY_FIRST)
        local cfg=config.BOX_SECOND_BALL
        if (bx0-gx0)^2+(by0-gy0)^2<=cfg.goal_radius^2 then
            second_ball_sequence=second_ball_sequence+1
            second_ball_lock={start=report.frame,
                expires=report.frame+cfg.window_frames,
                sequence=second_ball_sequence,switches=0,saw_unowned=false}
            report:write("BOX_SECOND_BALL_START",true,
                {possession=possession,game_state=gs,my_base=my_base},
                "SHOT_COUNTER","sequence="..second_ball_sequence)
        end
    end
    if second_ball_last_shots_cpu and shots_cpu<second_ball_last_shots_cpu then
        second_ball_lock=nil
    end
    second_ball_last_shots_cpu=shots_cpu
    if second_ball_lock then
        if possession==0 then second_ball_lock.saw_unowned=true end
        local reason=nil
        if gs~=0 or not gameplay_active.is_active(gameplay_value) then
            reason="STOPPAGE"
        elseif second_ball_lock.saw_unowned and players.valid_my_base(possession) then
            reason="MY_RECOVERED"
        elseif second_ball_lock.saw_unowned and players.valid_cpu_base(possession) then
            reason="CPU_RECOVERED"
        elseif report.frame>=second_ball_lock.expires then reason="TIMEOUT" end
        if reason then
            report:write(reason=="MY_RECOVERED" and
                "BOX_SECOND_BALL_RECOVERED" or "BOX_SECOND_BALL_LOST",
                true,{possession=possession,game_state=gs,my_base=my_base},
                "SECOND_BALL","reason="..reason..";sequence="
                ..second_ball_lock.sequence..";elapsed="
                ..(report.frame-second_ball_lock.start))
            second_ball_lock=nil
        end
    end
    -- A reposition attempt belongs to one confirmed attacking carrier.
    if possession~=my_base or gs~=0
        or not gameplay_active.is_active(gameplay_value) then
        if final_third_lock then
            report:write("REPOSITION_ABORT",true,
                {possession=possession,game_state=gs,my_base=my_base},
                "OBSERVE_REPOSITION",
                "reason="..(gs~=0 and "STOPPAGE" or "POSSESSION_LOST")
                ..";age="..(report.frame-final_third_lock.start))
        end
        final_third_lock=nil
        final_third_decision=nil
        if final_third_reset then
            report:write("FINAL_THIRD_RESET_ABORT",true,
                {possession=possession,game_state=gs,my_base=my_base},
                "RESET","reason=POSSESSION_LOST_OR_STOPPAGE")
        end
        final_third_reset=nil
        final_third_failures.count=0
        if midfield_rebuild then
            report:write("MIDFIELD_REBUILD_OUTCOME",true,
                {possession=possession,game_state=gs,my_base=my_base},
                "REBUILD","result=POSSESSION_LOST_OR_STOPPAGE")
            midfield_rebuild=nil
        end
    end
    if gs~=1 then goal_kick.reset() end
    if possession~=0 or gs~=0 or not gameplay_active.is_active(gameplay_value) then
        if first_rebound_lock then
            report:write("FIRST_REBOUND_LOCK_END",true,
                {possession=possession,game_state=gs,my_base=my_base},
                "OBSERVE_REBOUND",
                "reason="..(possession~=0 and "POSSESSION_CONFIRMED"
                    or gs~=0 and "STOPPAGE" or "GAMEPLAY_IDLE"))
            first_rebound_lock=nil
        end
        contest_intercept_lock=nil
        if my_recovery_lock then
            local reason=possession~=0 and "POSSESSION_CONFIRMED"
                or gs~=0 and "STOPPAGE" or "GAMEPLAY_IDLE"
            report:write("MY_RECOVERY_LOCK_END",true,
                {possession=possession,game_state=gs,my_base=my_base},
                "OBSERVE_RECOVERY",
                "reason="..reason..";age="..(report.frame-my_recovery_lock.frame))
            my_recovery_lock=nil
        end
    end

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

    -- RAM possession remains authoritative. Preserve only a short tactical
    -- hypothesis when the same CPU runner stays glued to the loose ball.
    local continuity_cfg=config.CPU_CARRIER_CONTINUITY
    if continuity_cfg.enabled then
        local t=cpu_carrier_continuity
        local reason=nil
        if gs~=0 or not gameplay_active.is_active(gameplay_value) then
            reason="STOPPAGE"
        elseif players.valid_my_base(possession) then
            reason="MY_POSSESSION"
        elseif t and players.valid_cpu_base(possession)
            and possession~=t.base then
            reason="DIFFERENT_CPU"
        elseif t and possession==0 then
            local cx,cy=players.xy(t.base)
            local dist=math.sqrt((cx-bx)^2+(cy-by)^2)
            local age=report.frame-t.last_confirmed
            local ball_step=math.sqrt((bx-t.ball_x)^2+(by-t.ball_y)^2)
            local runner_step=math.sqrt((cx-t.x)^2+(cy-t.y)^2)
            if age>continuity_cfg.max_unowned_frames then
                reason="TIMEOUT"
            elseif dist>continuity_cfg.max_ball_distance then
                reason="SEPARATION"
            elseif ball_step>continuity_cfg.max_ball_step then
                reason="BALL_DISPLACEMENT"
            elseif runner_step>continuity_cfg.max_runner_step then
                reason="RUNNER_DISPLACEMENT"
            else
                if not t.active and age>=1 then
                    t.active=true
                    report:write("CPU_CARRIER_CONTINUITY_START",true,
                        {possession=possession,game_state=gs,my_base=my_base},
                        "OBSERVE_CARRIER","base="..t.base..";distance="..dist
                        ..";age="..age)
                end
                t.x,t.y=cx,cy
                t.ball_x,t.ball_y=bx,by
            end
        end
        if t and reason then
            if t.active then
                report:write("CPU_CARRIER_CONTINUITY_END",true,
                    {possession=possession,game_state=gs,my_base=my_base},
                    "OBSERVE_CARRIER","base="..t.base..";reason="..reason
                    ..";age="..(report.frame-t.last_confirmed))
            end
            cpu_carrier_continuity=nil
        end
        if players.valid_cpu_base(possession)
            and possession~=config.CPU_FIRST then
            local cx,cy=players.xy(possession)
            if t and t.active then
                report:write("CPU_CARRIER_CONTINUITY_END",true,
                    {possession=possession,game_state=gs,my_base=my_base},
                    "OBSERVE_CARRIER","base="..t.base
                    ..";reason=POSSESSION_RECONFIRMED;age="
                    ..(report.frame-t.last_confirmed))
            end
            cpu_carrier_continuity={base=possession,x=cx,y=cy,
                ball_x=bx,ball_y=by,last_confirmed=report.frame,active=false}
        end
    end

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
        if possession~=my_base then
            defensive_exit.reset(); defensive_carrier=nil
            defensive_hold_guard=nil
            defensive_pass_alignment=nil
            defensive_alignment_blocks={}
        end
        corner_kick.reset()
        goal_kick.reset()
        throw_in.reset()
        restart.clear()

        -- Mantem a heuristica temporal aquecida apenas como fallback.
        local fallback_class =
            possession_context.update(possession, bx, by)

        local team_value = team_possession.read()
        local team_kind,team_kind_source,team_kind_conflict =
            team_possession.resolve(team_value,possession)
        local effective_unowned_team=team_kind
        if possession==0 and gk_release_lock then
            effective_unowned_team="CPU"
            team_kind="CPU"
            team_kind_source="CPU_GK_RELEASE_ORIGIN"
        end

        local function attach_live_state(state, source, class)
            -- Centralized handoff: an old MY recovery commitment cannot
            -- survive a higher-priority defensive action or a player switch.
            if my_recovery_lock and state.status~="MY_UNOWNED_RECOVERY"
                and state.status~="MY_UNOWNED_RECOVERY_LOCK" then
                local lock=my_recovery_lock
                local reason=state.status=="PLAYER_SWITCH" and "PLAYER_SWITCH"
                    or "PREEMPTED"
                report:write("MY_RECOVERY_LOCK_END",true,
                    {possession=possession,game_state=gs,my_base=my_base,
                     ball_x=bx,ball_y=by},"OBSERVE_RECOVERY",
                    "reason="..reason..";next_status="..tostring(state.status)
                    ..";age="..(report.frame-lock.frame))
                my_recovery_lock=nil
            end
            state.team_possession = team_value
            state.team_possession_kind = team_kind
            state.team_possession_kind_source = team_kind_source
            state.team_possession_conflict = team_kind_conflict
            state.gk_release_origin_active = possession==0 and gk_release_lock~=nil
            state.gk_release_origin_age = gk_release_lock and (report.frame-gk_release_lock.start) or nil
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
            if decision.button=="R" then long_pass_receiver_selection.request(report.frame) end
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
                    -- Continue a charge before replanning: tactical plans can vary
                    -- while A is held, but the charge must retain direction.
                    if defensive_clear_charge then
                        local ch=defensive_clear_charge
                        local cc=config.CHARGED_DEFENSIVE_CLEARANCE
                        if possession~=ch.carrier or gs~=0 then
                            report:write("DEF_CLEAR_CHARGE_ABORT",true,
                                {possession=possession,game_state=gs,my_base=my_base},
                                "RELEASE_A","reason=OWNER_CHANGED")
                            defensive_clear_charge=nil
                            movement.stop()
                        elseif ch.frames<ch.target_frames then
                            movement.press_direction_button(ch.direction,"A")
                            ch.frames=ch.frames+1
                            local state=make_state(my_base,0,0,
                                "DEF_CLEAR_CHARGING",possession,gs)
                            state.defensive_clear_charge_frames=ch.frames
                            state.defensive_clear_target_frames=ch.target_frames
                            return attach_live_state(state,"DEFENSIVE_TRANSITION","MY_CONTROLLED")
                        else
                            movement.press_direction_button(ch.direction,nil)
                            local cbx,cby=ball.world_xy()
                            local sequence,superseded=defensive_clearance_outcome.start(
                                report.frame,cbx,cby,ch.carrier,ch.frames,
                                field_side.attack_direction(),ch.variant)
                            if superseded then
                                report:write("DEF_CLEAR_OUTCOME_UNRESOLVED",true,
                                    {possession=possession,game_state=gs,my_base=my_base},
                                    "OBSERVE_CLEARANCE",
                                    "reason=SUPERSEDED_BY_NEW_LAUNCH;sequence="
                                    ..superseded.sequence..";age="..superseded.age
                                    ..";charge_frames="..superseded.frames
                                    ..";variant="..tostring(superseded.variant))
                            end
                            long_pass_position_observer.start(report.frame,ch.carrier)
                            long_pass_receiver_selection.start(report.frame,cbx,cby,sequence,ch.carrier)
                            if config.LONG_PASS_AI_ASSIST_EXPERIMENT.enabled then
                                long_pass_ai_lock={start=report.frame,carrier=ch.carrier,
                                    clearance_sequence=sequence,neutral_frames=0}
                                report:write("LONG_PASS_AI_ASSIST_START",true,
                                    {possession=possession,game_state=gs,my_base=my_base},
                                    "OBSERVE_LONG_PASS","clearance_sequence="..sequence)
                            end
                            report:write("DEF_CLEAR_CHARGE_RELEASE",true,
                                {possession=possession,game_state=gs,my_base=my_base},
                                movement.last_command,
                                "frames="..ch.frames..";direction="..ch.direction
                                ..";threat="..tostring(ch.threat)
                                ..";clearance_sequence="..sequence
                                ..";variant="..tostring(ch.variant))
                            defensive_clear_charge=nil
                            local state=make_state(my_base,0,0,
                                "DEF_CLEAR_RELEASE",possession,gs)
                            return attach_live_state(state,"DEFENSIVE_TRANSITION","MY_CONTROLLED")
                        end
                    end
                    if defensive_carrier~=my_base then
                        defensive_carrier=my_base
                        defensive_hold_age=0
                    end
                    defensive_hold_age=defensive_hold_age+1
                    if defensive_hold_guard and defensive_hold_guard.carrier~=my_base then
                        defensive_hold_guard=nil
                    end
                    -- Do not release a defensive pass immediately after a
                    -- rebound recovery. Face the intended cardinal pass lane
                    -- for a few frames first; this is a proxy, not a verified
                    -- sprite-facing memory address.
                    local function align_defensive_pass(plan)
                        local cfg=config.DEFENSIVE_PASS_ALIGNMENT
                        local key=my_base..":"..tostring(plan.receiver)..":"..tostring(plan.direction)
                        local a=defensive_pass_alignment
                        local blocked=defensive_alignment_blocks[key]
                        if blocked and report.frame<blocked then return false end
                        if a and a.key==key and a.blocked_until then
                            defensive_pass_alignment=nil
                            a=nil
                        end
                        if not a or a.key~=key then
                            a={key=key,start=report.frame,confirmed=0}
                            defensive_pass_alignment=a
                            report:write("DEFENSIVE_PASS_ALIGN_START",true,
                                {my_base=my_base,possession=possession,game_state=gs},
                                "OBSERVE_FACING","receiver="..tostring(plan.receiver)
                                ..";direction="..tostring(plan.direction))
                        end
                        local px,py=players.xy(my_base)
                        local ball_x,ball_y=ball.world_xy()
                        local dx,dy=ball_x-px,ball_y-py
                        local along,across
                        if plan.direction=="Right" then along,across=dx,math.abs(dy)
                        elseif plan.direction=="Left" then along,across=-dx,math.abs(dy)
                        elseif plan.direction=="Down" then along,across=dy,math.abs(dx)
                        elseif plan.direction=="Up" then along,across=-dy,math.abs(dx)
                        else along,across=0,math.huge end
                        local facing=along>=cfg.min_forward_offset
                            and along<=cfg.max_ball_offset
                            and across<=cfg.max_lateral_offset
                            and along>=across*cfg.dominance_ratio
                        a.confirmed=facing and a.confirmed+1 or 0
                        if a.confirmed>=cfg.confirm_frames then
                            report:write("PASS_FACING_CONFIRMED",true,
                                {my_base=my_base,possession=possession,game_state=gs},
                                "OBSERVE_FACING","direction="..plan.direction
                                ..";dx="..dx..";dy="..dy
                                ..";age="..(report.frame-a.start))
                            defensive_pass_alignment=nil
                            return true
                        end
                        local age=report.frame-a.start
                        if age>=cfg.max_window_frames then
                            a.blocked_until=report.frame+cfg.retry_block_frames
                            defensive_alignment_blocks[key]=a.blocked_until
                            report:write("PASS_FACING_ABORT",true,
                                {my_base=my_base,possession=possession,game_state=gs},
                                "OBSERVE_FACING","direction="..plan.direction
                                ..";dx="..dx..";dy="..dy..";age="..age)
                            return false
                        end
                        movement.press_direction_button(plan.direction,nil)
                        local state=make_state(my_base,0,0,
                            "DEFENSIVE_PASS_ALIGN",possession,gs)
                        state.defensive_recovery=true
                        state.forward_pass_receiver=plan.receiver
                        state.forward_pass_direction=plan.direction
                        state.forward_pass_alignment_frames=age
                        return attach_live_state(state,"PASS_ALIGNMENT","MY_CONTROLLED")
                    end
                                        -- No forward dribble or Y dash while holding the defensive line.
                    local outlet=forward_pass.plan(my_base)
                    local outlet_ready=false
                    if outlet then
                        local waiting=align_defensive_pass(outlet)
                        if type(waiting)=="table" then return waiting end
                        outlet_ready=waiting==true
                    end
                    if outlet_ready and forward_pass.fire(outlet,movement) then
                        defensive_exit.on_pass()
                        if defensive_pass_pending then
                            report:write("DEFENSIVE_PASS_UNRESOLVED",true,
                                {possession=possession,game_state=gs,my_base=my_base},
                                "OBSERVE_PASS_OUTCOME",
                                "sequence="..defensive_pass_pending.sequence
                                ..";reason=SUPERSEDED")
                        end
                        defensive_pass_sequence=defensive_pass_sequence+1
                        defensive_pass_pending={
                            sequence=defensive_pass_sequence,
                            frame=report.frame,passer=my_base,
                            receiver=outlet.receiver,direction=outlet.direction}
                        report:write("DEFENSIVE_PASS_SENT",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            movement.last_command,
                            "sequence="..defensive_pass_sequence
                            ..";passer="..my_base
                            ..";expected_receiver="..tostring(outlet.receiver)
                            ..";direction="..tostring(outlet.direction))
                        defensive_pass_alignment=nil
                        defensive_alignment_blocks={}
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
                    if exit.mode=="HOLD" and exit.reason=="NO_SAFE_SPACE" then
                        if not defensive_hold_guard then
                            defensive_hold_guard={carrier=my_base,start=report.frame}
                        elseif report.frame-defensive_hold_guard.start==
                            config.DEFENSIVE_EXIT.guard_stall_log_frames then
                            report:write("DEFENSIVE_HOLD_STALL",true,
                                {possession=possession,game_state=gs,my_base=my_base},
                                "OBSERVE_HOLD","reason=NO_SAFE_SPACE;threat="
                                ..tostring(exit.threat))
                        end
                    elseif exit.mode~="HOLD" then
                        defensive_hold_guard=nil
                    end
                    local exit_ready=false
                    if exit.mode=="PASS" then
                        local waiting=align_defensive_pass(exit)
                        if type(waiting)=="table" then return waiting end
                        exit_ready=waiting==true
                    end
                    if exit_ready and forward_pass.fire(exit,movement) then
                        defensive_exit.on_pass()
                        if defensive_pass_pending then
                            report:write("DEFENSIVE_PASS_UNRESOLVED",true,
                                {possession=possession,game_state=gs,my_base=my_base},
                                "OBSERVE_PASS_OUTCOME",
                                "sequence="..defensive_pass_pending.sequence
                                ..";reason=SUPERSEDED")
                        end
                        defensive_pass_sequence=defensive_pass_sequence+1
                        defensive_pass_pending={
                            sequence=defensive_pass_sequence,
                            frame=report.frame,passer=my_base,
                            receiver=exit.receiver,direction=exit.direction}
                        report:write("DEFENSIVE_PASS_SENT",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            movement.last_command,
                            "sequence="..defensive_pass_sequence
                            ..";passer="..my_base
                            ..";expected_receiver="..tostring(exit.receiver)
                            ..";direction="..tostring(exit.direction))
                        defensive_pass_alignment=nil
                        defensive_alignment_blocks={}
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
                        state.forward_pass_forward=exit.forward
                        state.forward_pass_lateral=exit.lateral
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
                        local charge_cfg=config.CHARGED_DEFENSIVE_CLEARANCE
                        local charging=exit.button=="A"
                            and (exit.direction=="Left" or exit.direction=="Right")
                        if charging then
                            local urgent=exit.threat and exit.threat<=charge_cfg.urgent_radius
                            local frames=urgent and charge_cfg.urgent_frames or charge_cfg.normal_frames
                            local variant=urgent and "URGENT_FIXED" or "NORMAL_FIXED"
                            if not urgent and charge_cfg.calibration_enabled then
                                clearance_calibration_index=clearance_calibration_index+1
                                local variants=charge_cfg.calibration_frames
                                local slot=(clearance_calibration_index-1)%#variants+1
                                frames=variants[slot]
                                variant="CALIBRATION_"..tostring(frames)
                            end
                            defensive_clear_charge={carrier=my_base,
                                direction=exit.direction,frames=1,target_frames=frames,
                                threat=exit.threat,variant=variant}
                        end
                        movement.press_direction_button(exit.direction,exit.button)
                        if charging then
                            report:write("DEF_CLEAR_CHARGE_START",true,
                                {possession=possession,game_state=gs,my_base=my_base},
                                movement.last_command,
                                "target_frames="..defensive_clear_charge.target_frames
                                ..";direction="..exit.direction
                                ..";threat="..tostring(exit.threat)
                                ..";variant="..defensive_clear_charge.variant)
                        end
                        local cbx,cby=ball.world_xy()
                        defensive_escape_pending={carrier=my_base,start=report.frame,
                            x=cbx,y=cby,attempt=exit.clear_attempts or 1}
                        report:write("DEFENSIVE_HOLD_ESCAPE",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            movement.last_command,"reason="..tostring(exit.reason)
                            ..";threat="..tostring(exit.threat)
                            ..";attempt="..tostring(exit.clear_attempts))
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
                if midfield_rebuild then
                    local dir_now=field_side.attack_direction()
                    local x_now=players.xy(my_base)
                    if report.frame-midfield_rebuild.start>=
                        config.FINAL_THIRD_RESET.rebuild_window_frames then
                        report:write("MIDFIELD_REBUILD_OUTCOME",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "REBUILD","result=TIMEOUT")
                        midfield_rebuild=nil
                    elseif dir_now==midfield_rebuild.dir
                        and (x_now-midfield_rebuild.boundary)*dir_now>=0 then
                        report:write("MIDFIELD_REBUILD_OUTCOME",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "REBUILD","result=RETURNED_TO_FINAL_THIRD")
                        midfield_rebuild=nil
                    end
                end
                local shot = shoot.plan(my_base)
                local shoot_diag = shoot.last_diagnostic
                if shot and shoot.fire(shot, movement) then
                    if midfield_rebuild then
                        report:write("MIDFIELD_REBUILD_OUTCOME",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "REBUILD","result=SHOT")
                        midfield_rebuild=nil
                    end
                    if final_third_decision then
                        report:write("FINAL_THIRD_DECISION",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "SHOT","reason=VALID_SHOOT_WINDOW")
                        final_third_decision=nil
                    end
                    if final_third_lock then
                        report:write("REPOSITION_SUCCESS",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "OBSERVE_REPOSITION","reason=SHOT_AFTER_REPOSITION")
                        final_third_lock=nil
                    end
                    local state = make_state(
                        my_base, 0, 0, "ATTACK_SHOOT", possession, gs
                    )
                    state.shot_reason = shoot_diag and shoot_diag.reason
                    state.shot_fired = true
                    state.shot_variant = shot.variant
                    state.shot_button = shot.button
                    report:write("ATTACK_SHOOT_"..shot.variant,true,state,
                        movement.last_command,
                        "distance="..tostring(shot.distance)
                        ..";angle="..tostring(shot.shot_angle)
                        ..";lateral="..tostring(shot.lateral_offset)
                        ..";carrier="..tostring(my_base))
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
                    if midfield_rebuild then
                        report:write("MIDFIELD_REBUILD_PASS",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "REBUILD","intent="..tostring(pass.intent))
                    end
                    if final_third_decision then
                        report:write("FINAL_THIRD_DECISION",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "PASS","reason=SAFE_FORWARD_OUTLET")
                        final_third_decision=nil
                    end
                    if final_third_lock then
                        report:write("REPOSITION_ABORT",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "OBSERVE_REPOSITION","reason=PASS_OPTION")
                        final_third_lock=nil
                    end
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
                -- Maintain a short, fixed reposition target; abandon if the
                -- angle fails to improve or the run loses too much ground.
                local rl=config.FINAL_THIRD_REPOSITION_LOCK
                local px_now,py_now=players.xy(my_base)
                local dir=field_side.attack_direction()
                local angle=shoot_diag and shoot_diag.shot_angle
                if final_third_lock and final_third_lock.carrier~=my_base then
                    final_third_lock=nil
                end
                if final_third_lock then
                    local lock=final_third_lock
                    local age=report.frame-lock.start
                    local retreat=(lock.start_x-px_now)*lock.direction
                    local gain=(lock.start_angle or 0)-(angle or lock.start_angle or 0)
                    local dist=math.sqrt((lock.target_x-px_now)^2+(lock.target_y-py_now)^2)
                    local reason=nil
                    if not poor_angle then reason="ANGLE_RESOLVED"
                    elseif age>=rl.max_frames then reason="TIMEOUT"
                    elseif retreat>rl.max_retreat then reason="EXCESS_RETREAT"
                    elseif age>=rl.progress_check_frames and gain<rl.min_angle_gain then
                        reason="NO_ANGLE_GAIN"
                    elseif dist<=rl.arrive_distance then reason="TARGET_REACHED" end
                    if reason then
                        report:write(reason=="ANGLE_RESOLVED" and "REPOSITION_SUCCESS"
                            or "REPOSITION_ABORT",true,
                            {status="ATTACK_FINAL_THIRD_REPOSITION",
                             possession=possession,game_state=gs,my_base=my_base},
                            "OBSERVE_REPOSITION",
                            "reason="..reason..";age="..age
                            ..";angle_gain="..gain..";retreat="..retreat
                            ..";target_x="..lock.target_x..";target_y="..lock.target_y)
                        final_third_lock=nil
                        if reason~="ANGLE_RESOLVED" then
                            local cfg=config.FINAL_THIRD_RESET
                            if report.frame-final_third_failures.last>cfg.stall_window_frames then
                                final_third_failures.count=0
                            end
                            final_third_failures.count=final_third_failures.count+1
                            final_third_failures.last=report.frame
                        else
                            final_third_failures.count=0
                        end
                        final_third_decision={carrier=my_base,start=report.frame,
                            reason=reason}
                        report:write("FINAL_THIRD_DECISION_START",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "OBSERVE_FINAL_THIRD","reason="..reason)
                        final_third_cooldown_until=report.frame+rl.cooldown_frames
                    else
                        attack={mode="FINAL_THIRD_REPOSITION",
                            target_x=lock.target_x,target_y=lock.target_y,
                            direction=dir,
                            goal_target_x=lock.goal_x,goal_target_y=lock.goal_y,
                            goal_distance=shoot_diag and shoot_diag.distance,
                            lateral_offset=shoot_diag and shoot_diag.lateral_offset}
                    end
                end
                if not final_third_lock and not final_third_reset and attack
                    and attack.mode=="FINAL_THIRD_REPOSITION"
                    and poor_angle and report.frame>=final_third_cooldown_until
                    and (not midfield_rebuild or report.frame-midfield_rebuild.start>
                        config.FINAL_THIRD_RESET.reposition_block_frames)
                    and (dir==1 or dir==-1) then
                    local retreat=(px_now-attack.target_x)*dir
                    if retreat>rl.max_retreat then
                        attack.target_x=px_now-dir*rl.max_retreat
                    end
                    final_third_lock={carrier=my_base,start=report.frame,
                        start_x=px_now,start_angle=angle, direction=dir,
                        target_x=attack.target_x,target_y=attack.target_y,
                        goal_x=attack.goal_target_x,goal_y=attack.goal_target_y}
                    report:write("REPOSITION_START",true,
                        {status="ATTACK_FINAL_THIRD_REPOSITION",
                         possession=possession,game_state=gs,my_base=my_base},
                        "OBSERVE_REPOSITION",
                        "angle="..tostring(angle)
                        ..";target_x="..tostring(attack.target_x)
                        ..";target_y="..tostring(attack.target_y))
                elseif not final_third_lock and attack
                    and attack.mode=="FINAL_THIRD_REPOSITION" then
                    -- Following a failed attempt, avoid repeating the same
                    -- reverse movement; allow the ordinary guarded advance.
                    attack.mode="ADVANCE"
                    attack.target_x=px_now+dir*config.FINAL_THIRD_REPOSITION_LOCK.max_retreat
                    attack.target_y=py_now
                end

                if final_third_decision and not final_third_reset then
                    local decision=final_third_decision
                    local cfg=config.FINAL_THIRD_ATTACK_DECISION
                    local elapsed=report.frame-decision.start
                    if elapsed>=cfg.window_frames then
                        report:write("FINAL_THIRD_DECISION",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "END","reason=WINDOW_EXPIRED;elapsed="..elapsed)
                        final_third_decision=nil
                    elseif attack and (attack.mode=="FINAL_THIRD_REPOSITION"
                        or attack.mode=="LANE") then
                        -- Shoot/pass were already evaluated above this branch.
                        -- Avoid another backwards lane cycle during the window.
                        local dir=field_side.attack_direction()
                        if (dir==1 or dir==-1) and elapsed<cfg.max_advance_frames then
                            attack.mode="ADVANCE"
                            attack.target_x=px_now+dir*cfg.advance_step
                            attack.target_y=py_now
                        else
                            attack.mode="ADVANCE"
                            attack.target_x=px_now
                            attack.target_y=py_now
                        end
                    end
                end

                -- Only reset after repeated failed reposition attempts.
                -- Shoot and safe forward pass are evaluated before this block.
                local reset_cfg=config.FINAL_THIRD_RESET
                if final_third_reset and final_third_reset.carrier==my_base then
                    local r=final_third_reset
                    local age=report.frame-r.start
                    local progress=(r.start_x-px_now)*r.dir
                    local remaining=math.sqrt((r.target_x-px_now)^2
                        +(r.target_y-py_now)^2)
                    local finish=nil
                    -- Every progress window must move meaningfully toward midfield.
                    if age-r.progress_checked_at>=reset_cfg.progress_window_frames then
                        local window_gain=(r.progress_x-px_now)*r.dir
                        if window_gain<reset_cfg.min_window_progress then
                            finish="STALLED_PROGRESS"
                        else
                            r.progress_x=px_now
                            r.progress_checked_at=age
                        end
                    end
                    local nearest_cpu=math.huge
                    players.each_cpu(function(base)
                        local ex,ey=players.xy(base)
                        local d=math.sqrt((ex-px_now)^2+(ey-py_now)^2)
                        if d<nearest_cpu then nearest_cpu=d end
                    end)
                    if nearest_cpu<=reset_cfg.pressure_abort_radius then
                        finish="PRESSURE_ABORT"
                    end
                    if (px_now-r.boundary)*r.dir<=-reset_cfg.midfield_margin then
                        finish="MIDFIELD_REACHED"
                    elseif remaining<=reset_cfg.arrive_distance then
                        finish="TARGET_REACHED"
                    elseif not finish and age>=r.deadline then
                        finish="TIMEOUT"
                    end
                    if finish then
                        if finish=="TARGET_REACHED" and
                            (px_now-r.boundary)*r.dir>-reset_cfg.midfield_margin then
                            finish="TARGET_BEFORE_MIDFIELD"
                        end
                        report:write(finish=="MIDFIELD_REACHED" and
                            "FINAL_THIRD_RESET_COMPLETE" or "FINAL_THIRD_RESET_ABORT",
                            true,{possession=possession,game_state=gs,my_base=my_base},
                            "RESET","reason="..finish..";age="..age
                            ..";retreat="..progress..";deadline="..r.deadline
                            ..";remaining="..remaining..";nearest_cpu="..nearest_cpu)
                        if finish=="MIDFIELD_REACHED" then
                            midfield_rebuild={start=report.frame,dir=r.dir,
                                boundary=r.boundary}
                            report:write("MIDFIELD_REBUILD_START",true,
                                {possession=possession,game_state=gs,my_base=my_base},
                                "REBUILD","boundary="..r.boundary)
                        end
                        final_third_reset=nil
                        final_third_failures.count=0
                        final_third_reset_cooldown=report.frame+reset_cfg.cooldown_frames
                        live_attack.reset()
                    else
                        attack={mode="FINAL_THIRD_RESET",
                            target_x=r.target_x,target_y=r.target_y,
                            direction=r.dir}
                    end
                elseif not final_third_reset
                    and final_third_failures.count>=reset_cfg.failed_attempts
                    and report.frame>=final_third_reset_cooldown
                    and not midfield_rebuild
                    and (dir==1 or dir==-1) and shoot_diag
                    and shoot_diag.distance
                    and shoot_diag.distance<=reset_cfg.min_goal_distance then
                    local field_len=mem.u16(config.ADDR.field_length)
                    local center=mem.u16(config.ADDR.center_field_x)
                    local valid_geometry=field_len>=500 and field_len<=4000
                        and center>=100
                    local boundary=valid_geometry
                        and (center+dir*field_len/6) or nil
                    -- Never claim a midfield reset when field geometry is invalid.
                    local target_x=boundary and
                        (boundary-dir*reset_cfg.midfield_margin) or nil
                    local target_y=py_now
                    local guarded=target_x and
                        field_boundary.correct(px_now,py_now,target_x,target_y)
                    if guarded and (px_now-guarded.x)*dir>=reset_cfg.min_retreat_progress then
                        local reset_distance=(px_now-guarded.x)*dir
                        local deadline=math.min(reset_cfg.max_frames,
                            math.max(reset_cfg.min_deadline_frames,
                                math.ceil(reset_distance/reset_cfg.estimated_units_per_frame)
                                +reset_cfg.deadline_slack_frames))
                        final_third_reset={carrier=my_base,start=report.frame,
                            start_x=px_now,dir=dir,target_x=guarded.x,
                            target_y=guarded.y,boundary=boundary,
                            deadline=deadline,progress_x=px_now,progress_checked_at=0}
                        final_third_lock=nil
                        final_third_decision=nil
                        attack={mode="FINAL_THIRD_RESET",
                            target_x=guarded.x,target_y=guarded.y,
                            direction=dir}
                        report:write("FINAL_THIRD_RESET_START",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            "RESET","failures="..final_third_failures.count
                            ..";target_x="..guarded.x..";target_y="..guarded.y
                            ..";deadline="..deadline..";distance="..reset_distance)
                    end
                end

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
                        attack.mode == "FINAL_THIRD_RESET" and "ATTACK_FINAL_THIRD_RESET"
                        or (attack.mode == "FINAL_THIRD_REPOSITION"
                        and "ATTACK_FINAL_THIRD_REPOSITION"
                        or (attack.mode == "LANE" and "ATTACK_LANE" or "ATTACK_ADVANCE"))

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
                    local action,phase=gk_distribution.next_action(plan)
                    local fired=action~=nil
                    if fired then
                        if action.direction then
                            movement.press_direction_button(action.direction,action.button)
                        else
                            movement.press_button(action.button)
                        end
                        gk_distribution.mark_fired(action,phase)
                        if phase~="HOLD" then
                        report:write("GK_DISTRIBUTION_ATTEMPT",true,
                            {possession=possession,game_state=gs,my_base=my_base},
                            movement.last_command,
                            "attempt="..gk_distribution.attempts
                            ..";mode="..tostring(action.mode)
                            ..";reason="..tostring(action.decision_reason)
                            ..";held_frames="..gk_distribution.held_frames
                            ..";press_frames="..tostring(action.press_frames)
                            ..";direction="..tostring(action.direction))
                        end
                    else
                        movement.stop()
                    end

                    local state = make_state(
                        my_base, 0, 0,
                        fired and "GK_DISTRIBUTION_ATTEMPT"
                            or phase=="EXHAUSTED" and "GK_DISTRIBUTION_EXHAUSTED"
                            or "GK_DISTRIBUTION_WAIT", possession, gs
                    )
                    state.gk_dist_fired = fired
                    state.gk_dist_phase=phase
                    state.gk_dist_press_remaining=gk_distribution.press_remaining
                    state.gk_dist_attempts = gk_distribution.attempts
                    state.gk_dist_recovery_cycles=gk_distribution.recovery_cycles
                    state.gk_dist_held_frames = gk_distribution.held_frames
                    state.gk_dist_lane_clearance = plan.lane_clearance
                    state.gk_dist_decision_reason = plan.decision_reason
                    state.gk_dist_mode = action and action.mode or plan.mode
                    state.gk_dist_direction = action and action.direction
                    state.gk_dist_button = action and action.button or plan.button
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
            -- A confirmed controlled outfielder must not become permanently
            -- idle merely because the normal lane planner returned nil.
            if possession==my_base and my_base~=config.MY_FIRST then
                local px,py=players.xy(my_base)
                local gx,gy=players.xy(config.CPU_FIRST)
                local dir=field_side.attack_direction()
                local source="FIELD_SIDE"
                if dir~=1 and dir~=-1 then
                    -- Only infer attacking direction if goals are clearly
                    -- separated; never use an arbitrary sign near midfield.
                    if math.abs(gx-px)>=config.POSSESSION_FALLBACK.min_goal_separation then
                        dir=gx>px and 1 or -1
                        source="OPPONENT_GK"
                    end
                end
                if dir==1 or dir==-1 then
                    local cfg=config.POSSESSION_FALLBACK
                    local tx=px+dir*cfg.forward_step
                    local lateral=gy-py
                    local ty=py+math.max(-cfg.lateral_step,
                        math.min(cfg.lateral_step,lateral))
                    local guarded=field_boundary.correct(px,py,tx,ty)
                    local dx,dy=guarded.x-px,guarded.y-py
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,
                        "POSSESSION_SAFE_ADVANCE",possession,gs)
                    state.attack_target_x=guarded.x
                    state.attack_target_y=guarded.y
                    state.report_detail="source="..source
                    return attach_live_state(state,"POSSESSION_FALLBACK","MY_CONTROLLED")
                end
                movement.stop()
                local state=make_state(my_base,0,0,
                    "POSSESSION_WAIT_DIRECTION",possession,gs)
                state.report_detail="reason=attacking_direction_unavailable"
                return attach_live_state(state,"POSSESSION_FALLBACK","MY_CONTROLLED")
            end

            movement.stop()
            return attach_live_state(
                make_state(my_base,0,0,
                    possession==my_base and "GK_DISTRIBUTION_WAIT"
                    or "MY_TEAMMATE_POSSESSION",possession,gs),
                "PLAYER_POSSESSION","MY_CONTROLLED"
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

            -- Before the shot: cover a completely exposed carrier-to-goal
            -- corridor. Count all outfield defenders, not only the selected one.
            -- Do not request R: its destination is not deterministic.
            do
                local guard=config.PRE_SHOT_DEFENSIVE_COVER
                local cx,cy=players.xy(possession)
                local gx,gy=players.xy(config.MY_FIRST)
                local vx,vy=gx-cx,gy-cy
                local lane_length=math.sqrt(vx*vx+vy*vy)
                if guard.enabled and players.valid_my_base(my_base)
                    and my_base~=config.MY_FIRST and lane_length>=1
                    and lane_length<=guard.activation_radius then
                    local covered=0
                    local nearest=math.huge
                    local selected_lateral=math.huge
                    local selected_along=nil
                    players.each_my(function(base)
                        if base~=config.MY_FIRST then
                            local dx,dy=players.xy(base)
                            local rx,ry=dx-cx,dy-cy
                            local along=(rx*vx+ry*vy)/lane_length
                            local lateral=math.abs(rx*vy-ry*vx)/lane_length
                            local near=math.sqrt(rx*rx+ry*ry)
                            if near<nearest then nearest=near end
                            if along>guard.min_along and along<lane_length
                                and lateral<=guard.lane_width then
                                covered=covered+1
                            end
                            if base==my_base then
                                selected_lateral=lateral
                                selected_along=along
                            end
                        end
                    end)
                    local open=covered==0
                    if open and lane_length<=guard.emergency_radius then
                        local px,py=players.xy(my_base)
                        local offset=math.min(guard.cover_offset,
                            lane_length*guard.max_fraction)
                        local tx=cx+vx/lane_length*offset
                        local ty=cy+vy/lane_length*offset
                        local dx,dy=tx-px,ty-py
                        movement.move_toward(dx,dy)
                        local state=make_state(my_base,dx,dy,
                            "PRE_SHOT_DEFENSIVE_COVER",possession,gs)
                        state.live_carrier=possession
                        state.live_target_x=tx
                        state.live_target_y=ty
                        report:write("PRE_SHOT_COVER_UNCOVERED",true,state,
                            movement.last_command,
                            "carrier="..possession..";cover_count="..covered
                            ..";nearest_defender="..nearest
                            ..";selected_lateral="..selected_lateral
                            ..";selected_along="..tostring(selected_along)
                            ..";goal_distance="..lane_length)
                        return attach_live_state(state,"PRE_SHOT_COVER",
                            "CPU_CONTROLLED")
                    end
                end
            end

            -- A free CPU carrier near our goal outranks marking a secondary
            -- attacker. Occupy the carrier-to-GK lane before chasing away.
            -- Keep the current outfielder: R may select an arbitrary player.
            local primary_lane=live_defense.shot_lane(possession,my_base)
            if primary_lane and primary_lane.exposed then
                local cx,cy=players.xy(possession)
                local px,py=players.xy(my_base)
                local carrier_distance=math.sqrt((cx-px)^2+(cy-py)^2)
                if carrier_distance>config.ACTIVE_TACKLE.max_distance then
                    local guarded=field_boundary.correct(px,py,
                        primary_lane.target_x,primary_lane.target_y)
                    local dx,dy=guarded.x-px,guarded.y-py
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,
                        "PRIMARY_CARRIER_GOAL_COVER",possession,gs)
                    state.live_carrier=possession
                    state.live_target_x=guarded.x
                    state.live_target_y=guarded.y
                    state.shot_lane_exposed=true
                    state.shot_lane_lateral=primary_lane.lateral
                    state.shot_lane_along=primary_lane.along
                    state.tackle_distance=carrier_distance
                    return attach_live_state(state,"GOAL_SIDE_COVER","CPU_CONTROLLED")
                end
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

        -- Early commitment to an aerial contest, ahead of ground rebound
        -- arbitration. Never assume R selects a particular defender.
        do
            local ac=config.AERIAL_CONTEST_LOCK
            local valid=possession==0 and gs==0
                and players.valid_my_base(my_base)
                and my_base~=config.MY_FIRST
            local height=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
            local gx,gy=players.xy(config.MY_FIRST)
            local goal_dist=math.sqrt((bx-gx)^2+(by-gy)^2)
            local px,py=nil,nil
            local dist=math.huge
            if valid then
                px,py=players.xy(my_base)
                dist=math.sqrt((bx-px)^2+(by-py)^2)
            end
            local active=valid and height>=ac.min_height
                and height<=ac.max_height
                and goal_dist<=ac.goal_radius
                and dist<=ac.approach_distance
            if aerial_contest_lock then
                local lock=aerial_contest_lock
                local reason=nil
                if not active then reason="LOST_AERIAL_WINDOW"
                elseif lock.base~=my_base then reason="CONTROL_CHANGED"
                elseif report.frame-lock.start>=ac.max_frames then reason="TIMEOUT"
                end
                if reason then
                    report:write("AERIAL_CONTEST_LOCK_END",true,
                        {possession=possession,game_state=gs,my_base=my_base},
                        "OBSERVE_AERIAL","reason="..reason
                        ..";base="..lock.base
                        ..";age="..(report.frame-lock.start))
                    aerial_contest_lock=nil
                end
            end
            if active and not aerial_contest_lock then
                aerial_contest_lock={base=my_base,start=report.frame}
                report:write("AERIAL_CONTEST_LOCK_START",true,
                    {possession=possession,game_state=gs,my_base=my_base},
                    "OBSERVE_AERIAL","base="..my_base..";distance="..dist
                    ..";height="..height)
            end
            if active and aerial_contest_lock
                and aerial_contest_lock.base==my_base
                and dist>config.DEFENSIVE_HEADER.contact_distance then
                local dx,dy=bx-px,by-py
                -- Experimental: neutral input permits the game's own
                -- player-assist movement (if enabled in match settings).
                if ac.ai_assist_enabled then movement.stop()
                else movement.move_toward(dx,dy) end
                local state=make_state(my_base,dx,dy,
                    ac.ai_assist_enabled and "AERIAL_AI_ASSIST"
                    or "AERIAL_CONTEST_APPROACH",possession,gs)
                state.header_height=height
                state.header_distance=dist
                state.aerial_ai_assist=ac.ai_assist_enabled
                return attach_live_state(state,"AERIAL_CONTEST","MY_UNOWNED_BALL")
            end
        end

        -- Near-contact defensive heading on a descending cross.
        -- X is also SHOOT: only issue it for a free aerial ball next to a
        -- controlled outfielder inside our defensive goalkeeper radius.
        -- The observation-only header window is not itself a button command.
        if possession==0 and players.valid_my_base(my_base)
            and my_base~=config.MY_FIRST then
            local hc=config.DEFENSIVE_HEADER
            local gx,gy=players.xy(config.MY_FIRST)
            local px,py=players.xy(my_base)
            local height=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
            local dist=math.sqrt((bx-px)^2+(by-py)^2)
            local goal_dist=math.sqrt((bx-gx)^2+(by-gy)^2)
            local descending=header_last_height~=nil
                and height<=header_last_height
            header_last_height=height
            if goal_dist<=hc.goal_radius
                and height>=hc.min_height and height<=hc.max_height
                and dist<=hc.contact_distance and descending
                and report.frame-header_last_frame>=hc.cooldown_frames then
                local dx,dy=bx-px,by-py
                local attack_dir=field_side.attack_direction()
                local header_mode="EMERGENCY_CONTACT"
                local heading="BALL_APPROACH"
                -- Near contact, prefer clearing toward the opposing half.
                -- Farther away, preserve contact probability by approaching the ball.
                if attack_dir~=0 and dist<=hc.forward_contact_distance then
                    heading=attack_dir==1 and "Right" or "Left"
                    movement.press_direction_button(heading,"X")
                    header_mode="FORWARD_CLEAR"
                else
                    movement.move_toward_button(dx,dy,"X")
                end
                header_last_frame=report.frame
                defensive_header_pending={frame=report.frame,base=my_base,
                    x=bx,y=by,height=height,observed_unowned=false}
                local state=make_state(my_base,dx,dy,
                    "DEFENSIVE_HEADER_ATTEMPT",possession,gs)
                state.header_height=height
                state.header_distance=dist
                state.header_goal_distance=goal_dist
                state.header_mode=header_mode
                state.header_heading=heading
                report:write("DEFENSIVE_HEADER_ATTEMPT",true,state,
                    movement.last_command,
                    "height="..height..";distance="..dist
                    ..";goal_distance="..goal_dist
                    ..";controlled_base="..my_base
                    ..";mode="..header_mode
                    ..";heading="..heading
                    ..";attack_dir="..attack_dir
                    ..";ball_dx="..dx..";ball_dy="..dy)
                return attach_live_state(state,"AERIAL_CLEARANCE_ATTEMPT",
                    effective_unowned_team=="CPU"
                    and "CPU_UNOWNED_BALL" or "MY_UNOWNED_BALL")
            end
        else
            header_last_height=nil
        end

        -- Experimental offensive aerial contact. Positioning may be assisted by
        -- the game, but neutral input cannot intentionally win a header.
        -- Never override defensive heading within the goalkeeper danger radius.
        if config.AERIAL_CONTACT_DECISION.enabled and possession==0
            and gs==0 and players.valid_my_base(my_base)
            and my_base~=config.MY_FIRST then
            local cc=config.AERIAL_CONTACT_DECISION
            local h=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
            local px,py=players.xy(my_base)
            local gx,gy=players.xy(config.MY_FIRST)
            local distance=math.sqrt((bx-px)^2+(by-py)^2)
            local own_goal_distance=math.sqrt((bx-gx)^2+(by-gy)^2)
            local dir=field_side.attack_direction()
            local field_length=mem.u16(config.ADDR.field_length)
            local field_center=mem.u16(config.ADDR.center_field_x)
            local opp_goal_x=field_center+dir*field_length/2
            local opp_goal_distance=math.sqrt((bx-opp_goal_x)^2+(by-gy)^2)
            local descending=aerial_contact_previous_height~=nil
                and h<=aerial_contact_previous_height
            aerial_contact_previous_height=h
            local ng=config.AERIAL_NATURAL_RECEPTION_GUARD
            -- Only trust this guard away from our goal; emergency headers above
            -- retain priority. Track a single observed aerial opportunity.
            if aerial_contact_attempt_lock then
                local lock=aerial_contact_attempt_lock
                if possession~=0 or gs~=0 or h<ng.reset_height
                    or report.frame-lock.frame>=ng.max_attempt_lock_frames then
                    aerial_contact_attempt_lock=nil
                end
            end
            local threat=math.huge
            players.each_cpu(function(cpu)
                local cx,cy=players.xy(cpu)
                local d=math.sqrt((cx-px)^2+(cy-py)^2)
                if d<threat then threat=d end
            end)
            -- A safe flight is not automatically a header opportunity.
            -- Approach the ball before its low reception window; avoid A/X.
            local safe_flight=ng.enabled and descending
                and h>=ng.min_height and h<=ng.approach_max_height
                and distance<=ng.approach_distance
                and threat>=ng.min_cpu_clearance
                and own_goal_distance>config.DEFENSIVE_HEADER.goal_radius
            local natural=safe_flight and h<=ng.max_height
                and distance<=ng.reception_distance
            if safe_flight then
                if not natural_reception_pending then
                    natural_reception_pending={frame=report.frame,base=my_base}
                    report:write("NATURAL_RECEPTION_ALLOWED",true,
                        {possession=possession,game_state=gs,my_base=my_base},
                        "OBSERVE_RECEPTION",
                        "height="..h..";distance="..distance
                        ..";cpu_clearance="..threat)
                end
                local dx,dy=bx-px,by-py
                local approaching=distance>ng.stop_distance
                if approaching then
                    movement.move_toward(dx,dy)
                else
                    movement.stop()
                end
                local state=make_state(my_base,dx,dy,
                    approaching and "AERIAL_NATURAL_APPROACH"
                        or "AERIAL_NATURAL_RECEPTION",possession,gs)
                if report.frame%ng.telemetry_every_frames==0 then
                    report:write("AERIAL_RECEPTION_DECISION",true,state,
                        movement.last_command,
                        "decision=NATURAL;reason=SAFE_DESCENDING"
                        ..";height="..h..";distance="..distance
                        ..";cpu_clearance="..threat
                        ..";phase="..(approaching and "APPROACH" or "WAIT"))
                end
                return attach_live_state(state,"NATURAL_RECEPTION","MY_UNOWNED_BALL")
            end
            if dir~=0 and field_length>=500 and field_length<=4000
                and own_goal_distance>config.DEFENSIVE_HEADER.goal_radius
                and h>=cc.min_height and h<=cc.max_height
                and distance<=cc.contact_distance and descending
                and (not ng.enabled or threat<ng.min_cpu_clearance
                    or opp_goal_distance<=cc.shot_goal_radius)
                and not aerial_contact_attempt_lock
                and report.frame-aerial_contact_last_frame>=cc.cooldown_frames then
                local shot=opp_goal_distance<=cc.shot_goal_radius
                local button=shot and "X" or "A"
                -- Offensive header: X attempts goal, A attempts continuation.
                -- No directional override while the game's positioning assists.
                movement.press_button(button)
                aerial_contact_last_frame=report.frame
                aerial_contact_attempt_lock={frame=report.frame,base=my_base}
                local state=make_state(my_base,0,0,
                    shot and "AERIAL_SHOT_ATTEMPT" or "AERIAL_PASS_ATTEMPT",
                    possession,gs)
                state.header_height=h
                state.header_distance=distance
                report:write("AERIAL_CONTACT_DECISION",true,state,
                    movement.last_command,
                    "button="..button..";height="..h
                    ..";distance="..distance
                    ..";own_goal_distance="..own_goal_distance
                    ..";opp_goal_distance="..opp_goal_distance
                    ..";contact_confirmed=false;reason="
                    ..(shot and "GOAL_FINISH" or "CONTESTED_AERIAL"))
                return attach_live_state(state,"AERIAL_CONTACT_ATTEMPT",
                    "MY_UNOWNED_BALL")
            end
        else
            aerial_contact_previous_height=nil
        end

        -- Experimental long-clearance positioning: let the game guide the
        -- selected receiver where safe. Contact decisions above retain priority.
        if long_pass_ai_lock then
            local lc=config.LONG_PASS_AI_ASSIST_EXPERIMENT
            local lock=long_pass_ai_lock
            local age=report.frame-lock.start
            local h=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
            local px,py=players.xy(my_base)
            local gx,gy=players.xy(config.MY_FIRST)
            local dist=math.sqrt((bx-px)^2+(by-py)^2)
            local goal_dist=math.sqrt((bx-gx)^2+(by-gy)^2)
            local danger=possession==0 and interception.danger_target(
                bx,by,possession_context.ball_dx,possession_context.ball_dy,
                possession_context.ball_speed,gx,gy,field_side.goal_direction())
            local reason=nil
            if not lc.enabled then reason="DISABLED"
            elseif gs~=0 or not gameplay_active.is_active(gameplay_value) then
                reason="STOPPAGE"
            elseif age>=lc.max_frames then reason="TIMEOUT"
            elseif players.valid_cpu_base(possession) then reason="CPU_POSSESSION"
            elseif players.valid_my_base(possession) and
                (possession~=lock.carrier or age>lc.release_grace_frames) then
                reason="MY_POSSESSION"
            elseif danger then reason="GOAL_BOUND_DANGER"
            elseif not players.valid_my_base(my_base) or my_base==config.MY_FIRST then
                reason="NO_OUTFIELDER" end
            -- A clearance begins near its kicker and possibly still at low
            -- height: neither is evidence the ball will never enter flight.
            if not reason and not lock.flight_started then
                if possession==0 and h>=lc.min_height
                    and goal_dist>config.DEFENSIVE_HEADER.goal_radius then
                    lock.flight_started=report.frame
                    report:write("LONG_PASS_FLIGHT_CONFIRMED",true,
                        {possession=possession,game_state=gs,my_base=my_base},
                        "OBSERVE_LONG_PASS","age="..age..";height="..h
                        ..";clearance_sequence="..lock.clearance_sequence)
                elseif age>=lc.warmup_frames then
                    reason="FLIGHT_WARMUP_TIMEOUT"
                elseif age==1 then
                    report:write("LONG_PASS_FLIGHT_WARMUP",true,
                        {possession=possession,game_state=gs,my_base=my_base},
                        "OBSERVE_LONG_PASS","height="..h
                        ..";clearance_sequence="..lock.clearance_sequence)
                end
            end
            if not reason and lock.flight_started and dist<=lc.contact_distance then
                reason="CONTACT_WINDOW"
            end
            if reason then
                report:write("LONG_PASS_AI_ASSIST_END",true,
                    {possession=possession,game_state=gs,my_base=my_base},
                    "OBSERVE_LONG_PASS",
                    "reason="..reason..";age="..age
                    ..";flight_started="..tostring(lock.flight_started~=nil)
                    ..";neutral_frames="..lock.neutral_frames
                    ..";clearance_sequence="..lock.clearance_sequence)
                long_pass_ai_lock=nil
            elseif lock.flight_started then
                -- Intervene only when the selected player has a plausible
                -- uncontested interception; otherwise preserve game AI movement.
                local rc=config.DEFENSIVE_CLEARANCE_SECOND_BALL_RECOVERY
                local nearest_cpu=math.huge
                players.each_cpu(function(base)
                    if base~=config.CPU_FIRST then
                        local cx,cy=players.xy(base)
                        local d=math.sqrt((bx-cx)^2+(by-cy)^2)
                        if d<nearest_cpu then nearest_cpu=d end
                    end
                end)
                local nearest_my=math.huge
                local nearest_base=nil
                players.each_my(function(base)
                    if base~=config.MY_FIRST then
                        local mx,my=players.xy(base)
                        local d=math.sqrt((bx-mx)^2+(by-my)^2)
                        if d<nearest_my then nearest_my=d;nearest_base=base end
                    end
                end)
                if rc.enabled and nearest_base==my_base
                    and dist>lc.contact_distance
                    and dist<=rc.approach_distance
                    and nearest_cpu-dist>=rc.min_cpu_margin
                    and goal_dist>config.DEFENSIVE_HEADER.goal_radius then
                    local dx,dy=bx-px,by-py
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,
                        "DEF_CLEAR_SECOND_BALL_APPROACH",possession,gs)
                    state.live_target_x=bx
                    state.live_target_y=by
                    if report.frame%rc.log_interval==0 then
                        report:write("DEF_CLEAR_SECOND_BALL_DECISION",true,state,
                            movement.last_command,
                            "decision=APPROACH;sequence="..lock.clearance_sequence
                            ..";my_base="..my_base..";my_distance="..dist
                            ..";cpu_distance="..nearest_cpu
                            ..";height="..h)
                    end
                    return attach_live_state(state,"DEF_CLEAR_SECOND_BALL",
                        "MY_UNOWNED_BALL")
                end
                movement.stop()
                lock.neutral_frames=lock.neutral_frames+1
                local state=make_state(my_base,0,0,
                    "LONG_PASS_AI_ASSIST",possession,gs)
                state.header_height=h
                state.header_distance=dist
                return attach_live_state(state,"LONG_PASS_AI_ASSIST","MY_UNOWNED_BALL")
            end
            -- During warmup, preserve existing tactical decisions.
        end

        -- A failed defensive header must not leave the defender neutral while
        -- the ball remains near the own goal. Contact is inferred, never assumed.
        if defensive_header_pending and possession==0 and gs==0
            and players.valid_my_base(my_base)
            and my_base~=config.MY_FIRST then
            local hc=config.AERIAL_CONTACT_OUTCOME_GUARD
            local age=report.frame-defensive_header_pending.frame
            local hh=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
            local gx,gy=players.xy(config.MY_FIRST)
            local px,py=players.xy(my_base)
            local gd=math.sqrt((bx-gx)^2+(by-gy)^2)
            local dist=math.sqrt((bx-px)^2+(by-py)^2)
            if age>=hc.recovery_delay_frames and age<hc.max_frames
                and hh<=hc.recovery_max_height
                and gd<=config.DEFENSIVE_HEADER.goal_radius
                and dist<=hc.recovery_distance then
                local dx,dy=bx-px,by-py
                movement.move_toward(dx,dy)
                local state=make_state(my_base,dx,dy,
                    "AERIAL_CONTACT_RECOVERY",possession,gs)
                state.header_height=hh
                state.header_distance=dist
                return attach_live_state(state,"AERIAL_CONTACT_RECOVERY",
                    "MY_UNOWNED_BALL")
            end
        end

        -- Keep manual chase/rebound arbitration from immediately overriding
        -- neutral AI assistance inside the heading window. The header attempt
        -- above has first priority and still sends X when eligible.
        if config.AERIAL_CONTEST_LOCK.ai_assist_enabled
            and aerial_contest_lock and possession==0
            and players.valid_my_base(my_base)
            and my_base==aerial_contest_lock.base then
            local h=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
            local ax,ay=players.xy(my_base)
            local d=math.sqrt((bx-ax)^2+(by-ay)^2)
            if h>=config.DEFENSIVE_HEADER.min_height
                and h<=config.AERIAL_CONTEST_LOCK.max_height
                and d<=config.DEFENSIVE_HEADER.contact_distance then
                movement.stop()
                local state=make_state(my_base,0,0,
                    "AERIAL_AI_ASSIST_CONTACT_WAIT",possession,gs)
                state.header_height=h
                state.header_distance=d
                state.aerial_ai_assist=true
                return attach_live_state(state,"AERIAL_CONTEST","MY_UNOWNED_BALL")
            end
        end

        -- Highest-priority goal-bound ball guard: independent of the logical
        -- team flag, and before second-ball / goalkeeper-rebound arbitration.
        -- Do not spend emergency frames switching players (R); the current
        -- outfielder pursues the projected interception point.
        if possession==0 then
            local gx,gy=players.xy(config.MY_FIRST)
            local critical=interception.danger_target(bx,by,
                possession_context.ball_dx,possession_context.ball_dy,
                possession_context.ball_speed,gx,gy,field_side.goal_direction())
            if critical then
                local px,py=players.xy(my_base)
                if players.valid_my_base(my_base) and my_base~=config.MY_FIRST then
                    local target=field_boundary.correct(px,py,critical.x,critical.y)
                    local dx,dy=target.x-px,target.y-py
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,
                        "GOAL_BOUND_INTERCEPT_PRIORITY",possession,gs)
                    state.intercept_target_x=target.x
                    state.intercept_target_y=target.y
                    state.intercept_danger=true
                    state.intercept_frames_to_goal=critical.frames_to_goal
                    if report.frame%15==0 then
                        report:write("GOAL_BOUND_PRIORITY",true,state,
                            movement.last_command,
                            "frames_to_goal="..tostring(critical.frames_to_goal)
                            ..";target_x="..tostring(target.x)
                            ..";target_y="..tostring(target.y))
                    end
                    return attach_live_state(state,"CRITICAL_TRAJECTORY",
                        effective_unowned_team=="CPU"
                        and "CPU_UNOWNED_BALL" or "MY_UNOWNED_BALL")
                end
            end
        end

        -- A zero-possession frame can be a dribble stride, not a rebound.
        -- Keep pressure on the last CPU runner only with close spatial evidence.
        if possession==0 and cpu_carrier_continuity
            and cpu_carrier_continuity.active
            and players.valid_my_base(my_base)
            and my_base~=config.MY_FIRST then
            local base=cpu_carrier_continuity.base
            local cx,cy=players.xy(base)
            local px,py=players.xy(my_base)
            local gx,gy=players.xy(config.MY_FIRST)
            local vx,vy=gx-cx,gy-cy
            local length=math.sqrt(vx*vx+vy*vy)
            if length>1 and length<=continuity_cfg.press_goal_radius then
                local offset=math.min(continuity_cfg.goal_side_offset,length*0.5)
                local tx=cx+vx/length*offset
                local ty=cy+vy/length*offset
                local dx,dy=tx-px,ty-py
                movement.move_toward(dx,dy)
                local state=make_state(my_base,dx,dy,
                    "CPU_CARRIER_CONTINUITY_PRESS",possession,gs)
                state.live_carrier=base
                state.live_target_x=tx
                state.live_target_y=ty
                return attach_live_state(state,"CPU_CARRIER_CONTINUITY",
                    "CPU_UNOWNED_BALL")
            end
        end

        -- First loose rebound: reach the ball before pressuring its likely
        -- recipient. Use current-frame positions only, conservative ETA
        -- advantage, and a short same-defender commitment.
        if possession==0 then
            local cfg=config.FIRST_REBOUND_RECOVERY
            local gx,gy=players.xy(config.MY_FIRST)
            local goal_dist=math.sqrt((bx-gx)^2+(by-gy)^2)
            local height=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
            local critical=interception.danger_target(bx,by,
                possession_context.ball_dx,possession_context.ball_dy,
                possession_context.ball_speed,gx,gy,field_side.goal_direction())
            local lock=first_rebound_lock
            if lock then
                local age=report.frame-lock.frame
                local drift=math.sqrt((bx-lock.bx)^2+(by-lock.by)^2)
                local reason=nil
                if my_base~=lock.base then reason="CONTROL_CHANGED"
                elseif age>=cfg.lock_frames then reason="TIMEOUT"
                elseif drift>cfg.max_ball_drift then reason="BALL_MOVED"
                elseif height>cfg.max_height then reason="BALL_TOO_HIGH"
                elseif goal_dist>cfg.goal_radius then reason="LEFT_DANGER_ZONE"
                elseif critical then reason="SHOT_DANGER" end
                if reason then
                    report:write("FIRST_REBOUND_LOCK_END",true,
                        {possession=possession,game_state=gs,my_base=my_base,
                         ball_x=bx,ball_y=by},"OBSERVE_REBOUND",
                        "reason="..reason..";age="..age)
                    first_rebound_lock=nil
                end
            end
            if not critical and goal_dist<=cfg.goal_radius
                and height<=cfg.max_height
                and players.valid_my_base(my_base)
                and my_base~=config.MY_FIRST then
                local px,py=players.xy(my_base)
                local my_distance=math.sqrt((bx-px)^2+(by-py)^2)
                local cpu_distance=math.huge
                players.each_cpu(function(base)
                    if base~=config.CPU_FIRST then
                        local ax,ay=players.xy(base)
                        cpu_distance=math.min(cpu_distance,
                            math.sqrt((bx-ax)^2+(by-ay)^2))
                    end
                end)
                local my_eta=my_distance/cfg.estimated_speed
                local cpu_eta=cpu_distance/cfg.estimated_speed
                local advantage=cpu_eta-my_eta
                if first_rebound_lock or (my_distance<=cfg.max_my_distance
                    and advantage>=cfg.min_eta_advantage) then
                    local guarded=field_boundary.correct(px,py,bx,by)
                    local dx,dy=guarded.x-px,guarded.y-py
                    if not first_rebound_lock then
                        first_rebound_lock={frame=report.frame,base=my_base,
                            bx=bx,by=by}
                        report:write("FIRST_REBOUND_LOCK_START",true,
                            {possession=possession,game_state=gs,my_base=my_base,
                             ball_x=bx,ball_y=by},"OBSERVE_REBOUND",
                            "my_eta="..my_eta..";cpu_eta="..cpu_eta
                            ..";advantage="..advantage)
                    end
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,
                        "FIRST_REBOUND_RECOVERY",possession,gs)
                    state.intercept_target_x=guarded.x
                    state.intercept_target_y=guarded.y
                    state.contest_my_eta=my_eta
                    state.contest_cpu_eta=cpu_eta
                    return attach_live_state(state,"FIRST_REBOUND",
                        effective_unowned_team=="CPU"
                        and "CPU_UNOWNED_BALL" or "MY_UNOWNED_BALL")
                end
            end
        elseif first_rebound_lock then
            report:write("FIRST_REBOUND_LOCK_END",true,
                {possession=possession,game_state=gs,my_base=my_base},
                "OBSERVE_REBOUND","reason=POSSESSION_CONFIRMED")
            first_rebound_lock=nil
        end

        -- Quando nenhum jogador esta fisicamente ligado a bola,
        -- 0x104C passa a ser a fonte primaria para o lado da posse.
        -- Rebound recovery belongs to an individually free ball, regardless
        -- of the logical team-possession flag. Danger interception takes priority.
        -- Stable response to individually unowned second balls, TeamPoss agnostic.
        if possession==0 and second_ball_lock then
            local cfg=config.BOX_SECOND_BALL
            local gx,gy=players.xy(config.MY_FIRST)
            local danger=interception.danger_target(bx,by,
                possession_context.ball_dx,possession_context.ball_dy,
                possession_context.ball_speed,gx,gy,field_side.goal_direction())
            if (bx-gx)^2+(by-gy)^2<=cfg.goal_radius^2 and not danger then
                local best,best_dist=nil,math.huge
                players.each_my(function(base)
                    if base~=config.MY_FIRST then
                        local x,y=players.xy(base)
                        local d=math.sqrt((bx-x)^2+(by-y)^2)
                        if d<best_dist then best,best_dist=base,d end
                    end
                end)
                if best and best_dist<=cfg.max_outfielder_distance then
                    local px,py=players.xy(my_base)
                    local controlled_dist=math.sqrt((bx-px)^2+(by-py)^2)
                    if controlled_dist>cfg.max_outfielder_distance
                        and controlled_dist-best_dist>=cfg.min_switch_gain
                        and second_ball_lock.expires-report.frame>=cfg.switch_min_remaining
                        and second_ball_lock.switches<cfg.max_switches then
                        local switched=maybe_switch_player(bx,by,
                            "BOX_SECOND_BALL_CONTINUITY")
                        if switched then
                            second_ball_lock.switches=second_ball_lock.switches+1
                            return switched
                        end
                    end
                    if controlled_dist<=cfg.max_outfielder_distance then
                        local guarded=field_boundary.correct(px,py,bx,by)
                        local dx,dy=guarded.x-px,guarded.y-py
                        movement.move_toward(dx,dy)
                        local state=make_state(my_base,dx,dy,
                            "BOX_SECOND_BALL_CONTINUITY",possession,gs)
                        state.intercept_target_x=guarded.x
                        state.intercept_target_y=guarded.y
                        state.second_ball_sequence=second_ball_lock.sequence
                        return attach_live_state(state,"SHOT_COUNTER",
                            effective_unowned_team=="CPU"
                            and "CPU_UNOWNED_BALL" or "MY_UNOWNED_BALL")
                    end
                end
            end
        end
        if possession==0 and gk_rebound_recovery.active(report.frame) then
            local gx,gy=players.xy(config.MY_FIRST)
            local cfg=config.GK_REBOUND_RECOVERY
            local gd2=(bx-gx)^2+(by-gy)^2
            local danger=interception.danger_target(bx,by,
                possession_context.ball_dx,possession_context.ball_dy,
                possession_context.ball_speed,gx,gy,field_side.goal_direction())
            if gd2<=cfg.goal_radius^2 and not danger then
                local best,best_d=nil,math.huge
                players.each_my(function(base)
                    if base~=config.MY_FIRST then
                        local x,y=players.xy(base)
                        local d=math.sqrt((bx-x)^2+(by-y)^2)
                        if d<best_d then best,best_d=base,d end
                    end
                end)
                if best and best_d<=cfg.max_outfielder_distance then
                    local px,py=players.xy(my_base)
                    local controlled_distance=math.sqrt((bx-px)^2+(by-py)^2)
                    -- No late switch: a switch consumes a control frame
                    -- right when the opponent may collect the rebound.
                    local switch_state=nil
                    if controlled_distance>best_d+cfg.switch_margin
                        and controlled_distance>cfg.max_outfielder_distance
                        and gk_rebound_recovery.remaining(report.frame)>cfg.no_switch_last_frames then
                        switch_state=maybe_switch_player(bx,by,"GK_REBOUND_RECOVERY")
                    end
                    if switch_state then
                        switch_state.gk_rebound_candidate=true
                        return switch_state
                    end
                    if controlled_distance<=cfg.max_outfielder_distance then
                        local guarded=field_boundary.correct(px,py,bx,by)
                        local dx,dy=guarded.x-px,guarded.y-py
                        movement.move_toward(dx,dy)
                        local state=make_state(my_base,dx,dy,
                            "GK_REBOUND_RECOVERY",possession,gs)
                        state.intercept_target_x=guarded.x
                        state.intercept_target_y=guarded.y
                        state.gk_rebound_candidate=true
                        return attach_live_state(state,"GK_REBOUND_CANDIDATE",
                            effective_unowned_team=="CPU"
                            and "CPU_UNOWNED_BALL" or "MY_UNOWNED_BALL")
                    end
                end
            end
        end

        if possession == 0 and effective_unowned_team=="CPU" then
            -- This branch can run without attach_live_state until its return;
            -- centralized handoff will record the takeover there.
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
                return attach_live_state(state,"BOX_PRESSURE","CPU_UNOWNED_BALL")
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
                "CPU_UNOWNED_BALL"
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
                gk_release_lock and "CPU_GK_RELEASE_ORIGIN" or "TEAM_POSSESSION_RAM",
                "CPU_UNOWNED_BALL"
            )
        end

        if possession == 0 and effective_unowned_team=="MY" then
            live_attack.reset()
            gk_distribution.reset()
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
                return attach_live_state(state,"DANGER_OVERRIDE","MY_UNOWNED_BALL")
            end
            -- Keep an approved chase briefly; release if the defender cannot arrive.
            local lock=contest_intercept_lock
            if lock then
                local lc=config.BALL_CONTEST_DECISION_GATE
                local px,py=players.xy(my_base)
                local dist=math.sqrt((lock.x-px)^2+(lock.y-py)^2)
                local dx_ball,dy_ball=bx-lock.bx,by-lock.by
                local drift=math.sqrt(dx_ball*dx_ball+dy_ball*dy_ball)
                local my_eta=dist/config.BALL_CONTEST_FEASIBILITY.estimated_my_speed
                local eta_deficit=my_eta-lock.cpu_eta
                local reason=nil
                if report.frame-lock.start>=lc.lock_frames then reason="TIMEOUT"
                elseif math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))>lc.max_height then reason="HEIGHT"
                elseif drift>lc.lock_target_tolerance then reason="TRAJECTORY_CHANGED"
                elseif my_eta>lc.lock_max_defender_eta
                    or eta_deficit>lc.lock_max_eta_deficit then reason="UNREACHABLE"
                elseif dist<=lc.lock_stop_distance then reason="ARRIVED" end
                if reason then
                    report:write(reason=="UNREACHABLE" and "INTERCEPT_ABORT_UNREACHABLE"
                        or "BALL_CONTEST_LOCK_END",true,
                        {possession=possession,game_state=gs,my_base=my_base,
                         ball_x=bx,ball_y=by},"OBSERVE_CONTEST_LOCK",
                        "reason="..reason..";distance="..dist
                        ..";my_eta="..my_eta..";cpu_eta="..lock.cpu_eta
                        ..";age="..(report.frame-lock.start))
                    contest_intercept_lock=nil
                    contest_abort_until=report.frame+config.BALL_CONTEST_DECISION_GATE.abort_cooldown_frames
                else
                    local dx,dy=lock.x-px,lock.y-py
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,
                        "BALL_CONTEST_INTERCEPT_LOCK",possession,gs)
                    state.intercept_target_x=lock.x
                    state.intercept_target_y=lock.y
                    state.contest_my_eta=my_eta
                    state.contest_cpu_eta=lock.cpu_eta
                    return attach_live_state(state,"ETA_INTERCEPT_LOCK","MY_UNOWNED_BALL")
                end
            end
            -- Previous-frame stable ETA can unlock a conservative low-ball chase.
            -- Existing goal-box danger override above retains priority.
            local gate=config.BALL_CONTEST_DECISION_GATE
            local eta=latest_contest
            local reason="NO_STABLE_ETA"
            if report.frame>=contest_abort_until and eta and latest_contest_frame
                and report.frame-latest_contest_frame<=gate.max_age_frames then
                local height=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
                local gkx,gky=players.xy(config.MY_FIRST)
                local near_goal=(bx-gkx)^2+(by-gky)^2<=gate.goal_proximity_radius^2
                local origin_cpu=flight_context.origin=="CPU"
                if height>gate.max_height then reason="BALL_TOO_HIGH"
                elseif not (origin_cpu or near_goal) then reason="OWN_PASS_PROTECTED"
                elseif eta.class~="CPU" or eta.raw_class~="CPU"
                    or eta.stability<gate.min_stability_frames then
                    reason="ETA_NOT_STABLE_CPU"
                elseif eta.my_distance>gate.max_my_distance then
                    reason="DEFENDER_TOO_FAR"
                elseif eta.my_eta-eta.cpu_eta<gate.min_cpu_eta_advantage then
                    reason="INSUFFICIENT_CPU_ADVANTAGE"
                else
                    reason="ALLOWED"
                    local tx,ty=eta.target_x,eta.target_y
                    local px,py=players.xy(my_base)
                    local distance=math.sqrt((tx-px)^2+(ty-py)^2)
                    local defender_eta=distance/config.BALL_CONTEST_FEASIBILITY.estimated_my_speed
                    if defender_eta>gate.lock_max_defender_eta
                        or defender_eta-eta.cpu_eta>gate.lock_max_eta_deficit then
                        reason="INTERCEPT_UNREACHABLE"
                        contest_abort_until=report.frame+gate.abort_cooldown_frames
                        report:write("INTERCEPT_ABORT_UNREACHABLE",true,
                            {possession=possession,game_state=gs,my_base=my_base,
                             ball_x=bx,ball_y=by},"OBSERVE_CONTEST_GATE",
                            "reason=INITIAL_FEASIBILITY;my_eta="..defender_eta
                            ..";cpu_eta="..eta.cpu_eta)
                    else
                    contest_intercept_lock={x=tx,y=ty,bx=bx,by=by,
                        start=report.frame,cpu_eta=eta.cpu_eta}
                    report:write("BALL_CONTEST_LOCK_START",true,
                        {possession=possession,game_state=gs,my_base=my_base,
                         ball_x=bx,ball_y=by},"OBSERVE_CONTEST_LOCK",
                        "target_x="..tx..";target_y="..ty
                        ..";my_eta="..defender_eta..";cpu_eta="..eta.cpu_eta)
                    local switch_state=maybe_switch_player(tx,ty,"BALL_CONTEST_DECISION_GATE")
                    if switch_state then
                        switch_state.contest_gate="ALLOWED_SWITCH"
                        switch_state.contest_my_eta=eta.my_eta
                        switch_state.contest_cpu_eta=eta.cpu_eta
                        switch_state.intercept_target_x=tx
                        switch_state.intercept_target_y=ty
                        return switch_state
                    end
                    local px,py=players.xy(my_base)
                    local dx,dy=tx-px,ty-py
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,
                        "BALL_CONTEST_INTERCEPT",possession,gs)
                    state.intercept_target_x=tx
                    state.intercept_target_y=ty
                    state.contest_gate="ALLOWED"
                    state.contest_my_eta=eta.my_eta
                    state.contest_cpu_eta=eta.cpu_eta
                    return attach_live_state(state,"ETA_DECISION_GATE","MY_UNOWNED_BALL")
                    end
                end
            end
            -- Denial is sampled; do not fill the CSV with a row per frame.
            if report.frame%gate.log_denied_every==0 then
                report:write("BALL_CONTEST_GATE_DENIED",true,
                    {possession=possession,game_state=gs,gameplay_active=gameplay_value,
                     my_base=my_base,ball_x=bx,ball_y=by},
                    "OBSERVE_GATE","reason="..reason)
            end
            -- A logical MY flight can originate from a confirmed CPU carrier.
            -- Only contest low balls when CPU is materially closer, and a
            -- Brazilian outfielder is still within a reasonable chase range.
            local fc=config.MY_FLIGHT_INTERCEPTION
            if report.frame>=contest_abort_until and flight_context.origin=="CPU"
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
                    return attach_live_state(state,"ORIGIN_OVERRIDE","MY_UNOWNED_BALL")
                end
            end
            -- A committed attempt survives short-lived ETA/class flicker.
            -- It is deliberately bounded and cannot override the box emergency.
            if my_recovery_lock then
                local lock=my_recovery_lock
                local rc=config.MY_UNOWNED_RECOVERY
                local px,py=players.xy(my_base)
                local drift=math.sqrt((bx-lock.bx)^2+(by-lock.by)^2)
                local dist=math.sqrt((lock.x-px)^2+(lock.y-py)^2)
                local age=report.frame-lock.frame
                local height=math.max(0,-mem.s16(config.AERIAL_CONTACT.height_addr))
                local reason=nil
                if lock.base~=my_base then reason="CONTROLLED_PLAYER_CHANGED"
                elseif age>=rc.lock_frames then reason="TIMEOUT"
                elseif drift>rc.lock_max_ball_drift then reason="TRAJECTORY_CHANGED"
                elseif height>rc.lock_max_height then reason="BALL_TOO_HIGH"
                elseif dist>rc.max_controlled_distance then reason="OUT_OF_REACH"
                elseif dist<=rc.lock_arrive_distance then reason="ARRIVED" end
                if reason then
                    report:write("MY_RECOVERY_LOCK_END",true,
                        {possession=possession,game_state=gs,my_base=my_base,
                         ball_x=bx,ball_y=by},"OBSERVE_RECOVERY",
                        "reason="..reason..";age="..age..";distance="..dist
                        ..";locked_base="..tostring(lock.base)
                        ..";controlled_base="..tostring(my_base))
                    my_recovery_lock=nil
                else
                    local dx,dy=lock.x-px,lock.y-py
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,
                        "MY_UNOWNED_RECOVERY_LOCK",possession,gs)
                    state.intercept_target_x=lock.x
                    state.intercept_target_y=lock.y
                    return attach_live_state(state,"RECOVERY_CONTINUITY","MY_UNOWNED_BALL")
                end
            end
            -- Opportunistic recovery: logical MY ownership does not imply a
            -- Brazilian player controls the ball. Pursue only a stable, low
            -- ball with a meaningful arrival-time advantage.
            local recovery=config.MY_UNOWNED_RECOVERY
            local eta=latest_contest -- previous frame: avoid current-frame lookahead
            if report.frame>=contest_abort_until and eta and latest_contest_frame
                and report.frame-latest_contest_frame<=recovery.max_age_frames
                and eta.class=="MY" and eta.raw_class=="MY"
                and eta.stability>=recovery.stability_frames
                and eta.height<=recovery.max_height
                and eta.my_distance<=recovery.max_distance
                and eta.eta_advantage>=recovery.min_eta_advantage then
                local tx,ty=eta.target_x,eta.target_y
                local current_x,current_y=players.xy(my_base)
                local guarded=field_boundary.correct(current_x,current_y,tx,ty)
                tx,ty=guarded.x,guarded.y
                local switch_state=maybe_switch_player(tx,ty,"MY_UNOWNED_RECOVERY")
                if switch_state then
                    switch_state.intercept_target_x=tx
                    switch_state.intercept_target_y=ty
                    return switch_state
                end
                local px,py=players.xy(my_base)
                local dx,dy=tx-px,ty-py
                local distance=math.sqrt(dx*dx+dy*dy)
                -- Avoid dragging a distant controlled player across the field:
                -- player selection uses R sequentially, not direct selection.
                if distance<=recovery.max_controlled_distance then
                    my_recovery_lock={x=tx,y=ty,bx=bx,by=by,
                        base=my_base,frame=report.frame}
                    report:write("MY_RECOVERY_LOCK_START",true,
                        {possession=possession,game_state=gs,my_base=my_base,
                         ball_x=bx,ball_y=by},"OBSERVE_RECOVERY",
                        "target_x="..tx..";target_y="..ty
                        ..";eta_advantage="..eta.eta_advantage)
                    movement.move_toward(dx,dy)
                    local state=make_state(my_base,dx,dy,
                        "MY_UNOWNED_RECOVERY",possession,gs)
                    state.intercept_target_x=tx
                    state.intercept_target_y=ty
                    state.contest_my_eta=eta.my_eta
                    state.contest_cpu_eta=eta.cpu_eta
                    return attach_live_state(state,"ETA_RECOVERY","MY_UNOWNED_BALL")
                end
            end
            movement.stop()
            return attach_live_state(
                make_state(my_base,0,0,"MY_UNOWNED_BALL",possession,gs),
                "TEAM_POSSESSION_RAM","MY_UNOWNED_BALL")
        end

        -- Fallback temporal somente se 0x104C sair do dominio validado 0/1.
        if fallback_class == "CPU_UNOWNED_BALL" then
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

        if fallback_class == "MY_UNOWNED_BALL" then
            return attach_live_state(
                make_state(
                    my_base, 0, 0, "MY_UNOWNED_BALL_FALLBACK",
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
                local plan=corner_kick.plan(bx,by,restart.taker,restart.taker_team,my_base)
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
            -- Physical situation is orthogonal to tactical status, including
            -- danger overrides, switches and intercept locks. No carrier must
            -- be confirmed: team possession RAM is only the logical side.
            if state.possession==0 and state.game_state==0 then
                local side=state.gk_release_origin_active and "CPU"
                    or (mem.u8(config.ADDR.team_possession)==0 and "MY"
                    or mem.u8(config.ADDR.team_possession)==1 and "CPU" or nil)
                if side then
                    state.ball_situation_class=side.."_BALL_"..flight.height_band
                end
            end
            if state.status=="MY_FLIGHT_BOX_DANGER" then
                -- Classify the existing box intervention after the decision:
                -- no change to movement, threat selection or switch priority.
                state.flight_height_band=flight.height_band
                state.flight_strategy=flight.height_band=="AERIAL"
                    and "COVER_AERIAL_BOX" or flight.height_band=="LOW"
                    and "RECOVER_LOW_BOX" or "RECOVER_GROUND_BOX"
                state.status=flight.height_band=="AERIAL"
                    and "MY_BOX_AERIAL_COVER" or flight.height_band=="LOW"
                    and "MY_BOX_LOW_RECOVERY" or "MY_BOX_GROUND_RECOVERY"
            end
            if state.status=="MY_UNOWNED_BALL" then
                state.status,state.flight_strategy,state.flight_height_band=
                    BallFlightContext.classify_unowned_ball(flight,"MY")
            elseif state.status=="CPU_BALL_INTERCEPT" then
                -- Separate interception state by measured height, without
                -- changing the movement command or danger override.
                local physical,strategy,band=
                    BallFlightContext.classify_unowned_ball(flight,"CPU")
                state.flight_physical_status=physical
                state.flight_strategy=strategy
                state.flight_height_band=band
                state.status=band=="GROUND" and "CPU_GROUND_INTERCEPT"
                    or band=="LOW" and "CPU_LOW_INTERCEPT"
                    or "CPU_AERIAL_INTERCEPT"
            end
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
        local rebound_event=gk_rebound_recovery.update(state,report.frame)
        if rebound_event then
            report:write("GK_REBOUND_"..rebound_event.kind,true,state,
                "OBSERVE_GK_REBOUND",
                "reason="..tostring(rebound_event.reason)
                ..";elapsed="..tostring(rebound_event.elapsed)
                ..";sequence="..tostring(rebound_event.sequence)
                ..";speed="..tostring(rebound_event.speed)
                ..";acceleration="..tostring(rebound_event.acceleration)
                ..";height_change="..tostring(rebound_event.height_change)
                ..";height="..tostring(state.ball_height)
                ..";ball_x="..tostring(state.ball_x)
                ..";ball_y="..tostring(state.ball_y))
        end
        local header_window=aerial_defensive_contact.update(state)
        if header_window then
            report:write("AERIAL_DEFENSIVE_CONTACT_"..header_window.kind,
                true,state,"OBSERVE_HEADER_WINDOW",
                "height="..tostring(header_window.height)
                ..";distance="..tostring(header_window.distance)
                ..";nearest_base="..tostring(header_window.nearest_base)
                ..";vertical_delta="..tostring(header_window.delta)
                ..";class="..tostring(header_window.classification)
                ..";reason="..tostring(header_window.reason))
        end
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
        local physical_control=ball_physical_control.update(state)
        if physical_control and (physical_control.changed or report.frame%60==0) then
            report:write("BALL_PHYSICAL_CONTROL_CLASS",true,state,
                "OBSERVE_CONTROL",
                "class="..tostring(physical_control.class)
                ..";confidence="..tostring(physical_control.confidence)
                ..";candidate="..tostring(physical_control.candidate)
                ..";team="..tostring(physical_control.team)
                ..";distance="..tostring(physical_control.distance)
                ..";motion_error="..tostring(physical_control.error)
                ..";streak="..tostring(physical_control.streak)
                ..";ambiguous="..tostring(physical_control.ambiguous)
                ..";height="..tostring(physical_control.height))
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
        latest_contest=contest
        latest_contest_frame=contest and report.frame or nil
        if state.contest_gate=="ALLOWED" or state.contest_gate=="ALLOWED_SWITCH" then
            report:write("BALL_CONTEST_GATE_ALLOWED",true,state,
                state.controller_command,
                "gate="..tostring(state.contest_gate)
                ..";my_eta="..tostring(state.contest_my_eta)
                ..";cpu_eta="..tostring(state.contest_cpu_eta)
                ..";target_x="..tostring(state.intercept_target_x)
                ..";target_y="..tostring(state.intercept_target_y))
        end
        if contest and (contest.changed or report.frame%30==0) then
            report:write(contest.changed and "BALL_CONTEST_ETA_CHANGE" or "BALL_CONTEST_ETA_SAMPLE",
                true,state,"OBSERVE_CONTEST_ETA",
                "class="..tostring(contest.class)
                ..";raw_class="..tostring(contest.raw_class)
                ..";stability="..tostring(contest.stability)
                ..";pending="..tostring(contest.pending)
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
                ..";elapsed="..tostring(contest_result.elapsed)
                ..";correct="..tostring(contest_result.correct)
                ..";initial_my_eta="..tostring(contest_result.my_eta)
                ..";initial_cpu_eta="..tostring(contest_result.cpu_eta)
                ..";initial_eta_advantage="..tostring(contest_result.advantage)
                ..";initial_height="..tostring(contest_result.height))
        end
        local transition_events=defensive_midfield_transition.update(state,report.frame)
        for _,event in ipairs(transition_events) do
            report:write("DEF_MID_TRANSITION_"..event.kind,true,state,
                "OBSERVE_TRANSITION",
                "reason="..tostring(event.reason)
                ..";sequence="..tostring(event.sequence)
                ..";age="..tostring(event.age)
                ..";route="..tostring(event.route)
                ..";boundary="..tostring(event.boundary)
                ..";game_state="..tostring(event.game_state)
                ..";gameplay_active="..tostring(event.gameplay_active)
                ..";possession="..tostring(event.possession)
                ..";selected="..tostring(event.selected)
                ..";status="..tostring(event.status)
                ..";direction="..tostring(event.direction)
                ..";zone="..tostring(event.zone)
                ..";owner_changes="..tostring(event.owner_changes)
                ..";loose_frames="..tostring(event.loose_frames))
        end
        for _,event in ipairs(mid_attack_transition.update(state,report.frame)) do
            report:write("MID_ATTACK_TRANSITION_"..event.kind,true,state,
                "OBSERVE_TRANSITION",
                "reason="..tostring(event.reason)
                ..";sequence="..tostring(event.sequence)
                ..";age="..tostring(event.age)
                ..";route="..tostring(event.route)
                ..";start_progress="..tostring(event.start_progress)
                ..";max_progress="..tostring(event.max_progress)
                ..";progress_gain="..tostring(event.progress_gain)
                ..";net_progress="..tostring(event.net_progress)
                ..";remaining="..tostring(event.remaining)
                ..";first_cross_age="..tostring(event.first_cross_age)
                ..";entries="..tostring(event.entries)
                ..";stability_resets="..tostring(event.returns)
                ..";retreats="..tostring(event.retreats)
                ..";unowned_frames="..tostring(event.unowned_frames)
                ..";deadline="..tostring(event.deadline)
                ..";extensions="..tostring(event.extensions)
                ..";recent_gain="..tostring(event.recent_gain)
                ..";grace_granted="..tostring(event.grace_granted)
                ..";grace_frames="..tostring(event.grace_frames))
        end
        local clearance=defensive_clearance_outcome.update(state,report.frame)
        if clearance then
            report:write("DEF_CLEAR_OUTCOME_"..clearance.kind,true,state,
                "OBSERVE_CLEARANCE",
                "reason="..tostring(clearance.reason)
                ..";sequence="..clearance.sequence
                ..";age="..clearance.age
                ..";progress="..tostring(clearance.progress)
                ..";start_x="..tostring(clearance.start_x)
                ..";end_x="..tostring(clearance.end_x)
                ..";variant="..tostring(clearance.variant)
                ..";charge_frames="..clearance.frames
                ..";owner="..tostring(clearance.owner)
                ..";receiver="..tostring(clearance.receiver)
                ..";receiver_x="..tostring(clearance.receiver_x)
                ..";inactive_frames="..tostring(clearance.inactive_frames)
                ..";game_state="..tostring(clearance.game_state)
                ..";gameplay_active="..tostring(clearance.gameplay_active))
        end
        for _,event in ipairs(long_pass_position_observer.update(
            state,report.frame,movement.last_command) or {}) do
            report:write("LONG_PASS_POSITION_"..event.kind,true,state,
                "OBSERVE_LONG_PASS",
                "reason="..tostring(event.reason)
                ..";sequence="..tostring(event.sequence)
                ..";age="..tostring(event.age)
                ..";neutral_frames="..tostring(event.neutral_frames)
                ..";neutral_distance="..tostring(event.neutral_distance)
                ..";directional_frames="..tostring(event.directional_frames)
                ..";directional_distance="..tostring(event.directional_distance)
                ..";switches="..tostring(event.switches)
                ..";initial_ball_distance="..tostring(event.initial_ball_distance)
                ..";min_ball_distance="..tostring(event.min_ball_distance)
                ..";gameplay_active="..tostring(event.gameplay_active)
                ..";game_state="..tostring(event.game_state))
        end
        for _,event in ipairs(long_pass_receiver_selection.update(state,report.frame,movement.last_command) or {}) do
            report:write("LONG_PASS_RECEIVER_"..event.kind,true,state,
                "OBSERVE_LONG_PASS",
                "sequence="..tostring(event.sequence)
                ..";age="..tostring(event.age)
                ..";previous="..tostring(event.previous)
                ..";current="..tostring(event.current)
                ..";travel="..tostring(event.travel)
                ..";straight="..tostring(event.straight)
                ..";ball_distance="..tostring(event.ball_distance)
                ..";height="..tostring(event.height)
                ..";switches="..tostring(event.switches)
                ..";source="..tostring(event.source)
                ..";band="..tostring(event.band)
                ..";selected="..tostring(event.selected)
                ..";neutral_frames="..tostring(event.neutral_frames)
                ..";neutral_movement="..tostring(event.neutral_movement)
                ..";direction_frames="..tostring(event.direction_frames)
                ..";direction_movement="..tostring(event.direction_movement)
                ..";intervention_frames="..tostring(event.intervention_frames)
                ..";intervention_movement="..tostring(event.intervention_movement)
                ..";closest="..tostring(event.closest)
                ..";closest_distance="..tostring(event.closest_distance)
                ..";previous_distance="..tostring(event.previous_distance)
                ..";selected_distance="..tostring(event.selected_distance)
                ..";available="..tostring(event.available)
                ..";gameplay_active="..tostring(event.gameplay_active)
                ..";game_state="..tostring(event.game_state))
        end
        if defensive_header_pending then
            local pending=defensive_header_pending
            local age=report.frame-pending.frame
            local result=nil
            if players.valid_my_base(state.possession) then
                result="MY_POSSESSION_AFTER_ATTEMPT"
            elseif players.valid_cpu_base(state.possession) then
                result="CPU_FIRST_POSSESSION"
            elseif state.game_state~=0 or state.gameplay_active~=1 then
                result="STOPPAGE"
            elseif age>=config.AERIAL_CONTACT_OUTCOME_GUARD.max_frames then
                result="UNRESOLVED"
            end
            if result then
                report:write("AERIAL_CONTACT_OUTCOME",true,state,
                    "OBSERVE_AERIAL",
                    "result="..result..";age="..age
                    ..";header_base="..pending.base
                    ..";initial_height="..pending.height
                    ..";contact_confirmed=unknown")
                defensive_header_pending=nil
            end
        end
        if natural_reception_pending then
            local rp=natural_reception_pending
            local result=nil
            if players.valid_my_base(state.possession) then
                result="MY_RECEIVED"
            elseif players.valid_cpu_base(state.possession) then
                result="CPU_RECEIVED"
            elseif state.game_state~=0 or state.gameplay_active~=1 then
                result="STOPPAGE"
            elseif report.frame-rp.frame>=config.AERIAL_NATURAL_RECEPTION_GUARD.outcome_frames then
                result="UNRESOLVED"
            end
            if result then
                report:write("NATURAL_RECEPTION_RESULT",true,state,
                    "OBSERVE_RECEPTION",
                    "result="..result..";age="..(report.frame-rp.frame)
                    ..";selected_base="..rp.base)
                natural_reception_pending=nil
            end
        end
        if state.team_possession_conflict and
            (not team_possession_conflict_active or report.frame%60==0) then
            report:write("TEAM_POSSESSION_CONFLICT",true,state,
                "OBSERVE_POSSESSION",
                "owner="..tostring(state.possession)
                ..";confirmed_team="..tostring(state.team_possession_kind)
                ..";logical_value="..tostring(state.team_possession)
                ..";source="..tostring(state.team_possession_kind_source))
        end
        team_possession_conflict_active=not not state.team_possession_conflict
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
