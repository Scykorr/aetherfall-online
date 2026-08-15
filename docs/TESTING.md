# Testing

Use Godot 4.7.1 for all project validation.

## Automated server tests

Run the complete deterministic server suite headlessly:

```powershell
godot --headless --path server --script tests/test_runner.gd
```

Run client snapshot ordering tests:

```powershell
godot --headless --path client --script tests/network_snapshot_test.gd
```

Both commands are non-interactive and return exit code `0` only when every test passes. They cover entity/session cleanup, protocol validation, authoritative movement, ownership, malformed vectors, anti-teleport behavior, deterministic monster AI, monster HP/ownership and snapshot ordering/despawn.

## Continuous integration

GitHub Actions runs both suites on every push and pull request using Godot 4.7.1 on `ubuntu-latest`. The workflow is defined in `.github/workflows/server-tests.yml`; a non-zero test runner exit code fails the job.

## Local integration test

Start the zone server:

```powershell
godot --headless --path server
```

Then run two instances of the client project. Both automatically connect to `127.0.0.1:7777`. Verify that their debug HUDs show `READY` with different entity IDs and that server health logs show entity/session counts changing `2 -> 1 -> 0` as the clients close.

Development arguments support isolated tests, including `--network-port=<port>`, `--protocol-version=<version>`, `--duplicate-handshake`, `--malformed-handshake`, `--skip-handshake` and `--shutdown-after=<seconds>`.

TASK-006 headless integration clients may additionally use `--movement-test=move_to_point` or `--movement-test=follow_cursor`. These hooks are disabled by default and exist only for repeatable local acceptance testing.

TASK-007 monster despawn can be exercised with the server argument `--despawn-monster-after=<seconds>`. The default is disabled.

## Test categories

- **Automated:** deterministic headless logic tests required for server-critical behavior.
- **Integration:** real server and client processes using ENet.
- **Manual:** visual presentation and gameplay feel.
- **Load/performance:** deferred until representative gameplay and concurrency exist.
