"""Generate the GAFTI prop GLBs and Blender previews from one metre-scale source."""
from math import cos, pi, sin, tau
from pathlib import Path
from random import Random
import json
import struct
import sys

import bpy
import numpy as np
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "assets" / "models" / "props"
PREVIEWS = ROOT / "tools" / "previews"
SIZE = 512


def material(name, hex_color, roughness=.65, metal=0, alpha=1, emission=0):
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    rgb = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb]
    rgba = (*rgb, alpha)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    for socket, value in (
        ("Base Color", rgba), ("Roughness", roughness), ("Metallic", metal),
        ("Alpha", alpha), ("Emission Color", rgba), ("Emission Strength", emission),
    ):
        bsdf.inputs[socket].default_value = value
    if alpha < 1:
        mat.surface_render_method = "BLENDED"
        mat.use_transparency_overlap = False
    return mat


def palette():
    specifications = {
        "wood": ("Honey pine", "A5653C"), "light": ("Fresh cut pine", "D79458"),
        "dark": ("End grain", "633A2A"), "grain": ("Burnished grain", "B77748"),
        "green": ("Forest enamel", "28765A", .39, .18),
        "mint": ("Sage enamel", "5DAA83", .42, .1),
        "pine": ("Pine shadow", "214F43"), "fern": ("Spruce needles", "28745C"),
        "leaf": ("Rainlit tea leaves", "75A848", .51), "tea": ("Tea leaves", "427C3B"),
        "olive": ("Sunlit needles", "6C9A56"), "orange": ("Pumpkin enamel", "D97737", .42, .16),
        "clay": ("Terracotta", "AE5139"), "rim": ("Glazed terracotta", "DD7852", .37),
        "black": ("Charcoal rubber", "263537", .8), "steel": ("Blued iron", "48626B", .37, .62),
        "silver": ("Brushed steel", "9AB6B2", .32, .55),
        "gold": ("Aged brass", "CF9C55", .35, .58),
        "cream": ("Oat linen", "EBCB99", .88),
        "cloth_dark": ("Deep spruce fabric", "386858", .91),
        "cloth": ("Pine woven fabric", "588D6D", .91),
        "cloth_light": ("Sage woven fabric", "7BA584", .94),
        "rust": ("Brick weave", "AD4B43", .88), "rose": ("Rose weave", "D97B60", .8),
        "glass": ("Sea-green glass", "94DCCE", .1, .15, .32),
        "mirror": ("Silvered glass", "B5D8D5", .11, .86),
        "glow": ("Warm amber filament", "FFB760", .31, 0, 1, 3),
        "screen": ("Jade display", "77E6B3", .37, 0, 1, .7),
        "cork": ("Speckled cork", "C68A56", .88),
        "stone": ("Wet slate", "536974", .43), "stone_light": ("Rainlit slate", "81949B", .49),
        "stone_dark": ("Slate seams", "394F59", .5), "moss": ("Moss", "617F38", .94),
        "soil": ("Potting soil", "554133", .95),
        "proxy": ("Invisible collision proxy", "000000", 1, 0, 0),
    }
    return {key: material(*spec) for key, spec in specifications.items()}


COLORS = {}


def finish(obj, name, tone, bevel=0, smooth=False):
    obj.name = name
    obj.data.name = name
    if tone:
        obj.data.materials.append(COLORS[tone])
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    if bevel:
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new("Soft edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        modifier.harden_normals = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        normals = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        normals.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=normals.name)
    return obj


def mesh(name, vertices, faces, tone=None, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, tone, smooth=smooth)


def box(center, dimensions, tone, bevel=0, angle=0, name="Piece"):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=(0, 0, angle))
    obj = bpy.context.object
    obj.scale = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, tone, bevel, smooth=bool(bevel))


def lathe(profile, tone, center=(0, 0, 0), sides=16, name="Turned piece", closed=False):
    vertices = [(radius * cos(tau * j / sides), radius * sin(tau * j / sides), z)
                for radius, z in profile for j in range(sides)]
    faces = [(i * sides + j, i * sides + (j + 1) % sides,
              (i + 1) * sides + (j + 1) % sides, (i + 1) * sides + j)
             for i in range(len(profile) - 1) for j in range(sides)]
    if closed:
        last = (len(profile) - 1) * sides
        faces.extend((last + j, last + (j + 1) % sides, (j + 1) % sides, j)
                     for j in range(sides))
    else:
        faces.extend([tuple(reversed(range(sides))),
                      tuple(range((len(profile) - 1) * sides, len(profile) * sides))])
    obj = mesh(name, vertices, faces, tone, smooth=True)
    obj.location = center
    if not closed:
        for polygon in obj.data.polygons[-2:]:
            polygon.use_smooth = False
    return obj


def rod(start, end, radius, tone, tip=None, sides=8):
    direction = Vector(end) - Vector(start)
    obj = lathe([(radius, 0), (radius if tip is None else tip, direction.length)],
                tone, start, sides)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def pipe(points, radius, tone, sides=8, cap=True, plane=(0, 1, 0)):
    vertices = []
    for index, point in enumerate(points):
        tangent = Vector(points[min(index + 1, len(points) - 1)]) - Vector(points[max(index - 1, 0)])
        u = tangent.normalized().cross(Vector(plane)).normalized()
        v = tangent.normalized().cross(u)
        for step in range(sides):
            angle = tau * step / sides
            vertices.append(Vector(point) + radius * (cos(angle) * u + sin(angle) * v))
    faces = [(i * sides + j, i * sides + (j + 1) % sides,
              (i + 1) * sides + (j + 1) % sides, (i + 1) * sides + j)
             for i in range(len(points) - 1) for j in range(sides)]
    if cap:
        faces += [tuple(reversed(range(sides))),
                  tuple(range((len(points) - 1) * sides, len(points) * sides))]
    return mesh("Bent tube", vertices, faces, tone, smooth=True)


