"""Build Pusludere's shared character rig, wardrobe and studio portraits."""
from pathlib import Path
from math import sin, cos, pi, radians
import json
import struct

import bpy
from mathutils import Vector, Euler, Quaternion

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/hero/character_base.glb"
PREVIEW = ROOT / "tools/previews"
OUT.parent.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

def paint(name, hex_color):
    rgb = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    rgba = [((c+.055)/1.055)**2.4 if c>.04045 else c/12.92 for c in rgb] + [1]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = rgba
    shader.inputs["Roughness"].default_value = .78
    return mat

skin = paint("Skin", "DC986F")
hair = paint("Hair", "51332D")
ink = paint("Lash", "30262C")
ivory = paint("Oat", "FAE9CB")
iris = paint("Hazel", "506A50")
lip = paint("Smile", "964F46")
top = paint("Cloth_Top", "E6AB38")
knit = paint("Cloth_Knit", "356E62")
linen = paint("Cloth_Linen", "BE7055")
pants = paint("Cloth_Pants", "42566A")
boot = paint("Boots", "304D47")
trim = paint("Leather", "68493A")
brass = paint("Brass", "E4B15E")
band = paint("Pine", "224E49")
# Geometry is authored in Blender metres, facing -Y (glTF +Z).
arm = bpy.data.armatures.new("CharacterSkeleton")
rig = bpy.data.objects.new("Armature", arm)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
def bone(name, a, b, parent=None):
    eb = arm.edit_bones.new(name)
    eb.head, eb.tail = a,b
    if parent:
        eb.parent = arm.edit_bones[parent]
bone("hips",(0,0,.71),(0,0,.85))
bone("spine",(0,0,.85),(0,0,1.02),"hips")
bone("chest",(0,0,1.02),(0,0,1.19),"spine")
bone("neck",(0,0,1.19),(0,0,1.31),"chest")
bone("head",(0,0,1.31),(0,0,1.72),"neck")
for s, side in [(1,".L"),(-1,".R")]:
    for names, pts, parent in [
        (["shoulder","upper_arm","forearm","hand"],[(0,0,1.16),(.192,0,1.15),(.286,0,.965),(.326,-.029,.793),(.345,-.045,.68)],"chest"),
        (["thigh","shin","foot"],[(.102,0,.75),(.112,-.012,.425),(.12,0,.14),(.12,-.12,.055)],"hips")]:
        for i,name in enumerate(names):
            bone(name+side, (s*pts[i][0],*pts[i][1:]),(s*pts[i+1][0],*pts[i+1][1:]),parent)
            parent = name+side
bpy.ops.object.mode_set(mode='OBJECT')

class Part:
    def __init__(self,name):
        self.name=name
        self.verts=[]; self.faces=[]; self.slots=[]; self.weights=[]; self.indices=[]
    def surface(self, rings, material, weights, smooth=True):
        n=len(rings[0]); base=len(self.verts)
        if material not in self.slots: self.slots.append(material)
        for ring,w in zip(rings,weights):
            self.verts.extend(ring); self.weights.extend([w]*n)
        faces=[tuple(base+i for i in reversed(range(n)))]
        for j in range(len(rings)-1):
            for i in range(n):
                a=base+j*n+i; b=base+j*n+(i+1)%n
                faces.append((a,b,b+n,a+n))
        faces.append(tuple(base+(len(rings)-1)*n+i for i in range(n)))
        self.faces.extend(faces); self.indices.extend([self.slots.index(material)]*len(faces))
    def loft(self,rows,mat,w,n=12):
        rings=[[(x+rx*cos(i*2*pi/n),y+ry*sin(i*2*pi/n),z) for i in range(n)] for x,y,z,rx,ry in rows]
        self.surface(rings,mat,[w]*len(rows) if isinstance(w,str) else w)
    def oval(self,center,radii,mat,w,n=10,k=5,angle=0):
        n=max(3,round(n*.83)); k=max(2,k-1)
        x,y,z=center; a,b,c=radii; rings=[]
        for j in range(k+1):
            v=-pi/2+.035+(pi-.07)*j/k
            ring=[]
            for i in range(n):
                t=2*pi*i/n; dx=a*cos(v)*cos(t); dz=c*sin(v)
                ring.append((x+dx*cos(angle)-dz*sin(angle),y+b*cos(v)*sin(t),z+dx*sin(angle)+dz*cos(angle)))
            rings.append(ring)
        self.surface(rings,mat,[w]*len(rings))
    def stroke(self,points,radii,mat,w,n=6):
        p=list(map(Vector,points)); rings=[]
        for i,(v,r) in enumerate(zip(p,radii)):
            tangent=(p[min(i+1,len(p)-1)]-p[max(0,i-1)]).normalized()
            ref=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0))
            u=tangent.cross(ref).normalized(); q=tangent.cross(u)
            rings.append([tuple(v+r*(u*cos(2*pi*j/n)+q*sin(2*pi*j/n))) for j in range(n)])
        self.surface(rings,mat,[w]*len(p))
    def finish(self):
        mesh=bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.verts,[],self.faces); mesh.update()
        obj=bpy.data.objects.new(self.name,mesh); scene.collection.objects.link(obj)
        for m in self.slots: mesh.materials.append(m)
        for f,idx in zip(mesh.polygons,self.indices): f.material_index=idx; f.use_smooth=True
        for i,w in enumerate(self.weights):
            for key,value in ({w:1} if isinstance(w,str) else w).items():
                group=obj.vertex_groups.get(key) or obj.vertex_groups.new(name=key)
                group.add([i],value,'REPLACE')
        obj.parent=rig; mod=obj.modifiers.new("Skinning",'ARMATURE'); mod.object=rig
        return obj

