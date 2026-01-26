# Stealth & Coercion

Detection systems and threat+demand mechanics.

---

## 16. Stealth System

### Detection Channels

#### Vision
| Factor | Effect |
|--------|--------|
| FOV cone | Awareness only within cone |
| Distance | Falloff over range |
| Line-of-sight | Raycast check |
| Salience | Weapon visible, sprinting, blood/bodies increase detection |
| Stance | Crouch reduces profile |
| Lighting | (Optional) exposure affects visibility |

#### Hearing

Every action emits a **sound event** with:
- Type (footstep, gunshot, impact, scream)
- Loudness
- Radius
- Duration
- Occlusion rules (walls reduce)

| Action | Noise Level |
|--------|-------------|
| Crouch walk | Minimal |
| Walk | Low |
| Sprint | High |
| Soft landing | Low |
| Hard landing | High |
| Slide/roll | High (unless "soft roll" perk) |
| Suppressed shot | Medium |
| Unsuppressed shot | Very high |
| Melee impact | Medium |
| Screaming | High (propagates panic) |

### Suppressed Weapons

**Not "silent = invisible"** — uses acoustic simulation:

- Suppressor reduces loudness and radius
- Does NOT remove:
  - Mechanical noise (action cycling)
  - Impact noise (bullet strike)
  - Witness reaction (screams)

| Weapon | Sound Radius |
|--------|--------------|
| Suppressed pistol + subsonic | Small (3-5m) |
| Suppressed SMG | Medium (6-10m) |
| Knife/garrote | Minimal (1-2m) |
| Throwing knife | Low (2-4m) |

**Visual tells still exist:**
- Muzzle flash reduced but not zero
- Impacts leave evidence (blood/holes)
- Bodies trigger investigation

### Automatic Stealth Takedowns

**Trigger conditions (all must pass):**

| Condition | Requirement |
|-----------|-------------|
| Input | Click with weapon in hand |
| Range | Within takedown range (~1.2m) |
| Position | Behind target (within 60° of back) |
| Awareness | Target is Unaware or Suspicious |
| Aim | Invisible "cursor" hits target (SphereCast against torso/head) |
| Speed | Player below sprint threshold (optional) |

**If all conditions pass → Takedown triggers**
**Otherwise → Normal action (shoot/swing)**

### Takedown Variants

| Weapon | Animation | Duration | Noise Radius |
|--------|-----------|----------|--------------|
| Knife | Silent stab | 0.4-0.7s | 3-5m |
| Katana | Slash/draw-cut | 0.7-1.0s | 6-8m |
| Gun | Pistol-whip → finish | 0.6-0.8s | 6-10m |
| Empty hand | Choke/neck snap | 0.8-1.0s | 4-6m |

### Enemy Awareness States

```
Unaware → Suspicious → Alerted → Combat → Searching → Return-to-Normal
```

| State | Description | Takedown Allowed |
|-------|-------------|------------------|
| **Unaware** | Routine behavior | Yes |
| **Suspicious** | Heard/saw something odd | Yes (riskier) |
| **Alerted** | Confirmed threat | No |
| **Combat** | Active engagement | No |
| **Searching** | Lost target, checking area | No |

---

## 17. Threat + Demand System

### Core Concept

"Threat + Demand" is a first-class interaction system that works for both AI and players.

**Any actor can:**
1. **Issue a Demand** to a target
2. While **maintaining Threat**
3. Target responds based on shared model

### Demand Types

| Demand | Description |
|--------|-------------|
| Open door | Swipe badge / enter PIN |
| Hack terminal | Loop camera / disable alarm / access logs |
| Move to location | Walk to designated point |
| Hands up / kneel | Assume compliant position |
| Drop item | Surrender weapon / keycard |
| Call off guards | Only if target has authority |

### Threat Sources

| Source | Pressure Value |
|--------|----------------|
| Weapon aimed at target | High |
| Proximity + melee weapon | Medium-High |
| Recent violence (shots/kills) | High |
| Allies nearby (numbers) | Medium |
| Restraints applied | Very High |

### Threat Model Formula

```
ThreatScore = AimPressure + Proximity + Numbers + RecentViolence - EscapeOpportunity
```

### AI Response Model

Based on:
- **Permissions** - Can they actually do what's demanded?
- **Traits** - Bravery, lawfulness, composure
- **Context** - Guards nearby, escape routes, surveillance
- **Opportunity** - Silent alarm access if not watched

| Response | Description |
|----------|-------------|
| **Comply (fast)** | Overwhelmed, immediate action |
| **Comply (slow)** | Uncertain, fumbling, nervous |
| **Stall** | Pretend to comply, buying time |
| **Resist** | Run, fight, trigger alarm |
| **Signal** | Silent alarm if opportunity exists |

### Capability Constraints

**NPCs can only perform actions within their role/access:**

| Role | Can Do |
|------|--------|
| Scientist | Open lab doors, access research terminals |
| IT/Hacker | Operate security terminals, loop cameras, door overrides |
| Guard | Open checkpoints, call lockdown, escort |
| Janitor | Access service corridors, maintenance panels |

**If demanded to do something outside permissions:**
- Attempt closest valid equivalent ("I can open Ring-1 but not Ring-3")
- Or stall ("Terminal denies, need admin") while system spawns follow-up path

### Multiplayer Coercion (Later)

**Anti-grief protections:**
- Max hold time before forced resolution
- Captor must maintain threat (aim breaks = compliance pressure drops)
- Certain actions require hands free
- Clear escape windows for targets

---

# PART IV: FACILITY SIMULATION

