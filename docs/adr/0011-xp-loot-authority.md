# ADR-0011: Server-authoritative XP and loot foundation

Status: Accepted.

## Decision

Monster death rewards originate only from the single authoritative `DIED` lifecycle event. `PlayerProgressionSystem` owns level/current XP and a deterministic level curve. A death key prevents duplicate event processing from granting XP or rolling loot twice.

`LootSystem` uses server-seeded RNG and data-driven item/loot definitions. Successful rolls register lightweight `loot` entities in the shared entity ID namespace at the authoritative death position. Loot belongs exclusively to the killer and remains independent of monster respawn; owner death or disconnect does not transfer or remove it before its tick-based timeout.

Clients send only a loot entity ID. The server derives the player from the READY session and validates life state, ownership, existence, range, item definition and quantity. Pickup removes the world loot exactly once and grants a temporary server-owned `acquired_items` RewardLedger entry. Full inventory integration is deferred to TASK-012.

## Consequences

- Clients cannot choose XP, item, quantity, position or ownership.
- Replayed/concurrent pickup intents cannot duplicate rewards.
- Existing full snapshots replicate loot spawn, late join state and despawn.
- Full prototype snapshots use reliable delivery now that progression and loot can exceed one unreliable ENet MTU; splitting replication channels is deferred until measured load work.
- The placeholder world representation has no final art, icon, beam or animation.
