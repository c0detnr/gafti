"""Generate Pusludere architecture and its GLB previews."""
from math import atan2, cos, pi, sin, sqrt
from pathlib import Path
from random import Random

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/models/town"
PREVIEWS = ROOT / "tools/previews"
COLORS = {
    "Stone": "535959 6E706A 838078 635C54 92918A",
    "Cobble": "6D7470 81857B 777A73 969185",
    "Wood": "623C28 764A30 895338 986543 A3714D",
    "Oak": "C18756 A67045 D29A66", "Dark": "312D2A", "Cream": "F3D9A9",
    "Window": "305460", "Glint": "618687", "Amber": "FFB05B",
    "Copper": "A5563A 944630 B46044 AD553E", "Moss": "426754 395C50 527763 4C705B",
    "Blue": "3E6875 477684 547B86 40606C", "Zinc": "626C71 788185 68777D 899193",
    "Red": "8F3E32 A94732 A7553A", "Ochre": "BA793F C88949 D89753",
    "Green": "35754F 428B5B 3D7E53", "Lichen": "758550 96A35D",
    "Rubber": "282E30", "Metal": "ADAAA0", "Ivory": "E8E0CA",
}
pieces, materials = {}, {}
rng = Random(23)


def linear_color(code):
    channels = (int(code[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in channels)


def material(name, code, roughness=.82):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*linear_color(code), 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def swatch(group):
    code = rng.choice(COLORS[group].split())
    if code not in materials:
        materials[code] = material(f"{group} {code}", code, .35 if group == "Window" else .82)
    return materials[code]


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pieces.clear()
    materials.clear()
    rng.seed(23)


def mesh(name, vertices, faces, mat=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    if mat:
        data.materials.append(mat)
    return obj


def part(obj, name):
    pieces.setdefault(name, []).append(obj)
    return obj


def bevel(obj, amount):
    if amount:
        modifier = obj.modifiers.new("Soft edges", "BEVEL")
        modifier.width = amount
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def box(name, loc, size, color=None, soft=0):
    x, y, z = (axis / 2 for axis in size)
    verts = [(-x,-y,-z), (x,-y,-z), (x,y,-z), (-x,y,-z),
             (-x,-y,z), (x,-y,z), (x,y,z), (-x,y,z)]
    faces = [(3,2,1,0), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7), (4,5,6,7)]
    obj = mesh(name, verts, faces, swatch(color) if color else None)
    obj.location = loc
    bevel(obj, soft)
    return part(obj, name)


def beam(name, a, b, width, depth, color, soft=0):
    a, b = Vector(a), Vector(b)
    obj = box(name, (a + b) / 2, (width, depth, (b - a).length), color, soft)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return obj


def tube(name, loc, radius, depth, color, axis="Z", segments=12, soft=0):
    rotation = (0, pi / 2, 0) if axis == "X" else (pi / 2, 0, 0) if axis == "Y" else (0, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=depth,
                                       location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.data.materials.append(swatch(color))
    bevel(obj, soft)
    return part(obj, name)


def letters(body, x, y, z, size, color="Cream"):
    curve = bpy.data.curves.new(body, "FONT")
    curve.body = body
    curve.align_x = curve.align_y = "CENTER"
    curve.size, curve.resolution_u = size, 2
    obj = bpy.data.objects.new(body, curve)
    bpy.context.collection.objects.link(obj)
    obj.location, obj.rotation_euler.x = (x, y, z), pi / 2
    curve.materials.append(swatch(color))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    part(bpy.context.object, "Sign")


def combine():
    result = []
    for name, objects in pieces.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        obj = bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        obj.name = obj.data.name = name
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        result.append(obj)
    return result


def export(name, objects, limit):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    counts = {}
    for obj in objects:
        obj.select_set(True)
        obj.data.calc_loop_triangles()
        counts[obj.name] = len(obj.data.loop_triangles)
    if sum(counts.values()) > limit:
        raise ValueError(f"{name}: {sum(counts.values())} triangles exceed {limit}: {counts}")
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / f"{name}.glb"), export_format="GLB",
                              use_selection=True, export_yup=True, export_animations=False)
    print(f"TOWN_ASSET {name} {sum(counts.values())} {counts}", flush=True)


def camera(location, target, scale):
    data = bpy.data.cameras.new("Preview camera")
    cam = bpy.data.objects.new("Preview camera", data)
    bpy.context.collection.objects.link(cam)
    cam.location = location
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    data.type, data.ortho_scale, data.clip_end = "ORTHO", scale, 1800
    bpy.context.scene.camera = cam
    return cam


def light(name, kind, location, target, energy, color, size):
    data = bpy.data.lights.new(name, kind)
    data.energy, data.color = energy, color
    if kind == "AREA":
        data.shape, data.size = "DISK", size
    else:
        data.angle = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def render(name):
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 24
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEWS / f"{name}.png")
    scene.view_settings.view_transform = "AgX"
    bpy.ops.render.render(write_still=True)


