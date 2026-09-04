extends Node3D
## Fallen enemy — chaser with hit-flash. Types: normal / elite(mini-boss).
var hp := 20.0
var max_hp := 20.0
var speed := 3.2
var radius := 0.6
var contact := 8.0
var elite := false
var flying := false
var kind := "chaser"  # chaser | wisp(flying) | cantor(shooter) | brute(charger)
var fire_cd := 0.0
var charge_state := 0  # 0 roam, 1 telegraph, 2 charge, 3 recover
var charge_t := 0.0
var charge_dir := Vector3.ZERO
var base_y := 0.0
var mesh: MeshInstance3D
var mat: StandardMaterial3D
var flash := 0.0
var touch_cd := 0.0

func setup(p_elite: bool, hp_scale: float, p_flying: bool = false, p_kind: String = "chaser") -> void:
	elite = p_elite
	flying = (p_flying or p_kind == "wisp") and not p_elite
	kind = "chaser"
	if flying:
		kind = "wisp"
	elif p_kind in ["cantor", "brute"] and not p_elite:
		kind = p_kind
	var mult := 6.0 if elite else 1.0
	max_hp = (90.0 if elite else 20.0) * hp_scale * mult / (6.0 if elite else 1.0)
	if elite:
		max_hp = 90.0 * hp_scale
	hp = max_hp
	speed = (3.4 if elite else 4.6 + randf() * 1.4) * (1.0 + hp_scale * 0.03)
	radius = 1.1 if elite else 0.6
	contact = 16.0 if elite else 8.0
	if kind == "brute":
		hp = 45.0 * hp_scale
		max_hp = hp
		speed = 3.0
		radius = 0.9
		contact = 14.0
		mesh = MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = radius
		bm.height = radius * 2.2
		mesh.mesh = bm
		mesh.scale = Vector3(1.25, 1.0, 1.0)
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.06, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.3, 0.08)
		mat.emission_energy_multiplier = 1.0
		mesh.material_override = mat
		mesh.position.y = radius * 1.1
		add_child(mesh)
		return
	if kind == "cantor":
		hp = 15.0 * hp_scale
		max_hp = hp
		speed = 3.2
		radius = 0.5
		contact = 6.0
		fire_cd = 1.5 + randf() * 1.5
		mesh = MeshInstance3D.new()
		var sp := CylinderMesh.new()
		sp.top_radius = 0.15
		sp.bottom_radius = 0.5
		sp.height = 2.6
		mesh.mesh = sp
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.1, 0.45)
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.25, 1.0)
		mat.emission_energy_multiplier = 1.2
		mesh.material_override = mat
		mesh.position.y = 1.3
		add_child(mesh)
		return
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
	touch_cd = maxf(0.0, touch_cd - dt)
	if charge_state == 1:
		# telegraph strobe: GET OFF THE LINE
		mat.emission_energy_multiplier = 2.5 + sin(Time.get_ticks_msec() / 60.0) * 1.5
		return
	if flash > 0.0:
		flash = maxf(0.0, flash - dt * 6.0)
		mat.emission_energy_multiplier = 0.7 + flash * 3.0
	elif kind == "brute" and charge_state != 1:
		mat.emission_energy_multiplier = 1.0
	if flying:
		# hover + bob; game.gd steers XZ and dive
		mesh.position.y = base_y + sin(Time.get_ticks_msec() / 280.0 + float(get_instance_id() % 10)) * 0.4
		mesh.rotation.y += dt * 3.0
		return
	# hover bob
	if mesh:
		mesh.position.y = radius * 1.5 + sin(Time.get_ticks_msec() / 300.0 + float(get_instance_id() % 10)) * 0.15
