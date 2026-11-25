extends Node

const SERVER_WS_BASE: String = "wss://star-stream-coop.dinokorn-game.workers.dev/room/"

signal room_joined(room_code: String, peer_id: String, is_host_flag: bool)
signal room_updated(players: Array, host_id: String, started: bool, stage_num: int)
signal room_disconnected(reason: String)
signal room_error(message: String)
signal stage_start_received(stage_num: int)
signal peer_state_received(data: Dictionary)
signal peer_fx_received(data: Dictionary)
signal enemy_hit_received(data: Dictionary)
signal enemy_sync_received(enemies: Array)
signal player_hit_received(data: Dictionary)
signal scenario_sync_received(data: Dictionary)
signal revive_received(from_peer: String, target_peer: String)
signal toast_received(text: String)

var _ws: WebSocketPeer = null
var _was_open: bool = false
var _ping_timer: float = 0.0

var is_online: bool = false
var is_connecting: bool = false
var is_host: bool = false
var my_peer_id: String = ""
var host_id: String = ""
var room_code: String = ""
var player_name: String = "ผู้รอดชีวิต"
var room_players: Array = []
var room_started: bool = false
var room_stage: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func generate_room_code() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var out := ""
	for _i in 4:
		out += chars[randi() % chars.length()]
	return out


func connect_room(code: String, p_name: String, char_idx: int, attr_id: String) -> void:
	disconnect_room()
	var clean_code := code.strip_edges().to_upper()
	if clean_code.length() < 2:
		room_error.emit("กรุณากรอกรหัสห้อง 4 หลัก")
		return
	room_code = clean_code
	player_name = p_name.strip_edges()
	if player_name == "":
		player_name = "ผู้รอดชีวิต"

	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 262144
	_ws.outbound_buffer_size = 262144
	var url := "%s%s?room=%s&name=%s&char=%d&attr=%s" % [
		SERVER_WS_BASE,
		clean_code.uri_encode(),
		clean_code.uri_encode(),
		player_name.uri_encode(),
		char_idx,
		attr_id.uri_encode(),
	]
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		room_error.emit("เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ (err %d)" % err)
		return
	is_connecting = true
	_was_open = false
	_ping_timer = 0.0


func disconnect_room() -> void:
	if _ws != null:
		_ws.close()
		_ws = null
	var was_active := is_online or is_connecting
	is_online = false
	is_connecting = false
	is_host = false
	_was_open = false
	my_peer_id = ""
	host_id = ""
	room_code = ""
	room_players.clear()
	room_started = false
	room_stage = 1
	if was_active:
		room_disconnected.emit("ออกจากห้องแล้ว")


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		_was_open = true
		is_connecting = false
		_ping_timer += delta
		if _ping_timer >= 15.0:
			_ping_timer = 0.0
			_send_json({"type": "ping", "t": Time.get_ticks_msec()})
		while _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet()
			var txt := pkt.get_string_from_utf8()
			_handle_message(txt)
	elif st == WebSocketPeer.STATE_CLOSED:
		var reason := "หลุดการเชื่อมต่อจากห้อง" if _was_open else "เข้าห้องไม่สำเร็จ (ห้องอาจเต็ม 4/4 หรือเน็ตหลุด)"
		_ws = null
		is_online = false
		is_connecting = false
		is_host = false
		_was_open = false
		my_peer_id = ""
		host_id = ""
		room_players.clear()
		room_disconnected.emit(reason)
		room_error.emit(reason)


func _send_json(payload: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify(payload))


