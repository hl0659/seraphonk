"""Wave director: budget curve + mini-boss ticks + final swarm."""
from __future__ import annotations

def budget(t_sec: float) -> float:
    """Enemy budget grows ~quadratically, tuned for 10:00 run."""
    m = t_sec / 60.0
    return 4 + 6*m + 2.5*m*m

def is_miniboss_tick(t_sec: float) -> bool:
    return t_sec > 0 and int(t_sec) % 90 == 0

def is_wrath(t_sec: float, run_len: float = 600.0) -> bool:
    return t_sec >= run_len
