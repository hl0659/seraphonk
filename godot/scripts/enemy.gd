extends Node3D
## Fallen enemy — chaser with hit-flash. Types: normal / elite(mini-boss).
var hp := 20.0
var max_hp := 20.0
var speed := 3.2
var radius := 0.6
var contact := 8.0
var elite := false
var flying := false
var base_y := 0.0
var mesh: MeshInstance3D
var mat: StandardMaterial3D
var flash := 0.0

func setup(p_elite: bool, hp_scale: float, p_flying: bool = false) -> void:
	elite = p_elite
	flying = p_flying and not p_elite
	var mult := 6.0 if elite else 1.0
	max_hp = (90.0 if elite else 20.0) * hp_scale * mult / (6.0 if elite else 1.0)
	if elite:
		max_hp = 90.0 * hp_scale
	hp = max_hp
	speed = (3.4 if elite else 4.6 + randf() * 1.4) * (1.0 + hp_scale * 0.03)
	radius = 1.1 if elite else 0.6
	contact = 16.0 if elite else 8.0
	if flying:
		hp = 12.0 * hp_scale
		max_hp = hp
		speed = 5.5
		radius = 0.45
		contact = 6.0
		base_y = 3.0
		mesh = MeshInstance3D.new()
		var wm := SphereMesh.new()
		wm.radius = radius
		wm.height = radius * 2.0
		mesh.mesh = wm
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.9, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.8, 1.0)
		mat.emission_energy_multiplier = 2.0
		mesh.material_override = mat
		mesh.position.y = base_y
		add_child(mesh)
		return
	if ResourceLoader.exists("res://assets/models/fallen.glb"):
		var ps := load("res://assets/models/fallen.glb") as PackedScene
		if ps:
			mesh = null
			var inst := ps.instantiate() as Node3D
			var sc := (radius * 1.6) if not elite else 2.2
			inst.scale = Vector3(sc, sc, sc)
			add_child(inst)
			mat = StandardMaterial3D.new()  # dummy for flash path
			return
	mesh = MeshInstance3D.new()
	if elite:
		var sm := SphereMesh.new()
		sm.radius = radius
		sm.height = radius * 2.4
		mesh.mesh = sm
	else:
		var cm := CapsuleMesh.new()
		cm.radius = radius
		cm.height = radius * 3.0
		mesh.mesh = cm
	mat = StandardMaterial3D.new()
	if elite:
		mat.albedo_color = Color(0.45, 0.08, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.15, 0.2)
		mat.emission_energy_multiplier = 1.4
	else:
		var tint := randf()
		if tint < 0.4:
			mat.albedo_color = Color(0.2, 0.12, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.5, 0.2, 0.9)
			mat.emission_energy_multiplier = 0.7
		elif tint < 0.75:
			mat.albedo_color = Color(0.3, 0.1, 0.1)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.25, 0.15)
			mat.emission_energy_multiplier = 0.7
		else:
			mat.albedo_color = Color(0.12, 0.2, 0.18)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.8, 0.5)
			mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat
	mesh.position.y = radius * 1.5
	add_child(mesh)
	# thorn crown for readability
	if elite:
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.15
		tor.outer_radius = radius + 0.5
		ring.mesh = tor
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(1, 0.8, 0.3)
		rm.emission_enabled = true
		rm.emission = Color(1, 0.7, 0.2)
		rm.emission_energy_multiplier = 2.0
		ring.material_override = rm
		ring.position.y = radius * 2.6
		add_child(ring)

func damage(amount: float, from: Vector3) -> void:
	hp -= amount
	flash = 1.0
	# knockback away from hit (heft without physics)
	var push: Vector3 = global_position - from
	push.y = 0.0
	if push.length() > 0.01:
		global_position += push.normalized() * (0.25 if not elite else 0.05)

func _process(dt: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - dt * 6.0)
		mat.emission_energy_multiplier = 0.7 + flash * 3.0
	if flying:
		# hover + bob; game.gd steers XZ and dive
		mesh.position.y = base_y + sin(Time.get_ticks_msec() / 280.0 + float(get_instance_id() % 10)) * 0.4
		mesh.rotation.y += dt * 3.0
		return
	# hover bob
	if mesh:
		mesh.position.y = radius * 1.5 + sin(Time.get_ticks_msec() / 300.0 + float(get_instance_id() % 10)) * 0.15
