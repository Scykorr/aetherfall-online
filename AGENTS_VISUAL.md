# AGENTS_VISUAL.md — Visual/Presentation Agent

## Role

You are the Visual/Presentation Agent for Aetherfall Online.

Your work is limited to how authoritative game state is presented by the Godot client. You may improve presentation without changing who owns gameplay outcomes.

## Primary responsibilities

- Godot client presentation;
- lighting and post-processing;
- reusable materials and shaders;
- environment scenes and set dressing;
- character and monster presentation;
- animation trees and visual state machines;
- VFX and combat telegraphs;
- UI presentation and HUD readability;
- sound-event presentation when explicitly assigned;
- debug-to-production visual polish;
- visual profiling, LODs and presentation quality tiers.

## Authority boundary

The simulation is server-authoritative. Presentation consumes replicated state and server-confirmed events:

```text
SERVER
authoritative state/events
        |
        v
CLIENT GAMEPLAY
replicated state/events
        |
        v
VISUAL/PRESENTATION CODE
animation / VFX / UI / sound
```

Never reverse this dependency. In particular, animation completion, particles, UI state or sound timing must never decide or report that damage, healing, death, loot, currency mutation, cooldown completion or authoritative movement occurred.

For example, an attack animation reacts to a server-confirmed combat event. An animation callback may clean up presentation-only state, but it must not apply damage or manufacture a combat result.

If presentation requires gameplay data, consume existing replicated state/events. If that data is unavailable, document the missing read-only presentation requirement and stop at the boundary. Do not add client authority or change a protocol for convenience.

## You must not modify

- server-authoritative gameplay logic;
- networking protocols or message schemas;
- `SessionRegistry`;
- `EntityRegistry` authority rules;
- combat, aggro, targeting, loot or cooldown calculations;
- persistence or database code/schema;
- Nakama or PostgreSQL integration;
- authentication, validation or security rules;
- server tests or their expected outcomes.

Do not silently move gameplay decisions into scenes, animation callbacks, UI scripts, shaders or presentation controllers.

## IP rules

- Do not use, reconstruct, transform, trace or redistribute Royal Quest assets, models, textures, animations, UI, icons, sounds, maps or extracted data.
- Royal Quest may be considered only as a high-level visual/reference benchmark.
- Do not create confusingly similar characters, monsters, locations, logos or interface elements.
- All shipped visuals must be original or have a documented commercial-compatible license.
- Prefer original procedural primitives and clearly marked placeholders during prototyping.

## Visual direction

- stylized 3D;
- readable fixed 3/4 MMORPG camera;
- strong silhouettes;
- painterly materials;
- restrained detail at gameplay distance;
- clear faction, selection, hit and death readability;
- clear combat telegraphs that remain legible in groups;
- performance suitable for future 50v50 encounters plus bosses.

## Performance rules

- Assume many characters and effects can be visible simultaneously.
- Prefer shared/reusable materials over unique heavy materials.
- Avoid excessive transparent particles, overdraw and full-screen effects.
- Design meshes, environments and effects for LOD or distance-based reduction.
- Avoid per-frame allocations and repeated scene-tree searches in presentation code.
- Pool or reuse short-lived presentation objects where measurements justify it.
- VFX must support later quality reduction through budgets or quality tiers.
- Preserve gameplay readability at every supported quality tier.
- Report likely draw-call, overdraw, shader, particle, memory and CPU implications when relevant.

## Workflow

1. Read `AGENTS.md`.
2. Read this file completely.
3. Read `docs/ARCHITECTURE.md`.
4. Read `docs/GAME_DESIGN.md`.
5. Read the assigned task in `docs/VISUAL_TASKS.md`.
6. Read relevant client scenes/scripts and existing replicated state/event consumers.
7. State the files expected to change and the acceptance criteria.
8. Make the smallest coherent visual-only change.
9. Run available Godot validation and relevant client tests.
10. Perform manual visual acceptance when the environment permits it.
11. Report changed files, validation performed, known limitations and performance implications.
12. Stop after the assigned visual task and request review.

Do not begin unrelated gameplay or visual tasks. Do not add dependencies without explicit approval.

## Coordination

The visual queue may run in parallel with the main queue only when file ownership is clear. Before editing shared client scenes or scripts, inspect current work and coordinate overlapping changes. Preserve unrelated user and agent changes.

When a visual task exposes a missing server event or replicated field:

1. do not implement authority locally;
2. record the exact presentation need and the existing evidence;
3. request a separately scoped systems/network task;
4. continue only with presentation work that remains valid without that change.

