"""Run the same physical intervention twice, select/switch via UI, compare raw semantics."""
from pathlib import Path
import hashlib, importlib.util, json, os, subprocess, sys
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'verification/localization'
spec=importlib.util.spec_from_file_location('cascade',ROOT/'verification/v02/run_cascade_checks.py')
cascade=importlib.util.module_from_spec(spec);spec.loader.exec_module(cascade)
def normalize(trace):
    events=trace['events']; indexes={e['event_uuid']:e['event_index'] for e in events}
    def clean(value):
        if isinstance(value,dict):return {k:clean(v) for k,v in value.items() if k not in ['locale']}
        if isinstance(value,list):return [clean(v) for v in value]
        if isinstance(value,str) and value in indexes:return {'event_index':indexes[value]}
        return value
    return [clean({k:v for k,v in e.items() if k not in ['client_monotonic_ms','event_uuid']}) for e in events]
def run():
    baseline=cascade.reference.protected()
    reports={};traces={}
    for locale in ['tr','en']:
        env=os.environ.copy();env['APPDATA']=str(OUT/'userdata');(OUT/'userdata').mkdir(exist_ok=True)
        args=[str(cascade.GODOT),'--path',str(ROOT),'--rendering-method','mobile','--rendering-driver','vulkan',
              '--log-file',str(OUT/(locale+'.log')),'res://scenes/main/power_coupling_cascade.tscn','--',
              '--verify-localization','--locale='+locale,'--progress-file=res://verification/localization/progress_'+locale+'.json','--api-base=http://127.0.0.1:1/api/v2/research-station']
        with (OUT/(locale+'.stdout')).open('w',encoding='utf-8') as out,(OUT/(locale+'.stderr')).open('w',encoding='utf-8') as err:
            p=subprocess.Popen(args,stdout=out,stderr=err,startupinfo=cascade.reference.hidden(),env=env)
            try:code=p.wait(timeout=120)
            except subprocess.TimeoutExpired:
                p.kill();p.wait();raise RuntimeError('Runtime timed out: '+locale)
        errors=(OUT/(locale+'.stderr')).read_text(encoding='utf-8')
        assert code==0 and not any(s in errors for s in ['SCRIPT ERROR','Parse Error','Missing localization','Failed loading']), (locale,code,errors,(OUT/(locale+'.stdout')).read_text(encoding='utf-8')[-3500:])
        reports[locale]=json.loads((OUT/('runtime_'+locale+'.json')).read_text(encoding='utf-8'))
        assert reports[locale]['all_gameplay_checks_passed']
        traces[locale]=json.loads((OUT/('telemetry_'+locale+'.json')).read_text(encoding='utf-8'))
        print(locale, 'PASS',len(traces[locale]['events']),'events',flush=True)
    left,right=normalize(traces['tr']),normalize(traces['en'])
    if left!=right:
        (OUT/'semantic_difference.json').write_text(json.dumps({'tr':left,'en':right},indent=2),encoding='utf-8')
        raise AssertionError('Locale changed event semantics; inspect semantic_difference.json')
    assert cascade.reference.protected()==baseline
    reference=cascade.frozen()
    old=json.loads((OUT/'before_files.json').read_text())
    protected=[name for name in old if not any(part in name.replace('\\','/') for part in ['scripts/intervention/','config/intervention_v02','scenes/intervention/'])]
    assert all(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==old[name] for name in protected)
    result={'tr_passed':True,'en_passed':True,'event_names_and_semantics_identical':True,
            'event_count_per_language':len(left),'locale_only_context':True,'production_unchanged':True,
            'reference':reference,'runtime_reports':reports}
    (OUT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print('BILINGUAL_RUNTIME_PASS',flush=True)
if __name__=='__main__':run()
