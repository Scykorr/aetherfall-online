# Testing

Use Godot 4.7.1 for all project validation.

Godot must be able to read and write its normal `%APPDATA%\Godot` and `%LOCALAPPDATA%\Godot` directories. A restricted Windows sandbox that denies both paths may crash during headless startup before loading the project; run validation in a normal developer shell in that case.

## Automated server tests

Run the complete deterministic server suite headlessly:

```powershell
godot --headless --path server --script tests/test_runner.gd
```

Run client snapshot ordering tests:

```powershell
godot --headless --path client --script tests/network_snapshot_test.gd
```

Both commands are non-interactive and return exit code `0` only when every test passes. They cover entity/session cleanup, protocol validation, authoritative movement, ownership, malformed vectors, anti-teleport behavior, deterministic monster aggro/chase/attack/leash/return, monster HP/ownership/lifecycle, authoritative player HP, targeting security, combat range/cooldown/replay/security and snapshot ordering/despawn/death/respawn.

## Continuous integration

GitHub Actions runs both suites on every push and pull request using Godot 4.7.1 on `ubuntu-latest`. The workflow is defined in `.github/workflows/server-tests.yml`; a non-zero test runner exit code fails the job.

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

TASK-007 monster despawn can be exercised with the server argument `--despawn-monster-after=<seconds>`. The default is disabled.

TASK-008A manual acceptance uses two clients. Verify that LMB on the monster selects it without movement, shows its ring and server-replicated HP frame, while the other client remains untargeted. Verify ground click, hold-LMB, RMB orbit and wheel zoom independently. Press Escape to clear the confirmed target. Repeat with `--despawn-monster-after=<seconds>` and confirm the ring/frame disappear after server despawn.

For repeatable headless targeting transport checks, one client may use `--target-test=first-monster`. The hook requests the first replicated monster once and logs authoritative target confirmation; it is disabled by default.

TASK-008B uses the `basic_attack` Input Map action (`Space`). Basic attacks are allowed while moving. Headless combat transport modes are `--combat-test=single`, `--combat-test=cooldown` and `--combat-test=out-of-range`; they select the first monster and exercise only their named scenario. All hooks are disabled by default. Combat events are authoritative; TASK-008C replaced TASK-008B's historical HP floor with the lifecycle described below.

TASK-008C removes the temporary HP floor. Training Wisp death and respawn use authoritative server ticks and a delay from its shared template. The server retains the same runtime entity ID, clears all player targets on death and emits reliable `DIED`/`RESPAWNED` lifecycle events. Use `--combat-test=lifecycle` on one headless client to chase and defeat the monster, observe respawn, explicitly retarget it and attack again; run a second ordinary client to verify it receives identical lifecycle events. This development hook is disabled by default.

TASK-009 makes Training Wisp AI server-authoritative. `--ai-test=observe` logs replicated AI state/aggro transitions and authoritative local player HP without changing gameplay. Combine it with `--movement-test=leash` to move a test player outside the leash and observe `CHASE -> RETURN -> IDLE`. The existing `--combat-test=lifecycle` scenario also validates that death interrupts monster combat and respawn restores clean AI. Run a second `--ai-test=observe` client to compare the same combat events and AI states. Player HP is temporarily clamped to `1`; player death belongs to TASK-010. All hooks are disabled by default.

## Test categories

- **Automated:** deterministic headless logic tests required for server-critical behavior.
- **Integration:** real server and client processes using ENet.
- **Manual:** visual presentation and gameplay feel.
- **Load/performance:** deferred until representative gameplay and concurrency exist.
