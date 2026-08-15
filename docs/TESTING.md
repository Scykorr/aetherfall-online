# Testing

Use Godot 4.7.1 for all project validation.

## Automated server tests

Run the complete deterministic server suite headlessly:

```powershell
godot --headless --path server --script tests/test_runner.gd
```

The command is non-interactive and returns exit code `0` only when every test passes. It covers entity IDs and cleanup, sessions, protocol validation, duplicate handshakes and tick-driven timeout cleanup.

## Continuous integration

GitHub Actions runs the same server suite on every push and pull request using Godot 4.7.1 on `ubuntu-latest`. The workflow is defined in `.github/workflows/server-tests.yml`; a non-zero test runner exit code fails the job.

## Local integration test

Start the zone server:

```powershell
godot --headless --path server
```

Then run two instances of the client project. Both automatically connect to `127.0.0.1:7777`. Verify that their debug HUDs show `READY` with different entity IDs and that server health logs show entity/session counts changing `2 -> 1 -> 0` as the clients close.

Development arguments support isolated tests, including `--network-port=<port>`, `--protocol-version=<version>`, `--duplicate-handshake`, `--malformed-handshake`, `--skip-handshake` and `--shutdown-after=<seconds>`.

## Test categories

- **Automated:** deterministic headless logic tests required for server-critical behavior.
- **Integration:** real server and client processes using ENet.
- **Manual:** visual presentation and gameplay feel.
- **Load/performance:** deferred until representative gameplay and concurrency exist.
