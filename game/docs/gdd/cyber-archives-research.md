# Cyber / Archives Facility — Research and Procedural GDD

**Goal:** Research and procedurally generate a functionally authentic Cyber/Archives facility whose jobs, security, infrastructure, and failure procedures form a believable autonomous operation.

**Status:** First source-grounded design pass  
**Researched:** 2026-07-16 EDT  
**Target:** One newly generated, internally coherent facility per run

---

## 1. Design thesis

The facility is not a maze decorated like a secret laboratory. It is an operating institution.

The generator must begin with a mission and produce the jobs, rooms, equipment, access rules, utility dependencies, circulation, and emergency procedures needed to sustain that mission. The playable map is the spatial consequence of that operating model.

The first facility combines two coupled missions:

1. **Cyber research and operations** receive questions, run isolated investigations, monitor systems, handle incidents, and produce technical findings.
2. **Archives and records custody** receive those findings and their evidence, classify and index them, preserve them, retrieve them for authorized work, and eventually review them for transfer, release, or destruction.

The key gameplay property is consequence: disabling cooling affects compute; losing credentials closes secure routes; interrupting accession leaves evidence unregistered; isolating a network segment changes what analysts can see; a fire-door closure changes both circulation and records survival.

---

## 2. Scope and honesty boundary

### In scope

- Public federal building, cybersecurity, continuity, records-storage, and security criteria.
- Functional room types and job relationships.
- Plausible secure circulation and layered authorization.
- Continuous operation across shifts.
- Power, cooling, communications, fire protection, water-risk, maintenance, and logistics dependencies.
- Procedures for ordinary work and degraded operation.
- Constraint-driven procedural generation.

### Not claimed

- A replica of an active classified facility.
- Knowledge of classified operating procedures.
- Exact SCIF construction details not obtained from a public source during this research pass.
- A realistic attack guide or bypass map for a real site.

Public standards are used to derive a fictional but functionally coherent institution. Exact real-facility plans are neither required nor assumed.

---

## 3. Evidence ledger

### Retrieved and read

1. **NIST SP 800-53 Revision 5 — Security and Privacy Controls for Information Systems and Organizations**  
   https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf

   Design-bearing controls include:
   - AU-2 Event Logging
   - CP-2 Contingency Plan
   - CP-4 Contingency Plan Testing
   - CP-7 Alternate Processing Site
   - CP-10 System Recovery and Reconstitution
   - IR-4 Incident Handling
   - PE-2 Physical Access Authorizations
   - PE-3 Physical Access Control
   - PE-11 Emergency Power
   - PE-14 Environmental Controls
   - PE-15 Water Damage Protection
   - MP controls for media access, storage, transport, and sanitization

2. **CISA Zero Trust Maturity Model Version 2.0**  
   https://www.cisa.gov/sites/default/files/2023-04/CISA_Zero_Trust_Maturity_Model_Version_2_508c.pdf

   CISA organizes the model around five pillars—Identity, Devices, Networks, Applications and Workloads, and Data—with Visibility and Analytics, Automation and Orchestration, and Governance crossing all five.

3. **NARA Records Storage Standards Toolkit**  
   https://www.archives.gov/records-mgmt/storage-standards-toolkit

4. **NARA Facility Standards presentation**  
   https://www.archives.gov/files/records-mgmt/toolkit/pdf/file8.pdf

   The retrieved presentation describes, among other requirements:
   - non-combustible construction;
   - flood and water-intrusion considerations;
   - posted structural floor-load limits;
   - no ordinary piping through records-storage areas except required fire-protection piping;
   - load-safe and seismically braced storage systems;
   - anti-intrusion alarms;
   - separation of storage bays with rated fire barriers;
   - separation of storage from auxiliary spaces;
   - controlled penetrations and self-closing rated doors;
   - redundant primary power as a design expectation for newer facilities;
   - positive air pressure for permanent-record storage areas.

5. **NARA Appendix A — Minimum Security Standards for Level III Federal Facilities**  
   https://www.archives.gov/files/records-mgmt/toolkit/pdf/file6.pdf

   This supports perimeter, parking, entry, visitor identification, interior security, threat nomenclature, planning, and training as separate operational responsibilities rather than one generic “security room.”

6. **NARA Appendix B — fire-safety detection and suppression material**  
   https://www.archives.gov/files/records-mgmt/toolkit/pdf/file7.pdf

7. **NARA toolkit guidance for agency-operated and commercial records centers**  
   https://www.archives.gov/records-mgmt/storage-standards-toolkit/file2.html  
   https://www.archives.gov/records-mgmt/storage-standards-toolkit/file3.html

   The guidance makes approval, documentation, inspection, material-change review, and records-officer responsibility part of the operating system. A facility is not compliant merely because it was built once.

8. **GSA 2024 P100 — Facilities Standards for the Public Buildings Service**  
   https://www.gsa.gov/system/files/P100%202024%20Final%2010012024.pdf

   Relevant themes include mission-critical resilience, facility-specific risk assessment, security countermeasures spanning architecture and engineering, thermal resilience, fire command and security control centers, UPS/battery rooms, loading-dock separation, maintainability, and redundancy.

### Identified but not fully retrieved in this pass

9. **UFC 4-010-05 — SCIF/SAPF Planning, Design, and Construction**  
   Public index: https://www.wbdg.org/ffc/dod/unified-facilities-criteria-ufc/ufc-4-010-05

10. **Technical Specifications for Construction and Management of Sensitive Compartmented Information Facilities**  
    Public ODNI/NCSC document host was identified, but automated retrieval returned HTTP 403.

These two sources remain research obligations. No detailed SCIF requirement below is attributed to them until the text is successfully retrieved and reviewed.

---

## 4. Source-derived design requirements

The following requirements are faithful game abstractions of the retrieved public material.

### 4.1 Authorization is layered

A single badge level is too shallow. Access is a decision over:

- person and role;
- current assignment;
- clearance or formal authorization;
- need to access this room or data set;
- device state;
- time and shift;
- escort state;
- incident posture.

**Game rule:** a credential is necessary but may not be sufficient. Doors evaluate a compact access policy, allowing believable states such as “authorized analyst, wrong project,” “maintenance role, escorted only,” or “valid badge, facility in lockdown.”

### 4.2 Physical entry and system entry are separate

NIST PE-3 distinguishes facility access from access to spaces containing concentrated system components. CISA further separates identity, device, network, application/workload, and data decisions.

**Game rule:** reaching a workstation does not mean the player can use its systems. A room, terminal, device, network enclave, application, and archive collection may each impose a different gate.

### 4.3 Logging is operational evidence

Event logging and records custody imply a continuous evidence trail.

**Game rule:** badge reads, visitor registration, door overrides, network changes, experiment starts, media transfers, archive retrieval, alarms, and emergency shutdowns produce records. Some jobs exist to review and reconcile those records.

### 4.4 Cyber work requires containment and recovery

NIST IR-4 frames incident handling as preparation, detection and analysis, containment, eradication, and recovery. CP controls add tested contingency plans, alternate processing, backups, and recovery to a known state.

**Game rule:** the facility needs isolated analysis rooms, quarantine storage, incident command, recovery images/backups, and procedures that can move work into a degraded mode.

### 4.5 Compute requires a physical plant

Emergency power, environmental controls, and water-damage protection make compute dependent on electrical, cooling, fire, plumbing-isolation, and maintenance systems.

**Game rule:** server and operations spaces consume power and cooling. UPS bridges short interruptions; generators or alternate feeds support longer operation; cooling failure forces progressive shedding rather than instant arbitrary failure.

### 4.6 Archives require custody, fire compartmentation, and environmental control

NARA treats records facilities as inspected systems with structural, fire, water, security, environmental, and storage-equipment requirements.

**Game rule:** archives are not shelves placed in an office. They have intake, inspection, processing, secure bays, rated separations, controlled penetrations, restricted utility routing, environmental monitoring, retrieval control, and disaster response.

### 4.7 Compliance is maintained, not inherited

NARA guidance requires approval, documentation, periodic inspection, and review after material changes.

**Game rule:** inspectors, records officers, facilities engineers, and security managers maintain the facility’s standing. Deferred defects create operational risk and can produce mission events.

---

## 5. Facility mission model

### Inputs

- research directives;
- threat intelligence and telemetry;
- software, firmware, hardware, and removable media;
- captured technical evidence;
- staff, contractors, supplies, and replacement equipment;
- external power, communications, water, and fuel.

### Outputs

- research findings;
- validated tools and defensive techniques;
- incident reports;
- preserved evidence packages;
- indexed records and retrieval packages;
- audit and compliance records;
- sanitized or destroyed media;
- transfer packages for another repository or authority.

### Persistent state

- personnel and role assignments;
- credential and escort state;
- project compartments;
- device inventory and health;
- network enclave state;
- active research cases;
- archive catalog and custody history;
- facility condition and outstanding maintenance;
- emergency posture;
- power, cooling, fuel, and consumable reserves.

---

## 6. Jobs that make the facility function

Each job owns facts, consumes inputs, produces outputs, and has a physical station.

| Job | Owns | Station | Needs | Produces | Failure consequence |
|---|---|---|---|---|---|
| Facility director | mission priority and operating posture | command office | briefings, status reports | priorities, authorizations | conflicting work and delayed decisions |
| Duty officer | current shift coordination | operations control | handover, alarms, staffing | tasking, escalation | unattended incidents and stalled responses |
| Security control officer | physical access state | security control center | sensors, access requests | access decisions, lockdowns | unauthorized movement or sealed routes |
| Guard / screening officer | entry and visitor custody | gate, lobby, screening | identity, manifests | admitted/denied/escorted persons | uncontrolled entry or delivery backlog |
| Cyber operations analyst | current operational picture | operations floor | telemetry and intelligence | triage, alerts, cases | threats remain unclassified |
| Cyber researcher | research hypothesis and experiment | research workstation/lab | approved case, data, tools | findings and artifacts | mission backlog or unsafe experimentation |
| Malware / forensic analyst | isolated evidence examination | contained analysis lab | evidence package, clean environment | indicators, report, derived samples | contamination or evidence loss |
| Network engineer | enclave topology and service state | network operations room | change request, inventory | routes, segments, recovery actions | lost visibility or service interruption |
| Identity administrator | digital authorization state | identity administration | personnel status, approvals | accounts, tokens, revocations | stale or missing access |
| Systems administrator | compute/workload health | server operations | power, cooling, approved changes | available systems and backups | research and archives become unavailable |
| Incident commander | active incident strategy | incident room | correlated reports | containment and recovery plan | contradictory response actions |
| Records officer | records policy and disposition | records administration | schedules, legal/mission rules | retention and custody decisions | orphaned or improperly handled records |
| Accession technician | intake registration | archive receiving/accession | sealed transfer, manifest | accession record and custody handoff | unregistered material enters storage |
| Media examiner | intake safety and condition | inspection/quarantine | received media | cleared, quarantined, or rejected package | contamination enters production/archive |
| Digitization technician | faithful digital surrogate | scan/digitization room | cleared records | scans, checksums, metadata | unusable or untrustworthy copies |
| Cataloger / archivist | descriptive metadata and location | processing room | accession package | indexed collection and finding aids | records become functionally lost |
| Retrieval officer | authorized circulation | archive service desk | approved request | tracked issue/return package | chain of custody breaks |
| Vault custodian | physical storage state | secure stacks/vault | catalog locations, environment | preserved holdings | loss, damage, or misplacement |
| Media sanitization officer | controlled destruction | destruction room | approved disposition | destruction certificate | sensitive remnants survive |
| Facilities engineer | building systems | engineering control/workshop | sensors, work orders, spares | repaired utilities | cascading plant failure |
| Electrical technician | distribution, UPS, generators | electrical rooms | load state, fuel, spares | stable power | compute shutdown and access failures |
| HVAC technician | temperature, humidity, pressure | mechanical plant | sensor state, filters, power | viable environment | compute trip or archive damage |
| Fire/life-safety officer | fire system readiness | fire command center | alarms, inspections | response and evacuation control | uncontrolled spread or unsafe evacuation |
| Logistics receiver | material flow | loading and receiving | deliveries, manifests | screened internal shipments | parts and supplies stop moving |
| Custodial / waste staff | cleanliness and waste custody | service areas | routes, schedules | clean spaces, segregated waste | contamination, obstruction, evidence leakage |
| Medical responder | immediate staff care | clinic/first aid room | access and supplies | stabilized personnel | avoidable loss and blocked operations |

### Shift model

A minimal autonomous facility has three staffing classes:

1. **Continuous:** security control, guard coverage, duty officer, cyber monitoring, facilities watch.
2. **Extended-hours/on-call:** network, systems, electrical, HVAC, fire/life safety, incident response.
3. **Business-cycle:** research teams, archives processing, compliance, administration, procurement.

Every continuous station requires a handover point and a relief route. The generator must not produce a facility that operates only while every employee is present.

---

## 7. Functional zones and room catalog

### Z0 — External and perimeter

