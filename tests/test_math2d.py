def test_vec():
    from engine.math2d import Vec2, clamp, approach
    assert Vec2(3, 4).length() == 5.0
    assert clamp(9, 0, 1) == 1
    assert approach(0, 10, 3) == 3
