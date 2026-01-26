# Tactical Espionage

Metal Gear Solid-style alert phases and environmental interaction.

---

## 10. Tactical Espionage (Metal Gear Solid-Style)

### Alert Phases (MGS-Inspired)

The facility has a **global alert state** that affects all systems:

| Phase | State | Duration | Behavior |
|-------|-------|----------|----------|
| **Phase 0** | Normal | Indefinite | Routine operations |
| **Phase 1** | Caution | 30-60s | Suspicious activity detected |
| **Phase 2** | Alert | Until cleared | Hostile confirmed, active search |
| **Phase 3** | Evasion | 60-120s | Lost contact, searching |
| **Phase 4** | Lockdown | Until resolved | Full facility response |

### Phase Transitions

```
Normal → Caution: Suspicious sound, brief sighting, camera anomaly
Caution → Normal: Timer expires, nothing found
Caution → Alert: Confirmed hostile, shots fired, body found
Alert → Evasion: Lost visual/audio contact with threat
Evasion → Caution: Search timeout, no new contacts
Evasion → Alert: Reacquire target
Alert/Evasion → Lockdown: Major incident (hostage, device, mass casualties)
```

### Environmental Interaction (MGS-Style)

| Element | Interaction |
|---------|-------------|
| **Cardboard boxes** | Hide in place, carried as disguise |
| **Lockers** | Hide bodies, hide self |
| **Dumpsters** | Hide bodies, emergency concealment |
| **Vents** | Alternative routes, eavesdropping |
| **Ceiling panels** | Overhead traversal |
| **Under vehicles** | Concealment, ambush |
| **Food/water** | Poison, drug, distract |
| **Radios** | Intercept communications |
| **Magazines/distractions** | Lure guards |
| **Power boxes** | Create blackouts |
| **Fire alarms** | Force evacuation |
| **PA system** | Broadcast false information |

### Intel System (Codec-Style)

**Handler communication** provides:
- Mission updates
- NPC background info
- Hint system (optional)
- Lore/world-building
- Real-time intel from offsite support

**Implementation:**
- Radio earpiece (immersive)
- Optional—players can ignore
- Context-sensitive tips
- Character development through dialogue

### Scoring/Rating System (MGS-Style)

Post-mission rating based on:

| Factor | Best Rating |
|--------|-------------|
| Alerts triggered | Zero |
| Bodies found | Zero |
| Kills | Zero (ghost) or all targets (assault) |
| Time | Under par |
| Objectives | All complete |
| Evidence left | None |
| Budget efficiency | Under budget |

**Codenames** awarded based on playstyle:
- **Ghost** - No alerts, no kills, no evidence
- **Shadow** - No alerts, clean kills only
- **Panther** - Aggressive stealth, efficient
- **Assault** - Loud and successful
- **Chaos** - High collateral, still won

---