def oval(center, scale, tone, seed=0, angle=0, detail=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=detail, radius=1, location=center)
    obj = bpy.context.object
    rng = Random(seed)
    for vert in obj.data.vertices:
        factor = rng.uniform(.8, 1.13) if seed else 1
        for index in range(3):
            vert.co[index] *= scale[index] * factor
    obj.rotation_euler.z = angle
    return finish(obj, "Rounded piece", tone, smooth=not seed)


def join(name, parts, origin=(0, 0, 0)):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = parts[0]
    obj.name = name
    obj.data.name = name
    bpy.context.scene.cursor.location = origin
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Join keeps one slot per object even when both slots refer to the same material.
    materials = list(obj.data.materials)
    if not materials:
        return obj
    unique = list(dict.fromkeys(materials))
    indices = [unique.index(material) for material in materials]
    polygon_indices = [indices[polygon.material_index] for polygon in obj.data.polygons]
    obj.data.materials.clear()
    for mat in unique:
        obj.data.materials.append(mat)
    for polygon, index in zip(obj.data.polygons, polygon_indices):
        polygon.material_index = index
    return obj


def collision(name, parts):
    obj = join(name + "-col", parts)
    # Godot preserves the mesh instance when it generates a collider from -col.
    obj.data.materials.append(COLORS["proxy"])
    return obj


def slats(width, depth, z, count, tone="wood"):
    step = depth / count
    return [box((0, (i + .5) * step - depth / 2, z),
                (width, step - .008, .046),
                "light" if i % 3 == 0 and tone == "wood" else tone, .013)
            for i in range(count)]


def graining(parts, width, z, rows, seed):
    rng = Random(seed)
    for y in rows:
        for _ in range(2):
            x = rng.uniform(-.34, .27) * width
            length = rng.uniform(.10, .22) * width
            vertices = [(x, y, z), (x + length * .43, y + .004, z),
                        (x + length, y + .003, z), (x + length * .37, y + .010, z)]
            parts.append(mesh("Brush mark", vertices, [(0, 1, 2, 3)], "grain"))


def pot():
    body = lathe([(.103, 0), (.113, .012), (.137, .176), (.143, .186), (.140, .201),
                  (.123, .201), (.118, .177), (.089, .027)], "clay", sides=24)
    rim = lathe([(.136, .166), (.149, .173), (.150, .195), (.145, .207),
                 (.126, .207), (.123, .197), (.125, .174)], "rim", sides=24, closed=True)
    foot = lathe([(.109, .012), (.116, .018), (.118, .027), (.115, .031)], "rim", sides=24)
    soil = lathe([(.112, .153), (.116, .169)], "soil", sides=24)
    return [join("Pot", [body, rim, foot]), join("Soil", [soil], (0, 0, .169))]


def grow_lamp():
    shade = lathe([(.245, .032), (.251, .044), (.241, .068), (.113, .172),
                   (.067, .189), (.060, .166), (.099, .145), (.225, .053), (.225, .032)],
                  "green", sides=24, closed=True)
    rim = lathe([(.236, .032), (.249, .034), (.253, .043), (.247, .052), (.232, .048)], "gold", sides=24, closed=True)
    socket = lathe([(.043, .089), (.062, .102), (.062, .197), (.040, .217)], "black")
    eye = pipe([(-.025 * cos(pi * i / 8), 0, .211 + .039 * sin(pi * i / 8))
                for i in range(9)], .008, "steel", sides=6)
    bulb = lathe([(.026, 0), (.058, .009), (.069, .032), (.064, .056),
                  (.037, .088), (.030, .111)], "glow", sides=20)
    return [join("Shade", [shade, rim, socket, eye]), join("Bulb", [bulb], (0, 0, .107))]


def shelf_shop():
    parts = [box((x, y, .87), (.075, .075, 1.74), "dark", .013)
             for x in (-.52, .52) for y in (-.18, .18)]
    for z in (.22, .65, 1.08, 1.51):
        parts += slats(1.14, .46, z, 3)
        parts.append(box((0, -.227, z - .025), (1.15, .036, .083), "light", .009))
        for x in (-.39, 0, .39):
            parts.append(box((x, -.248, z - .027), (.135, .008, .044), "gold", .004))
    parts += [box((0, .184, 1.698), (1.12, .068, .146), "green", .025),
              box((0, .143, 1.703), (.75, .018, .035), "mint", .008)]
    collider = collision("Shelf", [box((0, 0, .897), (1.15, .5, 1.794), None)])
    return [join("Shelf", parts), collider]


def counter():
    parts = [box((0, 0, .092), (1.47, .63, .184), "dark", .021),
             box((0, 0, .47), (1.58, .66, .72), "green", .028),
             box((0, 0, .855), (1.72, .74, .09), "light", .023)]
    for x in (-.52, 0, .52):
        parts.extend([box((x, -.337, .45), (.47, .03, .56), "wood", .022),
                      box((x, -.358, .45), (.365, .019, .444), "light", .016),
                      box((x, .339, .60), (.46, .035, .19), "wood", .009),
                      box((x, .365, .60), (.13, .027, .027), "gold", .009)])
        for z, shift, length in ((.35, -.12, .21), (.42, -.06, .19), (.52, -.11, .16)):
            x0 = x + shift
            points = [(x0, -.368, z), (x0 + length * .43, -.368, z - .004),
                      (x0 + length, -.368, z + .005), (x0 + length * .52, -.368, z + .003)]
            parts.append(mesh("Panel grain", points, [(0, 1, 2, 3)], "grain"))
    graining(parts, 1.55, .901, (-.22, -.091, .045, .19), 7)
    collider = collision("Counter", [box((0, 0, .45), (1.70, .72, .9), None)])
    return [join("Counter", parts), collider]


