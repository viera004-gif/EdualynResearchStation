"""Phase 2B GPU, localization, progression, performance and isolated API checks."""
from pathlib import Path
from contextlib import closing
from unittest.mock import patch
import argparse, hashlib, importlib.util, json, os, socket, sqlite3, subprocess, sys, tempfile, time, zipfile
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'verification/phase2b'
spec=importlib.util.spec_from_file_location('cascade',ROOT/'verification/v02/run_cascade_checks.py')
cascade=importlib.util.module_from_spec(spec);spec.loader.exec_module(cascade)
spec2=importlib.util.spec_from_file_location('bilingual',ROOT/'verification/localization/run_localization_checks.py')
bilingual=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(bilingual)
def game(name,scene,flag,locale='en',api='http://127.0.0.1:1/api/v2/research-station',completed=None):
    progress=OUT/('progress_'+name+'.json')
    progress.write_text(json.dumps({'schema_version':1,'completed':completed or []}))
    env=os.environ.copy();env['APPDATA']=str(OUT/'userdata');Path(env['APPDATA']).mkdir(exist_ok=True)
    args=[str(cascade.GODOT),'--path',str(ROOT),'--rendering-method','mobile','--rendering-driver','vulkan',
          '--log-file',str(OUT/(name+'.log')),scene,'--','--verify',flag,'--skip-language-selector',
          '--locale='+locale,'--progress-file='+str(progress),'--api-base='+api]
    with (OUT/(name+'.stdout')).open('w',encoding='utf-8') as out,(OUT/(name+'.stderr')).open('w',encoding='utf-8') as err:
        p=subprocess.Popen(args,stdout=out,stderr=err,startupinfo=cascade.reference.hidden(),env=env)
        try:
            deadline=time.monotonic()+100
            while p.poll() is None:
                time.sleep(.2)
                diagnostic=(OUT/(name+'.stderr')).read_text(encoding='utf-8')
                if any(marker in diagnostic for marker in ['SCRIPT ERROR','Parse Error']):
                    p.kill();p.wait();raise RuntimeError(name+': '+diagnostic)
                if time.monotonic()>deadline:raise subprocess.TimeoutExpired(args,100)
            code=p.returncode
        except subprocess.TimeoutExpired:
            p.kill();p.wait();raise RuntimeError('Runtime timeout '+name)
    errors=(OUT/(name+'.stderr')).read_text(encoding='utf-8')
    assert code==0 and not any(s in errors for s in ['SCRIPT ERROR','Parse Error','Missing localization','Failed loading','Cannot open']), (name,code,errors,(OUT/(name+'.stdout')).read_text(encoding='utf-8')[-4000:])
    print('GPU_PASS',name,flush=True)
def mb02(locale,api='http://127.0.0.1:1/api/v2/research-station'):
    mode='offline' if ':1/' in api else 'online';suffix=locale+'_'+mode
    game('mb02_'+suffix,'res://scenes/main/relay_polarity_failure.tscn','--verify-mb02',locale,api,['MB01'])
    report=json.loads((OUT/('runtime_mb02_'+suffix+'.json')).read_text(encoding='utf-8'))
    trace=json.loads((OUT/('telemetry_mb02_'+suffix+'.json')).read_text(encoding='utf-8'))
    assert report['all_gameplay_checks_passed']
    events=trace['events']
    assert all(e['mission_id']=='MODULE_BAY_02_RELAY_POLARITY' and e['metadata']['session_purpose']=='intervention' for e in events)
    assert [e['event_index'] for e in events]==list(range(len(events)))
    assert len({e['event_uuid'] for e in events})==len(events)
    assert {e['metadata']['failure_state'] for e in events if e['event_type']=='relay_configuration_invalid'}=={'BOTH_RELAYS_MISMATCHED','PHASE_COLLAPSE_AT_B','INPUT_BLOCKED_AT_A'}
    assert {1,2,3}<={e['metadata']['help_level'] for e in events if e['event_type']=='help_delivered'}
    assert {'relay_unit_rotated','relay_configuration_invalid','relay_configuration_valid','power_route_changed','scanner_scan_completed','help_requested','mission_completed'}<={e['event_type'] for e in events}
    if mode=='online':assert trace['completed'] and not trace['pending'] and not trace['quarantined']
    else:assert trace['pending'] and not trace['session_uuid']
    return report,trace
