"""Gymnasium environment scaffold for International Superstar Soccer Deluxe."""

from __future__ import annotations

from typing import Any

import gymnasium as gym
import numpy as np
from gymnasium import spaces


class ISSDEnv(gym.Env):
    """Initial ISS Deluxe RL environment scaffold.

    Emulator integration and RAM addresses are intentionally left as TODOs
    until the RAM map has been validated.
    """

    metadata = {"render_modes": ["human"]}

    def __init__(self, frame_skip: int = 4) -> None:
        super().__init__()
        self.frame_skip = frame_skip

        # Baseline discrete action set.
        self.action_space = spaces.Discrete(12)

        # Minimal normalized state placeholder:
        # ball x/y, controlled player x/y, possession,
        # score for/against, match time.
        self.observation_space = spaces.Box(
            low=-1.0,
            high=1.0,
            shape=(8,),
            dtype=np.float32,
        )

    def _read_state(self) -> np.ndarray:
        """Read and normalize the current state from emulator RAM."""
        raise NotImplementedError("RAM integration not implemented yet.")

    def _send_action(self, action: int) -> None:
        """Send a controller action to the emulator for frame_skip frames."""
        raise NotImplementedError("Emulator control not implemented yet.")

    def _reward(self, previous: np.ndarray, current: np.ndarray) -> float:
        """Compute the current curriculum reward."""
        return 0.0

    def reset(
        self,
        *,
        seed: int | None = None,
        options: dict[str, Any] | None = None,
    ):
        super().reset(seed=seed)
        observation = self._read_state()
        info: dict[str, Any] = {}
        return observation, info

    def step(self, action: int):
        previous = self._read_state()
        self._send_action(action)
        observation = self._read_state()

        reward = self._reward(previous, observation)
        terminated = False
        truncated = False
        info: dict[str, Any] = {}

        return observation, reward, terminated, truncated, info
