extends Node3D
## SERAPHONK — game manager. Builds arena in code, runs director/combat/UI/juice.
## Design refs: Megabonk loop (auto-weapons, XP/tomes, gate+boss, 10:00 Wrath),
## Ultrakill movement (dash i-frames, slide momentum, slam AoE), juice tiers
## (hitstop 40-120ms, shake 0.15-0.25s decay, FOV kick, damage numbers).

const RUN_LEN := 600.0
const ARENA := Vector2(40.0, 30.0)
const WEAPON_MAX := 5

var player: CharacterBody3D
var cam: Camera3D
var cam_base_fov := 75.0
var trauma := 0.0
var hitstop_t := 0.0
var t := 0.0
var kills := 0
var gold := 0
var level := 1
var xp := 0.0
var xp_next := 8.0
var weapons: Array = []  # [{id, lvl, cd}]
var tomes := {"quantity": 0, "zeal": 0, "radius": 0, "swiftness": 0}
var enemies: Array = []
var projectiles: Array = []
var pickups: Array = []
var spawn_acc := 0.0
var miniboss_done := {}
var game_over := false
var victory := false
var draft_open := false
var hud_layer: CanvasLayer
var hud_label: Label
var draft_panel: PanelContainer
var orbs_magnet := 3.5
var sfx: Node
var prev_dash := 0.0
var shrines: Array = []  # [{pos, r, progress, done, node}]
var chests: Array = []  # [{pos, cost, opened, node}]
var chest_count := 0
var warden_spawned := false
var warden: Node3D = null
var gate_node: MeshInstance3D = null
var gate_sealed := true
var pause_label: Label
var title_label: Label
var dmg_label_count := 0
var eprojectiles: Array = []  # hostile orbs
var rings: Array = []  # warden shockwaves [{pos, r, node}]
var warden_cd := 0.0
var warden_phase := 0
var vendor_cost := 30
var vendor_cd := 0.0
var dmg_flash := 0.0
var vignette: ColorRect
var sens_mult := 1.0
var shake_mult := 1.0
var stage := 1
var stage_t := 0.0
var lavas: Array = []  # [{pos, r}]
var style := 0.0
var style_label: Label
var announce_label: Label
var announce_t := 0.0
var surge_t := 0.0
var warden_enraged := false
var tracers: Array = []  # beam visuals [{node, life}]
var meta := {"runs": 0, "victories": 0, "kills": 0}

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://seraphonk.cfg") == OK:
		sens_mult = float(cfg.get_value("feel", "sensitivity", 1.0))
		shake_mult = float(cfg.get_value("feel", "shake", 1.0))
	if cfg.load("user://seraphonk_meta.cfg") == OK:
		meta["runs"] = int(cfg.get_value("meta", "runs", 0))
		meta["victories"] = int(cfg.get_value("meta", "victories", 0))
		meta["kills"] = int(cfg.get_value("meta", "kills", 0))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("feel", "sensitivity", sens_mult)
	cfg.set_value("feel", "shake", shake_mult)
	cfg.save("user://seraphonk.cfg")

func _save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "runs", int(meta["runs"]))
	cfg.set_value("meta", "victories", int(meta["victories"]))
	cfg.set_value("meta", "kills", int(meta["kills"]) + kills)
	cfg.save("user://seraphonk_meta.cfg")

func _record_run(won: bool) -> void:
	var mins := int(t) / 60
	var secs := int(t) % 60
	var line := "%s %02d:%02d Lv%d %dk" % ["WON" if won else "fell", mins, secs, level, kills]
	var cfg := ConfigFile.new()
	cfg.load("user://seraphonk_runs.cfg")
	var hist: Array = []
	if cfg.has_section("runs"):
		for k in cfg.get_section_keys("runs"):
			hist.append(str(cfg.get_value("runs", k, "")))
	hist.push_front(line)
	while hist.size() > 8:
		hist.pop_back()
	var out := ConfigFile.new()
	for i in hist.size():
		out.set_value("runs", "r%d" % i, hist[i])
	out.save("user://seraphonk_runs.cfg")

func _run_history_text() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://seraphonk_runs.cfg") != OK or not cfg.has_section("runs"):
		return "No flights yet — this is your first."
	var lines: Array = []
	for k in cfg.get_section_keys("runs"):
		lines.append(str(cfg.get_value("runs", k, "")))
	return "Recent flights: " + " · ".join(lines)

func _try_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	return n

func budget(tt: float) -> float:
	var m := tt / 60.0
	return 4.0 + 6.0 * m + 2.5 * m * m

func _ready() -> void:
	# UI + manager must run while paused (start/draft/pause menus)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	player = $Player
	cam = $Player/Cam
	cam_base_fov = cam.fov
	player.set("sens_mult", sens_mult)
	# meta blessings: veterans start stronger (Silver Grace across runs)
	meta["runs"] = int(meta["runs"]) + 1
	_save_meta()
	gold = 10 * int(meta["victories"])
	var hp_bonus := 5 * (int(meta["runs"]) / 3)
	player.set("max_hp", 100.0 + hp_bonus)
	player.set("hp", 100.0 + hp_bonus)
	sfx = Node.new()
	sfx.set_script(load("res://scripts/sfx.gd"))
	add_child(sfx)
	_build_arena()
	_build_hud()
	_build_shrines_chests()
	weapons.append({"id": "chakram", "lvl": 1, "cd": 0.0})
	_show_start()
	set_process(true)

func _show_start() -> void:
	# start overlay: goal + controls + Start (captures mouse). Skipped headless.
	if DisplayServer.get_name() == "headless":
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dim := ColorRect.new()
	dim.name = "StartDim"
	dim.color = Color(0.02, 0.02, 0.06, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(dim)
	var center := CenterContainer.new()
	center.name = "StartCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "StartPanel"
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(560, 0)
	panel.add_child(vb)
	var t := Label.new()
	t.add_theme_font_size_override("font_size", 34)
	t.text = "SERAPHONK"
	vb.add_child(t)
	var g := Label.new()
	g.add_theme_font_size_override("font_size", 16)
	g.text = "You are a seraph. The fallen swarm.\nSurvive, gather grace, choose blessings.\nAt 5:00 the Gate unseals — enter it and slay the Warden.\nAt 10:00 the Wrath comes for the slow."
	g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(g)
	var meta_l := Label.new()
	meta_l.add_theme_font_size_override("font_size", 14)
	meta_l.text = "Across runs: %d flights · %d victories · %d fallen · starting +%d gold, +%d HP" % [
		int(meta["runs"]), int(meta["victories"]), int(meta["kills"]),
		10 * int(meta["victories"]), 5 * (int(meta["runs"]) / 3)]
	vb.add_child(meta_l)
	var hist := Label.new()
	hist.add_theme_font_size_override("font_size", 13)
	hist.text = _run_history_text()
	hist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hist)
	var c := Label.new()
	c.add_theme_font_size_override("font_size", 16)
	c.text = "WASD move (W = sprint) · MOUSE look · SHIFT dash (invincible) · SPACE jump (mid-dash = dash-jump) · CTRL slide, CTRL in air = slam · ESC pause · R restart"
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(c)
	var b := Button.new()
	b.text = "ASCEND"
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(_start_game)
	vb.add_child(b)
	var sh := HBoxContainer.new()
	var shl := Label.new()
	shl.text = "Look sensitivity"
	sh.add_child(shl)
	var ssl := HSlider.new()
	ssl.min_value = 0.4
	ssl.max_value = 2.2
	ssl.step = 0.05
	ssl.value = sens_mult
	ssl.custom_minimum_size = Vector2(220, 0)
	ssl.value_changed.connect(_on_sens_changed)
	sh.add_child(ssl)
	vb.add_child(sh)
	var shb := CheckBox.new()
	shb.text = "Screen shake"
	shb.button_pressed = shake_mult > 0.0
	shb.toggled.connect(_on_shake_toggled)
	vb.add_child(shb)

