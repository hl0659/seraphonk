"""Headless Blender asset forge: builds low-poly angelic set, exports .glb for Godot.
Run: blender -b -P tools/seraph_blender.py -- <outdir>
No bpy outside Blender: refuses to run as plain python (use placeholder path instead).
"""
import sys, os

def outdir():
    if "--" in sys.argv:
        i = sys.argv.index("--")
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return os.path.join("godot", "assets", "models")

OUT = outdir()
os.makedirs(OUT, exist_ok=True)

try:
    import bpy
except ImportError:
    print("seraph_blender needs Blender's bpy; run via: blender -b -P tools/seraph_blender.py -- outdir")
    raise SystemExit(2)

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def mat(name, color, emission, energy):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
    bsdf.inputs["Emission Strength"].default_value = energy
    return m

def export_selected(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                              use_selection=True, export_materials='EXPORT',
                              export_yup=True)

IVORY = mat("Ivory", (0.95, 0.93, 0.85), (1.0, 0.95, 0.75), 0.6)
GOLD = mat("Gold", (0.9, 0.75, 0.4), (1.0, 0.8, 0.3), 2.0)
FALLEN = mat("Fallen", (0.3, 0.08, 0.1), (1.0, 0.15, 0.2), 1.2)
STONE = mat("Stone", (0.5, 0.48, 0.45), (0.4, 0.38, 0.5), 0.3)

def build_seraph():
    clear()
    bpy.ops.mesh.primitive_cone_add(radius1=0.55, depth=1.7, location=(0, 0, 0.85))
    robe = bpy.context.active_object
    robe.data.materials.append(IVORY)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(0, 0, 1.95))
    head = bpy.context.active_object
    head.data.materials.append(IVORY)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.42, minor_radius=0.07, location=(0, 0, 2.45))
    halo = bpy.context.active_object
    halo.data.materials.append(GOLD)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(sx * 0.65, -0.25, 1.4))
        w = bpy.context.active_object
        w.scale = (0.5, 1.1, 1.0)
        w.rotation_euler = (0.5, 0.0, sx * 0.5)
        w.data.materials.append(IVORY)
    bpy.ops.object.select_all(action='SELECT')
    export_selected(os.path.join(OUT, "seraph.glb"))

def build_fallen():
    clear()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6, location=(0, 0, 0.9))
    body = bpy.context.active_object
    body.data.materials.append(FALLEN)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(radius1=0.12, depth=0.5, location=(sx * 0.3, 0, 1.6))
        h = bpy.context.active_object
        h.data.materials.append(FALLEN)
    bpy.ops.object.select_all(action='SELECT')
    export_selected(os.path.join(OUT, "fallen.glb"))

def build_pillar():
    clear()
    bpy.ops.mesh.primitive_cylinder_add(radius=1.1, depth=6.0, location=(0, 3, 0))
    p = bpy.context.active_object
    p.data.materials.append(STONE)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.1, minor_radius=0.12, location=(0, 5.6, 0))
    r = bpy.context.active_object
    r.data.materials.append(GOLD)
    bpy.ops.object.select_all(action='SELECT')
    export_selected(os.path.join(OUT, "pillar.glb"))

def build_gate():
    clear()
    bpy.ops.mesh.primitive_torus_add(major_radius=2.0, minor_radius=0.3, location=(0, 2.6, 0))
    g = bpy.context.active_object
    g.data.materials.append(GOLD)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=2.6, location=(sx * 2.0, 1.3, 0))
        c = bpy.context.active_object
        c.data.materials.append(STONE)
    bpy.ops.object.select_all(action='SELECT')
    export_selected(os.path.join(OUT, "gate.glb"))

build_seraph()
build_fallen()
build_pillar()
build_gate()
print("forged:", sorted(os.listdir(OUT)))
