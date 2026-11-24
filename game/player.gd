extends CharacterBody3D


# MOVEMENT SETTINGS
const SPEED = 6.0
const SPRINT_SPEED = 9.0
const JUMP_VELOCITY = 4.5

const ACCELERATION = 12.0
const DECELERATION = 14.0


# STAMINA SETTINGS
const MAX_STAMINA = 100.0
const STAMINA_DRAIN = 25.0
const STAMINA_REGEN = 15.0
const SPRINT_RECOVERY_THRESHOLD = 30.0

var stamina = MAX_STAMINA
var can_sprint = true
var is_rift_world = false


# CAMERA SETTINGS
@export var mouse_sensitivity = 0.003

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D


# CHARACTER SETTINGS
@onready var animation_player = $Character/AnimationPlayer
@onready var character = $Character
@onready var stamina_bar = $"../CanvasLayer/StaminaBar"
@onready var floor_mesh = $"../Floor"
@onready var rift_pillar = $"../RiftPillar"

var was_on_floor = true
var is_landing = false


func _ready():

	# IDLE AND JOG BLENDING
	animation_player.set_blend_time(
		"UAL1_Standard/Idle",
		"UAL1_Standard/Jog_Fwd",
		0.25
	)

	animation_player.set_blend_time(
		"UAL1_Standard/Jog_Fwd",
		"UAL1_Standard/Idle",
		0.25
	)


	# JOG AND SPRINT BLENDING
	animation_player.set_blend_time(
		"UAL1_Standard/Jog_Fwd",
		"UAL1_Standard/Sprint",
		0.4
	)

	animation_player.set_blend_time(
		"UAL1_Standard/Sprint",
		"UAL1_Standard/Jog_Fwd",
		0.4
	)


	# IDLE AND SPRINT BLENDING
	animation_player.set_blend_time(
		"UAL1_Standard/Idle",
		"UAL1_Standard/Sprint",
		0.3
	)

	animation_player.set_blend_time(
		"UAL1_Standard/Sprint",
		"UAL1_Standard/Idle",
		0.3
	)


	# JUMP BLENDING
	animation_player.set_blend_time(
		"UAL1_Standard/Idle",
		"UAL1_Standard/Jump_Start",
		0.1
	)

	animation_player.set_blend_time(
		"UAL1_Standard/Jog_Fwd",
		"UAL1_Standard/Jump_Start",
		0.1
	)

	animation_player.set_blend_time(
		"UAL1_Standard/Jump_Start",
		"UAL1_Standard/Jump",
		0.15
	)

	animation_player.set_blend_time(
		"UAL1_Standard/Jump",
		"UAL1_Standard/Jump_Land",
		0.15
	)


	# LANDING BLENDING
	animation_player.set_blend_time(
		"UAL1_Standard/Jump_Land",
		"UAL1_Standard/Idle",
		0.2
	)

	animation_player.set_blend_time(
		"UAL1_Standard/Jump_Land",
		"UAL1_Standard/Jog_Fwd",
		0.2
	)

	animation_player.set_blend_time(
		"UAL1_Standard/Jump_Land",
		"UAL1_Standard/Sprint",
		0.2
	)
	update_realm_visuals()


# PREVENTS RESTARTING THE SAME ANIMATION EVERY FRAME
func play_animation(animation_name: String):

	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name)


# CAMERA CONTROLS
func _unhandled_input(event):

	if event is InputEventKey:

		if event.pressed and event.keycode == KEY_CTRL:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		elif not event.pressed and event.keycode == KEY_CTRL:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:

		camera_pivot.rotate_y(
			-event.relative.x * mouse_sensitivity
		)

		camera.rotate_x(
			-event.relative.y * mouse_sensitivity
		)

		camera.rotation.x = clamp(
			camera.rotation.x,
			deg_to_rad(-60),
			deg_to_rad(30)
		)