func _on_sens_changed(v: float) -> void:
	sens_mult = v
	player.set("sens_mult", v)
	_save_settings()

func _on_shake_toggled(on: bool) -> void:
	shake_mult = 1.0 if on else 0.0
	_save_settings()

func _start_game() -> void:
	hud_layer.get_node("StartDim").queue_free()
	hud_layer.get_node("StartCenter").queue_free()
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _style_rank() -> Array:
	# [letter, color] — Ultrakill-style aggression meter, cosmetic
	if style >= 3.5: return ["SSS", Color(1.0, 0.3, 0.2)]
	if style >= 2.5: return ["SS", Color(1.0, 0.45, 0.15)]
	if style >= 1.8: return ["S", Color(1.0, 0.75, 0.2)]
	if style >= 1.2: return ["A", Color(0.5, 0.9, 1.0)]
	if style >= 0.7: return ["B", Color(0.5, 1.0, 0.6)]
	if style >= 0.3: return ["C", Color(0.7, 0.7, 0.8)]
	return ["D", Color(0.45, 0.45, 0.5)]

func _marker(text: String, pos: Vector3, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	return l

func _build_arena() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA.x, 0.5, ARENA.y)
	col.shape = box
	floor_body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(ARENA.x, 0.5, ARENA.y)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.09, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.22, 0.45)
	mat.emission_energy_multiplier = 0.35
	mesh.material_override = mat
	set_meta("floor_mat", mat)
	floor_body.add_child(mesh)
	floor_body.position = Vector3(0, -0.25, 0)
	add_child(floor_body)
	# glowing choir pillars (cover + slam reference) — 5 of 8 candidate naves per run
	var pillar_pool := [Vector3(-12, 0, -8), Vector3(12, 0, -8), Vector3(-12, 0, 8), Vector3(12, 0, 8), Vector3(0, 0, 0), Vector3(-6, 0, -5), Vector3(6, 0, 5), Vector3(-14, 0, 1), Vector3(14, 0, -1)]
	pillar_pool.shuffle()
	var pillar_pos := pillar_pool.slice(0, 5)
	for i in pillar_pos.size():
		var p: Vector3 = pillar_pos[i]
		var sb := StaticBody3D.new()
		var cc := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 1.2
		cyl.height = 6.0
		cc.shape = cyl
		cc.position.y = 3.0
		sb.add_child(cc)
		var model := _try_model("res://assets/models/pillar.glb")
		if model:
			model.position.y = 0.0
			sb.add_child(model)
		else:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 1.0
			cm.bottom_radius = 1.3
			cm.height = 6.0
			mi.mesh = cm
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.85, 0.8, 0.65)
			pm.emission_enabled = true
			pm.emission = Color(1.0, 0.9, 0.6)
			pm.emission_energy_multiplier = 0.6 if i != 4 else 1.2
			mi.material_override = pm
			mi.position.y = 3.0
			sb.add_child(mi)
		sb.position = Vector3(p.x, 0, p.z)
		add_child(sb)
	# jumpable choir platforms (slam-from-above plays, escape routes) — 3 of 5 per run
	var plat_pool := [[Vector3(-6, 0, 4), 1.0], [Vector3(6, 0, -4), 1.0], [Vector3(0, 0, -9), 1.9], [Vector3(-9, 0, -3), 1.0], [Vector3(9, 0, 3), 1.9]]
	plat_pool.shuffle()
	var plat_spots := plat_pool.slice(0, 3)
	for ps in plat_spots:
		var ppos: Vector3 = ps[0]
		var ph: float = ps[1]
		var pb := StaticBody3D.new()
		var pc := CollisionShape3D.new()
		var pbox := BoxShape3D.new()
		pbox.size = Vector3(3.0, 0.4, 3.0)
		pc.shape = pbox
		pc.position.y = ph - 0.2
		pb.add_child(pc)
		var pm2 := MeshInstance3D.new()
		var pmm := BoxMesh.new()
		pmm.size = Vector3(3.0, 0.4, 3.0)
		pm2.mesh = pmm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.35, 0.32, 0.45)
		pmat.emission_enabled = true
		pmat.emission = Color(0.45, 0.4, 0.8)
		pmat.emission_energy_multiplier = 0.5
		pm2.material_override = pmat
		pm2.position.y = ph - 0.2
		pb.add_child(pm2)
		pb.position = Vector3(ppos.x, 0, ppos.z)
		add_child(pb)
	# Sanctum Gate (boss portal) at north edge
	var gate_pos := Vector3(0, 2.5, -ARENA.y * 0.5 + 2.0)
	var gate_model := _try_model("res://assets/models/gate.glb")
	if gate_model:
		gate_model.name = "Gate"
		gate_model.position = Vector3(gate_pos.x, 0.0, gate_pos.z)
		add_child(gate_model)
	gate_node = MeshInstance3D.new()
	gate_node.name = "GateRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 2.2
	gate_node.mesh = tm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1, 0.95, 0.75)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.85, 0.4)
	gm.emission_energy_multiplier = 0.6  # sealed; rises when unsealed
	gate_node.material_override = gm
	gate_node.position = gate_pos
	add_child(gate_node)
	(gate_node as MeshInstance3D).set_meta("marker", _marker("SANCTUM · sealed", gate_pos + Vector3(0, 3.5, 0), Color(0.6, 0.6, 0.7)))

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud_layer)
	hud_label = Label.new()
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.position = Vector2(12, 10)
	hud_layer.add_child(hud_label)
	draft_panel = PanelContainer.new()
	var draft_vb := VBoxContainer.new()
	draft_vb.name = "Choices"
	draft_vb.custom_minimum_size = Vector2(520, 0)
	draft_panel.add_child(draft_vb)
	var draft_dim := ColorRect.new()
	draft_dim.name = "DraftDim"
	draft_dim.color = Color(0, 0, 0, 0.65)
	draft_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	draft_dim.visible = false
	hud_layer.add_child(draft_dim)
	var draft_center := CenterContainer.new()
	draft_center.name = "DraftCenter"
	draft_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	draft_center.visible = false
	draft_center.add_child(draft_panel)
	hud_layer.add_child(draft_center)
	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.text = "WASD move · SHIFT dash · SPACE jump · CTRL slide/slam · aim with crosshair"
	title_label.position = Vector2(12, 34)
	hud_layer.add_child(title_label)
	var objective := Label.new()
	objective.name = "Objective"
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective.add_theme_font_size_override("font_size", 17)
	objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(objective)
	var cross := ColorRect.new()
	cross.name = "Crosshair"
	cross.color = Color(1, 0.95, 0.8)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-2, -2)
	cross.size = Vector2(4, 4)
	hud_layer.add_child(cross)
	var mouseln := Label.new()
	mouseln.name = "MouseHint"
	mouseln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouseln.add_theme_font_size_override("font_size", 18)
	mouseln.text = "CLICK TO LOOK AROUND"
	mouseln.set_anchors_preset(Control.PRESET_CENTER)
	mouseln.position = Vector2(-110, 40)
	mouseln.visible = false
	hud_layer.add_child(mouseln)
	vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0.7, 0.05, 0.1, 0.0)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(vignette)
	style_label = Label.new()
	style_label.add_theme_font_size_override("font_size", 44)
	style_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	style_label.position = Vector2(-140, 40)
	hud_layer.add_child(style_label)
	announce_label = Label.new()
	announce_label.add_theme_font_size_override("font_size", 30)
	announce_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	announce_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce_label.position.y = 80
	announce_label.visible = false
	hud_layer.add_child(announce_label)