def cash_register():
    body = box((0, 0, .049), (.39, .34, .098), "dark", .023)
    upper = box((0, .026, .145), (.37, .244, .118), "mint", .028)
    upper.rotation_euler.x = .31
    parts = [body, upper, box((0, -.168, .047), (.315, .035, .062), "green", .008),
             box((0, -.194, .047), (.102, .025, .023), "gold", .007),
             rod((0, .081, .164), (0, .081, .262), .025, "black"),
             box((0, .085, .268), (.231, .069, .079), "steel", .015),
             box((0, .048, .268), (.172, .009, .046), "screen", .006)]
    for row in range(4):
        y = -.082 + row * .034
        for col in range(5):
            key = box(((col - 2) * .044, y, .198 + (y - .026) * .32),
                      (.036, .027, .018), ("orange" if col == 4 else "cream"), .004)
            key.rotation_euler.x = .31
            parts.append(key)
    return [join("Register", parts)]


def drying_rack():
    parts = [box((x, y, .79), (.068, .068, 1.58), "wood", .012)
             for x in (-.54, .54) for y in (-.27, .27)]
    for z in (.25, .63, 1.01, 1.39):
        for y in (-.29, .29):
            parts.append(box((0, y, z), (1.17, .065, .065), "light", .011))
        for x in (-.54, .54):
            parts.append(box((x, 0, z), (.065, .51, .057), "wood", .009))
        for n in range(-5, 6):
            parts.append(box((n * .093, 0, z), (.032, .52, .018), "dark"))
    for x in (-.54, .54):
        parts.append(box((x, 0, 1.55), (.10, .64, .065), "green", .011))
    collider = collision("DryingRack", [box((0, 0, .79), (1.17, .64, 1.58), None)])
    return [join("DryingRack", parts), collider]


def jar():
    profile = [(.054, 0), (.066, .006), (.071, .017), (.071, .124), (.063, .145),
               (.057, .153), (.060, .163), (.058, .172), (.051, .172),
               (.050, .156), (.056, .142), (.064, .122), (.064, .018), (.051, .011)]
    glass = lathe(profile, "glass", sides=28)
    cork = lathe([(.047, .151), (.050, .167), (.056, .178), (.058, .191),
                  (.054, .197)], "cork", sides=24)
    rng = Random(11)
    flecks = []
    for index in range(18):
        a = rng.random() * tau
        r = .047 * rng.random() ** .5
        x, y = r * cos(a), r * sin(a)
        flecks.append(mesh("Cork fleck", [(x, y, .1972), (x + .003, y - .001, .1972),
                                         (x + .002, y + .002, .1972)],
                           [(0, 1, 2)], "wood" if index % 2 else "light"))
    plaque = box((0, -.071, .081), (.080, .012, .053), "cream", .007)
    accent = box((0, -.078, .080), (.036, .002, .008), "green", .001)
    return [join("Glass", [glass]), join("Lid", [cork, *flecks], (0, 0, .177)),
            join("Label", [plaque, accent])]


def work_frame(width, depth, height, tone):
    parts = []
    for x in (-width / 2 + .075, width / 2 - .075):
        for y in (-depth / 2 + .075, depth / 2 - .075):
            parts.append(box((x, y, (height - .02) / 2), (.081, .080, height - .02), tone, .013))
    for y in (-depth / 2 + .075, depth / 2 - .075):
        parts.append(box((0, y, height - .10), (width - .13, .06, .125), tone, .011))
    return parts


def rolling_table():
    parts = work_frame(1.25, .68, .87, "green") + slats(1.25, .68, .84, 4)
    parts += [box((0, .135, .24), (1.09, .473, .042), "wood", .013),
              box((0, -.279, .745), (.63, .033, .129), "light", .013),
              box((0, -.31, .749), (.122, .029, .027), "gold", .007),
              box((0, .291, .88), (1.233, .045, .058), "dark", .012)]
    graining(parts, 1.2, .864, (-.25, -.08, .09, .25), 19)
    return [join("RollingTable", parts)]


def generator():
    parts = [box((0, 0, .092), (.73, .435, .096), "black", .018),
             box((0, 0, .300), (.57, .379, .37), "orange", .039),
             box((0, 0, .477), (.597, .396, .093), "green", .025),
             box((-.147, -.198, .32), (.244, .023, .201), "black", .014)]
    for index in range(5):
        parts.append(box((-.15, -.213, .254 + index * .032), (.192, .012, .009), "steel"))
    parts.append(box((.153, -.202, .32), (.177, .025, .193), "cream", .013))
    for x in (.11, .19):
        parts.append(rod((x, -.212, .34), (x, -.233, .34), .027, "black", sides=10))
    parts += [box((.15, -.221, .269), (.102, .013, .029), "rust", .004),
              lathe([(.037, .519), (.04, .543), (.032, .553)], "black", (-.132, .02, 0), sides=12)]
    for y in (-.228, .228):
        outline = [(-.34, y, .036), (.34, y, .036), (.374, y, .077),
                   (.374, y, .484), (.336, y, .551), (-.336, y, .551),
                   (-.374, y, .484), (-.374, y, .077), (-.34, y, .036)]
        parts.append(pipe(outline, .027, "steel", cap=False))
        for x in (-.264, .264):
            parts.append(box((x, y, .022), (.109, .079, .044), "black", .01))
    collider = collision("Generator", [box((0, 0, .282), (.78, .51, .564), None)])
    return [join("Generator", parts), collider]


