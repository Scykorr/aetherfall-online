# ADR-0004: Server-authoritative player movement

Status: Accepted.

## Decision

Clients send sequenced movement intents (`MOVE_TO_POINT`, `FOLLOW_CURSOR`, `STOP`), never authoritative position, speed or entity ownership. The zone server derives the controlled entity from the READY session, validates each intent and simulates movement on the fixed 30 Hz server tick.

The initial server movement system uses direct horizontal steering at a server-configured speed. It emits full player movement snapshots at 10 Hz. Snapshots include server tick, entity ID, position, velocity, movement mode and acknowledged input sequence.

Clients ignore out-of-order snapshots. Local and remote placeholder representations smooth toward authoritative snapshot positions; this interpolation is presentation only and never becomes authority. FOLLOW_CURSOR intents are limited to 20 Hz client-side, with immediate sends for start, meaningful direction changes and STOP.

## Consequences

- Client-provided entity IDs, positions and speeds cannot control authoritative state.
- New clients discover existing players through full snapshots; missing entities are despawned.
- Sequence numbers reject stale movement commands.
- Server-side NavMesh/pathfinding and obstacle-aware movement remain future work. `MOVE_TO_POINT` currently follows a validated finite destination directly at the configured speed.
- Prediction/reconciliation may be added later without changing server authority.