func _unhandled_input(event: InputEvent) -> void:
	# click-to-capture backup (primary path is _input below)
	_try_capture(event)

func _input(event: InputEvent) -> void:
	# runs before GUI: clicks on labels can never block recapture
	_try_capture(event)

func _try_capture(event: InputEvent) -> void:
	# click-to-capture: any lost pointer capture recovers with one click
	if DisplayServer.get_name() == "headless":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not get_tree().paused and not draft_open and not game_over:
				if hud_layer.get_node_or_null("StartCenter") == null:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_label = Label.new()
	pause_label.add_theme_font_size_override("font_size", 42)
	pause_label.text = "PAUSED"
	pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.visible = false
	hud_layer.add_child(pause_label)
	var pause_hint := Label.new()
	pause_hint.name = "PauseHint"
	pause_hint.add_theme_font_size_override("font_size", 18)
	pause_hint.text = "ESC resume · R abandon run · look sensitivity applies live"
	pause_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint.position.y -= 120
	pause_hint.visible = false
	hud_layer.add_child(pause_hint)

func _build_shrines_chests() -> void:
	var shrine_pool := [Vector3(-16, 0, 0), Vector3(16, 0, 0), Vector3(0, 0, 10), Vector3(-10, 0, -10), Vector3(10, 0, -10)]
	shrine_pool.shuffle()
	var shrine_spots := shrine_pool.slice(0, 3)
	for i in shrine_spots.size():
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.15
		tm.outer_radius = 2.5
		ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.8, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.3, 0.6, 1.0)
		m.emission_energy_multiplier = 1.0
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.7
		ring.material_override = m
		ring.position = shrine_spots[i] + Vector3(0, 0.15, 0)
		add_child(ring)
		shrines.append({"pos": shrine_spots[i], "r": 2.5, "progress": 0.0, "done": false, "node": ring,
			"marker": _marker("BLESS", shrine_spots[i] + Vector3(0, 3.0, 0), Color(0.4, 0.7, 1.0))})
	var chest_pool := [Vector3(-8, 0, -11), Vector3(8, 0, -11), Vector3(0, 0, 12), Vector3(-15, 0, 6), Vector3(15, 0, 6)]
	chest_pool.shuffle()
	var chest_spots := chest_pool.slice(0, 3)
	for i in chest_spots.size():
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 0.8, 0.9)
		box.mesh = bm
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(0.7, 0.55, 0.2)
		cm.emission_enabled = true
		cm.emission = Color(1.0, 0.8, 0.3)
		cm.emission_energy_multiplier = 0.8
		box.material_override = cm
		box.position = chest_spots[i] + Vector3(0, 0.4, 0)
		add_child(box)
		chests.append({"pos": chest_spots[i], "cost": 20 + i * 10, "opened": false, "node": box,
			"marker": _marker("CACHE", chest_spots[i] + Vector3(0, 2.2, 0), Color(1.0, 0.8, 0.3))})
	# Tithe vendor: golden pillar, touch to buy blessings (escalating)
	var vend := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	vm.top_radius = 0.7
	vm.bottom_radius = 0.9
	vm.height = 3.0
	vend.mesh = vm
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.9, 0.75, 0.3)
	vmat.emission_enabled = true
	vmat.emission = Color(1.0, 0.8, 0.25)
	vmat.emission_energy_multiplier = 1.2
	vend.material_override = vmat
	vend.position = Vector3(10, 1.5, 8)
	add_child(vend)
	_marker("TITHE · blessings for gold", Vector3(10, 4.2, 8), Color(1.0, 0.85, 0.4))

