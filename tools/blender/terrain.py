"""Generate the Pusludere heightfield, road network, creek, and annotated map."""
from mathutils.noise import noise
from math import cos, exp, hypot, sin, sqrt
from pathlib import Path
import sys

# Blender's background --python does not add the file's folder to sys.path.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from town import camera, export, light, linear_color, material, mesh, render, reset_scene

import bpy

EDGE = 130
BRIDGE_X, BRIDGE_Z = 5, -45
LOCATIONS = (
    ("Başlangıç", -62, 28, 2), ("Ev", -70, 40, 2), ("Sera", -55, 30, 2),
    ("Dış tarla", -45, 48, 2), ("Kurutma ambarı", -78, 22, 2),
    ("Meydan", 60, 0, 0), ("GAFTİ dükkânı", 60, -14, 0),
    ("Kahvehane", 46, 8, 0), ("Muhtarlık", 74, 8, 0),
    ("Denetim ofisi", 78, -8, 0), ("Hırdavatçı", 42, -10, 0),
    ("Minibüs durağı", 72, 48, 0), ("Köprü", BRIDGE_X, BRIDGE_Z, -1),
    ("Ladin ormanı", -45, -70, None), ("Keklik Tepe", 0, -110, 28),
)
FARM_HULL = ((-78,22),(-55,30),(-45,48),(-70,40))
PADS = ((60,0,22,0),(72,48,6,0),(0,-110,6,28))

# The pairs are X/Z in Godot. The separate creek bank approach segments stop at
# the bridge ramps, so the imported bridge is the crossing surface.
ROUTES = (
    (2.25, ((-70,29),(-62,28),(-50,25),(-28,21),(-13,16),(0,10),(18,6),(40,0),(60,0))),
    (2.20, ((60,0),(64,15),(66,30),(72,48))),
    (1.95, ((40,0),(29,-8),(15,-19),(9,-29),(5,-38),(5,-40))),
    (1.45, ((5,-50),(5,-54),(6,-63),(13,-74),(15,-85),(8,-94),(0,-102),(0,-110))),
    (1.35, ((-65,28),(-73,25),(-78,22))),
    (1.27, ((-55,26),(-55,30),(-49,37),(-45,48))),
    (1.50, ((60,0),(60,-14))),
    (1.30, ((49,0),(46,8))),
    (1.35, ((66,0),(74,8))),
    (1.40, ((71,0),(78,-8))),
    (1.40, ((47,-.5),(42,-10))),
)
SEGMENTS = [(width, *a, b[0]-a[0], b[1]-a[1],
             (b[0]-a[0])**2+(b[1]-a[1])**2)
            for width, points in ROUTES for a,b in zip(points,points[1:])]


def clamp(value):
    return max(0, min(1, value))


def smooth(a, b, value):
    t = clamp((value - a) / (b - a))
    return t * t * (3 - 2 * t)


def blend(a, b, weight):
    return a + (b-a)*weight


def gaussian(x,z,cx,cz,sx,sz):
    return exp(-((x-cx)/sx)**2 - ((z-cz)/sz)**2)


def distance_to_segment(x,z,ax,az,dx,dz,length):
    t = clamp(((x-ax)*dx+(z-az)*dz)/length)
    return hypot(x-ax-t*dx,z-az-t*dz)


def farm_distance(x,z):
    distances, signs = [], []
    for a,b in zip(FARM_HULL,FARM_HULL[1:]+FARM_HULL[:1]):
        dx,dz = b[0]-a[0], b[1]-a[1]
        distances.append(distance_to_segment(x,z,*a,dx,dz,dx*dx+dz*dz))
        signs.append(dx*(z-a[1])-dz*(x-a[0]))
    return 0 if min(signs) >= 0 or max(signs) <= 0 else min(distances)


