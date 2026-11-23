"""GPU/input verification with actual FastAPI on a temporary synthetic database."""
from pathlib import Path
from contextlib import closing
from unittest.mock import patch
import argparse, hashlib, importlib.util, json, os, socket, sqlite3, subprocess, sys, tempfile, time, zipfile
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'verification/v02'
spec = importlib.util.spec_from_file_location('reference_verifier', ROOT/'verification/run_checks.py')
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)
GODOT = next(Path('C:/Users/DELL/Desktop').rglob('Godot_v4.7.2-stable_win64_console.exe'))
def game(mode, api):
    env = os.environ.copy()
    env['APPDATA'] = str(OUT/'userdata')
    (OUT/'userdata').mkdir(exist_ok=True)
    args = [str(GODOT), '--path', str(ROOT), '--rendering-method', 'mobile', '--rendering-driver', 'vulkan',
            '--log-file', str(OUT/(mode+'.log')), 'res://scenes/main/power_coupling_cascade.tscn',
            '--', '--verify', '--verify-v02', '--skip-language-selector', '--progress-file=res://verification/v02/progress_'+mode+'.json', '--api-base='+api]
    with (OUT/(mode+'.stdout')).open('w', encoding='utf-8') as out, (OUT/(mode+'.stderr')).open('w', encoding='utf-8') as err:
        process = subprocess.Popen(args, stdout=out, stderr=err, startupinfo=reference.hidden(), env=env)
        try:
            code = process.wait(timeout=150)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()
            raise RuntimeError('GPU verification timeout')
    errors = (OUT/(mode+'.stderr')).read_text(encoding='utf-8')
    # Certificate-store access is an environment error unrelated to localhost HTTP.
    assert not any(s in errors for s in ['SCRIPT ERROR', 'Parse Error', 'Failed loading', 'Error loading']), errors
    assert code == 0, (code, (OUT/(mode+'.stdout')).read_text(encoding='utf-8')[-6000:], errors)
    report = json.loads((OUT/('runtime_'+mode+'.json')).read_text())
    trace = json.loads((OUT/('telemetry_'+mode+'.json')).read_text())
    assert report['all_gameplay_checks_passed'], report
    events = trace['events']
    assert [e['event_index'] for e in events] == list(range(len(events)))
    assert len({e['event_uuid'] for e in events}) == len(events)
    assert all(e['mission_id']=='MODULE_BAY_01_POWER_COUPLING_CASCADE_V02' and e['metadata']['session_purpose']=='intervention' for e in events)
    required = {'cooling_regulator_interaction', 'cooling_regulator_changed', 'cooling_ready', 'relay_interaction',
                'relay_rejected', 'relay_activated', 'scanner_picked_up', 'scanner_scan_started', 'scanner_scan_completed',
                'subsystem_inspected', 'help_station_opened', 'help_requested', 'help_delivered', 'placement_attempt',
                'placement_invalid', 'placement_valid', 'machine_activated', 'mission_completed'}
    assert required <= {e['event_type'] for e in events}
    assert {1,2,3} <= {e['metadata']['help_level'] for e in events if e['event_type']=='help_delivered'}
    invalid_ids = {e['event_uuid'] for e in events if e['event_type'] in ['relay_rejected','placement_invalid']}
    assert all(e['metadata']['invalid_event_uuid'] in invalid_ids for e in events if e['event_type']=='invalid_action_observed')
    if mode == 'online':
        assert trace['completed'] and not trace['pending'] and not trace['quarantined']
    else:
        assert len(trace['pending'])==len(events) and not trace['completed']
    return report, trace
def frozen():
    manifest = json.loads((ROOT/'reference_builds/reference_v01_files.json').read_text())
    with zipfile.ZipFile(ROOT/'reference_builds/module_bay_01_reference_v0_1.zip') as archive:
        assert all(hashlib.sha256(archive.read(name)).hexdigest()==digest for name,digest in manifest.items())
    # The reference README was already updated to describe its archive before this session.
    baseline = json.loads((OUT/'session_baseline.json').read_text())
    changed = [name for name,digest in baseline.items() if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest]
    assert not changed, changed
    return {'archive_entries_verified': len(manifest), 'preexisting_reference_files_unchanged': True}
