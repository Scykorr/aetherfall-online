# ADR-0003: ENet client/zone-server handshake

Status: Accepted.

## Decision

Use Godot's built-in `ENetMultiplayerPeer` for the first direct client-to-zone-server connection. Transport connection and successful game handshake are separate states.

The client sends only protocol version during this handshake. The zone server validates version 1, creates the player entity through its authoritative `EntityRegistry`, and returns the server-assigned entity ID. A dedicated session registry maps the real ENet peer ID to that entity.

## Rationale

ENet is available in Godot 4.7.1 without an additional dependency and is sufficient for local development of the initial authoritative protocol. Separating transport from game readiness prevents a connected peer from becoming a gameplay participant before validation completes.

## Consequences

- Clients cannot choose runtime entity IDs.
- Protocol mismatch and malformed or duplicate handshakes are rejected.
- Pending sessions expire after a configurable timeout.
- Authentication, encryption, persistence and gameplay replication remain future work.
