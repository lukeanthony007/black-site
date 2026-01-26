# Movement System

Mirror's Edge-style parkour and traversal.

---

## 13. Movement System

### Movement Pillars

| Mode | Speed | Noise | Profile | Use Case |
|------|-------|-------|---------|----------|
| **Walk** | Casual but fast | Low-medium | Normal | Blending in, observation |
| **Sprint** | Very fast | High | High | Parkour, escape, pursuit |
| **Crouch-Sneak** | Slow | Minimal | Low | Stealth approach |
| **Crouch Idle** | None | Minimal | Minimal | Hiding, ambush |

### Parkour Set (Mirror's Edge Core)

| Move | Description | Notes |
|------|-------------|-------|
| **Vault/Mantle** | Ledge climb and obstacle hop | Context-sensitive |
| **Wallrun** | Left/right wall traversal | Gravity scaling, time limit |
| **Wallkick** | Launch off wall | Chain into other moves |
| **Slide** | Speed conservation ground slide | Sprint + crouch |
| **Dive-Roll** | GunZ-style aerial dodge | Shooting allowed during |
| **Soft/Hard Landing** | Fall recovery | Affects noise + accuracy |

**Additional traversal (roof/interior connectors):**
- Ladders
- Fire escapes
- Vents/crawlspaces
- Scaffolding
- Service shafts

### Physics Feel

**Recommended technical approach: Kinematic Player Motor + Physics World**

- Player uses stable kinematic motor (capsule casts, deterministic) for responsive, consistent parkour
- World uses rigidbody physics (props, ragdolls, impacts) for realistic outcomes
- Result: "Realistic physics" where it matters without sacrificing tight parkour

### NPC Traversal Tiers

| Tier | Roles | Capabilities |
|------|-------|--------------|
| **Tier 0** | Staff, civilians, scientists | Normal nav only |
| **Tier 1** | Guards | Vault small obstacles, basic pursuit |
| **Tier 2** | Elite/QRF | Better pursuit routes, ladders, limited shortcuts |
| **Tier 3** | Spy/Operative | Vents, service shafts, advanced traversal |

---

