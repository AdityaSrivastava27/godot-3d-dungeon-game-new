# Minimap task — rubric

Branch: `task/minimap/solution`, on top of `task/minimap/base`.
Commits: `d9ff8fd` (minimap) and `bead0d6` (mirroring fix).
Files: `Scripts/minimap.gd` (new, 224 lines) and a `Minimap` Control node added to
the HUD in `Scenes/Main.tscn`.

## What was asked

- A circular minimap showing dungeon areas, the player icon, and enemies in red.
- The player icon fixed pointing up; the map rotates with the player instead.
- Doors clearly visible, plus enemy line of sight and room interiors.

## What was implemented

- **Drawn from level geometry, not a second camera.** `_collect()` walks the
  scene once at `_ready()` and sorts every `CSGBox3D` by node name into floors,
  props, walls and doors, so each kind gets its own colour and shape.
- **Sorting by name, not by a hand-written list.** Rooms added to the level later
  turn up on the map without touching `minimap.gd`.
- **Player-relative frame.** `_to_map()` converts world x/z into the player's
  frame: the player sits at the centre as a fixed green triangle pointing up the
  screen, and the dungeon rotates underneath.
- **Round map, not a square one.** Shapes crossing the rim are trimmed against a
  48-segment circle with `Geometry2D.intersect_polygons`, so nothing spills into
  the rest of the HUD.
- **Doors in orange**, re-read every frame from their live transforms because
  they swing open.
- **Enemies as red dots**, taken from the `enemy` group each frame.
- **Enemy line of sight** as a translucent wedge built from each guard's
  `sight_angle` and `sight_range`, brightening to orange when `guard.chasing`.
- **Scale and radius are configurable** via the `metres_shown` export; sight
  cones can be switched off with `show_enemy_sight`.
- **Resizes with its Control node** — `_measure()` is re-run on `resized`.

## Issues faced and how they were handled

- **A top-down camera could not do the job.** It would have needed the ceilings
  hidden to see anything at all, and cannot show a guard's vision cone, which is
  not geometry in the level. Hence drawing the map by hand.
- **Ceilings covered everything.** Read like any other box, `Ceil*` nodes sat on
  top of the rooms below them and hid the map. They are skipped in `_collect()`.
- **Door leaves were invisible.** A leaf is about 0.18 m thick, which is under a
  pixel at this scale. `_footprint()` takes a `min_thickness`, and doors are
  widened to `DOOR_MIN_THICKNESS` (0.45 m) when drawn.
- **Doors could not be cached with the walls.** They rotate as they open, so
  their footprint is recomputed every frame rather than gathered once.
- **Clipping to the circle was not just a bounds check.** A shape can have every
  corner outside the rim and still cross it. `_blot()` only discards a shape when
  its nearest corner is further out than the rim plus the shape's own longest
  edge; otherwise it clips properly.
- **Left and right came out mirrored** (`bead0d6`). The player faces **+Z**, not
  Godot's usual −Z — `Player._physics_process` sets the yaw from the camera's
  `basis.z`. The sideways axis had been derived for a −Z facing, which made the
  whole transform a reflection rather than a rotation, so a guard ahead-left
  showed up ahead-right. Facing +Z puts the player's right hand towards −x, so
  the axis is `(-cos, sin)`. Ahead/behind was already correct for a +Z facing,
  which is why only one axis looked wrong.
  - Side effect checked: the fix flips polygon winding. Harmless here —
    `Geometry2D.intersect_polygons` uses even-odd fill, and
    `draw_colored_polygon` does not backface-cull.

## Known limitations

- **No fog of war.** The whole dungeon is drawn from the first frame; there is no
  reveal-as-explored behaviour.
- **Height is ignored.** Only world x/z is used, so a multi-storey dungeon would
  draw both floors on top of each other.
- **Redraws every frame.** `_process()` calls `queue_redraw()` unconditionally and
  `_blot()` re-maps every polygon in the level each time. Fine at this dungeon's
  size; would need culling by distance if the level grew much larger.

## Verification status

The geometry was reasoned through and checked against the reported symptom and
the reference screenshot; the mirroring fix was **not** confirmed by running the
game, as no Godot binary was available in this environment. Worth a visual pass
in the editor before merging.
