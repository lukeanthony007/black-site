# Role Gameplay & Immersive Sim Design

Every role is a complete gameplay experience with agency, not scripts.

---

## 7. Immersive Sim Design

### Core Philosophy

**No role is a "press E simulator."** Every role has meaningful agency, dangerous tools, and the ability to betray, sabotage, or profit. If a scientist's gameplay is "stand at workstation, press E," players quit. Instead: they can rig a centrifuge to explode, steal formula data, sell secrets to China, or poison a rival researcher's coffee.

### The Universal Core Loop: Secrets Economy

**The whole game is stealing and trading research.**

Every role participates in the same economy—just with different access, risks, and methods:

```
WORK LEGITIMATELY (slow, safe)
        ↓
    Earn salary
        ↓
    Build access/trust
        ↓
STEAL SECRETS (fast, risky)
        ↓
    Sell to rival nation
        ↓
    Earn 10x the money
        ↓
    Advance faster
```

**Why this works:**
- Working for one side earns steady money
- But stealing secrets and selling to Russia/China/US pays MORE
- Every role can steal—they just steal different things
- Risk/reward scales with ambition
- Players choose their own pace: loyal employee or double agent

### What Makes an Immersive Sim

| Principle | Implementation |
|-----------|----------------|
| **Player agency always** | Never "follow the script"—always choices |
| **Dangerous tools** | Every role has equipment that can harm/help |
| **Systems interact** | Fire + sprinklers, centrifuge + overload, chemicals + ventilation |
| **Betrayal is valid** | Any role can become a double agent |
| **Environment as weapon** | Everything can be sabotaged or exploited |
| **Multiple profit paths** | Salary, theft, sabotage-for-hire, blackmail |

### Role-Specific Secrets Economy

#### Spy/Operative
| Aspect | Details |
|--------|---------|
| **What they steal** | Primary targets: prototypes, hard drives, scientists |
| **How they profit** | Direct extraction → sell to handler → big payday |
| **Unique sabotage** | Plant explosives, assassinate key personnel, destroy research |
| **Risk level** | Highest (no cover identity, always suspicious if seen) |
| **Agency examples** | Choose extraction method, decide who lives/dies, double-cross handler |

**Spy emergent scenarios:**

| Situation | Player Choices |
|-----------|----------------|
| Guard offers to look away | Pay bribe, kill witness anyway, turn them as asset |
| Scientist wants to defect | Extract them (bonus), take data and leave them, sell their location to security |
| Another operative already inside | Cooperate for split, sabotage their mission, race to objective |
| Target isn't where intel said | Interrogate staff, search systematically, abort and demand refund |
| Extraction compromised | Fight through, find insider help, take hostage for leverage |
| Handler offers bonus for extra target | Accept the risk, negotiate higher pay, refuse and stay focused |

#### Guard
| Aspect | Details |
|--------|---------|
| **What they steal** | Security codes, patrol schedules, camera blind spots, confiscated items |
| **How they profit** | Sell access info to outside buyers, "lose" evidence, accept bribes |
| **Unique sabotage** | Disable cameras "for maintenance," unlock doors, look the other way |
| **Risk level** | Medium (trusted but watched by supervisors) |
| **Agency examples** | Let spy through for cash, frame innocent coworker, steal from evidence locker |

**Guard emergent scenarios:**

| Situation | Player Choices |
|-----------|----------------|
| Suspicious person at checkpoint | Wave through (bribe), full search (confiscate valuables), detain (interrogate) |
| Colleague skimming from evidence | Join them, blackmail them, report for promotion |
| Spy offers money for access | Take bribe and look away, take bribe and betray them anyway, arrest on principle |
| Scientist clearly nervous | Ignore it, follow them discreetly, confront and shake down |
| Post-incident evidence collection | Secure everything properly, pocket key items, plant evidence |
| Ordered to escort VIP | Protect them, lead them into ambush, gather intel on them |

