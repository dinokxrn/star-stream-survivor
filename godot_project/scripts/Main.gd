extends Node

const SubwayStageScript = preload("res://scripts/world/SubwayStage.gd")
const AttributeRollScript = preload("res://scripts/ui/AttributeRollScreen.gd")
const HudOverlayScript = preload("res://scripts/ui/HudOverlay.gd")
const TouchControlsScript = preload("res://scripts/ui/TouchControls.gd")
const ModalsScript = preload("res://scripts/ui/ModalsController.gd")

var _viewport: SubViewport
var _view_rect: TextureRect
var _stage: Node2D = null
var _ui_layer: CanvasLayer
var _roll_screen: Control
var _hud: Control
var _touch_ui: Control
var _modals: Control
var _in_gameplay: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 480x270 crisp pixel-art SubViewport
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(480, 270)
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.snap_2d_vertices_to_pixel = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_viewport)

	# Full-screen TextureRect scaling 480x270 -> 1280x720 with Nearest filtering
	var world_layer := CanvasLayer.new()
	world_layer.layer = 0
	add_child(world_layer)

	_view_rect = TextureRect.new()
	_view_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_view_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view_rect.texture = _viewport.get_texture()
	world_layer.add_child(_view_rect)

	# HD 1280x720 Star Stream Thai UI Layer
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	_hud = Control.new()
	_hud.set_script(HudOverlayScript)
	_hud.visible = false
	_ui_layer.add_child(_hud)

	_touch_ui = Control.new()
	_touch_ui.set_script(TouchControlsScript)
	_touch_ui.visible = false
	_ui_layer.add_child(_touch_ui)

	_modals = Control.new()
	_modals.set_script(ModalsScript)
	_ui_layer.add_child(_modals)
	_modals.stat_upgraded.connect(_on_stat_upgraded)
	_modals.next_stage_requested.connect(_open_boon_before_next_stage)
	_modals.boon_picked_continue.connect(_advance_next_stage)
	_modals.restart_stage_requested.connect(_restart_current_stage)
	_modals.reroll_new_game_requested.connect(_show_roll_screen)

	_roll_screen = Control.new()
	_roll_screen.set_script(AttributeRollScript)
	_ui_layer.add_child(_roll_screen)
	_roll_screen.start_game_requested.connect(_start_run_with_attribute)
	_roll_screen.continue_save_requested.connect(_continue_from_save)

	ScenarioManager.scenario_condition_met.connect(_on_scenario_condition_met)
	ScenarioManager.scenario_exited.connect(_on_scenario_exited)
	ScenarioManager.scenario_failed.connect(_on_scenario_failed)
	NetworkManager.stage_start_received.connect(_on_net_stage_start)
	SfxManager.play_bgm("bgm_subway")


func _unhandled_key_input(event: InputEvent) -> void:
	if not _in_gameplay:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I:
			_modals.toggle_bag_window()
		elif event.physical_keycode == KEY_R and not _modals.is_modal_open():
			var wname := GameState.cycle_next_weapon()
			SfxManager.play("coin")
			if _stage != null and is_instance_valid(_stage) and _stage.player != null:
				_stage.player.spawn_floating_text("⚔ สลับอาวุธ: %s" % wname, Color(1.0, 0.88, 0.32))


func _process(delta: float) -> void:
	if not _in_gameplay:
		return
	if Input.is_action_just_pressed("toggle_status"):
		_modals.toggle_attribute_window()
	elif Input.is_action_just_pressed("toggle_shop"):
		_modals.toggle_shop_window()
	elif Input.is_action_just_pressed("exit_train") and ScenarioManager.is_farming and not _modals.is_modal_open():
		_modals.show_post_clear_choice()
	elif Input.is_action_just_pressed("ui_cancel") and _modals.is_modal_open():
		if _modals._active_kind in ["status", "shop", "bag", "bug_box"]:
			_modals.close_modal()

	if not get_tree().paused:
		ScenarioManager.tick(delta)


func _start_run_with_attribute(attr_id: String) -> void:
	_roll_screen.visible = false
	_hud.visible = true
	_touch_ui.visible = true
	_in_gameplay = true
	GameState.start_new_run(attr_id)
	if NetworkManager.is_online and NetworkManager.is_host:
		NetworkManager.send_stage_start(1)
	_start_stage(1)


