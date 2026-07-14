--!strict

-- Layout der Map: fliegende Hauptinsel mit Baum, Satelliteninseln mit Brücken.
-- Alle Maße in Studs.

local MapConfig = {
	-- Y-Höhe der Insel-Oberflächen (Lobby liegt weit darüber und daneben)
	TopY = 100,

	-- Fällt ein Charakter unter diese Höhe, zählt das als Tod (Respawn in der Lobby)
	KillY = 40,

	-- Hauptinsel (quadratisch, Kantenlänge der obersten Schicht)
	MainIslandSize = 72,

	-- Nebeninseln, per Brücke mit der Hauptinsel verbunden
	SatelliteSize = 36,
	SatelliteDistance = 110,
	SatelliteAngles = { 30, 150, 270 }, -- Grad, um die Hauptinsel verteilt

	-- Spawn-Pads (Teleport-Ziele für "Join Game")
	MainSpawnPads = 6,
	MainSpawnRadius = 26,

	BridgeWidth = 6,
}

return MapConfig
