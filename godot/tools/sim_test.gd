extends SceneTree
## Scripted systems test: exercises draft/trumpet/slam/shrine/chest/warden/wrath.
## Run: godot --headless --path godot -s res://tools/sim_test.gd
var frames := 0
var game: Node = null
var player: CharacterBody3D = null
var booted := false
var checks := {}

func note(key: String, ok: bool) -> void:
	checks[key] = ok
	print("SIM CHECK ", key, " = ", "PASS" if ok else "FAIL")

func _process(_dt: float) -> bool:
	if not booted:
		booted = true
		var ps := load("res://scenes/main.tscn") as PackedScene
		game = ps.instantiate()
		root.add_child(game)
		player = game.get_node("Player") as CharacterBody3D
		print("SIM: booted")
		return false
	frames += 1
	# auto-pick draft blessings (except the single frame we assert on)
	if bool(game.get("draft_open")) and frames != 1000:
		var vb: VBoxContainer = game.get("draft_panel").get_node("Choices")
		for c in vb.get_children():
			if c is Button:
				print("SIM: picking draft: ", (c as Button).text)
				(c as Button).pressed.emit()
				break
	match frames:
		5:
			Input.action_press("move_forward")
			player.set("hp", 5000.0)
			player.set("max_hp", 5000.0)
		300:
			Input.action_press("ui_right")
		600:
			Input.action_release("ui_right")
		900:
			game.call("_open_draft")
		1000:
			note("draft_resumed", not bool(game.get("draft_open")) and not paused)
			(game.get("weapons") as Array).append({"id": "trumpet", "lvl": 1, "cd": 0.0})
		1400:
			note("trumpet_fires", (game.get("projectiles") as Array).size() > 0 or int(game.get("kills")) > 0)
		1500:
			player.global_position = Vector3(0, 10, 0)
			player.set("slamming", true)
			(player as CharacterBody3D).velocity = Vector3(0, -28, 0)
		1700:
			note("slam_landed", not bool(player.get("slamming")) and player.global_position.y < 1.0)
		1750:
			Input.action_release("move_forward")
		1800:
			player.global_position = Vector3(-16, 0.5, 0)
			(player as CharacterBody3D).velocity = Vector3.ZERO
		2100:
			pass  # channeling... (headless runs ~150fps: 300 frames ~= 2s)
		2400:
			var done := false
			for s in game.get("shrines"):
				if bool(s["done"]):
					done = true
			note("shrine_channel", done)
			game.set("gold", 500)
			player.global_position = Vector3(-8, 0.5, -11)
		2700:
			note("chest_open", int(game.get("chest_count")) > 0)
		2800:
			game.set("t", 301.0)
		2900:
			note("gate_unsealed", not bool(game.get("gate_sealed")))
			player.global_position = Vector3(0, 0.5, -13)
		3200:
			note("warden_spawned", game.get("warden") != null)
			if game.get("warden") != null:
				var wp: Vector3 = (game.get("warden") as Node3D).global_position
				game.call("_damage_area", wp, 10.0, 999999.0, true)
		3500:
			note("victory_on_warden_kill", bool(game.get("victory")))
			Input.action_press("move_forward")
		3600:
			game.set("victory", false)
			game.set("t", 601.0)
		3800:
			note("wrath_swarm", (game.get("enemies") as Array).size() >= 10)
	if frames % 600 == 0:
		print("SIM f=%d t=%.0f hp=%.0f enemies=%d kills=%d lvl=%d w=%d" % [
			frames, float(game.get("t")), float(player.get("hp")),
			(game.get("enemies") as Array).size(), int(game.get("kills")),
			int(game.get("level")), (game.get("weapons") as Array).size()])
	if frames >= 4000:
		print("SIM: done. summary:")
		for k in checks.keys():
			print("  ", k, "=", "PASS" if checks[k] else "FAIL")
		return true
	return false
