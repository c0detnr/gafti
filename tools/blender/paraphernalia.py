"""Build GAFTİ close-up props in metres and render their catalogue views."""
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/models/hero"
PREVIEW = ROOT / "tools/previews"
TAU = math.tau
sin, cos, pi = math.sin, math.cos, math.pi


def paint(name, rgb, metal=0, rough=.48, alpha=1):
    m = bpy.data.materials.new(name)
    color = tuple(((int(rgb[i:i+2], 16) / 255 + .055) / 1.055) ** 2.4 for i in (0, 2, 4))
    m.diffuse_color = (*color, alpha)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    for k, v in {"Base Color": (*color, 1), "Metallic": metal, "Roughness": rough, "Alpha": alpha}.items():
        p.inputs[k].default_value = v
    if alpha < 1:
        m.surface_render_method = 'BLENDED'
    return m


class Part:
    def __init__(self, name):
        self.name, self.verts, self.faces, self.slots, self.indices, self.smooth = name, [], [], [], [], []

    def mesh(self, verts, faces, mat, smooth=False):
        start = len(self.verts)
        self.verts.extend(verts)
        if mat not in self.slots:
            self.slots.append(mat)
        for face in faces:
            self.faces.append(tuple(start + i for i in face))
            self.indices.append(self.slots.index(mat))
            self.smooth.append(smooth)

    def build(self, pivot=(0, 0, 0)):
        data = bpy.data.meshes.new(self.name)
        data.from_pydata([Vector(v)-Vector(pivot) for v in self.verts], [], self.faces)
        data.update()
        for m in self.slots:
            data.materials.append(m)
        for face, idx, smooth in zip(data.polygons, self.indices, self.smooth):
            face.material_index = idx
            face.use_smooth = smooth
        obj = bpy.data.objects.new(self.name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = pivot
        return obj


def skin(part, rings, mat, loop=True, smooth=True):
    n = len(rings[0])
    faces = [(j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i)
             for j in range(len(rings)-1) for i in range(n if loop else n-1)]
    part.mesh([v for row in rings for v in row], faces, mat, smooth)


def lathe(p, profile, mat, n=32, form=None, smooth=True):
    form = form or (lambda r, a, z: (r*cos(a), r*sin(a), z))
    rings = [[form(r, TAU*i/n, z) for i in range(n)] for z, r in profile]
    skin(p, rings, mat, smooth=smooth)


def disk(p, r, z, mat, center=(0, 0), n=32):
    x, y = center
    p.mesh([(x+r*cos(TAU*i/n), y+r*sin(TAU*i/n), z) for i in range(n)], [range(n)], mat)


def poly(p, xy, z, mat):
    pts = [(x,y,z) for x,y in xy]
    area = sum(x*xy[(i+1)%len(xy)][1]-y*xy[(i+1)%len(xy)][0] for i,(x,y) in enumerate(xy))
    p.mesh(pts, [range(len(pts)) if area>0 else reversed(range(len(pts)))], mat)


def line(p, pts, radius, mat, n=6):
    pts = list(map(Vector, pts))
    rings = []
    for i, v in enumerate(pts):
        tangent = (pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        axis = Vector((0,1,0)) if abs(tangent.y)<.85 else Vector((0,0,1))
        u = tangent.cross(axis).normalized()
        w = tangent.cross(u)
        rings.append([v+radius*(cos(TAU*j/n)*u+sin(TAU*j/n)*w) for j in range(n)])
    skin(p, rings, mat)


def rounded(p, layers, mats, steps=5, dx=0, dy=0):
    rows = []
    for z,w,h,r in layers:
        row = []
        for j,(sx,sy) in enumerate([(1,1),(-1,1),(-1,-1),(1,-1)]):
            for k in range(steps+1):
                a = (j+k/steps)*pi/2
                row.append((dx+sx*(w/2-r)+r*cos(a),dy+sy*(h/2-r)+r*sin(a),z))
        rows.append(row)
    p.mesh(rows[0], [reversed(range(len(rows[0])))], mats[0])
    for i in range(len(rows)-1):
        skin(p, rows[i:i+2], mats[min(i,len(mats)-1)])
    p.mesh(rows[-1], [range(len(rows[-1]))], mats[-1])


def palette():
    global pine, teal, mint, gold, cream, clay, dark, steel, silver, cork
    pine=paint("Ladin enamel","174c4e",.22)
    teal=paint("Lake teal","31948b",.12)
    mint=paint("Mint screen print","a6dabe")
    gold=paint("Marigold","f1af4c",.16)
    cream=paint("Warm ivory","f5e6c6")
    clay=paint("Mandarin","df643b",.08)
    dark=paint("Graphite","353a40",.55)
    steel=paint("Pewter","899695",.68)
    silver=paint("Burnished edges","d6d7c9",.65,.27)
    cork=paint("Honey kraft","c79056",0,.76)


def bucket():
    p=Part("Bucket")
    def dent(r,a,z):
        r *= 1-.055*max(0,cos(a+.8))**48*math.exp(-((z-.135)/.067)**2)
        return r*cos(a),r*sin(a),z
    lathe(p,[(0,.104),(.004,.111),(.012,.114),(.021,.113),(.17,.139),(.234,.15),(.239,.154),(.248,.154),(.25,.15),(.246,.145),(.02,.106)],teal,30,dent)
    disk(p,.104,0,pine)
    disk(p,.106,.02,teal)
    lathe(p,[(.223,.149),(.225,.152),(.229,.152),(.23,.15)],pine,32)
    lathe(p,[(.033,.116),(.036,.1165)],mint,32)
    # Wire bail hanging against the front, with a salvaged orange grip.
    def bail(t):
        return (.151*cos(t),-.13*sin(t),.212-.076*sin(t))
    line(p,[bail(pi*i/32) for i in range(33)],.003,steel,5)
    line(p,[bail(pi*i/32) for i in range(12,21)],.007,clay,7)
    for s in (-1,1):
        line(p,[(s*.143,0,.211),(s*.156,0,.211)],.011,gold,12)
    for k in range(19):
        a=-2.8+(k*1.27)%3.4
        z=.044+(k*.0271)%.142
        r=.113+(z-.021)*.17
        p.mesh([dent(r+.0008,a,z),dent(r+.0008,a+.048,z+.0019),dent(r+.0008,a+.1,z+.0024)],[(0,1,2)],mint)
    # A worn anchovy stamp under the handle, printed onto the curved front.
    def stamp(points, mat, lift):
        verts=[]
        for dx, dz in points:
            z=.090+dz
            a=-1.27+dx/.126
            # Interpolate the two tapered wall rings used by the mould.
            r=.113+(z-.021)*(.139-.113)/(.17-.021)+lift
            verts.append(dent(r,a,z))
        p.mesh(verts,[range(len(verts))],mat)
    stamp([(-.023,0),(-.012,-.009),(.005,-.008),(.022,0),(.009,.008),(-.006,.01)],cream,.0016)
    stamp([(.017,0),(.031,-.009),(.03,.009)],gold,.0016)
    stamp([(-.016,.001),(-.014,-.001),(-.012,.001),(-.014,.003)],pine,.0028)
    w=Part("Water")
    water=paint("Creek water","53aaad",.16,.18,.73)
    disk(w,.134,.167,water,n=48)
    lathe(w,[(.167,.129),(.168,.134),(.17,.137)],water,48)
    for i in range(3):
        a=-1.55+i*.18
        line(w,[(r*cos(t),r*sin(t),.168) for r in [.09+i*.011] for t in [a+j*.036 for j in range(12)]],.00058,mint,4)
    return [p.build(),w.build()]


def bottle():
    b,c,f=Part("Bottle"),Part("Cap"),Part("Bowl")
    plastic=paint("Sea glass PET","82c6bf",.09,.22,.28)
    def shell(r,a,z):
        return r*cos(a),r*sin(a),z+.0013*sin(a*5+.4)*max(0,1-z/.025)
    profile=[(.0013,.05),(.005,.051),(.012,.052),(.021,.051),(.027,.048),(.032,.052),(.048,.054),(.055,.051),(.061,.054),(.117,.055),(.157,.054),(.165,.052),(.17,.054),(.188,.054),(.202,.05),(.222,.037),(.239,.018),(.247,.014),(.256,.014)]
    lathe(b,profile,plastic,26,shell)
    # Torn wrap with a little mountain print on the surviving face.
    def patch(a,z,r=.0556):
        return r*cos(a),r*sin(a),z
    rows=[]
    for j in range(3):
        rows.append([patch(-2.8+i*.132+[0,.15,-.04][j]*max(0,1-i/3)+[0,-.24,.07][j]*max(0,(i-15)/3),[.094,.115,.142][j]+.0018*sin(i*2.7+j)) for i in range(19)])
    skin(b,rows,pine,loop=False)
    for i in range(6):
        a=-2.52+i*.31
        for dz,m in [(0,mint),(.012,gold)]:
            b.mesh([patch(a,.105+dz,.0562),patch(a+.25,.105+dz,.0562),patch(a+.12,.115+dz,.0562)],[(0,1,2)],m)
    lathe(c,[(.245,.015),(.246,.018),(.249,.018),(.25,.015),(.252,.019),(.264,.019),(.266,.016)],clay,32)
    disk(c,.016,.266,clay)
    for i in range(20):
        a=TAU*i/20
        line(c,[(.019*cos(a),.019*sin(a),z) for z in (.253,.263)],.0007,gold,4)
    def foil(r,a,z):
        r*=1+.07*sin(7*a+.6)+.04*sin(11*a-z*180)
        return r*cos(a),r*sin(a),z+.0017*sin(9*a+z*120)
    lathe(f,[(.263,.009),(.271,.01),(.284,.025),(.287,.0255),(.284,.021),(.272,.007)],silver,31,foil,False)
    disk(f,.008,.272,dark)
    return [b.build(),c.build(),f.build()]


def lighter():
    b,w=Part("Body"),Part("Wheel")
    rounded(b,[(0,.024,.012,.005),(.002,.028,.015,.006),(.052,.028,.015,.006),(.055,.025,.014,.004)],[pine,clay,clay])
    rounded(b,[(.003,.0283,.0153,.006),(.005,.0283,.0153,.006)],[gold])
    rounded(b,[(.053,.016,.014,.003),(.055,.017,.015,.003),(.067,.017,.015,.003),(.068,.015,.013,.003)],[dark,steel,silver],dx=-.005)
    rounded(b,[(.055,.009,.012,.003),(.059,.01,.012,.003),(.061,.008,.01,.002)],[pine,teal],dx=.009)
    for k in range(3):
        x=-.010+k*.0045
        b.mesh([(x-.001,-.00755,.058),(x+.001,-.00755,.058),(x+.001,-.00755,.064),(x-.001,-.00755,.064)],[(0,1,2,3)],dark)
    for k,(s,m) in enumerate([(.009,pine),(.006,mint),(.003,gold)]):
        b.mesh([(0,-.00753-k*.00003,.033+s),(s,-.00753-k*.00003,.033),(0,-.00753-k*.00003,.033-s),(-s,-.00753-k*.00003,.033)],[(3,2,1,0)],m)
    def axle(r,a,z):
        return .004+r*cos(a),-z,.065+r*sin(a)
    lathe(w,[(-.006,.0035),(-.005,.005),(.005,.005),(.006,.0035)],dark,28,axle)
    for i in range(20):
        a=TAU*i/20
        line(w,[axle(.0051,a+t*.19,-.0048+t*.0096) for t in (0,1)],.00045,silver,4)
    for s in (-1,1):
        w.mesh([axle(.0035,TAU*i/24,s*.006) for i in range(24)],[range(24) if s==1 else reversed(range(24))],gold)
    return [b.build(),w.build((.004,0,.065))]


def grinder():
    b,l=Part("Base"),Part("Lid")
    lathe(b,[(0,.024),(.002,.027),(.005,.028),(.016,.028),(.019,.027),(.021,.025),(.021,.023),(.007,.023)],pine,32)
    disk(b,.024,0,pine)
    disk(b,.023,.007,steel)
    for i in range(15):
        a=i*TAU/10
        r=.016 if i<10 else .008
        if i>=10: a=TAU*(i-10)/5+.24
        x,y=r*cos(a),r*sin(a)
        def tooth(rr,t,z): return x+rr*cos(t+a),y+rr*sin(t+a),z
        lathe(b,[(.007,.0038),(.015,.0031),(.018,.0007)],silver,4,tooth,False)
    lathe(l,[(.0218,.026),(.023,.0285),(.03,.0285),(.033,.027),(.034,.024)],teal,40)
    disk(l,.026,.0218,dark)
    disk(l,.024,.034,pine)
    disk(l,.012,.03406,gold,n=32)
    for i in range(12):
        a=TAU*i/12
        def point(r,t): return (r*cos(t),r*sin(t))
        poly(l,[point(.014,a),point(.018,a-.09),point(.0225,a),point(.018,a+.09)],.0341,mint)
    poly(l,[(-.008,-.005),(0,.008),(.008,-.005)],.03412,pine)
    for i in range(36):
        a=TAU*i/36
        line(b,[(.028*cos(a+t*.055),.028*sin(a+t*.055),.005+t*.009) for t in (0,1)],.00055,steel,4)
    return [b.build(),l.build((0,0,.0279))]


def paper():
    p=Part("Paper")
    rice=paint("Laid rice paper","f2e6cf",0,.84,.79)
    gum=paint("Acacia gum","d5b67f",0,.35,.69)
    # Both axes are subdivided for rolling along either local edge.
    rows=[]
    for j in range(32):
        v=j/31
        rows.append([((i/32-.5)*.09,(v-.5)*.043,.00018+.00023*(2*v-1)**4+.00006*cos(i*pi/16)) for i in range(33)])
    # One indexed grid keeps deformation continuous at the gum line.
    p.mesh([pt for row in rows for pt in row],[(j*33+i,j*33+i+1,(j+1)*33+i+1,(j+1)*33+i) for j in range(31) for i in range(32)],rice)
    p.slots.append(gum)
    p.indices[-64:]=[1]*64
    obj=p.build()
    uv=obj.data.uv_layers.new(name="Paper grain")
    for loop in obj.data.loops:
        i=loop.vertex_index
        uv.data[loop.index].uv=(i%33/32,i//33/31)
    # Bake the laid-wire impression and pulp fibres into the exported base colour.
    rng=random.Random(82)
    width,height=512,256
    grain=[rng.uniform(-.017,.017) for _ in range(width*height)]
    for _ in range(1600):
        x,y=rng.randrange(width),rng.randrange(height)
        length=rng.randint(2,9)
        slope=rng.uniform(-.7,.7)
        for t in range(length):
            grain[((y+round(t*slope))%height)*width+(x+t)%width]-=.055*sin(pi*(t+.5)/length)
    pixels=[]
    for j in range(height):
        for i in range(width):
            value=grain[j*width+i]-.048*(i%12<1)-.023*(j%64<2)
            pixels.extend((.95+value,.90+value,.79+value,1))
    texture=bpy.data.images.new("Rice fibres",width=width,height=height,alpha=False)
    texture.pixels.foreach_set(pixels)
    texture.pack()
    node=rice.node_tree.nodes.new("ShaderNodeTexImage")
    node.image=texture
    rice.node_tree.links.new(node.outputs["Color"],rice.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    return [obj]


def horizontal(r,a,x,off=.006):
    return x,r*cos(a),off+r*sin(a)


def filter_tip():
    p=Part("Filter")
    for j in range(2):
        pts=[]
        for k in range(43):
            a=k*TAU/39
            r=.0047+k*.000012
            pts.append(horizontal(r,a,-.011 if j==0 else .011,.0052))
        if j==0: row=pts
        else: skin(p,[row,pts],cork,loop=False)
    yz=[(-.0046,.005),(-.003,.0084),(-.0013,.0025),(.0004,.0085),(.0022,.0025),(.0044,.0067)]
    skin(p,[[(-.0108,y,z) for y,z in yz],[(.0108,y,z) for y,z in yz]],cream,False,False)
    for s in (-1,1):
        line(p,[(s*.01085,y,z) for y,z in yz],.00022,cork,4)
    return [p.build()]


def joint():
    p=Part("Joint")
    rice=paint("Flax paper","e4d4ae",0,.8)
    def wrap(r,a,x):
        twist=max(0,(x-.031)/.015)
        r*=1+(.021+.17*twist)*sin(5*a-9*twist)
        return x,r*cos(a)+.0035*twist**2,.0066+r*sin(a)+.004*twist**2
    lathe(p,[(-.044,.0034),(-.043,.0036),(-.029,.0038)],cork,24,wrap)
    lathe(p,[(-.029,.0039),(-.027,.0041),(-.013,.0045),(.016,.0057),(.030,.0063),(.034,.0057),(.037,.0035),(.04,.0018),(.043,.0027),(.046,.00055)],rice,25,wrap)
    p.mesh([wrap(.0034,TAU*i/24,-.044) for i in range(24)],[reversed(range(24))],dark)
    line(p,[(-.0441,y,.0066+z) for y,z in [(-.003,0),(-.0018,.002),(-.0008,-.002),(.0006,.002),(.0019,-.002),(.003,0)]],.00027,cork,5)
    for x in (-.0318,-.0305):
        lathe(p,[(x,.00391),(x+.00048,.00391)],clay,24,wrap)
    for k in range(4):
        line(p,[wrap(.00398+.00245*t, k*pi/2+6*t,-.027+.057*t) for t in [i/20 for i in range(21)]],.00013,cream,4)
    return [p.build()]


def tray():
    p=Part("Tray")
    rounded(p,[(0,.239,.143,.025),(.002,.245,.15,.028),(.011,.266,.172,.032),(.014,.267,.174,.032),(.015,.263,.17,.030),(.013,.257,.165,.029),(.004,.236,.142,.024)],[pine,teal,pine,gold,gold,teal],8)
    z=.00412
    disk(p,.023,z,gold,(.035,.018),38)
    for j,(y,m) in enumerate([(.005,mint),(-.005,pine),(-.022,teal)]):
        peaks=[(-.093,y-.006),(-.078,y+.004),(-.065,y+.013),(-.056,y+.007),(-.031,y+.034-j*.006),(-.006,y+.008),(.009,y+.019),(.03,y),(.058,y+.018),(.088,y-.005),(.093,y-.011)]
        poly(p,peaks+[(.080,-.039),(-.082,-.039)],z+.00007*(j+1),m)
    for x,y,s in [(-.072,-.033,1),(-.058,-.031,.66),(.076,-.033,.78)]:
        for i in range(3):
            w=(.011-i*.0025)*s
            h=y+i*.009*s
            poly(p,[(x-w,h),(x,h+.018*s),(x+w,h)],.00448+i*.00002,pine)
    for s in (-1,1):
        for i in range(-5,6):
            x=i*.018
            y=s*.052
            poly(p,[(x-.006,y),(x,y+.0031),(x+.006,y),(x,y-.0031)],.00422,cream if i%2 else gold)
    for x,y in [(-.07,.035),(-.058,.041),(.072,.038)]:
        poly(p,[(x-.005,y+.002),(x,y),(x+.005,y+.002),(x,y-.0016)],.00426,pine)
    return [p.build()]


def preview(name, objects):
    scene=bpy.context.scene
    # Offset the removable lid for the catalogue photo only.
    if name=="grinder":
        objects[1].location += Vector((.055,.014,-.0218))
    bpy.context.view_layer.update()
    corners=[obj.matrix_world @ Vector(v) for obj in objects for v in obj.bound_box]
    lo=Vector(tuple(min(p[i] for p in corners) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in corners) for i in range(3)))
    center=(lo+hi)*.5
    size=max(hi-lo)
    view=Vector((.49,-1,.68))
    if name in ("joint","filter_tip"): view=Vector((-.8,-1,.66))
    if name in ("rolling_tray","rolling_paper","grinder"): view=Vector((.27,-1,1.45))
    bpy.ops.object.camera_add(location=center+view.normalized()*size*3)
    camera=bpy.context.object
    camera.rotation_euler=(-view).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'
    camera.data.clip_start=.0002
    rotation=camera.rotation_euler.to_matrix().transposed()
    projection=[rotation @ (obj.matrix_world @ vert.co-center) for obj in objects for vert in obj.data.vertices]
    bounds=[(min(p[i] for p in projection),max(p[i] for p in projection)) for i in (0,1)]
    camera.location += rotation.transposed() @ Vector(((bounds[0][0]+bounds[0][1])/2,(bounds[1][0]+bounds[1][1])/2,0))
    camera.data.ortho_scale=max(high-low for low,high in bounds)*1.10
    scene.camera=camera
    bpy.ops.mesh.primitive_plane_add(size=size*200,location=(0,0,lo.z-.00012))
    bpy.context.object.data.materials.append(paint("Studio sage","637977",0,.95))
    for loc,power,tint in [((-1,-2,3),180,(1,.88,.72)),((2,1,2),160,(.76,1,.95)),((1,-2,1),50,(1,1,1))]:
        pos=Vector(loc)*size+center
        bpy.ops.object.light_add(type='AREA',location=pos)
        lamp=bpy.context.object
        lamp.rotation_euler=(center-pos).to_track_quat('-Z','Y').to_euler()
        lamp.data.energy=power*size**2
        lamp.data.shape='DISK'
        lamp.data.size=size*1.7
        lamp.data.color=tint
    scene.world.color=(.32,.32,.32)
    scene.render.engine='BLENDER_EEVEE'
    scene.eevee.taa_render_samples=32
    scene.render.resolution_x=scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.render.filepath=str(PREVIEW/(name+".png"))
    bpy.ops.render.render(write_still=True)


if __name__=="__main__":
    OUTPUT.mkdir(exist_ok=True,parents=True)
    PREVIEW.mkdir(exist_ok=True,parents=True)
    import sys
    chosen=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    for name,make in [("bong_bucket",bucket),("bong_bottle",bottle),("lighter",lighter),("grinder",grinder),("rolling_paper",paper),("filter_tip",filter_tip),("joint",joint),("rolling_tray",tray)]:
        if chosen and name not in chosen: continue
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        bpy.data.orphans_purge(do_recursive=True)
        palette()
        objects=make()
        triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in objects)
        assert triangles<=2000,(name,triangles)
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects: o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(name+".glb")),use_selection=True,export_yup=True)
        print(name,triangles,flush=True)
        preview(name,objects)

