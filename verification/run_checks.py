"""Real GPU/input/raycast verification plus isolated actual FastAPI integration."""
import argparse, hashlib, json, os, socket, sqlite3, subprocess, sys, tempfile, time, urllib.request
from pathlib import Path
from contextlib import closing
ROOT=Path(__file__).resolve().parent.parent
BACKEND=ROOT.parent/"StudentPlanner"
GODOT=Path(r"C:\Users\DELL\Desktop\Alkın\Programlar Setup\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
def protected():
    with closing(sqlite3.connect((BACKEND/"data/studentplanner.db").as_uri()+"?mode=ro",uri=True)) as db:
        tables=[r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
        rows={t:hashlib.sha256(repr(db.execute('SELECT * FROM "'+t+'" ORDER BY rowid').fetchall()).encode()).hexdigest() for t in tables}
    return {"rows":rows,"hashes":{n:hashlib.sha256((BACKEND/"data"/n).read_bytes()).hexdigest() for n in ["studentplanner.db","studentplanner_backup.db"]}}
def hidden():
    info=subprocess.STARTUPINFO()
    info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    info.wShowWindow=0
    return info
def json_request(url,body=None):
    payload=None if body is None else json.dumps(body).encode()
    req=urllib.request.Request(url,payload,headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=4) as response:
        return json.load(response)
def backend(db,port):
    sys.path.insert(0,str(BACKEND))
    import backend.main as main
    import uvicorn
    main.DB_PATH=Path(db)
    uvicorn.run(main.app,host="127.0.0.1",port=int(port),log_level="warning")
def game(mode,api):
    log=ROOT/"verification"/("runtime_"+mode+".log")
    args=[str(GODOT),"--path",str(ROOT),"--rendering-method","mobile","--rendering-driver","vulkan",
          "--log-file",str(log),"--","--verify","--api-base="+api]
    with (ROOT/"verification"/(mode+".stdout")).open("w",encoding="utf-8") as out, (ROOT/"verification"/(mode+".stderr")).open("w",encoding="utf-8") as err:
        process=subprocess.Popen(args,stdout=out,stderr=err,startupinfo=hidden())
        try:
            deadline=time.monotonic()+55
            while process.poll() is None:
                time.sleep(.2)
                failure=(ROOT/'verification'/(mode+'.stderr')).read_text(encoding='utf-8',errors='replace')
                if 'SCRIPT ERROR' in failure or 'ERROR:' in failure:
                    process.kill(); process.wait()
                    raise RuntimeError(failure)
                if time.monotonic()>deadline: raise subprocess.TimeoutExpired(args,55)
            code=process.wait()
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()
            raise RuntimeError("GPU verification timed out; inspect "+str(log))
    print("GODOT_EXIT",mode,code)
    stdout=(ROOT/"verification"/(mode+".stdout")).read_text(encoding="utf-8")
    stderr=(ROOT/"verification"/(mode+".stderr")).read_text(encoding="utf-8")
    print(stdout[-6500:])
    print(stderr[-3500:])
    assert code==0,(mode,code)
    assert not any(marker in stderr for marker in ["SCRIPT ERROR","ERROR:"]),(mode,stderr)
    report=json.loads((ROOT/"verification"/("runtime_"+mode+".json")).read_text())
    assert report["all_gameplay_checks_passed"],report
    warning_lines=[line for line in stderr.splitlines() if "WARNING:" in line]
    assert warning_lines in ([], ['WARNING: 7 RIDs of type "Texture" were leaked.']),stderr
    report["shutdown"]={"exit_code":code,"warning_lines":warning_lines,"known_engine_reflection_atlas_warning":bool(warning_lines)}

    assert "Vulkan" in stdout and "Forward Mobile" in stdout and "AMD Radeon" in stdout
    trace=json.loads((ROOT/"verification"/("telemetry_"+mode+".json")).read_text())
    expected=["game_started","terminal_interaction","mission_started","object_grabbed",
              "object_rotated","placement_attempt","placement_invalid","object_rotated",
              "placement_attempt","placement_invalid","object_rotated","placement_attempt",
              "placement_valid","machine_activated","mission_completed"]
    assert [entry["event_type"] for entry in trace["events"]]==expected,trace
    assert [entry["event_index"] for entry in trace["events"]]==list(range(15))
    report["exact_behavior_sequence_verified"]=True

    if mode=="offline":
        assert trace["pending"] and not trace["session_uuid"],trace
    else:
        assert trace["completed"] and not trace["pending"] and not trace["quarantined"]
    return report,trace
def run(mode):
    baseline=protected()
    reports={}
    if mode in ("offline","both"):
        reports["offline"],_=game("offline","http://127.0.0.1:1/api/v2/research-station")
    if mode in ("online","both"):
        with tempfile.TemporaryDirectory(prefix="edualyn_rs_api_") as directory:
            db=Path(directory)/"isolated.db"
            # An explicit synthetic student, never a copy of private production data.
            sys.path.insert(0,str(BACKEND))
            import backend.main as main
            from unittest.mock import patch
            with patch.object(main,"DB_PATH",db):
                main.init_database()
                with main.database_connection() as connection:
                    connection.execute("INSERT INTO students (id,student_code,first_name,last_name,grade) VALUES (1,'SYNTHETIC','Runtime','Fixture',7)")
            with socket.socket() as endpoint:
                endpoint.bind(("127.0.0.1",0)); port=endpoint.getsockname()[1]
            with (ROOT/"verification/backend.log").open("w") as log:
                server=subprocess.Popen([sys.executable,"-B",str(Path(__file__)),"--backend",str(db),str(port)],stdout=log,stderr=log,startupinfo=hidden())
                try:
                    for attempt in range(50):
                        try:
                            json_request("http://127.0.0.1:%d/health"%port); break
                        except Exception:
                            if server.poll() is not None: raise RuntimeError("Isolated backend exited")
                            time.sleep(.2)
                    else: raise RuntimeError("Isolated backend did not become ready")
                    api="http://127.0.0.1:%d/api/v2/research-station"%port
                    reports["online"],trace=game("online",api)
                    sid=trace["session_uuid"]
                    replay=json_request(api+"/sessions/"+sid+"/events:batch",{"events":[trace["events"][0]]})
                    assert replay["results"][0]["status"]=="already_accepted",replay
                    conflicting=dict(trace["events"][0],metadata={"conflict_probe":True})
                    conflict=json_request(api+"/sessions/"+sid+"/events:batch",{"events":[conflicting]})
                    assert conflict["results"][0]["status"]=="conflict",conflict
                    with closing(sqlite3.connect(db)) as connection:
                        rows=connection.execute("SELECT event_uuid,event_type,event_index FROM research_station_events ORDER BY event_index").fetchall()
                        assert len(rows)==len(trace["events"])==trace["acknowledged"]
                        assert len({r[0] for r in rows})==len(rows)
                        assert [r[2] for r in rows]==list(range(len(rows)))
                        assert set(["game_started","terminal_interaction","mission_started","object_grabbed","object_rotated","placement_attempt","placement_invalid","placement_valid","machine_activated","mission_completed"]) <= {r[1] for r in rows}
                        assert connection.execute("SELECT count(*) FROM academic_records").fetchone()[0]==0
                    reports["api"]={"isolated_database":True,"event_count":len(rows),"replay":"already_accepted","conflict":"conflict","production_used":False}
                finally:
                    server.terminate()
                    try: server.wait(timeout=8)
                    except subprocess.TimeoutExpired: server.kill(); server.wait()
    assert protected()==baseline,"Production database or backup changed"
    reports["protected_databases_unchanged"]=True
    (ROOT/"verification/summary.json").write_text(json.dumps(reports,indent=2))
    print("VERIFICATION_SUMMARY",json.dumps(reports))
if __name__=="__main__":
    if len(sys.argv)>1 and sys.argv[1]=="--backend":
        backend(sys.argv[2],sys.argv[3])
    else:
        parser=argparse.ArgumentParser(); parser.add_argument("--mode",choices=["offline","online","both"],default="both")
        run(parser.parse_args().mode)
