def test_hitstop_freezes_and_decays():
    from engine.feel import Feel
    f = Feel()
    f.trigger_hitstop(0.05)
    assert f.update(1/60) is True
    for _ in range(10):
        f.update(1/60)
    assert f.hitstop_t <= 0

def test_trauma_shake_decays():
    from engine.feel import Feel
    f = Feel()
    f.add_trauma(1.0)
    assert f.shake() > 0
    for _ in range(120):
        f.update(1/60)
    assert f.shake() < 0.5

def test_trail_expires():
    from engine.feel import Feel
    f = Feel()
    f.push_trail(0, 0)
    assert len(f.trail) == 1
    for _ in range(60):
        f.update(1/60)
    assert len(f.trail) == 0
