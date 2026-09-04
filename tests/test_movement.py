def test_dash_gives_iframes_and_costs_stamina():
    from engine.movement import MoveState, update
    from engine.math2d import Vec2
    s = MoveState()
    update(s, Vec2(1, 0), 1/60, want_dash=True)
    assert s.stamina < 3.0
    assert s.iframes_t > 0
    assert s.vel.length() > 600

def test_slide_preserves_fast_momentum():
    from engine.movement import MoveState, update
    from engine.math2d import Vec2
    s = MoveState()
    update(s, Vec2(1, 0), 1/60, want_dash=True)
    fast = s.vel.length()
    update(s, Vec2(1, 0), 1/60, want_slide=True)
    assert s.sliding
    assert s.vel.length() >= min(fast, 500)

def test_slam_aoe_landing():
    from engine.movement import MoveState, update
    from engine.math2d import Vec2
    s = MoveState()
    s.airborne = True; s.z = 200.0; s.vz = 0.0
    update(s, Vec2(), 1/60, want_slam=True)
    assert s.slamming
    result = None
    for _ in range(60):
        result = update(s, Vec2(), 1/60)
        if result == "slammed": break
    assert result == "slammed"
    assert s.z == 0