- approach road;
- vehicle barrier/checkpoint;
- employee and visitor parking separated where scale permits;
- protected delivery approach;
- generator, fuel, transformer, and cooling yards;
- emergency assembly point.

### Z1 — Public and screened entry

- security vestibule;
- reception;
- visitor registration;
- screening room;
- waiting/holding room;
- guard office;
- package screening;
- public interview/briefing room.

### Z2 — Staff support and administration

- staff entrance;
- locker/change area;
- offices;
- conference and briefing rooms;
- training room;
- break room/canteen;
- toilets;
- clinic/first aid;
- general supply storage.

### Z3 — Cyber operations

- security operations floor;
- duty officer station;
- network operations room;
- identity administration room;
- incident command room;
- secure briefing room;
- researcher workrooms;
- equipment staging;
- controlled print/reproduction room.

### Z4 — Contained research

- sample intake and quarantine;
- isolated malware/forensic labs;
- hardware analysis bench room;
- clean build/recovery room;
- air-gapped enclave rooms;
- controlled removable-media store;
- evidence packaging room.

Contained research must have a controlled material path separate from ordinary office circulation.

### Z5 — Digital infrastructure

- communications entrance/demarcation;
- network distribution rooms;
- primary server room;
- backup/storage room;
- operations console area;
- UPS and battery room;
- electrical switchgear;
- cooling distribution and mechanical support;
- maintenance access.

### Z6 — Archive accession and processing

- secure receiving vestibule;
- manifest/custody desk;
- inspection and quarantine;
- temporary holding;
- digitization room;
- metadata/cataloging room;
- quality-control station;
- archival packaging/supply room.

### Z7 — Archive storage and service

- controlled retrieval desk;
- secure stacks split into fire compartments;
- special-media room;
- high-value vault;
- returned-material inspection;
- authorized research/reading room where the mission requires one;
- disaster-recovery supplies;
- approved destruction staging and sanitization room.

### Z8 — Facility plant and service

- loading dock and receiving;
- screened internal receiving;
- freight/service corridor;
- maintenance shop;
- janitorial rooms;
- waste segregation;
- fire command center;
- security control center;
- mechanical rooms;
- electrical rooms;
- emergency generator and fuel systems.

---

## 8. Adjacency and separation rules

### Hard adjacency requirements

- Entry security must see or control every ordinary personnel entrance.
- Loading must connect to screening before internal logistics.
- Archive receiving must connect to accession and quarantine before storage.
- Digitization must connect to cleared archive processing, not directly to public circulation.
- Contained cyber labs must connect to evidence/sample control and clean recovery.
- Server rooms must connect to power, cooling, network distribution, and maintenance access.
- Security control must receive access-control and intrusion-alarm state.
- Fire command must be reachable during ordinary circulation failure.
- UPS must bridge protected loads to orderly shutdown or alternate power.

### Hard separation requirements

- Public circulation cannot enter controlled work without screening and authorization.
- Delivery circulation cannot bypass package/material screening.
- Unexamined media cannot enter production networks or archive stacks.
- Archive storage cannot share ordinary wet-service routing.
- General waste cannot share the controlled media-destruction chain.
- Visitor circulation cannot silently merge with unescorted staff circulation.
- Contained research networks cannot share an unmediated connection with production operations.
- A single door failure must not create a direct public-to-high-security path.

### Soft adjacency preferences

- Operations near incident command.
- Researchers near secure briefing and controlled print.
- Archive processing near accession and storage, but buffered from loading noise and exterior risk.
- Staff support near shift stations without crossing high-security rooms.
- Facilities workshop near plant and service routes.
- Security control near the protected entry but not exposed directly to the public lobby.

---

## 9. Security-depth model

Security depth is represented as policy transitions, not colored keys.

| Tier | Typical spaces | Ordinary requirements |
|---|---|---|
| 0 — External | roads, yards, public approach | perimeter policy |
| 1 — Screened public | reception, waiting, interview | identity/visitor registration |
| 2 — Controlled staff | offices, support, training | valid staff or escort |
| 3 — Restricted operations | SOC, NOC, records processing | role plus assignment |
| 4 — Compartmented work | contained labs, project rooms, secure stacks | role, need, project authorization |
| 5 — Critical custody/plant | vault, identity core, primary compute, key plant controls | narrow role, dual control or explicit task where applicable |

A generated route is valid only if its transition sequence is monotonic unless it passes through a staffed or automated downgrade boundary such as exit screening, return inspection, or material sanitization.

---

## 10. Facility dependency graph

```text
external power ─┬─> switchgear ─> UPS ─> critical compute
                └─> mechanical plant ─> cooling ─> compute + archives

generator + fuel ─> alternate distribution ─> selected critical loads

communications entrance ─> network core ─> enclaves ─> cyber operations
                                              └─> digital archive services

identity records ─> physical access decisions ─> room circulation
                 └> digital authorization ─> devices/apps/data

research directive ─> approved case ─> contained experiment ─> findings
                                                          └─> evidence package

evidence package ─> accession ─> quarantine/inspection ─> catalog ─> storage
                                                        └─> digitization

catalog + authorization ─> retrieval ─> issue/use ─> return inspection ─> storage

alarms + logs + staff reports ─> duty officer / incident command ─> response
```

No critical node may exist without a job that monitors it and a procedure for its failure.

---

## 11. Rudimentary autonomous operating procedure

### Normal mission cycle

1. **Receive directive** — director/duty officer opens a mission case.
2. **Authorize work** — security, identity, and project authority assign personnel, devices, rooms, and data access.
3. **Stage inputs** — evidence/media pass through receiving, custody registration, and quarantine.
4. **Prepare environment** — systems staff instantiate an approved isolated environment from a known baseline.
5. **Conduct research** — researchers execute bounded work; operations and logging remain active.
6. **Review findings** — technical peer review and security review classify the result and its handling requirements.
7. **Accession evidence** — records staff register authoritative outputs, manifests, custody, and retention requirements.
8. **Preserve and index** — archives package, digitize where appropriate, catalog, and store.
9. **Publish controlled output** — authorized findings are delivered to their consumers.
10. **Close or continue** — the case is closed, branched, or held for further evidence.

### Continuous support cycle

1. Monitor power, cooling, network, alarms, access, environmental conditions, and capacity.
2. Detect threshold violations.
3. Open a work order or incident.
4. Assign responsible staff and authorize access.
5. Isolate affected equipment or area.
6. Repair, replace, or shift load.
7. Test service restoration.
8. Record the intervention and update facility standing.
9. Replenish consumed spares, fuel, filters, and emergency supplies.

### Archive circulation cycle

1. Receive an authorized request.
2. Verify requester, purpose, collection authority, and destination.
3. Locate material from the catalog.
4. Remove it under custody tracking.
5. Inspect and issue it.
6. Monitor due state and authorized use.
7. Receive and inspect return.
8. Reconcile contents and custody.
9. Re-shelve or quarantine.
10. Close the circulation record.

---

## 12. Degraded-day procedures

Failures are game states with procedures, not binary decoration.

### Primary power loss

1. UPS carries critical loads.
2. Noncritical loads shed.
3. Generator/alternate supply starts.
4. Duty officer declares degraded posture.
5. Research experiments checkpoint or terminate safely.
6. Archives environmental monitoring remains powered.
7. If alternate power is unstable, systems perform orderly shutdown.
8. Recovery requires power stabilization, equipment checks, and logged reconstitution.

### Cooling degradation

1. Detect rising temperature/humidity or loss of pressure control.
2. Shift compute load and stop nonessential experiments.
3. Isolate failed plant component.
4. Protect archive conditions and special media first according to local policy.
5. Deploy repair staff through service circulation.
6. If thresholds continue to rise, shut down affected compute zones or relocate vulnerable holdings.

### Cyber incident

1. Detect and classify.
2. Preserve relevant logs and volatile evidence.
3. Segment or isolate affected devices/enclaves.
4. Move command to incident mode.
5. Continue essential functions through unaffected systems where possible.
6. Eradicate or rebuild from a known state.
7. Validate recovery.
8. Accession incident evidence and after-action records.

### Unauthorized physical access

1. Alarm and localize.
2. Freeze or narrow affected access zones.
3. Account for visitors and staff.
4. Dispatch security without opening wider bypasses.
5. Protect critical rooms and custody chains.
6. Investigate badge, door, camera, and system logs.
7. Restore access in controlled stages.

### Archive water or fire event

1. Alarm, isolate utilities where safe, and activate life-safety response.
2. Close compartment boundaries.
3. Evacuate or account for personnel.
4. Protect unaffected bays from spread.
5. Establish salvage triage only after the area is safe.
6. Track every moved container as a custody event.
7. Stabilize, dry/freeze/relocate according to media-specific recovery plans.
8. Reconcile catalog locations and document losses.

### Communications loss

1. Detect failed external or internal path.
2. Preserve local operations and local logging.
3. Shift to alternate communications where available.
4. Restrict changes that cannot be externally validated.
5. Queue outbound reports and archive transfers.
6. Reconcile queued actions when connectivity returns.

### Staff shortage

1. Identify uncovered continuous stations.
2. Consolidate operations into minimum-safe posture.
3. Suspend nonessential research and archive processing.
4. Preserve security, life safety, plant monitoring, and custody first.
5. Call qualified relief staff.
6. Record deferred tasks and risk acceptance.

---

## 13. Procedural-generation model

### 13.1 Generate operation before geometry

```text
seed
→ mission profile
→ operating scale and staffing
→ security/records policy
→ required processes
→ jobs and stations
→ room program
→ adjacency/separation graph
→ utility graph
→ circulation graph
→ floor/volume layout
→ doors and policy transitions
→ equipment and dressing
→ failure scenarios
→ validation
→ playable facility
```

### 13.2 Facility specification

```gdscript
FacilitySpec {
    seed
    mission_profile
    staff_capacity
    shift_model
    research_compartments
    archive_media_classes
    archive_capacity
    security_posture
    continuity_target
    site_constraints
    utility_sources
    failure_scenarios
}
```

### 13.3 Room node

```gdscript
RoomSpec {
    id
    function
    zone
    security_tier
    required_jobs
    capacity
    equipment
    environmental_profile
    utility_loads
    required_neighbors
    forbidden_neighbors
    circulation_classes
    failure_modes
}
```

### 13.4 Edge types

- personnel circulation;
- escorted visitor circulation;
- material/evidence circulation;
- service/maintenance circulation;
- emergency egress;
- power;
- cooling/air;
- communications;
- fire compartment boundary;
- policy transition;
- sight/sensor coverage.

The generator must not reduce all relationships to doorway adjacency.

### 13.5 Hard generation invariants

A generated facility is rejected unless:

1. Every occupied room has a valid emergency egress path.
2. Every normal entrance passes through an entry-control function.
3. No public path reaches Tier 3–5 without a policy transition.
4. Loading cannot reach internal storage without screening.
5. Unexamined media cannot reach production cyber rooms or archive stacks.
6. Every archive bay is in a storage compartment separated from auxiliary/service space.
7. Archive storage has no ordinary wet-service route through it.
8. Every critical compute room has power, UPS/alternate-power policy, cooling, communications, and maintenance access.
9. Every continuous station has staff access, relief circulation, and a handover location.
10. Security control can observe access/alarm state without being exposed directly to the public zone.
11. Every critical system has an owner job and a degraded procedure.
12. The facility has no single ordinary doorway that bypasses multiple security tiers.
13. Restricted material has a complete receiving-to-custody-to-storage path.
14. Controlled destruction cannot merge with ordinary waste before sanitization is complete.
15. The generated mission can complete its normal cycle with the generated jobs and rooms.

### 13.6 Soft optimization goals

Score valid layouts for:

- short routine staff routes;
- minimal crossing between public, staff, material, and service flows;
- compact utility distribution;
- useful security depth;
- maintainable plant access;
- limited exterior exposure of critical rooms;
- archive protection from water, loading impact, vibration, and uncontrolled access;
- redundancy without impossible duplication;
- legible player navigation;
- multiple tactical approaches that do not violate the institution’s basic logic.

### 13.7 Generation strategy

1. Build a typed graph from the selected mission profile.
2. Expand mandatory process templates into room nodes.
3. Allocate security zones.
4. Place anchor nodes: entry, loading, operations, archive storage, compute, and plant.
5. Solve hard adjacency and separation constraints.
6. Route distinct circulation classes.
7. Route utilities and reject impossible or forbidden penetrations.
8. Add redundancy according to continuity target.
9. Convert graph regions into floor-plan cells and vertical levels.
10. Insert doors, vestibules, stairs, lifts, barriers, and service access.
11. Dress rooms from their function and current operating state.
12. Simulate one normal mission cycle and each selected degraded scenario.
13. Reject any layout whose process, custody, access, utility, or egress graph fails.

---

## 14. First playable facility profile

### Cyber/Archives — Rudimentary autonomous site

