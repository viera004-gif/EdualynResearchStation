"""Mission 02 original hard-surface assets. Reuses accepted material/helper definitions only."""
from pathlib import Path
prefix=Path(__file__).with_name('build_intervention_v02.py').read_text(encoding='utf-8').split('# Wall-mounted')[0]
exec(compile(prefix,str(__file__),'exec'))
MODELS=ROOT/'assets/models/mb02';SOURCE=ROOT/'art_source/blender/mb02'
MODELS.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
stats={}
def plus(name,p,size=.065,material='MAT_COPPER'):
    return [box(name+'Horizontal',p,(size,.018,.018),material,.003),box(name+'Vertical',p,(.018,size,.018),material,.003)]
def minus(name,p,size=.065,material='MAT_COPPER'):
    return [box(name,p,(size,.018,.018),material,.003)]
for unit,target in [('a',1),('b',2)]:
    start('PolarityRelay'+unit.upper())
    box('RelayMount',(0,1.35,.025),(.80,1.12,.09),'MAT_METAL_DARK',.035)
    box('CeramicCarrier',(0,1.35,.10),(.65,.90,.08),'MAT_PANEL_LIGHT',.025)
    cyl('RotaryStator',(0,1.35,.18),.29,.13,'MAT_METAL_DARK','z',48)
    torus('MachinedStatorRing',(0,1.35,.29),.30,.022,'MAT_METAL_BRUSHED')
    # Connector position signs encode the target orientation physically.
    for sign,angle in [(1,target*math.pi/2),(-1,target*math.pi/2+math.pi)]:
        x=-math.sin(angle)*.345;y=1.35+math.cos(angle)*.345
        box('FixedContact',(x,y,.25),(.095,.095,.15),'MAT_COPPER',.01)
        (plus if sign==1 else minus)('FixedPositive' if sign==1 else 'FixedNegative',(x,y,.335),.07,'MAT_LABEL')
    parts=[cyl('RotorCartridge',(0,1.35,.32),.225,.13,'MAT_PANEL_GRAPHITE','z',48),
           torus('RotorGrip',(0,1.35,.41),.195,.022,'MAT_METAL_BRUSHED'),
           box('CartridgeGrip',(0,1.35,.445),(.10,.23,.07),'MAT_POLYMER_BLACK',.018)]
    for sign,offset in [(1,.22),(-1,-.22)]:
        parts.append(box('MovingContact',(0,1.35+offset,.36),(.10,.12,.11),'MAT_COPPER',.01))
        parts += (plus if sign==1 else minus)('RotorPositive' if sign==1 else 'RotorNegative',(0,1.35+offset,.425),.075,'MAT_LABEL')
    pivot('PolarityRotor',(0,1.35,.32),parts)
    if unit=='a':
        for x in [-.36,.36]:box('SideGuard',(x,1.35,.31),(.045,.80,.15),'MAT_METAL_BRUSHED',.012)
    else:
        for y in [.92,1.78]:box('CrownGuard',(0,y,.30),(.70,.055,.17),'MAT_METAL_BRUSHED',.012)
    for x in [-.34,.34]:
        for y in [.87,1.83]:bolt((x,y,.09),.018)
    box('PolarityIndicator',(0,.99,.15),(.19,.025,.02),'MAT_POLYMER_BLACK',.003)
    for x in [-.14,.14]:box('LatchRail',(x,1.75,.20),(.06,.07,.17),'MAT_METAL_DARK',.008)
    text('PolarityIdentity','A' if unit=='a' else 'B',(-.025,1.84,.11),.075)
    export('polarity_relay_'+unit)
start('RelayCouplingAssembly')
box('TestBackplate',(0,1.32,.035),(.55,1.15,.10),'MAT_METAL_DARK',.035)
box('SourceTransformer',(0,1.58,.18),(.42,.43,.25),'MAT_PANEL_GRAPHITE',.025)
for x in [-.14,-.07,0,.07,.14]:box('TransformerCoolingFin',(x,1.61,.32),(.022,.27,.07),'MAT_METAL_BRUSHED',.004)
box('SourceIndicator',(0,1.85,.10),(.23,.025,.018),'MAT_EMISSIVE_BLUE',.004)
box('TestContactor',(0,1.16,.18),(.40,.30,.23),'MAT_PANEL_LIGHT',.025)
parts=[cyl('ContactorAxle',(0,1.2,.32),.055,.08,'MAT_METAL_BRUSHED','z',24),
       box('RouteTestGrip',(0,1.31,.37),(.17,.09,.09),'MAT_POLYMER_BLACK',.018),
       box('RouteTestArm',(0,1.25,.35),(.035,.16,.04),'MAT_METAL_BRUSHED',.005)]
pivot('RouteTestLever',(0,1.2,.32),parts)
box('TestStatusIndicator',(0,.97,.10),(.20,.025,.02),'MAT_POLYMER_BLACK',.004)
export('relay_coupling_assembly')
start('PolarityConnectorBank')
for x in [-2.35,-1.35,0]:
    for dx in [-.10,.10]:
        cyl('BusConnector',(x+dx,.80,.16),.047,.13,'MAT_METAL_BRUSHED','y',24)
        box('InsulatorBoot',(x+dx,.72,.16),(.10,.10,.13),'MAT_POLYMER_BLACK',.014)
        box('BusPin',(x+dx,.84,.16),(.045,.06,.055),'MAT_COPPER',.006)
export('polarity_connectors')
start('PolarityRoutingChannels')
for name,left,right in [('SourceFeed',-2.35,-1.35),('RelayFeed',-1.35,0),('CouplerFeed',0,1.15)]:
    mid=(left+right)/2
    box(name+'Housing',(mid,.74,-3.73),(right-left+.06,.18,.13),'MAT_METAL_DARK',.012)
    for offset in [-.042,.042]:
        box(name+'Copper',(mid,.74+offset,-3.65),(right-left,.018,.025),'MAT_COPPER',.003)
    box(name+'Flow',(mid,.74,-3.64),(right-left-.07,.022,.015),'MAT_POLYMER_BLACK',.003)
    for x in [left+.14,right-.14]:
        box('CableBrace',(x,.74,-3.63),(.045,.21,.03),'MAT_METAL_BRUSHED',.005)
box('CouplerRiserHousing',(1.15,1.08,-3.73),(.13,.66,.13),'MAT_METAL_DARK',.012)
box('CouplerRiserFlow',(1.15,1.08,-3.64),(.025,.60,.015),'MAT_POLYMER_BLACK',.003)
export('polarity_routes')
(ROOT/'verification/phase2b/asset_manifest.json').write_text(json.dumps(stats,indent=2))
print('MB02_ASSETS_COMPLETE',json.dumps(stats))
