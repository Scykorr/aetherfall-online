# Codex task queue

Work strictly top-to-bottom unless the human explicitly reprioritizes.

## TASK-001 — Verify bootstrap client

Status: Completed.

Goal: ensure the committed Godot client opens and runs without script errors.

Acceptance:
- `client/project.godot` imports in Godot 4.x;
- Main scene starts;
- grey floor, player capsule and camera are visible;
- no copyrighted third-party assets.

Do not add networking.

## TASK-002 — Player movement polish

Status: Completed.

Goal: improve the existing WASD greybox movement.

Acceptance:
- movement uses Input Map;
- diagonal movement is normalized;
- acceleration/deceleration are configurable exports;
- player rotates toward movement direction;
- movement remains framerate-independent via physics tick.

Non-goal: animation.

## TASK-003 — Camera feel

Status: Completed.

Goal: make a fixed three-quarter MMORPG camera component.

Acceptance:
- exported distance, height and look-ahead;
- smooth follow;
- optional zoom input with min/max;
- player movement does not rotate the camera.

Non-goal: free orbit camera.

## TASK-003A — Mouse Movement Controller

Status: Completed.

Goal: replace WASD runtime movement with classic MMORPG mouse movement while preserving right-mouse camera orbit.

Acceptance:
- a short left click uses a camera ray and walkable-only physics query to set a destination;
- holding left mouse past an exported threshold follows the ground point under the cursor and stops on release;
- movement uses explicit `IDLE`, `MOVE_TO_POINT` and `FOLLOW_CURSOR` intent states;
- exported arrival distance prevents jitter at the destination;
- the destination marker uses only Godot primitives and hides on arrival;
- UI clicks and invalid ground hits do not create movement commands;
- player acceleration, deceleration and smooth rotation remain physics-tick based;
- right-mouse camera orbit and wheel zoom continue to work independently.

Non-goals: NavMesh, networking, combat, targeting, interaction and animation.

## TASK-003B — Navigation & Pathfinding

Status: Completed.

Goal: add navigation-based click-to-move while preserving responsive direct steering for hold-to-move.

Acceptance:
- `NavigationRegion3D` uses a baked Godot `NavigationMesh` covering the walkable greybox floor;
- primitive cube, column and passage obstacles are excluded from navigable paths;
- the player owns a configured `NavigationAgent3D` child component;
- `MOVE_TO_POINT` validates destinations and follows agent path positions through the existing character motor;
- unreachable or obstacle destinations are rejected unless a nearby navigation point is within the configured snap distance;
- a new click replaces the active path without setting a target every frame;
- the marker shows the resolved navigation destination and hides when movement ends;
- optional Godot-only path debug visualization is disabled by default;
- `FOLLOW_CURSOR`, right-mouse camera orbit and wheel zoom retain their TASK-003A behavior;
- automated Godot navigation smoke tests cover paths, obstacle rejection, motor movement and path replacement.

Non-goals: dynamic pathfinding for hold mode, networking, combat, targeting and animation.

## TASK-004 — Headless zone server bootstrap

Status: Completed.

Goal: create a minimal Godot headless server project.

Acceptance:
- server launches headless;
- creates a deterministic test zone;
- prints simulation tick health periodically;
- no client connection yet.

## TASK-005 — Client/server handshake

Status: Completed.

Goal: two clients can connect to the zone server and receive assigned network IDs.

Acceptance:
- server owns IDs;
- disconnect cleans up session;
- malformed handshake rejected;
- protocol version is explicit.

## TASK-005A — Automated server test CI

Status: Completed.

Goal: run the deterministic Godot server test suite automatically for repository changes.

Acceptance:
- GitHub Actions runs server tests on every push and pull request;
- CI uses Godot 4.7.1 in headless, non-interactive mode;
- a failed automated test produces a failed workflow job;
- CI configuration does not add a third-party test framework.

## TASK-006 — Authoritative network movement

Status: Completed.

Goal: replace local-authoritative movement with input intent + server snapshots.

Acceptance:
- client sends directional input;
- server computes final position;
- remote clients interpolate;
- client-supplied transform cannot teleport character.

## TASK-007 — First server-owned monster

Status: Completed.

Goal: server spawns one training creature.

Acceptance:
- monster exists on server first;
- clients receive spawn/despawn;
- idle/wander is server-side;
- monster has server-owned HP.

## TASK-008A — Entity Targeting System

Status: In Progress (automated/runtime validation complete; manual LMB and visual acceptance pending).

Goal: add server-authoritative monster targeting without combat.

Acceptance:
- LMB on a replicated monster requests target selection without starting movement;
- server validates READY ownership, entity type, existence and selection range;
- confirmed target state is replicated per player;
- selected monster shows a procedural ring and authoritative HP frame;
- clear, disconnect and monster despawn remove target state;
- automated targeting and existing regression tests pass.

Non-goals: attacks, damage, cooldowns, aggro, PvP targeting and skills.

## TASK-008A-FIX — Diagnose Godot signal 11 startup crash

Status: Completed.

Goal: isolate the local Godot 4.7.1 startup crash, repair project parse regressions and rerun TASK-008A validation.

Result:
- restricted headless launches could not access Godot AppData/cache directories and crashed before project loading;
- clean-cache GUI validation exposed global class-cache dependencies in client and server scripts;
- direct preload/base-node references removed those clean-checkout parse failures;
- client, editor, recovery mode, server/client suites and two-client network integration run successfully outside the restricted sandbox.

## TASK-008B — Server-Authoritative Basic Attack & Damage

