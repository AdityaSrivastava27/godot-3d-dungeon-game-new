# Gun mechanics — rubric

What this branch implements, and the criteria an implementation of the same
task should be judged against.

- **Start point:** `task/gun-mechanics/base` — the dungeon with a player, a
  third-person shoulder camera and doors. No gun, no HUD, no crosshair.
- **Reference solution:** `task/gun-mechanics/solution` — this branch. The diff
  against base is purely additive: `Scripts/gun.gd`, `Scripts/hud.gd`, the
  `Gun` and `HUD` node trees in `Scenes/Main.tscn`, and two input actions in
  `project.godot`.

## The task

> 1. On game start user should have 5 magazines.
> 2. First Magazine is auto loaded in the gun.
> 3. Each Magazine contains 6 Bullets.
> 4. User can reload the Magazine using R Key.
> 5. Reduce magazine count upon each reload.
> 6. We need to show the bullet as well as magazine counts.
> 7. Each gun fire reduces one bullet.
> 8. User can not fire if there is no bullet remaining.
> 9. Add a crosshair for the player to aim.

## Required criteria

All nine must pass. Each is observable at runtime, not merely present in the
source.

| # | Criterion | Passes when | In this branch |
|---|---|---|---|
| 1 | Starting magazines | The player begins with five magazines' worth of ammunition — 30 rounds in total | `Gun.STARTING_MAGAZINES = 5` (`Scripts/gun.gd:17`) |
| 2 | First magazine chambered | The gun can fire immediately at start, with no reload needed | `bullets` initialised to `MAGAZINE_SIZE` (`gun.gd:24`) |
| 3 | Six rounds per magazine | A full magazine yields exactly six shots before running dry | `Gun.MAGAZINE_SIZE = 6` (`gun.gd:16`) |
| 4 | R reloads | Pressing R swaps in a fresh magazine; the binding is a real input action, not a hard-coded key scan | `reload` action, physical keycode 82 (`project.godot`); handled in `_unhandled_input` (`gun.gd:37`) |
| 5 | Reload spends a magazine | Each successful reload decrements the spare count by exactly one | `magazines -= 1` in `reload()` (`gun.gd:64`) |
| 6 | Both counts displayed | Bullets *and* magazines are visible on screen and update immediately on every fire and reload | `HUD/AmmoLabel` driven by the `ammo_changed` signal (`Scripts/hud.gd:22`) |
| 7 | Firing costs a bullet | One trigger pull removes exactly one bullet — not zero, not one per frame held | `bullets -= 1` in `fire()`, called on `is_action_pressed` (`gun.gd:50`) |
| 8 | No firing when empty | With zero bullets the trigger does nothing at all: no shot, no count going negative | Early `return false` guard (`gun.gd:47`) |
| 9 | Crosshair | A crosshair is drawn at the centre of the screen, and the shot lands where it points | `HUD/Crosshair`, anchored 0.5/0.5 (`Scenes/Main.tscn:679`); shot traced along the camera axis (`gun.gd:72`) |

## Judgement calls

These are defensible either way. An implementation that chooses differently is
not wrong, but it should be deliberate and consistent with what it displays.

| Decision | This branch | The alternative |
|---|---|---|
| Does "5 magazines" include the loaded one? | Yes — 5 total, one chambered, 4 spare, 30 rounds | 5 spare *plus* a loaded one, 36 rounds. One-line change to `STARTING_MAGAZINES` |
| Reloading a partly-used magazine | The remaining rounds are lost, as in a real magazine swap | Carry the rounds over into the reserve |
| Reloading when already full | Refused, so a magazine is not thrown away for nothing | Allow it and consume the spare |
| Where the shot originates | The camera, so it lands exactly on the crosshair | The muzzle, which is more physical but misses the crosshair at close range |

## Beyond the spec

Present here, not required to pass:

- A gun model on the player's right side (body, grip, barrel, muzzle marker).
- A muzzle flash on firing and a brief spark at the point of impact — without
  some feedback, firing is invisible, since the level has nothing to shoot at.
- An `Empty - press R to reload` / `OUT OF AMMO` hint on the HUD.

## Deliberately absent

Not required by the task, and their absence is not a fault:

- No fire-rate limit or automatic fire — one shot per click.
- No reload delay or animation; the swap is instant.
- No enemies, damage, ammo pickups or sound.

## How to verify

Headless, no editor needed:

```sh
godot --headless --path . --import          # first run only
godot --headless --path . --quit-after 300  # expect exit 0, no script errors
```

For the behaviour itself, drive the scene from a `SceneTree` script and assert
on `Gun.bullets` / `Gun.magazines` after sequences of `fire()` and `reload()`.
Do the asserting in `_process`, not `_initialize` — nodes have not run `_ready`
yet at `_initialize` time, so the HUD is not wired up and the checks silently
read stale values.

Two checks worth automating beyond the counts:

- **30 rounds total.** Fire six, reload, four times over; the seventh magazine
  must not exist and `reload()` must return false.
- **The crosshair line is clear of the player.** Cast a ray from the camera
  along its forward axis, with the player included in the query, across a
  spread of positions and look pitches. It must never report the player as the
  collider — otherwise the player shoots their own body.