def free_game():
    env=os.environ.copy();env['APPDATA']=str(OUT/'userdata')
    args=[str(GODOT),'--path',str(ROOT),'--rendering-method','mobile','--rendering-driver','vulkan',
          '--log-file',str(OUT/'free.log'),'res://scenes/main/power_coupling_cascade.tscn','--',
          '--verify-free-v02','--skip-language-selector','--progress-file=res://verification/v02/progress_free.json','--api-base=http://127.0.0.1:1/api/v2/research-station']
    with (OUT/'free.stdout').open('w',encoding='utf-8') as out,(OUT/'free.stderr').open('w',encoding='utf-8') as err:
        process=subprocess.Popen(args,stdout=out,stderr=err,startupinfo=reference.hidden(),env=env)
        try: code=process.wait(timeout=35)
        except subprocess.TimeoutExpired:
            process.kill();process.wait();raise RuntimeError('Free interaction verification timeout')
    errors=(OUT/'free.stderr').read_text(encoding='utf-8')
    assert code==0 and not any(s in errors for s in ['SCRIPT ERROR','Parse Error','Failed loading']),errors
    report=json.loads((OUT/'runtime_free.json').read_text())
    assert report['all_gameplay_checks_passed'],report
    trace=json.loads((OUT/'telemetry_free.json').read_text())
    assert not any(e['event_type'] in ['terminal_interaction','help_requested'] for e in trace['events'])
    assert any(e['event_type']=='mission_completed' for e in trace['events'])
    return report
def run(mode):
    baseline = reference.protected()
    reports = {}
    if mode in ['offline','both']:
        reports['offline'], _ = game('offline','http://127.0.0.1:1/api/v2/research-station')
    if mode in ['online','both']:
        with tempfile.TemporaryDirectory(prefix='cascade_v02_') as directory:
            db = Path(directory)/'synthetic.db'
            sys.path.insert(0,str(reference.BACKEND))
            import backend.main as main
            with patch.object(main,'DB_PATH',db):
                main.init_database()
                with main.database_connection() as connection:
                    connection.execute("INSERT INTO students (id,student_code,first_name,last_name,grade) VALUES (1,'SYNTHETIC','Runtime','Fixture',7)")
            with socket.socket() as sock:
                sock.bind(('127.0.0.1',0)); port = sock.getsockname()[1]
            with (OUT/'backend.log').open('w') as log:
                server = subprocess.Popen([sys.executable,'-B',str(ROOT/'verification/run_checks.py'),'--backend',str(db),str(port)],stdout=log,stderr=log,startupinfo=reference.hidden())
                try:
                    for _ in range(60):
                        try:
                            reference.json_request('http://127.0.0.1:%d/health'%port); break
                        except Exception:
                            if server.poll() is not None: raise RuntimeError('Isolated backend exited')
                            time.sleep(.2)
                    else: raise RuntimeError('Isolated backend not ready')
                    api='http://127.0.0.1:%d/api/v2/research-station'%port
                    reports['online'],trace=game('online',api)
                    path=api+'/sessions/'+trace['session_uuid']+'/events:batch'
                    replay=reference.json_request(path,{'events':[trace['events'][0]]})
                    assert replay['results'][0]['status']=='already_accepted'
                    conflict=reference.json_request(path,{'events':[dict(trace['events'][0],metadata={'conflict_probe':True})]})
                    assert conflict['results'][0]['status']=='conflict'
                    with closing(sqlite3.connect(db)) as connection:
                        rows=connection.execute('SELECT event_uuid,event_type,event_index FROM research_station_events ORDER BY event_index').fetchall()
                        assert len(rows)==trace['acknowledged']==len(trace['events'])
                        assert [r[2] for r in rows]==list(range(len(rows)))
                        assert connection.execute('SELECT session_purpose FROM research_station_sessions').fetchone()[0]=='intervention'
                        assert connection.execute('SELECT count(*) FROM academic_records').fetchone()[0]==0
                    reports['api']={'synthetic_database_only':True,'accepted_events':len(rows),'idempotent_replay':True,'conflict_detected':True}
                finally:
                    server.terminate(); server.wait(timeout=8)
    reports['free_interaction']=free_game()
    assert reference.protected()==baseline, 'Production database changed'
    reports['production_unchanged']=True
    reports['frozen_reference']=frozen()
    (OUT/('summary_'+mode+'.json')).write_text(json.dumps(reports,indent=2))
    print(json.dumps(reports,indent=2))
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--mode',choices=['offline','online','both'],default='both')
    run(parser.parse_args().mode)
