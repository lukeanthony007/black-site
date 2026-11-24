extends Node
## Tiny procedural SFX so the slice has audio without asset packs.

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)


func play_gunshot() -> void:
	_play_tone(180.0, 0.06, 0.35, true)


func play_silenced() -> void:
	_play_tone(240.0, 0.035, 0.12, true)


func play_impact() -> void:
	_play_tone(90.0, 0.04, 0.2, true)


func play_pickup() -> void:
	_play_tone(520.0, 0.08, 0.18, false)


func play_interact() -> void:
	_play_tone(340.0, 0.1, 0.2, false)


func play_hurt() -> void:
	_play_tone(120.0, 0.12, 0.3, true)


func play_footstep() -> void:
	_play_tone(70.0, 0.03, 0.08, true)


func _play_tone(freq: float, duration: float, volume: float, noise: bool) -> void:
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 4)
	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var envelope := 1.0 - (t / duration)
		var sample := 0.0
		if noise:
			sample = (randf() * 2.0 - 1.0) * envelope * volume
			sample += sin(TAU * freq * t) * envelope * volume * 0.35
		else:
			sample = sin(TAU * freq * t) * envelope * volume
		var s := int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 4, s)
		bytes.encode_s16(i * 4 + 2, s)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = true
	stream.data = bytes
	if _player.playing:
		_player.stop()
	_player.stream = stream
	_player.play()


func _exit_tree() -> void:
	if _player:
		_player.stop()
		_player.stream = null