#### Scientist/Researcher
| Aspect | Details |
|--------|---------|
| **What they steal** | Research data, formulas, experimental results, prototype specs |
| **How they profit** | Copy data → dead drop → rival nation pays premium |
| **Unique sabotage** | Rig equipment to fail, contaminate samples, publish "accidentally," poison rivals |
| **Risk level** | Low-Medium (high access, low suspicion, but audited) |
| **Agency examples** | Sabotage competitor's experiment, rig centrifuge to explode during inspection, fake results |

**Scientist gameplay is NOT "press E at workstation":**
- Run actual experiments (mini-games with consequences)
- Decide what to report vs. hide
- Rig equipment as traps or distractions
- Poison the coffee, swap the samples, "accidentally" create a chemical leak
- Access restricted data during "routine work"

**Scientist emergent scenarios:**

| Situation | Player Choices |
|-----------|----------------|
| Running centrifuge | Complete normally, rig to explode if guards approach, sabotage to delay project |
| Colleague asks to borrow keycard | Lend it (alibi), refuse (suspicion), report them (frame job) |
| Security audit incoming | Hide contraband, plant evidence on rival, clean up and act normal |
| Spy breaks into your lab | Help them escape, trigger alarm, negotiate a cut |
| Breakthrough discovery | Report it, hide it for yourself, sell it before publishing |
| Contaminated sample | Fix it quietly, blame colleague, let experiment fail spectacularly |

#### Hacker/IT
| Aspect | Details |
|--------|---------|
| **What they steal** | Database dumps, credentials, encryption keys, communication logs |
| **How they profit** | Exfiltrate data remotely, sell access, enable other agents |
| **Unique sabotage** | Plant backdoors, corrupt backups, forge audit logs, trigger false alarms |
| **Risk level** | Medium (powerful but logged, patterns detected) |
| **Agency examples** | Erase evidence of spy for payment, create fake employee records, blackmail with surveillance footage |

**Hacker gameplay is NOT "press E at terminal":**
- Navigate actual system interfaces
- Race against intrusion detection
- Choose what to copy, delete, or modify
- Plant traps for other hackers
- Watch everything through cameras—decide who to help or expose

**Hacker emergent scenarios:**

| Situation | Player Choices |
|-----------|----------------|
| Spy triggers camera alert | Delete footage, report intrusion, sell footage to spy's rivals |
| Guard requests door override | Grant access, deny ("system error"), trap them inside |
| Detect unauthorized access | Trace the source, ignore it, sell the intel to affected party |
| Backup scheduled tonight | Let it run, corrupt specific files, copy everything first |
| Someone's accessing your terminal | Lock them out, watch what they do, plant malware |
| Foreign server ping detected | Block it, trace it, route your own exfil through it |

#### Janitor/Maintenance
| Aspect | Details |
|--------|---------|
| **What they steal** | Discarded documents, overheard conversations, "lost" items, photos of restricted areas |
| **How they profit** | Sell intel about layouts/schedules, plant bugs, smuggle items out in trash |
| **Unique sabotage** | Cut power "accidentally," create chemical spills, disable locks, plant evidence |
| **Risk level** | Lowest (invisible, but limited high-value access) |
| **Agency examples** | Hide a body in your cart, plant listening device in boardroom, "find" the prototype in the trash |

**Janitor gameplay is NOT "mop floors":**
- Access everywhere (service corridors, vents, restricted during "cleaning")
- Overhear critical conversations while "working"
- Plant bugs, cameras, explosives while "cleaning"
- Use chemicals as weapons or distractions
- Nobody remembers the janitor's face

**Janitor emergent scenarios:**

| Situation | Player Choices |
|-----------|----------------|
| Find classified docs in trash | Pocket them, report security violation, sell to highest bidder |
| Overhear prototype location | Sell info to spy, steal it yourself later, ignore and stay safe |
| Spy hiding in supply closet | Ignore them, lock them in, negotiate cut of their job |
| Guard bribing scientist | Blackmail both, report it, become the middleman |
| Need access to Ring-3 lab | Fake work order, follow authorized person, crawl through vents |
| Body discovered in your zone | Hide it in cart, report it, plant evidence on someone else |

