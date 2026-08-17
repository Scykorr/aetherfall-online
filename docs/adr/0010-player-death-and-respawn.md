# ADR-0010: Server-authoritative player death and respawn

Status: Accepted.

## Decision

Player combat lifecycle is server-owned and separate from network sessions. `PlayerHealthSystem` stores `ALIVE`/`DEAD`, HP, death/respawn ticks and the authoritative spawn position for each connected player entity.

Lethal damage through `CombatSystem` transitions HP to zero exactly once, records the server-derived monster killer and death position, stops movement, clears the player's combat target and invalidates monster aggro. Movement, targeting and player attacks independently reject dead entities, so disabling client controls is not a security boundary.

Respawn is scheduled from the fixed server tick using `player_respawn_delay_seconds`. The same session and entity ID are retained. At the scheduled tick, HP is restored, movement is reset at the stored spawn position, target remains empty and reliable lifecycle events plus world snapshots replicate the result.

## Consequences

- Clients cannot choose life state, killer, respawn time or respawn position.
- Disconnect removes the lifecycle state, so no scheduled respawn survives entity/session cleanup.
- No reconnect is required and normal movement/target/combat gates reopen after respawn.
- Corpse behavior, death penalties, resurrection skills, VFX and UI remain out of scope.
