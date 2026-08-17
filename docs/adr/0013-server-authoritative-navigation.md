# ADR 0013: Server-authoritative click navigation

## Status

Accepted.

## Context

The client already used a `NavigationAgent3D` for local click presentation, but the network server stored only a destination and steered toward it directly. The collision safety map prevented penetration, yet it could only stop or slide a player at a static obstacle; it could not choose a route around one. Accepting a client-calculated path would also violate the server-authoritative movement boundary.

## Decision

The zone server owns a `NavigationRegion3D` built from the original greybox navigation mesh. On each valid `MOVE_TO_POINT` intent it:

1. projects the requested destination to the server navigation map;
2. rejects projection beyond the configured snap distance;
3. calculates an optimized server-side path;
4. stores and follows the resulting waypoints at the fixed simulation tick rate.

A later `MOVE_TO_POINT` replaces the stored path. Any path field supplied by a client is ignored. The existing analytic collision map remains a final movement safety boundary. `FOLLOW_CURSOR` deliberately keeps its direct, server-authoritative steering behavior.

The server waits for Godot's navigation-map physics synchronization before opening the network listener. Paths are calculated only when a click intent arrives, not on every simulation tick.

## Consequences

- Networked click movement can route around the static greybox obstacles without trusting client navigation data.
- Click path calculation cost is proportional to click intent frequency rather than player tick frequency.
- The client and server projects each contain their own copy of the same original navigation mesh resource because Godot project resource paths cannot cross project roots. Changes to greybox walkability must update and validate both copies.
- Dynamic agent avoidance, crowd simulation and monster pathfinding remain separate future work.
