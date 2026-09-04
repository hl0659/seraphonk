# TASKS.md — phased checklist

## M0 skeleton [x]
- [x] Repo layout, docs, requirements, CI, smoke entry

## M1 movement prototype [x]
- [x] `engine/movement.py` dash/slide/slam + stamina + coyote/buffer
- [x] Feel: trail, shake, hitstop hooks (headless-testable state, no gfx asserts)
- [x] Playtest scene: empty arena + pillars, 60fps fixed step
- [x] Tests: dash i-frames, slide preserves momentum, slam AoE values

## M2 combat core (2D ref — optional now)
- [ ] Auto-weapon + 1 melee + 1 ranged, XP grace + level-up choice (3 options)
- [ ] 1 enemy type + contact damage + grace drop

## M3D Godot production track (current)
- [x] Scaffold: project.godot 4.7 Forward+, input map, main.tscn, player.gd, director.gd
- [ ] Install Godot 4.7.2 + templates, open `godot/`, F5 playtest movement
- [ ] Blender .blend → .glb seraph/fallen/arena, import + materials
- [ ] M2-3D: auto-weapons, enemies, XP/level, HUD
- [ ] M3-3D: gate/boss, timer/Wrath, chests/shrines/vendors
- [ ] Export Windows .exe via export_presets.cfg, CI headless export

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
