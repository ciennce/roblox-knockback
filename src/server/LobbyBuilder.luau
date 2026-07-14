--!strict

-- Baut die Prelobby beim Serverstart: ein Altbau-Gang im klassischen
-- Roblox-Studs-Look — Parkettboden, hohe Sprossenfenster mit echten
-- Wandöffnungen, Sockel- und Stuckleisten, Pendelleuchten — plus
-- Waffen-Placeholder auf den Wandpfeilern zwischen den Fenstern.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)

local LobbyBuilder = {}

-- Fensterraster entlang der Z-Achse (Mittelpunkte der Öffnungen)
local WINDOW_CENTERS = { -50, -30, -10, 10, 30, 50 }
local WINDOW_WIDTH = 8
local SILL_Y = 3.5 -- Unterkante Glas
local TOP_Y = 11 -- Oberkante Glas

-- Waffen-Slots sitzen auf den Wandpfeilern zwischen den Fenstern
local SLOT_CENTERS = { -40, -20, 0, 20, 40 }

local COLOR_WALL = BrickColor.new("Brick yellow")
local COLOR_TRIM = BrickColor.new("White")
local COLOR_WOOD = BrickColor.new("Reddish brown")
local COLOR_WOOD_LIGHT = BrickColor.new("Brown")
local COLOR_CEILING = BrickColor.new("Institutional white")
local COLOR_GLASS = BrickColor.new("Light blue")
local COLOR_ACCENT = BrickColor.new("Toothpaste")

local function makePart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	-- klassischer Roblox-Look: Plastik, Studs oben, Inlets unten
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.Parent = parent
	return part
end

local function buildFloorAndCeiling(root: Model)
	local origin = LobbyConfig.Origin
	local length = LobbyConfig.HallLength
	local width = LobbyConfig.HallWidth
	local height = LobbyConfig.HallHeight

	-- Parkett: schmale Dielen in zwei abwechselnden Brauntönen
	local plankWidth = 2
	local plankCount = width / plankWidth
	for i = 1, plankCount do
		local x = -width / 2 + (i - 0.5) * plankWidth
		local plank = makePart(
			"FloorPlank",
			Vector3.new(plankWidth, 1, length),
			CFrame.new(origin + Vector3.new(x, -0.5, 0)),
			root
		)
		plank.BrickColor = if i % 2 == 0 then COLOR_WOOD else COLOR_WOOD_LIGHT
	end

	local ceiling = makePart(
		"Ceiling",
		Vector3.new(width + 2, 1, length),
		CFrame.new(origin + Vector3.new(0, height + 0.5, 0)),
		root
	)
	ceiling.BrickColor = COLOR_CEILING
end

local function buildWallSegment(root: Model, wallX: number, fromZ: number, toZ: number)
	local len = toZ - fromZ
	if len <= 0 then
		return
	end
	local origin = LobbyConfig.Origin
	local height = LobbyConfig.HallHeight
	local segment = makePart(
		"Wall",
		Vector3.new(1, height, len),
		CFrame.new(origin + Vector3.new(wallX, height / 2, (fromZ + toZ) / 2)),
		root
	)
	segment.BrickColor = COLOR_WALL
end

local function buildWindow(root: Model, wallX: number, centerZ: number)
	local origin = LobbyConfig.Origin
	local height = LobbyConfig.HallHeight
	local glassHeight = TOP_Y - SILL_Y
	local glassMidY = (SILL_Y + TOP_Y) / 2

	-- Wandstücke unter und über der Öffnung
	local below = makePart(
		"WindowWallBelow",
		Vector3.new(1, SILL_Y, WINDOW_WIDTH),
		CFrame.new(origin + Vector3.new(wallX, SILL_Y / 2, centerZ)),
		root
	)
	below.BrickColor = COLOR_WALL

	local headerHeight = height - TOP_Y
	local above = makePart(
		"WindowWallAbove",
		Vector3.new(1, headerHeight, WINDOW_WIDTH),
		CFrame.new(origin + Vector3.new(wallX, TOP_Y + headerHeight / 2, centerZ)),
		root
	)
	above.BrickColor = COLOR_WALL

	local glass = makePart(
		"WindowGlass",
		Vector3.new(0.4, glassHeight, WINDOW_WIDTH),
		CFrame.new(origin + Vector3.new(wallX, glassMidY, centerZ)),
		root
	)
	glass.BrickColor = COLOR_GLASS
	glass.Transparency = 0.45
	glass.Reflectance = 0.15
	glass.TopSurface = Enum.SurfaceType.Smooth
	glass.BottomSurface = Enum.SurfaceType.Smooth

	-- weißer Rahmen: zwei senkrechte Leisten, Fensterbank und Sturz
	for _, zSide in { -1, 1 } do
		local vertical = makePart(
			"WindowFrame",
			Vector3.new(1.3, glassHeight + 1.2, 0.7),
			CFrame.new(origin + Vector3.new(wallX, glassMidY, centerZ + zSide * (WINDOW_WIDTH / 2 + 0.35))),
			root
		)
		vertical.BrickColor = COLOR_TRIM
	end

	local sillBoard = makePart(
		"WindowSill",
		Vector3.new(1.6, 0.6, WINDOW_WIDTH + 2.4),
		CFrame.new(origin + Vector3.new(wallX, SILL_Y - 0.3, centerZ)),
		root
	)
	sillBoard.BrickColor = COLOR_TRIM

	local topBoard = makePart(
		"WindowLintel",
		Vector3.new(1.3, 0.6, WINDOW_WIDTH + 2.4),
		CFrame.new(origin + Vector3.new(wallX, TOP_Y + 0.3, centerZ)),
		root
	)
	topBoard.BrickColor = COLOR_TRIM

	-- Sprossenkreuz
	local muntinV = makePart(
		"WindowMuntin",
		Vector3.new(0.5, glassHeight, 0.35),
		CFrame.new(origin + Vector3.new(wallX, glassMidY, centerZ)),
		root
	)
	muntinV.BrickColor = COLOR_TRIM

	local muntinH = makePart(
		"WindowMuntin",
		Vector3.new(0.5, 0.35, WINDOW_WIDTH),
		CFrame.new(origin + Vector3.new(wallX, glassMidY, centerZ)),
		root
	)
	muntinH.BrickColor = COLOR_TRIM
