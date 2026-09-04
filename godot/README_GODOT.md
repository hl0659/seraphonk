# SERAPHONK 3D — Godot production track
Python `engine/` prototype = numbers reference. This `godot/` folder = shippable game.

## Install (you, once)
```powershell
winget install GodotEngine.GodotEngine --version 4.7.2
# open: godot --path godot
# export .exe needs templates once: Editor → Manage Export Templates → Download 4.7
```

## Structure
- `scenes/main.tscn` — arena + player + director bootstrap
- `scripts/player.gd` — CharacterBody3D: walk/dash/dash-jump/slide/slam, i-frames, stamina
- `scripts/director.gd` — budget curve, mini-boss ticks, 10:00 Wrath (ports engine/waves.py)
- `assets/models/` — Blender source .blend, export .glb (File → Export → glTF)
- `export_presets.cfg` — Windows Desktop single-exe (embed pck)

## Blender pipeline (5.2.1, working)
```powershell
blender -b godot/assets/models/seraph.blend -o //../../gen/seraph -a  # or File → Export glTF
# Keep low-poly (<5k tris), bake 128px halo/emissive, Y-up, +Z forward for Godot
```

## Numbers (from prototype, scaled to 3D m/s)
walk 7.5, dash 19.0 0.16s + iframes 0.25s, slide 10.5 friction, slam 28 m/s down + 3m AoE.
Feel: coyote 0.08, buffer 0.12, hitstop 40ms, trauma shake — see player.gd constants.
