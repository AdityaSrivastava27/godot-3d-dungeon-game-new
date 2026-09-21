extends CharacterBody3D


const SPEED = 5.0
const ROTATION_SPEED = 10.0
const JUMP_VELOCITY = 4.5


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction.
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	# Get the camera.
	var camera: Camera3D = $CameraPivot/Camera3D

	# Get the camera's forward and right directions.
	var forward: Vector3 = camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x

	# Ignore the camera's vertical direction.
	forward.y = 0
	right.y = 0

	# Normalize the directions.
	forward = forward.normalized()
	right = right.normalized()

	# Calculate movement direction relative to the camera.
	var direction: Vector3 = (right * input_dir.x + forward * input_dir.y).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED

		var target_rotation := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