end

local function buildSideWalls(root: Model)
	local length = LobbyConfig.HallLength

	for _, side in { -1, 1 } do
		local wallX = side * (LobbyConfig.HallWidth / 2 + 0.5)

		-- Wandpfeiler zwischen den Fensteröffnungen
		local prevEdge = -length / 2
		for _, centerZ in WINDOW_CENTERS do
			buildWallSegment(root, wallX, prevEdge, centerZ - WINDOW_WIDTH / 2)
			prevEdge = centerZ + WINDOW_WIDTH / 2
		end
		buildWallSegment(root, wallX, prevEdge, length / 2)

		for _, centerZ in WINDOW_CENTERS do
			buildWindow(root, wallX, centerZ)
		end
	end
end

local function buildEndWalls(root: Model)
	local origin = LobbyConfig.Origin
	local length = LobbyConfig.HallLength
	local width = LobbyConfig.HallWidth
	local height = LobbyConfig.HallHeight

	for _, zSide in { -1, 1 } do
		local wall = makePart(
			zSide == -1 and "WallBack" or "WallFront",
			Vector3.new(width + 2, height, 1),
			CFrame.new(origin + Vector3.new(0, height / 2, zSide * (length / 2 + 0.5))),
			root
		)
		wall.BrickColor = COLOR_WALL
	end

	-- Portal-Attrappe am Gangende (+Z): Doppeltür mit weißem Rahmen
	local doorZ = length / 2 - 0.2
	local door = makePart(
		"Door",
		Vector3.new(8, 10.5, 0.4),
		CFrame.new(origin + Vector3.new(0, 10.5 / 2, doorZ)),
		root
	)
	door.BrickColor = COLOR_WOOD

	for _, xSide in { -1, 1 } do
		local jamb = makePart(
			"DoorFrame",
			Vector3.new(0.7, 11.4, 0.6),
			CFrame.new(origin + Vector3.new(xSide * 4.35, 11.4 / 2, doorZ)),
			root
		)
		jamb.BrickColor = COLOR_TRIM
	end

	local header = makePart(
		"DoorFrame",
		Vector3.new(9.4, 0.7, 0.6),
		CFrame.new(origin + Vector3.new(0, 10.85, doorZ)),
		root
	)
	header.BrickColor = COLOR_TRIM

	for _, xSide in { -1, 1 } do
		local handle = makePart(
			"DoorHandle",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(origin + Vector3.new(xSide * 0.7, 4.8, doorZ - 0.4)),
			root
		)
		handle.Shape = Enum.PartType.Ball
		handle.BrickColor = BrickColor.new("Bright yellow")
	end
end

local function buildTrim(root: Model)
	local origin = LobbyConfig.Origin
	local length = LobbyConfig.HallLength
	local width = LobbyConfig.HallWidth
	local height = LobbyConfig.HallHeight

	for _, side in { -1, 1 } do
		-- Sockelleiste aus dunklem Holz
		local wainscot = makePart(
			"Wainscot",
			Vector3.new(0.4, 2.6, length),
			CFrame.new(origin + Vector3.new(side * (width / 2 - 0.2), 1.3, 0)),
			root
		)
		wainscot.BrickColor = COLOR_WOOD

		-- Stuckleiste unter der Decke
		local cornice = makePart(
			"Cornice",
			Vector3.new(0.5, 0.7, length),
			CFrame.new(origin + Vector3.new(side * (width / 2 - 0.25), height - 0.35, 0)),
			root
		)
		cornice.BrickColor = COLOR_TRIM
	end

	for _, zSide in { -1, 1 } do
		local endCornice = makePart(
			"Cornice",
			Vector3.new(width, 0.7, 0.5),
			CFrame.new(origin + Vector3.new(0, height - 0.35, zSide * (length / 2 - 0.25))),
			root
		)
		endCornice.BrickColor = COLOR_TRIM
	end
