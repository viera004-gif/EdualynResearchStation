extends Node3D
const CUES := ["terminal", "pickup", "rotate", "invalid", "lock", "startup", "hum"]
var voices: Dictionary = {}
var cue_counts: Dictionary = {}
var owned_bus: bool = false
var bus_index: int = -1
var capture: AudioEffectCapture
var mixed_peak: float = 0.0
var captured_frames: int = 0
var nonzero_frames: int = 0
var hum_started: bool = false
var disabled_for_profile: bool = false
func _ready() -> void:
	if "--profile-without-audio" in OS.get_cmdline_user_args():
		disabled_for_profile = true
		set_process(false)
		return
	bus_index = AudioServer.get_bus_index("StationSFX")
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, "StationSFX")
		owned_bus = true
	AudioServer.set_bus_volume_db(bus_index, -7)
	for cue in CUES:
		var stream := load("res://assets/audio/" + cue + ".wav") as AudioStreamWAV
		assert(stream != null, "Missing original audio cue: " + cue)
		if cue == "hum":
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Audio_" + cue
		voice.stream = stream
		voice.bus = "StationSFX"
		voice.unit_size = 2
		voice.max_distance = 9
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.volume_db = -10 if cue == "hum" else -3
		voice.max_polyphony = 1
		add_child(voice)
		voices[cue] = voice
		cue_counts[cue] = 0
	if "--verify" in OS.get_cmdline_user_args():
		capture = AudioEffectCapture.new()
		capture.buffer_length = .5
		AudioServer.add_bus_effect(bus_index, capture)
func play_cue(cue: String, at: Vector3) -> void:
	if disabled_for_profile or not voices.has(cue):
		return
	var voice: AudioStreamPlayer3D = voices[cue]
	voice.global_position = at
	voice.play()
	cue_counts[cue] += 1
func start_hum(at: Vector3) -> void:
	if disabled_for_profile or hum_started:
		return
	hum_started = true
	var voice: AudioStreamPlayer3D = voices["hum"]
	voice.volume_db = -40
	play_cue("hum", at)
	create_tween().tween_property(voice, "volume_db", -10.0, .6)
func _process(_delta: float) -> void:
	if capture == null:
		return
	var count := capture.get_frames_available()
	if count == 0:
		return
	var frames := capture.get_buffer(count)
	for sample in frames:
		var amplitude := maxf(absf(sample.x), absf(sample.y))
		mixed_peak = maxf(mixed_peak, amplitude)
		if amplitude > .000001:
			nonzero_frames += 1
	captured_frames += frames.size()
func report() -> Dictionary:
	return {"cue_counts": cue_counts.duplicate(), "captured_frames": captured_frames,
		"nonzero_frames": nonzero_frames, "bus_peak_linear": mixed_peak,
		"bus_peak_db": linear_to_db(maxf(mixed_peak, .000001)), "driver": AudioServer.get_driver_name(),
		"hum_playing": (voices["hum"] as AudioStreamPlayer3D).playing,
		"hum_loop_frames": (voices["hum"] as AudioStreamPlayer3D).stream.loop_end,
		"hum_duration_seconds": (voices["hum"] as AudioStreamPlayer3D).stream.get_length()}
func _exit_tree() -> void:
	for voice in voices.values():
		voice.stop()
	if owned_bus and AudioServer.get_bus_index("StationSFX") >= 0:
		AudioServer.remove_bus(AudioServer.get_bus_index("StationSFX"))
	capture = null
