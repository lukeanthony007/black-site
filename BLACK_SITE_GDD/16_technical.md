# Technical Architecture

Visual style, performance targets, and Unity systems.

---

## 26. Visual Style

### Art Direction

**"Clean Low-Poly with Premium Lighting"**

| Element | Approach |
|---------|----------|
| Geometry | Low-poly, hard edges, limited textures |
| Lighting | Strong HDR, baked + mixed GI |
| Effects | Bloom, tonemap, fog, light shafts |
| Decals | Bullet impacts, blood splats (pooled) |
| Particles | Muzzle flash, impacts, debris (budgeted) |
| Materials | Clean colors, roughness variation, minimal textures |

### Level Design for Readability

- Parkour surfaces visually legible
- Combat spaces with verticality and escape routes
- Lighting helps navigation (bright routes, shadow cover)
- Security rings visually distinct
- Vents and service routes have consistent visual language

---

## 27. Technical Targets (Unity)

### Rendering
- URP (Universal Render Pipeline)
- Strict performance budgets
- Baked lighting for static geometry
- Limited real-time shadows distance

### Performance
- Object pooling: decals, particles, projectiles, ragdolls
- Avoid heavy transparency
- Limit shadow cascades
- AI tick rate LOD (distance-based)
- Simple colliders for environment

### Physics
- Kinematic player motor for consistent parkour
- Rigidbody physics for props, ragdolls, impacts
- Pooled ragdoll cleanup (cap active count)

---

## 28. Unity Architecture

### Player Components

| Component | Function |
|-----------|----------|
| PlayerMotor | Movement state machine |
| PlayerCamera | Look, recoil, FOV, sway |
| HandController | Left/right equip, input dispatch |
| WeaponController | Fire, reload, spread, recoil |
| MeleeController | Gesture tracking, sweeps |
| StealthSystem | Takedown checks, animation locks |
| Inventory | Pickup, drop, swap |

### Weapon System

| Component | Function |
|-----------|----------|
| WeaponData | ScriptableObject: stats, curves |
| WeaponViewModel | Visual representation |
| HitscanShooter | Raycast shooting |
| ProjectileShooter | Physical projectiles |
| ImpactSystem | Decals, particles, sounds |
| TakedownProfile | Range, angle, duration, noise |

### AI System

| Component | Function |
|-----------|----------|
| NpcTraits | Bravery, lawfulness, composure |
| NpcPerception | Vision, hearing |
| NpcMemory | Recent events, threats, obligations |
| NpcBrain | State machine + utility selection |
| NpcMotor | NavMesh + roof connectors |
| NpcAnimator | Blend trees, turn-in-place |
| NpcVoice | Shouts, panic sounds |
| JobRunner | Task execution, reporting |

### World Systems

| System | Function |
|--------|----------|
| WorldGen | FacilityGraph + zones + triggers |
| SecurityNet | Cameras, doors, logs, alarms |
| EventBus | Sound, crime, alarm, witness events |
| LedgerSystem | Resources, heat, incident tracking |
| TaskMarket | Open requests + assignment |
| SocialGraph | Relationships, trust, fear |

### Data (ScriptableObjects)

- FactionDef, RankDef, RoleDef
- JobDef, TaskDef, ConstraintDef
- FacilityArchetype, RoomArchetype
- ItemDef, WeaponDef
- TakedownProfile, DemandProfile

---

# PART VII: MULTIPLAYER

