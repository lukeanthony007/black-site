## Description

First-person immersive sim where you infiltrate procedurally generated black sites as a loyalty-free operator—stealing secrets, switching sides, and trading intelligence across three rival superpowers.

## Skills / Tools / Stack

- Unity (URP)
- C#
- Procedural Generation
- Autonomous NPC Systems
- Immersive Sim Design

# Summary

Black Site drops you into an operating facility, not a level. Guards patrol, scientists work, IT monitors cameras, janitors clean hallways—all running autonomously before you arrive. The facility has a chain of command, shift schedules, security rings, and standard operating procedures. Your job is to exist inside that system and exploit it.

You play a free-agent operator with no permanent allegiance. Contract with Russia, the United States, or China—then betray them the next run. The entire game revolves around a secrets economy: work legitimately for steady pay, or steal research and sell it to rival nations for 10x the profit. Start as a janitor because it's all you can afford, observe the facility, pocket data while mopping floors, sell it to China, and eventually buy your way into the spy role.

Every mission can flip from silent spycraft to full counter-terror intervention in seconds. Stealth uses Hitman-style social disguises, MGS-style alert phases, and Dishonored-style gadgets. Combat runs on Counter-Strike gunfeel with no crosshair, Mirror's Edge parkour, and dual-wield freedom. Threaten a guard at gunpoint to open a door—the coercion system handles it mechanically. Your choices feed an arms race campaign where nations adapt with better sensors, tighter security, and new technology based on what you stole and who you sold it to.

## Features

- Procedurally generated facilities from realistic schemas—security rings, staff routes, labs, and offices follow real-world adjacency logic
- Autonomous NPC simulation with guards, scientists, IT staff, and janitors running jobs on shift schedules
- Secrets economy where every role participates—steal research, sell to rivals, climb the role ladder
- Role cost system from janitor ($) to spy ($$$$$), each with unique gameplay loops
- Hitman-style social stealth with disguises, enforcers, and suspicious action detection
- Dishonored-style gadget loadouts including grapple, EMP, decoy, remote hack, and x-ray vision
- MGS-style alert phases with escalation from suspicion through full lockdown
- Counter-Strike gunfeel with no crosshair, recoil patterns, and movement penalties
- Mirror's Edge parkour with wallruns, vaults, slides, and dive-roll shooting
- Dual-wield system with independent per-hand actions and mixed weapon combos
- Gesture melee using mouse-swing tracking for punches, gun-bashes, and blade attacks
- Threat and demand coercion—"open the door or I shoot" works mechanically for AI and players
- Continuous escalation from stealth to counter-terror intervention with no resets
- Three-nation arms race campaign where Russia, US, and China evolve based on your actions
- Player-funded escalation with personal budget for gear, support, and role upgrades
- Seven facility archetypes: research facility, bunker, silo, chemical plant, cyber/archives, train, and frigate

### Roadmap

1. Core movement—sprint, jump, vault, wallrun, slide, dive-roll, crouch sneak
2. Gun feel—no-crosshair firing, recoil patterns, spread model, impact effects
3. Dual wield, gesture melee, and stealth takedowns
4. Procedural facility generation with security rings, vents, and door access control
5. Autonomous NPC jobs, security tech, and threat/demand coercion
6. Escalation state machine with CT response spawning
7. Disguise system, gadget loadouts, and alert phases
8. Campaign ledger with national research trees and doctrine changes

### Instructions

1. Browse the full game design document in the `BLACK_SITE_GDD/` directory
2. Start with `01_introduction/01_overview.md` for the high concept and design pillars
3. Read `01_introduction/02_core_loop.md` for the secrets economy and player identity
4. Explore `02_gameplay/` for detailed systems—combat, stealth, roles, gadgets, missions
5. See `04_production/18_development.md` for the vertical slice scope and phase milestones

### License

MIT
