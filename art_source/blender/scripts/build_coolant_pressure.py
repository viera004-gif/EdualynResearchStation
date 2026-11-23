"""MB03 original modeled cooling instruments; shared PBR palette, batched static surfaces."""
from pathlib import Path
prefix=Path(__file__).with_name('build_intervention_v02.py').read_text(encoding='utf-8').split('# Wall-mounted')[0]
exec(compile(prefix,str(__file__),'exec'))
MODELS=ROOT/'assets/models/mb03';SOURCE=ROOT/'art_source/blender/mb03'
MODELS.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
stats={};original_export=export
def export(name):
    # Batch static surfaces by material and parent; retain named feedback meshes.
    groups={}
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH' and not any(k in o.name for k in ['Flow','Indicator']):
            groups.setdefault((o.parent.name if o.parent else '',o.data.materials[0].name),[]).append(o)
    for (_,material),objects in groups.items():
        if len(objects)<2:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
        objects[0].name='Static_'+material
    original_export(name)
def loop(name,p,major,minor=.016,material='MAT_METAL_BRUSHED',segments=32):
    bpy.ops.mesh.primitive_torus_add(major_segments=segments,minor_segments=6,major_radius=major,minor_radius=minor,location=pos(p),rotation=(math.pi/2,0,0))
    return finish(bpy.context.object,name,material,0)
start('CoolantManifold')
box('Reservoir',(0,.45,.15),(2.80,.50,.42),'MAT_PANEL_GRAPHITE',.05)
box('ReservoirFace',(0,.45,.38),(2.58,.30,.055),'MAT_METAL_BRUSHED',.018)
for x in [-1.1,0,1.15]:
    cyl('SupplyPort',(x,.75,.13),.075,.20,'MAT_METAL_BRUSHED','y',24)
    cyl('PortCollar',(x,.67,.13),.11,.055,'MAT_METAL_DARK','y',24)
    bolt((x,.45,.42),.022)
box('ManifoldIndicator',(-1.02,.50,.414),(.22,.025,.015),'MAT_EMISSIVE_BLUE',.004)
for x in [-1.25,1.25]:box('MountingFoot',(x,.16,.1),(.14,.12,.30),'MAT_METAL_DARK',.015)
export('coolant_manifold')
start('PrimaryCoolantValve')
box('PrimaryMount',(0,1.35,.025),(.72,1.10,.09),'MAT_METAL_DARK',.03)
cyl('PrimaryPipe',(0,1.25,.15),.065,.94,'MAT_METAL_BRUSHED','y',24)
cyl('PrimaryBody',(0,1.35,.25),.14,.18,'MAT_METAL_DARK','z',32)
parts=[loop('Wheel',(0,1.35,.39),.21,.024,segments=48),cyl('WheelHub',(0,1.35,.39),.055,.05,'MAT_POLYMER_BLACK','z',24)]
for angle in [0,math.pi/2,math.pi,3*math.pi/2]:
    o=box('WheelSpoke',(math.sin(angle)*.10,1.35+math.cos(angle)*.10,.39),(.025,.20,.025),'MAT_METAL_DARK',.004)
    o.rotation_euler[1]=-angle;parts.append(o)
parts.append(box('WheelKey',(0,1.57,.4),(.055,.04,.035),'MAT_LABEL',.004))
pivot('ValveWheel',(0,1.35,.39),parts)
for x in [-.29,.29]:
    for y in [.88,1.82]:bolt((x,y,.09))
export('primary_valve')
start('PressureRegulator')
box('RegulatorMount',(0,1.35,.025),(.76,1.10,.09),'MAT_METAL_DARK',.03)
box('PressureHousing',(0,1.18,.18),(.39,.38,.27),'MAT_PANEL_LIGHT',.035)
cyl('PressureCylinder',(0,1.49,.18),.085,.35,'MAT_METAL_BRUSHED','y',24)
for y in [1.38,1.45,1.52,1.59]:loop('Spring',(0,y,.29),.09,.011,segments=24)
parts=[cyl('AdjustmentStem',(0,1.55,.18),.035,.33,'MAT_METAL_BRUSHED','y',24),
       box('AdjusterGrip',(0,1.75,.18),(.29,.065,.13),'MAT_POLYMER_BLACK',.022),
       box('PositionPointer',(.23,1.55,.18),(.12,.025,.05),'MAT_COPPER',.004)]
pivot('RegulatorSlide',(0,1.55,.18),parts)
box('TravelScale',(.27,1.54,.13),(.03,.42,.035),'MAT_LABEL',.004)
for y in [1.38,1.49,1.60,1.71]:box('TravelTick',(.29,y,.15),(.08,.012,.025),'MAT_METAL_DARK',.002)
for x in [-.31,.31]:
    for y in [.88,1.82]:bolt((x,y,.09))
