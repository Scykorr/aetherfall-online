# ADR-0005: Server-owned world entities

Status: Accepted.

## Decision

Players and monsters share the authoritative `EntityRegistry` ID namespace. Monster metadata is registered with `entity_type = monster`; runtime HP, position, velocity and AI state are owned by `MonsterSystem` and simulated on the fixed server tick.

World snapshots use a small generic entity envelope (`entity_id`, `entity_type`, position and velocity) with type-specific player or monster state. Late joiners receive the same existing world entities through the current full snapshot boundary. Client scenes are presentation only.

Player session cleanup removes only the player entity linked to that session. Server-owned world entities have no player session ownership and survive player disconnects.

## Consequences

- A client cannot move or mutate a monster through player movement intents.
- Monster spawn/despawn is reflected by appearance or absence in authoritative snapshots.
- The initial snapshot broadcasts all test-zone entities; future interest management can filter at this replication boundary without changing entity authority.
