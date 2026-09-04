# test-and-fix — green the build
1. Run `python -m pytest -q`
2. Run `python -m game.main --smoke`
3. Fix failures smallest-first, add regression test, commit `fix:` / `test:`.
4. If 2 fixes fail, stop and report hypothesis + evidence.