func _process(dt: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().paused = not get_tree().paused
		pause_label.visible = get_tree().paused
		(hud_layer.get_node("PauseHint") as CanvasItem).visible = get_tree().paused
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED
		return
	if Input.is_key_pressed(KEY_R):
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	if game_over or draft_open or get_tree().paused:
		return
	# FPS contract: while playing, the pointer belongs to the camera.
	# (Pause/draft/end explicitly release it elsewhere.)
	if DisplayServer.get_name() != "headless":
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and hud_layer.get_node_or_null("StartCenter") == null:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if hitstop_t > 0.0:
		hitstop_t -= dt
		return
	t += dt
	stage_t += dt
	_director(dt)
	_weapons(dt)
	_enemies(dt)
	_projectiles(dt)
	_pickups(dt)
	_shrines(dt)
	_chests()
	_vendor(dt)
	_lava(dt)
	_gate(dt)
	_warden_fight(dt)
	_rings(dt)
	_tracers(dt)
	_juice(dt)
	_hud(dt)
	# dash whoosh edge
	var dnow: float = float(player.get("dash_t"))
	if dnow > 0.0 and prev_dash <= 0.0:
		sfx.call("play", "dash")
	prev_dash = dnow

func _announce(text: String, dur: float = 3.0) -> void:
	announce_label.text = text
	announce_label.visible = true
	announce_t = dur
	sfx.call("play", "boss")

func _director(dt: float) -> void:
	# surge events every minute: 15s of doubled pressure + announcement
	if int(t) > 0 and int(t) % 60 == 0 and surge_t <= 0.0 and t < RUN_LEN:
		surge_t = 15.0
		_announce("THE FALLEN SURGE")
	if surge_t > 0.0:
		surge_t -= dt
	if announce_t > 0.0:
		announce_t -= dt
		if announce_t <= 0.0:
			announce_label.visible = false
	# spawn pressure from budget curve; cap alive for perf (Megabonk-like chaos without meltdown)
	var alive := enemies.size()
	var mult := 2.2 if surge_t > 0.0 else 1.0
	var want := int(minf(budget(t) * 0.6 * mult, 110.0))
	spawn_acc += dt * (2.0 + t / 45.0) * mult
	var tick := int(t) % 90 == 0 and t > 5.0
	var key := int(t)
	if tick and not miniboss_done.get(key, false):
		miniboss_done[key] = true
		# miniboss variety: herald (apex wisp), bulwark (siege brute), fallen champion
		var roll := randf()
		if roll < 0.33:
			_spawn_enemy(true, true, "herald")
			_announce("A HERALD DESCENDS", 2.5)
		elif roll < 0.66:
			_spawn_enemy(true, false, "bulwark")
			_announce("A BULWARK APPROACHES", 2.5)
		else:
			_spawn_enemy(true)
			_announce("A CHAMPION RISES", 2.5)
	while spawn_acc >= 1.0 and alive < want:
		spawn_acc -= 1.0
		_spawn_enemy(false, randf() < 0.25, _cantor_ok())
		alive += 1
	if t >= RUN_LEN and not victory:
		# Wrath swarm: flood + end pressure, hard-capped for perf
		for i in 12:
			if enemies.size() < 140:
				_spawn_enemy(false, false)

func _cantor_ok() -> String:
	# cantors (ranged pressure) join after the first minute, brutes after two;
	# stage 2 fields veterans from the start
	if stage == 2 and randf() < 0.22:
		return "brute"
	if (stage == 2 or t > 120.0) and randf() < 0.18:
		return "brute"
	if (stage == 2 or t > 60.0) and randf() < 0.3:
		return "cantor"
	return "chaser"

func _spawn_enemy(elite: bool, flying: bool = false, kind: String = "chaser") -> void:
	var e := Node3D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	var ang := randf() * TAU
	var r := 22.0 + randf() * 6.0
	var pp: Vector3 = player.global_position
	e.position = Vector3(clampf(pp.x + cos(ang) * r, -ARENA.x * 0.5 + 1.0, ARENA.x * 0.5 - 1.0), 0, clampf(pp.z + sin(ang) * r, -ARENA.y * 0.5 + 1.0, ARENA.y * 0.5 - 1.0))
	add_child(e)
	var hp_scale := (1.0 + t / 120.0) * (1.5 if stage == 2 else 1.0)
	e.call("setup", elite, hp_scale, flying, kind)
	enemies.append(e)

func _weapons(dt: float) -> void:
	var zeal_mult: float = 1.0 + float(tomes["zeal"]) * 0.12
	var qty: int = 1 + int(tomes["quantity"])
	for w in weapons:
		w["cd"] -= dt * zeal_mult
		if w["cd"] > 0.0:
			continue
		if w["id"] == "chakram":
			w["cd"] = maxf(0.35, 0.9 - w["lvl"] * 0.07)
			_chakram_burst(int(w["lvl"]) + qty - 1, 2.6 + tomes["radius"] * 0.4, 16.0 + w["lvl"] * 6.0)
		elif w["id"] == "wheel":
			w["cd"] = 0.45
			_chakram_burst(6 + qty, 3.4 + tomes["radius"] * 0.4, 30.0, true)
		elif w["id"] == "trumpet":
			w["cd"] = maxf(0.3, 1.1 - w["lvl"] * 0.08)
			_trumpet_volley(qty + int(w["lvl"]) / 2, 12.0 + w["lvl"] * 5.0, 0)
		elif w["id"] == "choir":
			w["cd"] = 0.7
			_trumpet_volley(4 + qty, 26.0, 3)
		elif w["id"] == "beams":
			w["cd"] = maxf(0.9, 2.2 - w["lvl"] * 0.15)
			_psalm_beams(1 + int(w["lvl"]) / 2, 30.0 + w["lvl"] * 12.0)

func _nearest_enemy(max_d: float) -> Node3D:
	var best: Node3D = null
	var bd := max_d
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d: float = (e as Node3D).global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = e
	return best

func _chakram_burst(count: int, radius: float, dmg: float, golden: bool = false) -> void:
	for i in count:
		var a := TAU * float(i) / float(maxi(1, count)) + t * (3.5 if golden else 2.5)
		var hit_pos := player.global_position + Vector3(cos(a), 0, sin(a)) * radius
		_damage_area(hit_pos, (2.8 if golden else 2.2) + tomes["radius"] * 0.25, dmg, golden)

func _trumpet_volley(count: int, dmg: float, pierce: int = 0) -> void:
	# FPS aim: crosshair cone first, else nearest enemy (guns never feel dead)
	var aim: Vector3 = -cam.global_transform.basis.z
	var target := _enemy_in_crosshair(0.985)
	if target == null:
		target = _nearest_enemy(40.0)
	var base_dir: Vector3 = ((target.global_position + Vector3(0, 1.2, 0)) - (player.global_position + Vector3(0, 1.5, 0))).normalized() if target else aim
	for i in count:
		var p := Node3D.new()
		p.set_script(load("res://scripts/projectile.gd"))
		add_child(p)
		var dir: Vector3 = base_dir.rotated(Vector3.UP, (float(i) - float(count - 1) * 0.5) * 0.1)
		p.call("setup", player.global_position + Vector3(0, 1.5, 0), dir, 26.0, dmg, 2.5, false, pierce)
		projectiles.append(p)
	sfx.call("play", "shoot")

func _psalm_beams(count: int, dmg: float) -> void:
	# hitscan rails down the crosshair with slight spread: pierce everything
	var aim: Vector3 = -cam.global_transform.basis.z
	var from: Vector3 = player.global_position + Vector3(0, 1.5, 0)
	for i in count:
		var dir: Vector3 = aim.rotated(Vector3.UP, (float(i) - float(count - 1) * 0.5) * 0.06)
		var end := from + dir * 30.0
		for e in enemies:
			if not is_instance_valid(e):
				continue
			var en := e as Node3D
			var to: Vector3 = (en.global_position + Vector3(0, 1.0, 0)) - from
			var along := to.dot(dir)
			if along < 0.5 or along > 30.0:
				continue
			if (to - dir * along).length() <= 1.2 + float(en.get("radius")):
				en.call("damage", dmg, from)
				_spawn_damage_number(en.global_position + Vector3(0, 2.0, 0), int(dmg))
				if float(en.get("hp")) <= 0.0:
					_kill_enemy(en, false)
		_tracer(from, end)
	sfx.call("play", "shoot")
	trauma = minf(1.0, trauma + 0.12)

func _tracer(from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var length := from.distance_to(to)
	bm.size = Vector3(0.12, 0.12, length)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.9, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.85, 1.0)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to)
	tracers.append({"node": mi, "life": 0.15})