Status: In Progress (implementation, automated tests and headless integration complete; manual SPACE input and remote CI confirmation pending).

Goal: add one server-authoritative basic attack against the confirmed monster target.

Acceptance:
- `basic_attack` Input Map action sends only a sequenced attack intent;
- server derives attacker and current target from authoritative session state;
- server validates target, range, cooldown and replay sequence;
- server calculates damage, clamps monster HP to 1 and broadcasts a combat result;
- both clients observe identical damage and authoritative HP;
- concurrent player attacks do not lose HP updates;
- existing and combat automated tests pass.

Non-goals: death, respawn, loot, aggro, monster attacks, PvP, skills and animation systems.

## TASK-008C — Death & Respawn

Status: Completed.

Goal: add authoritative death and respawn after the temporary TASK-008B HP floor is removed.

Acceptance:
- lethal server damage reduces HP to zero and transitions the monster from `ALIVE` to `DEAD` exactly once;
- the server records the authoritative killer, clears every target reference and stops dead-monster AI;
- dead monsters cannot be selected or attacked and their client presentation is non-targetable;
- a data-configured delay schedules respawn from the fixed server tick;
- respawn reuses the runtime entity ID, restores full HP and returns the monster to its spawn point;
- reliable lifecycle events and world snapshots give all clients the same death/respawn state;
- automated lifecycle regressions and a real one-server/two-client integration scenario pass.

Non-goals: loot, XP, monster attacks, persistence and animation systems.

## TASK-009 — Server-Authoritative Monster Aggro, Chase & Basic Attack

Status: In Progress (implementation, automated tests and local integration complete; remote CI confirmation pending).

Goal: turn the training monster into the first server-authoritative hostile PvE entity.

Acceptance:
- living monsters acquire the nearest valid player on deterministic server ticks and keep that target until invalidated;
- authoritative AI transitions through `IDLE`, `WANDER`, `CHASE`, `ATTACK`, `RETURN` and `DEAD`;
- chase, attack range, cooldown, damage and leash use only server-owned positions, ticks and template data;
- monster attacks use the shared `CombatSystem` event boundary;
- player HP is initialized, mutated and replicated server-side with a temporary floor of `1`;
- leash clears aggro, returns the monster to spawn and restores HP before normal idle/wander resumes;
- death interrupts aggro, movement and attacks, while respawn restores clean initial AI state;
- deterministic automated tests and one-server/two-client combat, leash and lifecycle integrations pass.

Non-goals: player death/respawn, threat tables, loot, XP, skills, animations, VFX and sound.

## TASK-010 — Server-Authoritative Player Death & Respawn

Status: In Progress (implementation, automated tests and local integration complete; remote CI confirmation pending).

Goal: complete the first PvE combat loop with authoritative player death and respawn.

Acceptance:
- lethal server damage transitions player HP to `0` and `ALIVE -> DEAD` exactly once;
- death records authoritative killer/ticks/position, stops movement, clears player target and invalidates monster aggro;
- dead players cannot move, target or attack through malicious client intents;
- configurable server ticks respawn the same connected entity at its server-owned spawn position;
- respawn restores full HP, `ALIVE`, zero velocity and empty target without reconnect;
- movement, targeting and combat work again after respawn;
- lifecycle state/events replicate consistently to local and remote clients;
- disconnect while dead removes the pending runtime lifecycle cleanly;
- deterministic automated tests and one-server/two-client integration pass.

Non-goals: XP, loot, inventory, corpse, penalties, resurrection skills, PvP and polished visuals.

## TASK-011 — XP + Server-Authoritative Loot Foundation

Status: In Progress (implementation, automated tests and local integration complete; remote CI confirmation pending).

Goal: grant authoritative XP and world loot for monster kills, then prove secure pickup without a full inventory.

Acceptance:
- the authoritative killer receives configured XP exactly once and deterministic multi-level progression works;
- server-seeded loot tables create registry-owned loot with authoritative item, quantity, position and killer ownership;
- loot replicates with one entity ID to all clients and survives monster respawn/player death/disconnect until pickup or timeout;
- pickup accepts only READY, living owner in range and grants the temporary RewardLedger exactly once;
- foreign, distant, dead, unknown and replayed pickup intents cannot grant rewards;
- item definitions and loot tables are data-driven;
- existing and new automated tests plus one-server/two-client integration pass.

Non-goals: full inventory, equipment, trading, currency, crafting, persistence, party loot and final visuals.

## TASK-012 — Server-Authoritative Inventory Foundation

Status: In Progress (implementation, automated tests and local integration complete; remote CI confirmation pending).

Goal: replace the temporary RewardLedger with the first authoritative slot/stack inventory and functional prototype UI.

Acceptance:
- every READY player receives a configurable 24-slot server-owned inventory with monotonically increasing revision;
- atomic loot pickup fills partial stacks before empty slots and leaves world loot intact when the full quantity does not fit;
- `max_stack`, item identity, slot indices and quantities are validated against shared item definitions;
- sequenced MOVE, merge, split, swap and explicit destroy intents mutate only the sender's inventory and stale/replayed commands are rejected;
- player death/respawn preserves runtime inventory while disconnect removes it;
- client applies only newer authoritative inventory states and offers an Input Map-driven functional 24-slot window;
- deterministic inventory, security, duplication, lifecycle and replication tests plus one-server/two-client integration pass.

Non-goals: equipment, stats, consumable use, vendors, trading, currency, bank, crafting, mail, persistence, database and final UI art.

STOP after each task and request review before starting the next task.
