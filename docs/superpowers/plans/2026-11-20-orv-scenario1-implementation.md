# Star Stream: Side-Car Survivor (Scenario #1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete, playable Godot 4.7.2 2D side-scrolling pixel-art action RPG implementing *Omniscient Reader's Viewpoint* Main Scenario #1 ("Proof of Value" across 3 subway cars) with randomized Personal Attributes, coin-based stat upgrades, Dokkaebi Bag shop, Constellation sponsorship & selection, and exported `patch-gg/pixelfx` sprite-sheet VFX.

**Architecture:** Hybrid rendering root (`Main.tscn`) combines a `480x270` pixel-art `SubViewport` (`TEXTURE_FILTER_NEAREST`) for world, characters, and `pixelfx` effects with a `1280x720` HD `CanvasLayer` (`canvas_items` stretch) for crisp Thai Star Stream UI. Core state lives in four Autoload singletons (`GameState`, `ScenarioManager`, `VfxManager`, `SfxManager`) backed by pure data tables (`GameData.gd`), enabling deterministic headless GDScript unit tests via `godot --headless --script`.

**Tech Stack:** Godot `4.7.2.stable` (GDScript), Node `v22` (`patch-gg/pixelfx` sprite sheet renderer + procedural pixel-art PNG generator), macOS Thai TTF fonts (`Tahoma.ttf`, `Tahoma Bold.ttf`).

**Spec:** `/Users/mac/Desktop/GAME_Project/docs/superpowers/specs/2026-11-20-orv-sidecar-survivor-design.md`

## Global Constraints

- Engine: Godot `4.7.2.stable` (GDScript) in `/Users/mac/Desktop/GAME_Project/godot_project/`.
- Hybrid viewport: `1280x720` (`canvas_items`, `keep`) for HD Thai UI; `480x270` `SubViewport` with `TEXTURE_FILTER_NEAREST` for all gameplay/VFX.
- All player-facing copy, Star Stream windows, and Constellation messages are in **Thai (ภาษาไทย)** using bundled `res://assets/fonts/Tahoma.ttf` and `Tahoma Bold.ttf`.
- VFX must come from `patch-gg/pixelfx` cloned at `/Users/mac/Desktop/GAME_Project/tools/pixelfx` and exported via `node tools/render.mjs <id> --sheet` into `godot_project/assets/vfx/`.
- No copyrighted ORV art/logos; all character and environment sprites are original shaded pixel art PNGs.
- All 5 ORV pillars required: Randomized Personal Attributes (Common/Rare/Hero with reroll), Coin stat upgrades (`100 * level` for STR/PHY/AGI/MAG), Skills (`1/2/3`), Items & Dokkaebi Bag (`B`), Main/Sub/Hidden Scenarios + Sponsor Selection finale.

## Review Focus

- **Coin upgrade edge cases:** Attempting to upgrade STR/PHY/AGI/MAG with insufficient coins must not deduct coins or increment level; upgrading PHY/MAG must increase MaxHP/MaxMP and preserve/heal proportional delta cleanly.
- **Pause/Modal input isolation:** Opening Attribute Window (`Tab`), Dokkaebi Bag (`B`), or Sponsor Selection must pause combat, scenario countdown timer, and enemy AI while still allowing UI clicks/close keys.
- **Dual-path Scenario #1 completion:** Clearing via Hidden Scenario (bug box in Car 3) vs. combat (defeating an enemy/mini-boss) must never double-trigger rewards or leave the 180s timer running into Sponsor Selection.
- **Perfect Dodge & i-frame boundaries:** Dashing through an active enemy hitbox grants i-frames (no damage taken) and triggers Perfect Dodge sponsor coins at most once per cooldown window (no infinite coin farming).
- **Thai font & nearest-neighbor integrity:** `project.godot` must enforce `TEXTURE_FILTER_NEAREST` default while UI theme explicitly loads `Tahoma.ttf` so Thai vowels/tone marks render without missing glyphs or blur.

---

