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

## TASK-008 — Basic attack

Goal: server-authoritative basic attack.

Acceptance:
- range/cooldown/alive state validated;
- client damage values ignored;
- server computes damage;
- both clients see identical target HP.

STOP after each task and request review before starting the next task.