def run(mode):
    before=cascade.reference.protected();results={}
    if mode in ['offline','all']:
        results['mb02_tr'],tr=mb02('tr');results['mb02_en'],en=mb02('en')
        assert bilingual.normalize(tr)==bilingual.normalize(en),'TR/EN event semantics differ'
        results['locale_equivalent']=True;results['events_per_mb02_run']=len(tr['events'])
    if mode in ['online','all']:
        with tempfile.TemporaryDirectory(prefix='mb02_api_') as directory:
            db=Path(directory)/'synthetic.db';sys.path.insert(0,str(cascade.reference.BACKEND))
            import backend.main as main
            with patch.object(main,'DB_PATH',db):
                main.init_database()
                with main.database_connection() as connection:
                    connection.execute("INSERT INTO students (id,student_code,first_name,last_name,grade) VALUES (1,'SYNTHETIC','Runtime','Fixture',7)")
            with socket.socket() as endpoint:endpoint.bind(('127.0.0.1',0));port=endpoint.getsockname()[1]
            with (OUT/'backend.log').open('w') as log:
                server=subprocess.Popen([sys.executable,'-B',str(ROOT/'verification/run_checks.py'),'--backend',str(db),str(port)],stdout=log,stderr=log,startupinfo=cascade.reference.hidden())
                try:
                    for _ in range(60):
                        try:cascade.reference.json_request('http://127.0.0.1:%d/health'%port);break
                        except Exception:
                            if server.poll() is not None:raise RuntimeError('Synthetic backend exited')
                            time.sleep(.2)
                    else:raise RuntimeError('Backend not ready')
                    api='http://127.0.0.1:%d/api/v2/research-station'%port
                    results['mb02_api'],trace=mb02('en',api)
                    path=api+'/sessions/'+trace['session_uuid']+'/events:batch'
                    assert cascade.reference.json_request(path,{'events':[trace['events'][0]]})['results'][0]['status']=='already_accepted'
                    assert cascade.reference.json_request(path,{'events':[dict(trace['events'][0],metadata={'conflict_probe':True})]})['results'][0]['status']=='conflict'
                    with closing(sqlite3.connect(db)) as connection:
                        count=connection.execute('SELECT count(*) FROM research_station_events').fetchone()[0]
                        assert count==trace['acknowledged']==len(trace['events'])
                        assert connection.execute('SELECT session_purpose FROM research_station_sessions').fetchone()[0]=='intervention'
                        assert connection.execute('SELECT count(*) FROM academic_records').fetchone()[0]==0
                    results['api']={'synthetic_only':True,'accepted_events':count,'replay_and_conflict_passed':True}
                finally:server.terminate();server.wait(timeout=8)
    if mode in ['program','all']:
        game('progression','res://scenes/main/power_coupling_cascade.tscn','--verify-progression',completed=[])
        results['progression']=json.loads((OUT/'progression.json').read_text())
        assert results['progression']['all_gameplay_checks_passed']
        game('profile_mb01','res://scenes/main/power_coupling_cascade.tscn','--verify-profile')
        game('profile_mb02','res://scenes/main/relay_polarity_failure.tscn','--verify-profile',completed=['MB01'])
        results['performance']={slot:json.loads((OUT/('profile_'+slot+'.json')).read_text()) for slot in ['MB01','MB02']}
        game('independent_mb02','res://scenes/main/relay_polarity_failure.tscn','--verify-mb02-independent',completed=['MB01'])
        results['independent_mb02']=json.loads((OUT/'independent_mb02.json').read_text())
        assert results['independent_mb02']['all_gameplay_checks_passed']
    assert cascade.reference.protected()==before,'Production data changed'
    results['production_unchanged']=True;results['frozen_reference']=cascade.frozen()
    manifest=json.loads((ROOT/'reference_builds/intervention_v02_pre_phase2b_files.json').read_text())
    with zipfile.ZipFile(ROOT/'reference_builds/module_bay_intervention_v02_pre_phase2b.zip') as archive:
        assert all(hashlib.sha256(archive.read(n)).hexdigest()==h for n,h in manifest.items())
    results['accepted_v02_snapshot_verified']=len(manifest)
    (OUT/('summary_'+mode+'.json')).write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    print('PHASE_2B_PASS',mode,flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--mode',choices=['offline','online','program','all'],default='all');run(p.parse_args().mode)
