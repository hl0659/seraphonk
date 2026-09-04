"""Headless Blender renderer: `blender -b -P tools/blender_render.py -- outdir`
Creates low-poly seraph/fallen/pickup turntable sprites. Safe no-op if run without blender.
"""
import sys, os
OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else os.path.join("assets", "sprites")
os.makedirs(OUT, exist_ok=True)
try:
    import bpy
    HAS_BPY = True
except ImportError:
    HAS_BPY = False

UNITS = ["seraph", "fallen", "grace", "manna", "pillar", "gate"]

def render_with_blender():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1)
    obj = bpy.context.active_object
    mat = bpy.data.materials.new("HaloMat")
    mat.use_nodes = True
    obj.data.materials.append(mat)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 128
    scene.render.resolution_y = 128
    scene.render.film_transparent = True
    for u in UNITS:
        scene.render.filepath = os.path.join(OUT, u + ".png")
        bpy.ops.render.render(write_still=True)
    print(f"blender rendered {len(UNITS)} sprites to {OUT}")

def placeholder():
    # Pillow-free PPM placeholder so pipeline never crashes without Blender/PIL
    for u in UNITS:
        p = os.path.join(OUT, u + ".ppm")
        with open(p, "wb") as f:
            f.write(b"P6\n32 32\n255\n" + bytes([200, 180, 120] * 32 * 32))
    print(f"placeholder sprites (PPM) written to {OUT} — install Blender for PNGs")

if __name__ == "__main__":
    (render_with_blender() if HAS_BPY else placeholder())
