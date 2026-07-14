-- Feuer-Script der Shotgun. Liegt als Template unter ReplicatedStorage.Shared
-- (dort läuft es nie) und wird von ShotgunFactory in jedes Tool geklont.
-- Schickt beim Klick/Tap die Zielrichtung an den Server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool = script.Parent
if not tool or not tool:IsA("Tool") then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remote = ReplicatedStorage:WaitForChild(WeaponConfig.FireRemoteName)

local reloadTime = tool:GetAttribute("ReloadTime") or 1
local lastShot = 0

tool.Activated:Connect(function()
	local now = os.clock()
	if now - lastShot < reloadTime then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	-- mouse.Hit funktioniert auch auf Touch; Fallback ist die Kamerarichtung
	local direction = mouse.Hit.Position - root.Position
	local camera = workspace.CurrentCamera
	if direction.Magnitude < 2 and camera then
		direction = camera.CFrame.LookVector
	end

	lastShot = now
	remote:FireServer(direction.Unit)
end)
