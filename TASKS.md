# TASKS.md — phased checklist

## M0 skeleton [x]
- [x] Repo layout, docs, requirements, CI, smoke entry

## M1 movement prototype [x]
- [x] `engine/movement.py` dash/slide/slam + stamina + coyote/buffer
- [x] Feel: trail, shake, hitstop hooks (headless-testable state, no gfx asserts)
- [x] Playtest scene: empty arena + pillars, 60fps fixed step
- [x] Tests: dash i-frames, slide preserves momentum, slam AoE values

## M2 combat core
- [ ] Auto-weapon + 1 melee + 1 ranged, XP grace + level-up choice (3 options)
- [ ] 1 enemy type + contact damage + grace drop

## M3 run structure
- [ ] Director (budget curve), mini-boss timer, Sanctum Gate + boss, 10:00 Wrath swarm
- [ ] Chests/shrines/vendors, gold/manna, 4-weapon/4-tome caps, stacking items

## M4 assets (headless Blender)
- [ ] `tools/blender_render.py` renders seraph/fallen/pickups to `assets/sprites/`
- [ ] Fallback procedural sprites if Blender absent; loader prefers PNG

## M5 packaging
- [ ] `tools/build_exe.ps1` PyInstaller onefile, smoke exe, CI artifact
- [ ] Balance pass + README run instructions

Each item = one commit + pytest. Check off as you prompt `build next`.