func _enemy_in_crosshair(min_dot: float) -> Node3D:
	var aim: Vector3 = -cam.global_transform.basis.z
	var from: Vector3 = player.global_position + Vector3(0, 1.5, 0)
	var best: Node3D = null
	var best_d := 30.0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var en := e as Node3D
		var to: Vector3 = (en.global_position + Vector3(0, 1.2, 0)) - from
		var d := to.length()
		if d > 30.0 or d < 0.5:
			continue
		if to.normalized().dot(aim) < min_dot:
			continue
		if d < best_d:
			best_d = d
			best = en
	return best

func _damage_area(center: Vector3, radius: float, dmg: float, heavy: bool) -> void:
	var killed: Array = []
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var en := e as Node3D
		if en.global_position.distance_to(center) <= radius + float(en.get("radius")):
			en.call("damage", dmg, center)
			sfx.call("play", "hit")
			_spawn_damage_number(en.global_position + Vector3(0, 2.0, 0), int(dmg))
			if float(en.get("hp")) <= 0.0:
				killed.append(e)
	for e in killed:
		_kill_enemy(e, heavy)

func _kill_enemy(e: Node3D, heavy: bool) -> void:
	enemies.erase(e)
	kills += 1
	style = minf(4.5, style + (0.3 if heavy or bool(e.get("elite")) else 0.12))
	sfx.call("play", "die")
	var pos: Vector3 = (e as Node3D).global_position
	var elite: bool = bool(e.get("elite"))
	_spawn_pickup(pos, elite)
	trauma = minf(1.0, trauma + (0.25 if heavy or elite else 0.08))
	if heavy or elite:
		hitstop_t = 0.06
		player.set("trauma", minf(1.0, float(player.get("trauma")) + 0.3))
	if e == warden:
		warden = null
		if stage == 1:
			_ascend_stage()
		else:
			victory = true
			_show_end(true)
	e.queue_free()

func _spawn_pickup(pos: Vector3, elite: bool) -> void:
	var p := Node3D.new()
	p.set_script(load("res://scripts/pickup.gd"))
	add_child(p)
	p.call("setup", pos, elite)
	pickups.append(p)
	if elite:
		gold += 5

func _enemies(dt: float) -> void:
	var pp := player.global_position
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var en := e as Node3D
		if bool(en.get("flying")):
			_flyer_steer(en, dt, pp)
			continue
		if String(en.get("kind")) == "cantor":
			_cantor_steer(en, dt, pp)
			continue
		if String(en.get("kind")) == "brute":
			_brute_steer(en, dt, pp)
			continue
		var to_p: Vector3 = pp - en.global_position
		to_p.y = 0.0
		var d := to_p.length()
		if d > 0.05:
			var spd: float = float(en.get("speed"))
			en.global_position += to_p.normalized() * spd * dt
		# separation (cheap, sampled)
		# contact damage with player i-frames respected
		if d < 1.1 + float(en.get("radius")) and float(en.get("touch_cd")) <= 0.0:
			en.set("touch_cd", 0.55 + randf() * 0.2)
			_hurt_player(float(en.get("contact")) * 0.5)

func _flyer_steer(en: Node3D, dt: float, pp: Vector3) -> void:
	var anchor: Vector3 = pp + Vector3(0, 1.4, 0)
	var to: Vector3 = anchor - en.global_position
	var fd := to.length()
	if fd > 0.1:
		var fspd: float = float(en.get("speed"))
		en.global_position += to.normalized() * fspd * dt
		en.global_position.y = clampf(en.global_position.y, 1.2, 6.0)
	if fd < 1.5 and float(en.get("touch_cd")) <= 0.0:
		en.set("touch_cd", 0.55 + randf() * 0.2)
		_hurt_player(float(en.get("contact")) * 0.5)

func _cantor_steer(en: Node3D, dt: float, pp: Vector3) -> void:
	var flat: Vector3 = pp - en.global_position
	flat.y = 0.0
	var d := flat.length()
	var spd: float = float(en.get("speed"))
	if d > 14.0:
		en.global_position += flat.normalized() * spd * dt
	elif d < 9.0 and d > 0.1:
		en.global_position -= flat.normalized() * spd * dt
	en.set("fire_cd", float(en.get("fire_cd")) - dt)
	if float(en.get("fire_cd")) <= 0.0 and d < 26.0:
		en.set("fire_cd", 2.5)
		if eprojectiles.size() < 40:
			var p := Node3D.new()
			p.set_script(load("res://scripts/projectile.gd"))
			add_child(p)
			var from: Vector3 = en.global_position + Vector3(0, 1.6, 0)
			var dir: Vector3 = ((pp + Vector3(0, 1.2, 0)) - from).normalized()
			p.call("setup", from, dir, 14.0, 12.0, 4.0, true)
			eprojectiles.append(p)

func _brute_steer(en: Node3D, dt: float, pp: Vector3) -> void:
	# telegraphed charge: roam -> flash 0.7s -> 16 m/s line -> recover. Dash the line.
	var st := int(en.get("charge_state"))
	var flat: Vector3 = pp - en.global_position
	flat.y = 0.0
	var d := flat.length()
	if st == 0:
		var spd: float = float(en.get("speed"))
		if d > 0.1:
			en.global_position += flat.normalized() * spd * dt
		if d < 9.0:
			en.set("charge_state", 1)
			en.set("charge_t", 0.7)
	elif st == 1:
		en.set("charge_t", float(en.get("charge_t")) - dt)
		if d > 0.1:
			en.set("charge_dir", flat.normalized())
		if float(en.get("charge_t")) <= 0.0:
			en.set("charge_state", 2)
			en.set("charge_t", 0.8)
	elif st == 2:
		en.global_position += (en.get("charge_dir") as Vector3) * 16.0 * dt
		en.global_position.y = 0.0
		en.set("charge_t", float(en.get("charge_t")) - dt)
		if float(en.get("charge_t")) <= 0.0:
			en.set("charge_state", 3)
			en.set("charge_t", 1.2)
	else:
		en.set("charge_t", float(en.get("charge_t")) - dt)
		if float(en.get("charge_t")) <= 0.0:
			en.set("charge_state", 0)
	if d < 1.2 + float(en.get("radius")) and float(en.get("touch_cd")) <= 0.0:
		en.set("touch_cd", 0.55 + randf() * 0.2)
		_hurt_player(float(en.get("contact")) * 0.5)

