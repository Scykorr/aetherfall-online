# ADR-0012: Server-authoritative inventory foundation

Status: Accepted.

## Decision

Each READY player entity owns one runtime `InventorySystem` state with a configurable slot count (24 by default), authoritative slots and a monotonically increasing revision. A slot is empty or contains only an item definition ID and positive quantity no greater than that definition's `max_stack`.

Pickup is all-or-nothing. The server deterministically plans insertion into existing partial stacks and then empty slots. Only after the complete quantity fits does it commit the slots, increment revision and remove the world loot. A full inventory therefore leaves loot unchanged in the world.

Clients send sequenced MOVE, SPLIT or DESTROY intents containing slot indices and, where required, a requested split/destroy amount. They never send resulting stacks. The server derives inventory ownership from the READY session, rejects stale/replayed sequences, validates invariants and sends a full authoritative inventory state after READY and every successful mutation. The client ignores states whose revision is not newer. MOVE swaps different items and merges identical items up to `max_stack`; SPLIT targets an empty slot; destruction requires an explicit action.

## Consequences

- Player death and respawn do not alter inventory.
- Disconnect removes the runtime inventory; persistence/database integration is intentionally deferred.
- Equipment, currency, trading, banks, crafting, consumable use and final UI art remain out of scope.
- Full snapshots favor prototype correctness over bandwidth optimization; slot deltas can be introduced later without changing authority.
