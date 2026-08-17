# Testing

Use Godot 4.7.1 for all project validation.

Godot must be able to read and write its normal `%APPDATA%\Godot` and `%LOCALAPPDATA%\Godot` directories. A restricted Windows sandbox that denies both paths may crash during headless startup before loading the project; run validation in a normal developer shell in that case.

## Automated server tests

Run the complete deterministic server suite headlessly:

```powershell
godot --headless --path server --script tests/test_runner.gd
```

Run the server navigation regression suite (it owns a temporary Godot navigation world and waits for the required physics synchronization):

```powershell
godot --headless --path server --script tests/navigation_movement_test.gd
```

Run client snapshot ordering tests:

```powershell
godot --headless --path client --script tests/network_snapshot_test.gd
```

All commands are non-interactive and return exit code `0` only when every test passes. They cover entity/session cleanup, protocol validation, authoritative movement and pathfinding, ownership, malformed vectors, anti-teleport behavior, deterministic monster/player lifecycle, authoritative HP, targeting/combat security, XP progression, deterministic loot generation, atomic pickup, inventory slot/stack invariants, mutation replay protection, lifecycle ownership and snapshot/revision ordering.

## Continuous integration

GitHub Actions runs the server logic, server navigation and client snapshot suites on every push and pull request using Godot 4.7.1 on `ubuntu-latest`. The workflow is defined in `.github/workflows/server-tests.yml`; a non-zero test runner exit code fails the job.

## Local integration test

