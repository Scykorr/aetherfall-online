# Visual/Presentation task queue

This queue is owned by the Visual/Presentation Agent and is governed by `AGENTS.md` and `AGENTS_VISUAL.md`.

Work top-to-bottom unless the human explicitly reprioritizes. Visual tasks may run in parallel with `docs/CODEX_TASKS.md` only when their file scopes do not conflict. Stop after each task and request review before starting the next task.

## Global acceptance rules

- Changes are client-side and presentation-only.
- Authoritative outcomes come exclusively from replicated state or server-confirmed events.
- No networking protocol, server gameplay, persistence, database, security or server-test changes.
- All assets are original, procedural placeholders or documented commercial-compatible licensed assets.
- Godot validation and relevant tests pass; manual checks and performance implications are reported honestly.

## VIS-001 — Prototype art direction

Status: Completed.

Goal: establish an original, lightweight visual language for the first playable slice.

Acceptance:
- a concise visual-direction document defines palette, value hierarchy, silhouettes, material treatment, scale and gameplay-distance readability;
- reference material records principles rather than copying another game's protected expression;
- player, hostile creature, traversable ground, obstacles, selection and danger telegraphs have distinct readability targets;
- an initial performance envelope covers materials, lights, shadows, particles and screen-space effects;
- a small Godot look-development scene uses only original/procedural placeholders.

Non-goals: final production assets, gameplay changes, combat redesign and protocol changes.

## VIS-002 — Player placeholder character

Status: Pending VIS-001.

Goal: replace the player capsule presentation with an original modular placeholder that reads clearly from the 3/4 camera.

Acceptance:
- the placeholder has a strong front/back silhouette and facing direction;
- geometry and materials are original and reusable;
- presentation remains separate from the authoritative movement/controller logic;
- remote and local players can share the presentation scene with controlled visual variation;
- material count and approximate render cost are documented.

Non-goals: equipment stats, character customization persistence, authoritative movement and final character art.

## VIS-003 — Monster visual pass

Status: Pending VIS-001.

Goal: give the existing training creature an original, readable placeholder presentation.

Acceptance:
- the creature silhouette is distinct from the player at gameplay distance;
- alive, selected, damaged, dead and respawned presentation follows existing replicated state;
- dead presentation is non-targetable because gameplay state says it is dead, not because the visual hides it;
- selection and HP presentation remain readable without copying third-party UI or creatures;
- reusable materials and expected cost for groups of monsters are documented.

Non-goals: monster AI, stats, aggro, attacks, loot and respawn authority.

## VIS-004 — Animation controller

Status: Pending VIS-002 and VIS-003.

Goal: add presentation-only animation state machines for player and monster placeholders.

Acceptance:
- idle and locomotion react to replicated movement state;
- attack reacts to a server-confirmed combat event;
- death and respawn react to authoritative lifecycle state/events;
- animation completion changes presentation-only state and never applies gameplay outcomes;
- repeated, delayed and out-of-order presentation inputs fail safely without inventing authoritative state;
- transition logic is typed, composable and documented.

Non-goals: damage timing authority, cooldown authority, root-motion authority, combat calculations and protocol changes.

## VIS-005 — Hit/death presentation

Status: Pending VIS-004 and an existing confirmed combat/lifecycle event path.

Goal: communicate confirmed hits, HP loss, death and respawn clearly.

Acceptance:
- hit feedback is spawned only from server-confirmed results or authoritative state changes;
- lethal presentation occurs once for an authoritative death transition;
- late join/snapshot state produces the correct alive/dead presentation without replaying false hits;
- effects remain readable when several characters attack one target;
- effect duration, transparency and particle cost are documented.

Non-goals: hit validation, damage calculation, killer selection, loot, XP and respawn scheduling.

## VIS-006 — Environment greybox polish

Status: Pending VIS-001.

Goal: turn the test zone into an original atmospheric readability benchmark while preserving navigation and collision behavior.

Acceptance:
- lighting, palette, reusable materials and set dressing support the 3/4 camera;
- walkable space, blockers and passages remain visually unambiguous;
- collision and navigation geometry are not changed unless explicitly included in a separately approved gameplay task;
- the scene includes a repeatable lighting/performance benchmark view;
- shadow, light, material and geometry costs are documented.

Non-goals: map expansion, navigation redesign, encounter design and copied locations.

## VIS-007 — Prototype HUD

Status: Pending VIS-001 and existing replicated target/combat state.

Goal: create an original, scalable HUD for current authoritative state.

Acceptance:
- local player, confirmed target, HP and relevant connection/debug state are readable at common window sizes;
- HUD values are bound to replicated state and never predict authoritative damage, loot or cooldown completion as fact;
- target loss, death, despawn, reconnect and missing data have explicit visual states;
- layout supports UI scaling and avoids blocking the combat focal area;
- no third-party UI, icon or font is used without a compatible documented license.

Non-goals: inventory/economy implementation, combat authority, protocol changes and final UX breadth.

## VIS-008 — VFX budget system

Status: Pending VIS-005.

Goal: provide reusable quality and concurrency controls for presentation effects.

Acceptance:
- effects declare a category, priority and scalable cost level;
- configurable budgets cap concurrent particles/effects and degrade low-priority visuals first;
- authoritative events are never dropped from gameplay state when their visual effect is suppressed;
- essential telegraphs remain readable at the lowest supported quality tier;
- a debug view exposes active counts and suppressed presentation effects;
- no per-frame allocations are introduced in the steady-state hot path where reasonably avoidable.

Non-goals: network interest management, combat event filtering and server performance logic.

## VIS-009 — LOD/performance test

Status: Pending VIS-002, VIS-003, VIS-006 and VIS-008.

Goal: measure presentation behavior under a representative future crowd-and-boss load.

Acceptance:
- a repeatable client-side benchmark scene or harness represents up to 50v50 characters plus a boss using presentation-only stand-ins;
- quality tiers exercise LOD, shadows, materials and VFX budgets;
- measurements report resolution, hardware/environment, visible counts, frame time/FPS and major bottlenecks;
- the benchmark does not simulate or bypass server-authoritative gameplay;
- regressions and follow-up optimization tasks are recorded with measurable targets.

Non-goals: production-scale networking load tests, server simulation benchmarks and premature engine-wide rewrites.
