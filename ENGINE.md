# ENGINE.md — SERAPH Engine (custom, thin-SDL)

## Decision
True from-scratch DirectX/Win32 unmonitored = unreliable. Pragmatic custom engine:
thin `pygame-ce` (SDL2) backend for window/input/audio only. Everything else is ours:
fixed-timestep loop, ECS, physics/movement, spatial hash, waves, asset pipeline.
Still packagable to `.exe` via PyInstaller. No Unity/Godot dependency.

## Modules
- `engine/loop.py` — fixed 60Hz `step(dt)`, decoupled render; `Clock.fixed_accumulator`
- `engine/math2d.py` — Vec2, clamp, lerp, approach
- `engine/ecs.py` — minimal Entity/Component/World (dict + lists, no dep)
- `engine/physics.py` — momentum model, friction, circle collision, spatial hash
- `engine/movement.py` — Ultrakill-adapted top-down with height `z`:
  walk 6.5 u/s, dash 12 u/s burst + i-frames 0.25s, dash-jump preserves momentum,
  slide 8 u/s low-friction + steering (slideways), slam: airborne + slide-key → fast `z` fall + AoE + bounce
- `engine/waves.py` — director: budget scales with time, mini-boss at intervals, final swarm
- `engine/assets.py` — loader: prefers `assets/sprites/*.png`, falls back to procedural surfaces

## Ultrakill numbers (adapted, from wiki research)
Source ULTRAKILL: dash 49.5 u/s + i-frames + momentum reset, slide 24 u/s zero-accel + Slideways +5 u/s side, max 72 u/s preserve-then-friction, slam 100 u/s down + bounce higher than start, dash-storage extends i-frames.
Ours scaled to top-down survivors arena (~10x smaller arena, 60Hz):
`WALK=380 px/s, DASH=950 px/s 0.16s, SLIDE=520 px/s friction 1.8/s, SLAM fall 1400 px/s-z + 120px AoE`.

## Feel checklist (online suggestions distilled)
Coyote 0.08s, input buffer 0.12s, dash trail + FOV kick + hitstop 40ms on slam, screen shake scaled by slam/boss kill, stamina 3 bars regen 1/s paused while sliding, variable jump height, landing dust if fall > threshold.

## Packaging
`tools/build_exe.ps1` runs PyInstaller `--onefile --windowed game/main.py`. CI runs `pytest` + smoke on push.
