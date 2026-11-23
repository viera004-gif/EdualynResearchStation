"""Original deterministic industrial cues; standard-library synthesis, no third-party recordings."""
import array, json, math, random, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/audio"
OUT.mkdir(exist_ok=True)
RATE=48000
rng=random.Random(1901)
def sound(name,seconds,function,loop=False):
    count=round(seconds*RATE)
    data=array.array('h')
    peak=0
    for i in range(count):
        t=i/RATE
        envelope=1 if loop else min(1,t/.008)*min(1,(seconds-t)/.03)
        value=max(-.7,min(.7,function(t)*envelope))
        peak=max(peak,abs(value))
        data.append(round(value*32767))
    with wave.open(str(OUT/(name+".wav")),"wb") as file:
        file.setnchannels(1);file.setsampwidth(2);file.setframerate(RATE);file.writeframes(data.tobytes())
    return {"seconds":seconds,"sample_rate":RATE,"channels":1,"peak_linear":peak,"loop":loop}
def tap(t,freq,decay=25):
    return math.sin(math.tau*freq*t)*math.exp(-decay*t)
spec={}
spec["terminal"]=sound("terminal",.34,lambda t:.16*tap(t,620,12)+.065*tap(max(0,t-.10),930,20)*(t>.10))
spec["pickup"]=sound("pickup",.22,lambda t:.20*tap(t,145,27)+.045*rng.uniform(-1,1)*math.exp(-35*t))
spec["rotate"]=sound("rotate",.14,lambda t:.10*tap(t,230,40)+.028*rng.uniform(-1,1)*math.exp(-55*t))
spec["invalid"]=sound("invalid",.34,lambda t:.13*tap(t,155,11)+.055*tap(t,205,16))
spec["lock"]=sound("lock",.38,lambda t:.23*tap(t,95,22)+.06*rng.uniform(-1,1)*math.exp(-38*t)+.06*tap(max(0,t-.10),280,28)*(t>.10))
spec["startup"]=sound("startup",2.4,lambda t:(.06+.04*t/2.4)*math.sin(math.tau*(48*t+22*t*t))+.04*math.sin(math.tau*(96*t+44*t*t))+.04*tap(max(0,t-.12),120,28)*(t>.12))
spec["hum"]=sound("hum",2,lambda t:(.105*math.sin(math.tau*50*t)+.034*math.sin(math.tau*100*t)+.017*math.sin(math.tau*150*t))*(.94+.06*math.cos(math.tau*.5*t)),True)
(ROOT/"assets/audio/audio_manifest.json").write_text(json.dumps({"license":"Original programmatic synthesis for this project; no commercial samples","generator":"art_source/audio/generate_audio.py","cues":spec},indent=2))
print("AUDIO_GENERATED",json.dumps(spec))