**Scale:** 90–140 staff, with a smaller continuous night shift.  
**Floors:** two occupied floors plus a plant/service level or roof/yard plant.  
**Mission:** defensive cyber research, incident analysis, and custody of technical evidence and institutional records.  
**Continuity:** critical monitoring, security, custody, and plant supervision continue during a single utility or staffing fault.

### Required anchors

- one screened public/staff entry;
- one screened service/loading entry;
- security control;
- operations floor;
- two contained analysis labs;
- network/server core;
- UPS and alternate-power connection;
- archive accession suite;
- digitization/cataloging suite;
- at least two separated archive storage compartments;
- special-media vault;
- controlled destruction room;
- mechanical/electrical plant;
- fire command/life-safety station;
- staff support and shift handover.

### Suggested vertical organization

**Service/plant level**
- switchgear, UPS, batteries, cooling plant, workshops, service corridor, protected communications entry.

**Ground floor**
- perimeter and entry, reception, screening, administration, loading, internal receiving, archive accession, quarantine, destruction staging, security control.

**Upper secure floor**
- cyber operations, incident command, contained labs, server/network rooms, archive processing, secure stacks, vault, controlled staff support.

This is a starting arrangement, not a fixed blueprint. A valid one-floor campus or deeper vertical facility is allowed if it satisfies the same operating graph.

---

## 15. Gameplay translation

The player should infer the institution from behavior:

- Shift changes move guards and analysts through believable routes.
- Archive retrieval causes a request, staff movement, vault opening, issue, and return.
- Deliveries wait at screening and create internal logistics tasks.
- Facilities staff respond to alarms through service routes.
- A cooling fault changes fan noise, room temperature, staff behavior, and compute availability.
- A credential revocation changes both doors and terminals.
- Incident posture closes some routes while opening emergency or maintenance procedures.
- Destroying or stealing a record changes custody and investigation state.
- Cutting power does not make everything instantly dark; UPS, emergency lighting, load shedding, generators, and orderly shutdown occur in sequence.

The best stealth opportunities arise from real process transitions: shift handover, maintenance windows, escorted deliveries, archive circulation, incident containment, and emergency reconfiguration.

---

## 16. Implementation order

1. **Operational graph prototype** — jobs, processes, rooms, typed dependencies, no geometry.
2. **Validator** — prove the normal mission cycle and hard invariants.
3. **Zone and adjacency solver** — produce abstract floor-plan graphs.
4. **Circulation classes** — staff, visitor, material, service, and egress routes.
5. **Utility graph** — power, cooling, communications, fire, and restricted wet services.
6. **Blockout generator** — convert valid graphs into Godot geometry.
7. **Door/access policies** — room and system authorization states.
8. **Job simulation** — shifts, handovers, work queues, maintenance, custody.
9. **Degraded-day simulation** — power, cooling, incident, archive, communications, and staffing failures.
10. **Mission and stealth layer** — objectives exploit the generated institution without breaking its logic.

Do not begin with decorative room kits. The first proof is an abstract facility that can run one normal workday and survive one selected failure without violating custody, access, or infrastructure invariants.

### Implemented tracer bullet — operational graph

The first implementation slice now exists at:

- `res://scripts/facility/facility_operation_graph.gd`
- `res://scripts/dev/facility_operation_selftest.gd`
- `res://scenes/dev_facility_operation_selftest.tscn`

It currently provides:

- deterministic seeded generation profiles for floor count, staff capacity, contained-lab count, archive-bay count, and service-spine side;
- typed rooms, jobs, personnel/material/evidence/egress circulation, utility dependencies, and mission steps;
- a complete loading → screening → accession → quarantine → processing → storage custody chain;
- ownership, mission-cycle, critical-utility, security-transition, and occupied-room egress validation;
- owned degraded-day procedures covering power, cooling, communications, security, custody, and staffing;
- negative proof that restoring generic connectivity cannot hide a missing quarantine checkpoint.

This is an abstract operational proof only. It does not yet alter the shipped parkour-gym geometry.

### Implemented tracer bullet — abstract floor-plan solver

The second implementation slice now exists at:

- `res://scripts/facility/facility_layout_solver.gd`
- `res://scripts/dev/facility_layout_selftest.gd`
- `res://scenes/dev_facility_layout_selftest.tscn`

It currently:

- consumes the validated `FacilityOperationGraph` rather than inventing a parallel room list;
- deterministically selects two or three floors and mirrors the service spine from the generation profile;
- places every operational room exactly once on an abstract grid;
- keeps screened entry adjacent to staff control;
- keeps every records-custody checkpoint spatially adjacent and ordered;
- separates received material from plant/communications service space;
- places cyber operations, contained research, and compute on the most restricted generated floor;
- rejects overlapping or out-of-range rooms;
- rejects a Tier-3 room placed directly against the exterior perimeter;
- emits an explicit secure, policy-controlled, egress-capable stair link for every adjacent floor pair;
- rejects multifloor plans whose vertical circulation has been removed.

This remains an abstract plan, not rendered geometry.

### Implemented tracer bullet — typed route and door routing

The third implementation slice now exists at:

- `res://scripts/facility/facility_route_router.gd`
- `res://scripts/dev/facility_route_selftest.gd`
- `res://scenes/dev_facility_route_selftest.tscn`

It currently:

- converts every operational circulation edge into a typed personnel, material, evidence, or emergency route;
- converts every power, cooling, communications, and maintenance dependency into a separately typed service route;
- assigns credentialed interlocks, custody-transfer interlocks, evidence-transfer interlocks, authorized-service boundaries, or alarmed emergency-egress doors by consequence;
- preserves one-way material, evidence, service, and emergency movement;
- keeps infrastructure routes unavailable to ordinary personnel traversal;
- keeps emergency routes unavailable to ordinary traversal while proving every occupied room can reach the emergency exit in emergency mode;
- emits contiguous grid-cell waypoints using deterministic breadth-first routing around occupied room cells;
- traverses floors only through the floor plan's validated secure stair shaft;
- treats same-room service dependencies as localized maintenance rather than inventing fake corridors;
- validates route coverage, endpoint ownership, door policy, horizontal continuity, vertical-shaft use, and rejects any route manifest that crosses an unrelated occupied room cell.

This remains abstract routing, not rendered geometry.

### Implemented tracer bullet — provenance-preserving geometry compiler

The fourth implementation slice now exists at:

- `res://scripts/facility/facility_geometry_compiler.gd`
- `res://scripts/dev/facility_geometry_selftest.gd`
- `res://scenes/dev_facility_geometry_selftest.tscn`

It currently:

- fails closed unless the operational graph, floor plan, and typed route manifest all pass their canonical validators;
- emits a generated `Node3D` hierarchy grouped into rooms, circulation, doors, service conduits, and vertical links;
- emits one collidable floor slab for every authoritative operational room and retains room id, zone, tier, owners, and critical dependencies as node metadata;
- merges shared traversable corridor cells while preserving all contributing route ids and flow types;
- emits service conduits as visible, typed, non-colliding geometry so infrastructure cannot silently become walkable circulation;
- emits door markers carrying their authoritative door mode, endpoints, flow, ordinary-access state, and emergency-only state;
- emits vertical-shaft markers carrying policy-transition and egress capability provenance;
- stores the generation seed, profile, and operational fingerprint at the generated facility root;
- rejects a corrupted route manifest with all emergency routes removed instead of rendering it.

This is the first real Godot geometry boundary, but it is intentionally skeletal: floors, route surfaces, conduits, door markers, and shaft markers—not finished room shells.

### Implemented tracer bullet — enclosure, policy doors, and launch scene

The fifth implementation slice now exists across:

- `res://scripts/facility/facility_policy_door.gd`
- the enclosure and door compilation paths in `facility_geometry_compiler.gd`
- `res://scripts/dev/generated_facility_main.gd`
- `res://scenes/dev_generated_facility.tscn`
- `res://scripts/dev/generated_facility_scene_selftest.gd`
- `res://scenes/dev_generated_facility_selftest.tscn`

It currently:

- derives each room's wall openings from the first and last horizontal steps of validated circulation routes;
- emits colliding four-sided room enclosures, splitting walls around route-authorized openings instead of cutting arbitrary holes;
- compiles each policy boundary as a colliding runtime door positioned in its source-room opening;
- executes credential-tier, archival-custody-role, evidence-transfer-role, authorized-service-role, and emergency-mode decisions at runtime;
- connects generated doors to the existing player `interact()` seam and reports granted or denied access through the existing objective prompt;
- launches a dedicated generated Cyber/Archives scene without replacing the project's current main scene;
- positions the real player from the generated `screened_entry` room's provenance-backed transform rather than a copied world coordinate;
- grants explicit inspection credentials only in the development scene and records the generated spawn as the player's checkpoint;
- proves launch with seed `7319`, a three-floor profile, and successful player placement at screened entry.

Architectural traversal is not complete: ceilings, door animation, room furnishing, job stations, and failure-state geometry remain.

### Implemented tracer bullet — traversable vertical core and corridor enclosure

The sixth implementation slice adds:

- distinct stair-shaft cells for adjacent floor pairs, preventing stacked flights from consuming the same intermediate landing;
- full-width contiguous corridor floor cells instead of disconnected pads;
- explicit circulation apertures at both floors of every vertical link;
- deterministic colliding stair flights sized to the player motor's supported step rise;
- separate colliding steps and non-colliding visual handrails with retained link provenance;
- corridor perimeter walls compiled only on boundaries not opened by an authoritative circulation route;
- closed walls between spatially adjacent cells whose route graphs do not authorize cross-flow, preventing accidental shortcuts caused by geometry adjacency;
- `facility_vertical_traversal_selftest.gd` and `dev_facility_vertical_traversal_selftest.tscn`, which drive the real player motor up generated stairs under physics.

Proof for seed `7319` reaches `y=4.64` against a first-floor target of `4.5`, after the generated scene's canonical graph, layout, routes, apertures, steps, and collisions are all compiled. Structural tests also prove clear shaft apertures, colliding stair steps, distinct adjacent shafts, and colliding corridor boundary walls.

### Implemented tracer bullet — operational inhabitation and normal mission handoff

The seventh implementation slice adds:

- authoritative equipment records owned by one job and located at one station room;
- explicit equipment functions and power, cooling, communications, or maintenance requirements;
- utility dependency validation for every equipment item;
- mission-step inputs, outputs, and required equipment in the operational graph;
- ordered artifact provenance from mission request through authorization, staged inputs, contained research, technical review, archival accession, preservation, and baseline restoration;
- `FacilityOperationRuntime`, which executes the authoritative mission steps without fabricating outputs for failed work;
- exact failure at the owning `conduct_research` step when `contained_analysis_bench` is removed;
- colliding visible equipment geometry compiled once per authoritative item, carrying equipment id, room, owner job, function, utility requirements, and participating mission steps;
- additional archive power and communications dependencies required by accession, records processing, catalog access, and controlled storage work.

The normal proof leaves both a `preserved_record` and `restored_baseline`, and its trace length matches the authoritative mission-step count. Equipment geometry count and ownership match the graph exactly.

### Implemented tracer bullet — degraded service and idempotent recovery

The eighth implementation slice adds:

- resumable mission state with a canonical next-step cursor, committed artifact map, execution trace, service snapshot, and procedure log;
- atomic step commits: a blocked or failed attempt cannot emit outputs or advance the mission cursor;
- mutable power, cooling, communications, and maintenance availability;
- automatic selection of the authoritative failure procedure and its owning job when a required service is unavailable;
- exact suspension of contained research under `cooling_failure` when the analysis bench loses cooling;
- recovery from the same cursor after service restoration, with every authoritative mission step committed exactly once;
- proof that pre-failure artifacts remain byte-for-byte unchanged across the blocked attempt and final preservation/restoration artifacts survive recovery;
- runtime equipment presentation that computes operational state from its own utility requirements;
- a visible degraded material state with unavailable-service provenance, plus deterministic restoration to the operational material;
- generated-scene controls that apply one service snapshot to both mission execution and every compiled equipment station.

The degraded proof commits the first three mission steps, loses cooling, blocks at `conduct_research` under the facilities engineer's `cooling_failure` procedure, restores cooling, and completes without duplicate trace entries or lost artifacts. The dedicated generated scene independently proves that cooling loss degrades the contained analysis bench while leaving unrelated authorization equipment operational, then restores it.

### Implemented tracer bullet — runtime material custody and incident hold

The ninth implementation slice adds:

- `FacilityCustodyRuntime`, which owns one immutable custody identity, current room, screening/accession/quarantine/processing/storage state, incident hold, and append-only transfer history;
- transfer admission against a real directed `material` edge rather than generic graph reachability;
- destination ownership checks, so the job receiving material must authorize the transition;
- phase guards that prevent accession before screening, processing before quarantine clearance, and storage before records processing;
- rejection semantics under which bypass attempts and role misuse do not mutate authoritative history;
- quarantine disposition owned by the accession technician and blocked while a custody incident remains active;
- `archive_fire_water` incident declaration, hold, and resolution by the authoritative records-officer procedure owner;
- proof that incident handling preserves both custody identity and prior history through quarantine clearance and final storage;
- destination-owner roles compiled into material and evidence interlocks, aligning physical doors with custody admission instead of accepting generic archive roles;
- a live generated-scene custody marker whose room and provenance update only after an accepted transfer.

