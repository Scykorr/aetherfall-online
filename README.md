# Aetherfall Online

Original stylized 3/4-view MMORPG prototype inspired by the strengths of classic MMORPGs, without copying Royal Quest assets, world, names, maps, UI, code, text or proprietary data.

## Milestone 0.1

The first playable milestone proves:

- Godot client boots into a 3D test world.
- Fixed 3/4 camera follows the player.
- WASD movement works in the local greybox.
- Project structure is ready for a server-authoritative zone server.
- Docker Compose starts PostgreSQL + Nakama for account/persistence work.
- Codex follows `AGENTS.md` and works one small task at a time.

## Repository layout

- `client/` — Godot game client.
- `server/` — future headless Godot authoritative zone server.
- `backend/` — Nakama + PostgreSQL local stack.
- `shared/` — data definitions shared conceptually between client/server.
- `docs/` — architecture, product rules and Codex task backlog.
- `tests/` — integration/load tests as they appear.
- `tools/` — content validation and developer utilities.

## Start

1. Install Godot 4.x, Git and Docker Desktop/Podman.
2. Open `client/project.godot` in Godot.
3. Run the project.
4. Use WASD to move the capsule.
5. Start backend with `docker compose -f backend/docker-compose.yml up -d`.

Read `AGENTS.md` before using Codex. See [`docs/TESTING.md`](docs/TESTING.md) for automated and local integration test commands.

## Local multiplayer on Windows

Set the path to Godot 4.7.1 once in the current PowerShell session, then start one headless server and two independent clients:

```powershell
cd D:\aetherfall_online

$env:GODOT_BIN = "C:\Users\Tony Fedos\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"

.\tools\run_local_multiplayer.ps1
```

If `godot` is already available in `PATH`, the `GODOT_BIN` line is not required. Separate server/client commands, custom ports and automated test commands are documented in [`docs/TESTING.md`](docs/TESTING.md).