end

local function buildLamps(root: Model)
	local origin = LobbyConfig.Origin
	local height = LobbyConfig.HallHeight

	for _, z in { -45, -15, 15, 45 } do
		local rod = makePart(
			"LampRod",
			Vector3.new(0.3, 2.5, 0.3),
			CFrame.new(origin + Vector3.new(0, height - 1.25, z)),
			root
		)
		rod.BrickColor = BrickColor.new("Dark stone grey")

		local shade = makePart(
			"LampShade",
			Vector3.new(2.2, 0.8, 2.2),
			CFrame.new(origin + Vector3.new(0, height - 2.9, z)),
			root
		)
		shade.BrickColor = BrickColor.new("Dark stone grey")

		local bulb = makePart(
			"LampBulb",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(origin + Vector3.new(0, height - 3.6, z)),
			root
		)
		bulb.Shape = Enum.PartType.Ball
		bulb.BrickColor = COLOR_CEILING
		bulb.Material = Enum.Material.Neon

		local light = Instance.new("PointLight")
		light.Range = 28
		light.Brightness = 1.1
		light.Parent = bulb
	end
end

local function buildWeaponSlot(parent: Folder, side: number, index: number, position: Vector3)
	local slot = Instance.new("Model")
	slot.Name = "WeaponSlot"
	slot:SetAttribute("Side", side == -1 and "Left" or "Right")
	slot:SetAttribute("Index", index)

	-- Holzsockel als Ausstellungspodest
	local pedestal = makePart("Pedestal", Vector3.new(3, 3, 3), CFrame.new(position + Vector3.new(0, 1.5, 0)), slot)
	pedestal.BrickColor = COLOR_WOOD

	local pad = makePart("Pad", Vector3.new(3.2, 0.2, 3.2), CFrame.new(position + Vector3.new(0, 3.1, 0)), slot)
	pad.BrickColor = COLOR_ACCENT
	pad.Material = Enum.Material.Neon

	-- Hologramm-Würfel als sichtbarer Platzhalter; hier kommt später die Waffe hin
	local hologram = makePart(
		"Hologram",
		Vector3.new(1.8, 1.8, 1.8),
		CFrame.new(position + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, math.rad(45), math.rad(20)),
		slot
	)
	hologram.BrickColor = COLOR_ACCENT
	hologram.Material = Enum.Material.ForceField
	hologram.CanCollide = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 28)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = 60
	billboard.Parent = hologram

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "WEAPON SLOT"
	label.TextColor3 = COLOR_ACCENT.Color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	slot.PrimaryPart = pedestal
	slot.Parent = parent
end

local function buildWeaponSlots(root: Model)
	local origin = LobbyConfig.Origin
	local width = LobbyConfig.HallWidth

	local slotsFolder = Instance.new("Folder")
	slotsFolder.Name = "WeaponSlots"
	slotsFolder.Parent = root

	for _, side in { -1, 1 } do
		local x = side * (width / 2 - 2.5)
		for index, z in SLOT_CENTERS do
			buildWeaponSlot(slotsFolder, side, index, origin + Vector3.new(x, 0, z))
		end
	end
end

local function buildSpawn(root: Model)
	local origin = LobbyConfig.Origin
	local length = LobbyConfig.HallLength

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	-- Blick in den Gang hinein (+Z)
	spawnLocation.CFrame = CFrame.lookAt(
		origin + Vector3.new(0, 0.5, -length / 2 + 6),
		origin + Vector3.new(0, 0.5, 0)
	)
	spawnLocation.Duration = 0
	spawnLocation.BrickColor = BrickColor.new("Medium stone grey")
	spawnLocation.TopSurface = Enum.SurfaceType.Studs
	spawnLocation.BottomSurface = Enum.SurfaceType.Inlet
	spawnLocation.Parent = root
end

function LobbyBuilder.build(): Model
	local root = Instance.new("Model")
	root.Name = "PreLobby"

	buildFloorAndCeiling(root)
	buildSideWalls(root)
	buildEndWalls(root)
	buildTrim(root)
	buildLamps(root)
	buildWeaponSlots(root)
	buildSpawn(root)

	root.Parent = workspace
	return root
end

return LobbyBuilder
