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

## VIS-002 — First playable environment prototype

Status: Completed.

Goal: create a small original outdoor MMORPG test location for existing movement, camera, targeting, combat and monster lifecycle testing.

Acceptance:
- terrain, path, vegetation, rocks, vertical landmarks, a small ruin and readable area boundaries establish the VIS-001 direction;
- player spawn, server-owned monster spawn and their combat space remain clear at gameplay distance;
- the existing gameplay camera, navigation mesh, collision layout and presentation systems are reused without changing authority logic;
- ground treatment leaves target rings, future AoE telegraphs and damage numbers readable;
- lighting is a reusable daytime baseline rather than a single-angle cinematic setup;
- materials, lights and repeated props remain suitable for later LOD, instancing and quality scaling.

Non-goals: final environment art, biome production, gameplay changes, player/monster redesign, VFX and protocol changes.

## VIS-003 — Character & monster visual pipeline prototype

Status: Completed.

Goal: replace capsule/sphere visuals with original stylized prototype models behind reusable presentation-scene boundaries.

Acceptance:
- local and remote players use the same swappable humanoid presentation scene;
- Training Wisp has a distinct non-humanoid silhouette and a separate presentation scene;
- gameplay/network roots do not depend on prototype model internals;
- player presentation exposes `RightHand`, `LeftHand`, `Head` and `Back` visual anchors;
- replicated ALIVE/DEAD and AI state may adjust monster presentation without creating client authority;
- scale, import, skeleton, material, naming and performance expectations are documented;
- existing movement, targeting, combat and lifecycle behavior remains intact.

Non-goals: final models, equipment gameplay, animation controller, attack/death animation, facial animation and customization.

## VIS-004 — Animation controller

Status: Completed.

Goal: add presentation-only animation state machines for player and monster placeholders.

Acceptance:
- idle and locomotion react to replicated movement state;
- attack reacts to a server-confirmed combat event;
- death and respawn react to authoritative lifecycle state/events;
- animation completion changes presentation-only state and never applies gameplay outcomes;
- repeated, delayed and out-of-order presentation inputs fail safely without inventing authoritative state;
- transition logic is typed, composable and documented.

Implementation notes:
- player and Training Wisp share a presentation-only state contract: Idle, Run, AttackBasic, Hit, Death and Respawn;
- locomotion and lifecycle consume replicated snapshots, while Attack/Hit consume the existing server-confirmed combat event;
- transitions animate model presentation only; gameplay roots, authority, protocol and combat timing are unchanged;
- prototype transform clips are deliberately replaceable by production skeletal clips with the same stable names.

Non-goals: damage timing authority, cooldown authority, root-motion authority, combat calculations and protocol changes.

## VIS-005 — XP, loot and reward feedback

Status: Completed.

Goal: make authoritative progression and loot outcomes understandable without the debug console.

Acceptance:
- local progression HUD displays replicated level, current XP and next-level requirement;
- positive XP changes and level increases produce bounded passive feedback from replicated state;
- replicated world loot shows display name, quantity, rarity decoration and non-color-only ownership state;
- pickup success is shown only to the authoritative recipient after the existing confirmed result;
- rejected pickup uses existing result codes and never predicts acceptance client-side;
- changed inventory slots flash only after a newer authoritative inventory revision is applied;
- passive reward UI ignores pointer input and reward feed entries expire with a strict concurrency cap.

Implementation notes:
- one-level XP deltas are derived only between consecutive authoritative progression snapshots; skipped multi-level snapshots use a generic `XP UPDATED` notice because the exact reward is not replicated;
- `INVENTORY_FULL`, `NOT_OWNER` and `TOO_FAR` have presentation mappings, but the current server returns generic `REJECTED` for ownership/range failures;
- common and uncommon loot use shared geometry with different label treatment; owned loot uses a ring plus pickup prompt, while unavailable loot uses a square marker plus `LOCKED` label.

Non-goals: reward calculation, loot RNG, ownership rules, pickup validation, inventory authority, final HUD, item icons, currency, quests, sound overhaul and legendary effects.

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
