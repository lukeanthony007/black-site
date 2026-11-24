# Black Site — Generated Cyber/Archives Facility

## Run

```bash
~/.local/bin/godot --path /home/luke/Source/personal/black-site-src/game
```

Project launch scene is the generated Cyber/Archives facility (`scenes/dev_generated_facility.tscn`). Use Godot **Run Project / F5**.

`F6` runs whichever scene is open in the editor; do not use it for the project launch.

Legacy testing scenes remain available below.

Other scenes:

```bash
# Legacy indoor facility testing map
~/.local/bin/godot --path game res://scenes/main.tscn
# Legacy outdoor OTR district testing map
~/.local/bin/godot --path game res://scenes/otr_district.tscn
```

### Headless self-tests

```bash
~/.local/bin/godot --path game --headless res://scenes/dev_motor_selftest.tscn
~/.local/bin/godot --path game --headless res://scenes/dev_gunfeel_selftest.tscn
~/.local/bin/godot --path game --headless res://scenes/dev_stealth_selftest.tscn
~/.local/bin/godot --path game --headless res://scenes/dev_gym_layout_selftest.tscn
~/.local/bin/godot --path game --headless res://scenes/dev_parkour_course_selftest.tscn
```

## Controls

| Input | Action |
|-------|--------|
| WASD | Move |
| Mouse | Look / aim |
| Shift | Sprint |
| Ctrl (or **X**) | Crouch / dive (in air) / slide (land or from sprint) |
| Space | Jump / **ledge grab + pull-up** / wallkick / air-dive |
| RMB | **Iron sights** (ADS) · tighter spread · FOV zoom |
| LMB | Fire |
| RMB | Aim (ADS — tighter spread, less recoil) |
| **1 / 2 / 3** | Threat demands (while aiming at guard) |
| **V** | Throw sound decoy |
| F / Q | Kill / knockout |
| G | Lockpick |
| C | Camera loop |
| E | Interact / drag |
| P | Restart |

## Motor constants (`MotorConstants`)

| Measure | Value | Notes |
|---------|-------|--------|
| Jump apex | ~1.03 m | `JUMP_VELOCITY² / 2g` |
| Mantle band | 1.05–1.55 m | Beyond pure jump |
| Slide clearance | 1.05 m | Crouch capsule + margin |
| Gaps | 1.5 / 2.2 / 2.8 / 3.4 m | Easy → extreme |
| Soft / hard land | &lt;2.4 m / ≥2.4 m | Noise 0.18 vs 0.78 |
| Wallrun | Lateral arc · **vertical climb** into wall | Space = grab lip / kick |

## Legacy rooftop course (`parkour_course.tscn`)

City roofs ~24 m up, street void below. Red marks = Runner path. Fall → last **CP**. Green helipad = extract.

| Sector | Mechanic |
|--------|----------|
| **SPRINT** | Long roof + slide under HVAC duct |
| **CROSSINGS** | Building-to-building gaps (`GAP_*`) |
| **ASCENT** | AC hops, scaffold mantle, facade wall-climb |
| **ALLEY** | Wallrun between towers |
| **SKYLIGHT** | Dive through broken frame |
| **DROP** | Soft vs hard roof landings |
| **CRANE** | Scaffold beam → extreme gap → extract roof |

## Legacy map — indoor facility gym (`main.tscn`)

Parkour pads use **neutral gray** materials. Stand on **CP** floor markers to set a **checkpoint**. Falling into the void returns you there.

| Dir | Zone | What to test | AI |
|-----|------|----------------|-----|
| Center | **HUB** | Armory, hop steps, mantle demo walls, legend | none |
| **N** | **STRIDE** | Sprint lane, slide-under at slide clearance | none |
| **W** | **GAPS** | Edge gaps from motor constants | none |
| **E** | **CLIMB** | Step ladder + mantle ledges → roof **EXTRACT** | none |
| **NE** | **WALL** | Parallel walls for wallrun | none |
| **S** | **TIGHTS** | Crawl / slide at clearance height | none |
| **SE** | **COMBAT** | Cover, hostile guards, crates | **yes** |
| **SW** | **STEALTH** | Doors, cameras, hide, keycards, patrols | **yes** |

**Objectives:** download (server) · destroy (climb mid) · ★ bunker (stealth cage) · extract (climb roof)

**Cards:** facility keycard on mid hub balcony · server keycard in SW security office