The normal proof rejects direct loading-to-storage movement, rejects an archive custodian at the loading-to-screening boundary, and admits the complete one-way chain under the correct destination owners. The incident proof establishes a hold in quarantine, rejects unauthorized resolution and premature disposition, then archives under the original custody identity after records-officer recovery. The live scene independently proves a rejected bypass leaves the material marker at loading and an accepted security-officer transfer moves it to material screening.

### Implemented tracer bullet — personnel screening, interlocks, and emergency egress

The tenth implementation slice adds:

- an authoritative `access_roles` policy per room, separate from operational ownership;
- explicit transit access for cyber, archive, infrastructure, plant, and common entry spaces;
- validation that every granted access role names a real facility job;
- `FacilityPersonnelSecurityRuntime` with immutable credential tier/roles, current authoritative room, screening state, interlock occupancy, consumed receipts, audit history, and denial history;
- security-officer entry screening that cannot be completed by unrelated roles;
- single-occupant interlock reservations shared across both directions of a boundary;
- one-use transition receipts bound to person, origin, destination, flow, and occupied boundary;
- replay rejection and location checks before completion;
- ordinary admission requiring both destination clearance tier and an authorized destination role, with explicit security-officer override;
- emergency egress accepted only on a directed `egress` edge under declared emergency mode;
- screening state cleared on egress and no reverse emergency ingress path;
- denial auditing that leaves clearance, roles, screening, location, and interlock authority unchanged;
- credentialed physical doors compiled with the same destination `access_roles`, closing the prior tier-only gap;
- generated-scene personnel transitions that move the player only after an accepted and consumed security receipt.

The runtime proof rejects unscreened entry, non-security screening, concurrent interlock occupancy, receipt replay, clearance-only role bypass, ordinary use of emergency egress, and reverse ingress. The live scene independently proves that an ordinary emergency-exit request leaves the player in place, while a declared emergency receipt moves the player to the generated emergency exit and clears screened-inside state.

### Implemented tracer bullet — seeded staffing, relief, and local shortage degradation

The eleventh implementation slice adds:

- a minimum on-shift coverage contract to each authoritative job;
- `FacilityStaffingRuntime`, which expands seeded `staff_capacity` into deterministic named staff records;
- day, swing, and night assignments plus job-specific relief pools;
- guaranteed minimum coverage and relief for every continuous post;
- deterministic distribution of remaining seeded headcount without changing job ownership;
- active-shift coverage, unavailability, relief activation, uncovered-job reporting, and append-only shortage logs;
- invocation of the authoritative `staffing_shortage` procedure with its duty-officer owner and preserved functions;
- responsibility-specific availability queries for mission steps, entry screening, and custody destinations;
- mission-runtime job availability, resumable staffing blocks, and `staffing_shortage` procedure provenance;
- live synchronization from staffing coverage into the existing mission state;
- generated on-duty staff markers carrying named staff id, job, shift, and relief status at each job station;
- live shortage controls that remove one job's staff, rebuild visible coverage, and leave unrelated posts operating.

For seed `7319`, the schedule instantiates the full generated staff capacity and reproduces exactly on replay. Every continuous job has minimum coverage on all three shifts and at least one relief assignment. Removing the active security primary watch consumes relief and preserves screening. Exhausting all cyber researchers leaves analyst review, relieved security screening, and records custody available, while the real mission runtime advances through staging and blocks exactly at `conduct_research` under `staffing_shortage`. The generated scene reproduces the same local block and removes only the affected on-duty markers.

### Implemented tracer bullet — gapless turnover and combined-failure arbitration

The twelfth implementation slice adds:

- explicit shift-turnover receipts with scheduled day→swing→night sequencing;
- pre-commit handoff records for every continuous job, naming outgoing staff and verified incoming staff;
- relief planning during turnover when incoming primaries alone cannot meet minimum coverage;
- fail-closed rejection when neither incoming primaries nor relief can cover a continuous post;
- one-use turnover completion, receipt replay rejection, turnover history, incoming-shift activation, and prior relief release;
- proof that mission artifacts/cursor, custody identity/history/location, and personnel credentials/audit/location remain unchanged through turnover;
- generated-scene turnover controls that rebuild named on-duty markers for the incoming shift;
- ordered multi-blocker mission preflight rather than first-error masking;
- explicit blocker priority: power, cooling, communications, maintenance, then staffing;
- an authoritative active-blocker set carrying blocker kind, identity, and governing procedure;
- independent blocker removal, so restoring one condition leaves all other procedures and safety holds active;
- atomic recovery from the original mission cursor only after every blocker is cleared;
- live combined cooling-plus-staffing degradation and partial-recovery proof.

The turnover proof leaves the active shift unchanged until a verified receipt is consumed, covers every continuous swing post, rejects replay, and rejects turnover after all incoming security primaries and relief are unavailable. The combined-failure proof blocks `conduct_research` on both cooling and cyber-research staffing, gives cooling the first safety priority, preserves committed artifacts, then transitions to `staffing_shortage` when cooling returns. Only restoring research coverage releases the mission. The generated scene reproduces both incoming-watch geometry and the partial-recovery hold.

### Implemented tracer bullet — control-room observability and occurrence-scoped acknowledgement

The thirteenth implementation slice adds:

- `FacilityControlRoomRuntime`, a downstream projection over authoritative mission, utility, custody, personnel, and staffing state;
- one ordered alarm view combining unavailable services, uncovered jobs, active mission blockers, custody incidents, mission cursor, active shift, personnel location, and custody location;
- procedure identity and owning job on every recoverable condition;
- stable condition occurrences while a condition remains active, with a new occurrence identity after clear-and-recur;
- append-only operator acknowledgements and denied-attempt records;
- acknowledgement authority limited to the duty officer or the governing procedure owner;
- source-state immutability proof across acknowledgement: mission, custody, personnel, and staffing dictionaries remain unchanged;
- alarm semantics in which acknowledgement records awareness but never clears, downgrades, or resolves the condition;
- generated-scene refresh after mission, service, custody, personnel, shortage, and turnover mutations;
- an in-world duty-station `Label3D` showing mission status/cursor, shift, custody location, open or acknowledged conditions, procedures, and owners;
- a rendered OpenGL compatibility shot harness for deterministic board inspection.

The cross-domain proof simultaneously presents cooling loss, uncovered cyber-research staffing, a blocked `conduct_research` mission cursor, and an archive custody incident. A cyber researcher cannot acknowledge cooling; the facilities engineer can. The accepted acknowledgement leaves all four source states byte-for-byte unchanged, leaves the cooling occurrence active, and leaves board severity at `alarm`. Clearing cooling removes that occurrence; a later cooling loss receives a new occurrence and does not inherit stale acknowledgement.

The live generated proof acknowledges cooling while staffing remains open, then restores cooling and confirms `staffing_shortage` still blocks the mission. The rendered 1280×720 compatibility-backend artifact places the board at normalized screen position `(0.5, 0.403)` with two conditions and alarm severity. Inspection confirms the alarm header, mission cursor, shift, custody location, both conditions, procedures, and owners are readable; the weapon does not obscure the text, though its laser crosses part of the lower condition area. This proves functional legibility, not final control-console art direction.

### Implemented tracer bullet — staffed procedure execution and verified infrastructure restoration

The fourteenth implementation slice adds:

- `FacilityInfrastructureRuntime` as the canonical owner of generated utility-service availability, active failures, recovery reservations, remediation evidence, verification, and history;
- explicit failure occurrences linked to the graph-authoritative procedure, owner job, and station;
- one-use recovery receipts that can only be reserved by a named on-duty member of the procedure-owner job while present at the procedure station;
- fail-closed rejection for wrong role, wrong station, uncovered owner job, unnamed/off-watch actors, mismatched procedure, inactive failure, and duplicate reservation;
- remediation evidence bound to the same actor, service, station, and receipt, without directly restoring service;
- independent restoration verification by a different named on-duty duty officer at the command station;
- rejection of premature verification, repair-actor self-verification, absent/off-watch verification, and consumed receipt replay;
- explicit infrastructure-to-mission snapshot coupling, so even verified restoration cannot silently mutate mission state until the new service snapshot is applied;
- refusal of direct generated-scene `available=true` mutation: restoration must execute the procedure path;
- live recovery orchestration using named active-shift staff markers and graph-derived stations;
- explicit on-call mobilization and audit history for non-continuous business-cycle jobs outside their ordinary shift.

The cooling proof declares an infrastructure failure, applies its unavailable snapshot, and blocks `conduct_research`. Acknowledging the cooling alarm leaves infrastructure unavailable and the mission blocked. A facilities engineer at the wrong station cannot reserve recovery; exhausting the facilities watch also denies recovery. A named on-duty engineer at the plant receives a receipt, but duty verification before repair changes nothing. Repair evidence still leaves cooling unavailable. The repair actor cannot self-verify. A different named on-duty duty officer at `cyber_ops` verifies restoration, after which infrastructure becomes available; the mission remains blocked until the explicit service snapshot is applied, then resumes from the same cursor and completes. Receipt replay fails.

The generated scene executes the same chain after day-to-swing turnover and proves the repair actor is the named swing facilities engineer visible in staffing presentation. Restoring cooling removes only the cooling condition; the independent cyber-research staffing blocker remains active. A separate swing-shift proof mobilizes named records-officer relief for business-cycle work and records the on-call action.

### Implemented tracer bullet — staged continuity and room-specific utility consequence

The fifteenth implementation slice replaces binary utility recovery with graph-authoritative continuity profiles:

- cooling enters `safe_hold`, preserves only `compute_core` and `archive_stack`, then requires `enter_controlled_shutdown → isolate_for_repair → repair → functional test → reconstitution verification → normal`;
- power enters `ride_through`, preserves security control, compute core, and archive stack, then declares load shedding and repair-isolation transitions;
- communications enters `local_only`, preserves cyber operations and security control, then declares external-link isolation and repair-isolation transitions;
- graph validation rejects a critical service with no profile, a missing preserved room, a missing response actor or station, a discontinuous transition chain, or a chain that never reaches `repair_pending`;
- infrastructure state records the current service phase and append-only phase transitions with named actor provenance;
- repair cannot begin before the declared response reaches `repair_pending`;
- repair advances to `testing`, not restoration; matched functional-test evidence advances to `reconstitution_pending`; only a distinct on-duty command verifier can return the service to `normal`;
- mission snapshots now carry service availability per consuming room rather than treating every consumer identically;
- equipment receives its station room's service snapshot, so the contained analysis bench degrades during cooling safe hold while the explicitly preserved compute-core baseline console remains operational;
- control-room service conditions expose the canonical infrastructure phase, including `safe_hold`, rather than flattening every condition to generic unavailability.

The focused cooling proof rejects repair directly from safe hold, commands controlled shutdown from the duty station, isolates the plant under facilities ownership, records repair without restoration, rejects verification before a functional test, records the matched plant test, rejects self-verification, and accepts independent command verification. The live generated proof confirms both room-specific equipment consequences and `safe_hold` phase visibility before executing the complete recovery chain.

### Implemented tracer bullet — physical local procedure controls

The sixteenth implementation slice compiles each graph-authoritative infrastructure response into physical station controls:

- `FacilityProcedurePanel` is a colliding `StaticBody3D` with an interaction surface, phase/action label, enabled-state material, service/action/station/job/phase provenance, and a downstream `last_result`;
- the generated scene creates command, isolation, repair reservation, repair evidence, functional test, and independent reconstitution panels from each power, cooling, and communications continuity profile plus its governing failure procedure;
- panel placement is derived from the authoritative station room rather than copied world coordinates;
- interaction consumes the existing player `interact()` seam and rejects identities outside the generated personnel-security state;
- a panel requires the player's authoritative personnel room—not merely their transform—to match its station and requires the panel's actor role;
- accepted actions still execute under a named active-watch staff identity, preserving staffing authority separately from the interacting inspection identity;
- each accepted action advances at most one phase and appends panel ID, service, action, station, initiator, named staff actor, and resulting phase;
- remote activation, wrong-role activation, wrong-phase replay, repair without a receipt, testing without repair, and verification away from command fail without advancing infrastructure state;
- panel availability is a downstream projection: safe hold enables only its command action, command acceptance disables that panel and enables plant isolation, and receipt reservation transfers availability from `begin_repair` to `record_repair`;
- the synchronous recovery harness now iterates the same generated panel definitions and `_execute_procedure_panel` command path rather than maintaining a second recovery implementation.

The focused live proof enters through screening, traverses `screened_entry → staff_control → cyber_ops`, performs exactly one command action, returns through `staff_control` to `plant`, executes isolation/receipt/repair/test locally, then returns to `cyber_ops` for independent reconstitution. Remote command and verification attempts and same-panel replay are rejected. Six accepted controls produce exactly six provenance records, and cooling returns to `normal` only after the command-station verification.