def water_tank():
    body = lathe([(.39, .075), (.498, .10), (.527, .168), (.532, 1.006),
                  (.516, 1.075), (.430, 1.148), (.278, 1.202), (.175, 1.211)],
                 "green", sides=24)
    parts = [body]
    for z in (.245, .487, .731, .972):
        parts.append(lathe([(.531, z - .03), (.549, z - .018), (.551, z + .014),
                            (.530, z + .029)], "mint", sides=24))
    parts += [lathe([(.167, 1.201), (.179, 1.222), (.175, 1.266), (.150, 1.281)],
                    "black", sides=20),
              lathe([(.42, 0), (.45, .013), (.45, .093), (.43, .113)], "dark", sides=20),
              pipe([(0, -.489, .171), (0, -.61, .171), (0, -.661, .148),
                    (0, -.667, .100)], .031, "gold", plane=(1, 0, 0)),
              box((0, -.615, .238), (.130, .036, .023), "orange", .006),
              rod((0, -.615, .170), (0, -.615, .231), .013, "gold")]
    collider = collision("Tank", [lathe([(.54, 0), (.54, 1.128), (.37, 1.252)], None, sides=12)])
    return [join("Tank", parts), collider]


def watering_can():
    body = lathe([(.108, 0), (.122, .011), (.131, .042), (.126, .167), (.108, .203),
                  (.071, .221), (.050, .221), (.048, .207), (.062, .193)],
                 "mint", sides=20)
    handle = pipe([(-.106 - .096 * sin(pi * i / 12), 0, .110 + .074 * cos(pi * i / 12))
                   for i in range(13)], .015, "green")
    spout = rod((.102, 0, .065), (.311, 0, .235), .032, "green", .014, sides=12)
    rose = rod((.303, 0, .22), (.342, 0, .252), .042, "gold", .055, sides=16)
    face = rod((.340, 0, .250), (.346, 0, .254), .046, "steel", sides=16)
    band = lathe([(.123, .025), (.134, .036), (.134, .05), (.130, .054)], "green", sides=20)
    perforations = []
    axis = Vector((.006, 0, .004)).normalized()
    right = Vector((0, 1, 0))
    up = axis.cross(right)
    cap_center = Vector((.346, 0, .254)) + .002 * axis
    centers = [cap_center] + [cap_center + .027 * (cos(t) * right + sin(t) * up)
                              for t in (i * tau / 7 for i in range(7))]
    for center in centers:
        verts = [center + .0038 * (cos(t) * right + sin(t) * up)
                 for t in (i * tau / 7 for i in range(7))]
        perforations.append(mesh("Spray hole", verts, [tuple(range(7))], "black"))
    return [join("Can", [body, handle, spout, rose, face, band, *perforations])]


def fence():
    parts = []
    for x in (-.95, .95):
        parts += [box((x, 0, .483), (.151, .149, .966), "dark", .020),
                  box((x, 0, .959), (.180, .173, .085), "light", .025)]
    for index, z in enumerate((.34, .696)):
        rail = box((0, 0, z), (1.931, .072, .148), "wood" if index else "light", .018)
        rail.rotation_euler.y = -.021 if index else .027
        parts.append(rail)
        for x in (-.923, .923):
            parts.append(rod((x, -.074, z), (x, -.092, z), .021, "steel"))
    collider = collision("Fence", [box((0, 0, .486), (2.06, .166, .972), None)])
    return [join("Fence", parts), collider]
def spruce_tree():
    rng = Random(45)
    trunk = lathe([(.30, 0), (.23, .21), (.165, 1.26), (.107, 3.25), (.045, 5.10)],
                  "dark", sides=11)
    bark = [trunk]
    for index in range(6):
        angle = tau * index / 6
        x, y = cos(angle), sin(angle)
        bark.append(rod((.39 * x, .39 * y, .042), (.136 * x, .136 * y, .43),
                        .094, "wood", .052, sides=6))
    crown = []
    for level, (z, radius, height) in enumerate(
            [(1.07, 1.43, 1.75), (1.77, 1.27, 1.60), (2.44, 1.11, 1.46),
             (3.08, .92, 1.37), (3.67, .73, 1.20), (4.17, .53, 1.14)]):
        sides = 16
        rings = [(0.30, .13), (.84, .01), (1, .20), (.67, .44), (.34, .71), (.035, 1)]
        vertices = []
        for rad, elevation in rings:
            for j in range(sides):
                angle = j * tau / sides + level * .6
                branch = (1 if j % 2 == 0 else .77) * rng.uniform(.89, 1.10)
                vertices.append((cos(angle) * rad * radius * branch + .07 * level / 5,
                                 sin(angle) * rad * radius * branch,
                                 z + height * elevation + rng.uniform(-.07, .07) * rad))
        faces = [(i * sides + j, i * sides + (j + 1) % sides,
                  (i + 1) * sides + (j + 1) % sides, (i + 1) * sides + j)
                 for i in range(len(rings) - 1) for j in range(sides)]
        faces += [tuple(reversed(range(sides))), tuple(range(5 * sides, 6 * sides))]
        needles = mesh("Needle tier", vertices, faces, "fern")
        for tone in ("pine", "olive"):
            needles.data.materials.append(COLORS[tone])
        for index, polygon in enumerate(needles.data.polygons):
            layer = index // sides
            polygon.material_index = 1 if layer < 2 else (2 if rng.random() < .28 else 0)
        crown.append(needles)
    collider = collision("Trunk", [lathe([(.295, 0), (.185, 1.15), (.127, 2.35)], None, sides=8)])
    return [join("Trunk", bark), join("Needles", crown), collider]


