"""Reproducible authored hard-surface Module Bay 01 assets. Coordinates in metres."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[3]
MODELS = ROOT / "assets/models"
SOURCE = ROOT / "art_source/blender"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
M = {}
def mat(name, color, metal=0, rough=.5, emission=0, alpha=1):
    m=bpy.data.materials.new(name); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,alpha)
    bs.inputs['Metallic'].default_value=metal
    bs.inputs['Roughness'].default_value=rough
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1)
        bs.inputs['Emission Strength'].default_value=emission
    if alpha < 1:
        bs.inputs['Transmission Weight'].default_value=.2
        bs.inputs['Alpha'].default_value=alpha
        m.surface_render_method='DITHERED'
    M[name]=m
mat("MAT_METAL_DARK",(.105,.132,.155),.78,.37)
mat("MAT_METAL_BRUSHED",(.38,.43,.46),.86,.29)
mat("MAT_POLYMER_BLACK",(.018,.026,.035),.1,.62)
mat("MAT_PANEL_LIGHT",(.44,.49,.51),.36,.49)
mat("MAT_PANEL_GRAPHITE",(.075,.096,.116),.5,.48)
mat("MAT_FLOOR",(.11,.133,.15),.48,.58)
mat("MAT_GLASS",(.12,.23,.28),.12,.17,alpha=.32)
mat("MAT_EMISSIVE_BLUE",(.025,.39,.59),.2,.25,2.3)
mat("MAT_EMISSIVE_WHITE",(.64,.79,.86),.05,.25,2.5)
mat("MAT_EMISSIVE_WARNING",(.8,.27,.035),.25,.34,1.1)
mat("MAT_COPPER",(.36,.17,.065),.8,.35)
mat("MAT_LABEL",(.65,.72,.75),.15,.55)
mat("MAT_SCREEN",(.008,.022,.032),.15,.25)
# Reproducible subtle roughness variation exported as standard glTF PBR textures.
import random
textures=ROOT/'assets/textures'
textures.mkdir(parents=True,exist_ok=True)
for key in ['MAT_METAL_DARK','MAT_METAL_BRUSHED','MAT_PANEL_GRAPHITE','MAT_FLOOR']:
    image=bpy.data.images.new(key+'_Roughness',width=128,height=128)
    image.colorspace_settings.name='Non-Color'
    rng=random.Random(42)
    pixels=[]
    base=.43 if key=='MAT_METAL_BRUSHED' else (.62 if key=='MAT_FLOOR' else .49)
    for y in range(128):
        for x in range(128):
            value=base+.035*math.sin(y*3.3)+rng.uniform(-.035,.035)
            pixels.extend([value,value,value,1])
    image.pixels=pixels
    image.filepath_raw=str(textures/(key.lower()+'_roughness.png'))
    image.file_format='PNG'
    image.save()
    material=M[key]
    node=material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image=image
    material.node_tree.links.new(node.outputs['Color'],material.node_tree.nodes.get('Principled BSDF').inputs['Roughness'])
root=None
stats={}
def pos(v): return (v[0],-v[2],v[1])
def finish(o,name,material,bevel=.02,parent=None):
    o.name=name
    o.data.materials.append(M[material])
    if bevel:
        b=o.modifiers.new("Machined edge radii","BEVEL"); b.width=bevel; b.segments=2
        b.affect='EDGES'
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=b.name)
    if o.type=='MESH':
        for f in o.data.polygons: f.use_smooth=True
        n=o.modifiers.new("Weighted corner normals","WEIGHTED_NORMAL")
        n.keep_sharp=True; n.weight=50
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=n.name)
    o.parent=parent or root
    return o
def box(name,p,s,material="MAT_METAL_DARK",bevel=.025,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos(p))
    o=bpy.context.object; o.dimensions=(s[0],s[2],s[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,material,min(bevel,min(s)*.25),parent)
def cyl(name,p,r,depth,material="MAT_METAL_BRUSHED",axis='y',vertices=32,parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=pos(p))
    o=bpy.context.object
    if axis=='z': o.rotation_euler[0]=math.pi/2
    if axis=='x': o.rotation_euler[1]=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(o,name,material,min(.012,depth*.12),parent)
def torus(name,p,major,minor,material="MAT_METAL_BRUSHED",parent=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=8,location=pos(p),major_radius=major,minor_radius=minor,rotation=(math.pi/2,0,0))
    return finish(bpy.context.object,name,material,0,parent)
def text(name,body,p,size=.1,material="MAT_LABEL"):
    bpy.ops.object.text_add(location=pos(p),rotation=(math.pi/2,0,0))
    o=bpy.context.object; o.name=name; o.data.body=body; o.data.size=size
    o.data.extrude=.0006; o.data.space_character=1.15
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object,name,material,0)
def bolt(p,r=.018,axis='z'):
    o=cyl("CaptiveHexFastener",p,r,.013,"MAT_METAL_BRUSHED",axis,6)
def start(name):
    global root
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    root=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(root)
def export(name):
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    triangles=sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)
    stats[name]={"mesh_objects":len(meshes),"triangles":triangles}
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+".blend")))
    bpy.ops.export_scene.gltf(filepath=str(MODELS/(name+".glb")),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
# Room shell: individually machined wall bays, inset service joints, floor seams.
start("ModuleBayRoom")
box("Foundation",(0,-.16,0),(9,.25,9),"MAT_POLYMER_BLACK")
for x in range(-4,5):
    for z in range(-4,5):
        box("DeckPlate_%d_%d"%(x,z),(x,-.025,z),(.986,.06,.986),"MAT_FLOOR",.012)
for x in [-4.46,4.46]:
    box("WallStructure",(x,1.95,0),(.16,3.9,9),"MAT_METAL_DARK")
    for z in range(-4,5):
        box("SideServicePanel",(x*.987,1.9,z),(.08,2.9,.93),"MAT_PANEL_GRAPHITE",.025)
        box("SidePanelInset",(x*.976,2.2,z),(.04,.72,.75),"MAT_METAL_DARK",.008)
        for h in [.58,.71,.84]:
            box("VentLouvre",(x*.967,h,z),(.035,.035,.56),"MAT_POLYMER_BLACK",.004)
    box("FloorCableTrunk",(x*.966,.18,0),(.13,.24,8.95),"MAT_METAL_BRUSHED")
    box("WallLightRail",(x*.965,3.3,0),(.035,.045,8.7),"MAT_EMISSIVE_WHITE",.004)
for z in [-4.46,4.46]:
    box("EndWall",(0,1.95,z),(9,3.9,.16),"MAT_METAL_DARK")
    for x in range(-4,5):
        box("EndWallPanel",(x,1.9,z*.987),(.94,2.9,.08),"MAT_PANEL_LIGHT" if z<0 else "MAT_PANEL_GRAPHITE",.025)
        box("PanelLowerInset",(x,.62,z*.974),(.74,.36,.035),"MAT_METAL_DARK",.01)
        if z<0:
            for bx in [-.36,.36]:
                bolt((x+bx,3.08,z+.14))
box("CeilingShadowPlane",(0,3.92,0),(9,.12,9),"MAT_POLYMER_BLACK")
for z in [-3.4,-1.2,1.2,3.4]:
    box("CeilingTransverseRib",(0,3.72,z),(8.9,.23,.17),"MAT_METAL_DARK")
    for x in [-2.5,0,2.5]:
        box("LuminaireHousing",(x,3.64,z),(1.5,.11,.28),"MAT_METAL_BRUSHED")
        box("LuminaireDiffuser",(x,3.57,z),(1.3,.025,.19),"MAT_EMISSIVE_WHITE",.005)
for x in [-4.2,4.2]:
    for z in [-3.2,0,3.2]:
        box("StructuralPillar",(x,1.85,z),(.18,3.7,.24),"MAT_METAL_BRUSHED")
        box("PillarInset",(x,1.65,z+.13),(.07,2.6,.018),"MAT_POLYMER_BLACK",.003)
# Access door, warning chevrons, tracks and viewport.
box("AirlockFrame",(0,1.5,4.25),(2.25,3,.20),"MAT_METAL_BRUSHED")
for x in [-.52,.52]:
    box("AirlockLeaf",(x,1.45,4.10),(.98,2.7,.10),"MAT_PANEL_LIGHT")
    box("AirlockRecess",(x,1.55,4.03),(.68,.84,.025),"MAT_POLYMER_BLACK")
    box("AirlockVisionGlass",(x,1.68,4.005),(.48,.45,.018),"MAT_GLASS",.01)
    box("AirlockHandle",(x*.22,1.2,3.98),(.04,.36,.065),"MAT_METAL_BRUSHED",.01)
box("AirlockStatusBar",(0,2.95,4.0),(1.75,.045,.035),"MAT_EMISSIVE_BLUE",.008)
for x in [-2.7,2.7]:
    for z in [-2.5,-1.7,-.9,0,.9,1.7,2.5]:
        box("DeckWayfinding",(x,.012,z),(.04,.007,.38),"MAT_LABEL",.001)
# Back-wall typography gives designed scale and identity.
text("StationIdentity","EDUALYN / RESEARCH STATION",(-3.75,3.29,-4.27),.15)
text("ModuleBayTitle","MODULE BAY",(-3.75,2.85,-4.27),.27)
text("BayNumber","01",(2.9,2.75,-4.27),.69)
text("SafetyLabel","CONTROLLED ENVIRONMENT  /  SERVICE ACCESS",(-3.75,.4,-4.26),.065)
# Sparse service equipment with ribs/fasteners rather than unarticulated boxes.
for x in [-3.75,3.65]:
    box("ServiceCabinet",(x,.7,-3.9),(.72,1.32,.55),"MAT_PANEL_GRAPHITE")
    box("CabinetAccessDoor",(x,.75,-3.59),(.61,1.12,.06),"MAT_METAL_DARK")
    for h in [.35,.45,.55,.65]:
        box("CoolingVent",(x,h,-3.55),(.42,.025,.02),"MAT_POLYMER_BLACK",.002)
    box("CabinetIndicator",(x-.21,1.17,-3.54),(.055,.018,.02),"MAT_EMISSIVE_BLUE",.002)
# Overhead duct with banded flanges.
for x in [-3.65,3.65]:
    cyl("ServiceDuct",(x,3.37,0),.13,7.6,"MAT_METAL_DARK",'z')
    for z in [-3,-1,1,3]:
        cyl("DuctCollar",(x,3.37,z),.16,.08,"MAT_METAL_BRUSHED",'z')
export("module_bay_01")
# Workbench in local coordinates.
start("Workbench")
box("BenchTop",(0,.99,0),(1.9,.14,.86),"MAT_METAL_BRUSHED",.035)
box("BenchWorkMat",(0,1.07,0),(1.65,.018,.65),"MAT_POLYMER_BLACK",.018)
for x in [-.73,.73]:
    box("BenchLeg",(x,.48,0),(.13,.93,.66),"MAT_METAL_DARK")
    box("BenchFoot",(x,.07,0),(.36,.10,.78),"MAT_POLYMER_BLACK")
box("RearCrossBrace",(0,.33,-.27),(1.5,.14,.09),"MAT_METAL_DARK")
box("BenchDrawer",(0,.77,.13),(1.28,.26,.52),"MAT_PANEL_GRAPHITE")
box("DrawerHandle",(0,.77,.415),(.34,.035,.04),"MAT_METAL_BRUSHED",.01)
for x in [-.82,.82]:
    bolt((x,1.078,.31),.018,'y')
text("BenchID","ASSEMBLY / A-01",(-.56,.91,.44),.055)
export("workbench")
# Freestanding physical terminal with a recessed glass screen and tactile controls.
start("MissionTerminal")
box("TerminalFoot",(0,.06,0),(.77,.12,.64),"MAT_POLYMER_BLACK")
box("TerminalColumn",(0,.65,-.04),(.28,1.2,.23),"MAT_METAL_BRUSHED")
box("TerminalBody",(0,1.49,0),(.9,.79,.21),"MAT_METAL_DARK",.065)
box("ScreenRecess",(0,1.54,.12),(.76,.53,.035),"MAT_POLYMER_BLACK",.02)
box("TerminalDisplay",(0,1.54,.143),(.68,.43,.009),"MAT_SCREEN",.008)
box("TerminalStatus",(0,1.88,.09),(.37,.018,.025),"MAT_EMISSIVE_BLUE",.004)
box("TerminalControlDeck",(0,1.08,.18),(.78,.08,.34),"MAT_PANEL_LIGHT")
for x in [-.25,-.12,.01]:
    cyl("PhysicalKey",(x,1.13,.20),.026,.015,"MAT_POLYMER_BLACK",'y',16)
cyl("ConfirmButton",(.24,1.13,.20),.046,.019,"MAT_EMISSIVE_BLUE",'y',24)
text("TerminalChassisMark","RS / CONTROL",(-.29,1.22,.13),.045)
export("mission_terminal")
# Repair unit with moving ring/core subassemblies.
start("RepairMachine")
box("MachinePlinth",(0,.12,0),(2.05,.24,1.23),"MAT_POLYMER_BLACK",.06)
box("MachineBase",(0,.55,0),(1.89,.74,1.05),"MAT_METAL_DARK",.065)
box("MachineFrontAccess",(0,.57,.55),(1.55,.47,.05),"MAT_PANEL_GRAPHITE",.025)
for x in [-.63,.63]:
    box("ServiceDrawerHandle",(x,.59,.59),(.22,.035,.04),"MAT_METAL_BRUSHED",.008)
for x in [-.82,.82]:
    box("VerticalActuator",(x,1.55,-.17),(.18,1.76,.25),"MAT_METAL_BRUSHED")
    box("ActuatorTrack",(x,1.57,-.015),(.08,1.38,.035),"MAT_POLYMER_BLACK")
    cyl("ActuatorRod",(x,1.65,.035),.025,1.3,"MAT_METAL_BRUSHED",'y',16)
box("UpperBridge",(0,2.43,-.17),(1.83,.18,.35),"MAT_METAL_DARK")
box("SocketShelf",(0,.98,.61),(2.1,.12,.53),"MAT_METAL_BRUSHED",.028)
# Ring pivot local parent: move geometry into local space while preserving export transform.
ring=bpy.data.objects.new("RingRotor",None); bpy.context.collection.objects.link(ring); ring.parent=root
ring.location=pos((0,1.73,.03))
parts=[]
for rad,minr,material in [(.56,.052,"MAT_METAL_BRUSHED"),(.46,.024,"MAT_POLYMER_BLACK"),(.62,.019,"MAT_METAL_DARK")]:
    parts.append(torus("DriveRing", (0,1.73,.03),rad,minr,material))
for k in range(8):
    a=k*math.tau/8
    p=(math.sin(a)*.56,1.73+math.cos(a)*.56,.03)
    parts.append(box("RingCoupler",p,(.12,.15,.13),"MAT_METAL_DARK",.018))
    parts.append(cyl("RingFastener",(p[0],p[1],.115),.027,.02,"MAT_METAL_BRUSHED",'z',6))
for o in parts:
    world=o.matrix_world.copy(); o.parent=ring; o.matrix_world=world
core=bpy.data.objects.new("CoreLift",None); bpy.context.collection.objects.link(core); core.parent=root
core.location=pos((0,1.6,.02))
parts=[cyl("CoreContainment",(0,1.6,.01),.26,.33,"MAT_POLYMER_BLACK",'z',48),
       cyl("CoreFace",(0,1.6,.21),.21,.06,"MAT_METAL_BRUSHED",'z',48),
       cyl("CoreLens",(0,1.6,.25),.15,.02,"MAT_SCREEN",'z',48),
       torus("CoreIndicator",(0,1.6,.275),.16,.012,"MAT_EMISSIVE_BLUE")]
for o in parts:
    world=o.matrix_world.copy(); o.parent=core; o.matrix_world=world
for x in [-.71,.71]:
    box("MachineIndicator",(x,2.42,.022),(.085,.035,.025),"MAT_POLYMER_BLACK",.005)
text("RepairUnitID","POWER COUPLING / R-01",(-.55,.77,.59),.07)
export("repair_machine")
# Power cartridge: stepped body, unequal connector keys, cooling fins and captive screws.
start("EnergyModule")
box("ModuleShell",(0,.13,0),(.48,.24,.32),"MAT_METAL_BRUSHED",.035)
box("ModuleTopCap",(-.035,.259,0),(.38,.025,.27),"MAT_METAL_DARK",.012)
box("AsymmetricKeyTab",(.25,.16,-.09),(.10,.12,.12),"MAT_EMISSIVE_WARNING",.015)
box("OrientationStripe",(-.13,.278,0),(.025,.009,.21),"MAT_EMISSIVE_BLUE",.002)
for x in [-.14,-.07,0,.07,.14]:
    box("CoolingFin",(x,.15,-.17),(.025,.13,.035),"MAT_POLYMER_BLACK",.004)
for x in [-.12,0,.12]:
    box("ConnectorPin",(x,-.015,0),(.035,.07,.095),"MAT_COPPER",.006)
for x in [-.16,.13]:
    for z in [-.09,.09]:
        bolt((x,.279,z),.013,'y')
box("ModuleFrontInset",(0,.14,.166),(.34,.12,.016),"MAT_POLYMER_BLACK",.009)
text("ModuleSerial","E-A",(-.08,.12,.178),.05,"MAT_LABEL")
export("energy_module")
# Complementary keyed docking geometry. Open rails frame a real recessed contact bay.
for correct in [False,True]:
    start("SocketCorrect" if correct else "SocketWrong")
    box("SocketMount",(0,.025,0),(.60,.05,.64),"MAT_METAL_DARK",.025)
    box("ContactWell",(0,.054,0),(.34,.015,.43),"MAT_POLYMER_BLACK",.006)
    for x in [-.24,.24]:
        box("DockGuideRail",(x,.095,0),(.065,.10,.55),"MAT_METAL_BRUSHED",.012)
        for z in [-.24,.24]: bolt((x,.15,z),.015,'y')
    box("DockRearStop",(0,.09,-.26),(.45,.08,.05),"MAT_METAL_BRUSHED",.01)
    for z in [-.12,0,.12]:
        box("ContactPad",(0,.068,z),(.12,.012,.038),"MAT_COPPER",.003)
    box("KeyedRail",(.19 if correct else -.19,.105,.17),(.04,.09,.12),"MAT_EMISSIVE_WARNING",.005)
    box("SocketIndicator",(0,.068,.28),(.16,.015,.024),"MAT_POLYMER_BLACK",.004)
    text("SocketLegend","POWER A" if correct else "SERVICE",(-.18,.02,.332),.045)
    export("socket_correct" if correct else "socket_wrong")
MODELS.mkdir(parents=True,exist_ok=True)
(ROOT/"verification/asset_manifest.json").write_text(json.dumps(stats,indent=2))
print("ASSET_BUILD_COMPLETE",json.dumps(stats))
