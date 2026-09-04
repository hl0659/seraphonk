"""Feel hooks: trauma shake, hitstop, dash trail. Headless-testable, no gfx."""
from __future__ import annotations
from dataclasses import dataclass, field

@dataclass
class Feel:
    trauma: float = 0.0
    hitstop_t: float = 0.0
    trail: list = field(default_factory=list)  # [(x, y, age)]
    time_scale: float = 1.0

    def add_trauma(self, amount: float):
        self.trauma = min(1.0, self.trauma + amount)

    def trigger_hitstop(self, duration: float):
        self.hitstop_t = max(self.hitstop_t, duration)

    def push_trail(self, x: float, y: float):
        self.trail.append([x, y, 0.35])
        if len(self.trail) > 24:
            self.trail.pop(0)

    def update(self, dt: float) -> bool:
        """Returns True if frozen (hitstop active)."""
        if self.hitstop_t > 0:
            self.hitstop_t -= dt
            return True
        self.trauma = max(0.0, self.trauma - dt * 1.6)
        for p in self.trail:
            p[2] -= dt
        self.trail = [p for p in self.trail if p[2] > 0]
        return False

    def shake(self, max_px: float = 14.0) -> float:
        return self.trauma * self.trauma * max_px
