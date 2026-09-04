"""Fixed-timestep accumulator."""
from __future__ import annotations

class FixedAccumulator:
    def __init__(self, step: float = 1/60):
        self.step = step
        self.acc = 0.0
    def frames(self, dt: float) -> int:
        self.acc += min(dt, 0.25)
        n = 0
        while self.acc >= self.step:
            self.acc -= self.step
            n += 1
        return n