#### Elite/CT Operator
| Aspect | Details |
|--------|---------|
| **What they steal** | Captured intel, defector testimony, recovered prototypes |
| **How they profit** | "Lose" evidence, sell captured tech, accept bribes to botch raids |
| **Unique sabotage** | Flash-bang wrong room "accidentally," let target escape, destroy evidence |
| **Risk level** | Medium-High (scrutinized after operations) |
| **Agency examples** | Execute instead of capture, pocket the prototype, tip off the target beforehand |

**Elite/CT emergent scenarios:**

| Situation | Player Choices |
|-----------|----------------|
| Breach room with prototype | Secure for agency, pocket for yourself, destroy to deny everyone |
| Capture spy with stolen data | Book properly, "lose" evidence, flip them as double agent |
| Hostage knows too much | Extract safely, silence them, use them to get info first |
| Teammate taking bribes | Report, demand cut, gather evidence for later leverage |
| Target offers to surrender | Accept peacefully, "he went for a weapon," let him escape for money |
| Writing post-op report | Accurate account, omit your own actions, frame teammate |

### Every Role Can Betray

| Role | Betrayal Example |
|------|------------------|
| Spy | Double-cross handler, sell to third nation, keep prototype for self |
| Guard | Accept bribe to unlock door, "miss" intruder on patrol, plant evidence |
| Scientist | Sell research to rival, sabotage own facility, defect mid-mission |
| Hacker | Sell access to multiple buyers, blackmail everyone, enable chaos |
| Janitor | Smuggle anything for anyone, plant anything anywhere, see nothing |
| Elite | Let target escape, botch raid intentionally, steal during "securing" |

### The Secrets Black Market

**How selling works:**

1. **Acquire secret** (steal data, photograph document, extract scientist)
2. **Contact buyer** (dead drop, handler meeting, encrypted comm)
3. **Negotiate price** (rarer secrets = higher value)
4. **Make the exchange** (risky—could be a trap)
5. **Collect payment** (funds hit your account)

**Pricing factors:**
| Factor | Effect on Price |
|--------|-----------------|
| Rarity | Unique prototype > common data |
| Timeliness | Fresh intel > stale intel |
| Completeness | Full formula > partial notes |
| Exclusivity | First seller > duplicate seller |
| Buyer desperation | Losing nation pays more |

**Who buys:**
- Rival nations (Russia, US, China)
- Independent brokers (higher risk, higher reward)
- Corporate buyers (side contracts)
- Your own nation (if you're defending and recover stolen goods)

### Role Traversal: Climbing the Ladder

**You're not locked into one role.** Earnings let you afford better roles:

```
Start as Janitor ($) 
    → Earn/steal enough 
    → Buy Guard role ($$)
    → Earn/steal more
    → Buy Hacker role ($$$)
    → Major heist
    → Buy Spy role ($$$$$)
```

**Or go sideways:**
- Janitor → Scientist (if you steal credentials and learn enough)
- Guard → Elite (promotion through performance or bribery)
- Hacker → Any role (you can forge the paperwork)

### Why Every Role is Fun

| Role | Why It's NOT Boring |
|------|---------------------|
| Spy | Obviously fun (power fantasy) |
| Guard | Hunt players, control access, take bribes, be the obstacle |
| Scientist | Dangerous equipment, valuable knowledge, sabotage power |
| Hacker | See everything, control everything, enable/prevent everything |
| Janitor | Ultimate stealth, plant anything, invisible betrayal |
| Elite | Action movie gameplay, life-or-death calls, tactical control |

**The key insight:** Every role has AGENCY. Not scripts. Not "press E." Meaningful choices with real consequences.

---

