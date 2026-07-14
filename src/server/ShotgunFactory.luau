--!strict

-- Baut Blocky-Shotguns prozedural: als ausrüstbares Tool (Handle + verschweißte
-- Parts + geklontes Feuer-LocalScript) oder als verankertes Ausstellungsmodell
-- für die Podeste in der Lobby. Lauf zeigt in -Z.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local ShotgunFactory = {}

local ACCENT = BrickColor.new("New Yeller")
local WOOD = BrickColor.new("Reddish brown")
local METAL = BrickColor.new("Dark stone grey")

type PartSpec = {
	name: string,
	size: Vector3,
	offset: CFrame, -- relativ zum Handle (Receiver)
	color: BrickColor,
	neon: boolean?,
}

local PART_SPECS: { PartSpec } = {
	{ name = "Grip", size = Vector3.new(0.35, 0.9, 0.45), offset = CFrame.new(0, -0.6, 0.85), color = WOOD },
	{ name = "Stock", size = Vector3.new(0.45, 0.55, 1.1), offset = CFrame.new(0, 0, 1.7), color = WOOD },
	{ name = "BarrelL", size = Vector3.new(0.3, 0.3, 2.6), offset = CFrame.new(-0.16, 0.16, -2.3), color = METAL },
	{ name = "BarrelR", size = Vector3.new(0.3, 0.3, 2.6), offset = CFrame.new(0.16, 0.16, -2.3), color = METAL },
	{ name = "Pump", size = Vector3.new(0.45, 0.45, 0.9), offset = CFrame.new(0, -0.22, -2.0), color = WOOD },
	{ name = "MuzzleL", size = Vector3.new(0.36, 0.36, 0.25), offset = CFrame.new(-0.16, 0.16, -3.7), color = ACCENT, neon = true },
	{ name = "MuzzleR", size = Vector3.new(0.36, 0.36, 0.25), offset = CFrame.new(0.16, 0.16, -3.7), color = ACCENT, neon = true },
	{ name = "Sight", size = Vector3.new(0.15, 0.22, 0.4), offset = CFrame.new(0, 0.38, -0.9), color = ACCENT, neon = true },
}

local function makeGunPart(name: string, size: Vector3, color: BrickColor, neon: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.BrickColor = color
	part.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Massless = true
	return part
end

-- Receiver = Handle; alle anderen Parts hängen relativ daran
local function buildHandle(variant: WeaponConfig.Variant): Part
	return makeGunPart("Handle", Vector3.new(0.5, 0.5, 2.4), variant.bodyColor, false)
end

function ShotgunFactory.createTool(variant: WeaponConfig.Variant): Tool
	local tool = Instance.new("Tool")
	tool.Name = variant.name
	tool.ToolTip = `Knockback {variant.knockback} • Reload {variant.reloadTime}s`
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponId", variant.id)
	tool:SetAttribute("ReloadTime", variant.reloadTime)
	-- Hand ans hintere Griffstück (Handle-lokal (0, -0.6, 0.85))
	tool.GripPos = Vector3.new(0, 0.6, -0.85)

	local handle = buildHandle(variant)
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	-- klassischer Roblox-Blast, wird vom Server bei jedem Schuss abgespielt
	local shootSound = Instance.new("Sound")
	shootSound.Name = "ShootSound"
	shootSound.SoundId = "rbxasset://sounds/Rocket shot.wav"
	shootSound.Volume = 0.25
	shootSound.RollOffMinDistance = 10
	shootSound.RollOffMaxDistance = 150
	shootSound.Parent = handle

	for _, spec in PART_SPECS do
		local part = makeGunPart(spec.name, spec.size, spec.color, spec.neon)
		part.CFrame = handle.CFrame * spec.offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = tool
	end

	local template = ReplicatedStorage.Shared:FindFirstChild("ShotgunClient")
	if template then
		template:Clone().Parent = tool
	else
		warn("[ShotgunFactory] ShotgunClient-Template fehlt in ReplicatedStorage.Shared")
	end

	return tool
end

function ShotgunFactory.createDisplay(variant: WeaponConfig.Variant): Model
	local model = Instance.new("Model")
	model.Name = variant.id

	local handle = buildHandle(variant)
	handle.Anchored = true
	handle.CFrame = CFrame.new()
	handle.Parent = model

	for _, spec in PART_SPECS do
		local part = makeGunPart(spec.name, spec.size, spec.color, spec.neon)
		part.Anchored = true
		part.CFrame = handle.CFrame * spec.offset
		part.Parent = model
	end

	model.PrimaryPart = handle
	return model
end

return ShotgunFactory