def studio(name, scale, direction, target):
    for obj in bpy.context.scene.objects:
        if obj.name.endswith("-col"):
            obj.hide_render = True
    bpy.context.scene.world = bpy.data.worlds.new("Studio")
    z = -.93 if name == "bridge" else -.025
    mesh("Backdrop", [(-100,-100,z), (100,-100,z), (100,100,z), (-100,100,z)],
         [(0,1,2,3)], material("Dried sage", "708478"))
    camera(Vector(target) + Vector(direction) * 15, target, scale * 1.075)
    light("Sun", "SUN", (-8,-10,16), (0,0,0), 2.6, (1,.83,.67), .16)
    light("Sky", "AREA", (2,-6,10), target, 2200, (.69,.85,1), 12)
    light("Bounce", "AREA", (-4,7,8), target, 2300, (1,.70,.47), 9)
    render(name)


def window(x, y, z, w, h, trim, shutter=False, awning=False):
    box("Windows", (x,y,z), (w,.14,h), "Dark", .032)
    box("Windows", (x,y-.079,z), (w-.13,.03,h-.13), "Window")
    for side in (-1, 1):
        box("Windows", (x+side*(w/2-.036),y-.067,z), (.085,.13,h), trim, .013)
        box("Windows", (x,y-.067,z+side*(h/2-.036)), (w,.13,.08), trim, .014)
        if shutter:
            sx = x + side * (w / 2 + .16)
            box("Shutters", (sx,y-.065,z), (.29,.095,h-.04), trim, .022)
            for offset in (-.23, 0, .23):
                box("Shutters", (sx,y-.12,z+offset*h), (.25,.04,.039), "Oak")
    box("Windows", (x,y-.092,z), (.062,.07,h-.13), trim, .007)
    box("Windows", (x,y-.095,z-.06), (w-.14,.07,.052), trim, .007)
    box("Windows", (x,y-.09,z-h/2-.025), (w+.18,.23,.09), "Oak", .014)
    for j in (-1, 1):
        obj = box("Windows", (x+j*w*.24,y-.098,z+h*.24), (w*.26,.009,.036), "Glint")
        obj.rotation_euler.y = -.42
    if awning:
        canopy(x, y, z + h / 2, w + .25, .44, 7, trim)


def canopy(x, y, z, w, reach, panels, trim):
    for j in range(panels):
        shade = "Cream" if j % 2 else trim
        px = x + (j + .5 - panels / 2) * w / panels
        beam("Canopy", (px,y-reach,z+.07), (px,y,z+.29), w/panels, .048, shade)
        box("Canopy", (px,y-reach,z+.025), (w/panels,.045,.13), shade, .012)


