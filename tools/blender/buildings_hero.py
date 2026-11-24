"""Rebuild GAFTI hero buildings and their 512 px previews with run_blender.ps1."""
from pathlib import Path
import json
import math
import random
import struct

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/hero"
PREVIEW = ROOT / "tools/previews"
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)

# Geometry uses Blender metres, with the front at -Y (Godot +Z).
parts = {}
rng = random.Random(1912)
wood = ["945638", "aa6941", "a76039", "b97749", "995b3c"]
beamwood = "683e30"
trim = "ecc895"
green = "377465"
stone = ["72837c", "677776", "8a9284", "778986", "929685", "737e78"]
moss = ["799348", "637e48", "97a850"]
glass = "8bc9c3"
roof = "aa5140"


def linear(h):
    c = int(h, 16) / 255
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4


def mesh(name, vertices, faces, color):
    verts, polys, colors = parts.setdefault(name, ([], [], []))
    offset = len(verts)
    verts.extend(vertices)
    polys.extend([tuple(i + offset for i in face) for face in faces])
    tone = tuple(linear(color[i:i+2]) for i in (0, 2, 4))
    colors.extend([(*tone, 1)] * len(vertices))


def block(name, p, size, color, bevel=0, rotation=None):
    a, b, c = (v / 2 for v in size)
    r = min(bevel, a * .45, b * .45, c * .45)
    # Clipped upper and lower edges catch light without subdivision.
    rings = [(-c, r), (-c+r, 0), (c-r, 0), (c, r)] if r else [(-c, 0), (c, 0)]
    verts = []
    for z, inset in rings:
        for x, y in [(-a+inset,-b+inset),(a-inset,-b+inset),
                     (a-inset,b-inset),(-a+inset,b-inset)]:
            v = Vector((x,y,z))
            verts.append((rotation @ v if rotation else v) + Vector(p))
    last = len(verts) - 4
    faces = [(3,2,1,0), tuple(range(last,last+4))]
    for i in range(0, last, 4):
        faces.extend((i+j,i+(j+1)%4,i+(j+1)%4+4,i+j+4) for j in range(4))
    mesh(name, verts, faces, color)


def rail(name, start, end, width, depth, color, bevel=0):
    a, b = Vector(start), Vector(end)
    delta = b-a
    block(name, (a+b)/2, (width,depth,delta.length), color, bevel,
          delta.to_track_quat('Z','Y'))


def revolve(name, p, rings, color, n=10):
    vs = [(p[0]+r*math.cos(i*math.tau/n), p[1]+r*math.sin(i*math.tau/n), p[2]+z)
          for z,r in rings for i in range(n)]
    last = len(vs)-n
    faces = [tuple(reversed(range(n))),tuple(range(last,last+n))]
    faces.extend((j+i,j+(i+1)%n,j+n+(i+1)%n,j+n+i)
                 for j in range(0,last,n) for i in range(n))
    mesh(name, vs, faces, color)


def collider(name, p, size):
    block(name+"-col", p, size, "ffffff")


def enclosure(half_x, half_y, height, opening, head, thick):
    for s, label in [(-1,"West"),(1,"East")]:
        collider(label+"Wall", (s*half_x,0,height/2), (thick,2*half_y,height))
        span = half_x-opening/2
        collider("Front"+label, (s*(opening/2+span/2),-half_y,height/2),
                 (span,thick,height))
    collider("RearWall", (0,half_y,height/2), (2*half_x,thick,height))
    collider("Lintel", (0,-half_y,(head+height)/2), (opening,thick,height-head))


