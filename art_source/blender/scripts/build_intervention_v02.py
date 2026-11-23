"""Additive Blender-authored v0.2 assemblies; never rewrites accepted v0.1 assets."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
MODELS=ROOT/"assets/models/intervention_v02"
SOURCE=ROOT/"art_source/blender/intervention_v02"
MODELS.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
M={};root=None;stats={}
old=(Path(__file__).with_name("build_assets.py")).read_text(encoding="utf-8")
# Reuse only the established material/helper definitions, NOT its asset generation.
exec(compile(old[old.index("def mat("):old.index("# Reproducible subtle")],str(__file__),"exec"))
for key in ["MAT_METAL_DARK","MAT_METAL_BRUSHED","MAT_PANEL_GRAPHITE","MAT_FLOOR"]:
    material=M[key];node=material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image=bpy.data.images.load(str(ROOT/"assets/textures"/(key.lower()+"_roughness.png")),check_existing=True)
    material.node_tree.links.new(node.outputs["Color"],material.node_tree.nodes.get("Principled BSDF").inputs["Roughness"])
exec(compile(old[old.index("def pos(v)"):old.index("# Room shell:")],str(__file__),"exec"))
def pivot(name,p,parts):
    empty=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(empty);empty.parent=root
    empty.location=pos(p)
    # Evaluate the pivot before computing child local transforms. Otherwise the
    # export doubles the pivot offset and leaves the wheel/lever floating above it.
    bpy.context.view_layer.update()
    for part in parts:
        world=part.matrix_world.copy();part.parent=empty;part.matrix_world=world
    return empty
# Wall-mounted coolant valve, flange/collar/pipe, machined wheel with orientation key.
start("CoolingRegulator")
box("ValveBackplate",(0,1.34,.035),(.72,1.16,.10),"MAT_METAL_DARK",.035)
box("ValveInset",(0,1.34,.10),(.59,.92,.035),"MAT_PANEL_GRAPHITE",.015)
cyl("CoolantTube",(.17,1.3,.19),.068,1.15,"MAT_METAL_BRUSHED",'y')
for y in [.82,1.25,1.78]:
    cyl("PipeFlange",(.17,y,.19),.10,.05,"MAT_METAL_DARK",'y')
cyl("ValveBody",(0,1.4,.27),.15,.19,"MAT_METAL_DARK",'z')
parts=[torus("ValveWheelRim",(0,1.4,.39),.21,.025,"MAT_METAL_BRUSHED"),
       cyl("ValveWheelHub",(0,1.4,.39),.06,.06,"MAT_POLYMER_BLACK",'z',24)]
for k in range(4):
    a=k*math.pi/2
    o=box("ValveWheelSpoke",(math.sin(a)*.105,1.4+math.cos(a)*.105,.39),(.026,.20,.028),"MAT_METAL_DARK",.006)
    o.rotation_euler[1]=-a;parts.append(o)
parts.append(box("ValvePositionKey",(0,1.62,.40),(.065,.055,.043),"MAT_EMISSIVE_WARNING",.008))
pivot("ValveWheel",(0,1.4,.39),parts)
box("CoolingIndicator",(0,1.03,.154),(.23,.025,.018),"MAT_POLYMER_BLACK",.004)
for x in [-.29,.29]:
    for y in [.86,1.82]:bolt((x,y,.115))
text("ValveIdentity","COOLING / C-01",(-.26,1.89,.10),.055)
text("ValveGaugeLabel","FLOW",(-.23,1.65,.15),.038)
export("cooling_regulator")
# Protected electromechanical contactor with moving lever and visible copper contacts.
start("AuxiliaryRelay")
box("RelayBackplate",(0,1.32,.035),(.72,1.16,.10),"MAT_METAL_DARK",.035)
box("ContactorHousing",(0,1.35,.16),(.52,.69,.21),"MAT_PANEL_LIGHT",.035)
box("ContactorRecess",(0,1.33,.285),(.34,.49,.04),"MAT_POLYMER_BLACK",.013)
for x in [-.10,.10]:
    box("RelayContact",(x,1.23,.315),(.045,.26,.024),"MAT_COPPER",.006)
for x in [-.25,.25]:
    box("RelayGuard",(x,1.4,.34),(.045,.56,.13),"MAT_METAL_BRUSHED",.01)
parts=[cyl("LeverAxle",(0,1.35,.36),.065,.08,"MAT_METAL_BRUSHED",'z'),
       box("LeverArm",(0,1.51,.39),(.035,.30,.04),"MAT_METAL_BRUSHED",.008),
       box("LeverGrip",(0,1.67,.39),(.20,.065,.09),"MAT_POLYMER_BLACK",.025)]
pivot("RelayLever",(0,1.35,.36),parts)
box("RelayIndicator",(0,.98,.155),(.23,.025,.018),"MAT_POLYMER_BLACK",.004)
for x in [-.29,.29]:
    for y in [.86,1.82]:bolt((x,y,.115))
text("RelayIdentity","AUXILIARY / R-02",(-.28,1.89,.10),.052)
export("auxiliary_relay")
start("DiagnosticScannerDock")
box("DockFoot",(0,.06,0),(.67,.12,.56),"MAT_POLYMER_BLACK",.04)
box("DockPedestal",(0,.56,-.06),(.22,.94,.19),"MAT_METAL_BRUSHED",.025)
box("DockDeck",(0,1.05,0),(.58,.10,.54),"MAT_METAL_DARK",.03)
for x in [-.21,.21]:
    box("ToolCradle",(x,1.15,0),(.055,.13,.37),"MAT_METAL_BRUSHED",.012)
for x in [-.065,.065]:
    box("ToolContact",(x,1.108,0),(.04,.015,.11),"MAT_COPPER",.003)
box("DockIndicator",(0,1.11,.22),(.22,.015,.02),"MAT_EMISSIVE_BLUE",.003)
text("DockIdentity","FIELD DIAGNOSTICS",(-.22,1.015,.28),.04)
export("scanner_dock")
# Actual handheld scanner, screen on camera-facing rear, optical head forward.
start("DiagnosticScanner")
box("ToolGrip",(0,.055,.035),(.12,.18,.18),"MAT_POLYMER_BLACK",.03)
box("ScannerChassis",(0,.21,0),(.32,.17,.40),"MAT_METAL_BRUSHED",.035)
box("ScannerArmor",(0,.305,-.015),(.28,.025,.32),"MAT_METAL_DARK",.012)
box("ScannerDisplay",(0,.22,.207),(.245,.105,.014),"MAT_SCREEN",.01)
box("ScannerScreenFrame",(0,.285,.211),(.27,.018,.02),"MAT_POLYMER_BLACK",.004)
for x in [-.11,.11]:
    cyl("OpticCollar",(x,.21,-.224),.043,.065,"MAT_METAL_DARK",'z',24)
    cyl("OpticLens",(x,.21,-.26),.029,.015,"MAT_EMISSIVE_BLUE",'z',24)
for z in [-.10,-.035,.03]:
    box("ScannerVent",(.166,.21,z),(.02,.065,.018),"MAT_POLYMER_BLACK",.003)
for x in [-.10,.10]:
    bolt((x,.324,.11),.012,'y')
muzzle=bpy.data.objects.new("ScannerMuzzle",None);bpy.context.collection.objects.link(muzzle);muzzle.parent=root;muzzle.location=pos((0,.21,-.27))
text("ScannerTag","DS-01",(-.08,.30,.14),.035)
export("diagnostic_scanner")
# Physical support console: separate silhouette, optics, recessed display and tactile deck.
start("DiagnosticAIStation")
box("AIStationFoot",(0,.07,0),(.87,.14,.76),"MAT_POLYMER_BLACK",.045)
box("AIStationColumn",(0,.66,-.05),(.37,1.14,.32),"MAT_PANEL_GRAPHITE",.04)
box("AIStationChest",(0,1.50,0),(.98,.88,.28),"MAT_METAL_DARK",.055)
box("AIStationScreenRecess",(0,1.52,.16),(.82,.56,.04),"MAT_POLYMER_BLACK",.018)
box("AIStationScreen",(0,1.53,.188),(.75,.48,.012),"MAT_SCREEN",.008)
box("AIStationHood",(0,1.99,.07),(1.03,.09,.48),"MAT_METAL_BRUSHED",.025)
box("StationBeacon",(0,1.955,.208),(.34,.018,.028),"MAT_POLYMER_BLACK",.003)
cyl("DiagnosticOpticHousing",(-.37,1.88,.21),.068,.06,"MAT_METAL_BRUSHED",'z',32)
cyl("DiagnosticOptic",(-.37,1.88,.247),.044,.018,"MAT_EMISSIVE_BLUE",'z',24)
box("AIControlDeck",(0,1.075,.24),(.90,.075,.39),"MAT_PANEL_LIGHT",.025)
for x in [-.28,-.12,.04]:
    cyl("AIControlButton",(x,1.123,.27),.025,.016,"MAT_POLYMER_BLACK",'y',16)
cyl("AIRequestButton",(.28,1.123,.27),.05,.02,"MAT_EMISSIVE_BLUE",'y',24)
text("AIIdentity","DIAGNOSTIC SUPPORT",(-.35,1.20,.15),.055)
export("diagnostic_ai_station")
# Manufactured routing: channels and clamps, no arrows or printed solution order.
start("PowerRoutes")
def route(name,p,s,axis):
    box(name+"Channel",p,s,"MAT_METAL_DARK",.012)
    strip=list(s)
    strip[2]=.014
    strip[1]=.025 if axis=='x' else s[1]-.04
    if axis=='y':strip[0]=.025
    box(name+"Flow",(p[0],p[1],p[2]+.048),tuple(strip),"MAT_POLYMER_BLACK",.003)
route("CoolingRoute",(-.77,.99,-3.87),(1.12,.09,.07),'x')
route("RelayRoute",(.58,.99,-3.87),(1.31,.09,.07),'x')
route("CouplerRoute",(1.20,1.48,-3.87),(.09,.91,.07),'y')
route("CoreRoute",(2.45,1.63,-2.57),(.055,.95,.055),'y')
for x in [-1.22,-.85,-.45,.12,.55,1.0]:
    box("CableClamp",(x,.99,-3.81),(.045,.15,.04),"MAT_METAL_BRUSHED",.006)
    bolt((x,1.035,-3.78),.011)
export("power_routes")
(ROOT/"verification/v02/asset_manifest.json").write_text(json.dumps(stats,indent=2))
print("V02_ASSETS_COMPLETE",json.dumps(stats))
