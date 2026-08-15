# ADR-0009: Server-authoritative monster aggro and combat

Status: Accepted.

## Decision

`MonsterSystem` owns a deterministic tick-driven state machine with `IDLE`, `WANDER`, `CHASE`, `ATTACK`, `RETURN` and `DEAD`. Living monsters periodically choose the nearest authoritative player inside template-defined aggro range. Entity ID breaks equal-distance ties. The chosen target remains sticky until it disconnects, becomes invalid, the monster dies or leash rules clear it.

Chase uses authoritative player positions from the existing movement system. Attack decisions flow through `CombatSystem`, which revalidates attacker state, target, range and tick cooldown before mutating the new server-owned `PlayerHealthSystem` and producing the common combat result event. Clients receive AI state, combat events and HP snapshots only.

Leash distance is measured from the monster's spawn point. Exceeding it clears aggro and enters `RETURN`; the monster ignores new aggro while returning, restores full HP at spawn and resumes `IDLE`. Death always overrides combat state, clears aggro and stops movement. Respawn restores the existing runtime entity ID with empty aggro and initial AI state.

## Consequences

- AI/combat values live in the monster template rather than scripts.
- Aggro scans use owned player collections at a configurable tick interval; spatial partitioning is deferred.
- Player HP is authoritative but temporarily clamped to `1`; player death and respawn are deferred to TASK-010.
- Threat tables, assists, monster skills and visual/audio feedback remain out of scope.