def torso(part,profile,mat,weights,n=16):
    part.loft([(0,0,z,x,y) for z,x,y in profile],mat,weights,n)

body=Part("Body")
torso(body,[(.704,.103,.085),(.78,.16,.11),(.91,.143,.103),(1.07,.182,.115),(1.14,.187,.11),(1.19,.09,.075),(1.31,.075,.07)],skin,["hips","hips","spine","chest","chest","neck","neck"])
torso(body,[(1.24,.055,.075),(1.27,.115,.12),(1.32,.163,.15),(1.40,.198,.173),(1.49,.202,.182),(1.59,.196,.177),(1.67,.16,.145),(1.714,.082,.095),(1.72,.025,.028)],skin,"head",24)
for s,side in [(1,".L"),(-1,".R")]:
    body.oval((s*.194,.001,1.432),(.042,.032,.062),skin,"head",12)
    body.oval((s*.212,-.025,1.432),(.016,.009,.027),lip,"head",8,4)
    body.oval((s*.081,-.158,1.489),(.049,.027,.045),ivory,"head",14,6,s*.06)
    body.oval((s*.079,-.18,1.488),(.025,.012,.031),iris,"head",12)
    body.oval((s*.079,-.19,1.49),(.014,.006,.022),ink,"head",10)
    body.oval((s*.079-.006,-.195,1.501),(.006,.004,.007),ivory,"head",8,3)
    body.stroke([(s*.033,-.177,1.50),(s*.06,-.182,1.526),(s*.089,-.179,1.531),(s*.118,-.16,1.517),(s*.133,-.146,1.50)],[.002,.005,.006,.005,.002],ink,"head")
    body.stroke([(s*.033,-.175,1.548),(s*.067,-.174,1.562),(s*.099,-.162,1.564),(s*.137,-.14,1.548)],[.005,.012,.012,.003],hair,"head")
    for i in range(3):
        body.oval((s*(.109+i*.011),-.149+i*.009,1.432+.004*(i%2)),(.003,.003,.003),lip,"head",5,2)
    body.loft([(s*x,y,z,a,b) for x,y,z,a,b in [(.335,-.03,.75,.035,.04),(.325,-.025,.80,.04,.044),(.307,-.012,.875,.049,.052),(.286,0,.965,.05,.055),(.25,0,1.055,.06,.064),(.19,0,1.143,.055,.053)]],skin,["hand"+side,"forearm"+side,"forearm"+side,{"upper_arm"+side:.5,"forearm"+side:.5},"upper_arm"+side,"upper_arm"+side])
    body.oval((s*.337,-.035,.737),(.054,.055,.077),skin,"hand"+side,12,5)
    body.oval((s*.302,-.074,.746),(.023,.023,.042),skin,"hand"+side,8,4,-s*.24)
    body.loft([(s*.12,0,.10,.042,.051),(s*.115,0,.42,.059,.061),(s*.10,0,.74,.075,.075)],skin,["shin"+side,{"shin"+side:.5,"thigh"+side:.5},"thigh"+side])
