--!strict

-- Verbindet die Waffen mit der Welt: bestückt die Lobby-Podeste mit rotierenden
-- Ausstellungs-Shotguns, Infotafeln und ProximityPrompts zum Freischalten bzw.
-- Ausrüsten, und gibt jedem Spieler bei jedem Spawn seine ausgerüstete Shotgun.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local PlayerData = require(script.Parent.PlayerData)
local ShotgunFactory = require(script.Parent.ShotgunFactory)

local WeaponService = {}

local spinningDisplays: { { model: Model, base: CFrame } } = {}

local function removeShotguns(player: Player)
	local function clear(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("WeaponId") ~= nil then
				child:Destroy()
			end
		end
	end
	clear(player:FindFirstChildOfClass("Backpack"))
	clear(player.Character)
end

local function giveEquipped(player: Player, equipNow: boolean)
	local variant = WeaponConfig.byId(PlayerData.getEquipped(player))
	if not variant then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	removeShotguns(player)
	local tool = ShotgunFactory.createTool(variant)
	tool.Parent = backpack

	if equipNow then
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid:EquipTool(tool)
		end
	end
end

local function flashPad(pad: BasePart, success: boolean)
	local original = BrickColor.new("Toothpaste")
	pad.BrickColor = BrickColor.new(if success then "Bright green" else "Really red")
	task.delay(0.35, function()
		if pad.Parent then
			pad.BrickColor = original
		end
	end)
end

local function tryUnlockOrEquip(player: Player, variant: WeaponConfig.Variant, pad: BasePart)
	if PlayerData.owns(player, variant.id) then
		PlayerData.setEquipped(player, variant.id)
		giveEquipped(player, true)
		flashPad(pad, true)
	elseif PlayerData.getKnockbacks(player) >= variant.cost then
		PlayerData.grant(player, variant.id)
		PlayerData.setEquipped(player, variant.id)
		PlayerData.saveNow(player)
		giveEquipped(player, true)
		flashPad(pad, true)
	else
		flashPad(pad, false)
	end
end

local function decorateSlot(slot: Model, variant: WeaponConfig.Variant)
	local pedestal = slot:FindFirstChild("Pedestal")
	local pad = slot:FindFirstChild("Pad")
	if not (pedestal and pedestal:IsA("BasePart") and pad and pad:IsA("BasePart")) then
		return
	end

	-- Placeholder-Hologramm (samt Billboard) weicht dem echten Ausstellungsstück
	local hologram = slot:FindFirstChild("Hologram")
	if hologram then
		hologram:Destroy()
	end

	local display = ShotgunFactory.createDisplay(variant)
	display:ScaleTo(0.75)
	local side = if slot:GetAttribute("Side") == "Left" then -1 else 1
	-- leicht zur Gangmitte versetzt, damit die rotierende Waffe nicht die Wand streift
	local base = CFrame.new(pedestal.Position + Vector3.new(-side * 0.8, 3.3, 0))
	display:PivotTo(base)
	display.Parent = slot
	table.insert(spinningDisplays, { model = display, base = base })

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 62)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.MaxDistance = 45
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.RichText = true
	label.Text = `<b>{variant.name}</b>\nKnockback {variant.knockback} • Reload {variant.reloadTime}s\n`
		.. (if variant.cost > 0 then `Ab {variant.cost} Knockbacks` else "Starter")
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = variant.name
	prompt.ActionText = if variant.cost > 0 then `Ausrüsten (ab {variant.cost} KB)` else "Ausrüsten"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = pedestal

	prompt.Triggered:Connect(function(player)
		tryUnlockOrEquip(player, variant, pad)
	end)
end

function WeaponService.init(lobby: Model)
	local slotsFolder = lobby:FindFirstChild("WeaponSlots")
	if slotsFolder then
		local slots: { Model } = {}
		for _, child in slotsFolder:GetChildren() do
			if child:IsA("Model") and child.Name == "WeaponSlot" then
				table.insert(slots, child)
			end
		end
		-- vom Spawn aus nach hinten: Index aufsteigend, links vor rechts —
		-- so hängen die Varianten in Fortschritts-Reihenfolge im Gang
		table.sort(slots, function(a, b)
			local aIndex = (a:GetAttribute("Index") :: number?) or 0
			local bIndex = (b:GetAttribute("Index") :: number?) or 0
			if aIndex ~= bIndex then
				return aIndex < bIndex
			end
			return tostring(a:GetAttribute("Side")) < tostring(b:GetAttribute("Side"))
		end)

		for i, variant in WeaponConfig.Variants do
			local slot = slots[i]
			if slot then
				decorateSlot(slot, variant)
			end
		end
	end

	-- Ausstellungsstücke langsam rotieren lassen
	local angle = 0
	RunService.Heartbeat:Connect(function(dt)
		angle += dt * 0.9
		local rotation = CFrame.Angles(0, angle, 0)
		for _, entry in spinningDisplays do
			entry.model:PivotTo(entry.base * rotation)
		end
	end)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			giveEquipped(player, false)
		end)
		if player.Character then
			giveEquipped(player, false)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Profil fertig geladen: ggf. bessere gespeicherte Waffe statt Starter geben
	PlayerData.ProfileLoaded.Event:Connect(function(player: Player)
		if player.Character then
			giveEquipped(player, false)
		end
	end)
end

return WeaponService
