extends Node3D
## SERAPHONK — game manager. Builds arena in code, runs director/combat/UI/juice.
## Design refs: Megabonk loop (auto-weapons, XP/tomes, gate+boss, 10:00 Wrath),
## Ultrakill movement (dash i-frames, slide momentum, slam AoE), juice tiers
## (hitstop 40-120ms, shake 0.15-0.25s decay, FOV kick, damage numbers).

const RUN_LEN := 600.0
const ARENA := Vector2(40.0, 30.0)

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
	player = $Player
	cam = $Player/Cam
	cam_base_fov = cam.fov
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

func _start_game() -> void:
	hud_layer.get_node("StartDim").queue_free()
	hud_layer.get_node("StartCenter").queue_free()
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	floor_body.add_child(mesh)
	floor_body.position = Vector3(0, -0.25, 0)
	add_child(floor_body)
	# glowing choir pillars (cover + slam reference)
	var pillar_pos := [Vector3(-12, 0, -8), Vector3(12, 0, -8), Vector3(-12, 0, 8), Vector3(12, 0, 8), Vector3(0, 0, 0)]
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
	# jumpable choir platforms (slam-from-above plays, escape routes)
	var plat_spots := [[Vector3(-6, 0, 4), 1.0], [Vector3(6, 0, -4), 1.0], [Vector3(0, 0, -9), 1.9]]
	for ps in plat_spots:
		var ppos: Vector3 = ps[0]
		var ph: float = ps[1]
		var pb := StaticBody3D.new()
		var pc := CollisionShape3D.new()
		var pbox := BoxShape3D.new()
		pbox.size = Vector3(4.0, 0.4, 4.0)
		pc.shape = pbox
		pc.position.y = ph - 0.2
		pb.add_child(pc)
		var pm2 := MeshInstance3D.new()
		var pmm := BoxMesh.new()
		pmm.size = Vector3(4.0, 0.4, 4.0)
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

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud_label = Label.new()
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
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.text = "WASD move · SHIFT dash · SPACE jump · CTRL slide/slam · aim with crosshair"
	title_label.position = Vector2(12, 34)
	hud_layer.add_child(title_label)
	var objective := Label.new()
	objective.name = "Objective"
	objective.add_theme_font_size_override("font_size", 17)
	objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(objective)
	var cross := ColorRect.new()
	cross.name = "Crosshair"
	cross.color = Color(1, 0.95, 0.8)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-2, -2)
	cross.size = Vector2(4, 4)
	hud_layer.add_child(cross)
	pause_label = Label.new()
	pause_label.add_theme_font_size_override("font_size", 42)
	pause_label.text = "PAUSED — ESC resume · R restart"
	pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.visible = false
	hud_layer.add_child(pause_label)

func _build_shrines_chests() -> void:
	var shrine_spots := [Vector3(-16, 0, 0), Vector3(16, 0, 0), Vector3(0, 0, 10)]
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
		shrines.append({"pos": shrine_spots[i], "r": 2.5, "progress": 0.0, "done": false, "node": ring})
	var chest_spots := [Vector3(-8, 0, -11), Vector3(8, 0, -11), Vector3(0, 0, 12)]
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
		chests.append({"pos": chest_spots[i], "cost": 20 + i * 10, "opened": false, "node": box})

