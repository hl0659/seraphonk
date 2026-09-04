"""Minimal ECS."""
from __future__ import annotations
from dataclasses import dataclass, field

_next_id = 1
def new_entity() -> int:
    global _next_id
    eid = _next_id; _next_id += 1
    return eid

@dataclass
class World:
    comps: dict = field(default_factory=dict)  # {CompType: {eid: comp}}
    def add(self, eid: int, comp):
        self.comps.setdefault(type(comp), {})[eid] = comp
    def get(self, comp_type, eid: int):
        return self.comps.get(comp_type, {}).get(eid)
    def all_of(self, comp_type):
        return self.comps.get(comp_type, {}).items()
