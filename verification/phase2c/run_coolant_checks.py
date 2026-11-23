"""Actual GPU MB03 configurations/languages, causal raw traces, and synthetic API."""
from pathlib import Path
import argparse, importlib.util, json, os, subprocess, time, sys, tempfile, socket, sqlite3
from unittest.mock import patch
from contextlib import closing
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'verification/phase2c'
spec=importlib.util.spec_from_file_location('prior',ROOT/'verification/phase2b/run_program_checks.py')
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
def game(name,scene='res://scenes/main/coolant_pressure_imbalance.tscn',flag='--verify-mb03',locale='en',config='A',api='http://127.0.0.1:1/api/v2/research-station',stall=False,completed=None):
    progress=OUT/('progress_'+name+'.json');progress.write_text(json.dumps({'schema_version':1,'completed':['MB01','MB02'] if completed is None else completed}))
    env=os.environ.copy();env['APPDATA']=str(OUT/'userdata');Path(env['APPDATA']).mkdir(exist_ok=True)
    args=[str(prior.cascade.GODOT),'--path',str(ROOT),'--rendering-method','mobile','--rendering-driver','vulkan','--log-file',str(OUT/(name+'.log')),scene,'--','--verify',flag,'--skip-language-selector','--locale='+locale,'--progress-file='+str(progress),'--api-base='+api]
    if config:args.append('--coolant-config='+config)
    if stall:args.append('--verify-stall')
    if flag=='--verify-profile':args.append('--profile-output-dir=res://verification/phase2c')
    with (OUT/(name+'.stdout')).open('w',encoding='utf-8') as out,(OUT/(name+'.stderr')).open('w',encoding='utf-8') as err:
        p=subprocess.Popen(args,stdout=out,stderr=err,startupinfo=prior.cascade.reference.hidden(),env=env)
        deadline=time.monotonic()+(190 if stall else 100)
        while p.poll() is None:
            time.sleep(.2)
            errors=(OUT/(name+'.stderr')).read_text(encoding='utf-8')
            if any(marker in errors for marker in ['SCRIPT ERROR','Parse Error','Missing localization']) or time.monotonic()>deadline:
                p.kill();p.wait();raise RuntimeError(name+': '+errors)
    errors=(OUT/(name+'.stderr')).read_text(encoding='utf-8')
    assert p.returncode==0 and not any(s in errors for s in ['SCRIPT ERROR','Parse Error','Failed loading']), (name,p.returncode,errors,(OUT/(name+'.stdout')).read_text(encoding='utf-8')[-4500:])
    print('GPU_PASS',name,flush=True)
def verify_trace(config,locale,mode,extra=''):
    suffix=config+'_'+locale+'_'+mode+extra
    report=json.loads((OUT/('runtime_'+suffix+'.json')).read_text(encoding='utf-8'))
    trace=json.loads((OUT/('telemetry_'+suffix+'.json')).read_text(encoding='utf-8'))
    assert report['all_gameplay_checks_passed']
    events=trace['events'];by_id={e['event_uuid']:e for e in events}
    assert [e['event_index'] for e in events]==list(range(len(events))) and len(by_id)==len(events)
    assert all(e['mission_id']=='MODULE_BAY_03_COOLANT_PRESSURE' and e['metadata']['configuration_id']==config for e in events)
    for e in events:
        cause=e['metadata'].get('cause_event_uuid')
        if cause:assert cause in by_id and by_id[cause]['event_index']<e['event_index']
        reversal=e['metadata'].get('reverses_action_uuid')
        if reversal:assert reversal in by_id and by_id[reversal]['event_index']<e['event_index']
    required={'coolant_valve_interaction','coolant_valve_changed','regulator_interaction','regulator_changed','bypass_interaction','bypass_changed','pressure_changed','coolant_flow_changed','scanner_scan_completed','help_requested','mission_completed'}
    assert required<={e['event_type'] for e in events}
    assert {1,2,3}<={e['metadata']['help_level'] for e in events if e['event_type']=='help_delivered'}
    assert any(e['metadata'].get('reverses_action_uuid') for e in events)
    assert any(e['metadata'].get('action_differs_from_last_negative') for e in events)
    if mode=='online':assert trace['completed'] and not trace['pending'] and not trace['quarantined']
    else:assert trace['pending'] and not trace['session_uuid']
    return report,trace
