def test_bounds_clamp():
    from game.arena import collide, W, H
    from engine.math2d import Vec2
    p = Vec2(-50, H+100); v = Vec2()
    collide(p, v)
    assert p.x == 0 and p.y == H

def test_pillar_pushout():
    from game.arena import collide, PILLARS
    from engine.math2d import Vec2
    pl = PILLARS[0]
    p = Vec2(pl.x + 1, pl.y); v = Vec2()
    info = collide(p, v)
    assert info["pillar"] is True
    import math
    d = math.hypot(p.x - pl.x, p.y - pl.y)
    assert d >= pl.r - 1e-3
