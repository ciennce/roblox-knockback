--!strict

-- Nimmt den "Join Game"-Request vom Client entgegen und teleportiert den
-- Charakter serverseitig auf ein zufälliges Spawn-Pad der Map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)

local JoinService = {}

local random = Random.new()

function JoinService.init(spawnPads: Folder)
	local remote = Instance.new("RemoteEvent")
	remote.Name = LobbyConfig.RemoteName
	remote.Parent = ReplicatedStorage

	remote.OnServerEvent:Connect(function(player)
		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local pads = spawnPads:GetChildren()
		if #pads == 0 then
			return
		end
		local pad = pads[random:NextInteger(1, #pads)]
		if not pad:IsA("BasePart") then
			return
		end

		-- knapp über dem Pad absetzen, Blick Richtung Inselmitte (Baum)
		local spawnPosition = pad.Position + Vector3.new(0, 3.5, 0)
		local lookTarget = Vector3.new(0, spawnPosition.Y, 0)
		character:PivotTo(CFrame.lookAt(spawnPosition, lookTarget))
	end)
end

return JoinService