def masonry(name, start, end, rows, height, width, thick, mossy=False):
    a, b = Vector(start), Vector(end)
    direction = (b-a).normalized()
    length = (b-a).length
    sideways = abs(direction.y) > .5
    for row in range(rows):
        cuts = [0]
        target = width * (.48 if row % 2 else 1)
        while length-cuts[-1] > target+.32:
            cuts.append(cuts[-1]+target)
            target = width*rng.uniform(.78,1.23)
        cuts.append(length)
        for lo,hi in zip(cuts,cuts[1:]):
            p = a + direction*((lo+hi)/2)
            p.z += (row+.5)*height
            t = thick + rng.uniform(.008,.045)
            size = (t,hi-lo-.012,height-.012) if sideways else (hi-lo-.012,t,height-.012)
            if name == "Stonework":
                # Extrude a five-sided split-stone profile along the wall normal.
                half=(hi-lo-.012)/2
                dz=(height-.012)/2
                profile=[(-half,-dz),(half,-dz),(half,dz-.05),
                         (half-.12,dz),(-half+.035,dz)]
                local=[(u,v,w) for v in [-t/2,t/2] for u,w in profile]
                verts=[p+Vector((-v,u,w) if sideways else (u,v,w)) for u,v,w in local]
                faces=[(0,1,2,3,4),(9,8,7,6,5)]
                faces.extend((i,5+i,5+(i+1)%5,(i+1)%5) for i in range(5))
                mesh(name,verts,faces,rng.choice(stone))
            else:
                block(name,p,size,rng.choice(stone),.045)
            if mossy and row==rows-1 and rng.random()<.68:
                p.z += height/2
                size = (t*.93,(hi-lo)*.79,.045) if sideways else ((hi-lo)*.79,t*.93,.045)
                block(name,p,size,rng.choice(moss),.02)


def lamp(group, x,y,z):
    revolve(group,(x,y,z),[(0,.09),(.06,.15),(.3,.11)],"ffc371",8)
    revolve(group,(x,y,z),[(.29,.23),(.34,.24),(.49,.06)],green,10)
    revolve(group,(x,y,z),[(-.04,.08),(0,.12)],beamwood,8)


