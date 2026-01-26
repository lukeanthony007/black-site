# NPC AI System

Autonomous behaviors, jobs, and personality.

---

## 21. NPC AI System

### Design Philosophy

**Realistic but not LLM-based.** Believable behavior from simple pieces:
- Perception (what they see/hear)
- Needs/Drives (where they want to go)
- Personality traits
- Memory (recent events)
- State machine for discrete modes
- Utility scoring inside states

### Staff/Civilian Baseline (GTA-Style)

| State | Behavior |
|-------|----------|
| **Routine** | Work, break, travel, clean, talk, idle |
| **Suspicious** | Pause, look, investigate minor anomalies |
| **Threatened** | Back away, comply, call for help |
| **Panic** | Flee, hide, scream, stampede |
| **Silent Alarm** | Trigger alarm if opportunity exists when not watched |
| **Return-to-Normal** | Cooldown after threat passes |

### Guard Baseline

| Behavior | Description |
|----------|-------------|
| Patrol SOP | Follow assigned route, check points |
| Checkpoint SOP | Verify badges, search if triggered |
| Investigate SOP | Respond to sounds/anomalies |
| Escalate SOP | Warn → Contain → Engage |
| Coordinate | Radio-based event-driven communication |

### Elite/QRF/CT

- Containment, breach, clear, extract procedures
- Stronger pursuit and coordination
- Heavier equipment
- Tighter rules of engagement
- Tactical movement and room clearing

### Personality Traits

Each NPC receives randomized (but bounded) traits:

| Trait | Effect |
|-------|--------|
| Bravery | Freeze vs flee vs fight |
| Aggression | Confront vs avoid |
| Lawfulness | Call authorities faster |
| Curiosity | Investigate suspicious noises |
| Composure | Resist panic, make better decisions |

### Crowd Behaviors

- **Panic contagion** - Neighbors escalate fear
- **Herding** - Run toward groups or safe zones
- **Bottleneck avoidance** - Choose open routes
- **Personal space** - Avoid while calm
- **Bystander effect** - Some freeze and watch

### Job System (Autonomous Operations)

**Jobs produce task chains based on the facility:**

```
Courier: Warehouse → Package → Delivery → Return
Guard: Patrol Node A → Node B → Investigate Sound → Escalate
Scientist: Lab → Run Experiment → Move Sample → Archive
IT: Monitor Terminal → Check Logs → Reset Alarm
Janitor: Clean Room A → Restock → Clean Room B
```

**Task execution is event-driven:**
1. Wake on schedule tick or relevant event
2. Evaluate available tasks
3. Claim task (or get assigned by superior)
4. Execute task
5. Publish events as interacting with world

### Simulation LOD (Level of Detail)

| Distance | Simulation Level |
|----------|------------------|
| **Near** | Full AI: movement, perception, combat, triggers |
| **Mid** | Simplified: steering + event reactions |
| **Far** | Ledger only: progress tasks without animation |

---