body.oval((0,-.182,1.436),(.043,.055,.045),skin,"head",14,6)
body.stroke([(-.061,-.159,1.385),(-.041,-.169,1.376),(0,-.175,1.371),(.036,-.17,1.376),(.06,-.159,1.386)],[.002,.005,.006,.005,.002],lip,"head",8)
body.finish()

# Sculpted hairlines wrap high across the forehead and low over the nape.
def scalp(part,style):
    rings=[]
    for j in range(5):
        ring=[]
        for i in range(16):
            a=2*pi*i/16; front=max(0,-sin(a))
            edge=-.52+1.05*front+.06*cos(3*a+style)
            v=edge+(1.54-edge)*j/4
            ring.append((.227*cos(v)*cos(a),.002+.209*cos(v)*sin(a),1.514+.239*sin(v)))
        rings.append(ring)
    part.surface(rings,hair,["head"]*5)

for style in range(1,7):
    h=Part(f"Hair_{style:02}")
    if style==4:
        for s in (-1,1): h.oval((s*.181,.016,1.481),(.032,.112,.10),hair,"head",12,5)
        h.oval((0,.146,1.49),(.164,.044,.087),hair,"head")
    else:
        scalp(h,style)
        if style in (1,5):
            for i in range(4):
                h.oval((-.12+i*.065,-.118+.018*abs(i-1.5),1.615+.017*i),(.055,.077,.086 if style==5 else .062),hair,"head",10,4,-.68)
            if style==5:
                for s in (-1,1): h.oval((s*.179,.016,1.45),(.05,.14,.127),hair,"head",12,5,s*.18)
        elif style==2:
            for i in range(12):
                a=2*pi*i/12
                h.oval((.166*cos(a),.149*sin(a),1.616+.034*(-sin(a))),(.067,.067,.066),hair,"head",8,4)
        elif style==3:
            h.oval((0,.171,1.534),(.067,.076,.059),brass,"head")
            h.oval((0,.194,1.421),(.081,.085,.146),hair,"head",12,5)
        else:
            h.oval((0,.145,1.652),(.080,.079,.082),brass,"head")
            h.oval((0,.167,1.68),(.102,.09,.099),hair,"head",12,6)
    h.finish()

for style in range(5):
    b=Part(f"Beard_{style:02}")
    if style==0: b.oval((0,0,1.45),(.001,)*3,hair,"head",3,2)
    if style in (1,2,4):
        for s in (-1,1):
            b.stroke([(s*.003,-.19,1.407),(s*.031,-.19,1.412),(s*.059,-.17,1.401),(s*.085,-.155,1.395),(s*(.126 if style==2 else .09),-.144,1.42 if style==2 else 1.391)],[.008,.018,.019,.012,.002],hair,"head",8)
    if style in (3,4):
        for i in range(13):
            a=pi*i/12
            x=.151*cos(a); y=-.049-.103*sin(a); z=1.354-.048*sin(a)
            if style==4: b.oval((x,y,z),(.052,.038,.056),hair,"head",8,4)
            else:
                for k in range(2): b.stroke([(x,y-.009,z+k*.014),(x+.003,y-.012,z+.008+k*.014)],[.002,.0025],hair,"head",4)
    b.finish()
hat=Part("Hat_Kasket")
hat.loft([(0,0,1.60,.201,.189),(0,0,1.63,.213,.196),(0,-.013,1.66,.22,.206),(.008,0,1.708,.206,.189),(.014,.026,1.754,.147,.139),(.014,.035,1.771,.042,.042)],knit,"head",20)
hat.oval((0,-.145,1.624),(.187,.115,.022),band,"head",18,4)
hat.oval((.014,.036,1.774),(.019,.02,.009),trim,"head")
hat.finish()

