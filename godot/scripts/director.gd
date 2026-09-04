extends Node3D
## Wave director — ports engine/waves.py. Budget curve + mini-boss + Wrath.
const RUN_LEN := 600.0
var t := 0.0

func budget(tt: float) -> float:
	var m := tt / 60.0
	return 4.0 + 6.0 * m + 2.5 * m * m

func _process(dt: float) -> void:
	t += dt
	# TODO M2-3D: spawn = budget(t), mini-boss every 90s, Wrath swarm at RUN_LEN
	if t >= RUN_LEN:
		pass  # wrath swarm — ends run cleanly like Megabonk timer
