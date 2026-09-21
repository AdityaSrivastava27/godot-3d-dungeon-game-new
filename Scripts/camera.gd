extends Node3D

## Third-person orbit camera with collision handling.
##
## The pivot follows the player and is rotated by the mouse (unchanged controls).
## Each frame we look for solid geometry between the player and the camera's
## resting spot; if something is in the way the camera slides in just in front of
## it, so it never clips through or sits inside a wall. With a clear view it stays
## at its normal resting distance, giving the usual over-the-shoulder framing.

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -45.0
@export var max_pitch: float = 45.0

# Resting local offset of the camera relative to the pivot: over the player's
# right shoulder rather than straight behind them. The sideways component is
# what keeps the body off the middle of the screen, so the centre of the view
# is always clear ground ahead of the player -- at any look pitch, not just
# when looking level.
const CAM_OFFSET := Vector3(0.85, 1.2, 2.8)

# Local rotation of the camera within the pivot, in degrees. The camera is
# angled back towards the player: down a little so the player sits in frame
# below the centre, and inwards so the view converges on the line they are
# facing instead of staring off to the right.
const CAM_PITCH := -5.0
const CAM_YAW := 3.0

const CAST_FROM_HEIGHT := 1.2   # ray starts near the player's head, not the floor
const COLLISION_MARGIN := 0.3   # keep the camera this far off the surface it hits
const MIN_DISTANCE := 0.6       # never let the camera collapse onto the player

@onready var player: CharacterBody3D = get_parent()
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The rig angle lives here rather than in the scene so it stays next to the
	# offset it belongs with; only the position is recomputed per frame.
	camera.rotation = Vector3(deg_to_rad(CAM_PITCH), deg_to_rad(CAM_YAW), 0.0)
	# Place the camera correctly on the very first frame so the game never opens
	# with the view stuck inside the wall behind the start position.
	global_position = player.global_position
	_update_camera()


func _process(_delta: float) -> void:
	global_position = player.global_position
	_update_camera()


# Slide the camera in when the line back to its resting spot is blocked.
#
# The pull-in runs from a shoulder anchor -- the rig's sideways and upward
# offset applied at zero distance back -- rather than from the player's head.
# That way only the distance behind shrinks and the camera keeps looking past
# the player's shoulder however tight the space gets; pulling towards the head
# instead would drag the view back onto the player's body in a corridor.
func _update_camera() -> void:
	if camera == null:
		return

	var head: Vector3 = global_position + Vector3(0, CAST_FROM_HEIGHT, 0)
	var anchor: Vector3 = global_transform * Vector3(CAM_OFFSET.x, CAM_OFFSET.y, 0.0)

	# The anchor itself can be inside a wall when the player hugs one, so slide
	# it back towards the head until it is clear. It is allowed to collapse all
	# the way to the head: in a tight spot the shoulder framing simply gives way
	# to the old straight-behind view, which beats burying the camera in stone.
	var side_hit := _cast(head, anchor)
	if not side_hit.is_empty():
		anchor = _pull_back(head, anchor, (side_hit.position - head).length(), 0.0)

	# Measure the resting spot back from wherever the anchor ended up, so the
	# camera always sits directly behind the shoulder it is looking over.
	var desired: Vector3 = anchor + global_transform.basis.z * CAM_OFFSET.z

	var target := desired
	var back_hit := _cast(anchor, desired)
	if not back_hit.is_empty():
		target = _pull_back(anchor, desired, (back_hit.position - anchor).length(), MIN_DISTANCE)

	# Only the camera position is adjusted; its rotation keeps the fixed rig angle
	# set in _ready and otherwise follows the pivot, so mouse control is unchanged.
	camera.global_position = target


func _cast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1                 # environment/world geometry only
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]       # ignore the player's own body
	return get_world_3d().direct_space_state.intersect_ray(query)


# A point on the from->to line, stopped short of `blocked_at` by the margin and
# never closer to `from` than `min_d`.
func _pull_back(from: Vector3, to: Vector3, blocked_at: float, min_d: float) -> Vector3:
	var offset := to - from
	var full := offset.length()
	if full <= 0.001:
		return to

	var d: float = clampf(blocked_at - COLLISION_MARGIN, min_d, full)
	return from + offset.normalized() * d


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
