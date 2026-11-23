"""Final audit of all mission regressions, MB03 evidence, preserved assets and budgets."""
from pathlib import Path
import importlib.util,json,hashlib,zipfile,re
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'verification/phase2c'
spec=importlib.util.spec_from_file_location('checks',OUT/'run_coolant_checks.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def main():
    coolant=read(OUT/'summary_coolant.json');support=read(OUT/'summary_support.json')
    assert all(r['all_gameplay_checks_passed'] for r in coolant['offline'].values())
    for case in ['A','B','C']:
        left=m.verify_trace(case,'tr','offline')[1];right=m.verify_trace(case,'en','offline')[1]
        assert m.prior.bilingual.normalize(left)==m.prior.bilingual.normalize(right)
    assert coolant['stall']['no_mb01_timed_nudge_at_46_seconds'] and coolant['stall']['actual_75_second_salience']
    assert coolant['online']['replay_conflict_passed'] and coolant['online']['runtime']['completed_controls_status']
    assert support['independent']['all_gameplay_checks_passed'] and support['progression']['all_gameplay_checks_passed']
    assert support['resource_loading']['only_current_mission_heavy_resources']
    assert read(OUT/'resources_before_mb03.json')['only_current_mission_heavy_resources']
    model=read(OUT/'network_model.json');assert len(model['valid_balances'])==3 and all(model['start_configurations_reachable'].values())
    mb01=read(ROOT/'verification/v02/summary_both.json');assert mb01['offline']['all_gameplay_checks_passed'] and mb01['online']['all_gameplay_checks_passed']
    assert read(ROOT/'verification/localization/summary.json')['event_names_and_semantics_identical']
    mb02=read(ROOT/'verification/phase2b/summary_offline.json');assert mb02['locale_equivalent']
    assert read(ROOT/'verification/phase2b/summary_online.json')['api']['accepted_events']==69
    for name in ['A_tr','A_en','B_tr','B_en','C_tr','C_en','stall_A_en','C_en_online','independent','progression','resources','profile_MB03']:
        diagnostic=(OUT/(name+'.stderr')).read_text(encoding='utf-8')
        assert not any(s in diagnostic for s in ['SCRIPT ERROR','Parse Error','Failed loading','Missing localization','ObjectDB']), (name,diagnostic)
    catalog=read(ROOT/'localization/catalog.json');messages={}
    for locale in catalog['locales']:
        messages[locale]={}
        for pack in catalog['packs']:
            entries=read(ROOT/'localization'/pack/(locale+'.json'))
            assert not(entries.keys() & messages[locale].keys())
            assert not any(any(bad in value for bad in ['\ufffd','\u00c4','\u00c5']) for value in entries.values())
            messages[locale].update(entries)
    assert messages['tr'].keys()==messages['en'].keys()
    for key in messages['tr']:
        assert set(re.findall(r'\{([^{}]+)\}',messages['tr'][key]))==set(re.findall(r'\{([^{}]+)\}',messages['en'][key])),key
    before=read(OUT/'before_files.json')
    with zipfile.ZipFile(ROOT/'reference_builds/module_bay_program_pre_phase2c.zip') as archive:
        assert all(hashlib.sha256(archive.read(name)).hexdigest()==digest for name,digest in before.items())
    protected=[name for name in before if name.startswith(('assets/','art_source/','scenes/','scripts/mission/','scripts/player/','scripts/machine/','scripts/interaction/','scripts/telemetry/','scripts/audio/')) or name in ['project.godot','README.md','REFERENCE_BUILD.md','VERIFICATION_REPORT.md','Launch_Module_Bay_01.ps1','Launch_Module_Bay_Program.ps1','scripts/intervention/power_coupling_cascade.gd','config/missions/mb01.json','config/missions/mb02.json']]
    assert all(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==before[name] for name in protected)
    frozen=m.prior.cascade.frozen()
    assert m.prior.cascade.reference.protected()['hashes']==read(ROOT/'verification/v02/production_before.json')['hashes']
    registry=read(ROOT/'config/module_bay_program.json')
    assert [entry['slot'] for entry in registry['missions'] if entry['implemented']]==['MB01','MB02','MB03']
    profiles={slot:read(OUT/('profile_'+slot+'.json')) for slot in ['MB02','MB03']}
    assert profiles['MB03']['shadow_lights']==profiles['MB02']['shadow_lights']==1
    assert profiles['MB03']['dynamic_light_nodes']==profiles['MB02']['dynamic_light_nodes']==8
    assert profiles['MB03']['mission_pooled_materials']==9
    result={'decision':'GO - Phase 2C prototype scope','mb03_configurations':['A','B','C'],'tr_en_equivalent':True,
            'configurations_solved_in_both_languages':6,'valid_balances':model['valid_balances'],
            'causal_telemetry_and_reversal_links_verified':True,'actual_75_second_help_test_passed':True,
            'synthetic_api':{k:v for k,v in coolant['online'].items() if k!='runtime'},
            'independent_repair':support['independent'],'progression':support['progression'],
            'resources':support['resource_loading'],'performance':profiles,
            'mb01_regression_passed':True,'mb02_regression_passed':True,'localization_keys_per_language':len(messages['tr']),
            'accepted_assets_and_mb01_rules_unchanged':True,'pre_phase2c_snapshot_files_verified':len(before),
            'frozen_v01':frozen,'production_unchanged':True,'mission04_started':False}
    (OUT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    files=[p for d in ['scripts','config','scenes','localization','assets','art_source'] for p in (ROOT/d).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    files += [ROOT/name for name in ['WORK_SESSION_HANDOFF.md','MODULE_BAY_PROGRAM.md','LOCALIZATION.md']]
    (OUT/'final_file_inventory.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2))
    assert (ROOT/'WORK_SESSION_HANDOFF.md').is_file()
    print('PHASE_2C_AUDIT_PASS',len(messages['tr']),'keys per locale;',coolant['online']['accepted_events'],'MB03 API events;',len(before),'preserved accepted files')
if __name__=='__main__':main()
