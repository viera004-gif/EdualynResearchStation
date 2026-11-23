"""Controlled same-GPU tests: no screenshots/HUD in minimal cases."""
import importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location("rs_checks",ROOT/"verification/run_checks.py")
checks=importlib.util.module_from_spec(spec);spec.loader.exec_module(checks)
results={}
outdir=ROOT/"verification/phase1b";outdir.mkdir(exist_ok=True)
for mode in ["minimal_no_probe","minimal_probe","full_no_capture","full_early_cleanup"]:
    args=[str(checks.GODOT),"--path",str(ROOT),"--rendering-method","mobile","--rendering-driver","vulkan",
          "--script","res://verification/rid_diagnostic.gd","--","--rid-case="+mode,
          "--api-base=http://127.0.0.1:1/api/v2/research-station"]
    result=subprocess.run(args,capture_output=True,text=True,timeout=40,startupinfo=checks.hidden())
    (outdir/(mode+".stdout")).write_text(result.stdout,encoding="utf-8")
    (outdir/(mode+".stderr")).write_text(result.stderr,encoding="utf-8")
    results[mode]={"exit":result.returncode,"stderr":result.stderr,"done":"RID_DIAGNOSTIC_DONE" in result.stdout}
    print(mode,result.returncode,result.stderr.strip(),flush=True)
    assert result.returncode==0 and results[mode]["done"]
(outdir/"rid_diagnostic.json").write_text(json.dumps(results,indent=2))