def river(x):
    # Each interval is pinned at both ends, including the bridge at (5,-45).
    if x <= BRIDGE_X:
        t = (x + EDGE) / (EDGE + BRIDGE_X)
        return blend(-60, BRIDGE_Z, t) + 9.0 * sin(t*6.28318)*sin(t*3.14159)**2
    t = (x-BRIDGE_X) / (EDGE-BRIDGE_X)
    return blend(BRIDGE_Z,-35,t) + 5.8 * sin(t*6.28318)*sin(t*3.14159)**2


def channel_width(x):
    return 1 + .19 * sin((x-BRIDGE_X)*.093) * smooth(9,32,abs(x-BRIDGE_X))


def near_road(x,z):
    distance = min(distance_to_segment(x,z,ax,az,dx,dz,d2)-width
               for width,ax,az,dx,dz,d2 in SEGMENTS)
    return max(distance, min(z+50, -40-z))


def landscape(x,z):
    roll = (1.35*sin(x*.052+z*.048)+1.08*cos(z*.084-x*.024)
            +.56*sin(z*.122)*cos(x*.121)+.30*cos(x*.25-z*.12))
    west = 17*gaussian(x,z,-98,-65,30,39) + 12*gaussian(x,z,-60,-104,30,26)
    east = 16*gaussian(x,z,104,-70,26,42) + 13*gaussian(x,z,101,84,29,29)
    south = 14*gaussian(x,z,-62,100,42,29) + 10*gaussian(x,z,37,112,50,35)
    summit = 28*gaussian(x,z,0,-112,30,39) + 7.5*gaussian(x,z,17,-89,29,31)
    # Closed, steep boundary ridges with varying crests around the whole valley.
    edge_dist = EDGE - max(abs(x),abs(z))
    brow = ((12+4.2*sin(x*.105-z*.064)+3.4*cos(x*.043+z*.074)) *
            (1-smooth(1,32,edge_dist)))
    boundary = 15*(1-smooth(0,7.5,edge_dist))
    height = roll + west + east + south + summit + brow + boundary
    height = blend(2,height,smooth(18.5,29,farm_distance(x,z)))
    for px,pz,r,y in PADS:
        pad = hypot(x-px,z-pz)
        height = blend(y,height,smooth(r+4.2,r+(13 if y==28 else 14),pad))

    off = abs(z-river(x))/channel_width(x)
    bank = 0 if abs(x-BRIDGE_X)<8 else max(0,min(2,height*.18))
    bed = -1 - .16 * sin((x-BRIDGE_X)*.095)**2
    bed_profile = blend(bed,bank,smooth(1.39,4.15,off))
    shore = 1-smooth(5.6,13.4,off)
    height = blend(height,bed_profile,shore)
    # Both ends have level landings at the contracted bridge placement.
    bridge_landing = (1-smooth(1.8,5.5,abs(x-BRIDGE_X))) * (1-smooth(7.2,12,off))
    return blend(height,bed_profile,bridge_landing)


def point(x, z):
    return (x, z, landscape(x,z), near_road(x,z))


def xyz(point):
    x,z,y,_ = point
    return (x,-z,y)


def coordinates(step, coarse):
    # Rows near the creek follow its centerline. Farther rows gradually return
    # to global X/Z. Keep the exact frame corners and the river endpoints.
    edge_pin = [-130, -60, 5, 60, 130]
    xs = sorted(set(range(-130,131,step)) | set(edge_pin))
    band = [-11,-8,-5.2,-5,-4.15,-3.3,-2.5,-1.4,0,1.4,2.5,3.3,4.15,5,5.2,8,11]
    if coarse:
        band = [-11,-6,-4.15,-2.5,0,2.5,4.15,6,11]
    rows = [z for z in range(-130,131,step) if z < -58 or z > -32] + [-130,130]
    rows = sorted(set(rows) | {-45+offset for offset in band})
    return xs,rows


