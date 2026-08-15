# ADR-0008: Server-authoritative monster death and respawn

Status: Accepted.

## Decision

Monster runtime state explicitly transitions between `ALIVE` and `DEAD`. Only the zone server applies damage, attributes the killer and creates the single death transition when HP reaches zero. Death clears all authoritative player target references, stops AI movement and makes the replicated client placeholder non-targetable.

Respawn delay is monster-template data converted to fixed simulation ticks when death occurs. At the scheduled tick, the server reuses the existing runtime entity ID, restores full HP and resets position, velocity and AI state at the original spawn point. Clients receive reliable lifecycle events for immediate feedback and full world snapshots as the durable presentation state.

## Consequences

- Client clocks, damage claims and respawn requests cannot advance lifecycle state.
- Reusing the entity ID avoids a despawn/spawn identity race in the first zone prototype.
- Respawn does not restore prior player targets; a player must explicitly select the living monster again.
- Loot, XP, persistence, corpse duration, animations and monster attacks remain separate systems.