func _handle_message(txt: String) -> void:
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return
	var msg: Dictionary = parsed
	var t := String(msg.get("type", ""))
	match t:
		"welcome":
			is_online = true
			is_connecting = false
			my_peer_id = String(msg.get("peer_id", ""))
			host_id = String(msg.get("host_id", ""))
			room_code = String(msg.get("room_code", room_code))
			room_stage = int(msg.get("stage", 1))
			room_started = bool(msg.get("started", false))
			is_host = (my_peer_id != "" and my_peer_id == host_id)
			var pl: Variant = msg.get("players", [])
			room_players = pl if pl is Array else []
			room_joined.emit(room_code, my_peer_id, is_host)
			room_updated.emit(room_players, host_id, room_started, room_stage)
		"room_update":
			host_id = String(msg.get("host_id", host_id))
			room_stage = int(msg.get("stage", room_stage))
			room_started = bool(msg.get("started", room_started))
			is_host = (my_peer_id != "" and my_peer_id == host_id)
			var pl2: Variant = msg.get("players", [])
			room_players = pl2 if pl2 is Array else []
			room_updated.emit(room_players, host_id, room_started, room_stage)
			var ev := String(msg.get("event", ""))
			var actor := String(msg.get("actor_name", ""))
			if ev == "join" and actor != "":
				toast_received.emit("🌐 %s เข้าร่วมห้อง Co-op!" % actor)
			elif ev == "leave" and actor != "":
				toast_received.emit("🌐 %s ออกจากห้องแล้ว" % actor)
		"stage_start":
			room_started = true
			room_stage = int(msg.get("stage", 1))
			var pl3: Variant = msg.get("players", [])
			if pl3 is Array and pl3.size() > 0:
				room_players = pl3
			stage_start_received.emit(room_stage)
		"player_state":
			peer_state_received.emit(msg)
		"player_fx":
			peer_fx_received.emit(msg)
		"enemy_hit":
			enemy_hit_received.emit(msg)
		"enemy_sync":
			var arr: Variant = msg.get("enemies", [])
			if arr is Array:
				enemy_sync_received.emit(arr)
		"player_hit":
			player_hit_received.emit(msg)
		"scenario_sync":
			scenario_sync_received.emit(msg)
		"revive":
			revive_received.emit(String(msg.get("peer_id", "")), String(msg.get("target_peer", "")))
		"chat_toast":
			toast_received.emit(String(msg.get("text", "")))


func send_profile_update(p_name: String, char_idx: int, attr_id: String) -> void:
	if not is_online:
		return
	player_name = p_name.strip_edges()
	if player_name == "":
		player_name = "ผู้รอดชีวิต"
	_send_json({
		"type": "profile_update",
		"name": player_name,
		"char_idx": char_idx,
		"attr_id": attr_id,
	})


func send_stage_start(stage_num: int) -> void:
	if not is_online or not is_host:
		return
	room_started = true
	room_stage = stage_num
	_send_json({"type": "stage_start", "stage": stage_num})


func send_player_state(pos: Vector2, vel: Vector2, facing: int, anim: String, hp: int, max_hp: int, dashing: bool, parrying: bool) -> void:
	if not is_online:
		return
	_send_json({
		"type": "player_state",
		"x": snappedf(pos.x, 0.5),
		"y": snappedf(pos.y, 0.5),
		"vx": snappedf(vel.x, 1.0),
		"vy": snappedf(vel.y, 1.0),
		"facing": facing,
		"anim": anim,
		"hp": hp,
		"max_hp": max_hp,
		"dashing": dashing,
		"parrying": parrying,
	})


func send_player_fx(vfx_name: String, pos: Vector2, facing: int, scale_val: float = 1.0) -> void:
	if not is_online:
		return
	_send_json({
		"type": "player_fx",
		"vfx": vfx_name,
		"x": snappedf(pos.x, 0.5),
		"y": snappedf(pos.y, 0.5),
		"facing": facing,
		"scale": scale_val,
	})


func send_enemy_hit(eid: String, dmg: int, knock_x: float = 0.0, stun: float = 0.0) -> void:
	if not is_online or eid == "":
		return
	_send_json({
		"type": "enemy_hit",
		"eid": eid,
		"dmg": dmg,
		"knock_x": snappedf(knock_x, 1.0),
		"stun": snappedf(stun, 0.05),
	})


func send_enemy_sync(enemies_arr: Array) -> void:
	if not is_online or not is_host:
		return
	_send_json({"type": "enemy_sync", "enemies": enemies_arr})


func send_player_hit(target_peer: String, dmg: int, knock_x: float, unparryable: bool = false) -> void:
	if not is_online or not is_host or target_peer == "":
		return
	_send_json({
		"type": "player_hit",
		"target_peer": target_peer,
		"dmg": dmg,
		"knock_x": snappedf(knock_x, 1.0),
		"unparryable": unparryable,
	})


func send_scenario_sync_dict(payload: Dictionary) -> void:
	if not is_online or not is_host:
		return
	var msg := payload.duplicate()
	msg["type"] = "scenario_sync"
	_send_json(msg)


func send_scenario_sync(stage_num: int, kills: int, target_kills: int, cleared: bool) -> void:
	if not is_online or not is_host:
		return
	_send_json({
		"type": "scenario_sync",
		"stage": stage_num,
		"kills": kills,
		"target_kills": target_kills,
		"cleared": cleared,
	})


func send_revive(target_peer: String) -> void:
	if not is_online:
		return
	_send_json({"type": "revive", "target_peer": target_peer})


func send_toast(text: String) -> void:
	if not is_online:
		return
	_send_json({"type": "chat_toast", "text": text})