def actual_z(x, base):
    offset = base-BRIDGE_Z
    if abs(offset)<=11:
        return river(x)+offset*channel_width(x)
    rim = EDGE if offset>0 else -EDGE
    joint = BRIDGE_Z+(11 if offset>0 else -11)
    edge_row = river(x)+(11 if offset>0 else -11)*channel_width(x)
    return blend(edge_row,rim,(base-joint)/(rim-joint))


def grid(step, coarse=False):
    xs,rows = coordinates(step,coarse)
    columns = [[point(x,actual_z(x,base)) for base in rows] for x in xs]
    return xs,rows,columns


def road_split(triangle, inside):
    result = []
    for a,b in zip(triangle,triangle[1:]+triangle[:1]):
        a_in = (a[3] <= 0) == inside
        b_in = (b[3] <= 0) == inside
        if a_in:
            result.append(a)
        if a_in != b_in:
            t = a[3] / (a[3]-b[3])
            result.append(tuple(blend(a[i],b[i],t) for i in range(3))+(0,))
    return result


def pigments(*codes):
    return [linear_color(code) for code in codes]


GRASS = pigments("376044","598448","82A653","A4AA65","707B66","626E6A")
ROAD = pigments("947859","B7A17B","CAB18C")
CREEK = pigments("465E54","647A66","A08D67")
WATER = pigments("3A7773","58A8A1","82BBB0")


def mix(a,b,t):
    return tuple(blend(x,y,t) for x,y in zip(a,b))


def paint(kind, p):
    x,z,y,road = p
    broad = noise((x*.043,z*.046,2.7), noise_basis="PERLIN_ORIGINAL")
    marks = noise((x*.137,z*.181,13.1), noise_basis="PERLIN_ORIGINAL")
    grain = noise((x*.29,z*.39,5.3), noise_basis="PERLIN_ORIGINAL")
    fields = clamp(.50+.81*broad+.29*marks+.12*grain)
    speckle = clamp(.50+.48*marks+.37*grain)
    if kind == "Road":
        return mix(mix(ROAD[0],ROAD[1],.44+.46*speckle),ROAD[2],.35*fields*smooth(0,1,-road))
    if kind == "Creek":
        bank = smooth(1.0,4.3,abs(z-river(x)))
        return mix(mix(CREEK[0],CREEK[1],speckle),CREEK[2],bank*(.41+.27*fields))
    if kind == "Water":
        t = clamp(.48+.23*sin(z*2.6+x*.73)+.17*sin(x*1.2))
        mid = mix(WATER[0],WATER[1],t)
        return mix(mid,WATER[2],.25*smooth(.68,1,t))
    meadow = mix(GRASS[0],GRASS[1],smooth(0,.58,fields))
    meadow = mix(meadow,GRASS[2],.91*smooth(.37,1,fields))
    forest = .68*gaussian(x,z,-45,-70,24,20)
    meadow = mix(meadow,GRASS[0],forest)
    tea = gaussian(x,z,-28,41,24,12)*(.5+.5*cos(z*1.33+x*.11+sin(x*.11)))
    meadow = mix(meadow,GRASS[2],.44*tea)
    near_field = gaussian(x,z,-44,49,9,7)
    furrows = .50+.50*sin(x*1.12+z*.48)
    meadow = mix(meadow,GRASS[3],near_field*(.35+.21*furrows))
    warm_edges = (1-smooth(0,1.2,max(0,road)))*.19
    meadow = mix(meadow,ROAD[0],warm_edges*(.55+.44*speckle))
    stone = smooth(11,32,y)*(.37+.50*smooth(.32,.80,fields))
    rock = mix(GRASS[4],GRASS[5],speckle)
    return mix(meadow,rock,stone)


def triangles(columns):
    for i in range(len(columns)-1):
        for j in range(len(columns[i])-1):
            a,b = columns[i][j:j+2]
            d,c = columns[i+1][j:j+2]
            if (i+j)%2:
                yield j,(a,b,d)
                yield j,(b,c,d)
            else:
                yield j,(a,b,c)
                yield j,(a,c,d)


