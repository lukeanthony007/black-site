# Facility Systems

The Three Graphs, procedural generation, and archetypes.

---

## 18. The Three Graphs

Each run generates and simulates three coupled systems:

### A) FacilityGraph (Space + Traversal)

**Rooms:**
- Labs, offices, bathrooms, storage
- Armory, server rooms, control rooms
- Break rooms, barracks, decon
- Evidence rooms, containment

**Connections:**
- Corridors, stairs, elevators
- Service corridors, maintenance routes
- Doors (normal, badge, blast)
- Mantraps, checkpoints
- Vents/crawlspaces, ladders

**Zone Rings:**
```
Ring 0: Public
Ring 1: Staff
Ring 2: Restricted  
Ring 3: High-Security
Ring 4: Containment
```

**Chokepoints:**
- Security checkpoints
- Badge gates
- Blast doors
- Mantraps

### B) SecurityNet (Tech + Policy)

**Devices:**

| Device | Function |
|--------|----------|
| CCTV (fixed) | Static surveillance |
| CCTV (PTZ) | Pan-tilt-zoom tracking |
| CCTV (thermal) | Heat signature detection |
| Motion sensors | Hallway/doorframe triggers |
| Door access control | Badge + PIN + biometric by ring |
| Metal detectors | Weapon scanning |
| RFID tracking | Badge location logging |

**Systems:**

| System | Function |
|--------|----------|
| Alarm levels | Local → Incident → Lockdown |
| Audit logs | Badge swipes, forced entry, terminal access |
| Security terminals | Camera feeds, door overrides, incident console |
| Lockdown policies | Ring-based sealing, routing changes |
| PA/Intercom | Announcements, alerts |

**Camera Mechanics:**
- FOV / range / update rate / alert threshold
- Live detection → raises suspicion/alert
- Recorded evidence → increases "heat" even after escape
- Can be looped, cut, or disabled

**Terminal Capabilities:**
- View camera feeds
- Lock/unlock specific doors (permission-based)
- Set lockdown policies
- Pull audit trails
- Wipe/corrupt logs (temporarily)

### C) OpsGraph (Hierarchy + Jobs)

**Organizations:**
- Security Division
- Research Division
- IT/Cyber
- Facilities/Maintenance
- Administration

**Hierarchy:**
```
Chief/Director
    └── Supervisors
            └── Workers/Guards/Technicians
```

**SOPs (Standard Operating Procedures):**
- Patrol routes and loops
- Shift changes
- Lab protocols
- Incident escalation procedures
- Containment procedures
- Access approval workflows

**Job Tasks bind to FacilityGraph nodes and obey access rules.**

---

## 19. Procedural Facility Generation

### Schema Components

| Component | Description |
|-----------|-------------|
| Room catalog | Sizes, connectors, props, functions |
| Adjacency rules | Bathrooms near offices, labs behind checkpoints |
| Flow constraints | Public vs staff vs service circulation |
| Security rings | Layered access control |
| Operational nodes | Workstations, terminals, storage, decon |
| Spy routes | Vent/service network separate from normal |

### Adjacency Rules (Examples)

- Bathrooms near offices/barracks
- Break rooms near work areas
- Security checkpoints before restricted labs
- Server room near IT office but in restricted zone
- Emergency egress routes throughout
- Maintenance access routes (utility corridors)

### Generation Outputs

1. **Nav graph** for streets + interiors + rooftops (separate layers with connectors)
2. **Building graphs** - rooms, doors, access permissions, loot nodes, triggers
3. **Service nodes** - workstations, registers, beds, terminals, delivery points
4. **Zone labels** + access controls for AI behavior

---

## 20. Facility Archetypes

### Research Facility (GoldenEye-Style)
- Labs behind Ring-2, server room Ring-3, offices Ring-1
- Vents spanning rings
- Medium security, strong patrol cadence
- Offices, labs, security office, armory, interrogation, control room

### Bunker
- Hardened corridors, checkpoints, blast doors
- Storage, barracks, strong containment SOP
- High security, restricted zones, chokepoints
- Limited vents, strong physical barriers

### Silo / Nuclear Site
- Layered rings, control room, turbine/power
- Strict lockdown, high-consequence response
- Containment zones, alarm-heavy
- Minimal service routes

### Chemical Plant
- Hazmat zones, decon rooms, containment
- Spill response SOP
- Labs with dangerous materials
- Protective equipment requirements

### Archives / Cyber
- Dense terminals/logs, heavy camera coverage
- Fewer guards but stronger audit trails
- Vault stacks, climate rooms, scanning stations
- Access strict, evidence-heavy

### Train / Convoy
- Linear topology, compartment access rules
- Moving constraints
- Rapid posture shifts
- Stealth/pursuit along a line

### Boat / Frigate
- Crew quarters, bridge, engine room
- Storage, narrow corridors
- Tight spaces, vertical decks
- Strong chokepoints, hostage scenarios

---

