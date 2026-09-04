"""Asset loader: prefers rendered PNGs, falls back to procedural."""
from __future__ import annotations
import os

def sprite_path(name: str) -> str:
    return os.path.join("assets", "sprites", f"{name}.png")

def has_sprite(name: str) -> bool:
    return os.path.exists(sprite_path(name))
