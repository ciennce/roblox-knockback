--!strict

-- Absturz-Erkennung und Todes-Verbuchung: unterhalb von MapConfig.KillY stirbt
-- der Charakter (Respawn am Lobby-Spawn, dem einzigen SpawnLocation). Jeder Tod
-- zählt auf das Deaths-Leaderstat; hat kurz zuvor jemand das Opfer mit der
-- Shotgun getroffen, bekommt der Schütze einen Knockback-Punkt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.MapConfig)
local CombatService = require(script.Parent.CombatService)
local PlayerData = require(script.Parent.PlayerData)

local DeathTracker = {}

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Once(function()
		PlayerData.addDeath(player)
		local attacker = CombatService.takeLastAttacker(player)
		if attacker and attacker ~= player then
			PlayerData.addKnockback(attacker)
		end
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function DeathTracker.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Absturz-Erkennung: unterhalb der Kill-Höhe stirbt der Charakter
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if not character then
					continue
				end
				local root = character:FindFirstChild("HumanoidRootPart")
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if
					root
					and root:IsA("BasePart")
					and humanoid
					and humanoid.Health > 0
					and root.Position.Y < MapConfig.KillY
				then
					humanoid.Health = 0
				end
			end
		end
	end)
end

return DeathTracker
