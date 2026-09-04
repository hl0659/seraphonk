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
		velocity.x = wish.x * WALK; velocity.z = wish.z * WALK
		if velocity.y < 0.0: velocity.y = -0.5
	move_and_slide()
	trauma = maxf(0.0, trauma - dt * 1.6)
