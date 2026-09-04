"""Spatial hash for circle queries."""
from __future__ import annotations

class SpatialHash:
    def __init__(self, cell: float = 64.0):
        self.cell = cell
        self.buckets: dict = {}
    def _key(self, x, y):
        return (int(x // self.cell), int(y // self.cell))
    def clear(self): self.buckets.clear()
    def insert(self, eid: int, x: float, y: float):
        self.buckets.setdefault(self._key(x, y), []).append(eid)
    def query(self, x, y, radius):
        out = []
        c = int(radius // self.cell) + 1
        kx, ky = self._key(x, y)
        for ix in range(kx-c, kx+c+1):
            for iy in range(ky-c, ky+c+1):
                out.extend(self.buckets.get((ix, iy), []))
        return out