func _hurt_player(amount: float) -> void:
	if float(player.get("iframes_t")) > 0.0:
		return
	# early-run grace: contact ramps 50% -> 100% over the first 90s
	var grace := 0.5 + 0.5 * minf(1.0, t / 90.0)
	player.set("hp", float(player.get("hp")) - amount * grace)
	dmg_flash = minf(1.0, dmg_flash + 0.45)
	style = maxf(0.0, style - 0.4)
	if float(player.get("hp")) <= 0.0 and not game_over:
		game_over = true
		sfx.call("play", "die")
		_show_end(false)

func _projectiles(dt: float) -> void:
	var dead: Array = []
	for p in projectiles:
		if not is_instance_valid(p):
			dead.append(p)
			continue
		var pr := p as Node3D
		pr.call("tick", dt)
		if bool(pr.get("dead")):
			dead.append(p)
			continue
		for e in enemies:
			if not is_instance_valid(e):
				continue
			var en := e as Node3D
			if en.global_position.distance_to(pr.global_position) <= 1.0 + float(en.get("radius")):
				var seen: Array = pr.get("hit_ids")
				if en.get_instance_id() in seen:
					continue
				seen.append(en.get_instance_id())
				en.call("damage", float(pr.get("dmg")), pr.global_position)
				_spawn_damage_number(en.global_position + Vector3(0, 2.0, 0), int(float(pr.get("dmg"))))
				if float(en.get("hp")) <= 0.0:
					_kill_enemy(en, false)
				if int(pr.get("pierce")) > 0:
					pr.set("pierce", int(pr.get("pierce")) - 1)
					continue
				pr.set("dead", true)
				dead.append(p)
				break
	for p in dead:
		projectiles.erase(p)
		if is_instance_valid(p):
			(p as Node).queue_free()
	# hostile orbs: dodge with dash i-frames, slide, or cover
	var edead: Array = []
	for p in eprojectiles:
		if not is_instance_valid(p):
			edead.append(p)
			continue
		var pr := p as Node3D
		pr.call("tick", dt)
		if bool(pr.get("dead")):
			edead.append(p)
			continue
		if pr.global_position.distance_to(player.global_position + Vector3(0, 1.0, 0)) < 0.9:
			_hurt_player(float(pr.get("dmg")))
			pr.set("dead", true)
			edead.append(p)
	for p in edead:
		eprojectiles.erase(p)
		if is_instance_valid(p):
			(p as Node).queue_free()

func _pickups(dt: float) -> void:
	var pp := player.global_position
	var dead: Array = []
	for p in pickups:
		if not is_instance_valid(p):
			dead.append(p)
			continue
		var pk := p as Node3D
		var d: float = pk.global_position.distance_to(pp)
		if d < orbs_magnet + tomes["radius"] * 0.4:
			pk.global_position = pk.global_position.lerp(pp + Vector3(0, 0.8, 0), minf(1.0, dt * 8.0))
		if d < 1.2:
			xp += float(pk.get("value"))
			gold += int(pk.get("gold"))
			sfx.call("play", "pickup")
			dead.append(p)
			pk.queue_free()
			if xp >= xp_next:
				_open_draft()
	for p in dead:
		pickups.erase(p)

func _open_draft() -> void:
	xp -= xp_next
	level += 1
	xp_next = xp_next * 1.22 + 4.0
	sfx.call("play", "levelup")
	draft_open = true
	get_tree().paused = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vb: VBoxContainer = draft_panel.get_node("Choices")
	for c in vb.get_children():
		c.queue_free()
	var opts := _draft_options()
	var title := Label.new()
	title.text = "CHOIR %d — choose a blessing ( %d gold )" % [level, gold]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(title)
	for o in opts:
		var b := Button.new()
		b.text = o["label"]
		b.pressed.connect(_pick_draft.bind(o))
		vb.add_child(b)
	(hud_layer.get_node("DraftDim") as CanvasItem).visible = true
	(hud_layer.get_node("DraftCenter") as CanvasItem).visible = true

func _has_weapon(id: String) -> Dictionary:
	for w in weapons:
		if w["id"] == id:
			return w
	return {}

func _draft_options() -> Array:
	var pool: Array = []
	# evolutions first: maxed base + paired tome = ascended form
	var chak := _has_weapon("chakram")
	var trum := _has_weapon("trumpet")
	if not chak.is_empty() and int(chak["lvl"]) >= WEAPON_MAX and int(tomes["quantity"]) >= 2 and _has_weapon("wheel").is_empty():
		pool.append({"kind": "evolve", "id": "wheel", "from": "chakram", "label": "EVOLVE: Seraphim Wheel (chakram ascended)"})
	if not trum.is_empty() and int(trum["lvl"]) >= WEAPON_MAX and int(tomes["zeal"]) >= 2 and _has_weapon("choir").is_empty():
		pool.append({"kind": "evolve", "id": "choir", "from": "trumpet", "label": "EVOLVE: Choir Eternal (trumpet ascended)"})
	var pool2: Array = [
		{"kind": "weapon", "id": "trumpet", "label": "Trumpet Volley (auto aim)"},
		{"kind": "weapon", "id": "beams", "label": "Psalm Beams (piercing rails)"},
		{"kind": "tome", "id": "quantity", "label": "Tome of Quantity +projectile"},
		{"kind": "tome", "id": "zeal", "label": "Tome of Zeal +attack speed"},
		{"kind": "tome", "id": "radius", "label": "Tome of Radius +area/magnet"},
		{"kind": "tome", "id": "swiftness", "label": "Feather of Swiftness +move"},
	]
	var can_up := false
	for w in weapons:
		if int(w["lvl"]) < WEAPON_MAX:
			can_up = true
	if can_up:
		pool2.append({"kind": "up", "id": "all", "label": "Empower weapons +dmg"})
	pool2.shuffle()
	pool.append_array(pool2)
	while pool.size() > 3:
		# evolutions always offered when available
		if pool[3]["kind"] == "evolve":
			pool.pop_at(0)
		else:
			pool.pop_back()
	return pool