for label,mat in [("Raincoat",top),("Sweater",knit),("Shirt",linen)]:
    g=Part("Top_"+label)
    rain=label=="Raincoat"; sweater=label=="Sweater"
    low=.671 if rain else .759
    profile=[(low,.219 if rain else .183,.148 if rain else .128),(low+.028,.223 if rain else .188,.15 if rain else .132),(.91,.191,.136),(1.052,.204,.144),(1.134,.219,.13),(1.166,.17,.11),(1.198,.089,.085)]
    torso(g,profile,mat,["hips","hips","spine","chest","chest","chest","neck"])
    torso(g,[(1.178,.10,.09),(1.206,.099,.093),(1.217,.085,.082)],band if sweater else mat,"neck",16)
    for s,side in [(1,".L"),(-1,".R")]:
        arm_profile=[(.326,-.026,.795,.052,.057),(.323,-.025,.823,.058,.061),(.301,-.01,.905,.063,.069),(.284,0,.973,.071,.074),(.256,0,1.045,.077,.084),(.219,0,1.119,.088,.088),(.188,0,1.154,.071,.070),(.174,0,1.165,.052,.056),(.157,0,1.169,.032,.033)]
        groups=["forearm"+side]*3+[{"upper_arm"+side:.5,"forearm"+side:.5}]+["upper_arm"+side]*5
        g.loft([(s*x,y,z,a,b) for x,y,z,a,b in arm_profile],mat,groups,10)
        g.loft([(s*.326,-.025,.788,.053,.057),(s*.323,-.024,.818,.058,.061)],band if sweater else mat,"forearm"+side)
        if rain:
            # Slanted patch-pocket welt follows the chest contour.
            g.stroke([(s*.086,-.13,.841),(s*.116,-.12,.852),(s*.154,-.099,.872)],[.009,.011,.009],trim,"spine")
        if label=="Shirt":
            g.stroke([(s*.086,-.022,1.192),(s*.075,-.081,1.163),(s*.047,-.139,1.126),(s*.016,-.119,1.166)],[.009,.021,.012,.007],ivory,"chest",5)
    if sweater:
        # Fair Isle diamonds follow the elliptical yoke, including its reverse.
        for i in range(18):
            a=2*pi*i/18; rings=[]
            for da,dz in [(0,-.024),(.118,0),(0,.024),(-.118,0)]:
                rings.append((.211*cos(a+da),.146*sin(a+da),1.053+dz))
            mid=tuple(sum(p[k] for p in rings)/4 for k in range(3))
            idx=len(g.verts); g.verts.extend(rings+[mid]); g.weights.extend(["chest"]*5)
            if ivory not in g.slots: g.slots.append(ivory)
            for k in range(4):
                g.faces.append((idx+k,idx+4,idx+(k+1)%4)); g.indices.append(g.slots.index(ivory))
        for z in [1.009,1.095]:
            torso(g,[(z,.207,.144),(z+.009,.208,.144)],brass,"chest",18)
    else:
        for i in range(5):
            z=.801+i*.078; y=-.149 if rain else -.145
            g.oval((0,y,z),(.009,.007,.009),brass if rain else ivory,"chest" if z>1 else "spine",8,3)
        if rain:
            g.oval((0,.095,1.101),(.161,.091,.109),top,"chest",14,6)
    g.finish()

p=Part("Pants_01")
torso(p,[(.663,.045,.067),(.69,.134,.105),(.76,.177,.118),(.812,.169,.113)],pants,"hips")
torso(p,[(.786,.174,.119),(.815,.173,.118)],trim,"hips")
for s,side in [(1,".L"),(-1,".R")]:
    p.loft([(s*x,y,z,a,b) for x,y,z,a,b in [(.12,0,.177,.061,.069),(.12,0,.29,.072,.076),(.115,0,.395,.075,.08),(.111,-.009,.45,.083,.089),(.101,0,.597,.091,.097),(.087,0,.744,.103,.109)]],pants,["shin"+side,"shin"+side,"shin"+side,{"shin"+side:.45,"thigh"+side:.55},"thigh"+side,"thigh"+side])
