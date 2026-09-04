extends Node3D
## Grace (XP) / manna (gold) orb with magnet handled by game.gd.
var value := 1.0
var gold := 0
var mesh: MeshInstance3D
var t := 0.0

func setup(pos: Vector3, elite: bool) -> void:
	global_position = pos + Vector3(0, 0.6, 0)
	value = 5.0 if elite else 1.0
	gold = 2 if elite else 0
	mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28 if elite else 0.18
	sm.height = 0.56 if elite else 0.36
	mesh.mesh = sm
	var m := StandardMaterial3D.new()
	if elite:
		m.albedo_color = Color(1, 0.85, 0.3)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.15)
		m.emission_energy_multiplier = 2.2
	else:
		m.albedo_color = Color(0.6, 0.85, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.35, 0.7, 1.0)
		m.emission_energy_multiplier = 1.6
	mesh.material_override = m
	add_child(mesh)

func _process(dt: float) -> void:
	t += dt
	if mesh:
		mesh.position.y = 0.2 + sin(t * 5.0) * 0.12
		mesh.rotation.y += dt * 2.0
