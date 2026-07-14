--!strict

-- Baut die Map beim Serverstart: eine fliegende Hauptinsel mit großem Baum
-- und Spawn-Pads, umgeben von Nebeninseln, die über Holzbrücken mit der
-- Hauptinsel verbunden sind. Klassischer Roblox-Studs-Look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.MapConfig)

local MapBuilder = {}

local COLOR_GRASS = BrickColor.new("Bright green")
local COLOR_EARTH = BrickColor.new("Brown")
local COLOR_EARTH_DEEP = BrickColor.new("Reddish brown")
local COLOR_WOOD = BrickColor.new("Reddish brown")
local COLOR_LEAVES = { BrickColor.new("Bright green"), BrickColor.new("Forest green") }
local COLOR_PAD = BrickColor.new("Medium stone grey")

local LAYER_THICKNESS = 4
local LAYER_SCALES = { 1, 0.8, 0.6, 0.4, 0.2 }

local function makePart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.Parent = parent
	return part
end

-- topCenter = Mittelpunkt der Insel-Oberfläche; darunter verjüngen sich die Schichten
local function buildIsland(parent: Instance, topCenter: Vector3, topSize: number)
	for i, scale in LAYER_SCALES do
		local size = topSize * scale
		local y = topCenter.Y - (i - 0.5) * LAYER_THICKNESS
		local layer = makePart(
			"IslandLayer",
			Vector3.new(size, LAYER_THICKNESS, size),
			CFrame.new(topCenter.X, y, topCenter.Z),
			parent
		)
		layer.BrickColor = if i == 1 then COLOR_GRASS elseif i <= 3 then COLOR_EARTH else COLOR_EARTH_DEEP
	end
end

local function buildTree(parent: Instance, base: Vector3)
	local trunk = makePart("TreeTrunk", Vector3.new(7, 20, 7), CFrame.new(base + Vector3.new(0, 10, 0)), parent)
	trunk.BrickColor = COLOR_WOOD

	-- Krone aus gestapelten, verdrehten Blöcken — klassischer Blocktree
	local canopyLayers = {
		{ size = 34, height = 9, y = 22, rotation = 0 },
		{ size = 25, height = 8, y = 28.5, rotation = 45 },
		{ size = 16, height = 7, y = 34, rotation = 20 },
		{ size = 8, height = 5, y = 38.5, rotation = 45 },
	}
	for i, layer in canopyLayers do
		local canopy = makePart(
			"TreeCanopy",
			Vector3.new(layer.size, layer.height, layer.size),
			CFrame.new(base + Vector3.new(0, layer.y, 0)) * CFrame.Angles(0, math.rad(layer.rotation), 0),
			parent
		)
		canopy.BrickColor = COLOR_LEAVES[(i - 1) % 2 + 1]
	end
end

local function buildBridge(parent: Instance, fromCenter: Vector3, toCenter: Vector3, fromHalf: number, toHalf: number)
	local delta = toCenter - fromCenter
	local dist = delta.Magnitude
	local dir = delta.Unit

	-- 1 Stud Überlappung in beide Inseln, Deck liegt 0.05 über dem Gras (kein Z-Fighting)
	local startPos = fromCenter + dir * (fromHalf - 1)
	local endPos = fromCenter + dir * (dist - toHalf + 1)
	local length = (endPos - startPos).Magnitude
	local mid = (startPos + endPos) / 2
	local cf = CFrame.lookAt(mid, endPos)

	local deck = makePart(
		"BridgeDeck",
		Vector3.new(MapConfig.BridgeWidth, 1, length),
		cf * CFrame.new(0, -0.45, 0),
		parent
	)
	deck.BrickColor = COLOR_WOOD

	for _, side in { -1, 1 } do
		local xOffset = side * (MapConfig.BridgeWidth / 2 - 0.2)

		local rail = makePart(
			"BridgeRail",
			Vector3.new(0.4, 0.4, length),
			cf * CFrame.new(xOffset, 2.4, 0),
			parent
		)
		rail.BrickColor = COLOR_WOOD

		local postCount = math.max(2, math.floor(length / 10) + 1)
		for p = 1, postCount do
			local zOffset = -length / 2 + (p - 1) * (length / (postCount - 1))
			local post = makePart(
				"BridgePost",
				Vector3.new(0.4, 2.6, 0.4),
				cf * CFrame.new(xOffset, 1.3, zOffset),
				parent
			)
			post.BrickColor = COLOR_EARTH
		end
	end
end

-- position = Punkt auf der Insel-Oberfläche
local function buildSpawnPad(padsFolder: Folder, position: Vector3)
	local pad = makePart("SpawnPad", Vector3.new(6, 0.4, 6), CFrame.new(position + Vector3.new(0, 0.2, 0)), padsFolder)
	pad.BrickColor = COLOR_PAD
end

function MapBuilder.build(): (Model, Folder)
	local map = Instance.new("Model")
	map.Name = "Map"

	local pads = Instance.new("Folder")
	pads.Name = "SpawnPads"
	pads.Parent = map

	local mainCenter = Vector3.new(0, MapConfig.TopY, 0)
	buildIsland(map, mainCenter, MapConfig.MainIslandSize)
	buildTree(map, mainCenter)

	-- Spawn-Pads im Kreis um den Baum
	for i = 1, MapConfig.MainSpawnPads do
		local angle = math.rad((i - 1) * (360 / MapConfig.MainSpawnPads))
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * MapConfig.MainSpawnRadius
		buildSpawnPad(pads, mainCenter + offset)
	end

	local mainHalf = MapConfig.MainIslandSize / 2
	local satelliteHalf = MapConfig.SatelliteSize / 2
	for _, angleDeg in MapConfig.SatelliteAngles do
		local angle = math.rad(angleDeg)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local satelliteCenter = mainCenter + dir * MapConfig.SatelliteDistance

		buildIsland(map, satelliteCenter, MapConfig.SatelliteSize)
		buildBridge(map, mainCenter, satelliteCenter, mainHalf, satelliteHalf)

		-- zwei Pads pro Nebeninsel, quer zur Brückenachse versetzt
		local perpendicular = Vector3.new(-dir.Z, 0, dir.X)
		for _, side in { -1, 1 } do
			buildSpawnPad(pads, satelliteCenter + perpendicular * (side * 9))
		end
	end

	map.Parent = workspace
	return map, pads
end

return MapBuilder