def greenhouse():
    g = "TimberFrame"
    block("Floor",(0,0,-.065),(12.25,6.25,.13),"99856a")
    collider("Floor",(0,0,-.065),(12.25,6.25,.13))
    enclosure(6.1,3.1,2.8,1.84,2.41,.20)
    for y in [-3.1,3.1]:
        runs = [(-6.12,-1),(1,6.12)] if y<0 else [(-6.12,6.12)]
        for lo,hi in runs:
            masonry("MossyFooting",(lo,y,0),(hi,y,0),2,.23,1,.29,True)
            for h in [.5,1.52,2.8]:
                block(g,((lo+hi)/2,y,h),(hi-lo,.13,.105),wood[2],.016)
        for x in [-6.1,-4.4,-2.7,-1,1,2.7,4.4,6.1]:
            block(g,(x,y,1.6),(.14,.17,2.52),rng.choice(wood),.016)
        for lo,hi in zip([-6.1,-4.4,-2.7,-1,1,2.7,4.4],[-4.4,-2.7,-1,1,2.7,4.4,6.1]):
            floor = 2.48 if y<0 and lo==-1 else .52
            mesh("Glass",[(lo,y,floor),(hi,y,floor),(hi,y,2.8),(lo,y,2.8)],[(0,1,2,3)],glass)
    block(g,(0,-3.1,2.46),(2.12,.22,.10),trim,.015)
    # Offset ridge and uneven pitch echo an old, field-repaired structure.
    for side in [-1,1]:
        y=side*3.27
        # Leave the glazing absent beneath the operable front roof light.
        spans=[(-6.23,-4.4),(-2.7,6.23)] if side==-1 else [(-6.23,6.23)]
        if side==-1:
            mesh("Glass",[(-4.4,y,2.81),(-2.7,y,2.81),(-2.7,-1.49,3.315),(-4.4,-1.49,3.315)],[(0,1,2,3)],glass)
            corners=[(-4.4,.29,3.84),(-2.7,.29,3.84),(-2.7,-1.46,4.06),(-4.4,-1.46,4.06)]
            mesh("Glass",corners,[(0,1,2,3)],glass)
            for j in range(4):
                rail("RoofVent",corners[j],corners[(j+1)%4],.095,.10,green,.01)
            rail("RoofVent",(-3.52,-1.46,3.32),(-3.52,-1.46,4.06),.05,.055,beamwood)
        for lo,hi in spans:
            mesh("Glass",[(lo,y,2.81),(hi,y,2.81),(hi,.29,3.82),(lo,.29,3.82)],
             [(0,1,2,3)],glass)
        block(g,(0,y,2.81),(12.58,.17,.15),green,.02)
        for x in [-6.18,-4.4,-2.7,-1,1,2.7,4.4,6.18]:
            rail(g,(x,y,2.81),(x,.29,3.82),.115,.14,rng.choice(wood))
        block(g,(0,(y+.29)/2,3.31),(12.49,.085,.08),wood[1])
    block(g,(0,.29,3.84),(12.65,.25,.15),green,.025)
    for x in [-6.1,6.1]:
        masonry("MossyFooting",(x,-3.1,0),(x,3.1,0),2,.23,.92,.29,True)
        pts=[(x,-3.1,.47),(x,3.1,.47),(x,3.1,2.8),(x,.29,3.81),(x,-3.1,2.8)]
        mesh("Glass",pts,[(0,1,2,3,4)],glass)
        for h in [.5,1.52,2.79]:
            block(g,(x,0,h),(.15,6.2,.115),wood[3])
        for y in [-1.55,.29,1.55]:
            h=3.78-abs(y-.29)*.34
            block(g,(x,y,(.46+h)/2),(.15,.13,h-.46),wood[0])
    for y,label in [(-.78,"FrontBench"),(1.77,"RearBench")]:
        for j in range(4):
            block(label,(0,y+(j-1.5)*.255,.745),(9.8,.25,.11),wood[j],.012)
        for x in [-4.64,0,4.64]:
            for side in [-1,1]:
                block(label,(x,y+side*.36,.36),(.14,.14,.72),green,.012)
            block(label,(x,y,.64),(.16,1.02,.11),wood[0])
        for side in [-1,1]:
            block(label,(0,y+side*.38,.58),(9.55,.085,.17),green)
        collider(label,(0,y,.40),(9.8,1.015,.80))
    for x in [-4.0,0,4.0]:
        rail("PendantLamps",(x,.29,3.78),(x,.29,3.05),.032,.032,beamwood)
        lamp("PendantLamps",x,.29,2.59)
    # Hairline fractures held by conspicuously mismatched linen tape.
    for x,h in [(-1.9,1.87),(3.57,2.11)]:
        for dx,dz in [(-.37,.34),(.19,.53),(.42,-.39),(-.15,-.31)]:
            rail("PaneRepairs",(x,-3.112,h),(x+dx,-3.112,h+dz),.02,.018,"719892")
        for dx,dz in [(.14,.14),(-.11,-.12)]:
            rail("PaneRepairs",(x+dx-.12,-3.13,h+dz-.06),
                 (x+dx+.12,-3.13,h+dz+.06),.083,.022,"edca83")
    # A hand-painted sprout above the entrance.
    block("NurserySign",(0,-3.26,2.76),(1.20,.12,.43),green,.045)
    for s in [-1,1]:
        mesh("NurserySign",[(0,-3.327,2.69),(s*.19,-3.327,2.70),
                            (s*.32,-3.327,2.84),(s*.13,-3.327,2.82)],[(0,1,2,3)],trim)
    rail("NurserySign",(0,-3.33,2.60),(0,-3.33,2.77),.035,.022,trim)
    # Narrow runner from the doorway and around the benches.
    for x in [-4.8,-3.7,-2.6,-1.5,-.4,.7,1.8,2.9,4.0,5.1]:
        block("Floor",(x,-2.10,.012),(1.04,.72,.024),rng.choice(stone),.01)
    # An open green sliding door parked against the front wall.
    for x in [1.14,2.95]:
        block("SlidingDoor",(x,-3.30,1.19),(.105,.10,2.34),green,.015)
    for h in [.14,.81,2.34]:
        block("SlidingDoor",(2.045,-3.30,h),(1.9,.11,.12),green,.016)
    for i in range(8):
        block("SlidingDoor",(1.27+i*.22,-3.3,.47),(.214,.069,.57),rng.choice(wood))
    mesh("Glass",[(1.18,-3.30,.86),(2.90,-3.30,.86),(2.90,-3.30,2.31),(1.18,-3.30,2.31)],[(0,1,2,3)],glass)
    block("SlidingDoor",(1.19,-3.4,1.13),(.07,.08,.24),trim,.015)
    block("SlidingDoor",(1,-3.31,2.51),(4.26,.09,.08),"424c44")

