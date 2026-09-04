def test_budget_grows_and_wrath():
    from engine import waves
    assert waves.budget(600) > waves.budget(60) > waves.budget(0)
    assert waves.is_wrath(600) and not waves.is_wrath(599)
    assert waves.is_miniboss_tick(90) and not waves.is_miniboss_tick(91)
