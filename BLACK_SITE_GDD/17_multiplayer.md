# Multiplayer Readiness

Network architecture preparation.

---

## 29. Multiplayer Readiness

### Design Principles (Apply Even in Singleplayer)

- Separate Input → Simulation → Presentation
- Keep combat authoritative in "server-style" way:
  - Player sends intent (fire/melee/takedown)
  - Game validates and applies results via single source of truth

### Later Multiplayer Target

| Feature | Implementation |
|---------|----------------|
| Model | Host-client or dedicated server |
| Movement | Client-predicted, server-authoritative |
| Shooting | Lag compensation for hitscan |
| Melee/Takedowns | Server-authoritative validation |
| Coercion | Same Threat+Demand system for players |

### Multiplayer Coercion Protections

- Max hold time before forced resolution
- Captor must maintain threat
- Clear escape windows
- Anti-stall mechanics

---

# PART VIII: DEVELOPMENT

