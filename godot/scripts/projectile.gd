extends Node3D
## Trumpet bolt — pooled projectile, manual motion.
var vel := Vector3.ZERO
var dmg := 10.0
var life := 3.0
var dead := false
var hostile := false
var mesh: MeshInstance3D

func setup(from: Vector3, dir: Vector3, speed: float, p_dmg: float, p_life: float, p_hostile: bool = false) -> void:
	global_position = from
	vel = dir.normalized() * speed
	dmg = p_dmg
	life = p_life
	hostile = p_hostile
	mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.26 if hostile else 0.18
	sm.height = 0.52 if hostile else 0.36
	mesh.mesh = sm
	var m := StandardMaterial3D.new()
	if hostile:
		m.albedo_color = Color(1, 0.3, 0.6)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.1, 0.4)
		m.emission_energy_multiplier = 2.5
	else:
		m.albedo_color = Color(1, 0.95, 0.7)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.85, 0.4)
		m.emission_energy_multiplier = 2.5
	mesh.material_override = m
	add_child(mesh)

func tick(dt: float) -> void:
	if dead:
		return
	life -= dt
	global_position += vel * dt
	if life <= 0.0 or absf(global_position.x) > 22.0 or absf(global_position.z) > 17.0:
		dead = true
		queue_free()
