extends Node

signal volume_changed(percent: int, muted: bool)

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_idx: int = 0
var _bgm_player: AudioStreamPlayer
var _bgm_streams: Dictionary = {}
var _current_bgm: String = ""
var bgm_muted: bool = false
var master_volume: float = 0.75 # 0.0 .. 1.0
var master_muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	for sfx_name in ["slash", "hit", "dash", "jump", "coin", "system", "skill", "levelup", "hurt"]:
		var stream := _load_wav("res://assets/sfx/%s.wav" % sfx_name, false)
		if stream != null:
			_streams[sfx_name] = stream

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -14.0
	add_child(_bgm_player)
	for track in ["bgm_subway", "bgm_battle", "bgm_boss"]:
		var bs := _load_wav("res://assets/sfx/%s.wav" % track, true)
		if bs != null:
			_bgm_streams[track] = bs
	_apply_master_volume()


func _apply_master_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, master_muted or master_volume <= 0.001)
		var db := linear_to_db(maxf(0.001, master_volume))
		AudioServer.set_bus_volume_db(bus, db)
	volume_changed.emit(get_volume_percent(), master_muted)


func get_volume_percent() -> int:
	return 0 if master_muted else int(round(master_volume * 100.0))


func change_volume(delta: float) -> void:
	master_muted = false
	master_volume = clampf(snappedf(master_volume + delta, 0.05), 0.0, 1.0)
	_apply_master_volume()


func toggle_master_mute() -> void:
	master_muted = not master_muted
	_apply_master_volume()


func _load_wav(res_path: String, looping: bool) -> AudioStream:
	var stream: AudioStream = null
	if ResourceLoader.exists(res_path):
		stream = load(res_path)
	if stream == null and FileAccess.file_exists(res_path):
		var bytes := FileAccess.get_file_as_bytes(res_path)
		if bytes.size() > 44:
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_16_BITS
			wav.mix_rate = 22050
			wav.stereo = false
			wav.data = bytes.slice(44)
			stream = wav
	if stream == null:
		var abs_path := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var bytes2 := FileAccess.get_file_as_bytes(abs_path)
			if bytes2.size() > 44:
				var wav2 := AudioStreamWAV.new()
				wav2.format = AudioStreamWAV.FORMAT_16_BITS
				wav2.mix_rate = 22050
				wav2.stereo = false
				wav2.data = bytes2.slice(44)
				stream = wav2
	if looping and stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.data.size() / 2)
	return stream


func play_bgm(track_name: String) -> void:
	if _current_bgm == track_name and _bgm_player.playing:
		return
	if not _bgm_streams.has(track_name):
		return
	_current_bgm = track_name
	_bgm_player.stream = _bgm_streams[track_name]
	if not bgm_muted:
		_bgm_player.play()


func toggle_bgm_mute() -> void:
	bgm_muted = not bgm_muted
	if bgm_muted:
		_bgm_player.stop()
	elif _current_bgm != "":
		_bgm_player.play()


func play(sfx_name: String, pitch_jitter: float = 0.08) -> void:
	if not _streams.has(sfx_name):
		return
	var p := _players[_next_idx]
	_next_idx = (_next_idx + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()
