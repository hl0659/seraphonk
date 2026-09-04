"""Minimal 2D math."""
from __future__ import annotations
import math

class Vec2:
    __slots__ = ("x", "y")
    def __init__(self, x: float = 0.0, y: float = 0.0):
        self.x, self.y = float(x), float(y)
    def __add__(self, o): return Vec2(self.x + o.x, self.y + o.y)
    def __sub__(self, o): return Vec2(self.x - o.x, self.y - o.y)
    def __mul__(self, s): return Vec2(self.x * s, self.y * s)
    def length(self): return math.hypot(self.x, self.y)
    def normalized(self):
        l = self.length()
        return Vec2(0, 0) if l == 0 else Vec2(self.x / l, self.y / l)

def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))

def approach(v: float, target: float, delta: float) -> float:
    if v < target: return min(target, v + delta)
    return max(target, v - delta)

def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t