p.finish()
b=Part("Boots_Rubber")
for s,side in [(1,".L"),(-1,".R")]:
    b.loft([(s*.12,y,z,a,d) for y,z,a,d in [(-.04,.018,.083,.14),(-.042,.044,.088,.146),(-.047,.072,.086,.14),(-.039,.099,.079,.127),(-.014,.129,.07,.088),(0,.161,.068,.077),(0,.269,.079,.084),(0,.298,.078,.083)]],boot,["foot"+side]*4+[{"foot"+side:.55,"shin"+side:.45}]+["shin"+side]*3,16)
    b.loft([(s*.12,-.043,z,a,d) for z,a,d in [(0,.08,.135),(.009,.089,.146),(.031,.09,.148),(.039,.086,.143)]],band,"foot"+side,16)
    b.loft([(s*.12,0,.277,.08,.086),(s*.12,0,.302,.082,.087)],brass,"shin"+side)
b.finish()

# Rotations are expressed around character-space axes then converted to each
# bone's rest basis. Hips shifts are applied in metres in the same space.
def make_action(name,frames):
    rig.animation_data_create()
    act=bpy.data.actions.new(name); rig.animation_data.action=act
    for frame,rots,shift in frames:
        for pb in rig.pose.bones:
            basis=pb.bone.matrix_local.to_quaternion()
            angles=rots.get(pb.name,(0,0,0))
            q=Euler([radians(v) for v in angles]).to_quaternion()
            pb.rotation_quaternion=basis.inverted() @ q @ basis
            pb.keyframe_insert(data_path="rotation_quaternion",frame=frame,group=pb.name)
        hips=rig.pose.bones["hips"]
        hips.location=hips.bone.matrix_local.to_quaternion().inverted() @ Vector(shift)
        hips.keyframe_insert(data_path="location",frame=frame,group="hips")
    act.use_fake_user=True
    rig.animation_data.action=None
    for pb in rig.pose.bones:
        pb.location=(0,0,0)
        pb.rotation_quaternion=(1,0,0,0)
    return act

def row(frame,rot=None,z=0):
    return (frame,rot or {},(0,0,z))
make_action("idle",[row(1),row(31,{"chest":(-2,0,1),"head":(1,-2,-2),"upper_arm.L":(-2,0,0)},.008),row(61)])
for name,period,swing in [("walk",30,26),("run",20,47)]:
    rows=[]
    for i in range(9):
        phase=i*pi/4
        d={"chest":(13 if name=="run" else 4,0,4*sin(phase)),"head":(-4,0,-3*sin(phase))}
        for s,suffix in [(1,".L"),(-1,".R")]:
            stride=s*sin(phase); lift=max(0,s*cos(phase))
            d["thigh"+suffix]=(-swing*stride,0,0)
            d["shin"+suffix]=((48 if name=="run" else 30)*lift,0,0)
            d["foot"+suffix]=(swing*.36*stride-19*lift,0,0)
            d["upper_arm"+suffix]=(swing*.79*stride,0,0)
            d["forearm"+suffix]=(-48 if name=="run" else -13,0,0)
        rows.append(row(1+round(i*period/8),d,.024*(1-cos(2*phase))/2))
    make_action(name,rows)
reach={"chest":(14,0,4),"upper_arm.R":(-48,-10,5),"forearm.R":(-30,0,0),"head":(8,0,0)}
make_action("interact",[row(1),row(11,reach),row(19,{**reach,"hand.R":(-16,5,0)}),row(32)])
seated={"thigh.L":(-85,0,0),"thigh.R":(-85,0,0),"shin.L":(85,0,0),"shin.R":(85,0,0),"upper_arm.L":(-20,0,0),"upper_arm.R":(-20,0,0),"forearm.L":(-60,0,0),"forearm.R":(-60,0,0),"chest":(7,0,0)}
make_action("sit",[row(1),row(18,seated,-.285),row(51,seated,-.285)])
rolling={"head":(16,0,0),"chest":(10,0,0)}
for s,side in [(1,".L"),(-1,".R")]:
    rolling["upper_arm"+side]=(-28,s*18,0)
    rolling["forearm"+side]=(-65,0,-s*28)
rows=[row(1)]
for i in range(5):
    rows.append(row(12+6*i,{**rolling,"hand.L":(12*(-1)**i,0,7),"hand.R":(-12*(-1)**i,0,-7)}))
