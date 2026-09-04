# SERAPHONK — Angelic Movement Survivors-like
Custom engine + headless-Blender pipeline. Megabonk loop x Ultrakill movement.

## Quickstart (Windows PowerShell 5.1)
```powershell
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m pytest -q
python -m game.main --smoke
```

## Layout
- `engine/` — your custom engine: loop, ECS, physics/movement, waves, spatial hash
- `game/` — angelic game data: config, weapons/tomes/items, main entry
- `assets/` — `blender/` source .blend + `sprites/` rendered PNGs + placeholders
- `tools/blender_render.py` — headless `blender -b -P` asset renderer
- `tests/` — headless logic tests (no window needed)
- `.opencode/commands/` — reusable agent workflows
- `TASKS.md` — phased checklist, `game-design.md` — design doc

## Workflow
See `WORKFLOW.md`. Small commits, `pytest` every change, `python -m game.main --smoke` before push.
Packaging: `tools/build_exe.ps1` → PyInstaller `.exe` (see `ENGINE.md`).

## Status
M0 skeleton installed. Next: M1 movement prototype.
