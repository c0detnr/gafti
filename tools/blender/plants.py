"""Build the five GAFTİ hero plants. Run via run_blender.ps1."""
from math import sin, cos, pi, sqrt
from pathlib import Path
from random import Random

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "assets/models/hero"
PREVIEWS = ROOT / "tools/previews"
STAGES = ("germ", "seedling", "veg", "flower", "harvest")
HEIGHTS = (.08, .25, .7, 1.1, 1.2)
UP = Vector((0, 0, 1))


def radial(angle):
    return Vector((cos(angle), sin(angle), 0))


def blend(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


class Part:
    def __init__(self, name):
        self.name = name
        self.points = []
        self.faces = []
        self.uv = []
        self.mask = []
        self.paint = []

    def point(self, p, u=.5, t=0, wind=0, shade=.5, accent=0):
        self.points.append(p.copy())
        self.uv.append((u, 1 - t))  # glTF exporter flips V.
        self.mask.append((wind, shade, accent, 1))
        if self.name == "Stem":
            color = blend((.12, .13, .038), (.42, .52, .13), shade)
        elif self.name == "Leaves":
            color = blend((.011, .09, .044), (.14, .46, .065), shade)
            color = blend(color, (.46, .65, .16), accent)
        else:
            color = blend((.075, .21, .095), (.54, .72, .40), shade)
            color = blend(color, (.98, .29, .045), accent)
        self.paint.append((*color, 1))
        return len(self.points) - 1

    def build(self, scale):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([p * scale for p in self.points], [], self.faces)
        mesh.update()
        for face in mesh.polygons:
            face.use_smooth = True
        uv = mesh.uv_layers.new(name="RootToTip")
        for loop in mesh.loops:
            uv.data[loop.index].uv = self.uv[loop.vertex_index]
        for name, values in (("WindPaint", self.mask), ("Preview", self.paint)):
            attr = mesh.color_attributes.new(name=name, type="FLOAT_COLOR", domain="POINT")
            attr.data.foreach_set("color", [v for rgba in values for v in rgba])
        mesh.color_attributes.active_color_index = 0
        mesh.color_attributes.render_color_index = 0
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def tube(part, centers, radii, sides=6):
    rings = []
    for j, (c, r) in enumerate(zip(centers, radii)):
        axis = (centers[min(j+1, len(centers)-1)] - centers[max(j-1, 0)]).normalized()
        if j == 0 and c.length == 0:
            axis = UP
        side = axis.cross(Vector((1, .2, 0))).normalized()
        forward = axis.cross(side)
        ring = []
        for k in range(sides):
            a = 2*pi*k/sides
            ring.append(part.point(c + r*(side*cos(a)+forward*sin(a)), k/sides,
                                   j/(len(centers)-1), shade=.47+.25*cos(a)+.12*j/(len(centers)-1)))
        if rings:
            old = rings[-1]
            for k in range(sides):
                n = (k+1) % sides
                part.faces.append((old[k], old[n], ring[n], ring[k]))
        rings.append(ring)
    part.faces.extend((tuple(reversed(rings[0])), tuple(rings[-1])))


def blade(part, root, direction, length, width, lift, curve, shade, teeth=3):
    side = UP.cross(direction).normalized()
    start = part.point(root, t=0, shade=shade, accent=.48)
    rows = []
    fractions = [.14, .28, .43, .59, .72, .85] if teeth else [.18, .45, .7, .87]
    for j, t in enumerate(fractions):
        center = root + length*(direction*t + UP*(lift*t+curve*sin(pi*t)))
        half = width * sin(pi*t)**(.70 if teeth else .38)
        # Project alternating margin points towards the tip for saw teeth.
        inset = .68 if teeth and j % 2 == 0 else 1
        sweep = .075*length if teeth and j % 2 else 0
        row = []
        for k in (-1, 0, 1):
            pos = center + side*(k*half*inset)
            pos += direction*sweep*abs(k) + UP*(half*(.28 if k == 0 else -.08 + .10*k))
            row.append(part.point(pos, (k+1)/2, t, t**1.4,
                                  min(1, max(0, shade+.18*k+.14*t)), .36 if k == 0 else 0))
        if rows:
            old = rows[-1]
            for k in range(2):
                part.faces.append((old[k], row[k], row[k+1], old[k+1]))
        else:
            part.faces.extend(((start, row[0], row[1]), (start, row[1], row[2])))
        rows.append(row)
    end = part.point(root + length*(direction + UP*lift), t=1, wind=1, shade=min(1,shade+.22))
    part.faces.extend(((rows[-1][0], end, rows[-1][1]), (rows[-1][1], end, rows[-1][2])))


def fan(leaves, root, angle, size, fingers, lift, shade):
    mid = fingers//2
    for i in range(-mid, mid+1):
        s = abs(i)/max(mid, 1)
        blade(leaves, root, radial(angle+i*.36), size*(1-.52*s),
              size*(.23 if fingers == 1 else .094)*(1-.38*s),
              lift+.08*s, .17, shade, teeth=fingers > 1)


def cluster(buds, base, radius, height, ripe, rng):
    # Overlapping keeled bracts taper into a single terminal spear.
    for tier, count in enumerate((6, 5, 4, 3, 1)):
        t = tier/5
        for j in range(count):
            a = 2*pi*j/count + tier*2.4 + rng.uniform(-.14,.14)
            d, side = radial(a), radial(a+pi/2)
            r = radius*(1-.73*t)
            c = base + UP*(height*(t+rng.uniform(-.043,.043))) + radial(tier*1.8)*radius*.13
            foot = buds.point(c+d*r*.17, shade=.20)
            rim = []
            for k in range(5):
                b = 2*pi*k/5
                p = c + UP*(height*.115) + d*r*(.53+.53*cos(b)) + side*r*.65*sin(b)
                rim.append(buds.point(p, t=.45, shade=.35+.21*cos(b)+rng.uniform(-.09,.09)))
            apex = c + UP*(height*(.24+rng.uniform(0,.06))) + d*r*.62
            tip = buds.point(apex, t=1, shade=.98 if ripe else .70)
            for k in range(5):
                n = (k+1)%5
                buds.faces.extend(((foot,rim[n],rim[k]),(rim[k],rim[n],tip)))
            if ripe and (j+tier)%2 == 0:
                p = apex-UP*(height*.09)+d*r*.46
                bend = p+d*radius*.23+UP*height*.10
                ids = [buds.point(q, accent=1, shade=.6) for q in
                       (p-side*radius*.085,p+side*radius*.085,bend+side*radius*.047,
                        bend-side*radius*.047,bend+UP*height*.075-side*radius*.12)]
                buds.faces.extend(((ids[0],ids[1],ids[2],ids[3]),(ids[3],ids[2],ids[4])))


def generate(stage):
    stem, leaves, buds = [Part(n) for n in ("Stem","Leaves","Buds")]
    rng = Random(4700+stage)
    def spine(z):
        return Vector((.036*sin(z*5), .035*sin(z*3.3), z))
    tip = (.78,.84,1,.91,.91)[stage]
    tube(stem,[spine(tip*k/8) for k in range(9)],
         [(.028 if stage < 2 else .017)*(1-.84*k/8) for k in range(9)],8)
    if stage < 2:
        for i in range(2):
            fan(leaves,spine(.59 if stage == 0 else .31),i*pi+.28,
                .60 if stage == 0 else .28,1,.22,.77)
        for i in range(2):
            fan(leaves,spine(tip),i*pi+1.54,.28 if stage == 0 else .52,
                1 if stage == 0 else 5,.62,.54)
        if stage == 1:
            for i in range(2):
                fan(leaves,spine(.55),i*pi+.54,.50,3,.21,.35)
    else:
        for i in range(10):
            t = i/9
            z = .23+.62*t
            a = .34+i*2.40 + rng.uniform(-.14,.14)
            d = radial(a)
            span = (.26-.15*t)*(1.1 if stage == 2 else 1)
            root = spine(z)
            joint = root + span*d + UP*(.055+.056*t)
            end = joint + .047*d + UP*(.085+.012*t)
            tube(stem,[root,joint,end],[.009,.0055,.0028],5)
            fan(leaves,joint,a, (.39-.18*t)*(1.13 if stage == 2 else 1),
                (5,7,9,7,5)[i%5], rng.uniform(-.34,.16),.27+.36*t)
            if stage == 2 or i % 2 == 1:
                fan(leaves,end,a+1.03,.12-.037*t,3,.55,.69)
            if stage >= 3 and i % 2 == 0:
                cluster(buds,end,.045 if stage == 3 else .060,
                        .105 if stage == 3 else .145,stage == 4,rng)
        if stage == 2:
            fan(leaves,spine(tip),2.1,.17,5,.65,.74)
            # Unopened apical meristem.
            cluster(buds,spine(tip),.012,.04,False,rng)
        else:
            cluster(buds,spine(.83),.066 if stage == 3 else .087,
                    .23 if stage == 3 else .29,stage == 4,rng)
    parts = [part for part in (stem, leaves, buds) if part.points]
    scale = HEIGHTS[stage]/max(p.z for part in parts for p in part.points)
    return [part.build(scale) for part in parts]


def preview(objects, path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = -0.65
    scene.world = bpy.data.worlds.new("Studio sky")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.41,.55,.56,1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .38
    for obj in objects:
        material = bpy.data.materials.new("Paint")
        material.use_nodes = True
        color = material.node_tree.nodes.new("ShaderNodeVertexColor")
        color.layer_name = "Preview"
        surface = material.node_tree.nodes.get("Principled BSDF")
        surface.inputs["Roughness"].default_value = .78
        material.node_tree.links.new(color.outputs["Color"], surface.inputs["Base Color"])
        if obj.name == "Leaves":
            # Fine painted midrib in the same leaflet UVs sampled in Godot.
            nodes, links = material.node_tree.nodes, material.node_tree.links
            coords = nodes.new("ShaderNodeTexCoord")
            split = nodes.new("ShaderNodeSeparateXYZ")
            links.new(coords.outputs["UV"], split.inputs[0])
            midrib = nodes.new("ShaderNodeValToRGB")
            ramp = midrib.color_ramp
            ramp.elements[0].position = .464
            ramp.elements[0].color = (0,0,0,1)
            ramp.elements[1].position = .50
            ramp.elements[1].color = (.63,.63,.63,1)
            ramp.elements.new(.536).color = (0,0,0,1)
            links.new(split.outputs["X"], midrib.inputs[0])
            paint = nodes.new("ShaderNodeMixRGB")
            links.new(midrib.outputs[0], paint.inputs[0])
            links.new(color.outputs[0], paint.inputs[1])
            paint.inputs[2].default_value = (.51,.67,.18,1)
            links.new(paint.outputs[0], surface.inputs["Base Color"])
        obj.data.materials.append(material)
    points = [v.co for obj in objects for v in obj.data.vertices]
    height = max(p.z for p in points)
    for location, power, tint in (((-1.5,-2.3,3.8),170,(1,.88,.71)),
                                  ((1.9,-1.2,1.4),70,(.74,.87,1)),
                                  ((-.6,1.3,2.5),140,(.94,1,.77))):
        bpy.ops.object.light_add(type="AREA",location=Vector(location)*height)
        light = bpy.context.object
        light.rotation_euler = (UP*height*.5-light.location).to_track_quat("-Z","Y").to_euler()
        light.data.energy = power*height**2
        light.data.shape = "DISK"
        light.data.size = height*1.6
        light.data.color = tint
    bpy.ops.mesh.primitive_plane_add(size=200*height)
    floor = bpy.context.object
    matte = bpy.data.materials.new("Backdrop")
    matte.use_nodes = True
    matte.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.039,.066,.056,1)
    floor.data.materials.append(matte)
    target = Vector((0,0,max(p.z for p in points)*.5))
    direction = Vector((1.2,-2.8,2.05)).normalized()
    bpy.ops.object.camera_add(location=target + direction*4)
    cam = bpy.context.object
    cam.rotation_euler = (-direction).to_track_quat("-Z","Y").to_euler()
    rotation = cam.rotation_euler.to_matrix().transposed()
    projected = [rotation @ (p-target) for p in points]
    bounds = [(min(p[i] for p in projected),max(p[i] for p in projected)) for i in (0,1)]
    cam.location += rotation.transposed() @ Vector((*[(a+b)/2 for a,b in bounds],0))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(b-a for a,b in bounds)*1.13
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    MODELS.mkdir(parents=True,exist_ok=True)
    PREVIEWS.mkdir(parents=True,exist_ok=True)
    for index, suffix in enumerate(STAGES):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        objects = generate(index)
        triangles = sum(len(p.vertices)-2 for o in objects for p in o.data.polygons)
        assert triangles <= 4000, (suffix,triangles)
        name = "plant_"+suffix
        bpy.ops.export_scene.gltf(filepath=str(MODELS/(name+".glb")),
                                  export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                                  export_attributes=False, export_materials="NONE",export_yup=True)
        preview(objects,PREVIEWS/(name+".png"))
        print(name,triangles,flush=True)


if __name__ == "__main__":
    main()
