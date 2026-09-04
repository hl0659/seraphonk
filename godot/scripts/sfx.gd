extends Node
## Procedural SFX synth — no audio files needed. Tiny sine/noise blips via AudioStreamWAV.
var players: Array = []
var idx := 0
var last_play := {}

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)

func _tone(f0: float, f1: float, dur: float, vol: float, noise: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(f0, f1, t)
		phase += TAU * f / float(rate)
		var env := sin(PI * minf(1.0, t * 1.15)) * (1.0 - t * 0.6)
		var s := sin(phase) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func play(name: String) -> void:
	# throttle spammy sounds (survivors shoot a lot)
	var now := Time.get_ticks_msec()
	if last_play.get(name, -1000) + (120 if name in ["shoot", "hit"] else 40) > now:
		return
	last_play[name] = now
	var s: AudioStreamWAV
	match name:
		"shoot": s = _tone(880, 660, 0.08, 0.25, 0.1)
		"hit": s = _tone(220, 110, 0.1, 0.4, 0.35)
		"pickup": s = _tone(660, 1320, 0.09, 0.3, 0.0)
		"levelup": s = _tone(440, 1760, 0.35, 0.4, 0.0)
		"dash": s = _tone(300, 900, 0.14, 0.3, 0.5)
		"slam": s = _tone(120, 40, 0.3, 0.6, 0.4)
		"chest": s = _tone(520, 1560, 0.25, 0.4, 0.05)
		"shrine": s = _tone(392, 1175, 0.4, 0.4, 0.0)
		"boss": s = _tone(98, 65, 0.7, 0.6, 0.3)
		"evolve": s = _tone(523, 2093, 0.6, 0.45, 0.0)
		"die": s = _tone(330, 82, 0.5, 0.5, 0.2)
		_: return
	var p: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	p.stream = s
	p.pitch_scale = randf_range(0.94, 1.06) if name in ["shoot", "hit", "pickup"] else 1.0
	p.play()
