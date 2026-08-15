# AGENTS.md — instructions for Codex and coding agents

## Mission

Build Aetherfall Online as an ORIGINAL MMORPG. Royal Quest may be studied only as a high-level design reference.

## Hard IP boundary

NEVER add, reconstruct, transform, trace or redistribute:
- Royal Quest models, textures, animations, audio, maps or UI;
- Royal Quest code or decompiled code;
- extracted Royal Quest balance tables/data;
- Royal Quest quest/dialogue/localization text;
- confusingly similar names, logos, characters or locations.

Use original placeholders or assets with documented commercial-compatible licenses.

## Architecture invariants

1. The MMO simulation is server-authoritative.
2. A client may send INPUT/INTENT, never authoritative damage, loot, currency, cooldown completion or final position.
3. Persistent item/currency mutations must eventually be transactional and idempotent.
4. Do not change DB schemas or network protocols unless the task explicitly asks.
5. Gameplay content should be data-driven where practical.
6. Prefer small composable systems over large managers.
7. Do not add dependencies silently.
8. Do not perform unrelated refactors.
9. Keep Godot scenes/scripts human-readable and Git-friendly.
10. Security and duplication exploits are correctness bugs, not future polish.

## Workflow for every task

Before editing:
1. Read this file.
2. Read `docs/ARCHITECTURE.md`.
3. Read the task in `docs/CODEX_TASKS.md`.
4. State the files you expect to change.
5. State acceptance criteria.

During implementation:
- make the smallest coherent diff;
- keep placeholder visuals original and generic;
- prefer typed GDScript;
- keep warnings/errors at zero where reasonable.

After implementation:
- run available validation/tests;
- report changed files;
- report tests performed;
- report known limitations;
- do not claim something was tested if it was not.

## Testing policy

- Server/network/combat/persistence/economy logic requires automated tests where technically reasonable.
- Every fixed bug should receive a regression test when possible.
- Persistence operations must test retries, failures and idempotency.
- Inventory/currency/item ownership systems must test duplication invariants.
- Visual/gameplay-feel systems may use manual acceptance testing.
- Never claim a test passed unless it was actually executed.
- A task is not complete when required tests are failing.

## Godot conventions

- Godot 4.x syntax only.
- UTF-8.
- 4 spaces.
- snake_case files/functions/variables.
- PascalCase class names.
- use `_physics_process` for physics movement.
- use Input Map actions, not hard-coded keyboard polling in gameplay scripts.
- avoid autoload singletons unless there is a clear cross-scene lifetime requirement.

## Git

One feature/fix per commit.

Suggested commits:
- `chore(project): bootstrap Godot client`
- `feat(movement): add greybox player controller`
- `feat(camera): add fixed three-quarter follow camera`

Never commit secrets, local DB data, `.godot/`, imported caches or generated binaries.
