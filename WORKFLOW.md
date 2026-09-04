# WORKFLOW.md — how we build unmonitored but safe

## Loop
1. Pick smallest unchecked item in `TASKS.md`
2. Implement + add/extend headless test in `tests/` (no window needed)
3. Run `python -m pytest -q`; fix; then `python -m game.main --smoke`
4. Commit: `feat(engine): ...`, `fix(game): ...`, `test: ...`, `asset: ...`, `chore: ...`
5. Push frequently; CI must stay green. Stop and report if 2 fixes fail.

## Commands (for you to prompt me)
- `plan M1` → I break milestone into <200-line steps
- `build next` → I implement next TASKS item + tests + commit
- `test and fix` → I run pytest + smoke, fix failures, commit
- `asset pass` → I run `blender -b -P tools/blender_render.py` or regenerate placeholders
- `package exe` → I run `tools/build_exe.ps1`

## Rules
- Never exceed ~400 lines per change without a test run
- Game feel changes must cite `ENGINE.md` numbers
- No secrets in repo; balance numbers live in `game/config.py`
- If Blender missing, placeholders are acceptable; pipeline must not crash
