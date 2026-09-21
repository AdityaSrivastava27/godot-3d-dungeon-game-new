# Minimap task — rubric

## Implemented

- Circular minimap showing the dungeon areas, with the player icon and enemies
  in red.
- The player icon stays fixed at the centre pointing up the screen; the map
  rotates with the player instead.
- Doors are drawn clearly, in their own colour and widened so they stay visible.
- Enemy line of sight is drawn as a cone.
- Room interiors are shown: floors, walls and the clutter inside each room.

## Issue faced

- Left and right came out mirrored on the map: a guard ahead on the left showed
  up ahead on the right, while ahead and behind were correct.
- Cause: the player faces +Z, not Godot's usual −Z, so the sideways axis had
  been derived from the wrong facing and made the transform a reflection rather
  than a rotation.
- Fixed by deriving the sideways axis for a +Z facing, which un-mirrors the
  guards, their sight cones, the doors and the walls together.
