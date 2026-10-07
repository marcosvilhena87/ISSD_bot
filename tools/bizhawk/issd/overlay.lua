local M = {}

function M.new(players, game_state)
    local obj = {}

    function obj.draw(state)
        gui.text(8, 8, "ISSD CHASE BOT: ON")
        gui.text(8, 22, string.format(
            "Player: %s",
            state.my_base and players.decode_my(state.my_base) or "?"
        ))
        gui.text(8, 36, string.format(
            "Delta: (%s,%s)",
            tostring(state.dx),
            tostring(state.dy)
        ))
        gui.text(8, 50, string.format(
            "Status: %s",
            state.status or "?"
        ))
        gui.text(8, 64, string.format(
            "GA=$%02X(%s) GS=%d(%s) P=$%04X",
            state.gameplay_active or 0,
            tostring(state.gameplay_active_kind or "?"),
            state.game_state or -1,
            game_state.kind(state.game_state or -1),
            state.possession or 0
        ))

        if state.game_state == 0 and state.team_possession ~= nil then
            gui.text(8, 78, string.format(
                "TeamPoss=$%02X (%s) src=%s",
                state.team_possession,
                tostring(state.team_possession_kind),
                tostring(state.team_possession_source)
            ))
            gui.text(8, 92, string.format(
                "Class: %s",
                tostring(state.possession_class)
            ))
            gui.text(8, 106, string.format(
                "Fallback last=%s owner=%s NoPoss=%d",
                tostring(state.context_last_team),
                state.context_last_owner == nil
                    and "-"
                    or string.format("$%04X", state.context_last_owner),
                state.context_frames_without or 0
            ))
        end

        if state.status == "GK_DISTRIBUTE" then
            gui.text(8, 120, string.format(
                "GK action=%s dir=%s button=%s wait=%d",
                tostring(state.gk_dist_mode or "?"),
                tostring(state.gk_dist_direction or "?"),
                tostring(state.gk_dist_button or "?"),
                state.gk_dist_wait_frames or 0
            ))

            if state.gk_dist_receiver ~= nil then
                gui.text(8, 134, string.format(
                    "Receiver: %s dist=%.1f clear=%.1f",
                    players.decode_any(state.gk_dist_receiver),
                    state.gk_dist_receiver_distance or 0,
                    state.gk_dist_receiver_clearance or 0
                ))
                gui.text(8, 148, string.format(
                    "Forward=%.1f score=%.1f",
                    state.gk_dist_receiver_forward or 0,
                    state.gk_dist_receiver_score or 0
                ))
            else
                gui.text(8, 134, "Receiver: none -> LONG_KICK")
            end
        end

        if state.status == "ATTACK_ADVANCE"
           or state.status == "ATTACK_LANE" then
            gui.text(8, 120, string.format(
                "Attack target: (%s,%s)",
                tostring(state.attack_target_x),
                tostring(state.attack_target_y)
            ))
            gui.text(8, 134, string.format(
                "Attack dir=%s Side=%s mode=%s",
                state.attack_direction == 1 and "RIGHT"
                    or state.attack_direction == -1 and "LEFT"
                    or "?",
                tostring(state.attack_my_side),
                tostring(state.attack_mode or "?")
            ))

            if state.status == "ATTACK_LANE" then
                gui.text(8, 148, string.format(
                    "Lane=%s lock=%d blocker=%s F=%.1f L=%.1f",
                    state.attack_lane_direction == -1 and "UP"
                        or state.attack_lane_direction == 1 and "DOWN"
                        or "?",
                    state.attack_lane_lock_frames or 0,
                    players.decode_any(state.attack_blocker_base),
                    state.attack_blocker_forward or 0,
                    state.attack_blocker_lateral or 0
                ))
                gui.text(8, 162, string.format(
                    "Clear UP=%s DOWN=%s",
                    state.attack_up_clearance == nil
                        and "-"
                        or string.format("%.1f", state.attack_up_clearance),
                    state.attack_down_clearance == nil
                        and "-"
                        or string.format("%.1f", state.attack_down_clearance)
                ))
            end
        end

        if state.status == "PLAYER_SWITCH" then
            gui.text(8, 120, string.format(
                "Switch %s -> %s via %s",
                players.decode_any(state.my_base),
                players.decode_any(state.switch_best_base),
                tostring(state.switch_button or "?")
            ))
            gui.text(8, 134, string.format(
                "Dist current=%.1f best=%.1f gain=%.1f",
                state.switch_current_distance or 0,
                state.switch_best_distance or 0,
                state.switch_improvement or 0
            ))
            gui.text(8, 148, string.format(
                "Cooldown=%d",
                state.switch_cooldown or 0
            ))
        end

        if state.status == "LIVE_DEFENSE" then
            gui.text(8, 120, string.format(
                "Carrier: %s",
                players.decode_any(state.live_carrier)
            ))
            gui.text(8, 134, string.format(
                "Def target: (%s,%s) Side=%s",
                tostring(state.live_target_x),
                tostring(state.live_target_y),
                tostring(state.live_my_side)
            ))

            if state.gk_distance ~= nil then
                gui.text(8, 148, string.format(
                    "GK dist=%.1f threshold=%.1f PRESS",
                    state.gk_distance,
                    state.gk_press_threshold or 0
                ))
            end
        end

        if state.status == "CPU_GK_HOLD" then
            gui.text(8, 120, "Carrier: CPU GK")
            gui.text(8, 134, string.format(
                "GK dist=%.1f threshold=%.1f HOLD",
                state.gk_distance or 0,
                state.gk_press_threshold or 0
            ))
        end

        if state.status == "CPU_BALL_INTERCEPT"
           or state.status == "CPU_BALL_INTERCEPT_FALLBACK" then
            gui.text(8, 120, string.format(
                "BallV=(%d,%d) speed=%.1f",
                state.ball_dx or 0,
                state.ball_dy or 0,
                state.ball_speed or 0
            ))
            gui.text(8, 134, string.format(
                "Intercept=(%s,%s) lead=%d pred=%s",
                tostring(state.intercept_target_x),
                tostring(state.intercept_target_y),
                state.intercept_lead_frames or 0,
                state.intercept_predictive and "YES" or "NO"
            ))
            gui.text(8, 148, string.format(
                "Dist=%.1f LeadVec=(%.1f,%.1f) clip=%s",
                state.intercept_player_ball_distance or 0,
                state.intercept_lead_x or 0,
                state.intercept_lead_y or 0,
                state.intercept_clipped and "YES" or "NO"
            ))
        end

        if state.game_state ~= nil and state.game_state ~= 0 then
            gui.text(8, 78, string.format(
                "Restart taker: %s",
                players.decode_any(state.restart_taker)
            ))

            if state.mark_target ~= nil then
                gui.text(8, 92, string.format(
                    "Mark target: %s",
                    players.decode_any(state.mark_target)
                ))

                gui.text(8, 106, string.format(
                    "Mark score=%.3f",
                    state.mark_score or -1
                ))

                gui.text(8, 120, string.format(
                    "Norm me=%.2f ball=%.2f goal=%.2f",
                    state.mark_norm_me or -1,
                    state.mark_norm_ball or -1,
                    state.mark_norm_goal or -1
                ))

                gui.text(8, 134, string.format(
                    "Raw me=%.1f ball=%.1f goal=%.1f Side=%s",
                    state.mark_dist_to_me or -1,
                    state.mark_dist_to_ball or -1,
                    state.mark_goal_cost or -1,
                    tostring(state.my_side)
                ))

                gui.text(8, 148, string.format(
                    "Lock=%d delta=%s %s",
                    state.lock_frames or 0,
                    state.switch_delta == nil
                        and "-"
                        or string.format("%.3f", state.switch_delta),
                    state.switch_blocked and "HOLD" or "FREE"
                ))

                local y = 162

                if state.last_switch_from ~= nil
                   and state.last_switch_to ~= nil then
                    gui.text(8, y, string.format(
                        "SWITCH %s -> %s d=%.3f age=%d",
                        players.decode_any(state.last_switch_from),
                        players.decode_any(state.last_switch_to),
                        state.last_switch_delta or -1,
                        state.last_switch_age or 0
                    ))
                    y = y + 14
                end

                local ranking = state.ranking or {}
                local top_n = math.min(3, #ranking)

                for i = 1, top_n do
                    local candidate = ranking[i]
                    gui.text(8, y + (i - 1) * 14, string.format(
                        "#%d %s S=%.3f M=%.2f B=%.2f G=%.2f",
                        i,
                        players.decode_any(candidate.base),
                        candidate.score or -1,
                        candidate.norm_me or -1,
                        candidate.norm_ball or -1,
                        candidate.norm_goal or -1
                    ))
                end
            end
        end
    end

    function obj.draw_off()
        gui.text(8, 8, "ISSD CHASE BOT: OFF (K) - manual control")
    end

    return obj
end

return M
