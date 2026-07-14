--!strict

-- Schuss-Logik der Shotguns: nimmt Feuer-Requests entgegen, simuliert die
-- Pellets (neon-gelbe Blöcke) serverseitig per Raycast-Stepping — sichtbar
-- wie Physik-Projektile, aber ohne Tunneling bei hoher Geschwindigkeit —
-- und wendet Knockback in Flugrichtung des Pellets an. Merkt sich pro Opfer
-- den letzten Angreifer, damit der DeathTracker Abschüsse zuordnen kann.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local Ragdoll = require(script.Parent.Ragdoll)

local CombatService = {}

-- max. Sekunden zwischen Treffer und Absturz, damit der Punkt noch zählt
local ATTACKER_WINDOW = 8

type Pellet = {
	part: Part,
	velocity: Vector3,
	shooter: Player,
	knockback: number,
	expires: number,
	params: RaycastParams,
}

local projectileFolder = Instance.new("Folder")
local activePellets: { Pellet } = {}
local lastHit: { [Player]: { attacker: Player, time: number } } = {}
local lastShot: { [Player]: number } = {}
local random = Random.new()

local function findCharacter(instance: Instance): Model?
	local model = instance:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	return nil
end

local function applyKnockback(shooter: Player, victimModel: Model, travel: Vector3, knockback: number)
	local root = victimModel:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	-- horizontal in Flugrichtung des Pellets, plus leichter Aufwärts-Schub
	local horizontal = travel * Vector3.new(1, 0, 1)
	local direction = if horizontal.Magnitude > 0.01 then horizontal.Unit else Vector3.new(0, 0, -1)
	local velocity = direction * knockback
		+ Vector3.new(0, knockback * WeaponConfig.Pellets.UpwardFactor, 0)

	-- erst ragdollen (löst die Gelenke), dann fliegen lassen
	local duration = WeaponConfig.Ragdoll.BaseTime + knockback * WeaponConfig.Ragdoll.TimePerKnockback
	Ragdoll.apply(victimModel, duration)

	-- Nach dem Lösen der Gelenke ist jedes Körperteil eine eigene Assembly:
	-- Velocity pro Assembly-Root setzen und für die Flugdauer den Großteil der
	-- Gravitation per VectorForce kompensieren — der schlaffe Körper segelt so
	-- auf gerader Bahn in Trefferrichtung davon.
	local antiGravity = workspace.Gravity * (1 - WeaponConfig.Ragdoll.GravityFactor)
	for _, descendant in victimModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.AssemblyRootPart == descendant then
			descendant.AssemblyLinearVelocity = velocity

			-- Kräfte eines früheren Treffers ersetzen statt stapeln
			local oldForce = descendant:FindFirstChild("KnockbackFlight")
			if oldForce then
				oldForce:Destroy()
			end
			local oldAttachment = descendant:FindFirstChild("KnockbackFlightAttachment")
			if oldAttachment then
				oldAttachment:Destroy()
			end

			local attachment = Instance.new("Attachment")
			attachment.Name = "KnockbackFlightAttachment"
			attachment.Parent = descendant

			local force = Instance.new("VectorForce")
			force.Name = "KnockbackFlight"
			force.Attachment0 = attachment
			force.RelativeTo = Enum.ActuatorRelativeTo.World
			force.Force = Vector3.new(0, descendant.AssemblyMass * antiGravity, 0)
			force.Parent = descendant

			task.delay(duration, function()
				force:Destroy()
				attachment:Destroy()
			end)
		end
	end

	local victim = Players:GetPlayerFromCharacter(victimModel)
	if victim and victim ~= shooter then
		lastHit[victim] = { attacker = shooter, time = os.clock() }
	end
end

