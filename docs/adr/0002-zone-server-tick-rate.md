# ADR-0002: Zone server simulation tick rate

Status: Accepted.

## Decision

Use a fixed 30 Hz authoritative simulation tick for the initial Godot zone server.

The zone configuration owns the selected tick rate, and `SimulationClock` applies it to Godot's dedicated physics tick. Gameplay systems consume a fixed simulation delta and monotonic server tick rather than render frames or wall-clock timestamps.

## Rationale

A 30 Hz tick provides a 33.33 ms simulation step. This is responsive enough for the first movement and combat prototypes while leaving more per-tick CPU budget than higher rates for the initial target of 20–50 players in one zone process.

## Consequences

- Authoritative systems must update from the server simulation tick.
- Rendering FPS cannot change gameplay simulation speed.
- Tick health is measured against a 33.33 ms budget.
- The rate is a baseline, not a permanent constraint. It may change after profiling movement quality, combat responsiveness and server load.