A rendered plant-state proof shows the generated panel bank at `repair_pending`: `BEGIN REPAIR` is visibly green and available while `RECORD REPAIR` and `FUNCTIONAL TEST` remain unavailable. The first-person laser crosses the lower bank but does not obscure the active label; staff markers remain visible below the controls.

### Implemented tracer bullet — authoritative named-watch location and dispatch

The seventeenth implementation slice removes the constructed staff-presence seam:

- `FacilityStaffAgentRuntime` creates deterministic room-level agents for every named active primary and relief assignment, initially located at the job's authoritative post;
- every agent owns one current room, destination, remaining room route, status, and append-only movement history;
- dispatch uses only graph `personnel` edges and admits each traversed destination through that room's `access_roles` for the agent's actual job;
- dispatch to a missing or role-forbidden room, a destination with no valid personnel route, an unknown/off-watch identity, or an already-dispatched agent fails without mutating location or task;
- dispatch records intent but does not fabricate arrival; each deterministic tick advances one room edge and records movement and final arrival separately;
- procedure-panel actor lookup now consumes authoritative agent location and active staffing identity instead of constructing `{current_room: station}`;
- moving the complete facilities watch away from `plant` disables plant-panel presentation and causes interaction to fail while cooling remains in `controlled_shutdown`;
- dispatching one named engineer back still leaves the panel unusable before the route tick; only the recorded arrival enables plant isolation;
- live staffing markers now compile from each agent's current room and expose staff ID, job, shift, relief status, agent status, and authoritative room;
- shift turnover and staffing-shortage changes rebuild the active agent set from the newly authoritative watch assignment, preventing stale off-watch actors from retaining panel authority.

The focused route proof moves a facilities engineer from `plant` to `staff_control`, separately records dispatch and arrival, rejects an unauthorized `archive_stack` dispatch without mutation, and requires a second dispatch/tick before plant presence returns. The live panel proof removes every facilities engineer from the plant, confirms the isolation panel becomes unavailable and cannot advance state, then returns one named engineer through the personnel graph and confirms both the marker and panel react only after arrival.

This is room-level operational motion, not finished navigation animation: markers update at route-edge ticks rather than walking continuously through corridor geometry.

### Implemented tracer bullet — durable autonomous procedure work

The eighteenth implementation slice inserts a durable scheduler between panel request and infrastructure mutation:

- `FacilityProcedureWorkRuntime` owns active tasks, one task per panel, named actor binding, initiator, destination station, original and remaining duration, status, interruptions, completion receipts, and append-only work history;
- a panel request selects a named active-watch actor already at station or dispatches a policy-valid actor through `FacilityStaffAgentRuntime`; dispatch acceptance does not create arrival or procedure progress;
- arrival starts work but consumes no duration on the arrival tick;
- command, reservation, and verification take one work tick; isolation and functional testing take two; repair evidence takes three;
- every work tick consumes exactly one unit while the bound actor remains at the station;
- duplicate work for the same panel is rejected while dispatch, work, interruption, or unconsumed completion remains active;
- interruption records its reason and frozen remaining duration, releases the actor from active work, and cannot emit a completion or mutate infrastructure;
- resumption requires the same bound actor still at the authoritative station and continues from the preserved duration rather than restarting or skipping work;
- completion emits a one-use receipt carrying task, panel, service, action, station, actor, initiator, and duration provenance;
- the generated controller consumes that receipt before executing the existing phase command, then consumes the scheduler receipt only after the infrastructure command succeeds;
- a failed infrastructure commit leaves the completion receipt unconsumed and the panel task blocked for reconciliation rather than silently dropping work;
- the bounded synchronous recovery harness now requests and ticks the same durable work tasks; it is no longer an immediate phase loop;
- physical panels project `DISPATCHED`, `WORKING`, or `INTERRUPTED` state and remaining ticks from scheduler truth.

The pure proof dispatches a facilities engineer from `staff_control`, separates arrival from work progress, consumes one of three repair ticks, interrupts at two ticks remaining, proves arbitrary scheduler ticks cannot advance interrupted work, resumes under the same actor, emits exactly one completion, and rejects receipt replay. The live cooling proof automatically dispatches the absent facilities watch, keeps `controlled_shutdown` unchanged through dispatch and arrival, commits isolation only after its duration, then interrupts and resumes repair without leaving `repair_pending`. Independent verification likewise queues work and leaves cooling in `reconstitution_pending` until its completion receipt commits.

The rendered plant proof captures `RECORD REPAIR [repair_pending] WORKING 2t` on the physical panel. The weapon laser crosses the panel face and its red dot touches the title area, but `WORKING 2t` remains readable.

### Implemented tracer bullet — receipt-bound work continuity across shifts

The nineteenth implementation slice makes staffing turnover and active procedure work one atomic operational boundary:

- staffing turnover still preflights every continuous post and issues its existing gapless watch receipt;
- `FacilityProcedureWorkRuntime.begin_shift_handoffs()` inspects every dispatched, working, or interrupted task before staffing commits;
- each task must belong to a job represented in the staffing receipt, and its named actor must appear in that job's outgoing watch;
- each active task reserves one distinct qualified incoming identity, preventing one relief actor from inheriting simultaneous incompatible work;
- business-cycle work with no incoming continuous-watch handoff fails closed rather than silently surviving under an off-watch identity;
- a failed work-handoff preflight cancels the pending staffing turnover through an append-only cancellation record and leaves the active shift unchanged;
- accepted tasks enter `handoff_pending`, which freezes remaining duration through arbitrary scheduler ticks;
- each work receipt binds turnover ID, shifts, task, panel, job, station, outgoing identity, incoming identity, prior status, and exact remaining ticks;
- after staffing commits, the generated controller rebuilds the incoming active watch and consumes each handoff receipt against that authoritative agent set;
- incoming relief must exist on the new watch with the exact job; it resumes immediately only if station-local, otherwise it receives a policy-valid dispatch;
- completed ticks are neither replayed nor discarded, and task provenance retains the consumed handoff receipt;
- forged identity changes, stale task duration, unknown receipts, and replayed receipts fail without changing task authority;
- the generated recovery harness now resumes from the current infrastructure phase, so a shift handoff after command work does not replay earlier continuity transitions.

The pure proof records one of three repair ticks under the day facilities engineer, freezes two ticks at turnover, rejects a forged receipt, commits `day → swing`, transfers authority to a distinct qualified engineer, preserves exactly two ticks, rejects receipt replay, and completes once. A separate negative proof starts business-cycle cyber work, rejects a nonexistent swing handoff, cancels the staffing transaction, and keeps the day watch authoritative.

The live generated-scene proof fails cooling, queues command work under the day duty officer, turns over to swing before its only work tick, proves the task actor changes while one tick remains, then lets the incoming duty officer commit `safe_hold → controlled_shutdown` exactly once. The remaining staged recovery continues from controlled shutdown rather than restarting.

Physical panels now append `H<n>` to active work after handoff. The rendered plant proof shows `RECORD REPAIR [repair_pending] WORKING 2t H1`; the laser crosses the title/phase area, but the status, remaining duration, and handoff count remain readable.

### Implemented tracer bullet — fail-closed procedure-work restart recovery

The twentieth implementation slice gives the procedure scheduler a validated persistence boundary and proves it across a real process restart:

- snapshots carry the explicit schema `facility-procedure-work/v1` and a deep copy of tasks, active-panel index, completion receipts, pending handoffs, work log, and monotonic counters;
- export reruns the same structural validator used by recovery rather than serializing arbitrary runtime memory;
- every task must retain identity, panel, service, action, station, job, named actor, initiator, valid status, positive original duration, bounded remaining duration, interruption history, and handoff history;
- the active-panel index must exactly match every noncommitted task, and duplicate active work for one panel invalidates the snapshot;
- a completed task must have zero remaining ticks and exactly one matching unconsumed completion receipt;
- every completion receipt must resolve to the exact completed task and panel;
- every handoff-pending task must have exactly one matching handoff receipt with the same remaining duration;
- missing maps/logs, invalid counters, unknown statuses, incomplete provenance, impossible duration, index contradictions, orphan receipts, and stale handoff receipts reject the entire snapshot without changing live state;
- JSON numeric counters and durations are normalized back to integers only after validation;
- `working`, `dispatched`, and `handoff_pending` are ephemeral claims and never survive restart as active authority;
- those tasks recover as `interrupted` with `restart_reconciliation_required`, prior status, and exact remaining ticks recorded append-only;
- pending staffing-handoff receipts are discarded because the corresponding in-memory staffing transaction cannot be presumed committed after restart;
- already interrupted tasks remain interrupted, committed tasks remain committed, and completed tasks retain their one-use receipt;
- the generated-scene recovery adapter rebuilds named agents from the authoritative active staffing watch, projects interrupted state onto physical panels, and requires explicit station-local resume before ticks can continue.

The cross-process proof writes a JSON snapshot to `user://`, launches a second Godot process on the same self-test scene, reconstructs the deterministic graph/staffing/agent context, and reads the file in the child. One three-tick repair recovers interrupted with exactly two ticks remaining. A separate task completed before shutdown retains its unconsumed receipt; the child consumes it once and rejects replay. Arbitrary ticks cannot advance the interrupted repair, explicit reconciliation resumes it, and exactly two ticks produce one completion.

Mutation proof changes the repair's remaining duration to `99` and confirms recovery rejects it. The live generated-scene proof corrupts the active-panel index and confirms authoritative state remains structurally identical, then restores the valid snapshot, confirms the physical command panel projects `INTERRUPTED 1t`, proves cooling remains in `safe_hold` through an unreconciled tick, and commits `controlled_shutdown` only after explicit resume.

This is a scheduler persistence boundary, not yet a coordinated whole-facility journal: graph generation, staffing, infrastructure, custody, personnel security, and agent watch are reconstructed by their existing deterministic owners rather than committed in one crash-consistent envelope.

### Implemented tracer bullet — secondary-condition work suspension

The twenty-first implementation slice makes station authority and supporting utilities continuous work preconditions rather than one-time admission checks:

- every generated procedure definition derives `required_services` from its station room's graph-authoritative `critical_requirements`;
- the service being recovered is excluded from its own work requirement so a failed utility does not trivially forbid its recovery;
- command-station cooling work therefore requires room-specific power and communications, while plant repair work requires maintenance support;
- request admission checks current station access and room-specific support before dispatching or starting an actor;
- every live scheduler tick re-evaluates those same conditions before agent movement or duration progress;
- station authorization requires the task's actual job to remain in the room's `access_roles`—ownership, clearance, or prior admission cannot substitute;
- service checks consume `FacilityInfrastructureRuntime.room_has_service()`, preserving staged room-specific ride-through rather than flattening a global service boolean;
- loss of station authority interrupts with `station_access_revoked`;
- loss of a named support service interrupts with `required_service_unavailable:<service>`;
- suspension preserves exact remaining duration, appends reason provenance, releases working authority, and prevents completion emission or infrastructure mutation;
- a task suspended while its actor is still dispatched cancels the remaining route and leaves the actor at the last authoritative room instead of allowing stale movement to continue;
- resume re-runs current station and service conditions before restoring work authority;
- inactive panel availability consumes the same condition check, and active physical panels project full reason metadata plus a compact visible label such as `POWER`.

The pure proof revokes facilities access to `plant`, freezes a four-tick repair before any progress, restores access, consumes exactly one tick, removes maintenance support, freezes three remaining ticks, blocks unavailable-support resume, restores support, and completes exactly once after three ticks. A second dispatch proof moves the facilities watch to `staff_control`, requests plant work, removes maintenance before arrival, and confirms both the task and route are cancelled without fabricated arrival.

The live generated-scene proof starts cooling command work in `safe_hold`, then declares an independent power failure. Because `cyber_ops` is not among power ride-through's preserved rooms, the next work tick suspends with one tick remaining, cooling stays in `safe_hold`, power stays in `ride_through`, no work receipt commits, and explicit resume is rejected while power remains unavailable.

A dedicated OpenGL compatibility render isolates the affected command panel and shows `ENTER CONTROLLED SHUTDOWN [safe_hold] INTERRUPTED 1t POWER`. The weapon laser intersects the phase/status area but all text remains readable; unrelated panels and the separate control board are hidden only in this inspection harness to avoid occlusion.

This exposed a real next boundary rather than hiding it: simultaneous utility failures could correctly suspend each other's station work, but the initial response had no alternate degraded controls.

### Implemented tracer bullet — hardened alternate controls and cascade ordering

The twenty-second implementation slice gives each critical utility's initial degraded response one graph-authoritative fallback at continuously staffed `security_control`:

- cooling shutdown, power load shedding, and communications isolation retain their primary duty-officer controls at `cyber_ops`;
- each initial transition now also declares a security-officer-owned `hardwired_emergency_control` at `security_control`;
- the graph contains named `hardwired_emergency_service_control` equipment, its room, owner, purpose, and power/communications requirements;
- alternate authority is transition-local: being a security officer does not grant arbitrary infrastructure transitions, and primary authority does not silently migrate to another room;
- graph validation rejects an initial critical response with no alternate, a missing/same station, an unauthorized alternate actor, a missing mode, mismatched equipment ownership/location, or an alternate station that another required-service failure would not preserve;
- `security_control` is explicitly preserved during power ride-through and communications local-only operation, has no cooling dependency, and therefore survives the modeled cross-service command failures;
- infrastructure transition history and results preserve the selected actor job, station, control mode, and equipment rather than recording only the abstract action.

Generation now emits separate physical panel identities such as `cooling:enter_controlled_shutdown@security_control`; alternate panels derive their own room-specific service requirements and visibly identify themselves as `HARDWIRED`. Primary and alternate panels remain separate authority boundaries even though they advance the same transition.

Equivalent work cannot run concurrently by default. A declared fallback may start only when the equivalent primary task is already interrupted. If the fallback commits first, the scheduler terminally marks the blocked task `superseded`, records the winning task and preserved remaining duration, releases the stale panel index, removes any stale handoff, and keeps that terminal fact valid through scheduler snapshot recovery. It does not pretend the blocked work completed.

`compile_degraded_response_plan()` now orders active service failures by authoritative failure sequence, prefers an available primary control within each failure, selects a declared alternate when the primary is unavailable, and advances to the next failure only after the older response has no remaining transition before repair isolation. The plan returns the concrete panel, station, actor job, action, phase, and control mode rather than a generic service recommendation.

The live cascade proof now:

1. starts primary cooling shutdown work in `safe_hold`;
2. declares power failure and observes the primary task suspend with one tick remaining;
3. confirms resume is denied and the planner recommends cooling's hardwired security-control panel;
4. commits that one-tick alternate command through the named on-duty security officer;
5. confirms cooling reaches `controlled_shutdown` and the blocked primary becomes restart-durable `superseded` work;
6. follows the planner to plant cooling isolation and reaches `repair_pending`;
7. confirms the planner then selects power's hardwired load-shed panel;
8. commits power load shedding at `security_control` and plant isolation;
9. leaves both failures in honest `repair_pending` state without fabricated restoration.

A dedicated OpenGL compatibility render isolates the security-control panel and shows `ENTER CONTROLLED SHUTDOWN · HARDWIRED [safe_hold] WORKING 1t`. The weapon laser crosses the text area but the label remains legible; unrelated panels and the control board are hidden only in the visual inspection harness.

This removed the initial command deadlock but left a later cascade edge: full reconstitution still required duty-officer verification at unsupported `cyber_ops`.

### Implemented tracer bullet — degraded independent reconstitution authority

The twenty-third implementation slice closes that edge without allowing the repair owner to approve their own work. This is an explicit design inference for the fictional institution—not a claim that a public standard mandates security officers as utility verifiers. The modeled security officer authorizes reconstitution from hardened controls after evidence review; they do not diagnose, repair, or perform the technical functional test.

Each critical service profile now declares a `verification_controls` policy containing:

- continuously staffed `security_officer` authority at `security_control`;
- `hardwired_reconstitution_authority` mode;
- the graph-owned `hardwired_emergency_service_control` equipment;
- mandatory `passed_functional_test` evidence;
- explicit `not_repair_actor` separation.

Graph validation rejects a critical service with no degraded verifier, a missing station, a non-continuous or unauthorized verifier job, verifier/repair-role collapse, missing passed-test policy, the wrong authority mode, mismatched equipment ownership/location, or a verification station that another required-service failure would not preserve.

`verify_and_restore()` now resolves one of two declared authority paths:

- primary duty-officer reconstitution at the mission command console in `cyber_ops`;
- degraded security-officer authorization at the hardwired control in `security_control`.

Both paths still require a live recovery receipt, recorded owner remediation, passed owner functional-test evidence, a verifier distinct from the repair actor, exact station presence, and named on-duty staffing. A valid degraded verifier cannot bypass an absent test, cannot substitute for the receipt owner, and cannot restore from an undeclared room. Restoration history and results record verifier job, station, control mode, and equipment.

Generation emits separate panels such as `cooling:verify_reconstitution@security_control`, with room-specific support checks and a visible `HARDWIRED` identity. The existing one-use timed-work boundary still applies before the authority call.

The response planner now owns the whole active-failure sequence rather than stopping at isolation:

1. staged initial response;
2. repair isolation;
3. receipt reservation;
4. owner remediation;
5. owner functional test;
6. independent reconstitution authorization.

For concurrent failures it keeps the oldest failure until restoration when a valid path exists. In the live cooling/power proof, cooling uses hardwired initial command, plant isolation, owner repair and testing, then hardwired security-officer reconstitution because power still removes support from `cyber_ops`. Once cooling is normal, the planner returns power response and verification to the primary duty-officer console. Both services finish `normal`, both active failures and recovery receipts clear, and repair/verifier identities remain distinct.

The pure mutation proof removes cooling's verification controls and confirms graph rejection. The runtime proof advances real cooling evidence through shutdown, isolation, receipt reservation, remediation, and functional test; a relocated repair actor cannot verify, while the named security officer at the declared hardened station restores exactly once with full provenance.

A dedicated OpenGL compatibility render isolates `VERIFY RECONSTITUTION · HARDWIRED [reconstitution_pending] WORKING 1t`. The weapon laser crosses the text area but the panel remains legible; unrelated panels and the control board are hidden only in the inspection harness.

That exposed the next boundary: infrastructure, recovery receipts, staffing, agents, procedure work, mission projection, and response ordering could each be valid while still belonging to different operational moments.

### Implemented tracer bullet — epoch-coupled scene checkpoint and restart reconciliation

The twenty-fourth implementation slice adds `FacilitySceneCheckpointRuntime` and a single composite checkpoint schema:

```text
generated-facility-scene/v1
```

A checkpoint has one monotonically increasing scene epoch, facility seed, graph-generation fingerprint, and separately named owner envelopes for:

- infrastructure failures, phases, evidence, history, and active recovery receipts;
- staffing roster, assignments, relief, shortages, active shift, and pending turnover;
- named-agent physical locations and in-flight intent;
- the validated procedure-work scheduler snapshot;
- the scene's service-to-recovery-receipt index;
- mission global and room-specific utility projections;
- the compiled degraded-response queue and recommended-panel identity.

Every owner envelope repeats the same epoch. Recovery rejects the whole checkpoint before authoritative replacement if any owner is absent, malformed, or from a different epoch. Seed and graph fingerprint bind the checkpoint to one generated facility rather than merely one compatible schema.

Cross-owner validation now checks:

- authoritative services, staged phases, active failure identities, and receipt/failure links;
- mission global and room-specific service truth against infrastructure truth;
- staffing generation identity, shift sequence, job assignments, relief membership, unavailable identities, pending-turnover provenance, and continuous-post coverage;
- exact equality between active-watch agents and current on-duty staffing;
- valid agent jobs, rooms, routes, and route destinations;
- active infrastructure receipts against the scene receipt index by service, failure, procedure, actor, and station;
- every durable task against its generated panel's service, action, station, actor job, control mode, equipment, and required-support set;
- every task actor against the persisted staffing roster;
- the recovered response-plan signature against a fresh compilation from staged owner state.

Recovery is staged. Procedure work passes through its existing snapshot validator and returns interrupted with `restart_reconciliation_required`; it cannot gain progress during deserialization. Valid agent physical rooms survive, but ephemeral route and work intent do not: routes are cleared, destinations collapse to the last authoritative room, and status becomes `arrived`. Invalid routes are rejected rather than sanitized into validity.

The live scene temporarily installs fully prepared owner state only to recompile response-plan identity. A mismatch restores every prior owner and refreshes downstream panels before returning denial. A committed epoch is one-use within the process; replay is rejected. Recovered scheduler work still requires explicit current-condition reconciliation before continuation.

Infrastructure transitions now propagate the mission's global and room-specific service snapshot after every accepted stage, not only failure declaration and final restoration. This closes a stale-projection defect that the composite validator exposed: moving from preservation into shutdown could previously leave mission room support describing the prior phase.

The cross-process proof checkpoints concurrent cooling/power failure during partially completed cooling remediation:

```text
cooling = repair_pending
power = ride_through
record_repair = working, 2 ticks remaining
cooling recovery receipt = active
unrelated named agent = traveling
```

Before process exit it mutation-tests and rejects, without changing live owner state:

- one owner with a different epoch;
- a forged scene recovery-receipt identity;
- a forged response-plan recommendation;
- an invalid persisted agent route;
- task support requirements that disagree with the generated panel;
- the wrong graph-generation fingerprint.

A second Godot process reads the serialized checkpoint, reconstructs the same seed, and recovers it. The procedure task remains interrupted with exactly two ticks, both utility phases remain unchanged, the unrelated agent retains its last room while losing stale route authority, and replay of the same checkpoint fails. Explicit reconciliation then commits the remaining owner remediation and the planner drives functional testing, degraded cooling verification, power response, repair, testing, and primary verification until both services are `normal` and both receipt stores are empty.

This established semantic atomicity but not a durable commit protocol: the first cross-process proof still wrote one checkpoint file directly.

### Implemented tracer bullet — checksummed append journal and recoverable head commit

The twenty-fifth implementation slice adds `FacilitySceneJournalRuntime` with schema:

```text
facility-scene-journal/v1
```

The journal stores immutable epoch records rather than overwriting the last operational state. Each record contains:

- the scene checkpoint epoch;
- the exact serialized checkpoint JSON;
- a SHA-256 checksum over those exact bytes;
- the journal schema identity.

Storing the original checkpoint bytes is deliberate. Re-serializing parsed JSON can normalize integer values into floating-point notation and would make a correct checksum appear corrupt. Recovery verifies the stored byte string first, then parses and hands the checkpoint to the existing cross-owner validator.

Commit ordering is:

1. serialize and checksum the already validated scene checkpoint;
2. write a uniquely named epoch record to a temporary file;
3. flush and rename that complete record into the append set;
4. write, flush, and replace `head.json` with epoch, record name, and checksum.

The epoch record is never exposed as committed head before its bytes are complete. If head replacement is interrupted and the head disappears, recovery scans immutable records and selects the newest complete checksummed epoch. If an older valid head remains, higher unheaded records are ignored. Temporary files and malformed unheaded records have no authority.

The head changes the failure policy. When a valid head names an invalid, missing, or checksum-mismatched record, recovery fails closed; it does not silently select an older epoch. An explicit request for any epoch other than the committed head is also rejected. This distinguishes recoverable interrupted append work from corruption of acknowledged authority.

`GeneratedCyberArchivesFacility` now exposes:

```text
commit_scene_journal(directory)
recover_scene_journal(directory, requested_epoch = -1)
```

A journal recovery first verifies record integrity and committed-head authority, then executes the full staged scene-checkpoint recovery. The journal cannot bypass generation fingerprint, owner epoch, receipt, staffing, agent, task, mission-projection, planner, replay, or restart-reconciliation checks.

The pure journal proof commits epochs one and two, rejects an explicit rollback to epoch one, confirms a malformed unheaded epoch three cannot displace head two, removes the head and recovers epoch two by checksummed scan, then corrupts a committed epoch-three record and confirms the runtime refuses to fall back.

The live real-process proof commits two cooling/power cascade epochs:

```text
epoch 1: cooling record_repair has 2 ticks remaining
epoch 2: cooling record_repair has 1 tick remaining
head: epoch 2
unheaded epoch 3: deliberately truncated
```

A second Godot process recovers through the journal API. It selects epoch two—not epoch one and not the torn epoch three—restores cooling at `repair_pending`, power at `ride_through`, and remediation interrupted with exactly one tick. Explicit reconciliation commits that tick, and the same planner drives testing, degraded cooling reconstitution, power response, repair, testing, and primary verification until both services are `normal` and all recovery receipts clear.

This proves process-crash and torn-record handling at the application-file layer. It does not claim hardware power-loss guarantees beyond Godot's `FileAccess.flush()` and rename behavior; directory `fsync` is not exposed here.

That left a dangerous mixed-reality restart: utilities and work could recover consistently while archive custody, an occupied security interlock, or operator awareness reset to fresh-scene defaults.

### Implemented tracer bullet — custody, personnel-security, and control-awareness journal authority

The twenty-sixth implementation slice adds three owners to every `generated-facility-scene/v1` epoch:

```text
custody
personnel_security
control_room
```

The custody owner persists material identity, current room, milestone flags, active incident, and append-only custody history. Recovery does not trust the summary fields alone. It replays history from the immutable receipt at `loading`, requires every transfer to advance exactly one authoritative material edge in the declared chain, validates quarantine disposition in place, and validates custody incident declaration/resolution against graph-owned procedures. Replayed room, incident, and milestone truth must exactly match the persisted summary.

