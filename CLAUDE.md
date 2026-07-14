# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Roblox game project (knockback mechanics) managed with Rojo. Code lives in `src/` as `.luau`
files on disk and is synced into Roblox Studio's DataModel; Studio is the runtime, not a build target.

## Commands

Rojo 7.6.1 is installed globally. There is no toolchain manager (Rokit/Aftman), no test framework,
and no linter configured — do not invent commands for these.

```sh
rojo serve                          # live-sync server on localhost:34872; connect via the Rojo Studio plugin
rojo build -o roblox-knockback.rbxl # build a place file without Studio
rojo sourcemap -o sourcemap.json    # regenerate types/autocomplete data for Luau LSP (gitignored; --watch to keep fresh)
```

`rojo build` is the fastest way to check that `default.project.json` and any `*.model.json` are
valid — it fails loudly on a malformed tree. It does **not** check Luau code, which is only
validated when Studio actually runs it.

## Architecture

`default.project.json` is the single source of truth for how disk paths map into the Roblox
DataModel. Read it before moving files around — a path that isn't mounted there simply won't exist
in-game.

| Path         | DataModel location                          |
| ------------ | ------------------------------------------- |
| `src/server` | `ServerScriptService.Server` (Script)       |
| `src/client` | `StarterPlayerScripts.Client` (LocalScript) |
| `src/shared` | `ReplicatedStorage.Shared` (ModuleScript)   |

Rojo derives the instance class from the file name suffix, so the suffix is load-bearing:
`*.server.luau` → `Script`, `*.client.luau` → `LocalScript`, plain `*.luau` → `ModuleScript`.
A directory becomes a folder-like instance, and its `init.*` file becomes that instance's own
script rather than a child.

All world geometry (pre-lobby hallway, floating-island map) is built procedurally at server
startup by `LobbyBuilder`/`MapBuilder` from constants in `src/shared/LobbyConfig.luau` and
`MapConfig.luau` — there are no static Workspace assets. The map has no ground below the
islands; `DeathTracker` kills characters below `MapConfig.KillY`.

Combat/progression flow: `WeaponConfig` (shared) defines shotgun variants (knockback,
reload, unlock cost); `ShotgunFactory` builds the blocky Tools procedurally and clones the
fire LocalScript from `ReplicatedStorage.Shared.ShotgunClient` into each one. `CombatService`
simulates pellets server-side by stepping visual parts with raycasts each Heartbeat (physics
projectiles would tunnel at pellet speed) and records the last attacker per victim;
`DeathTracker` consumes that record on death to award a Knockbacks point. `PlayerData` owns
leaderstats and DataStore persistence (deaths, knockbacks, owned/equipped weapons — requires
Studio API access for testing). Unlock costs are thresholds on total Knockbacks, not spent
currency. `WeaponService` decorates the lobby pedestals with displays/prompts and re-gives
the equipped Tool on every `CharacterAdded`.

Server and client are separate entry points that share code through
`require(ReplicatedStorage.Shared)`. Anything both sides need (constants, knockback math, remote
names) belongs in `src/shared`, since only that folder replicates to clients.

## Working with the live sync

While `rojo serve` runs, edits under `src/` reach Studio automatically. Edits to
`default.project.json` do **not** — that file is read once at startup, so restart the server after
changing the tree. Changes made inside Studio never flow back to disk; disk is authoritative and
Studio edits to synced instances get overwritten.