def tea_bush():
    rng = Random(622)
    branches, clusters, leaves = [], [], []
    for index in range(8):
        angle = tau * index / 8
        x, y = cos(angle), sin(angle)
        z = rng.uniform(.35, .51)
        end = (.45 * x, .42 * y, z)
        branches.append(rod((0, 0, .016), end, .031, "dark", .008, sides=6))
        clusters.append(oval(end, (.35, .28, .24), "tea" if index % 3 else "olive",
                             index + 1, angle, detail=2))
    for index in range(3):
        angle = index * tau / 3
        clusters.append(oval((.21 * cos(angle), .19 * sin(angle), .61),
                             (.34, .29, .23), "tea", index + 17, angle, detail=2))
    bpy.context.view_layer.update()
    for cluster in clusters:
        for face in cluster.data.polygons:
            face.use_smooth = True
        top_faces = [face for face in cluster.data.polygons if face.normal.z > .23]
        for face in rng.sample(top_faces, 8):
            base = cluster.matrix_world @ face.center - Vector((0, 0, .009))
            theta = rng.uniform(0, tau)
            direction = Vector((cos(theta), sin(theta), rng.uniform(.10, .45)))
            side = Vector((-sin(theta), cos(theta), 0))
            length = rng.uniform(.11, .205)
            width = length * .32
            verts = [base, base + direction * length * .41 - side * width,
                     base + direction * length + Vector((0, 0, .02)),
                     base + direction * length * .42 + side * width,
                     base + direction * length * .47 + Vector((0, 0, .025))]
            leaf = mesh("Tea flush", verts, [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)], "leaf")
            leaf.data.materials.append(COLORS["tea"])
            for edge in leaf.data.polygons[2:]:
                edge.material_index = 1
            leaves.append(leaf)
    return [join("Branches", branches), join("Foliage", clusters + leaves)]


def rock(dimensions, seed):
    rng = Random(seed)
    width, depth, height = dimensions
    sides = 9
    vertices = []
    for rad, z in [(.73, 0), (1, .25), (.83, .68), (.50, 1)]:
        for index in range(sides):
            angle = index * tau / sides
            skew = rng.uniform(.82, 1.14)
            x = width * (rad * .5 * skew * cos(angle) - .077 * z)
            y = depth * (rad * .5 * skew * sin(angle) + .088 * z)
            vertices.append((x, y, z * height * rng.uniform(.91, 1.06)))
    faces = [tuple(reversed(range(sides)))]
    for level in range(3):
        for index in range(sides):
            a = level * sides + index
            b = level * sides + (index + 1) % sides
            c, d = b + sides, a + sides
            faces.extend([(a, b, c), (c, d, a)])
    faces += [tuple(range(3 * sides, 4 * sides))]
    slate = mesh("Slate", vertices, faces, "stone")
    for tone in ("stone_dark", "stone_light"):
        slate.data.materials.append(COLORS[tone])
    for index, face in enumerate(slate.data.polygons):
        face.material_index = rng.choices(
            (0, 1, 2), (65, 35, 0) if index < 19 else (79, 12, 9))[0]
    slate.data.polygons[-1].material_index = 2
    pieces = [slate]
    for face_id in (29, 31, 32, 33, 38, 47, 49, 51, 52):
        triangle = [Vector(vertices[i]) for i in faces[face_id]]
        normal = (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).normalized()
        center = sum(triangle, Vector()) / 3
        offset = normal * .0018
        edges = [(triangle[i] + triangle[(i + 1) % 3]) / 2 for i in range(3)]
        patch = [center + (corner - center) * rng.uniform(.40, .94) + offset
                 for pair in zip(triangle, edges) for corner in pair]
        pieces.append(mesh("Moss on slate", patch, [tuple(range(6))],
                           "moss" if face_id % 3 else "olive"))
    collider = collision("Rock", [mesh("Proxy", vertices, faces)])
    return [join("Rock", pieces), collider]


def bench():
    parts = slats(1.60, .40, .445, 4, "light")
    for x in (-.62, .62):
        parts += [box((x, 0, .040), (.11, .437, .080), "steel", .014),
                  rod((x, -.16, .047), (x, -.13, .449), .034, "steel"),
                  rod((x, .12, .048), (x, .235, .83), .037, "steel"),
                  rod((x, -.17, .612), (x, .192, .625), .032, "green"),
                  rod((x, -.17, .465), (x, -.17, .612), .026, "steel")]
    for z in (.622, .753):
        board = box((0, .196 + .13 * (z - .62), z), (1.62, .052, .103), "wood", .012)
        board.rotation_euler.x = -.18
        parts.append(board)
        for x in (-.61, .61):
            parts.append(rod((x, .160, z), (x, .163, z), .012, "gold", sides=6))
    graining(parts, 1.55, .469, (-.139, -.044, .065, .14), 77)
    return [join("Bench", parts)]


