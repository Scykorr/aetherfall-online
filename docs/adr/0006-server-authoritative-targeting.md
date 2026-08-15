# ADR-0006: Server-authoritative entity targeting

Status: Accepted.

## Decision

The client detects a targetable presentation entity with a camera ray and sends only its candidate server entity ID. The zone server derives the player from the READY session and validates entity existence, allowed type and the independently configured target-selection range before storing the player's authoritative current target.

Target selection range is not attack range. TASK-008A permits monsters only; future entity types can be added explicitly without trusting client ownership or presentation metadata.

Confirmed target IDs replicate in player snapshot state. Selection rings and the prototype target frame follow that confirmed state and replicated monster HP. They are presentation only and never optimistically establish authority.

The current zone server owns a single zone-local `EntityRegistry`, so every candidate resolved from that registry is in the same zone by construction. Cross-zone targeting will require an explicit zone identity if entity registries are later shared.

## Consequences

- UI receives pointer input before targeting, and targetable entity detection precedes the existing ground movement ray.
- Invalid, self, disallowed, out-of-range and foreign-player mutations are rejected server-side.
- Player disconnect, zone reset and target despawn clear authoritative target state.
- Combat remains a separate future system and must revalidate attack-specific range and state.