The personnel-security owner contains both person state and the runtime authority that state depends on:

- identity, roles, clearance, screening, inside/outside trust, current room, audit, and denial history;
- active interlock receipt;
- boundary occupancy;
- runtime receipt registry and next receipt counter.

An active receipt is admitted only when person, source room, destination, flow, boundary key, occupancy, and an authoritative circulation edge agree. A receipt without occupancy, occupancy without a receipt, an unknown role/room, malformed audit sequence, impossible inside/perimeter state, or emergency exit that retained screening trust rejects the whole scene checkpoint.

Unlike staff dispatch routes, an occupied personnel interlock is not discarded as ephemeral intent. It is a bounded physical-security authority and survives restart. The recovered person remains at the source room, the boundary remains occupied, and the exact receipt may complete once. Replay remains denied.

The control-room owner persists occurrence allocation, active occurrence mapping, acknowledgement and denial history, counters, and the compiled read-only projection. Recovery validates console identity and occurrence/acknowledgement structure, then recompiles the projection after all staged source owners are installed. The recompiled conditions, occurrence IDs, acknowledged state, mission, services, custody, personnel, and staffing projection must semantically match the persisted snapshot. Numeric JSON normalization is handled explicitly without weakening structural equality.

Live scene recovery now stages and rolls back custody, personnel, interlock runtime, control console, and control projection alongside infrastructure, staffing, agents, work, receipts, and mission state. On commit it resynchronizes the custody marker and authoritative player room before refreshing panels and the control board.

The real journal restart proof establishes this coupled state:

```text
material = quarantine
custody incident = archive_fire_water
control occurrence = active and acknowledged by records_officer
player = screened_entry
personnel transition = screened_entry -> staff_control reserved
interlock boundary = occupied
```

Before journal commit, mutation proofs reject without changing live authority:

- a custody room that contradicts custody history;
- an active personnel receipt whose interlock occupancy was removed;
- a control projection that says an acknowledged occurrence is open.

A second Godot process recovers the journal epoch and proves:

1. material remains held in quarantine under the active incident;
2. transfer remains denied while the incident is active;
3. the player remains at the interlock source with the exact active receipt;
4. occupancy and runtime receipt authority both survive;
5. the custody occurrence retains its occurrence identity and acknowledgement;
6. the recovered interlock receipt completes exactly once and rejects replay;
7. only the custody procedure owner resolves the incident;
8. quarantine disposition then allows processing and stack transfer in canonical order;
9. the material becomes archivable with complete custody milestones;
10. the resolved occurrence leaves the active board while acknowledgement history remains;
11. the resolved state commits as the next journal epoch.

That procedural asymmetry has now been removed for the implemented archive fire/water hold.

### Implemented tracer bullet — staffed durable archive-incident containment

The twenty-seventh implementation slice moves live custody recovery behind the same named-actor work boundary used by infrastructure recovery. Two generated controls now exist:

```text
custody:contain_incident
  station: archive_processing
  actor job: records_officer
  phase: archive_fire_water
  duration: 3 ticks

custody:record_quarantine_disposition
  station: quarantine
  actor job: accession_technician
  phase: disposition_pending
  duration: 2 ticks
```

This exposed a real operational graph defect: quarantine had a material-transfer edge but no personnel route for its responsible accession staff. The graph now declares a directed personnel edge from `archive_accession` to `quarantine`. Layout and route compilation preserve that route separately from the ordered material-custody transfer edge; adding staff access does not create a custody bypass.

Live APIs that previously accepted role dictionaries for immediate incident resolution or quarantine clearance now fail closed. The pure custody runtime remains the semantic owner of those transitions, but the generated facility invokes it only after durable work completes with a named on-duty actor bound to the exact generated panel and station.

The custody response planner projects one admissible next control from custody truth:

```text
archive_fire_water  -> custody:contain_incident
disposition_pending -> custody:record_quarantine_disposition
normal              -> no custody response
```

The planner recommends but does not authorize. Work admission still requires active-shift staffing, station access, graph-routable named-agent movement, room support, correct panel phase, and absence of conflicting active work.

Containment and disposition inherit the scheduler's nonzero duration, arrival-without-work-tick, physical presence, condition suspension, exact progress, restart reconciliation, shift handoff, and one-use completion receipt guarantees. Custody mutation occurs only after the semantic transition accepts the completed receipt-bound work.

Scene-checkpoint validation now cross-checks active custody work against custody authority. Active containment requires the exact `archive_fire_water` incident. Active disposition requires material held in quarantine, no active incident, and no prior clearance. A valid-looking history that resolves the incident while containment work remains active is rejected as a mixed-owner contradiction.

The real two-process journal proof performs this sequence:

1. material enters quarantine through screening and accession;
2. `archive_fire_water` is declared;
3. immediate role-dictionary resolution is denied;
4. the planner selects `custody:contain_incident`;
5. a named records officer begins three-tick work at `archive_processing`;
6. one tick executes and two remain;
7. a forged resolved-history/active-work checkpoint is rejected without live mutation;
8. valid mid-containment state is journaled;
9. a second Godot process recovers the task interrupted with two ticks remaining;
10. transfer remains held until explicit reconciliation and completion;
11. immediate quarantine clearance is denied;
12. the planner advances to `custody:record_quarantine_disposition`;
13. an accession technician travels over the new personnel route to quarantine;
14. arrival consumes no work tick and two disposition ticks complete;
15. processing and stack transfer resume in canonical order;
16. archive eligibility returns and the resolved state commits as the next epoch.

A dedicated OpenGL/llvmpipe render at `/tmp/blacksite_shots/generated_custody_work.png` shows the generated `CONTAIN INCIDENT` panel in `archive_processing` with `[archive_fire_water]` and `WORKING 3t`. Weapon and laser overlays are disabled, leaving the state unobstructed and legible.

That manual arbitration gap is now closed for custody and critical-infrastructure response intake.

### Implemented tracer bullet — durable cross-domain operations queue

The twenty-eighth implementation slice adds `FacilityOperationsQueueRuntime` under schema `facility-operations-queue/v1`. It owns the operational clock, incident entries, first-seen time, deadlines, escalation, dispatch binding, append-only queue history, and event counter. Source domains still own incident truth; the queue owns only intake and arbitration.

Candidate identity binds the source occurrence to its current action and generated panel. Infrastructure candidates use failure receipt identity; custody candidates use material custody identity plus incident-history sequence. This prevents recurrence from inheriting a stale queue entry.

Base priorities are explicit and deterministic:

```text
archive fire/water containment  10
electrical power               20
cooling                        30
communications                 40
quarantine disposition         50
```

Lower numbers run first. A waiting entry that reaches its deadline escalates once, records an immutable escalation event, and receives an effective priority boost. Tie-breaking is stable by effective priority, first-seen clock, then entry identity. One arbitration tick may dispatch at most one task. The selected generated panel still passes through normal staffing, routing, station, phase, support, and duplicate-work admission; queue selection cannot manufacture authority.

The queue is now an owner in every scene epoch and journal record. Recovery validates schema, clock, counters, exact history sequence, panel identity, timing, status, and dispatched-task provenance. A dispatched entry must name a real nonterminal procedure task bound to the same panel. A waiting entry cannot carry task authority.

The real two-process proof declares cooling loss while archive material is held under `archive_fire_water`. It proves:

1. both source-domain plans enter one queue;
2. custody containment initially outranks cooling response;
3. custody reaches its deadline, escalates, and dispatches exactly one named task;
4. cooling continues aging while custody work is active;
5. cooling reaches its own deadline and escalates;
6. a forged queue claim binding cooling to a nonexistent dispatched task rejects the entire checkpoint without replacing the live queue;
7. queue clock, first-seen age, escalation, custody dispatch, and cooling wait state survive a real journal restart;
8. recovered custody work remains interrupted behind explicit reconciliation;
9. the recovered arbiter selects overdue cooling and dispatches exactly one additional task;
10. the post-arbitration state commits as the next journal epoch.

That lifecycle gap is now closed for dispatched procedure work.

### Implemented tracer bullet — queue lifecycle closure and resource reservations

The twenty-ninth implementation slice adds explicit actor and station reservation maps to `facility-operations-queue/v1`. A successful autonomous dispatch atomically binds queue entry, task, named actor, and exact station. Waiting entries cannot select a reserved station, and one actor or station cannot be reserved by multiple queue entries. Completion or terminal failure returns directly from the procedure scheduler to queue authority, records an immutable outcome event, changes queue status, and releases both reservations without waiting for a later source-plan reconciliation.

Rejected dispatches are classified explicitly. Retryable blockers retain waiting status, age, escalation, attempt count, and last blocker. Terminal rejection becomes `terminal_failed` and cannot silently retry. Queue checkpoint validation now rejects missing or orphan reservations, reservation-to-entry disagreement, dispatched task/panel mismatch, waiting entries carrying task authority, and malformed attempts/status.

The focused lifecycle proof establishes station exclusion, direct completion release, retryable attempt preservation, and terminal failure closure. The two-process integration proof now continues through both recovered custody and cooling tasks, verifies two direct `task_committed` queue events, proves actor/station reservations return empty, and journals the closed lifecycle state.

The control-room board now projects queue pressure without becoming queue authority:

```text
OPS  WAIT <n>  ESC <n>  RESERVED <n>
```

The OpenGL inspection render `/tmp/blacksite_shots/generated_control_room.png` visibly proves `OPS WAIT 1 ESC 1 RESERVED 0` during an overdue cooling response. The queue line is unobstructed and legible; lower condition text still shares the existing first-person inspection framing.

That policy is now graph-authoritative for the implemented response classes.

### Implemented tracer bullet — graph-owned retry and continuity limits

The thirtieth slice adds validated `operations_response_policies` for power, cooling, communications, archive containment, and quarantine disposition. Each declares priority, escalation deadline, retry backoff, maximum wait, and station capacity. Missing policies, zero backoff, invalid capacity, or a maximum wait shorter than the escalation deadline invalidate the operational graph.

Queue entries copy the graph policy as occurrence-bound admission provenance. Retryable dispatch rejection now sets an authoritative `next_attempt_clock`; arbitration cannot select the entry during backoff. Waiting work that reaches `max_wait_ticks` becomes terminal `abandoned` with a `continuity_limit_exceeded` history event rather than retrying forever. Checkpoint validation covers backoff, maximum wait, and abandoned status.

Focused proofs reject malformed graph policy and prove retry backoff blocks an early attempt. Existing two-process custody/cooling arbitration remains green using graph-derived values rather than runtime constants.

That abandonment gap is now closed for qualified staffing relief and custody safe hold.

### Implemented tracer bullet — executable continuity decisions

The thirty-first slice turns graph-declared abandonment policy into one-use, journaled action. Infrastructure occurrences execute `mobilize_qualified_relief`: continuous posts activate ordinary qualified relief while business-cycle jobs use on-call relief. Named mobilized staff are merged into the authoritative active watch without rebuilding or relocating unrelated active workers; unavailable idle identities are retired, while actors bound to live procedure tasks remain protected. The occurrence receives a fresh retry window and increments its reassignment count only after accepted staffing evidence.

Custody abandonment executes `mission_safe_hold`. It preserves the active custody hold, makes the queue occurrence non-dispatchable, and records custody identity and safe-hold evidence without fabricating containment or disposition.

`continuity_decisions` now persist with the operations queue. Checkpoint recovery validates action-to-policy identity, decision clock, evidence shape, safe-hold provenance, and reassignment counts. A forged action is rejected without replacing fresh live authority. A real second Godot process recovers both the named-relief decision and custody safe hold from the checksummed journal. Control-room projection now exposes safe-hold and decision counts.

The mission-shutdown branch is now explicit and restart-safe.

### Implemented tracer bullet — relief-exhaustion mission shutdown

The thirty-second slice separates failed qualified-relief mobilization from the resulting continuity command. Infrastructure policies declare `relief_failure_action: mission_shutdown`. Exhausting both primary and relief personnel records the rejected staffing decision, then a distinct accepted shutdown decision; the queue occurrence becomes terminal `mission_shutdown` while the infrastructure failure remains active and unavailable.

Mission authority receives one occurrence-bound `continuity_shutdowns` projection and remains `blocked`. Composite recovery requires an exact queue-to-mission bijection over entry, domain, action, clock, and reason. A forged mission snapshot that removes the projection while retaining queue shutdown is rejected without replacing live authority. An uncovered continuous post is persistable only when the same checkpoint carries a validated shutdown occurrence for that exact job; the general fail-closed coverage invariant remains intact.

The generated-facility proof exhausts the selected cooling-response job's primary and relief pools, reaches shutdown at the graph deadline, proves cooling was not restored, commits the epoch journal, and recovers queue, mission, staffing, infrastructure, and board state in a second Godot process. The OpenGL render `/tmp/blacksite_shots/generated_mission_shutdown.png` visibly reports `MISSION blocked` and `OPS WAIT 0 ESC 0 RESERVED 0 SAFE 0 SHUT 1 DEC 2`.

