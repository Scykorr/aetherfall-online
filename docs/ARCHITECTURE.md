# Architecture

## Target architecture

```text
Godot Client
   | input intents / snapshots
   v
Godot Headless Zone Server
   | persistence/social API
   v
Nakama OSS
   |
PostgreSQL
```

Milestone 0.1 intentionally has local client movement to validate camera/feel. It is disposable: once networking begins, authoritative movement moves to the zone server.

## Responsibilities

### Client
Rendering, UI, input sampling, camera, animation, interpolation/prediction.

### Zone server
Movement validation, combat, mobs, aggro, cooldowns, drops, visibility/interest management.

### Nakama/backend
Authentication, character metadata, social services and persistent APIs.

### PostgreSQL
Durable authoritative records.

## Networking direction

Start with one zone process and 20–50 players. Do not design Kubernetes/sharding before a measured need exists.

## Combat invariant

```text
client: "use skill X against entity Y"
server: validate -> calculate -> mutate -> broadcast
```

Never:
```text
client: "I dealt 427 damage"
```

## Data-driven gameplay

Skills/items/monsters live under `shared/data`. Scripts consume IDs and definitions. Display strings will later live in localization files.

## First vertical slice

Town greybox -> field -> one monster -> targeting -> attack -> loot -> inventory -> persistence -> party -> dungeon.
