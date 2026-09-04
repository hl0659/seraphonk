extends SceneTree
## Soak test: 4x speed survival with a dumb circle-strafe bot. Reports balance curve.
## Run: godot --headless --path godot -s res://tools/sim_soak.gd
var frames := 0
var game: Node = null
var player: CharacterBody3D = null
var booted := false

func _process(_dt: float) -> bool:
	if not booted:
		booted = true
		Engine.time_scale = 4.0
		var ps := load("res://scenes/main.tscn") as PackedScene
		game = ps.instantiate()
		root.add_child(game)
		player = game.get_node("Player") as CharacterBody3D
		print("SOAK: booted at 4x")
		return false
	frames += 1
	if frames == 5:
		Input.action_press("move_forward")
		Input.action_press("ui_left")
	if frames % 1200 == 0:
		if Input.is_action_pressed("ui_left"):
			Input.action_release("ui_left")
			Input.action_press("ui_right")
		else:
			Input.action_release("ui_right")
			Input.action_press("ui_left")
	if bool(game.get("draft_open")):
		var vb: VBoxContainer = game.get("draft_panel").get_node("Choices")
		for c in vb.get_children():
			if c is Button:
				(c as Button).pressed.emit()
				break
	if frames % 1500 == 0:
		print("SOAK f=%d t=%d hp=%.0f enemies=%d eproj=%d kills=%d lvl=%d gold=%d tomes=%s" % [
			frames, int(float(game.get("t"))), float(player.get("hp")),
			(game.get("enemies") as Array).size(), (game.get("eprojectiles") as Array).size(),
			int(game.get("kills")), int(game.get("level")), int(game.get("gold")),
			str(game.get("tomes"))])
		if bool(game.get("game_over")):
			print("SOAK: bot died at t=", int(float(game.get("t"))), " kills=", int(game.get("kills")))
			return true
	if float(game.get("t")) >= 330.0 or frames >= 14000:
		print("SOAK: survived to t=", int(float(game.get("t"))), " kills=", int(game.get("kills")))
		return true
	return false
