"""M1 playtest arena: bounds + circle pillars. Pure functions, headless-testable."""
from __future__ import annotations
from dataclasses import dataclass
from engine.math2d import Vec2

W, H = 1600.0, 1200.0

@dataclass
class Pillar:
    x: float
    y: float
    r: float

PILLARS = [
    Pillar(500, 400, 60),
    Pillar(1100, 400, 60),
    Pillar(500, 800, 60),
    Pillar(1100, 800, 60),
    Pillar(800, 600, 45),
]

def collide(pos: Vec2, vel: Vec2, pillars=None):
    """Clamp to bounds, push out of pillars. Mutates pos, returns hit info."""
    pillars = PILLARS if pillars is None else pillars
    hit_wall = False
    if pos.x < 0: pos.x = 0; hit_wall = True
    if pos.y < 0: pos.y = 0; hit_wall = True
    if pos.x > W: pos.x = W; hit_wall = True
    if pos.y > H: pos.y = H; hit_wall = True
    hit_pillar = False
    for p in pillars:
        dx, dy = pos.x - p.x, pos.y - p.y
        d2 = dx*dx + dy*dy
        if d2 < p.r * p.r and d2 > 1e-6:
            import math
            d = math.sqrt(d2)
            push = (p.r - d)
            pos.x += dx / d * push
            pos.y += dy / d * push
            hit_pillar = True
        elif d2 <= 1e-6:
            pos.x = p.x + p.r
            hit_pillar = True
    return {"wall": hit_wall, "pillar": hit_pillar}