Explicit local reactivation authority is now implemented.

### Implemented tracer bullet — occurrence-bound shutdown reactivation

The thirty-third slice adds graph-validated `reactivation_authority_job` and `reactivation_station` to each infrastructure response policy. The current authority is the continuously staffed security officer physically present at `security_control`; unknown jobs, non-duty authority, and undeclared stations invalidate generation.

Reactivation is denied while the failed response job remains uncovered. Once real qualified replacement capacity exists, the exact named security-control actor may issue one consumed occurrence-bound receipt. That receipt reopens only the matching queue entry with a fresh retry clock, removes only its mission-shutdown projection, and leaves the infrastructure failure active and unavailable. Receipt replay, wrong occurrence, wrong job, wrong station, remote authority, and duplicate receipt issuance fail closed.

The queue persists receipt identity, actor, authority job, station, clock, consumed state, and per-entry reactivation count. Composite recovery requires receipts and counts to agree. The real cooling proof first rejects reactivation while capacity is absent, mobilizes one declared relief identity, accepts security-control authorization, rejects replay, commits the epoch, and recovers the reopened queue plus still-failed cooling service in a second Godot process.

### Implemented tracer bullet — incident-scoped external response capacity

The thirty-fourth slice closes the local-capacity gap with graph-owned mutual-aid policy and a durable admission lifecycle:

```text
requested → arrived at screened_entry → screened → authorized → credentialed → escorted → admitted → revoked
```

Admission binds an exact source occurrence, responder, response job, destination, incident-scoped credential, duty authority, and named security escort. Partial admission grants no staffing or queue capacity, and external responders never enter the ordinary roster, relief pool, or shift-turnover owner.

External dispatch is atomic across the operations queue, durable procedure work, and mutual-aid capacity reservation. Work has nonzero duration and exact panel, actor, station, action, occurrence, case, and credential provenance. Every tick revalidates that authority. Completion produces an ordinary scheduler receipt but cannot claim semantic success until the generated physical panel and source runtime accept matching task, receipt, responder, occurrence, service, action, and station evidence. A late downstream contradiction restores infrastructure, mission projection, work, queue, mutual aid, receipts, and panel audit state.

The live canonical-seed proof admits `external-command-9` for the generated cooling command panel, advances `safe_hold → controlled_shutdown` through the public work loop, credits the external identity in infrastructure history, resolves the queue, commits the work, and releases reservations. Composite checkpoint recovery and a separate checksummed-journal process preserve the transition. Two later processes continue ordinary repair, functional test, independent verification, and reconstitution to `normal`, revoke the incident credential exactly once, and prove restart cannot resurrect temporary capacity.

Mutual-aid authority now also persists responder and escort locations plus route evidence. The canonical router derives each path only from generated circulation edges marked `flow: personnel`, `ordinary_access: true`, and `emergency_only: false`. Checkpoint export and recovery reject unknown jumps and service, custody-only, material, evidence, or emergency-egress edges before replacing live state. A forged `screened_entry → archive_stack` route leaves the target facility unchanged. All 38 self-test scenes pass this generated-route policy boundary.

### Implemented tracer bullet — elapsed escorted mutual-aid admission movement

The thirty-fifth slice closes atomic escorted admission. Mutual-aid state now carries an `admissions` map parallel to demobilizations. `record_escorted_arrival` no longer admits in one step: validated evidence begins escorted travel and keeps phase `escorted` while the case records responder/escort routes, rooms, and pickup status. Escort routes must pass the staging room for pickup; a direct escort-station-to-destination path that skips staging is denied. Each tick advances one edge—escort alone until staging or colocation, then both together. Travel completes only when both are at the destination: phase becomes `admitted`, durable `escort_routes` are written, and the admissions record is erased. Checkpoint recovery suspends open admissions the same way demobilizations are suspended; `resume_escorted_travel` is required before further ticks. `complete_escorted_travel` loops ticks to admission for call sites that do not need mid-travel inspection. Capacity still appears only after phase `admitted`.

Admission elapsed movement is closed.

### Implemented tracer bullet — staff-agent binding and mutual-aid location markers

The thirty-sixth slice binds rostered escort identities to mutual-aid temporary locations and draws visual markers for escorts and external responders. `FacilityStaffAgentRuntime.sync_mutual_aid_bindings` mirrors `mutual_aid_state.temporary_locations` onto existing agents only: bound escorts take the temporary room, clear route and destination, set status `mutual_aid_bound`, and record a case id when known. Agents that leave temporary locations clear the bound flags, empty their route, pin destination to the current room, and return to `arrived`. `dispatch` and `dispatch_egress` deny while `mutual_aid_bound` is set; `cancel_dispatch` may still clear an in-flight route, but the next sync re-applies the bind. External responders never enter the agents map or the active-watch checkpoint set; they remain non-roster and receive amber markers only. Bound escort markers use violet, with meta that distinguishes `role` external versus escort. Location authority remains mutual-aid `temporary_locations`; staff-agent state only mirrors rostered escorts. `_sync_mutual_aid_locations` runs after escorted-travel and environmental fire-inspector demobilization advances so agent rooms and markers track admission ticks.

Surface binding for temporary mutual-aid locations is closed. Residual presentation work, if any, is optional Label3D nameplates or route ribbons—not another authority or binding gap.

### Implemented tracer bullet — player mission layer on the institution

The thirty-seventh slice puts a player contract on the live Cyber/Archives facility without inventing institutional authority. `FacilityPlayerMissionRuntime` (`facility-player-mission/v1`) owns contracts `foreign_extract_evidence` and `foreign_extract_record`, wired through the generated facility scene. Objectives are ordered and required: infiltrate → locate → acquire → exfiltrate. Acquisition demands an institution-produced artifact already present in mission state plus physical colocation in the contract target room (`contained_lab` or `archive_stack`). Heat and an immutable audit trail advance on acquire and denied exfil; successful runs rate `GHOST` / `SHADOW` / `PANTHER` / `ASSAULT` from heat. Ordinary exfil is denied when the exit room carries a protective posture or when mission status is `blocked`; `emergency_exit` remains the blocked-mission exception. `project_objectives` feeds ObjectiveTracker without becoming mission authority.

Player contracts now wait on real institutional production rather than spawning loot.

### Implemented tracer bullet — autonomous institutional mission cycle driver

The thirty-eighth slice lets the facility advance `operation_runtime` mission steps without the player. When services and jobs are available, staff mission-graph preflight produces `evidence_package` and later artifacts through ordinary conduct steps. The player extract contracts observe those artifacts in place; they do not mint packages on start. Mission cycle progression, protective posture, and blocked status remain institutional owners that the player layer only reads.

Autonomous institutional artifact production for player contracts is closed. Player door interact now routes through personnel-security transitions rather than free teleport helpers.

### Implemented tracer bullet — policy-door personnel transitions and denial heat

The thirty-ninth slice binds player door interact to `personnel_security` authority. `FacilityPolicyDoor.interact` walks its parent chain for `handle_policy_door_interact`; the generated facility owns the decision when present, while isolated door tests keep the local `request_open` fallback. From the door's `from_room` / `to_room` metas and the player's current `personnel_state` room, the facility resolves a destination and calls `request_personnel_transition` (including reverse edges and emergency-only doors). Accepted transitions open the door visually and advance personnel room; denied transitions under an active player contract increment heat and append an `access_denied` audit entry via `FacilityPlayerMissionRuntime.record_access_denial`. Physical room remains authoritative `personnel_state`—teleport helpers stay test-only. Exfil gates for protective posture and mission-blocked status remain owned by the player mission runtime (slice 37).

Door-authority personnel movement for the player is closed. Residual next is live shift-change presentation / nameplates, or player acquisition leaving custody/audit evidence for investigators.

### Implemented tracer bullet — unauthorized removal investigation evidence

The fortieth slice makes free-agent acquisition leave investigator-visible evidence without erasing the institution's artifact. `FacilityCustodyRuntime.record_unauthorized_removal` fails closed on empty `artifact_id` or `room`, appends a custody history event `unauthorized_removal` with artifact, room, actor, and optional `run_id`, and opens an `open_investigations` entry (`investigation_id: theft-%d` from history sequence, kind `unauthorized_removal`, `open: true`). Successful `acquire_player_mission_target` calls that recorder, then marks the matching mission artifact `compromised=true` with `stolen_by` and `stolen_run` rather than deleting it, and refreshes the control board.

`FacilityControlRoomRuntime.compile_status` projects each open investigation as a condition of kind `investigation` (priority 25): unauthorized removals own to `security_officer`, other investigation kinds to `records_officer`. Custody incidents remain separate conditions; theft heat is now a board-visible investigation, not a silent inventory flag.

Player acquisition now leaves custody and control evidence for investigators. Residual next is operator-run bootstrap with physical mission stations for a playable free-agent path.

### Implemented tracer bullet — operator-run bootstrap and physical mission stations

The forty-first slice makes the generated facility launchable as an operator free-agent run. `generated_facility_main` exports `operator_run` (default false) and `operator_contract_id` (default `foreign_extract_evidence`). When `operator_run` is true at the end of `_ready`—after the player mission runtime is ready—the scene runs `run_institution_workday()`, starts the named player contract, builds mission stations, and prints `OPERATOR_RUN_READY`. `grant_inspection_credentials` remains independent so playability and door path are not collapsed into a separate god-mode credential branch in this slice.

Mission stations live under a `PlayerMissionStations` group: an acquire station at the contract `target_room` (Label3D `ACQUIRE TARGET`; interact observes then acquires) and an exfil station at `screened_entry` (Label3D `EXFILTRATE`), with an optional second exfil at `emergency_exit` when that room exists in geometry. Stations are simple `StaticBody3D` interactables created by `_make_mission_station`; `activate_player_mission_station(action, interactor)` requires the interactor to be the player and personnel `current_room` to match the station room meta before dispatching acquire (observe + acquire) or exfil (`try_player_exfiltrate`).

Operator playable bootstrap and physical acquire/exfil stations are closed.

### Implemented tracer bullet — restricted free-agent cover credentials

The forty-second slice separates operator identity from inspection god-mode. When `operator_run` is true, admission uses `operator_player` with forged `cyber_researcher` cover and keycard tier 4 only—not duty, security, facilities, or systems roles. Inspection builds still grant multi-role tier-5 credentials when `grant_inspection_credentials` is true and `operator_run` is false. The institution still produces artifacts through the ordinary workday; the free agent steals them under limited access that can fail closed at doors outside researcher reach.

Restricted free-agent cover is closed for the default operator launch. `facility_operator_run_selftest` door-walks `screened_entry → staff_control → cyber_ops → contained_lab`, acquires via mission station (leaving custody investigation + compromised institutional artifact), denies plant access under researcher cover, then door-walks out and exfils at `screened_entry`. The default main scene ships this playable free-agent steal path. Residual next: live shift presentation / nameplates, or stealth detection that converts theft heat into staff search without breaking institutional authority.

---

## 17. Open research obligations

The public DoD source `UFC 4-010-05, SCIF/SAPF Planning, Design, and Construction` (26 May 2023) was retrieved directly from WBDG as a 77-page PDF: <https://www.wbdg.org/FFC/DOD/UFC/ufc_4_010_05_2023.pdf>. It reissues and cancels the 1 October 2013 Change 1 edition, applies across planning through construction for DoD SCIF/SAPF projects, and explicitly points to ICD 705, ICS 705-1/02, the IC Technical Specification, and DoD manuals as the underlying regulatory authorities. This GDD uses it for public planning/process provenance only; it does not infer restricted construction details or claim that the generated facility is an accreditable SCIF/SAPF.

- Retrieve and review the public ODNI/NCSC SCIF technical specification.
- Study public national-laboratory and federal cyber-center planning documents without treating promotional descriptions as floor-plan evidence.
- Add media-specific archive requirements for paper, magnetic media, optical media, film, and preservation copies.
- Research federal evidence-handling and digital-forensics laboratory accreditation criteria suitable for a game abstraction.
- Research realistic staffing ratios and shift coverage from public SOC/NOC and records-center material.
- Research generator fuel autonomy, UPS duration, cooling ride-through, and restart sequencing at the selected facility scale.
- Build a source ledger for every room or procedure added after this document.

---

## 18. Acceptance test for the design

A generated Cyber/Archives facility is successful when a reviewer can answer all of the following from the generated model:

- What mission is this facility performing?
- Which jobs are required to perform it?
- Where does each job work and what does it produce?
- How do people, evidence, equipment, and waste move?
- Which authority controls each door, system, and collection?
- What powers and cools critical operations?
- How are records accessioned, stored, retrieved, and destroyed?
- What happens on the night shift?
- What happens when power, cooling, communications, staffing, or security fails?
- Can the facility continue its essential mission in a degraded state?
- Does the floor plan follow from those answers rather than from random room placement?

If those answers are absent, the result is a themed maze, not the autonomous facility this project is trying to build.