class Surface:
    def __init__(self, name):
        self.name = name
        self.vertices = []
        self.faces = []
        self.lookup = {}

    def add(self, polygon):
        if len(polygon) < 3:
            return
        indices = []
        for point in polygon:
            key = tuple(round(value,7) for value in point[:3])
            index = self.lookup.get(key)
            if index is None:
                index = len(self.vertices)
                self.lookup[key] = index
                self.vertices.append(point)
            if index not in indices:
                indices.append(index)
        if len(indices) >= 3:
            self.faces.append(tuple(indices))

    def finish(self):
        obj = mesh(self.name, [xyz(p) for p in self.vertices], self.faces)
        if self.name.endswith("-col"):
            return obj
        roughness = .45 if self.name=="Water" else .92
        mat = material(self.name, "FFFFFF", roughness)
        color_input = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        color_input.layer_name = "Paint"
        mat.node_tree.links.new(color_input.outputs["Color"],
                                mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
        obj.data.materials.append(mat)
        colors = obj.data.color_attributes.new(name="Paint", type="FLOAT_COLOR", domain="POINT")
        obj.data.color_attributes.active_color = colors
        colors.data.foreach_set("color",[c for p in self.vertices for c in (*paint(self.name,p),1)])
        for face in obj.data.polygons:
            face.use_smooth = True
        return obj


def terrain():
    xs,rows,columns = grid(2)
    ground,road,creek,water,collision = map(Surface,("Ground","Road","Creek","Water","Ground-col"))
    for j,triangle in triangles(columns):
        if -49.15 <= rows[j] and rows[j+1] <= -40.85:
            creek.add(triangle)
        else:
            ground.add(road_split(triangle,False))
            road.add(road_split(triangle,True))

    # The water is level across the valley. Its perimeter is buried in the banks.
    for a,b in zip(xs,xs[1:]):
        cross_sections = [[(x,river(x)+i*channel_width(x),-.69,0)
                           for i in (-2.85,-1.9,-.95,0,.95,1.9,2.85)] for x in (a,b)]
        for i in range(6):
            water.add((cross_sections[0][i],cross_sections[0][i+1],
                       cross_sections[1][i+1],cross_sections[1][i]))

    _,_,coarse = grid(4,True)
    for _,triangle in triangles(coarse):
        collision.add(triangle)
    border = (list(coarse[0]) + [c[-1] for c in coarse[1:]] +
              list(reversed(coarse[-1][:-1])) + [c[0] for c in reversed(coarse[1:-1])])
    for a,b in zip(border,border[1:]+border[:1]):
        # Close the outer rim and the two stream outlets for character collision.
        collision.add((b,a,(a[0],a[1],a[2]+30,0),(b[0],b[1],b[2]+30,0)))

    return [part.finish() for part in (ground,road,creek,water,collision)]


def emission(name, code):
    mat = material(name, code)
    tree = mat.node_tree
    shader = tree.nodes.new("ShaderNodeEmission")
    shader.inputs["Color"].default_value = (*linear_color(code),1)
    tree.links.new(shader.outputs["Emission"], tree.nodes["Material Output"].inputs["Surface"])
    return mat


def map_rectangle(name,x1,y1,x2,y2,z,mat):
    return mesh(name,[(x1,y1,z),(x2,y1,z),(x2,y2,z),(x1,y2,z)],[(0,1,2,3)],mat)


def map_text(body,x,y,z,size,mat,align="LEFT"):
    data = bpy.data.curves.new(body,"FONT")
    data.body,data.size,data.align_x,data.align_y = body,size,align,"CENTER"
    obj = bpy.data.objects.new(body,data)
    bpy.context.collection.objects.link(obj)
    obj.location = (x,y,z)
    data.materials.append(mat)


def map_circle(x,y,z,radius,mat):
    from math import tau
    corners = [(x+radius*cos(i*tau/24),y+radius*sin(i*tau/24),z) for i in range(24)]
    mesh("Map pin",corners,[tuple(range(24))],mat)


def map_line(ax,ay,bx,by,z,mat,width=.55):
    length = hypot(bx-ax,by-ay)
    px,py = (by-ay)*width/length,(ax-bx)*width/length
    mesh("Pin leader",[(ax+px,ay+py,z),(ax-px,ay-py,z),
                      (bx-px,by-py,z),(bx+px,by+py,z)],[(0,1,2,3)],mat)


def annotated_map():
    cam = camera((0,-14,480),(0,-14,0),344)
    cam.rotation_euler = (0,0,0)
    dark = emission("Map ink","152822")
    paper = emission("Map lettering","F4E7C8")
    muted = emission("Map captions","B4CCAD")
    farm = emission("Farm pins","FFD490")
    town = emission("Town pins","BDE7A1")
    wild = emission("Valley pins","D4EEE8")
    accent = emission("North arrow","FFBA73")
    map_rectangle("Map backing",-175,-187,175,159,-35,material("Map backing","324E42"))
    map_rectangle("Title card",-175,130,175,159,431,dark)
    map_rectangle("Legend card",-175,-187,175,-131,431,dark)
    map_text("PUSLUDERE YAYLASI",-131,145,432,13,paper)
    map_text("260 × 260 m",-131,134,432,5.6,muted)
    map_text("K",130,150,432,7,paper,"CENTER")
    mesh("North arrow",[(126.5,137,432),(133.5,137,432),(130,145,432)],[(0,1,2)],accent)
    map_line(-128,-123,-103,-123,432,paper,.50)
    for x in (-128,-103):
        map_line(x,-125,x,-121,432,paper,.47)
    map_text("25 m",-100,-123,432,5,paper)

    pin_offsets = ((-4,10),(-10,-8),(5,7),(5,-9),(-11,8),(4,-14),(0,11),
                   (-12,4),(10,-7),(11,6),(-10,4),(12,-4),(-9,-9),(-9,6),(10,5))
    for i,((label,x,z,_),(dx,dy)) in enumerate(zip(LOCATIONS,pin_offsets)):
        y = -z
        color = farm if i<5 else town if i<12 else wild
        map_line(x,y,x+dx,y+dy,430,paper,.32)
        map_circle(x,y,431,1.28,paper)
        map_circle(x+dx,y+dy,431,4.22,dark)
        map_text(str(i+1),x+dx,y+dy,432,5.35,color,"CENTER")
        col,row = divmod(i,5)
        legend_x,legend_y = -132+91*col, -139-8.65*row
        map_text(f"{i+1:02}",legend_x,legend_y,432,5.40,color)
        map_text(label,legend_x+11,legend_y,432,5.40,paper)

    render("terrain_top")


def previews(objects):
    objects[-1].hide_render = True
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("Valley sky")
    light("Morning sun","SUN",(-175,-120,190),(0,0,0),2.45,(1,.86,.70),.13)
    light("Cool sky","AREA",(55,22,170),(0,0,0),580000,(.73,.86,1),260)
    camera((211,-318,282),(0,0,2),396)
    mesh("Valley backdrop",[(-900,-900,-31),(900,-900,-31),(900,900,-31),(-900,900,-31)],
         [(0,1,2,3)], material("Valley backdrop","718A77"))
    render("terrain")
    annotated_map()


def main():
    reset_scene()
    objects = terrain()
    export("terrain",objects,60000)
    previews(objects)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import os
        import tempfile
        import traceback
        diagnostic = Path(tempfile.gettempdir())/"gafti_terrain_error.txt"
        diagnostic.write_text(traceback.format_exc(),encoding="utf-8")
        traceback.print_exc()
        os._exit(1)