func _process(dt: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().paused = not get_tree().paused
		pause_label.visible = get_tree().paused
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED
		return
	if Input.is_key_pressed(KEY_R):
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	if game_over or draft_open or get_tree().paused:
		return
	if hitstop_t > 0.0:
		hitstop_t -= dt
		return
	t += dt
	_director(dt)
	_weapons(dt)
	_enemies(dt)
	_projectiles(dt)
	_pickups(dt)
	_shrines(dt)
	_chests()
	_gate(dt)
	_juice(dt)
	_hud()
	# dash whoosh edge
	var dnow: float = float(player.get("dash_t"))
	if dnow > 0.0 and prev_dash <= 0.0:
		sfx.call("play", "dash")
	prev_dash = dnow

func _director(dt: float) -> void:
	# spawn pressure from budget curve; cap alive for perf (Megabonk-like chaos without meltdown)
	var alive := enemies.size()
	var want := int(minf(budget(t) * 0.6, 110.0))
	spawn_acc += dt * (2.0 + t / 45.0)
	var tick := int(t) % 90 == 0 and t > 5.0
	var key := int(t)
	if tick and not miniboss_done.get(key, false):
		miniboss_done[key] = true
		_spawn_enemy(true)
	while spawn_acc >= 1.0 and alive < want:
		spawn_acc -= 1.0
		_spawn_enemy(false, randf() < 0.3)
		alive += 1
	if t >= RUN_LEN and not victory:
		# Wrath swarm: flood + end pressure
		for i in 12:
			_spawn_enemy(false, false)

func _spawn_enemy(elite: bool, flying: bool = false) -> void:
	var e := Node3D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	var ang := randf() * TAU
	var r := 22.0 + randf() * 6.0
	var pp: Vector3 = player.global_position
	e.position = Vector3(clampf(pp.x + cos(ang) * r, -ARENA.x * 0.5 + 1.0, ARENA.x * 0.5 - 1.0), 0, clampf(pp.z + sin(ang) * r, -ARENA.y * 0.5 + 1.0, ARENA.y * 0.5 - 1.0))
	add_child(e)
	var hp_scale := 1.0 + t / 120.0
	e.call("setup", elite, hp_scale, flying)
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
			_chakram_burst(int(w["lvl"]) + qty - 1, 3.2 + tomes["radius"] * 0.5, 10.0 + w["lvl"] * 4.0)
		elif w["id"] == "trumpet":
			w["cd"] = maxf(0.3, 1.1 - w["lvl"] * 0.08)
			_trumpet_volley(qty + int(w["lvl"]) / 2, 12.0 + w["lvl"] * 5.0)

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

func _chakram_burst(count: int, radius: float, dmg: float) -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + t * 2.0
		var hit_pos := player.global_position + Vector3(cos(a), 0, sin(a)) * radius
		_damage_area(hit_pos, 1.6 + tomes["radius"] * 0.25, dmg, false)

func _trumpet_volley(count: int, dmg: float) -> void:
	# FPS aim: crosshair ray — best target inside a narrow cone, else straight ahead
	var aim: Vector3 = -cam.global_transform.basis.z
	var target := _enemy_in_crosshair(0.985)
	var base_dir: Vector3 = ((target.global_position + Vector3(0, 1.2, 0)) - (player.global_position + Vector3(0, 1.5, 0))).normalized() if target else aim
	for i in count:
		var p := Node3D.new()
		p.set_script(load("res://scripts/projectile.gd"))
		add_child(p)
		var dir: Vector3 = base_dir.rotated(Vector3.UP, (float(i) - float(count - 1) * 0.5) * 0.1)
		p.call("setup", player.global_position + Vector3(0, 1.5, 0), dir, 26.0, dmg, 2.5)
		projectiles.append(p)
	sfx.call("play", "shoot")

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
			var anchor: Vector3 = pp + Vector3(0, 1.4, 0)
			var to: Vector3 = anchor - en.global_position
			var fd := to.length()
			if fd > 0.1:
				var fspd: float = float(en.get("speed"))
				en.global_position += to.normalized() * fspd * dt
				en.global_position.y = clampf(en.global_position.y, 1.2, 6.0)
			if fd < 1.5 and float(player.get("iframes_t")) <= 0.0:
				player.set("hp", float(player.get("hp")) - float(en.get("contact")) * dt * 3.0)
				if float(player.get("hp")) <= 0.0 and not game_over:
					game_over = true
					sfx.call("play", "die")
					_show_end(false)
			continue
		var to_p: Vector3 = pp - en.global_position
		to_p.y = 0.0
		var d := to_p.length()
		if d > 0.05:
			var spd: float = float(en.get("speed"))
			en.global_position += to_p.normalized() * spd * dt
		# separation (cheap, sampled)
		# contact damage with player i-frames respected
		if d < 1.1 + float(en.get("radius")):
			if float(player.get("iframes_t")) <= 0.0:
				player.set("hp", float(player.get("hp")) - float(en.get("contact")) * dt * 3.0)
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
				en.call("damage", float(pr.get("dmg")), pr.global_position)
				_spawn_damage_number(en.global_position + Vector3(0, 2.0, 0), int(float(pr.get("dmg"))))
				if float(en.get("hp")) <= 0.0:
					_kill_enemy(en, false)
				pr.set("dead", true)
				dead.append(p)
				break
	for p in dead:
		projectiles.erase(p)
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

func _draft_options() -> Array:
	var pool: Array = [
		{"kind": "weapon", "id": "trumpet", "label": "Trumpet Volley (auto, nearest)"},
		{"kind": "up", "id": "chakram", "label": "Empower Chakram +dmg"},
		{"kind": "tome", "id": "quantity", "label": "Tome of Quantity +projectile"},
		{"kind": "tome", "id": "zeal", "label": "Tome of Zeal +attack speed"},
		{"kind": "tome", "id": "radius", "label": "Tome of Radius +area/magnet"},
		{"kind": "tome", "id": "swiftness", "label": "Feather of Swiftness +move"},
	]
	pool.shuffle()
	return pool.slice(0, 3)

func _pick_draft(o: Dictionary) -> void:
	if o["kind"] == "weapon":
		var has := false
		for w in weapons:
			if w["id"] == o["id"]:
				has = true
		if not has and weapons.size() < 4:
			weapons.append({"id": o["id"], "lvl": 1, "cd": 0.0})
	elif o["kind"] == "up":
		for w in weapons:
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

func _gate(dt: float) -> void:
	if t >= 300.0 and gate_sealed:
		gate_sealed = false
		if gate_node:
			(gate_node.material_override as StandardMaterial3D).emission_energy_multiplier = 2.5
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
	e.call("setup", true, 1.0 + t / 120.0)
	e.set("max_hp", float(e.get("max_hp")) * 8.0)
	e.set("hp", float(e.get("max_hp")))
	e.set("speed", 2.0)
	e.set("contact", 25.0)
	e.set("radius", 1.6)
	enemies.append(e)
	warden = e
	sfx.call("play", "boss")

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
	# player owns FOV; game only adds positional shake here
	if cam:
		var sh := trauma * trauma * 0.6
		cam.h_offset = randf_range(-sh, sh)
		cam.v_offset = randf_range(-sh, sh)
	# slam AoE hook from player
	if player.get("just_slammed"):
		player.set("just_slammed", false)
		_damage_area(player.global_position, 3.0 + tomes["radius"] * 0.4, 30.0, true)
		sfx.call("play", "slam")
		trauma = minf(1.0, trauma + 0.55)
		player.set("trauma", minf(1.0, float(player.get("trauma")) + 0.55))
		hitstop_t = 0.045

func _hud() -> void:
	var mins := int(t) / 60
	var secs := int(t) % 60
	hud_label.text = "HP %.0f | LV %d XP %.0f/%.0f | %02d:%02d / 10:00 | Kills %d | Gold %d | Enemies %d" % [
		float(player.get("hp")), level, xp, xp_next, mins, secs, kills, gold, enemies.size()]
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