func _pick_draft(o: Dictionary) -> void:
	if o["kind"] == "weapon":
		var has := false
		for w in weapons:
			if w["id"] == o["id"]:
				has = true
		if not has and weapons.size() < 4:
			weapons.append({"id": o["id"], "lvl": 1, "cd": 0.0})
	elif o["kind"] == "evolve":
		for i in weapons.size():
			if weapons[i]["id"] == o["from"]:
				weapons.remove_at(i)
				break
		weapons.append({"id": o["id"], "lvl": 1, "cd": 0.0})
		sfx.call("play", "evolve")
		trauma = minf(1.0, trauma + 0.4)
	elif o["kind"] == "up":
		for w in weapons:
			if int(w["lvl"]) < WEAPON_MAX:
				w["lvl"] += 1
	else:
		tomes[o["id"]] = int(tomes[o["id"]]) + 1
		if o["id"] == "swiftness":
			player.set("walk_mult", float(player.get("walk_mult")) + 0.08)
	draft_panel.visible = false
	(hud_layer.get_node("DraftDim") as CanvasItem).visible = false
	(hud_layer.get_node("DraftCenter") as CanvasItem).visible = false
	draft_open = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _shrines(dt: float) -> void:
	var pp := player.global_position
	for s in shrines:
		if bool(s["done"]):
			continue
		var d: float = Vector2(pp.x - (s["pos"] as Vector3).x, pp.z - (s["pos"] as Vector3).z).length()
		if d < float(s["r"]):
			s["progress"] = float(s["progress"]) + dt
			if float(s["progress"]) >= 3.0:
				s["done"] = true
				(s["node"] as MeshInstance3D).visible = false
				if is_instance_valid(s["marker"]):
					(s["marker"] as Node).queue_free()
				player.set("hp", minf(float(player.get("max_hp")), float(player.get("hp")) + 30.0))
				tomes["zeal"] = int(tomes["zeal"]) + 1
				sfx.call("play", "shrine")
				trauma = minf(1.0, trauma + 0.2)
		else:
			s["progress"] = maxf(0.0, float(s["progress"]) - dt * 2.0)

func _chests() -> void:
	var pp := player.global_position
	for c in chests:
		if bool(c["opened"]):
			continue
		var d: float = Vector2(pp.x - (c["pos"] as Vector3).x, pp.z - (c["pos"] as Vector3).z).length()
		if d < 1.8 and gold >= int(c["cost"]):
			gold -= int(c["cost"])
			c["opened"] = true
			(c["node"] as MeshInstance3D).visible = false
			if is_instance_valid(c["marker"]):
				(c["marker"] as Node).queue_free()
			chest_count += 1
			var roll := randi() % 3
			if roll == 0 and weapons.size() < 4:
				weapons.append({"id": "trumpet", "lvl": 1, "cd": 0.0})
			elif roll == 1:
				for w in weapons:
					w["lvl"] += 1
			else:
				var keys := ["quantity", "zeal", "radius"]
				var k: String = keys[randi() % keys.size()]
				tomes[k] = int(tomes[k]) + 1
			sfx.call("play", "chest")
			trauma = minf(1.0, trauma + 0.25)

func _ascend_stage() -> void:
	# the Warden falls — the choir descends into the Sunken Nave (stage 2)
	stage = 2
	stage_t = 0.0
	gate_sealed = true
	warden_spawned = false
	warden_enraged = false
	warden_phase = 0
	player.set("hp", float(player.get("max_hp")))
	_announce("THE SUNKEN NAVE — the Gate will reopen", 4.0)
	sfx.call("play", "evolve")
	if gate_node and gate_node.has_meta("marker"):
		var gmk := gate_node.get_meta("marker") as Label3D
		if is_instance_valid(gmk):
			gmk.text = "SANCTUM · sealed"
			gmk.modulate = Color(0.6, 0.6, 0.7)
		(gate_node.material_override as StandardMaterial3D).emission_energy_multiplier = 0.6
	var ember := OmniLight3D.new()
	ember.name = "EmberLight"
	ember.light_color = Color(1.0, 0.35, 0.12)
	ember.light_energy = 1.4
	ember.omni_range = 40.0
	ember.position = Vector3(0, 10, 0)
	add_child(ember)
	if has_meta("floor_mat"):
		(get_meta("floor_mat") as StandardMaterial3D).emission = Color(0.7, 0.15, 0.05)
	for lp in [Vector3(-10, 0, -6), Vector3(10, 0, -6), Vector3(0, 0, 8)]:
		var pool := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 2.2
		cm.bottom_radius = 2.2
		cm.height = 0.1
		pool.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 0.4, 0.1)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.3, 0.05)
		m.emission_energy_multiplier = 2.5
		pool.material_override = m
		pool.position = lp + Vector3(0, 0.06, 0)
		add_child(pool)
		lavas.append({"pos": lp, "r": 2.2})
	for c in chests:
		if not bool(c["opened"]):
			continue
		c["opened"] = false
		(c["node"] as MeshInstance3D).visible = true
		if is_instance_valid(c["marker"]):
			(c["marker"] as Node).queue_free()
		c["marker"] = _marker("CACHE", (c["pos"] as Vector3) + Vector3(0, 2.2, 0), Color(1.0, 0.8, 0.3))

func _lava(dt: float) -> void:
	if lavas.is_empty():
		return
	for l in lavas:
		var d: float = Vector2(player.global_position.x - (l["pos"] as Vector3).x, player.global_position.z - (l["pos"] as Vector3).z).length()
		if d < float(l["r"]) and player.global_position.y < 0.6:
			_hurt_player(10.0 * dt)

func _gate(dt: float) -> void:
	var unseal_at := 240.0 if stage == 2 else 300.0
	if stage_t >= unseal_at and gate_sealed:
		gate_sealed = false
		if gate_node:
			(gate_node.material_override as StandardMaterial3D).emission_energy_multiplier = 2.5
			if gate_node.has_meta("marker"):
				var mk := gate_node.get_meta("marker") as Label3D
				if is_instance_valid(mk):
					mk.text = "SANCTUM · OPEN"
					mk.modulate = Color(1.0, 0.85, 0.3)
		sfx.call("play", "boss")
	if not gate_sealed and not warden_spawned:
		var gp := Vector3(0, 0, -ARENA.y * 0.5 + 2.0)
		if player.global_position.distance_to(gp) < 3.0:
			warden_spawned = true
			_spawn_warden(gp)

func _spawn_warden(gp: Vector3) -> void:
	var e := Node3D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	add_child(e)
	e.position = gp
	e.call("setup", true, (1.0 + t / 120.0) * (1.6 if stage == 2 else 1.0))
	e.set("max_hp", float(e.get("max_hp")) * 8.0)
	e.set("hp", float(e.get("max_hp")))
	e.set("speed", 2.6 if stage == 2 else 2.0)
	e.set("contact", 30.0 if stage == 2 else 25.0)
	e.set("radius", 1.6)
	enemies.append(e)
	warden = e
	_announce("THE NAVE TYRANT" if stage == 2 else "THE GATE WARDEN", 3.0)