def window(x,y,h,side=False):
    def piece(dx,dy,dz,w,d,height,color):
        p = (x-dy,y+dx,h+dz) if side else (x+dx,y+dy,h+dz)
        block("Joinery",p,(d,w,height) if side else (w,d,height),color)
    piece(0,0,0,1.03,.13,1.2,beamwood)
    piece(0,-.08,0,.86,.06,1.03,"57827e")
    piece(0,-.13,0,.064,.06,1.07,trim)
    piece(0,-.13,.07,.90,.06,.06,trim)
    piece(0,-.10,-.61,1.28,.28,.10,trim)
    for s in [-1,1]:
        piece(s*.70,0,0,.33,.12,1.12,green)
        for dz in [-.35,-.13,.10,.33]:
            piece(s*.70,-.087,dz,.29,.055,.045,"71a491")


def seam(start,end):
    a,b=Vector(start),Vector(end)
    side=(b-a).cross(Vector((0,0,1))).normalized()*.027
    lift=Vector((0,0,.036))
    mesh("RoofSeams",[a-side,b-side,b+lift,a+lift,a+side,b+side],
         [(0,3,2,1),(3,4,5,2)],"cb7056")


def house():
    xh,yh=3.93,2.94
    enclosure(xh,yh,2.82,1.74,2.28,.26)
    block("Floor",(0,0,-.07),(8.16,6.13,.14),wood[0])
    collider("Floor",(0,0,-.07),(8.16,6.13,.14))
    for i in range(17):
        block("Floor",(0,(i-8)*.35,.013),(7.78,.346,.026),wood[i%5])
    for s in [-1,1]:
        block("LowerWalls",(s*xh,0,1.40),(.25,5.89,2.80),"606b65")
        block("LowerWalls",(s*2.403,-yh,1.4),(3.066,.25,2.8),"606b65")
    block("LowerWalls",(0,yh,1.4),(7.93,.25,2.80),"606b65")
    block("LowerWalls",(0,-yh,2.54),(1.75,.25,.52),"606b65")
    for y in [-yh,yh]:
        spans = [(-3.99,-.92),(.92,3.99)] if y<0 else [(-3.99,3.99)]
        for a,b in spans:
            masonry("Stonework",(a,y,0),(b,y,0),6,.46,1.16,.28)
    for x in [-xh,xh]:
        masonry("Stonework",(x,-2.93,0),(x,2.93,0),6,.46,1.24,.28)
    for x in [-.94,.94]:
        block("Joinery",(x,-3.01,1.14),(.14,.33,2.28),wood[2],.024)
    block("Joinery",(0,-3.01,2.37),(2.08,.34,.18),wood[1],.024)
    for x in [-2.49,2.49]:
        window(x,-3.10,1.57)
    window(4.09,-.70,1.56,True)
    block("UpperStorey",(0,0,3.91),(8.18,6.13,2.34),wood[1],.035)
    for level in range(8):
        z = 2.91+level*.295
        for s in [-1,1]:
            block("UpperStorey",(0,s*3.08,z),(8.20,.07,.285),wood[(level+2)%5])
            block("UpperStorey",(s*4.11,0,z),(.07,6.18,.285),wood[level%5])
    for z in [2.81,5.08]:
        block("UpperStorey",(0,0,z),(8.43,6.38,.19),beamwood,.025)
    for s in [-1,1]:
        for x in [-4.04,-1.44,1.44,4.04]:
            block("UpperStorey",(x,s*3.13,3.95),(.15,.13,2.19),beamwood)
        for y in [-2.98,0,2.98]:
            block("UpperStorey",(s*4.17,y,3.95),(.13,.15,2.19),beamwood)
    for x in [-2.70,2.70]:
        window(x,-3.18,4.02)
    for y in [-1.51,1.51]:
        window(4.19,y,3.98,True)
    block("Joinery",(0,-3.15,3.87),(1.40,.16,2.02),beamwood)
    block("Joinery",(0,-3.25,3.85),(1.19,.07,1.96),green)
    block("Joinery",(0,-3.30,4.13),(.81,.05,.79),"99b6a5")
    block("Joinery",(.42,-3.34,3.64),(.08,.07,.09),trim)
    # Balcony with a carved diamond frieze and exposed knee braces.
    block("Balcony",(0,-3.72,2.82),(7.89,1.32,.22),wood[1],.03)
    for x in [-3.69,-2.46,-1.23,0,1.23,2.46,3.69]:
        rail("Balcony",(x,-3.06,1.96),(x,-4.29,2.71),.16,.17,beamwood,.016)
        block("Balcony",(x,-4.30,3.36),(.14,.16,1.08),green,.012)
        block("Balcony",(x,-4.30,3.91),(.20,.20,.10),trim,.015)
    for i in range(6):
        x=-3.69+i*1.23
        for a,b in [((0,3.34),(.615,3.72)),((.615,3.72),(1.23,3.34)),
                    ((0,3.34),(.615,3.00)),((.615,3.00),(1.23,3.34))]:
            rail("Balcony",(x+a[0],-4.30,a[1]),(x+b[0],-4.30,b[1]),.076,.072,"c79661")
    for z in [3.,3.84]:
        block("Balcony",(0,-4.30,z),(7.61,.17,.11),green,.016)
        for x in [-3.69,3.69]:
            block("Balcony",(x,-3.73,z),(.14,1.29,.10),green)
    # Four pitched standing-seam roof planes over wide deep eaves.
    a,b,z,ridge,rh = 4.91,4.15,5.22,1.83,7.02
    corners=[(-a,-b,z),(a,-b,z),(a,b,z),(-a,b,z)]
    ends=[(-ridge,0,rh),(ridge,0,rh)]
    for i,face in enumerate([(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4)]):
        mesh("HippedRoof",corners+ends,[face],["ad5546","994c3e","b7624a","9e493e"][i])
    for i in range(4):
        rail("HippedRoof",corners[i],corners[(i+1)%4],.19,.20,beamwood,.017)
        rail("HippedRoof",corners[i],ends[0 if i in (0,3) else 1],.105,.105,"cb7659")
    mesh("HippedRoof",corners,[(3,2,1,0)],wood[0])
    rail("HippedRoof",*ends,.16,.16,"d48964",.018)
    for x in [j*.52 for j in range(-9,10)]:
        f=min(1,(a-abs(x))/(a-ridge))
        for s in [-1,1]:
            seam((x,s*b,z+.023),(x,s*b*(1-f),z+f*(rh-z)+.023))
    for y in [j*.59 for j in range(-6,7)]:
        f=1-abs(y)/b
        for s in [-1,1]:
            seam((s*a,y,z+.02),(s*(a-(a-ridge)*f),y,z+f*(rh-z)+.02))
    for j in range(7):
        block("Chimney",(-2.63,1.01,6.18+j*.20),(.62,.67,.207),stone[j%len(stone)],.018)
    block("Chimney",(-2.63,1.01,7.54),(.79,.85,.14),beamwood,.025)
    block("Chimney",(-2.63,1.01,7.62),(.56,.56,.06),"38423e")
    for x in [-2.53,2.53]:
        block("WindowBoxes",(x,-3.34,.96),(1.41,.36,.24),green,.025)
        for j in range(11):
            xx=x-.6+j*.12
            h=rng.uniform(.13,.36)
            revolve("WindowBoxes",(xx,-3.38,1.05),[(0,.06),(h*.64,.13),(h,.025)],rng.choice(moss),5)
            if j%2==0:
                revolve("WindowBoxes",(xx,-3.41,1.05+h),[(0,.04),(.05,.09),(.09,.05)],rng.choice(["e98b68","edb16b"]),6)
    lamp("PorchLamp",1.32,-3.32,1.96)
    block("PorchLamp",(1.32,-3.21,2.44),(.10,.38,.10),beamwood)
    # Ground-floor furniture, leaving the middle of the room clear.
    for name,p,size,color,bev in [
        ("Bed",(-2.86,1.35,.27),(1.55,2.39,.43),wood[0],.05),
        ("Bed",(-2.86,1.35,.55),(1.49,2.26,.23),"e6caa0",.08),
        ("Bed",(-2.86,1.02,.69),(1.53,1.59,.12),green,.04),
        ("Bed",(-2.86,2.10,.72),(1.04,.47,.16),"f2dcb5",.07),
        ("Sofa",(2.47,1.94,.38),(2.38,.91,.55),"ae6241",.10),
        ("Sofa",(2.47,2.34,.74),(2.38,.27,.83),"a65d41",.10),
        ("Mirror",(3.76,-1.25,1.45),(.15,1.06,1.51),wood[3],.05),
        ("Mirror",(3.66,-1.25,1.45),(.06,.89,1.33),"a7c7c2",.025)]:
        block(name,p,size,color,bev)
    for x in [1.38,3.56]:
        block("Sofa",(x,1.94,.64),(.23,.95,.47),"bb7654",.09)
    for x in [1.98,2.95]:
        block("Sofa",(x,1.85,.65),(.93,.68,.16),"db9969",.055)
    for j in range(4):
        block("Bed",(-2.86,.55+j*.13,.753),(1.49,.05,.011),trim)
    collider("Bed",(-2.86,1.35,.34),(1.55,2.39,.68))
    collider("Sofa",(2.47,1.94,.42),(2.38,.97,.84))


