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
            "Game_State=%d (%s) Possession=$%04X",
            state.game_state or -1,
            game_state.kind(state.game_state or -1),
            state.possession or 0
        ))

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

                local ranking = state.ranking or {}
                local top_n = math.min(3, #ranking)

                for i = 1, top_n do
                    local candidate = ranking[i]
                    gui.text(8, 162 + (i - 1) * 14, string.format(
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