def lamp_post():
    base = lathe([(.176, 0), (.184, .028), (.152, .079), (.108, .105), (.086, .336),
                  (.059, .382), (.048, .442), (.045, 1.92)], "steel")
    arm = pipe([(0, 0, 1.89), (.031, 0, 2.05), (.14, 0, 2.18), (.32, 0, 2.22),
                (.46, 0, 2.153), (.51, 0, 2.034)], .036, "steel")
    shade = lathe([(.226, 1.863), (.221, 1.886), (.160, 1.968), (.079, 2.046), (.050, 2.050)],
                  "green", (.51, 0, 0), sides=20)
    globe = lathe([(.071, 1.681), (.132, 1.703), (.157, 1.758),
                   (.158, 1.858), (.139, 1.889)], "glow", (.51, 0, 0), sides=20)
    cage = [lathe([(.078, 1.664), (.094, 1.679), (.097, 1.704), (.079, 1.715)],
                  "gold", (.51, 0, 0), sides=16)]
    for axis in range(5):
        angle = axis * tau / 5
        cage.append(pipe([(.51 + cos(angle) * radius, sin(angle) * radius, z)
                          for radius, z in ((.087, 1.692), (.146, 1.722), (.168, 1.792),
                                            (.165, 1.868))],
                         .011, "steel", sides=6, plane=(-sin(angle), cos(angle), 0)))
    return [join("Post", [base, arm, shade, *cage]), join("Bulb", [globe])]


def sofa():
    parts = [box((0, 0, .217), (1.87, .755, .279), "cloth_dark", .054)]
    for x in (-.73, .73):
        for y in (-.24, .24):
            parts.append(lathe([(.045, 0), (.054, .014), (.066, .119)], "dark", (x, y, 0), sides=10))
    back = box((0, .273, .538), (1.82, .215, .69), "cloth", .054)
    back.rotation_euler.x = -.15
    parts.append(back)
    for x in (-.844, .844):
        parts += [box((x, -.051, .452), (.253, .678, .32), "cloth", .072),
                  box((x, -.366, .484), (.146, .085, .154), "cloth_light", .035)]
    for x in (-.42, 0, .42):
        parts += [box((x, -.075, .379), (.399, .55, .166), "cloth_light", .039)]
        cushion = box((x, .236, .609), (.411, .157, .385), "cloth_light", .044)
        cushion.rotation_euler.x = -.16
        parts.append(cushion)
    for index, (x, tone, angle) in enumerate(((-.58, "rust", .24), (.58, "cream", -.23))):
        pillow = box((x, .112, .587), (.257, .104, .244), tone, .043)
        pillow.rotation_euler = (-.41, angle, 0)
        parts.append(pillow)
        for shift in (-1, 0, 1):
            stripe = box((x + shift * .041, .058, .583 + index * .004),
                         (.009, .008, .13), "rose" if index == 0 else "wood", .003)
            stripe.rotation_euler = pillow.rotation_euler
            parts.append(stripe)
    collider = collision("Sofa", [box((0, -.02, .234), (1.94, .76, .468), None),
                                  box((0, .275, .65), (1.86, .24, .45), None),
                                  *[box((x, -.045, .52), (.24, .66, .19), None) for x in (-.843, .843)]])
    return [join("Sofa", parts), collider]


def arch_profile(width, bottom, spring):
    radius = width / 2
    return [(-radius, bottom), (radius, bottom)] + [
        (radius * cos(i * pi / 18), spring + radius * sin(i * pi / 18)) for i in range(19)]


def mirror():
    outer = arch_profile(.69, .13, 1.48)
    inner = arch_profile(.557, .213, 1.48)
    verts = [(x, y, z) for y, profile in ((-.101, outer), (-.112, inner), (.018, outer), (.012, inner))
             for x, z in profile]
    n = len(outer)
    faces = []
    for rowa, rowb in ((0, 1), (1, 3), (3, 2), (2, 0)):
        faces += [(rowa * n + i, rowa * n + (i + 1) % n,
                   rowb * n + (i + 1) % n, rowb * n + i) for i in range(n)]
    arch = mesh("Arch", verts, faces, "wood")
    arch.data.materials.append(COLORS["light"])
    for index, polygon in enumerate(arch.data.polygons):
        if index < n and index % 2 == 0:
            polygon.material_index = 1
    glass = mesh("Reflector", [(x, -.097, z) for x, z in inner], [tuple(range(n))], "mirror")
    glint = mesh("Glass highlight", [(-.20, -.098, 1.41), (-.181, -.098, 1.40),
                                    (.21, -.098, 1.075), (.211, -.098, 1.036)], [(3, 2, 1, 0)], "silver")
    feet = [box((x, 0, .074), (.121, .305, .148), "dark", .02) for x in (-.215, .215)]
    backing = box((0, .041, .79), (.35, .072, 1.32), "dark", .022)
    return [join("Frame", [arch, backing] + feet), join("Glass", [glass, glint])]


def bed():
    parts = [box((0, 0, .256), (1.17, 2.04, .26), "wood", .028),
             box((0, 0, .418), (1.08, 1.968, .194), "cream", .059)]
    for x in (-.524, .524):
        for y, top in ((-.973, .51), (.96, 1.00)):
            parts.append(box((x, y, top / 2), (.133, .135, top), "dark", .025))
            parts.append(oval((x, y, top), (.075, .073, .061), "light", detail=2))
    parts += [box((0, .951, .716), (1.10, .09, .354), "wood", .034),
              box((0, .940, .904), (1.16, .12, .09), "light", .025),
              box((0, -.963, .41), (1.126, .112, .16), "light", .024),
              box((0, .687, .53), (.69, .38, .145), "cream", .053)]
    quilt = [box((0, -.24, .522), (1.133, 1.43, .088), "rust", .037)]
    for x in (-.548, .548):
        quilt.append(box((x, -.243, .463), (.070, 1.41, .163), "rust", .034))
    for y in (-.77, -.60, -.36, -.12, .12, .36):
        quilt.append(box((0, y, .568), (1.00, .028, .008),
                         "cream" if y in (-.77, .36) else "rose", .003))
    for x in (-.37, -.12, .12, .37):
        for y in (-.49, -.24, 0, .24):
            quilt.append(box((x, y, .569), (.078, .078, .006), "rose", angle=pi / 4))
    collider = collision("Bed", [box((0, 0, .28), (1.18, 2.05, .56), None),
                                 box((0, .96, .80), (1.19, .14, .51), None)])
    return [join("Bed", parts), join("Quilt", quilt), collider]