## File Structure

- `tools/pixelfx/` — Cloned `patch-gg/pixelfx` repo (outside `godot_project/`).
- `tools/export_vfx.mjs` — Script invoking `pixelfx/tools/render.mjs --sheet` for all game VFX and copying PNG+JSON to `godot_project/assets/vfx/`.
- `tools/gen_sprites.mjs` — Zero-dependency Node PNG generator producing shaded pixel-art sprite sheets (player, enemies, mini-boss, Dokkaebi, NPC, bug box, subway tiles/props) and retro WAV SFX (`tools/gen_sfx.mjs`).
- `godot_project/project.godot` — Godot 4.7.2 config, InputMap, Autoloads, display settings.
- `godot_project/scripts/data/GameData.gd` — Pure `class_name GameData` definitions: 5 Personal Attributes, 5 Weapons, 4 Consumables, 4 Skills, 4 Sponsor paths, Scenario #1 constants.
- `godot_project/scripts/autoload/GameState.gd` — Player runtime state, attribute roll, stat formulas, coin upgrade, inventory, quick-slots, skill cooldowns, signals.
- `godot_project/scripts/autoload/ScenarioManager.gd` — Main Scenario #1 timer/state, Sub-Scenario rescue, Hidden Scenario bug-box, Constellation live feed & sponsor coin rewards.
- `godot_project/scripts/autoload/VfxManager.gd` — Loads `pixelfx` PNG+JSON sheets into cached `SpriteFrames` and spawns positioned/flipped `AnimatedSprite2D` instances with `meta.pixelfx.pivot`.
- `godot_project/scripts/autoload/SfxManager.gd` — Plays procedural retro WAV sound effects.
- `godot_project/scripts/entities/Player.gd` + `scenes/entities/Player.tscn` — Side-scrolling player with walk, jump (coyote/buffer), dash (i-frames + Perfect Dodge), 3-hit combo, skills `1/2/3`, quick-items `Q/E`, hit-stop.
- `godot_project/scripts/entities/Enemy.gd` + `scenes/entities/Enemy.tscn` — Parameterized enemy (`frenzy`, `charger`, `boss`) with telegraph, attack hitbox, knockback, coin drop.
- `godot_project/scripts/world/Interactable.gd` + `scenes/world/Interactable.tscn` — Prompted `F` interactables (weapon pickup, Car 2 trapped NPC, Car 3 kid's backpack/bug box).
- `godot_project/scripts/world/SubwayStage.gd` + `scenes/world/SubwayStage.tscn` — 3 connected subway cars (~1,600 px), obstacles, flickering lights, Dokkaebi intro sequence, enemy/NPC spawns.
- `godot_project/scripts/ui/` + `scenes/ui/` — `AttributeRollScreen`, `HudOverlay`, `AttributeWindow`, `DokkaebiBagModal`, `SponsorModal`, `ResultModal`, `StarStreamPopup`.
- `godot_project/scenes/Main.tscn` + `scripts/Main.gd` — Hybrid `SubViewportContainer` (480x270) + HD `CanvasLayer` (1280x720) orchestrator.
- `godot_project/tests/test_core_systems.gd` — Headless `SceneTree` test suite verifying GameState, ScenarioManager, VfxManager, and edge cases.

---

### Task 1: Godot Project Scaffold, Thai Fonts & `pixelfx` VFX Export Pipeline

**Files:**
- Create: `godot_project/project.godot`
- Create: `godot_project/assets/fonts/Tahoma.ttf` & `Tahoma Bold.ttf` (copied from macOS `/System/Library/Fonts/Supplemental/`)
- Create: `tools/export_vfx.mjs`
- Create: `godot_project/assets/vfx/<effect>/<effect>.png` & `.json`
- Create: `godot_project/scripts/autoload/VfxManager.gd`
- Create: `godot_project/scripts/autoload/SfxManager.gd`
- Create: `tools/gen_sfx.mjs`

**Interfaces:**
- Produces:
  - `VfxManager.spawn_vfx(vfx_name: String, parent: Node2D, pos: Vector2, flip_h: bool = false, scale_mult: float = 1.0) -> AnimatedSprite2D`
  - `VfxManager.has_vfx(vfx_name: String) -> bool`
  - `SfxManager.play(sfx_name: String, pitch_jitter: float = 0.08) -> void`

- [ ] **Step 1: Clone `patch-gg/pixelfx` and inspect catalog for our 9 VFX**
  Run `git clone --depth 1 https://github.com/patch-gg/pixelfx /Users/mac/Desktop/GAME_Project/tools/pixelfx` and run `node tools/list.mjs` queries (`slash`, `dash`, `spark`, `burst`, `shield`, `explosion`, `coin`, `level`, `portal`) to pick verified effect IDs.
- [ ] **Step 2: Write `tools/export_vfx.mjs` and export sprite sheets (PNG + JSON)**
  Render 9 effects via `node tools/render.mjs <id> --sheet --opts '<palette>'` and copy PNG + JSON to `godot_project/assets/vfx/` under clean keys: `slash`, `wind_slash`, `hit_spark`, `dash_puff`, `mana_burst`, `shield_aura`, `fire_bomb`, `coin_sparkle`, `level_up`.
- [ ] **Step 3: Create `godot_project/project.godot`, copy Thai fonts, and generate retro SFX**
  Configure `1280x720` (`canvas_items`, `keep`), default texture filter `Nearest`, InputMap actions (`move_left`, `move_right`, `jump`, `dash`, `attack`, `skill_1`, `skill_2`, `skill_3`, `item_1`, `item_2`, `interact`, `toggle_status`, `toggle_shop`), and Autoloads. Copy `Tahoma.ttf` and `Tahoma Bold.ttf` to `godot_project/assets/fonts/`. Run `tools/gen_sfx.mjs` to create crisp WAV files in `godot_project/assets/sfx/`.
- [ ] **Step 4: Implement `VfxManager.gd` and `SfxManager.gd`**
  `VfxManager` parses `res://assets/vfx/<key>/<key>.json` (`frames` rects + `meta.pixelfx.fps` + `meta.pixelfx.pivot`), builds cached `SpriteFrames` using `AtlasTexture`, sets `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`, and frees non-looping sprites on `animation_finished`.
- [ ] **Step 5: Verify headless load of `VfxManager` & exported sheets**
  Run `godot --headless --path godot_project --quit` and confirm 0 script errors and all 9 VFX keys load valid `SpriteFrames`.

---

### Task 2: Core Data Tables & ORV State Singletons (`GameData`, `GameState`, `ScenarioManager`)

**Files:**
- Create: `godot_project/scripts/data/GameData.gd`
- Create: `godot_project/scripts/autoload/GameState.gd`
- Create: `godot_project/scripts/autoload/ScenarioManager.gd`
- Test: `godot_project/tests/test_core_systems.gd`

**Interfaces:**
- Consumes: `VfxManager`, `SfxManager` (optional signals)
- Produces:
  - `GameData`: `ATTRIBUTES` (5 entries), `WEAPONS` (5 entries), `CONSUMABLES` (4 entries), `SKILLS` (4 entries), `SPONSORS` (4 entries)
  - `GameState`:
    - `roll_attribute(rng: RandomNumberGenerator = null) -> Dictionary`
    - `start_new_run(attr_id: String) -> void`
    - `get_upgrade_cost(stat_name: String) -> int` (`100 * level`)
    - `upgrade_stat(stat_name: String) -> bool`
    - `add_coins(amount: int, reason: String = "") -> void`
    - `spend_coins(amount: int) -> bool`
    - `buy_item(item_id: String) -> bool`
    - `buy_skill(skill_id: String) -> bool`
    - `equip_weapon(weapon_id: String) -> bool`
    - `use_consumable(slot_index: int) -> Dictionary`
    - `get_max_hp() -> int`, `get_max_mp() -> int`, `get_attack_damage() -> int`, `get_move_speed() -> float`, `get_dash_cooldown() -> float`
    - Signals: `stats_changed`, `coins_changed(new_amount, delta)`, `inventory_changed`, `skills_changed`, `hp_mp_changed`
  - `ScenarioManager`:
    - `start_scenario_1() -> void`
    - `tick(delta: float) -> void`
    - `register_enemy_killed(enemy_type: String, is_human: bool) -> void`
    - `complete_hidden_bug_box() -> void`
    - `complete_sub_rescue() -> void`
    - `trigger_perfect_dodge() -> void`
    - `select_sponsor(sponsor_id: String) -> void`
    - Signals: `scenario_updated`, `constellation_message(text, coin_bonus)`, `scenario_cleared(path_type)`, `scenario_failed(reason)`

- [ ] **Step 1: Write failing headless unit test `godot_project/tests/test_core_systems.gd`**
  Assert:
  - `roll_attribute()` returns valid attribute from the 5 defined entries.
  - `upgrade_stat("str")` costs `100` at Lv.1, `200` at Lv.2, fails and deducts 0 coins when coins < cost, and `upgrade_stat("phy")` increases `max_hp` by 20.
  - `trigger_perfect_dodge()` awards coins once and respects cooldown (second immediate call awards 0).
  - `complete_hidden_bug_box()` clears Scenario #1 once, stops timer, and subsequent `register_enemy_killed` does NOT double-emit `scenario_cleared`.
- [ ] **Step 2: Run test to verify it fails**
  Run: `godot --headless --path godot_project --script res://tests/test_core_systems.gd`
- [ ] **Step 3: Implement `GameData.gd`, `GameState.gd`, and `ScenarioManager.gd`**
  Implement exact spec values, weighted rarity roll (35/22/22/15/6%), stat formulas, shop purchases, and dual-path Scenario #1 state machine.
- [ ] **Step 4: Run test to verify it passes**
  Run: `godot --headless --path godot_project --script res://tests/test_core_systems.gd`
  Expected: `ALL CORE TESTS PASSED` with exit code 0.

---

### Task 3: Procedural Shaded Pixel-Art Sprites & 3-Car Subway Stage

**Files:**
- Create: `tools/gen_sprites.mjs`
- Create: `godot_project/assets/sprites/*.png`
- Create: `godot_project/scripts/world/SubwayStage.gd`
- Create: `godot_project/scenes/world/SubwayStage.tscn`

**Interfaces:**
- Produces:
  - Sprite PNGs (`player_sheet.png`, `enemy_frenzy.png`, `enemy_charger.png`, `enemy_boss.png`, `dokkaebi.png`, `npc_survivor.png`, `props.png`, `subway_bg.png`)
  - `SubwayStage`: `player_spawn: Vector2`, `car_bounds: Rect2`, `get_camera_limits() -> Rect2`, `trigger_screen_shake(strength: float, duration: float) -> void`

- [ ] **Step 1: Write `tools/gen_sprites.mjs` and generate shaded pixel-art assets**
  Generate crisp, palette-shaded pixel art (with outlines, highlights, shadows—no flat rectangles):
  - `player_sheet.png` (24x32 frames: idle x2, run x4, jump x1, dash x1, attack x3, hurt x1)
  - `enemy_frenzy.png`, `enemy_charger.png`, `enemy_boss.png` (24x32 / 32x40 frames)
  - `dokkaebi.png` (24x24 floating Dokkaebi with horns & coat), `npc_survivor.png`, `props.png` (weapon pickup, kid's backpack, bug box, subway seat, luggage)
  - `subway_bg.png` (seamless 3-car subway interior with windows, tunnel darkness, poles, handrails, doors, overhead lamps)
- [ ] **Step 2: Build `SubwayStage.tscn` & `SubwayStage.gd`**
  3 connected subway cars (`x = 0..1600`, floor `y = 212`), StaticBody2D floor/walls + one-way jumpable luggage/seats, flickering ceiling lights, scrolling dark tunnel parallax outside windows, and camera shake controller.
- [ ] **Step 3: Verify stage loads cleanly in headless Godot**
  Run `godot --headless --path godot_project --quit` and inspect generated PNGs with `read_file` to verify visual quality.

---

### Task 4: Player Controller, Action Combat, Skills & `pixelfx` Integration

**Files:**
- Create: `godot_project/scripts/entities/Player.gd`
- Create: `godot_project/scenes/entities/Player.tscn`
- Create: `godot_project/scripts/world/FloatingText.gd`

**Interfaces:**
- Consumes: `GameState`, `ScenarioManager`, `VfxManager`, `SfxManager`
- Produces:
  - `Player`: `take_damage(amount: int, knockback_dir: float) -> void`, `is_dashing() -> bool`, `get_facing() -> int`, `apply_hit_stop(duration: float) -> void`
  - Signals: `player_died`, `hit_enemy(enemy, damage)`

- [ ] **Step 1: Implement `Player.gd` & `Player.tscn`**
  - Smooth horizontal movement scaled by `GameState.get_move_speed()`, gravity, jump with `0.10s` coyote time & `0.10s` jump buffer.
  - Dash left/right (`Shift`/`K`) with `0.22s` i-frames, ghost/dust `VfxManager.spawn_vfx("dash_puff", ...)`, and **Perfect Dodge** check (detects overlapping enemy attack hitbox during i-frames → calls `ScenarioManager.trigger_perfect_dodge()` + brief blue flash).
  - 3-hit melee combo (`J`) spawning `slash` VFX + `hit_spark` on contact + `0.05s` hit-stop + `FloatingText`.
  - Skills `1/2/3` (`Desperate Slash`, `Wind Step Slash`, `Mana Burst`, `Magic Barrier`) with MP cost, cooldowns, and `pixelfx` VFX.
  - Quick items `Q/E` (HP heal, MP restore, `fire_bomb` thrown projectile with `fire_bomb` explosion VFX).
- [ ] **Step 2: Verify Player scene instantiates cleanly via headless check**
  Extend `tests/test_core_systems.gd` to instantiate `Player.tscn` and verify movement/dash/damage/i-frame behavior.

---

### Task 5: Enemies, Mini-Boss, Interactables & Scenario #1 Flow

**Files:**
- Create: `godot_project/scripts/entities/Enemy.gd`
- Create: `godot_project/scenes/entities/Enemy.tscn`
- Create: `godot_project/scripts/world/Interactable.gd`
- Create: `godot_project/scenes/world/Interactable.tscn`
- Modify: `godot_project/scripts/world/SubwayStage.gd`

**Interfaces:**
- Consumes: `GameState`, `ScenarioManager`, `VfxManager`, `SfxManager`, `Player`
- Produces:
  - `Enemy.setup(archetype: String) -> void` (`"frenzy"`, `"charger"`, `"boss"`)
  - `Interactable.setup(kind: String, prompt: String) -> void` (`"weapon"`, `"npc_rescue"`, `"bug_box"`)

- [ ] **Step 1: Implement `Enemy.gd` & `Enemy.tscn`**
  3 distinct behaviors:
  - `frenzy`: chases player in car, winds up (`0.35s` red telegraph flash), melee strike.
  - `charger`: pauses with exclamation telegraph, dashes across floor toward player (encourages jump/dash dodge).
  - `boss` (Car 3 Gang Leader): alternates between telegraphed lunge and wide slash (`pixelfx` slash), displays boss HP bar, drops generous coins.
- [ ] **Step 2: Implement `Interactable.gd` & wire Car 1/2/3 encounters in `SubwayStage.gd`**
  - Car 1: Dokkaebi opening float-in + Star Stream `[ บทละครหลัก #1 ]` popup, spare weapon (`ท่อเหล็ก`), 2 `frenzy` enemies.
  - Car 2: Trapped NPC (`Sub-Scenario`: defeat 2 guarding enemies or talk after clearing → `+150` coins + potion), 1 `charger`.
  - Car 3: Gang Leader `boss` + Kid's Backpack (`bug_box`) at far end with glowing aura (brighter if `นักอ่านนิยายวันสิ้นโลก` attribute) allowing `F` to clear via Hidden Scenario without killing humans!
- [ ] **Step 3: Verify headless instantiation of SubwayStage with enemies and interactables**
  Run headless scene check.

---

### Task 6: Star Stream HD Thai UI Suite, Main Scene & End-to-End Verification

**Files:**
- Create: `godot_project/scripts/ui/UiTheme.gd` (reusable Star Stream blue translucent panel StyleBox + Thai font theme)
- Create: `godot_project/scenes/ui/AttributeRollScreen.tscn` + `.gd`
- Create: `godot_project/scenes/ui/HudOverlay.tscn` + `.gd`
- Create: `godot_project/scenes/ui/AttributeWindow.tscn` + `.gd`
- Create: `godot_project/scenes/ui/DokkaebiBagModal.tscn` + `.gd`
- Create: `godot_project/scenes/ui/SponsorModal.tscn` + `.gd`
- Create: `godot_project/scenes/ui/ResultModal.tscn` + `.gd`
- Create: `godot_project/scenes/Main.tscn` + `scripts/Main.gd`

**Interfaces:**
- Consumes: `GameState`, `ScenarioManager`, `VfxManager`, `SfxManager`, `SubwayStage`, `Player`
- Produces: Complete playable game launching directly into `res://scenes/Main.tscn`

- [ ] **Step 1: Build `UiTheme.gd` (Star Stream aesthetic + `Tahoma.ttf` / `Tahoma Bold.ttf`)**
  Deep translucent navy (`#081326e6`), glowing cyan border (`#38bdf8`), crisp white/gold Thai text, rarity colors (Common white, Rare cyan, Hero gold).
- [ ] **Step 2: Implement `AttributeRollScreen` (Start + Reroll Personal Attribute)**
  Shows `[ หน้าต่างข้อมูลตัวละครถูกสร้างขึ้น ]`, rolled attribute name, rarity badge, starting STR/PHY/AGI/MAG, starting weapon/item, passive description, **"สุ่มใหม่"** button, and **"เข้าสู่บทละคร #1"** button.
- [ ] **Step 3: Implement `HudOverlay`, `AttributeWindow` (`Tab`), and `DokkaebiBagModal` (`B`)**
  - HUD: Top-left HP/MP/Coins/Attribute badge, Top-right Scenario #1 objective + 180s timer + fading Constellation feed, Bottom-center 3 skill slots (`1/2/3`) + 2 quick-item slots (`Q/E`) + hotkey hints.
  - Attribute Window (`Tab`): pauses tree (`PROCESS_MODE_ALWAYS`), shows STR/PHY/AGI/MAG with `+ อัป (X เหรียญ)` buttons, equipped weapon switcher, skill loadout.
  - Dokkaebi Bag (`B`): pauses tree, tabs/sections for อาวุธ, สกิล, ไอเทมกดใช้ with coin prices and instant purchase.
- [ ] **Step 4: Implement `SponsorModal`, `ResultModal`, and `Main.tscn` Hybrid Orchestrator**
  - `Main.tscn` hosts `SubViewportContainer` (`480x270` `SubViewport` with `SubwayStage`) under `CanvasLayer` (`1280x720` HD UI).
  - Scenario clear → `SponsorModal` (choose 1 of 3 Constellations or Reject for +300 coins) → `ResultModal` (summary stats + "เล่นใหม่ / สุ่มคุณลักษณะใหม่").
  - Player death or 180s timeout → Game Over modal with "ลองใหม่ด่านนี้" and "สุ่มตัวละครใหม่".
- [ ] **Step 5: Run full headless test suite + live Godot launch check**
  Run `godot --headless --path godot_project --script res://tests/test_core_systems.gd` and verify `Main.tscn` loads with 0 errors/warnings.
