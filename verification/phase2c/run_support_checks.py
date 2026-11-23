"""Independent repair, physical unlock/variation, resource lifetime, controlled profiles."""
from pathlib import Path
import importlib.util,json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'verification/phase2c'
spec=importlib.util.spec_from_file_location('coolant',OUT/'run_coolant_checks.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def run():
    before=m.prior.cascade.reference.protected()
    m.game('independent',flag='--verify-mb03-independent',config='C')
    independent=json.loads((OUT/'independent.json').read_text());assert independent['all_gameplay_checks_passed']
    m.game('progression',scene='res://scenes/main/relay_polarity_failure.tscn',flag='--verify-mb03-progression',config=None,completed=['MB01'])
    progression=json.loads((OUT/'progression.json').read_text());assert progression['all_gameplay_checks_passed']
    m.game('resources',scene='res://scenes/main/power_coupling_cascade.tscn',flag='--verify-resources',config=None)
    resources=json.loads((OUT/'resources_all.json').read_text());assert resources['only_current_mission_heavy_resources']
    m.game('profile_MB02',scene='res://scenes/main/relay_polarity_failure.tscn',flag='--verify-profile',config=None)
    m.game('profile_MB03',flag='--verify-profile',config='A')
    profiles={slot:json.loads((OUT/('profile_'+slot+'.json')).read_text()) for slot in ['MB02','MB03']}
    assert m.prior.cascade.reference.protected()==before
    (OUT/'summary_support.json').write_text(json.dumps({'independent':independent,'progression':progression,'resource_loading':resources,'performance':profiles,'production_unchanged':True},indent=2))
    print('MB03_SUPPORT_PASS',flush=True)
if __name__=='__main__':run()