def crate():
    parts = [box((0, 0, .030), (.57, .439, .06), "dark", .009)]
    for x in (-.258, .258):
        for y in (-.187, .187):
            parts.append(box((x, y, .165), (.057, .054, .33), "light", .009))
    for index in range(3):
        z = .091 + .091 * index
        for sign in (-1, 1):
            tone = "light" if index == 1 else "wood"
            parts += [box((0, sign * .210, z), (.569, .034, .075), tone, .007),
                      box((sign * .272, 0, z), (.035, .392, .075), tone, .007)]
            for x in (-.233, .233):
                parts.append(rod((x, sign * .229, z), (x, sign * .232, z), .007, "steel", sides=6))
    return [join("Crate", parts)]


def tavla_table():
    parts = work_frame(.87, .68, .745, "dark")
    parts += [box((0, 0, .742), (.916, .716, .066), "wood", .017),
              box((0, 0, .776), (.764, .555, .019), "cream", .011)]
    for x in (-.405, 0, .405):
        parts.append(box((x, 0, .792), (.044, .605, .052), "dark", .009))
    for y in (-.303, .303):
        parts.append(box((0, y, .794), (.851, .046, .054), "dark", .009))
    for sign in (-1, 1):
        for side in (-1, 1):
            for index in range(6):
                x = side * (.047 + index * .059)
                y = sign * .269
                points = [(x - .027, y, .787), (x + .027, y, .787), (x, sign * .053, .787)]
                if sign > 0:
                    points.reverse()
                parts.append(mesh("Inlaid point", points, [(0, 1, 2)], "rust" if index % 2 else "green"))
    pieces = []
    for x, start, count, tone in ((-.341, -.235, 5, "cream"), (.341, .235, 5, "dark"),
                                  (-.223, .235, 3, "dark"), (.223, -.235, 3, "cream")):
        for index in range(count):
            y = start - index * .043 if start > 0 else start + index * .043
            pieces.append(lathe([(.020, .787), (.0215, .793), (.0195, .801)], tone,
                                (x, y, 0), sides=10))
    pieces += [box((-.109, -.024, .804), (.029, .029, .029), "cream", .005, angle=.25),
               box((.092, .039, .804), (.029, .029, .029), "cream", .005, angle=-.35)]
    return [join("TavlaTable", parts), join("Pieces", pieces)]


BUILDERS = {
    "pot": pot, "grow_lamp": grow_lamp, "shelf_shop": shelf_shop, "counter": counter,
    "cash_register": cash_register, "drying_rack": drying_rack, "jar": jar,
    "rolling_table": rolling_table, "generator": generator, "water_tank": water_tank,
    "watering_can": watering_can, "fence": fence, "spruce_tree": spruce_tree, "tea_bush": tea_bush,
    "rock_01": lambda: rock((1.76, 1.27, .92), 31),
    "rock_02": lambda: rock((1.20, 1.48, 1.19), 22),
    "bench": bench, "lamp_post": lamp_post, "sofa": sofa, "mirror": mirror, "bed": bed,
    "crate": crate, "tavla_table": tavla_table,
}


def exported_geometry(path):
    with path.open("rb") as glb:
        magic, version, _ = struct.unpack("<4sII", glb.read(12))
        assert (magic, version) == (b"glTF", 2)
        length, chunk = struct.unpack("<I4s", glb.read(8))
        assert chunk == b"JSON"
        document = json.loads(glb.read(length))
    counts = {}
    for node in document["nodes"]:
        if "mesh" not in node:
            continue
        primitives = document["meshes"][node["mesh"]]["primitives"]
        assert all(primitive.get("mode", 4) == 4 for primitive in primitives)
        counts[node["name"]] = sum(document["accessors"][primitive["indices"]]["count"] // 3
                                   for primitive in primitives)
    return counts