For the standard Windows multiplayer workflow, set `GODOT_BIN` to the Godot executable (or make `godot` available in `PATH`) and run:

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.7.1-stable_win64.exe"
.\tools\run_local_multiplayer.ps1
```

The launcher starts a headless server, waits two seconds, and opens two independent clients on `127.0.0.1:7777`. Close both client windows (or press `Ctrl+C` in the launcher terminal) to stop the server started by the script. Use an isolated port when needed:

```powershell
.\tools\run_local_multiplayer.ps1 -Port 7840
```

The same discovery rules and port option are available for separate terminals:

```powershell
.\tools\run_server.ps1 -Port 7777
.\tools\run_client.ps1 -HostAddress 127.0.0.1 -Port 7777
```

If local PowerShell policy blocks repository scripts, invoke them with `powershell -ExecutionPolicy Bypass -File .\tools\run_local_multiplayer.ps1`.

Start the zone server:

```powershell
godot --headless --path server
```

Then run two instances of the client project. Both automatically connect to `127.0.0.1:7777`. Verify that their debug HUDs show `READY` with different entity IDs and that server health logs show entity/session counts changing `2 -> 1 -> 0` as the clients close.

Development arguments support isolated tests, including `--network-port=<port>`, `--protocol-version=<version>`, `--duplicate-handshake`, `--malformed-handshake`, `--skip-handshake` and `--shutdown-after=<seconds>`.

TASK-006 headless integration clients may additionally use `--movement-test=move_to_point` or `--movement-test=follow_cursor`. These hooks are disabled by default and exist only for repeatable local acceptance testing.

FIX-MOVE-001 moves `MOVE_TO_POINT` path ownership to the server. The server projects a requested destination only within its configured snap distance, computes a path on the zone navigation map and advances through authoritative waypoints. `FOLLOW_CURSOR` remains direct server steering. Automated tests cover straight paths, static-obstacle detours, destination replacement, obstacle/unreachable rejection, ignored client path data and direct follow behavior. For a real transport check, run client A with `--movement-test=navigation_obstacle` and client B with any non-empty observer value such as `--movement-test=observe`; both print periodic authoritative snapshot positions while A routes behind the central obstacle. These hooks are disabled by default.

TASK-007 monster despawn can be exercised with the server argument `--despawn-monster-after=<seconds>`. The default is disabled.

TASK-008A manual acceptance uses two clients. Verify that LMB on the monster selects it without movement, shows its ring and server-replicated HP frame, while the other client remains untargeted. Verify ground click, hold-LMB, RMB orbit and wheel zoom independently. Press Escape to clear the confirmed target. Repeat with `--despawn-monster-after=<seconds>` and confirm the ring/frame disappear after server despawn.

For repeatable headless targeting transport checks, one client may use `--target-test=first-monster`. The hook requests the first replicated monster once and logs authoritative target confirmation; it is disabled by default.

TASK-008B uses the `basic_attack` Input Map action (`Space`). Basic attacks are allowed while moving. Headless combat transport modes are `--combat-test=single`, `--combat-test=cooldown` and `--combat-test=out-of-range`; they select the first monster and exercise only their named scenario. All hooks are disabled by default. Combat events are authoritative; TASK-008C replaced TASK-008B's historical HP floor with the lifecycle described below.

TASK-008C removes the temporary HP floor. Training Wisp death and respawn use authoritative server ticks and a delay from its shared template. The server retains the same runtime entity ID, clears all player targets on death and emits reliable `DIED`/`RESPAWNED` lifecycle events. Use `--combat-test=lifecycle` on one headless client to chase and defeat the monster, observe respawn, explicitly retarget it and attack again; run a second ordinary client to verify it receives identical lifecycle events. This development hook is disabled by default.

TASK-009 makes Training Wisp AI server-authoritative. `--ai-test=observe` logs replicated AI state/aggro transitions and authoritative local player HP without changing gameplay. Combine it with `--movement-test=leash` to move a test player outside the leash and observe `CHASE -> RETURN -> IDLE`. The existing `--combat-test=lifecycle` scenario also validates that death interrupts monster combat and respawn restores clean AI. Run a second `--ai-test=observe` client to compare the same combat events and AI states. Player HP is temporarily clamped to `1`; player death belongs to TASK-010. All hooks are disabled by default.

TASK-010 removes TASK-009's temporary player HP floor. Player death and respawn use authoritative lifecycle state and fixed server ticks. `--player-lifecycle-test` lets the monster kill the local test player; after the replicated respawn it requests movement, selects the monster and attacks without reconnecting. Combine it with `--ai-test=observe` on both clients to compare player `ALIVE`/`DEAD` snapshots, HP, positions and lifecycle events. This development hook is disabled by default.

FIX-PLAY-001 retarget validation can use victim A with `--combat-test=partial --ai-test=observe` and survivor B with `--combat-test=survivor --ai-test=observe`. A stops after five attacks; after A dies, B attacks only once it becomes the authoritative aggro target. AI observation logs state, aggro entity and monster HP. For the no-replacement boundary, run B with `--movement-test=leash --ai-test=observe`; after A dies, verify `RETURN` retains damaged HP and `IDLE` at spawn restores full HP. These development hooks are disabled by default.

TASK-011 adds authoritative XP and world loot. Press `E` (`interact`) to request pickup of a replicated loot entity; the client sends only its entity ID. For repeatable integration, start the server with `--loot-test-mode`, run killer A with `--combat-test=lifecycle --loot-test=owner`, and observer B with `--loot-test=unauthorized`. B requests first and must be rejected; A then picks up the same loot, after which both clients observe despawn.

TASK-012 replaces the temporary ledger with a server-authoritative, configurable 24-slot inventory. Press `I` (`toggle_inventory`) to open it. Click a non-empty source then a destination to move, merge or swap. Hold Shift while clicking an empty destination to split half the selected stack. Select a stack and use the explicit **Destroy selected stack** button to remove it. The server calculates every resulting item ID and quantity; the client applies only increasing inventory revisions. Inventory is runtime-only: death/respawn preserves it, disconnect removes it, and persistence is intentionally absent.

For repeatable transport validation, start the server with `--loot-test-mode`, run killer A with `--combat-test=lifecycle --loot-test=owner --inventory-test=owner`, and observer B with `--loot-test=unauthorized`. Test mode makes the guaranteed first loot stack quantity four. A logs authoritative pickup, MOVE, SPLIT, MERGE and final `Inventory integration PASS`; B's foreign pickup remains rejected. All hooks are disabled by default.

To validate the full-inventory boundary over ENet, also start the server with `--inventory-full-test-mode` and run A with `--inventory-test=full`. The server fills each test inventory to valid `max_stack` limits before sending its initial state. A must log `INVENTORY_FULL` followed by `Full inventory integration PASS loot remains=...` from a later world snapshot.

## Test categories

- **Automated:** deterministic headless logic tests required for server-critical behavior.
- **Integration:** real server and client processes using ENet.
- **Manual:** visual presentation and gameplay feel.
- **Load/performance:** deferred until representative gameplay and concurrency exist.