def stone(loc, width, height, angle=0):
    # An inset face and four chamfers cover the backing wall with ten triangles.
    x, z, cut = width / 2, height / 2, .047
    verts = [(-x,0,-z),(x,0,-z),(x,0,z),(-x,0,z),
             (-x+cut,-.075,-z+cut),(x-cut,-.075,-z+cut),
             (x-cut,-.075,z-cut),(-x+cut,-.075,z-cut)]
    faces = [(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
    obj = mesh("Stonework", verts, faces, swatch("Stone"))
    obj.location, obj.rotation_euler.z = loc, angle
    part(obj,"Stonework")


def masonry(x1, x2, y, top):
    for row in range(2):
        x = x1
        while x < x2 - .10:
            step = min(x2 - x, rng.uniform(.48,.86) if x > x1 or not row else .31)
            stone((x+step/2,y+rng.uniform(-.021,.006),(row+.5)*top/2),
                  step-.033,top/2-.035)
            x += step


def roof(w, d, eave, rise, color, overhang=.57):
    half, length = w / 2 + overhang, d + 2 * overhang
    spans = round(length / .31)
    for side in (-1, 1):
        for i in range(spans):
            spacing = length / spans
            y = -length / 2 + (i + .5) * spacing
            beam("Roof", (side*half,y,eave), (0,y,eave+rise), .084, spacing+.008, color)
            y -= spacing / 2
            beam("Roof seams", (side*half,y,eave+.055), (0,y,eave+rise+.055), .042,.038,color)
        for y in (-length/2, length/2):
            beam("Fascia", (side*(half+.02),y,eave-.09), (0,y,eave+rise-.09), .176,.14,"Oak",.016)
        box("Fascia", (side*(half+.035),0,eave-.12), (.15,length,.19), "Wood", .024)
    box("Roof", (0,0,eave+rise+.04), (.18,length+.10,.14), color, .04)


def gables(w, d, eave, rise):
    for side in (-1, 1):
        y, count = side * d / 2, round(w / .24)
        for i in range(count):
            a, b = (i - count / 2) * w / count, (i + 1 - count / 2) * w / count - .013
            za, zb = [eave + rise * (1 - abs(x) / (w / 2 + .57)) - .09 for x in (a,b)]
            verts = [(a,y-.044,eave-.12),(b,y-.044,eave-.12),(b,y-.044,zb),(a,y-.044,za),
                     (a,y+.044,eave-.12),(b,y+.044,eave-.12),(b,y+.044,zb),(a,y+.044,za)]
            faces = [(0,1,2,3),(7,6,5,4),(0,4,5,1),(3,2,6,7),(0,3,7,4),(1,5,6,2)]
            part(mesh("Gables", verts, faces, swatch("Wood")), "Gables")

BUILDINGS = {
    "shop_building": (8.56, 6.56, 3.62, 1.39, 0, 1.84, "Moss", "Green", "GAFTİ"),
    "kahvehane": (8.10, 5.85, 4.17, 1.47, -.78, 1.55, "Copper", "Red", "FADİME'NİN KAHVEHANESİ"),
    "muhtarlik": (6.42, 5.40, 4.66, 2.02, 0, 1.48, "Moss", "Moss", "MUHTARLIK"),
    "hardware_store": (7.94, 5.67, 3.49, 1.28, 1, 1.80, "Zinc", "Ochre", "HIRDAVAT"),
    "inspection_office": (7.19, 5.86, 4.06, 1.51, 0, 1.55, "Blue", "Blue", "LİSANS & DENETİM"),
    "drying_barn": (6.8, 5.8, 3.76, 1.76, 0, 2.20, "Copper", "Wood", None),
}


def wall(name, loc, size, color):
    box(name, loc, size, color)
    box("Shell-col", loc, size)


def building(name):
    w, d, eave, rise, door_x, door_w, metal, trim, label = BUILDINGS[name]
    front = -d / 2
    door_h, plinth = (2.60, .68) if name == "drying_barn" else (2.26, 1.03)
    box("Floor", (0,0,.009), (w,d,.018), "Dark")
    box("Shell-col", (0,0,.019), (w,d,.038))
    for i in range(round(w/.28)):
        step = (w-.56) / round(w/.28)
        x = -(w-.56)/2 + (i+.5)*step
        box("Floorboards", (x,0,.028), (step-.004,d-.27,.02), "Oak")
    wall("Walls", (0,-front-.14,eave/2), (w,.28,eave), "Wood")
    for side in (-1, 1):
        x = side * (w / 2 - .14)
        wall("Walls", (x,0,eave/2), (.28,d-.56,eave), "Wood")
        for i in range(round(d/.29)):
            step = (d-.46) / round(d/.29)
            y = -(d-.46)/2 + (i+.5)*step
            box("Cladding", (side*w/2,y,(eave+plinth)/2),
                (.09,step-.013,eave-plinth), "Wood")
        for row in range(2):
            count = round((d-.46)/.66)
            for i in range(count):
                step = (d-.46) / count
                y = -(d-.46)/2 + (i+.5)*step + (.073 if row and i < count-1 else 0)
                stone((side*w/2,y,(row+.5)*plinth/2), step-.038,plinth/2-.039,side*pi/2)
        box("Frame", (side*(w/2+.055),0,plinth+.035), (.145,d+.15,.14), "Oak", .022)
    left, right = door_x-door_w/2, door_x+door_w/2
    for x1, x2 in ((-w/2,left),(right,w/2)):
        wall("Walls", ((x1+x2)/2,front+.14,eave/2), (x2-x1,.28,eave), "Wood")
        masonry(x1+.08, x2-.08, front-.012, plinth)
        count = round((x2-x1)/.23)
        for i in range(count):
            step = (x2-x1) / count
            box("Cladding", (x1+(i+.5)*step,front-.011,(plinth+eave)/2),
                (step-.011,.065,eave-plinth), "Wood")
        box("Frame", ((x1+x2)/2,front-.075,plinth+.027), (x2-x1,.16,.15), "Oak", .018)
    wall("Walls", (door_x,front+.14,(door_h+eave)/2), (door_w,.28,eave-door_h), "Wood")
    for x in (-w/2+.045, w/2-.045):
        for y in (front-.02, -front+.02):
            box("Frame", (x,y,eave/2), (.25,.23,eave), "Oak", .025)
    for side in (-1,1):
        box("Doorframe", (door_x+side*(door_w/2+.068),front-.07,door_h/2),
            (.17,.25,door_h), trim, .025)
    box("Doorframe", (door_x,front-.084,door_h+.040), (door_w+.25,.26,.17), trim, .027)
    box("Threshold", (door_x,front+.042,.026), (door_w,.67,.052), "Cobble", .013)
    box("Threshold-col", (door_x,front+.042,.026), (door_w,.67,.052))
    if label:
        for x1, x2 in ((-w/2,left),(right,w/2)):
            width = min(x2-x1-.49, 2.16 if name == "shop_building" else 1.63)
            window((x1+x2)/2, front-.09, 1.67, width, .99, trim,
                   name in ("kahvehane","muhtarlik"), name == "shop_building")
        sign_width = {"shop_building":2.81,"kahvehane":5.78,"muhtarlik":2.79,
                      "hardware_store":2.55,"inspection_office":4.19}[name]
        sx = 0 if name in ("kahvehane","inspection_office") else door_x
        sz = 2.87 if name == "kahvehane" else 2.78
        sign(label, sx, front-.145, sz, sign_width, .56, trim, .42 if name=="shop_building" else .30)
    customize(name, front, w, d, eave)
    gables(w, d, eave, rise)
    roof(w, d, eave, rise, metal)
    box("Ceiling-col", (0,0,eave-.135), (w,d,.17))
    box("Ceiling", (0,0,eave-.135), (w,d,.15), "Wood")


def sign(label, x, y, z, w, h, color, size):
    box("Sign", (x,y,z), (w,.17,h), "Oak", .036)
    box("Sign", (x,y-.098,z), (w-.14,.075,h-.13), color, .022)
    letters(label, x, y-.141, z, size)
    for side in (-1, 1):
        tube("Sign", (x+side*(w/2-.135),y-.15,z), .025,.021,"Amber","Y",8)


def lantern(x, y, z):
    box("Lanterns", (x,y+.12,z+.22), (.14,.37,.08), "Dark", .014)
    box("Lanterns", (x,y,z), (.20,.20,.33), "Amber", .027)
    for dx in (-.094,.094):
        for dy in (-.094,.094):
            box("Lanterns", (x+dx,y+dy,z), (.028,.028,.34), "Dark")
    for dz in (-.17,.17):
        box("Lanterns", (x,y,z+dz), (.245,.245,.052), "Dark", .016)


def chimney(x, y, z):
    box("Chimney", (x,y,z), (.56,.65,1.29), "Stone", .055)
    for dz in (-.36,-.09,.18,.45):
        box("Chimney", (x,y,z+dz), (.60,.69,.062), "Cobble", .021)
    box("Chimney", (x,y,z+.62), (.76,.79,.13), "Dark", .039)


def customize(name, front, w, d, eave):
    if name == "shop_building":
        for x in (-1.68,1.68):
            lantern(x,front-.23,2.34)
        chimney(2.65,.91,eave+.15)
    elif name == "kahvehane":
        window(0, front-.10, 3.64, 1.22, .56, "Oak", True)
        chimney(-1.98,1.07,eave+.77)
        for x in (1.24,3.02):
            box("Porch", (x,front-.72,.26), (.12,.39,.52), "Wood", .02)
        box("Porch", (2.13,front-.72,.52), (2.05,.42,.09), "Oak", .024)
        box("Porch-col", (2.13,front-.72,.27), (2.05,.42,.54))
        canopy(2.11, front-.09, 2.27, 3.31, .91, 12, "Red")
        for x in (.46,3.76):
            beam("Canopy",(x,front,2.10),(x,front-.94,2.34),.067,.074,"Wood")
    elif name == "muhtarlik":
        window(0, front-.10, 3.58, 1.31, 1.02, "Oak", True)
        for x in (-2.04,2.04):
            beam("Frame",(0,front-.12,4.39),(x,front-.12,3.27),.16,.10,"Oak",.019)
        x = 1.70
        beam("Banner",(x,front,2.61),(x,front-.66,3.18),.061,.061,"Dark")
        box("Banner",(x,front-.59,2.82),(.33,.055,.51),"Red",.013)
        tube("Banner",(x,front-.624,2.85),.095,.012,"Cream","Y",16)
        tube("Banner",(x+.034,front-.634,2.87),.077,.010,"Red","Y",16)
    elif name == "hardware_store":
        for x in (-.47,2.47):
            lantern(x,front-.24,2.41)
        for x,z,size in ((-2.91,.25,.48),(-2.29,.29,.56),(-2.29,.72,.36)):
            box("Crates",(x,front-.46,z),(size,.48,size),"Wood",.033)
            for zz in (z-size*.36,z+size*.36):
                box("Crates",(x,front-.71,zz),(size,.055,.065),"Oak",.015)
        box("Crates-col",(-2.60,front-.46,.29),(1.10,.48,.58))
        box("Crates-col",(-2.29,front-.46,.72),(.36,.48,.36))
    elif name == "inspection_office":
        for x in (-2,2):
            window(x,front-.07,3.44,.92,.53,"Blue")
        for x in (-1.06,1.06):
            lantern(x,front-.24,2.29)
        box("Frame",(0,front-.08,3.94),(w,.13,.14),"Blue",.025)
    else:
        for x in (-2.10,2.10):
            for offset in (-.18,0,.18):
                box("Vents",(x+offset,front-.056,2.68),(.11,.03,.61),"Dark",.012)
            beam("Frame",(x-.72,front-.093,1.08),(x+.61,front-.093,2.35),.14,.13,"Oak",.012)
        for side in (-1,1):
            for y in (-d/2+.47,0,d/2-.47):
                box("Frame",(side*w/2,y,eave*.52),(.19,.21,eave*.86),"Oak",.018)
        window(0,front-.06,3.36,.82,.48,"Wood",True)


def bus_stop():
    w, d = 4.52, 2.30
    wall("Platform",(0,0,.020),(w,d,.040),"Cobble")
    for x in (-1.97,1.97):
        for y in (-.87,.86):
            wall("Frame",(x,y,1.16),(.19,.19,2.32),"Oak")
            box("Footings",(x,y,.13),(.34,.34,.26),"Stone",.042)
            beam("Frame",(x,y,1.96),(x*.83,y,2.31),.14,.14,"Wood",.017)
    for i in range(16):
        box("Back wall",((i-7.5)*.237,.90,.94),(.221,.123,1.81),"Wood",.020)
    box("Back-col",(0,.90,.94),(3.79,.123,1.81))
    for x in (-1.28,1.28):
        box("Bench",(x,.46,.26),(.23,.42,.49),"Stone",.043)
    for y in (.25,.43,.61):
        box("Bench",(0,y,.53),(3.08,.167,.10),"Oak",.029)
    box("Bench-col",(0,.43,.28),(3.08,.61,.56))
    sign("PUSLUDERE",0,-.96,2.24,2.20,.39,"Moss",.27)
    box("Timetable",(1.30,.817,1.50),(.56,.097,.50),"Cream",.019)
    for i in range(4):
        box("Timetable",(1.25,.763,1.61-i*.075),(.25,.012,.014),"Ochre")
        box("Timetable",(1.43,.763,1.61-i*.075),(.052,.012,.015),"Dark")
    box("Ceiling-col",(0,0,2.38),(4.55,2.35,.16))
    roof(w,d,2.48,.74,"Copper",.31)

def loft(name, rings, colors, belt=None):
    count = len(rings[0])
    verts = [point for ring in rings for point in ring]
    ends = [tuple(range(count))] if belt is None else [
        tuple(range(belt[0]+1)) + tuple(range(belt[1],count)), tuple(range(belt[0],belt[1]+1))]
    faces = ends.copy()
    for j in range(len(rings)-1):
        for i in range(count):
            a, b = j * count + i, j * count + (i+1) % count
            faces.append((a,a+count,b+count,b))
    faces.extend(tuple(len(verts)-count+i for i in reversed(face)) for face in ends)
    obj = mesh(name, verts, faces)
    for color in colors:
        obj.data.materials.append(swatch(color))
    if belt is not None:
        for face in obj.data.polygons:
            face.material_index = int(face.center.z > 1.29)
    return part(obj,name)


def minibus():
    profile = [(-.90,.40),(-1.04,.55),(-1.08,1.37),(-1.07,2.16),(-.99,2.40),(-.78,2.54),
               (.78,2.54),(.99,2.40),(1.07,2.16),(1.08,1.37),(1.04,.55),(.90,.40)]
    rings = [[(x*sx,y,.40+(z-.40)*sz) for x,z in profile]
             for y,sx,sz in ((2.48,.88,.94),(2.35,1,1),(-1.96,1,1),(-2.34,.97,.93),(-2.49,.85,.82))]
    loft("Body", rings, ("Green","Ivory"), belt=(2,9))
    box("Body-col",(0,0,1.28),(2.12,4.88,2.56))
    for side in (-1,1):
        x = side*1.08
        box("Beltline",(x,.03,1.38),(.051,4.62,.105),"Green",.015)
        for y,width in ((-1.68,.54),(-.96,.67),(-.08,.91),(.96,1.01),(1.88,.69)):
            box("Windows",(x,y,1.90),(.083,width,.65),"Dark",.05)
            box("Windows",(x+side*.045,y,1.91),(.026,width-.13,.52),"Window",.026)
            box("Windows",(x+side*.060,y+.075,2.05),(.010,width*.54,.038),"Glint")
        wheel_height = .4284
        for y in (-1.53,1.57):
            tube("Wheel arches",(side*1.05,y,.53),.53,.14,"Dark","X",18)
            tube("Wheels",(side*1.00,y,wheel_height),.435,.30,"Rubber","X",18,.047)
            tube("Wheels",(side*1.153,y,wheel_height),.226,.034,"Ivory","X",14,.017)
            tube("Wheels",(side*1.18,y,wheel_height),.10,.025,"Metal","X",12)
            for i in range(5):
                angle = i*2*pi/5
                tube("Wheels",(side*1.174,y+cos(angle)*.162,wheel_height+sin(angle)*.162),
                     .024,.019,"Dark","X",6)
        for y in (-1.84,-.62):
            box("Trim",(side*1.106,y,1.24),(.048,.19,.041),"Metal",.013)
        beam("Mirrors",(side*.98,-2.08,1.99),(side*1.35,-2.20,1.94),.05,.05,"Dark")
        box("Mirrors",(side*1.34,-2.21,1.99),(.19,.12,.31),"Green",.030)
        box("Mirrors",(side*1.34,-2.14,1.99),(.14,.025,.24),"Glint",.027)
        tube("Lights",(side*.66,-2.495,1.04),.199,.11,"Dark","Y",16,.020)
        tube("Lights",(side*.66,-2.558,1.04),.159,.058,"Ivory","Y",16,.025)
        box("Lights",(side*.79,-2.48,.762),(.26,.12,.105),"Amber",.026)
        box("Lights",(side*.82,2.47,.97),(.18,.13,.32),"Red",.039)
    for x in (-.43,.43):
        box("Windows",(x,-2.465,1.76),(.79,.097,.57),"Dark",.045)
        box("Windows",(x,-2.522,1.77),(.69,.028,.47),"Window",.035)
        beam("Wipers",(x-.25,-2.549,1.58),(x+.16,-2.549,1.74),.032,.029,"Dark")
        glint = box("Windows",(x+.03,-2.542,1.93),(.42,.013,.050),"Glint")
        glint.rotation_euler.y = -.28
        box("Windows",(x,2.465,1.83),(.72,.096,.63),"Window",.045)
    box("Grille",(0,-2.521,1.03),(.87,.081,.31),"Dark",.045)
    for i in range(4):
        box("Grille",(0,-2.569,.932+i*.063),(.72,.036,.019),"Metal",.007)
    for y in (-2.50,2.50):
        box("Bumpers",(0,y,.49),(2,.20,.20),"Metal",.062)
        box("Bumpers",(0,y*1.022,.49),(1.68,.12,.09),"Dark",.026)
    box("Sign",(0,-2.493,2.075),(1.05,.075,.17),"Cream",.021)
    letters("PUSLUDERE",0,-2.535,2.075,.133,"Dark")
    for x in (-.63,.63):
        for y in (-.95,.83):
            box("Roof rack",(x,y,2.60),(.10,.10,.15),"Metal",.015)
        box("Roof rack",(x,-.04,2.70),(.047,2.19,.047),"Metal",.012)
    for y in (-1.05,-.63,-.21,.21,.63,1.05):
        box("Roof rack",(0,y,2.69),(1.26,.041,.041),"Metal",.007)


def bridge_height(y):
    return 1 + .58 * (1 - (y / 5) ** 2) ** 1.5


def arch_stone(x, start, end):
    points = [(start,1),(end,1),(end,1.23),(start,1.23)]
    verts = [(xx,3.25*r*cos(a),-.24+1.37*r*sin(a))
             for xx in (x-.10,x+.10) for a,r in points]
    faces = [(0,1,2,3),(7,6,5,4),(4,5,1,0),(5,6,2,1),(6,7,3,2),(7,4,0,3)]
    obj = mesh("Voussoirs", verts, faces, swatch("Cobble"))
    bevel(obj,.014)
    part(obj,"Voussoirs")


def deck_tile(x, y, z, width, length):
    w, l, inset = width/2, length/2, .028
    verts = [(-w,-l,0),(w,-l,0),(w,l,0),(-w,l,0),
             (-w+inset,-l+inset,.053),(w-inset,-l+inset,.053),
             (w-inset,l-inset,.053),(-w+inset,l-inset,.053)]
    faces = [(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
    obj = mesh("Cobbled deck",verts,faces,swatch("Cobble"))
    obj.location = (x,y,z)
    return part(obj,"Cobbled deck")


def bridge():
    # Place the origin at creek-bed height. Both ramp ends sit about 1 m above it.
    angles = [i*pi/16 for i in range(17)]
    profile = sorted({-5,5,-4.25,4.25,*[3.25*cos(a) for a in angles]})
    sections = []
    for y in reversed(profile):
        under = -.24 + 1.37 * sqrt(max(0,1-(y/3.25)**2))
        sections.append([(-1.38,y,under),(-1.38,y,bridge_height(y)),
                         (1.38,y,bridge_height(y)),(1.38,y,under)])
    loft("Arch", sections, ("Stone",))
    loft("Arch-col", sections, ())
    for side in (-1,1):
        for a,b in zip(angles,angles[1:]):
            arch_stone(side*1.37,a+.010,b-.010)
        for row in range(4):
            for i in range(16):
                y = (i-7.5)*.61 + (.09 if row%2 else 0)
                bottom = bridge_height(y)-.25-row*.21
                edge = max(0,abs(y)-.30)
                arch_top = -.24+1.69*sqrt(max(0,1-(edge/4)**2))
                if bottom >= arch_top:
                    box("Spandrel",(side*1.38,y,bottom+.086),(.14,.567,.18),"Stone",.031)
        for i in range(16):
            a, b = -5+i*.625, -5+(i+1)*.625
            y = (a+b)/2
            za, zb = bridge_height(a), bridge_height(b)
            z = (za+zb)/2
            pitch = atan2(zb-za,b-a)
            for name, height, size, color, soft in (
                    ("Parapets",.292,(.35,.616,.56),"Stone",.037),
                    ("Parapets",.602,(.43,.617,.13),"Cobble",.035),
                    ("Parapets-col",.32,(.38,.64,.66),None,0)):
                box(name,(side*1.25,y,z+height),size,color,soft).rotation_euler.x = pitch
            if i in (1,4,10,14):
                box("Lichen",(side*1.45,y,z+.14),(.016,.20,.085),"Lichen",.007)
        for y in (-4.81,4.81):
            box("End piers",(side*1.25,y,1.09),(.60,.43,1.43),"Stone",.061)
            box("End piers",(side*1.25,y,1.84),(.66,.48,.14),"Cobble",.041)
            box("Parapets-col",(side*1.25,y,1.09),(.57,.41,1.60))
    for i in range(19):
        a,b = -5+i*10/19, -5+(i+1)*10/19
        y = (a+b)/2
        pitch = atan2(bridge_height(b)-bridge_height(a),b-a)
        for j in range(4):
            x = (j-1.5)*.50 + (.041 if i%2 else -.041)
            tile = deck_tile(x,y,bridge_height(y),.475,b-a-.021)
            tile.rotation_euler.x = pitch
    coords = [(x,y,bridge_height(y)+.048) for y in profile for x in (-1.14,1.14)]
    faces = [(i,i+1,i+3,i+2) for i in range(0,len(coords)-2,2)]
    part(mesh("Deck-col",coords,faces),"Deck-col")


def main():
    for name in (*BUILDINGS,"bus_stop","minibus","bridge"):
        reset_scene()
        if name in BUILDINGS:
            building(name)
        else:
            globals()[name]()
        export(name,combine(),8000)
        if name == "bridge":
            studio(name,11.6,(1.05,-.62,.50),(0,0,.43))
        elif name == "minibus":
            studio(name,6.25,(.86,-1,.49),(0,0,1.17))
        elif name == "bus_stop":
            studio(name,6.25,(.54,-1,.56),(0,0,1.38))
        else:
            w,d,eave,rise,*_ = BUILDINGS[name]
            studio(name,w+3.60,(.50,-1,.49),(0,0,(eave+rise)*.46))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import os
        import tempfile
        import traceback
        diagnostic = Path(tempfile.gettempdir()) / "gafti_town_error.txt"
        diagnostic.write_text(traceback.format_exc(), encoding="utf-8")
        traceback.print_exc()
        os._exit(1)







