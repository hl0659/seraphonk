# asset-pass — headless Blender sprites
1. If `blender` exists: `blender -b -P tools/blender_render.py -- assets/sprites`
2. Else: `python tools/blender_render.py assets/sprites` (placeholders)
3. Commit `asset:` with list of sprites produced.
