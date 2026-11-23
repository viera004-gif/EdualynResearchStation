"""Consolidate successful scenario evidence without rerunning GPU playthroughs."""
from pathlib import Path
import hashlib, importlib.util, json, re, zipfile
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'verification/phase2b'
spec=importlib.util.spec_from_file_location('checks',OUT/'run_program_checks.py')
checks=importlib.util.module_from_spec(spec);spec.loader.exec_module(checks)
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def main():
    reports={suffix:read(OUT/('runtime_mb02_'+suffix+'.json')) for suffix in ['tr_offline','en_offline','en_online']}
    assert all(r['all_gameplay_checks_passed'] for r in reports.values())
    traces={suffix:read(OUT/('telemetry_mb02_'+suffix+'.json')) for suffix in reports}
    assert checks.bilingual.normalize(traces['tr_offline'])==checks.bilingual.normalize(traces['en_offline'])
    online=read(OUT/'summary_online.json');program=read(OUT/'summary_program.json')
    assert program['progression']['all_gameplay_checks_passed'] and program['independent_mb02']['all_gameplay_checks_passed']
    assert online['api']['replay_and_conflict_passed'] and online['api']['accepted_events']==69
    assert read(ROOT/'verification/v02/summary_both.json')['offline']['all_gameplay_checks_passed']
    assert read(ROOT/'verification/v02/summary_both.json')['online']['all_gameplay_checks_passed']
    assert read(ROOT/'verification/localization/summary.json')['event_names_and_semantics_identical']
    for name in ['mb02_tr_offline','mb02_en_offline','mb02_en_online','progression','independent_mb02','profile_mb01','profile_mb02']:
        errors=(OUT/(name+'.stderr')).read_text(encoding='utf-8')
        assert not any(marker in errors for marker in ['SCRIPT ERROR','Parse Error','Failed loading','Missing localization']),errors
    merged={}
    catalog=read(ROOT/'localization/catalog.json')
    for locale in catalog['locales']:
        merged[locale]={}
        for pack in catalog['packs']:
            entries=read(ROOT/'localization'/pack/(locale+'.json'))
            assert not(merged[locale].keys() & entries.keys())
            for value in entries.values():
                assert not any(marker in value for marker in ['\ufffd','\u00c4','\u00c5'])
            merged[locale].update(entries)
    assert merged['tr'].keys()==merged['en'].keys()
    for key in merged['tr']:
        assert set(re.findall(r'\{([^{}]+)\}',merged['tr'][key]))==set(re.findall(r'\{([^{}]+)\}',merged['en'][key])),key
    snapshot=read(ROOT/'reference_builds/intervention_v02_pre_phase2b_files.json')
    with zipfile.ZipFile(ROOT/'reference_builds/module_bay_intervention_v02_pre_phase2b.zip') as archive:
        assert all(hashlib.sha256(archive.read(name)).hexdigest()==digest for name,digest in snapshot.items())
    # All accepted assets, original scripts and default configuration are protected.
    protected=[name for name in snapshot if name.startswith(('assets/','art_source/','scenes/','scripts/player/','scripts/mission/','scripts/machine/','scripts/interaction/','scripts/telemetry/','scripts/audio/')) or name in ['project.godot','README.md','REFERENCE_BUILD.md','VERIFICATION_REPORT.md','ANDROID_READINESS.md','Launch_Module_Bay_01.ps1','Launch_Module_Bay_Intervention_v02.ps1']]
    assert all(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==snapshot[name] for name in protected)
    reference=checks.cascade.frozen()
    assert checks.cascade.reference.protected()['hashes']==read(ROOT/'verification/v02/production_before.json')['hashes']
    changes=[name for name,digest in snapshot.items() if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest]
    current=[p for d in ['scripts','config','scenes','localization','assets','art_source'] for p in (ROOT/d).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    created=[str(p.relative_to(ROOT)).replace('\\','/') for p in current if str(p.relative_to(ROOT)).replace('\\','/') not in snapshot]
    result={'decision':'GO - Phase 2B prototype scope','mission01_regression_passed':True,'mission01_bilingual_passed':True,
            'mission02_runtime_passed':True,'mission02_tr_en_equivalent':True,'mission02_events_per_scenario':69,
            'mission02_api':online['api'],'progression':program['progression'],'independent_mb02':program['independent_mb02'],
            'performance':program['performance'],'localization_keys_per_language':len(merged['tr']),
            'frozen_reference':reference,'accepted_v02_snapshot_verified':len(snapshot),'accepted_assets_unchanged':True,
            'production_unchanged':True,'changed_accepted_source_files':changes,'new_source_asset_files':created,
            'known_runtime_messages':['restricted Windows root certificate store','known upstream seven Texture RID shutdown warning']}
    (OUT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    paths=[*current,*[ROOT/n for n in ['MODULE_BAY_PROGRAM.md','LOCALIZATION.md','INTERVENTION_MODULE_BAY_V02.md','WORK_SESSION_HANDOFF.md','Launch_Module_Bay_Program.ps1']]]
    (OUT/'final_file_inventory.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2))
    assert (ROOT/'WORK_SESSION_HANDOFF.md').is_file()
    print('PHASE_2B_AUDIT_PASS',len(merged['tr']),'keys per locale;',len(snapshot),'preserved v02 files;',reference['archive_entries_verified'],'v01 archive entries')
if __name__=='__main__':main()