def offline(configs,stall=False):
    results={}
    for config in configs:
        traces={}
        for locale in ['tr','en']:
            game(config+'_'+locale,locale=locale,config=config)
            report,trace=verify_trace(config,locale,'offline');results[config+'_'+locale]=report;traces[locale]=trace
        # Keep UUID references canonical while comparing the same exploration inputs.
        def semantic(trace):
            filtered=dict(trace,events=[e for e in trace['events'] if not(e['event_type']=='help_salience_changed' and e['metadata']['reason']=='no_progress')])
            # Normalize event indices and UUID references after that optional timer observation.
            mapping={e['event_uuid']:i for i,e in enumerate(filtered['events'])}
            def clean(value):
                if isinstance(value,dict):return {k:clean(v) for k,v in value.items() if k not in ['locale','event_index','client_monotonic_ms','event_uuid']}
                if isinstance(value,list):return [clean(v) for v in value]
                if isinstance(value,str) and value in mapping:return {'event_position':mapping[value]}
                return value
            return clean(filtered['events'])
        left,right=semantic(traces['tr']),semantic(traces['en'])
        if left!=right:
            (OUT/('difference_'+config+'.json')).write_text(json.dumps({'tr':left,'en':right},indent=2));raise AssertionError('Locale semantics differ: '+config)
    return results
def online():
    with tempfile.TemporaryDirectory(prefix='mb03_api_') as directory:
        db=Path(directory)/'synthetic.db';sys.path.insert(0,str(prior.cascade.reference.BACKEND))
        import backend.main as main
        with patch.object(main,'DB_PATH',db):
            main.init_database()
            with main.database_connection() as connection:connection.execute("INSERT INTO students (id,student_code,first_name,last_name,grade) VALUES (1,'SYNTHETIC','Runtime','Fixture',7)")
        with socket.socket() as endpoint:endpoint.bind(('127.0.0.1',0));port=endpoint.getsockname()[1]
        with (OUT/'backend.log').open('w') as log:
            server=subprocess.Popen([sys.executable,'-B',str(ROOT/'verification/run_checks.py'),'--backend',str(db),str(port)],stdout=log,stderr=log,startupinfo=prior.cascade.reference.hidden())
            try:
                for _ in range(60):
                    try:prior.cascade.reference.json_request('http://127.0.0.1:%d/health'%port);break
                    except Exception:time.sleep(.2)
                api='http://127.0.0.1:%d/api/v2/research-station'%port
                game('C_en_online',config='C',api=api)
                report,trace=verify_trace('C','en','online')
                path=api+'/sessions/'+trace['session_uuid']+'/events:batch'
                assert prior.cascade.reference.json_request(path,{'events':[trace['events'][0]]})['results'][0]['status']=='already_accepted'
                assert prior.cascade.reference.json_request(path,{'events':[dict(trace['events'][0],metadata={'conflict_probe':True})]})['results'][0]['status']=='conflict'
                with closing(sqlite3.connect(db)) as connection:
                    count=connection.execute('SELECT count(*) FROM research_station_events').fetchone()[0];assert count==trace['acknowledged']==len(trace['events'])
                    assert connection.execute('SELECT session_purpose FROM research_station_sessions').fetchone()[0]=='intervention'
                return {'accepted_events':count,'synthetic_only':True,'replay_conflict_passed':True,'runtime':report}
            finally:server.terminate();server.wait(timeout=8)
def main():
    p=argparse.ArgumentParser();p.add_argument('--configs',default='A,B,C');p.add_argument('--stall',action='store_true');p.add_argument('--online',action='store_true');p.add_argument('--online-only',action='store_true');a=p.parse_args()
    baseline=prior.cascade.reference.protected();results={}
    if not a.online_only:results['offline']=offline(a.configs.split(','),a.stall)
    if a.stall:
        game('stall_A_en',config='A',stall=True)
        results['stall']=verify_trace('A','en','offline','_stall')[0]
    (OUT/'summary_coolant.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    if a.online or a.online_only:results['online']=online()
    assert prior.cascade.reference.protected()==baseline
    results['production_unchanged']=True;results['frozen_reference']=prior.cascade.frozen()
    (OUT/'summary_coolant.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8');print('MB03_CHECKS_PASS',flush=True)
if __name__=='__main__':main()
