extends CharacterBody3D
## SERAPHONK player — ports engine/movement.py to 3D. Production foundation, not final feel.
const WALK := 7.5
const DASH := 19.0
const DASH_TIME := 0.16
const IFRAMES := 0.25
const SLIDE := 10.5
const SLAM_FALL := 28.0
const SLAM_AOE := 3.0
const MAX_STAMINA := 3.0
const REGEN := 1.0
const COYOTE := 0.08
const BUFFER := 0.12
const JUMP_VEL := 9.0
const DASH_JUMP_VEL := 10.5
const GRAVITY := 24.0

var stamina := MAX_STAMINA
var dash_t := 0.0
var iframes_t := 0.0
var coyote_t := 0.0
var buffer_t := 0.0
var sliding := false
var slamming := false
var trauma := 0.0
var hp := 100.0
var max_hp := 100.0
var walk_mult := 1.0
var just_slammed := false

func _ready() -> void:
	# seraph body: Blender-forged seraph.glb if present, else ivory primitives
	var have_model := false
	if ResourceLoader.exists("res://assets/models/seraph.glb"):
		var ps := load("res://assets/models/seraph.glb") as PackedScene
		if ps:
			var inst := ps.instantiate() as Node3D
			add_child(inst)
			have_model = true
	if not have_model:
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.5
		cap.height = 1.6
		body.mesh = cap
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.95, 0.93, 0.85)
		bm.emission_enabled = true
		bm.emission = Color(1.0, 0.95, 0.75)
		bm.emission_energy_multiplier = 0.5
		body.material_override = bm
		add_child(body)
	# halo ring (iconic readable even with model)
	var halo := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.08
	tor.outer_radius = 0.55
	halo.mesh = tor
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1, 0.9, 0.5)
	hm.emission_enabled = true
	hm.emission = Color(1.0, 0.8, 0.3)
	hm.emission_energy_multiplier = 2.5
	halo.material_override = hm
	halo.position.y = 2.1
	add_child(halo)
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.5
	cs.height = 1.6
	col.shape = cs
	col.position.y = 0.9
	add_child(col)

func _physics_process(dt: float) -> void:
	var wish := Vector3(
		Input.get_axis("move_left", "move_right"),
		0.0,
		Input.get_axis("move_forward", "move_back")).limit_length(1.0)
	# camera-relative would go here once follow-cam lands
	if Input.is_action_just_pressed("jump"): buffer_t = BUFFER
	else: buffer_t = maxf(0.0, buffer_t - dt)
	if is_on_floor(): coyote_t = COYOTE
	else: coyote_t = maxf(0.0, coyote_t - dt)
	if Input.is_action_just_pressed("dash") and stamina >= 1.0 and dash_t <= 0.0:
		stamina -= 1.0
		var d := wish if wish.length() > 0.01 else -global_transform.basis.z
		velocity.x = d.x * DASH; velocity.z = d.z * DASH
		dash_t = DASH_TIME; iframes_t = IFRAMES; slamming = false
	if not sliding:
		stamina = minf(MAX_STAMINA, stamina + REGEN * dt)
	dash_t = maxf(0.0, dash_t - dt)
	iframes_t = maxf(0.0, iframes_t - dt)
	# dash-jump: buffered jump during dash costs 2nd bar, keeps momentum
	if buffer_t > 0.0 and dash_t > 0.0 and not slamming:
		if stamina >= 1.0:
			stamina -= 1.0; dash_t = 0.0; sliding = false
			velocity.y = DASH_JUMP_VEL; buffer_t = 0.0; coyote_t = 0.0
		else: buffer_t = 0.0
	elif buffer_t > 0.0 and (is_on_floor() or coyote_t > 0.0) and not slamming:
		velocity.y = JUMP_VEL; buffer_t = 0.0; coyote_t = 0.0; sliding = false
	# slide / slam
	var slide_held := Input.is_action_pressed("slide")
	if slide_held and not is_on_floor() and not slamming:
		slamming = true; sliding = false; dash_t = 0.0
		velocity.x *= 0.05; velocity.z *= 0.05; velocity.y = -SLAM_FALL
	if slamming:
		if is_on_floor():
			slamming = false
			just_slammed = true
			trauma = minf(1.0, trauma + 0.55)  # caller spawns AoE of SLAM_AOE
		move_and_slide()
		return
	if slide_held and is_on_floor():
		sliding = true; dash_t = 0.0
		var spd := Vector2(velocity.x, velocity.z).length()
		var target := maxf(SLIDE, spd - 1.8 * SLIDE * dt)
		var d := wish if wish.length() > 0.01 else Vector3(velocity.x, 0, velocity.z).normalized()
		velocity.x = d.x * target; velocity.z = d.z * target
	elif not is_on_floor():
		velocity.x += wish.x * 12.0 * dt; velocity.z += wish.z * 12.0 * dt
		velocity.y -= GRAVITY * dt
	else:
		sliding = false
		velocity.x = wish.x * WALK * walk_mult; velocity.z = wish.z * WALK * walk_mult
		if velocity.y < 0.0: velocity.y = -0.5
	move_and_slide()
	trauma = maxf(0.0, trauma - dt * 1.6)
