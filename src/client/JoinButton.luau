--!strict

-- Baut die Prelobby-GUI: ein "Join Game"-Button, mittig am oberen Bildschirmrand.
-- Größen sind Scale-basiert mit Min/Max-Constraints, ScreenInsets halten den Button
-- auf Mobile aus Notch und Statusleiste heraus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared:WaitForChild("LobbyConfig"))

local JoinButton = {}

function JoinButton.mount()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remote = ReplicatedStorage:WaitForChild(LobbyConfig.RemoteName)

	local gui = Instance.new("ScreenGui")
	gui.Name = "PreLobbyGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 10

	local button = Instance.new("TextButton")
	button.Name = "JoinButton"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 12)
	button.Size = UDim2.fromScale(0.3, 0.08)
	button.BackgroundColor3 = Color3.fromRGB(56, 190, 110)
	button.Text = "JOIN GAME"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = gui

	-- Nie kleiner als ein sauberes Touch-Target (44 px), nie riesig auf Desktop
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(160, 44)
	sizeConstraint.MaxSize = Vector2.new(340, 72)
	sizeConstraint.Parent = button

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 30
	textConstraint.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(30, 120, 66)
	stroke.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = button

	-- Activated feuert bei Maus, Touch und Gamepad gleichermaßen
	button.Activated:Connect(function()
		remote:FireServer()
		gui.Enabled = false
	end)

	-- Nach dem Tod respawnt man in der Lobby, also Button wieder einblenden
	player.CharacterAdded:Connect(function()
		gui.Enabled = true
	end)

	gui.Parent = playerGui
end

return JoinButton
