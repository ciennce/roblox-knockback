--!strict

-- Geometrie der Prelobby und der Teleport-Vertrag zwischen Client und Server.
-- Alle Maße in Studs; die Lobby liegt hoch und seitlich versetzt, damit sie
-- von der Map aus praktisch unsichtbar ist.

local LobbyConfig = {
	-- Mittelpunkt des Hallway-Bodens (Boden-Oberkante = Origin.Y)
	Origin = Vector3.new(0, 300, -650),

	-- Gang verläuft entlang der Z-Achse
	HallLength = 120,
	HallWidth = 24,
	HallHeight = 16,

	RemoteName = "JoinGameRequest",
}

return LobbyConfig