export('pressure_regulator')
start('BypassValve')
box('BypassMount',(0,1.35,.025),(.70,1.10,.09),'MAT_METAL_DARK',.03)
cyl('BypassVertical',(0,1.25,.18),.065,.94,'MAT_METAL_BRUSHED','y',24)
cyl('ReturnTee',(.15,1.30,.18),.065,.40,'MAT_METAL_BRUSHED','x',24)
cyl('BypassBody',(0,1.35,.27),.11,.18,'MAT_METAL_DARK','z',32)
parts=[box('Lever',(0,1.49,.39),(.045,.28,.05),'MAT_METAL_BRUSHED',.006),box('LeverGrip',(0,1.65,.39),(.16,.07,.10),'MAT_POLYMER_BLACK',.02)]
pivot('BypassLever',(0,1.35,.39),parts)
for x in [-.28,.28]:
    for y in [.88,1.82]:bolt((x,y,.09))
export('bypass_valve')
start('CoolingCore')
box('ExchangerBase',(0,.12,0),(.82,.24,.67),'MAT_POLYMER_BLACK',.04)
box('HeatExchanger',(0,1.05,0),(.62,1.65,.35),'MAT_METAL_DARK',.05)
for y in [.45+i*.065 for i in range(20)]:box('RadiatorFin',(0,y,.22),(.73,.025,.24),'MAT_METAL_BRUSHED',.005)
for x in [-.28,.28]:
    cyl('CoreHeader',(x,1.05,.38),.05,1.50,'MAT_COPPER','y',24)
    for y in [.36,1.74]:cyl('HeaderUnion',(x,y,.38),.08,.09,'MAT_METAL_BRUSHED','y',24)
box('CoreWarningIndicator',(0,1.90,.18),(.35,.04,.025),'MAT_POLYMER_BLACK',.004)
box('CoreReadout',(0,1.65,.365),(.45,.23,.035),'MAT_SCREEN',.012)
export('cooling_core')
start('PressureGauge')
cyl('GaugeBack',(0,0,0),.22,.10,'MAT_METAL_DARK','z',48)
cyl('GaugeFace',(0,0,.06),.197,.025,'MAT_PANEL_LIGHT','z',48)
loop('GaugeBezel',(0,0,.09),.21,.018,segments=48)
for index in range(13):
    angle=2.35-index/12*4.7
    p=(-math.sin(angle)*.165,math.cos(angle)*.165,.08)
    o=box('GaugeTick',p,(.009,.034,.008),'MAT_METAL_DARK',0);o.rotation_euler[1]=-angle
for value in [0,2,4,6]:
    angle=2.35-value/6*4.7
    bpy.ops.object.text_add(location=pos((-math.sin(angle)*.12-.013,math.cos(angle)*.12-.015,.083)),rotation=(math.pi/2,0,0))
    digit=bpy.context.object;digit.data.body=str(value);digit.data.size=.032
    digit.data.resolution_u=3;digit.data.extrude=.0003
    bpy.ops.object.convert(target='MESH');finish(bpy.context.object,'GaugeNumber','MAT_METAL_DARK',0)
for value in [2.3+i*.1 for i in range(20)]:
    angle=2.35-value/6*4.7
    o=box('OperatingBand',(-math.sin(angle)*.187,math.cos(angle)*.187,.083),(.012,.015,.006),'MAT_EMISSIVE_BLUE',0);o.rotation_euler[1]=-angle
parts=[box('Needle',(0,.07,.105),(.012,.16,.012),'MAT_COPPER',.002),cyl('NeedleHub',(0,0,.105),.027,.02,'MAT_METAL_DARK','z',24)]
pivot('GaugeNeedle',(0,0,.105),parts)
export('pressure_gauge')
start('CoolantRouting')
def pipe(name,p,length,axis):
    cyl(name+'Pipe',p,.043,length,'MAT_METAL_BRUSHED',axis,20)
    size=(length-.06,.018,.018) if axis=='x' else (.018,length-.06,.018)
    box(name+'Flow',(p[0],p[1],p[2]+.045),size,'MAT_POLYMER_BLACK',.002)
pipe('FeedPipe',(-1.55,1.92,-3.73),1.10,'x')
pipe('CorePipe',(.95,2.45,-3.73),3.90,'x')
pipe('BypassPipe',(-.95,.85,-3.73),2.20,'x')
pipe('ReturnRiser',(.15,1.10,-3.73),.50,'y')
for x in [-2.1,-1.0,.15]:
    cyl('Riser',(x,1.00,-3.73),.043,.52,'MAT_METAL_BRUSHED','y',20)
    for y in [.78,1.22]:cyl('RiserCollar',(x,y,-3.73),.067,.05,'MAT_METAL_DARK','y',20)
pipe('CoreDown',(2.9,2.13,-3.73),.64,'y')
cyl('CoreLead',(2.9,1.81,-3.1),.043,1.25,'MAT_METAL_BRUSHED','z',20)
for x in [-1.8,-.7,.4,1.5,2.6]:box('PipeClamp',(x,2.45,-3.69),(.07,.15,.07),'MAT_METAL_DARK',.008)
export('coolant_routes')
(ROOT/'verification/phase2c/asset_manifest.json').write_text(json.dumps(stats,indent=2))
print('MB03_ASSETS_COMPLETE',json.dumps(stats))