func _on_net_stage_start(stage_num: int) -> void:
	if NetworkManager.is_host and _in_gameplay and ScenarioManager.current_stage == stage_num:
		return
	if not _in_gameplay:
		_roll_screen.visible = false
		_hud.visible = true
		_touch_ui.visible = true
		_in_gameplay = true
		var attr_id: String = _roll_screen.get_rolled_attribute_id() if _roll_screen.has_method("get_rolled_attribute_id") else GameState.current_attribute_id
		if attr_id == "":
			attr_id = "office_worker"
		GameState.start_new_run(attr_id)
	if _modals.is_modal_open():
		_modals.close_modal()
	_start_stage(stage_num)


func _continue_from_save() -> void:
	var saved_stage := GameState.load_game()
	if saved_stage <= 0:
		return
	_roll_screen.visible = false
	_hud.visible = true
	_touch_ui.visible = true
	_in_gameplay = true
	_start_stage(saved_stage)
	ScenarioManager.constellation_message.emit("[💾 โหลดเซฟสำเร็จ — กลับมาลุยบทละครที่ %d!]" % saved_stage, 0)


func _start_stage(stage_num: int) -> void:
	_hud.set_hazard_warning("")
	ScenarioManager.start_scenario(stage_num)
	GameState.save_game(stage_num)
	_load_stage(stage_num)
	_modals.show_scenario_intro(stage_num)


func _open_boon_before_next_stage() -> void:
	_modals.show_boon_selection()


func _advance_next_stage() -> void:
	var next_s := mini(4, ScenarioManager.current_stage + 1)
	if NetworkManager.is_online and NetworkManager.is_host:
		NetworkManager.send_stage_start(next_s)
	_start_stage(next_s)


func _restart_current_stage() -> void:
	if ScenarioManager.current_stage == 1:
		_start_run_with_attribute(GameState.current_attribute_id)
	else:
		_start_stage(ScenarioManager.current_stage)


func _show_roll_screen() -> void:
	_in_gameplay = false
	_hud.visible = false
	_touch_ui.visible = false
	_hud.set_hazard_warning("")
	_clear_stage()
	_roll_screen.visible = true
	_roll_screen._do_roll()
	_roll_screen.refresh_save_button()


func _clear_stage() -> void:
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
		_stage = null


func _load_stage(stage_num: int) -> void:
	_clear_stage()
	_stage = Node2D.new()
	_stage.set_script(SubwayStageScript)
	_viewport.add_child(_stage)
	_stage.build_stage(stage_num)
	_stage.request_bug_box_choice.connect(func(): _modals.show_bug_box_choice())
	_stage.hazard_status_changed.connect(func(txt: String): _hud.set_hazard_warning(txt))
	_stage.player_died_signal.connect(_on_local_player_died)
	_stage.apocalypse_dragon_killed_player.connect(func(reason: String): _on_scenario_failed(reason))


func _on_local_player_died() -> void:
	if NetworkManager.is_online and NetworkManager.room_players.size() > 1 and _stage != null and _stage.player != null:
		_stage.player.controls_locked = true
		_stage.player.spawn_floating_text("ล้มลง! รอเพื่อนชุบชีวิต [F] (หรือฟื้นใน 8 วิ)", Color(1.0, 0.55, 0.3))
		NetworkManager.send_toast("⚠ %s ล้มลง! เข้าไปใกล้แล้วกด [F] เพื่อชุบชีวิต!" % NetworkManager.player_name)
		var tw := create_tween()
		tw.tween_interval(8.0)
		tw.tween_callback(func():
			if _stage != null and is_instance_valid(_stage) and _stage.player != null and GameState.hp <= 0:
				_stage.player.revive_coop(0.50)
		)
		return
	_on_scenario_failed("คุณเสียชีวิตระหว่าง%s" % ScenarioManager.get_stage_title())


func _on_stat_upgraded() -> void:
	GameState.save_game(ScenarioManager.current_stage)
	if _stage != null and _stage.player != null:
		_stage.player.play_levelup_vfx()


func _on_scenario_condition_met(_path_type: String) -> void:
	SfxManager.play("levelup")
	_modals.show_sponsor_selection()


func _on_scenario_exited(_ending_type: String) -> void:
	SfxManager.play("levelup")
	_modals.show_result_modal(true, "")


func _on_scenario_failed(reason: String) -> void:
	SfxManager.play("hurt")
	_modals.show_result_modal(false, reason)
