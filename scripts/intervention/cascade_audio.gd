extends "res://scripts/audio/bay_audio.gd"
const EXTRA_CUES := ["valve", "flow", "relay_reject", "relay_engage", "scan_start", "scan_complete", "station_wake", "trace"]
func _ready() -> void:
	super._ready()
	if disabled_for_profile:
		return
	for cue in EXTRA_CUES:
		var stream := load("res://assets/audio/intervention_v02/" + cue + ".wav") as AudioStreamWAV
		assert(stream != null, "Missing original v0.2 cue")
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Audio_" + cue
		voice.stream = stream
		voice.bus = "StationSFX"
		voice.unit_size = 2
		voice.max_distance = 9
		voice.volume_db = -5
		voice.max_polyphony = 1
		add_child(voice)
		voices[cue] = voice
		cue_counts[cue] = 0
