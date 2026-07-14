# roblox-knockback

Roblox-Projekt, verwaltet mit [Rojo](https://rojo.space/) (getestet mit Rojo 7.6.1).

## Setup

1. `rojo serve` im Repo-Root starten — der Server lauscht auf `localhost:34872`.
2. In Roblox Studio ein leeres Place öffnen, das Rojo-Plugin öffnen und auf **Connect** klicken.

Änderungen an den Dateien unter `src/` werden dann live nach Studio synchronisiert.

## Struktur

| Pfad          | Ziel in Roblox                              |
| ------------- | ------------------------------------------- |
| `src/server`  | `ServerScriptService.Server` (Script)       |
| `src/client`  | `StarterPlayerScripts.Client` (LocalScript) |
| `src/shared`  | `ReplicatedStorage.Shared` (ModuleScript)   |

Die Welt (Prelobby-Hallway und Insel-Map) wird zur Laufzeit von Server-Skripten
gebaut (`LobbyBuilder`, `MapBuilder`) — es gibt keine statischen Workspace-Assets.

## Build

Eine Place-Datei ohne Studio-Sync bauen:

```sh
rojo build -o roblox-knockback.rbxl
```

## Luau LSP

`sourcemap.json` wird für Autocomplete/Typen gebraucht und ist nicht eingecheckt:

```sh
rojo sourcemap -o sourcemap.json --watch
```