func _tracers(dt: float) -> void:
	var done: Array = []
	for tr in tracers:
		tr["life"] = float(tr["life"]) - dt
		if float(tr["life"]) <= 0.0:
			done.append(tr)
			if is_instance_valid(tr["node"] as Node):
				(tr["node"] as Node).queue_free()
	for tr in done:
		tracers.erase(tr)

func _vendor(dt: float) -> void:
	vendor_cd = maxf(0.0, vendor_cd - dt)
	var d: float = player.global_position.distance_to(Vector3(10, 0, 8))
	if d < 2.2 and vendor_cd <= 0.0 and gold >= vendor_cost:
		gold -= vendor_cost
		vendor_cd = 1.0
		player.set("hp", minf(float(player.get("max_hp")), float(player.get("hp")) + 20.0))
		var keys := ["quantity", "zeal", "radius", "swiftness"]
		var k: String = keys[randi() % keys.size()]
		tomes[k] = int(tomes[k]) + 1
		if k == "swiftness":
			player.set("walk_mult", float(player.get("walk_mult")) + 0.08)
		vendor_cost *= 2
		sfx.call("play", "chest")
		trauma = minf(1.0, trauma + 0.2)

func _warden_fight(dt: float) -> void:
	if warden == null or not is_instance_valid(warden):
		warden = null
		return
	if not warden_enraged and float(warden.get("hp")) < float(warden.get("max_hp")) * 0.3:
		warden_enraged = true
		warden.set("contact", 32.0)
		_announce("THE WARDEN RAGES")
	warden_cd -= dt
	if warden_cd > 0.0:
		return
	warden_cd = 3.0 if warden_enraged else 6.0
	if warden_phase % 2 == 0:
		for i in 4:
			if enemies.size() < 140:
				_spawn_enemy(false, false, "chaser")
		sfx.call("play", "boss")
	else:
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.2
		tor.outer_radius = 1.0
		ring.mesh = tor
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 0.3, 0.2)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.2, 0.1)
		m.emission_energy_multiplier = 2.5
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = m
		ring.position = (warden as Node3D).global_position + Vector3(0, 0.6, 0)
		add_child(ring)
		rings.append({"pos": (warden as Node3D).global_position, "r": 1.0, "node": ring, "hit": false})
		sfx.call("play", "slam")
	warden_phase += 1

func _rings(dt: float) -> void:
	var done: Array = []
	for r in rings:
		r["r"] = float(r["r"]) + dt * 7.0
		var n := r["node"] as MeshInstance3D
		if not is_instance_valid(n):
			done.append(r)
			continue
		n.scale = Vector3(float(r["r"]), 1.0, float(r["r"]))
		var pd: float = Vector2(player.global_position.x - (r["pos"] as Vector3).x, player.global_position.z - (r["pos"] as Vector3).z).length()
		if not bool(r["hit"]) and absf(pd - float(r["r"])) < 1.2 and player.global_position.y < 1.0:
			r["hit"] = true
			_hurt_player(20.0)
		if float(r["r"]) > 12.0:
			done.append(r)
			n.queue_free()
	for r in done:
		rings.erase(r)

func _spawn_damage_number(pos: Vector3, amount: int) -> void:
	if dmg_label_count > 40:
		return
	dmg_label_count += 1
	var l := Label3D.new()
	l.text = str(amount)
	l.font_size = 64
	l.modulate = Color(1, 0.95, 0.7)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.no_depth_test = true
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", pos.y + 1.2, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_free_damage_number.bind(l))

func _free_damage_number(l: Label3D) -> void:
	dmg_label_count = maxi(0, dmg_label_count - 1)
	l.queue_free()

func _juice(dt: float) -> void:
	trauma = maxf(0.0, trauma - dt * 1.8)
	dmg_flash = maxf(0.0, dmg_flash - dt * 1.4)
	if vignette:
		vignette.color.a = dmg_flash * 0.45
	# player owns FOV; game only adds positional shake here
	if cam:
		var sh := trauma * trauma * 0.6 * shake_mult
		cam.h_offset = randf_range(-sh, sh) if shake_mult > 0.0 else 0.0
		cam.v_offset = randf_range(-sh, sh) if shake_mult > 0.0 else 0.0
	# slam AoE hook from player
	if player.get("just_slammed"):
		player.set("just_slammed", false)
		_damage_area(player.global_position, 3.0 + tomes["radius"] * 0.4, 30.0, true)
		sfx.call("play", "slam")
		trauma = minf(1.0, trauma + 0.55)
		player.set("trauma", minf(1.0, float(player.get("trauma")) + 0.55))
		hitstop_t = 0.045

func _hud(dt: float) -> void:
	var mins := int(t) / 60
	var secs := int(t) % 60
	hud_label.text = "S%d HP %.0f | LV %d XP %.0f/%.0f | %02d:%02d / 10:00 | Kills %d | Gold %d | Enemies %d" % [
		stage, maxf(0.0, float(player.get("hp"))), level, xp, xp_next, mins, secs, kills, gold, enemies.size()]
	style = maxf(0.0, style - dt * 0.05)
	var rank := _style_rank()
	style_label.text = rank[0]
	style_label.add_theme_color_override("font_color", rank[1])
	var mh := hud_layer.get_node_or_null("MouseHint") as Label
	if mh:
		mh.visible = (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED) and not get_tree().paused and not draft_open and not game_over
	var obj := hud_layer.get_node_or_null("Objective") as Label
	if obj:
		if warden_spawned and warden != null:
			obj.text = "SLAY THE WARDEN"
		elif not gate_sealed:
			obj.text = "THE GATE IS OPEN — enter the golden ring (north)"
		else:
			var left := int(300.0 - t)
			obj.text = "Survive · gather grace · Gate opens in %d:%02d" % [left / 60, left % 60]

func _show_end(won: bool) -> void:
	if won:
		meta["victories"] = int(meta["victories"]) + 1
	_save_meta()
	_record_run(won)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 42)
	l.text = "ASCENDED — Gate sealed" if won else "FELL — the choir fades"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_layer.add_child(l)
	var s := Label.new()
	s.add_theme_font_size_override("font_size", 20)
	var mins := int(t) / 60
	var secs := int(t) % 60
	s.text = "Lv %d · %d kills · %d gold · %02d:%02d — press R to try again" % [level, kills, gold, mins, secs]
	s.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position.y -= 60
	hud_layer.add_child(s)
