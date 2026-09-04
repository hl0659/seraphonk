extends SceneTree
## Content test: cantor fire, warden rings, vendor purchase.
## Run: godot --headless --path godot -s res://tools/sim_content.gd
var frames := 0
var game: Node = null
var player: CharacterBody3D = null
var booted := false
var checks := {}
var seen_orbs := false
var sim_k0 := 0

func note(key: String, ok: bool) -> void:
	checks[key] = ok
	print("SIM2 CHECK ", key, " = ", "PASS" if ok else "FAIL")

func _process(_dt: float) -> bool:
	if not booted:
		booted = true
		var ps := load("res://scenes/main.tscn") as PackedScene
		game = ps.instantiate()
		root.add_child(game)
		player = game.get_node("Player") as CharacterBody3D
		player.set("hp", 5000.0)
		player.set("max_hp", 5000.0)
		print("SIM2: booted")
		return false
	frames += 1
	if (game.get("eprojectiles") as Array).size() > 0:
		seen_orbs = true
	if bool(game.get("draft_open")):
		var vb: VBoxContainer = game.get("draft_panel").get_node("Choices")
		for c in vb.get_children():
			if c is Button:
				(c as Button).pressed.emit()
				break
	match frames:
		10:
			game.set("t", 130.0)
			game.call("_spawn_enemy", false, false, "brute")
			var es: Array = game.get("enemies")
			if es.size() > 0:
				(es[es.size() - 1] as Node3D).global_position = player.global_position + Vector3(6, 0, 0)
			game.call("_spawn_enemy", false, false, "cantor")
			var es2: Array = game.get("enemies")
			if es2.size() > 0:
				(es2[es2.size() - 1] as Node3D).global_position = player.global_position + Vector3(12, 0, 0)
		700:
			note("cantor_fires", seen_orbs)
			var charged := false
			for e in game.get("enemies"):
				if String((e as Node).get("kind")) == "brute" and int((e as Node).get("charge_state")) > 0:
					charged = true
			note("brute_charges", charged)
			game.set("t", 301.0)
		800:
			player.global_position = Vector3(0, 0.5, -13)
		1050:
			# deterministic style seed: real kill through the real damage path
			game.call("_damage_area", player.global_position, 30.0, 999.0, false)
		1100:
			note("style_grows", float(game.get("style")) > 0.0)
			note("warden_rings", (game.get("rings") as Array).size() > 0 or int(game.get("warden_phase")) > 0)
			game.set("gold", 500)
			player.global_position = Vector3(10, 0.5, 8)
		1400:
			note("vendor_sells", int(game.get("vendor_cost")) > 30)
		1500:
			for w in game.get("weapons"):
				if w["id"] == "chakram":
					w["lvl"] = 5
			(game.get("tomes") as Dictionary)["quantity"] = 2
			var offered := false
			for o in game.call("_draft_options"):
				if (o as Dictionary).get("kind") == "evolve":
					offered = true
					game.call("_pick_draft", o)
			note("evolve_offered", offered)
			(game.get("weapons") as Array).append({"id": "beams", "lvl": 3, "cd": 0.0})
		1600:
			sim_k0 = int(game.get("kills"))
			var pre_ids: Array = []
			for w in game.get("weapons"):
				pre_ids.append(w["id"])
			note("wheel_equipped", "wheel" in pre_ids)
			# isolate beams: strip other weapons so any kill is the rail
			game.set("weapons", [{"id": "beams", "lvl": 3, "cd": 0.0}])
			# park a chaser 10m down the crosshair: player faces -Z from spawn
			player.global_position = Vector3(0, 0.5, 6)
			(player as CharacterBody3D).rotation.y = 0.0
			game.call("_spawn_enemy", false, false, "chaser")
			var es3: Array = game.get("enemies")
			if es3.size() > 0:
				(es3[es3.size() - 1] as Node3D).global_position = Vector3(0, 0, -4)
		1700:
			pass  # wheel checked at 1600 (pre-strip)
		1750:
			note("beams_kill", int(game.get("kills")) > sim_k0)
			game.set("t", 59.0)
		2100:
			note("surge_event", float(game.get("surge_t")) > 0.0)
			game.set("t", 301.0)
		2200:
			player.global_position = Vector3(0, 0.5, -13)
		2500:
			note("warden_spawned", game.get("warden") != null)
			if game.get("warden") != null:
				(game.get("warden") as Node).set("hp", float((game.get("warden") as Node).get("max_hp")) * 0.1)
		2700:
			note("warden_enraged", bool(game.get("warden_enraged")))
			if game.get("warden") != null:
				var wp: Vector3 = (game.get("warden") as Node3D).global_position
				game.call("_damage_area", wp, 10.0, 999999.0, true)
		2900:
			note("victory_on_warden_kill", bool(game.get("victory")))
			game.set("victory", false)
			game.set("t", 601.0)
		3100:
			note("wrath_swarm", (game.get("enemies") as Array).size() >= 10)
	if frames >= 3300:
		print("SIM2: done. summary:")
		for k in checks.keys():
			print("  ", k, "=", "PASS" if checks[k] else "FAIL")
		return true
	return false
