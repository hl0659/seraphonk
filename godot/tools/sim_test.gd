extends SceneTree
## Headless playtest bot: loads main scene, holds W, turns, reports state.
## Run: godot --headless --path godot -s res://tools/sim_test.gd
var frames := 0
var game: Node = null
var player: Node3D = null
var booted := false

func _process(_dt: float) -> bool:
	if not booted:
		booted = true
		var ps := load("res://scenes/main.tscn") as PackedScene
		if ps == null:
			print("SIM: FAIL scene load")
			return true
		game = ps.instantiate()
		root.add_child(game)
		player = game.get_node("Player") as Node3D
		print("SIM: booted")
		return false
	frames += 1
	if frames == 5:
		Input.action_press("move_forward")
	if frames == 300:
		Input.action_press("ui_right")
	if frames == 600:
		Input.action_release("ui_right")
	if frames == 900:
		print("SIM: forcing draft + slam test")
		game.call("_open_draft")
		(player as CharacterBody3D).velocity.y = 8.0
	if frames % 120 == 0:
		var pp: Vector3 = player.global_position
		print("SIM f=%d t=%.1f paused=%s draft=%s pos=(%.1f,%.1f,%.1f) yaw=%.2f hp=%.0f enemies=%d kills=%d xp=%.0f/%.0f lvl=%d proj=%d pickups=%d" % [
			frames, float(game.get("t")), str(paused), bool(game.get("draft_open")),
			pp.x, pp.y, pp.z, float(player.get("yaw")), float(player.get("hp")),
			(game.get("enemies") as Array).size(), int(game.get("kills")),
			float(game.get("xp")), float(game.get("xp_next")), int(game.get("level")),
			(game.get("projectiles") as Array).size(), (game.get("pickups") as Array).size()])
		if bool(game.get("draft_open")):
			var vb: VBoxContainer = game.get("draft_panel").get_node("Choices")
			var btns: Array = []
			for c in vb.get_children():
				if c is Button:
					btns.append(c)
			if btns.size() > 0:
				print("SIM: picking draft: ", (btns[0] as Button).text)
				(btns[0] as Button).pressed.emit()
	if frames >= 1500:
		print("SIM: done")
		return true
	return false