def export(name, objects):
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    bpy.context.view_layer.update()
    base_z = min((obj.matrix_world @ vertex.co).z for obj in objects
                 if not obj.name.endswith("-col") for vertex in obj.data.vertices)
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objects:
        obj.location.z -= base_z
        obj.parent = root
        obj.select_set(True)
    target = MODELS / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB", use_selection=True,
                              export_yup=True, export_animations=False, export_cameras=False,
                              export_lights=False)
    counts = exported_geometry(target)
    assert set(counts) == {obj.name for obj in objects}, counts
    assert sum(counts.values()) <= 2000, (name, counts)
    print(f"PROP {name}: {sum(counts.values())} triangles | " +
          ", ".join(f"{node}={count}" for node, count in counts.items()), flush=True)


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def area(name, location, target, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    point_at(obj, target)


def preview(name, objects):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 16
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = -.4
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("Studio sky")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.42, .50, .57, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .34
    bpy.context.view_layer.update()
    corners = []
    for obj in objects:
        if obj.name.endswith("-col"):
            obj.hide_render = True
        else:
            corners += [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector(tuple(min(corner[axis] for corner in corners) for axis in range(3)))
    maximum = Vector(tuple(max(corner[axis] for corner in corners) for axis in range(3)))
    center = (minimum + maximum) / 2
    scale = max(maximum - minimum)
    camera_data = bpy.data.cameras.new("Studio")
    camera_data.type = "ORTHO"
    camera_data.clip_start = .001
    camera_obj = bpy.data.objects.new("Studio", camera_data)
    bpy.context.collection.objects.link(camera_obj)
    scene.camera = camera_obj
    angle = Vector((3.2, -5.5, 3.15))
    if name == "grow_lamp":
        angle = Vector((2.5, -5.5, -2.1))
    if name == "pot":
        angle.z = 4.4
    camera_obj.location = center + angle * scale
    point_at(camera_obj, center)
    axes = camera_obj.rotation_euler.to_matrix()
    # Frame the actual mesh vertices so a diagonal bound does not add empty space.
    projected = [axes.transposed() @ (obj.matrix_world @ vertex.co - center)
                 for obj in objects if not obj.hide_render for vertex in obj.data.vertices]
    ranges = [(min(p[i] for p in projected), max(p[i] for p in projected)) for i in (0, 1)]
    camera_obj.location += axes @ Vector(tuple((lo + hi) / 2 for lo, hi in ranges) + (0,))
    camera_data.ortho_scale = max(hi - lo for lo, hi in ranges) * 1.28
    ground = box((center.x, center.y, minimum.z - .0135 * scale),
                 (25 * scale, 25 * scale, .026 * scale), None)
    ground.data.materials.append(material("Studio slate", "3E5557", .87))
    if name == "grow_lamp":
        ground.hide_render = True
    area("Apricot key", center + scale * Vector((-2.6, -3.2, 4.4)), center,
         950 * scale ** 2, 3.8 * scale, (1, .83, .67))
    area("Overcast fill", center + scale * Vector((3, -1.4, 1.9)), center,
         360 * scale ** 2, 3.3 * scale, (.69, .83, 1))
    area("Window rim", center + scale * Vector((1.0, 3.0, 3.0)), center,
         1050 * scale ** 2, 2.5 * scale, (1, .91, .73))
    if name == "grow_lamp":
        area("Shade bounce", center + scale * Vector((1, -1, -1)), center,
             84 * scale ** 2, 1.7 * scale, (1, .81, .68))
    scene.render.filepath = str(PREVIEWS / (name + ".png"))
    bpy.ops.render.render(write_still=True)


# A small bitmap alphabet keeps contact sheet labels independent of system fonts.
GLYPHS = dict(zip("ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789", (
    "011101011111101", "110101110101110", "011100100100011", "110101101101110",
    "111100110100111", "111100110100100", "011100101101011", "101101111101101",
    "111010010010111", "001001001101010", "101101110101101", "100100100100111",
    "101111111101101", "101111111111101", "010101101101010", "110101110100100",
    "010101101111011", "110101110101101", "011100010001110", "111010010010010",
    "101101101101111", "101101101101010", "101101111111101", "101101010101101",
    "101101010010010", "111001010100111", "000000000000111", "111101101101111",
    "010110010010111", "110001010100111", "110001010001110", "101101111001001",
    "111100110001110", "011100110101010", "111001010010010", "010101010101010",
    "010101011001110",
)))


def sheet():
    names = list(BUILDERS)
    columns, rows = 5, 5
    gutter, caption, unit = 12, 36, 4
    stride_x, stride_y = SIZE + gutter, SIZE + caption + gutter
    width, height = columns * stride_x + gutter, rows * stride_y + gutter
    pixels = np.ones((height, width, 4), dtype=np.float32)
    pixels[:, :, :3] = (.098, .15, .157)
    for index, name in enumerate(names):
        column, row = index % columns, rows - 1 - index // columns
        x, y = gutter + column * stride_x, gutter + row * stride_y
        img = bpy.data.images.load(str(PREVIEWS / (name + ".png")), check_existing=False)
        tile = np.empty(SIZE * SIZE * 4, dtype=np.float32)
        img.pixels.foreach_get(tile)
        pixels[y + caption:y + caption + SIZE, x:x + SIZE] = tile.reshape((SIZE, SIZE, 4))
        bpy.data.images.remove(img)
        label = name.upper()
        left = x + (SIZE - (len(label) * 4 - 1) * unit) // 2
        for letter_index, letter in enumerate(label):
            for i, bit in enumerate(GLYPHS[letter]):
                if bit == "1":
                    gx = left + (letter_index * 4 + i % 3) * unit
                    gy = y + 9 + (4 - i // 3) * unit
                    pixels[gy:gy + unit, gx:gx + unit, :3] = (.88, .82, .70)
    canvas = bpy.data.images.new("GAFTI Props", width=width, height=height, alpha=False)
    canvas.pixels.foreach_set(pixels.ravel())
    canvas.file_format = "PNG"
    canvas.filepath_raw = str(PREVIEWS / "props_sheet.png")
    canvas.save()


def main():
    MODELS.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [argument for argument in arguments if not argument.startswith("--")]
    unknown = set(names) - BUILDERS.keys()
    if unknown:
        raise ValueError(f"Unknown props: {sorted(unknown)}")
    if "--sheet-only" in arguments:
        sheet()
        return
    for name in names or BUILDERS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        COLORS.clear()
        COLORS.update(palette())
        objects = BUILDERS[name]()
        export(name, objects)
        if "--export-only" not in arguments:
            preview(name, objects)
    if not names and "--export-only" not in arguments:
        sheet()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # The Store launcher does not pass Blender's --python-exit-code.
        import os
        import tempfile
        import traceback

        diagnostic = Path(tempfile.gettempdir()) / "gafti_props_error.txt"
        diagnostic.write_text(traceback.format_exc(), encoding="utf-8")
        traceback.print_exc()
        sys.stderr.flush()
        os._exit(1)

