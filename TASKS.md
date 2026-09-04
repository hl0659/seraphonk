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

## M3D Godot production track [x core loop shippable]
- [x] Scaffold: project.godot 4.7 Forward+, input map, main.tscn, player.gd, director.gd
- [x] Fix scene parse error (BoxShape3D sub_resource), all scripts --check-only clean
- [x] Movement: dash/dash-jump/slide/slam + i-frames/stamina/coyote/buffer (Ultrakill-adapted)
- [x] Combat: chakram orbit + trumpet volley, 3 enemy reads, elites, knockback, hit-flash
- [x] Loop: XP/magnet, level draft (3 blessings), tomes stacking, gold, shrines (3s channel), chests (gold), gate unseal 5:00 + Warden boss + victory, 10:00 Wrath, death/pause/restart
- [x] Juice: trauma shake, hitstop, FOV kick, damage numbers (capped), procedural SFX (10 synth voices)
- [x] Assets: headless Blender 5.2 forge (seraph/fallen/pillar/gate .glb) wired with primitive fallback
- [x] Export: 4.7.2 templates installed, Windows .exe (109MB, boots 300f headless clean)
- [ ] Balance pass with human playtests (numbers are math-derived, need feel iteration)
- [ ] More content: 2 extra weapons, evolutions, vendors, meta Silver progression, settings (shake slider/volume)

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
