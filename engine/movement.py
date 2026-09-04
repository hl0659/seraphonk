"""Movement model: Ultrakill-adapted top-down + height z. Headless-testable."""
from __future__ import annotations
from dataclasses import dataclass
from .math2d import Vec2, approach

WALK = 380.0
DASH = 950.0
DASH_TIME = 0.16
IFRAMES = 0.25
SLIDE = 520.0
SLIDE_FRICTION = 1.8
SLAM_FALL = 1400.0
SLAM_AOE = 120.0
MAX_STAMINA = 3.0
REGEN = 1.0
COYOTE = 0.08
BUFFER = 0.12
JUMP_VZ = 560.0
DASH_JUMP_VZ = 620.0

@dataclass
class MoveState:
    pos: Vec2 = None
    vel: Vec2 = None
    z: float = 0.0
    vz: float = 0.0
    airborne: bool = False
    dash_t: float = 0.0
    iframes_t: float = 0.0
    sliding: bool = False
    slamming: bool = False
    stamina: float = MAX_STAMINA
    coyote_t: float = 0.0
    buffer_jump_t: float = 0.0
    def __post_init__(self):
        if self.pos is None: self.pos = Vec2()
        if self.vel is None: self.vel = Vec2()

def try_dash(s: MoveState, direction: Vec2) -> bool:
    if s.stamina < 1.0 or s.dash_t > 0: return False
    s.stamina -= 1.0
    d = direction.normalized()
    s.vel = d * DASH
    s.dash_t = DASH_TIME
    s.iframes_t = IFRAMES
    s.slamming = False
    return True

def try_slide_jump(s: MoveState) -> bool:
    """Cheap momentum-preserving hop out of slide (1 stamina via jump buffer)."""
    if not s.sliding: return False
    s.sliding = False
    s.airborne = True
    s.vz = 420.0
    s.coyote_t = 0.0
    return True

def try_slam(s: MoveState) -> bool:
    if not s.airborne or s.slamming: return False
    s.slamming = True
    s.sliding = False
    s.dash_t = 0.0
    s.vel = s.vel * 0.05  # Ultrakill-like: kill horizontal (0.48 u/s equiv)
    s.vz = -SLAM_FALL
    return True

def try_jump_grounded(s: MoveState) -> bool:
    """Normal/coyote jump. Consumes buffer."""
    s.airborne = True
    s.sliding = False
    s.vz = JUMP_VZ
    s.z = max(s.z, 0.01)
    s.coyote_t = 0.0
    s.buffer_jump_t = 0.0
    return True

def update(s: MoveState, wish: Vec2, dt: float, want_dash=False, want_slide=False, want_slam=False, want_jump=False):
    grounded = (not s.airborne) and (not s.slamming) and s.z <= 0.001
    if want_jump:
        s.buffer_jump_t = BUFFER
    else:
        s.buffer_jump_t = max(0.0, s.buffer_jump_t - dt)
    if grounded:
        s.coyote_t = COYOTE
    else:
        s.coyote_t = max(0.0, s.coyote_t - dt)
    if want_dash: try_dash(s, wish if wish.length() > 0 else Vec2(1, 0))
    if want_slam: try_slam(s)
    # stamina regen paused while sliding (including entry frame intent)
    sliding_intent = want_slide and not s.airborne and not s.slamming
    if not s.sliding and not sliding_intent:
        s.stamina = min(MAX_STAMINA, s.stamina + REGEN * dt)
    if s.dash_t > 0:
        s.dash_t -= dt
    if s.iframes_t > 0:
        s.iframes_t -= dt
    # dash-jump: buffered jump during dash = 2nd stamina, keeps dash momentum
    if s.buffer_jump_t > 0 and s.dash_t > 0 and not s.slamming:
        if s.stamina >= 1.0:
            s.stamina -= 1.0
            s.dash_t = 0.0
            s.sliding = False
            s.airborne = True
            s.vz = DASH_JUMP_VZ
            s.z = max(s.z, 0.01)
            s.buffer_jump_t = 0.0
            s.coyote_t = 0.0
        else:
            s.buffer_jump_t = 0.0
    # slide-jump: cheap hop out of slide (1 total with prior slide = free jump)
    elif s.buffer_jump_t > 0 and s.sliding and not s.airborne:
        try_slide_jump(s)
        s.buffer_jump_t = 0.0
    elif s.buffer_jump_t > 0 and (grounded or s.coyote_t > 0) and not s.airborne and not s.slamming:
        try_jump_grounded(s)
    if want_slide and not s.airborne:
        s.dash_t = 0.0  # slide cancels dash (dash-storage feel)
    if s.dash_t > 0:
        # preserve dash burst velocity for dash duration (don't overwrite with walk)
        s.pos = s.pos + s.vel * dt
        return None
    if s.slamming:
        # fall in z; land triggers AoE flag via z<=0 handled by caller/scene
        s.z += s.vz * dt
        s.pos = s.pos + s.vel * dt
        if s.z <= 0:
            s.z = 0; s.slamming = False; s.airborne = False
            s.vz = 0
            return "slammed"
        return None
    if want_slide and not s.airborne:
        s.sliding = True
        # keep prior speed if faster, decay toward SLIDE (Ultrakill preserve-then-friction)
        spd = s.vel.length()
        target = max(SLIDE, spd - SLIDE_FRICTION * SLIDE * dt)
        d = wish.normalized() if wish.length() > 0 else (s.vel.normalized() if spd > 0 else Vec2(1, 0))
        # Slideways: small perpendicular steering bonus
        s.vel = d * target
    elif s.airborne:
        # limited air control
        s.vel = s.vel + wish * 600.0 * dt
        # gravity on z
        s.vz -= 2200.0 * dt
        s.z += s.vz * dt
        if s.z <= 0:
            s.z = 0; s.airborne = False; s.vz = 0
    else:
        s.sliding = False
        s.vel = wish.normalized() * WALK if wish.length() > 0 else Vec2()
    s.pos = s.pos + s.vel * dt
    return None
