# ADR-0007: Server-authoritative basic combat

Status: Accepted.

## Decision

The client sends only a monotonically increasing basic-attack sequence. The zone server derives the attacker from the READY session and uses the authoritative target selected by `TargetingSystem`; client damage, range, position, cooldown, target HP and attacker identity are ignored.

`CombatSystem` validates sequence, PvE target type, authoritative positions, range and tick-based cooldown. It calculates configured damage, mutates monster HP through the server-owned monster system and produces one authoritative combat event. The current broadcast boundary replicates that event to all connected zone clients, while subsequent world snapshots remain the source for persistent presentation state such as the target-frame HP.

Basic attacks are allowed while moving in this prototype and do not create an animation lock. Invalid range and cooldown attempts do not mutate HP; cooldown is consumed only by a successful attack.

TASK-008B temporarily clamps monster HP to 1. Death, despawn, respawn, loot and related state transitions are deferred to TASK-008C.

## Consequences

- Replayed or stale attack sequences cannot deal additional damage.
- Cooldown uses the fixed simulation tick and cannot be advanced by a client clock.
- Multiple player attacks are processed sequentially against one authoritative monster state.
- Future damage formulas can replace the isolated calculation boundary without changing the client trust model.
