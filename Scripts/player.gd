extends CharacterBody3D

## Player movement, and the health the enemies whittle down.
##
## Health is a plain 0..MAX_HEALTH count so the damage figures read as the
## percentages the design asks for: a ranged hit costs 20, a melee hit 50.
## Running out sends the player back to where they started at full health --
## there is nothing else to do with a death yet.

signal health_changed(current: int, maximum: int)
signal died

const MAX_HEALTH := 100

const SPEED = 5.0
const ROTATION_SPEED = 10.0
const JUMP_VELOCITY = 4.5

var health: int = MAX_HEALTH

var _spawn_point: Vector3


func _ready() -> void:
	_spawn_point = global_position


## Takes `amount` off the player's health, stopping at zero. Ignored once the
## player is already down, so two hits landing on the same frame cannot push
## the count negative.
func take_damage(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)

	if health == 0:
		died.emit()
		_respawn()


func _respawn() -> void:
	global_position = _spawn_point
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)


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
