extends CharacterBody3D
## SERAPHONK FPS controller — Ultrakill-inspired first-person movement.
## WASD camera-relative, mouse look, dash i-frames, dash-jump, slide, slam.
const WALK := 7.5
const SPRINT_MULT := 1.25
const DASH := 19.0
const DASH_TIME := 0.16
const IFRAMES := 0.25
const SLIDE := 10.5
const SLIDE_FRICTION := 1.8
const SLAM_FALL := 28.0
const SLAM_AOE := 3.0
const MAX_STAMINA := 3.0
const REGEN := 1.0
const COYOTE := 0.08
const BUFFER := 0.12
const JUMP_VEL := 9.0
const DASH_JUMP_VEL := 10.5
const GRAVITY := 24.0
const MOUSE_SENS := 0.0022
const PITCH_MIN := -1.55
const PITCH_MAX := 1.55

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
var yaw := 0.0
var pitch := 0.0
var bob_t := 0.0
var headless := false
var cam: Camera3D
var viewmodel: Node3D

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	cam = $Cam
	# collision capsule (invisible body in first person)
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.45
	cs.height = 1.7
	col.shape = cs
	col.position.y = 0.9
	add_child(col)
	_build_viewmodel()
	if not headless:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_viewmodel() -> void:
	# gold halo-ring bottom-center = your "trumpet" anchor; wings flare on dash
	viewmodel = Node3D.new()
	viewmodel.position = Vector3(0.35, -0.3, -0.7)
	cam.add_child(viewmodel)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.04
	tor.outer_radius = 0.16
	ring.mesh = tor
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1, 0.9, 0.5)
	hm.emission_enabled = true
	hm.emission = Color(1.0, 0.8, 0.3)
	hm.emission_energy_multiplier = 2.5
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = hm
	viewmodel.add_child(ring)

func _input(event: InputEvent) -> void:
	# _input (not _unhandled_input): GUI overlays can never swallow mouse motion.
	if headless:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * MOUSE_SENS
		pitch = clampf(pitch - mm.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
		rotation.y = yaw
		cam.rotation.x = pitch

func aim_dir() -> Vector3:
	return -cam.global_transform.basis.z

func _physics_process(dt: float) -> void:
	var fwd_in := Input.get_axis("move_back", "move_forward")
	var strafe_in := Input.get_axis("move_left", "move_right")
	var sin_y := sin(yaw)
	var cos_y := cos(yaw)
	# camera-relative wish on floor plane (forward = -Z rotated by yaw)
	var wish := Vector3(
		strafe_in * cos_y - fwd_in * sin_y,
		0.0,
		-fwd_in * cos_y - strafe_in * sin_y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var grounded := is_on_floor() and not slamming
	if Input.is_action_just_pressed("jump"):
		buffer_t = BUFFER
	else:
		buffer_t = maxf(0.0, buffer_t - dt)
	if grounded:
		coyote_t = COYOTE
	else:
		coyote_t = maxf(0.0, coyote_t - dt)
	# sprint = holding forward (Ultrakill pace); slide needs speed
	var sprinting := fwd_in > 0.1 and not sliding
	if Input.is_action_just_pressed("dash") and stamina >= 1.0 and dash_t <= 0.0:
		stamina -= 1.0
		var d := wish if wish.length() > 0.01 else -global_transform.basis.z
		d.y = 0.0
		d = d.normalized()
		velocity.x = d.x * DASH
		velocity.z = d.z * DASH
		dash_t = DASH_TIME
		iframes_t = IFRAMES
		slamming = false
	var sliding_intent := Input.is_action_pressed("slide") and is_on_floor() and not slamming
	if not sliding and not sliding_intent:
		stamina = minf(MAX_STAMINA, stamina + REGEN * dt)
	dash_t = maxf(0.0, dash_t - dt)
	iframes_t = maxf(0.0, iframes_t - dt)
	# dash-jump keeps dash momentum + vertical pop (2nd stamina bar)
	if buffer_t > 0.0 and dash_t > 0.0 and not slamming:
		if stamina >= 1.0:
			stamina -= 1.0
			dash_t = 0.0
			sliding = false
			velocity.y = DASH_JUMP_VEL
			buffer_t = 0.0
			coyote_t = 0.0
		else:
			buffer_t = 0.0
	elif buffer_t > 0.0 and sliding and not slamming:
		sliding = false
		velocity.y = JUMP_VEL
		buffer_t = 0.0
		coyote_t = 0.0
	elif buffer_t > 0.0 and (grounded or coyote_t > 0.0) and not slamming:
		velocity.y = JUMP_VEL
		buffer_t = 0.0
		coyote_t = 0.0
		sliding = false
	var slide_held := Input.is_action_pressed("slide")
	if slide_held and not is_on_floor() and not slamming:
		slamming = true
		sliding = false
		dash_t = 0.0
		velocity.x *= 0.05
		velocity.z *= 0.05
		velocity.y = -SLAM_FALL
	if slamming:
		if is_on_floor():
			slamming = false
			just_slammed = true
			trauma = minf(1.0, trauma + 0.55)
		move_and_slide()
		return
	if dash_t > 0.0:
		move_and_slide()
		return
	if slide_held and is_on_floor():
		sliding = true
		var spd := Vector2(velocity.x, velocity.z).length()
		var target := maxf(SLIDE, spd - SLIDE_FRICTION * SLIDE * dt)
		var hv := Vector2(velocity.x, velocity.z)
		var d := wish if wish.length() > 0.01 else Vector3(hv.x, 0, hv.y).normalized()
		velocity.x = d.x * target
		velocity.z = d.z * target
		velocity.y = minf(velocity.y, -0.5)
	elif not is_on_floor():
		velocity.x += wish.x * 14.0 * dt
		velocity.z += wish.z * 14.0 * dt
		velocity.y -= GRAVITY * dt
	else:
		sliding = false
		var spd := WALK * walk_mult * (SPRINT_MULT if sprinting else 1.0)
		velocity.x = wish.x * spd
		velocity.z = wish.z * spd
		if velocity.y < 0.0:
			velocity.y = -0.5
	move_and_slide()
	trauma = maxf(0.0, trauma - dt * 1.6)
	# invisible sanctum walls: the arena is 40x30, the void beyond is death
	global_position.x = clampf(global_position.x, -19.0, 19.0)
	global_position.z = clampf(global_position.z, -14.0, 14.0)
	# head bob + strafe tilt (no camera position fighting: offsets only)
	var hspd := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspd > 1.0:
		bob_t += dt * hspd * 1.4
	# arrow-key look fallback: looking must always be possible, even if
	# the OS/window ever refuses pointer capture
	var turn := Input.get_axis("ui_left", "ui_right")
	var tilt := Input.get_axis("ui_up", "ui_down")
	if turn != 0.0 or tilt != 0.0:
		yaw -= turn * 2.4 * dt
		pitch = clampf(pitch - tilt * 1.8 * dt, PITCH_MIN, PITCH_MAX)
		rotation.y = yaw
		cam.rotation.x = pitch
	cam.position = Vector3(0, 1.62 + sin(bob_t) * 0.045, 0)
	cam.rotation.z = lerpf(cam.rotation.z, -strafe_in * 0.025, dt * 8.0)
	# FOV: base 75, +dash kick, +trauma swell
	var want_fov := 75.0 + (7.0 if dash_t > 0.0 else 0.0) + (4.0 if trauma > 0.4 else 0.0)
	cam.fov = lerpf(cam.fov, want_fov, dt * 8.0)