func switch_realm():

	is_rift_world = !is_rift_world

	update_realm_visuals()

	if is_rift_world:
		print("Entered Rift World!")
	else:
		print("Returned to Material World!")

func update_realm_visuals():

	var floor_material = StandardMaterial3D.new()
	var pillar_material = StandardMaterial3D.new()

	if is_rift_world:

		# RIFT WORLD
		floor_material.albedo_color = Color(0.12, 0.02, 0.2)
		pillar_material.albedo_color = Color(0.9, 0.0, 1.0)

	else:

		# MATERIAL WORLD
		floor_material.albedo_color = Color(0.03, 0.08, 0.15)
		pillar_material.albedo_color = Color(0.0, 0.4, 1.0)

	floor_mesh.material_override = floor_material
	rift_pillar.material_override = pillar_material

# MAIN MOVEMENT
func _physics_process(delta: float):
	if Input.is_action_just_pressed("switch_realm"):
		switch_realm()

	# GRAVITY
	if not is_on_floor():
		velocity += get_gravity() * delta


	# JUMP
	if Input.is_action_just_pressed("jump") and is_on_floor():

		velocity.y = JUMP_VELOCITY
		is_landing = false

		play_animation("UAL1_Standard/Jump_Start")


	# MOVEMENT INPUT
	var input_dir = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	var direction: Vector3 = (
		camera_pivot.global_transform.basis *
		Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	var has_movement = direction.length_squared() > 0.001


	# CHARACTER ROTATION
	if has_movement:

		var target_rotation = atan2(
			direction.x,
			direction.z
		)

		character.rotation.y = lerp_angle(
			character.rotation.y,
			target_rotation,
			delta * 10.0
		)


	# STAMINA RECOVERY AND SPRINT CONTROL
	var sprint_requested = (
		Input.is_action_pressed("sprint")
		and has_movement
		and can_sprint
	)

	if sprint_requested:

		stamina = maxf(
			stamina - STAMINA_DRAIN * delta,
			0.0
		)

		if stamina <= 0.0:
			can_sprint = false

	else:

		stamina = minf(
			stamina + STAMINA_REGEN * delta,
			MAX_STAMINA
		)

		if stamina >= SPRINT_RECOVERY_THRESHOLD:
			can_sprint = true
	stamina_bar.value = stamina


	# SPRINT SPEED
	var current_speed = SPRINT_SPEED if sprint_requested else SPEED


	# SMOOTH MOVEMENT ACCELERATION
	if has_movement:

		velocity.x = move_toward(
			velocity.x,
			direction.x * current_speed,
			ACCELERATION * delta
		)

		velocity.z = move_toward(
			velocity.z,
			direction.z * current_speed,
			ACCELERATION * delta
		)

	else:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			DECELERATION * delta
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			DECELERATION * delta
		)


	# APPLY MOVEMENT
	move_and_slide()


	# LANDING DETECTION
	if is_on_floor() and not was_on_floor:

		is_landing = true
		play_animation("UAL1_Standard/Jump_Land")


	# LANDING ANIMATION
	elif is_landing:

		if has_movement:

			is_landing = false

			if sprint_requested:
				play_animation("UAL1_Standard/Sprint")
			else:
				play_animation("UAL1_Standard/Jog_Fwd")

		elif not animation_player.is_playing():

			is_landing = false
			play_animation("UAL1_Standard/Idle")


	# AIRBORNE ANIMATIONS
	elif not is_on_floor():

		if (
			animation_player.current_animation == "UAL1_Standard/Jump_Start"
			and animation_player.is_playing()
		):

			pass

		else:

			play_animation("UAL1_Standard/Jump")


	# GROUND MOVEMENT ANIMATIONS
	elif has_movement:

		if sprint_requested:
			play_animation("UAL1_Standard/Sprint")

		else:
			play_animation("UAL1_Standard/Jog_Fwd")


	# IDLE ANIMATION
	else:

		play_animation("UAL1_Standard/Idle")


	# UPDATE FLOOR STATE
	was_on_floor = is_on_floor()