local function stepPellets(dt: number)
	for i = #activePellets, 1, -1 do
		local pellet = activePellets[i]
		local part = pellet.part
		local remove = false

		if os.clock() >= pellet.expires or not part.Parent then
			remove = true
		else
			local step = pellet.velocity * dt
			local result = workspace:Raycast(part.Position, step, pellet.params)
			if result then
				local victimModel = findCharacter(result.Instance)
				if victimModel then
					local humanoid = victimModel:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						applyKnockback(pellet.shooter, victimModel, pellet.velocity, pellet.knockback)
					end
				end
				remove = true
			else
				part.Position += step
			end
		end

		if remove then
			part:Destroy()
			table.remove(activePellets, i)
		end
	end
end

local function spawnPellets(shooter: Player, root: BasePart, direction: Vector3, variant: WeaponConfig.Variant)
	local cfg = WeaponConfig.Pellets

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = shooter.Character
	params.FilterDescendantsInstances = if character
		then { character :: Instance, projectileFolder }
		else { projectileFolder }

	local origin = root.Position + direction * 2 + Vector3.new(0, 0.4, 0)
	local aim = CFrame.lookAt(root.Position, root.Position + direction)

	for _ = 1, cfg.Count do
		local pitch = math.rad(random:NextNumber(-cfg.SpreadAngle, cfg.SpreadAngle))
		local yaw = math.rad(random:NextNumber(-cfg.SpreadAngle, cfg.SpreadAngle))
		local pelletDirection = (aim * CFrame.Angles(pitch, yaw, 0)).LookVector

		local part = Instance.new("Part")
		part.Name = "Pellet"
		part.Size = Vector3.one * cfg.Size
		part.CFrame = CFrame.lookAt(origin, origin + pelletDirection)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.BrickColor = BrickColor.new("New Yeller")
		part.Material = Enum.Material.Neon
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = projectileFolder

		table.insert(activePellets, {
			part = part,
			velocity = pelletDirection * cfg.Speed,
			shooter = shooter,
			knockback = variant.knockback,
			expires = os.clock() + cfg.LifeTime,
			params = params,
		})
	end
end

local function onFire(player: Player, direction: unknown)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local dir = direction :: Vector3
	-- NaN-Vektoren vergleichen ungleich mit sich selbst
	if dir ~= dir or dir.Magnitude < 0.5 or dir.Magnitude > 2 then
		return
	end
	dir = dir.Unit

	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return
	end
	local variant = WeaponConfig.byId(tool:GetAttribute("WeaponId"))
	if not variant then
		return
	end

	-- Reload-Zeit serverseitig durchsetzen (kleine Toleranz für Netzwerk-Jitter)
	local now = os.clock()
	if now - (lastShot[player] or 0) < variant.reloadTime - 0.05 then
		return
	end
	lastShot[player] = now

	local handle = tool:FindFirstChild("Handle")
	local sound = if handle then handle:FindFirstChild("ShootSound") else nil
	if sound and sound:IsA("Sound") then
		-- doppelt so schnell abgespielt wird der Blast zum kurzen Knall;
		-- leichte Variation, damit Dauerfeuer nicht monoton klingt
		sound.PlaybackSpeed = random:NextNumber(1.85, 2.15)
		sound:Play()
		task.delay(0.35, function()
			if sound.Parent and sound.IsPlaying then
				sound:Stop()
			end
		end)
	end

	spawnPellets(player, root, dir, variant)
end

-- Gibt den letzten Angreifer zurück (und verbraucht den Eintrag), sofern der
-- Treffer frisch genug ist und der Angreifer noch im Spiel ist.
function CombatService.takeLastAttacker(victim: Player): Player?
	local record = lastHit[victim]
	lastHit[victim] = nil
	if record and os.clock() - record.time <= ATTACKER_WINDOW and record.attacker.Parent ~= nil then
		return record.attacker
	end
	return nil
end

function CombatService.init()
	projectileFolder.Name = "Projectiles"
	projectileFolder.Parent = workspace

	local remote = Instance.new("RemoteEvent")
	remote.Name = WeaponConfig.FireRemoteName
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(onFire)

	RunService.Heartbeat:Connect(stepPellets)

	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		lastShot[player] = nil
	end)
end

return CombatService