make_action("roll",rows+[row(48)])
inhale={"upper_arm.R":(-40,-22,0),"forearm.R":(-110,0,28),"head":(5,0,-8)}
make_action("smoke",[row(1),row(19,inhale),row(35,{**inhale,"head":(-4,0,-6)},.009),row(54)])
make_action("faint",[row(1),row(14,{"chest":(-12,-12,0),"head":(-20,8,0)}),row(26,{"hips":(-48,0,0),"thigh.L":(-22,0,0),"shin.R":(30,0,0)},-.24),row(36,{"hips":(-89,0,0),"head":(7,0,10)},-.52),row(51,{"hips":(-89,0,0),"head":(7,0,10)},-.52)])
wave={"upper_arm.L":(-15,-74,0),"forearm.L":(-12,-72,0),"head":(0,6,0)}
make_action("wave",[row(1)]+[row(12+7*i,{**wave,"hand.L":(0,20*(-1)**i,0)}) for i in range(5)]+[row(52)])

# Store garment palettes as vertex tints on a shared, recolourable material.
fabric=paint("FabricBase","FFFFFF")
top.name="OilskinPalette"; fabric.name="Cloth_Top"
for obj in list(rig.children):
    if not obj.name.startswith("Top_"): continue
    colors=obj.data.color_attributes.new(name="Color",type="FLOAT_COLOR",domain="CORNER")
    fabric_slots=[i for i,m in enumerate(obj.data.materials) if m in (top,linen,knit)]
    for poly in obj.data.polygons:
        color=obj.data.materials[poly.material_index].diffuse_color if poly.material_index in fabric_slots else (1,1,1,1)
        for idx in poly.loop_indices: colors.data[idx].color=color
    obj["fabric_slots"]=fabric_slots
    for i in fabric_slots: obj.data.materials[i]=fabric
node=fabric.node_tree.nodes.new("ShaderNodeVertexColor"); node.layer_name="Color"
fabric.node_tree.links.new(node.outputs["Color"],fabric.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format="GLB",export_animation_mode="ACTIONS",export_force_sampling=True,export_yup=True,export_extras=False)
raw=OUT.read_bytes(); size=struct.unpack_from("<I",raw,12)[0]; doc=json.loads(raw[20:20+size])
triangles=sum(doc["accessors"][p["indices"]]["count"]//3 for m in doc["meshes"] for p in m["primitives"])
assert triangles<=12000,triangles
assert {a["name"] for a in doc["animations"]}=={"idle","walk","run","interact","sit","roll","smoke","faint","wave"}
assert all("skin" in n for n in doc["nodes"] if "mesh" in n)
print("CHARACTER VERIFIED",triangles,"triangles",flush=True)

# Workbench uses diffuse swatches for studio lighting.
for obj in rig.children:
    if obj.name.startswith("Top_"):
        for idx in obj["fabric_slots"]: obj.data.materials[idx]={"Top_Raincoat":top,"Top_Sweater":knit,"Top_Shirt":linen}[obj.name]
scene.render.engine='BLENDER_WORKBENCH'
sh=scene.display.shading
sh.light='STUDIO'; sh.studio_light='paint.sl'; sh.color_type='MATERIAL'
sh.show_shadows=True; sh.show_specular_highlight=False; sh.show_cavity=True; sh.cavity_type='WORLD'; sh.cavity_ridge_factor=.65
sh.background_type='WORLD'
scene.world=bpy.data.worlds.new("Studio"); scene.world.color=(.075,.112,.11)
scene.view_settings.view_transform='Standard'
scene.render.resolution_x=scene.render.resolution_y=512; scene.render.resolution_percentage=100
bpy.ops.object.camera_add()
cam=bpy.context.object; cam.data.type='ORTHO'; cam.data.ortho_scale=2.06; scene.camera=cam
looks=[("raincoat","Hair_01","Beard_02","Top_Raincoat",True,.86),("sweater","Hair_02","Beard_04","Top_Sweater",False,-.83),("shirt","Hair_06","Beard_00","Top_Shirt",False,1.15)]
for label,h,b,t,cap,cx in looks:
    visible={"Body","Pants_01","Boots_Rubber",h,b,t}
    if cap: visible.add("Hat_Kasket")
    for ob in rig.children: ob.hide_render=ob.name not in visible
    cam.location=(cx,-3.9,1.75); cam.rotation_euler=(Vector((0,0,.88))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(PREVIEW/f"character_{label}.png")
    bpy.ops.render.render(write_still=True)








