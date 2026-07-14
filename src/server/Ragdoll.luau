--!strict

-- Temporärer Ragdoll für Charaktere: Motor6Ds werden deaktiviert und durch
-- BallSocketConstraints ersetzt, die Gliedmaßen bekommen Kollision, der
-- Humanoid geht in PlatformStand/Physics. Nach Ablauf wird alles
-- zurückgebaut und der Charakter steht wieder auf. Stirbt der Charakter
-- währenddessen, bleibt die Leiche als Ragdoll liegen.

local RunService = game:GetService("RunService")

local Ragdoll = {}

type State = {
	expires: number,
	motors: { Motor6D },
	temp: { Instance }, -- Attachments + Constraints
	collide: { [BasePart]: boolean },
	requiresNeck: boolean,
}

local states: { [Model]: State } = {}

local function restore(character: Model)
	local state = states[character]
	if not state then
		return
	end
	states[character] = nil

	for _, instance in state.temp do
		instance:Destroy()
	end
	for _, motor in state.motors do
		if motor.Parent then
			motor.Enabled = true
		end
	end
	for part, hadCollision in state.collide do
		if part.Parent then
			part.CanCollide = hadCollision
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.RequiresNeck = state.requiresNeck
		humanoid.PlatformStand = false
		if humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

function Ragdoll.apply(character: Model, duration: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- schon am Ragdollen: nur den Timer auffrischen
	local existing = states[character]
	if existing then
		existing.expires = os.clock() + duration
		return
	end

	local state: State = {
		expires = os.clock() + duration,
		motors = {},
		temp = {},
		collide = {},
		requiresNeck = humanoid.RequiresNeck,
	}

	-- ohne das würde das Deaktivieren des Neck-Motors den Charakter töten
	humanoid.RequiresNeck = false
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 then
			local attachment0 = Instance.new("Attachment")
			attachment0.CFrame = descendant.C0
			attachment0.Parent = descendant.Part0

			local attachment1 = Instance.new("Attachment")
			attachment1.CFrame = descendant.C1
			attachment1.Parent = descendant.Part1

			-- weite Limits, damit die Glieder richtig schlackern
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = attachment0
			socket.Attachment1 = attachment1
			socket.LimitsEnabled = true
			socket.UpperAngle = 80
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -75
			socket.TwistUpperAngle = 75
			socket.Parent = descendant.Part0

			table.insert(state.temp, socket)
			table.insert(state.temp, attachment0)
			table.insert(state.temp, attachment1)
			table.insert(state.motors, descendant)
			descendant.Enabled = false
		elseif descendant:IsA("BasePart") then
			state.collide[descendant] = descendant.CanCollide
			if descendant.Name == "HumanoidRootPart" then
				-- der große unsichtbare Root-Kollider würde den Ragdoll steif
				-- über den Boden schleifen — die Gliedmaßen kollidieren stattdessen
				descendant.CanCollide = false
			else
				-- Gliedmaßen brauchen Kollision, sonst sackt der Ragdoll durch den Boden
				descendant.CanCollide = true
			end
		end
	end

	states[character] = state
end

function Ragdoll.init()
	RunService.Heartbeat:Connect(function()
		for character, state in states do
			if character.Parent == nil then
				states[character] = nil
				continue
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				-- Tod während des Ragdolls: Leiche floppy liegen lassen,
				-- der Respawn ersetzt den Charakter sowieso
				states[character] = nil
			elseif os.clock() >= state.expires then
				restore(character)
			end
		end
	end)
end

return Ragdoll
