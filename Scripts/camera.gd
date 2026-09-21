extends Node3D

## Third-person orbit camera with collision handling.
##
## The pivot follows the player and is rotated by the mouse (unchanged controls).
## Each frame we look for solid geometry between the player and the camera's
## resting spot; if something is in the way the camera slides in just in front of
## it, so it never clips through or sits inside a wall. With a clear view it stays
## at its normal resting distance, giving the same framing as before.

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -45.0
@export var max_pitch: float = 45.0

# Resting local offset of the camera behind/above the pivot. This matches the
# Camera3D's authored position in the scene, so the default view is unchanged.
const CAM_OFFSET := Vector3(0, 1.5, 4)
const CAST_FROM_HEIGHT := 1.2   # ray starts near the player's head, not the floor
const COLLISION_MARGIN := 0.3   # keep the camera this far off the surface it hits
const MIN_DISTANCE := 0.6       # never let the camera collapse onto the player

@onready var player: CharacterBody3D = get_parent()
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Place the camera correctly on the very first frame so the game never opens
	# with the view stuck inside the wall behind the start position.
	global_position = player.global_position
	_update_camera()


func _process(_delta: float) -> void:
	global_position = player.global_position
	_update_camera()


# Slide the camera in when the line from the player to its resting spot is blocked.
func _update_camera() -> void:
	if camera == null:
		return

	var from: Vector3 = global_position + Vector3(0, CAST_FROM_HEIGHT, 0)
	var desired: Vector3 = global_transform * CAM_OFFSET  # resting spot in world space

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, desired)
	query.collision_mask = 1                 # environment/world geometry only
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]       # ignore the player's own body
	var hit := space.intersect_ray(query)

	var target := desired
	if not hit.is_empty():
		var hit_pos: Vector3 = hit.position
		var offset := desired - from
		var full := offset.length()
		if full > 0.001:
			var d: float = (hit_pos - from).length() - COLLISION_MARGIN
			d = clampf(d, MIN_DISTANCE, full)
			target = from + offset.normalized() * d

	# Only the camera's position is adjusted; its rotation still follows the pivot,
	# so the look direction and mouse controls are exactly as before.
	camera.global_position = target


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		var new_pitch: float = rotation.x - event.relative.y * mouse_sensitivity

		new_pitch = clamp(
			new_pitch,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

		rotation.x = new_pitch
