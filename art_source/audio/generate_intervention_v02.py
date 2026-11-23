"""Original deterministic procedural industrial cues; no samples or external assets."""
from pathlib import Path
import json, math, random, struct, wave, hashlib
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/intervention_v02'
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cues = {'valve': (180, .6), 'flow': (95, 1.6), 'relay_reject': (110, .3),
            'relay_engage': (240, .4), 'scan_start': (570, .45),
            'scan_complete': (780, .4), 'station_wake': (360, .7), 'trace': (470, .5)}
    manifest = {}
    for index, (name, (frequency, duration)) in enumerate(cues.items()):
        rng = random.Random(20261112 + index)
        samples = []
        low_noise = 0.0
        for i in range(int(48000 * duration)):
            t = i / 48000
            envelope = min(1, t / .025) * min(1, (duration - t) / .09)
            low_noise = .94 * low_noise + .06 * rng.uniform(-1, 1)
            sweep = 35 if name.startswith('scan') else -12
            tone = math.sin(2 * math.pi * (frequency*t + sweep*t*t))
            pulse = math.exp(-t*12) * math.sin(2*math.pi*1350*t)
            sample = envelope * (.11*tone + .1*low_noise + .045*pulse)
            samples.append(struct.pack('<h', int(sample * 32767)))
        path = OUT / (name + '.wav')
        with wave.open(str(path), 'wb') as stream:
            stream.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
            stream.writeframes(b''.join(samples))
        manifest[name] = {'duration_seconds': duration, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    (OUT / 'audio_manifest.json').write_text(json.dumps({'provenance': 'Original mathematical synthesis; no third-party samples', 'generator': 'art_source/audio/generate_intervention_v02.py', 'cues': manifest}, indent=2))
if __name__ == '__main__':
    main()