def material(name,alpha):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.use_backface_culling=False
    nodes=mat.node_tree.nodes
    bs=nodes.get("Principled BSDF")
    color=nodes.new("ShaderNodeVertexColor")
    color.layer_name="Paint"
    mat.node_tree.links.new(color.outputs["Color"],bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value=.80 if alpha==1 else .28
    bs.inputs["Alpha"].default_value=alpha
    if alpha<1:
        mat.surface_render_method='BLENDED'
    return mat


def realize():
    painted=material("Highland paint",1)
    glazing=material("Rainwashed glass",.22)
    invisible=material("Collision proxy",0)
    for name,(vs,faces,colors) in parts.items():
        data=bpy.data.meshes.new(name)
        data.from_pydata(vs,[],faces)
        data.materials.append(invisible if name.endswith("-col") else glazing if name=="Glass" else painted)
        attr=data.color_attributes.new(name="Paint",type="FLOAT_COLOR",domain="POINT")
        attr.data.foreach_set("color",[ch for c in colors for ch in c])
        obj=bpy.data.objects.new(name,data)
        bpy.context.collection.objects.link(obj)
        if name.endswith("-col"):
            obj.hide_render=True


def preview(name):
    scene=bpy.context.scene
    scene.render.engine='BLENDER_EEVEE'
    scene.view_settings.look='AgX - Medium High Contrast'
    scene.render.resolution_x=scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new("Overcast sky")
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value=(.71,.78,.82,1)
    bg.inputs[1].default_value=.40
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.14))
    floor=bpy.data.materials.new("Studio sage")
    floor.diffuse_color=(.26,.34,.28,1)
    bpy.context.object.data.materials.append(floor)
    for p,power,size in [((-6,-9,13),2600,8),((7,-4,8),1150,7),((0,8,12),2000,6)]:
        bpy.ops.object.light_add(type='AREA',location=p)
        light=bpy.context.object
        light.data.energy=power
        light.data.shape='DISK'
        light.data.size=size
        light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
    target=Vector((0,0,1.5 if name=="greenhouse" else 3.15))
    bpy.ops.object.camera_add(location=target+Vector((9,-17,8.2)))
    camera=bpy.context.object
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'
    camera.data.ortho_scale=16.1 if name=='greenhouse' else 14.6
    scene.camera=camera
    scene.render.filepath=str(PREVIEW/(name+'.png'))
    bpy.ops.render.render(write_still=True)


def generate(name, builder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts.clear()
    rng.seed(1912)
    builder()
    realize()
    path=OUT/(name+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,
                              export_vertex_color='ACTIVE',export_cameras=False,export_lights=False)
    raw=path.read_bytes()
    length=struct.unpack_from('<I',raw,12)[0]
    gltf=json.loads(raw[20:20+length])
    tris=sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
    assert tris<=8000,(name,tris)
    print(name,tris,"triangles",flush=True)
    preview(name)


generate("greenhouse",greenhouse)
generate("house",house)


