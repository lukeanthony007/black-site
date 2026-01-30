# Appendices

Glossary, design decisions, and checklists.

---

## A. Glossary

| Term | Definition |
|------|------------|
| **FacilityGraph** | Spatial layout: rooms, corridors, vents, doors |
| **SecurityNet** | Tech systems: cameras, sensors, alarms, access |
| **OpsGraph** | Hierarchy and jobs running autonomously |
| **SOP** | Standard Operating Procedure |
| **Ring** | Security access level (0-4) |
| **Posture** | Current security state of facility |
| **QRF** | Quick Reaction Force |
| **CT** | Counter-Terror |
| **Threat + Demand** | Coercion interaction system |
| **Arms Race** | Campaign meta-game of national research |
| **Immersive Sim** | Genre focused on player agency and multiple solutions |
| **Enforcer** | NPC who can see through specific disguises |
| **Alert Phase** | MGS-style global facility awareness state |
| **Role Cost** | Budget required to play a specific role |
| **Gadget** | Dishonored-style tool enabling creative solutions |
| **Social Stealth** | Hitman-style blending via disguises/behavior |
| **Ghost** | Playstyle with no alerts, kills, or evidence |

## B. Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Crosshair | None | CS-style skill ceiling |
| Movement base | Kinematic motor | Consistent parkour |
| Melee input | Modifier key | Allows automatic guns |
| Escalation | Continuous | No round resets |
| Player allegiance | None | Double-agent freedom |
| Budget system | Dual (personal + operation) | Run-and-gun viability |
| Role costs | Tiered pricing | Spy expensive, janitor cheap |
| Genre | Immersive sim | Every role must be fun |
| Social stealth | Hitman-style disguises | Multiple approach options |
| Gadgets | Dishonored-style variety | Creative problem-solving |
| Alert system | MGS-style phases | Clear escalation feedback |
| Scoring | Optional rating | Replayability, mastery |

## C. Role Design Checklist

Every role must answer YES to these questions:

- [ ] Does this role have a unique gameplay loop?
- [ ] Can this role complete objectives in satisfying ways?
- [ ] Does this role have meaningful choices?
- [ ] Is playing this role different from other roles?
- [ ] Can a skilled player succeed with this role?
- [ ] Does this role interact with facility systems uniquely?
- [ ] Is there a reason to replay as this role?

## D. Immersive Sim Checklist

Every mission/facility must provide:

- [ ] 3+ approaches to main objective
- [ ] Multiple entry points
- [ ] Non-lethal completion possible
- [ ] Loud completion possible
- [ ] Social/disguise route available
- [ ] Technical/hacking route available
- [ ] Parkour/traversal shortcuts
- [ ] Environmental storytelling
- [ ] Systems that interact meaningfully
- [ ] Consequences for player choices

---

*Document Version: 2.0*
*Last Updated: January 2026*
*Title: BLACK SITE - Complete Game Design Document*
*Total Sections: 33 + Appendices*

---

## Document Structure

**Part I: Overview** (Sections 1-5)
- High Concept, Pillars, Setting, Game Loop, Player Identity

**Part II: Economy & Roles** (Sections 6-12)  
- Role Costs, Immersive Sim Design, Disguises, Gadgets, Tactical Espionage, Missions, Resources

**Part III: Movement & Combat** (Sections 13-17)
- Movement, Gunplay, Melee, Stealth, Threat+Demand

**Part IV: Facility Simulation** (Sections 18-23)
- Three Graphs, Generation, Archetypes, NPC AI, Escalation, CT/Terrorists

**Part V: Nations & Campaign** (Sections 24-25)
- National Doctrines, Arms Race

**Part VI: Technical** (Sections 26-29)
- Visual Style, Technical Targets, Architecture, Multiplayer

**Part VII: Development** (Sections 30-33)
- Vertical Slice, Milestones, Controls, Tuning

**Appendices**
- Glossary, Design Decisions, Checklists
