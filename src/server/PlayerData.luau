--!strict

-- Zentrale Spielerdaten: Leaderstats (Knockbacks, Deaths), Waffenbesitz und
-- ausgerüstete Waffe — geladen und gespeichert per DataStore.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local STORE_NAME = "PlayerStats_v1"

export type Profile = {
	deaths: number,
	knockbacks: number,
	owned: { string },
	equipped: string,
}

local PlayerData = {}

-- feuert mit (player), sobald das Profil aus dem DataStore gemerged ist
PlayerData.ProfileLoaded = Instance.new("BindableEvent")

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local function profileKey(player: Player): string
	return `profile_{player.UserId}`
end

local function legacyDeathsKey(player: Player): string
	return `deaths_{player.UserId}`
end

local function defaultProfile(): Profile
	return {
		deaths = 0,
		knockbacks = 0,
		owned = { WeaponConfig.StarterId },
		equipped = WeaponConfig.StarterId,
	}
end

local function updateLeaderstats(player: Player)
	local profile = profiles[player]
	local leaderstats = player:FindFirstChild("leaderstats")
	if not profile or not leaderstats then
		return
	end
	local knockbacks = leaderstats:FindFirstChild("Knockbacks")
	if knockbacks and knockbacks:IsA("IntValue") then
		knockbacks.Value = profile.knockbacks
	end
	local deaths = leaderstats:FindFirstChild("Deaths")
	if deaths and deaths:IsA("IntValue") then
		deaths.Value = profile.deaths
	end
end

-- addiert statt zu setzen, falls der Spieler vor Ladeabschluss schon Stats gesammelt hat
local function mergeLoaded(profile: Profile, stored: any)
	if typeof(stored) == "number" then
		-- Altformat: es wurde nur der Death-Zähler gespeichert
		profile.deaths += stored
		return
	end
	if typeof(stored) ~= "table" then
		return
	end
	if typeof(stored.deaths) == "number" then
		profile.deaths += stored.deaths
	end
	if typeof(stored.knockbacks) == "number" then
		profile.knockbacks += stored.knockbacks
	end
	if typeof(stored.owned) == "table" then
		for _, id in stored.owned do
			if typeof(id) == "string" and WeaponConfig.byId(id) and not table.find(profile.owned, id) then
				table.insert(profile.owned, id)
			end
		end
	end
	if typeof(stored.equipped) == "string" and WeaponConfig.byId(stored.equipped) then
		profile.equipped = stored.equipped
	end
end

local function loadAsync(player: Player)
	local dataStore = store
	if not dataStore then
		PlayerData.ProfileLoaded:Fire(player)
		return
	end
	task.spawn(function()
		local ok, stored = pcall(function()
			return dataStore:GetAsync(profileKey(player))
		end)
		if ok and stored == nil then
			-- Migration vom alten Format
			ok, stored = pcall(function()
				return dataStore:GetAsync(legacyDeathsKey(player))
			end)
		end

		local profile = profiles[player]
		if not profile then
			return -- Spieler ist schon wieder weg
		end
		if ok then
			mergeLoaded(profile, stored)
		else
			warn(`[PlayerData] Laden für {player.Name} fehlgeschlagen: {stored}`)
		end
		updateLeaderstats(player)
		PlayerData.ProfileLoaded:Fire(player)
	end)
end

local function save(player: Player)
	local dataStore = store
	local profile = profiles[player]
	if not dataStore or not profile then
		return
	end
	local ok, err = pcall(function()
		dataStore:UpdateAsync(profileKey(player), function()
			return {
				deaths = profile.deaths,
				knockbacks = profile.knockbacks,
				owned = profile.owned,
				equipped = profile.equipped,
			}
		end)
	end)
	if not ok then
		warn(`[PlayerData] Speichern für {player.Name} fehlgeschlagen: {err}`)
	end
end

local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	profiles[player] = defaultProfile()

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local knockbacks = Instance.new("IntValue")
	knockbacks.Name = "Knockbacks"
	knockbacks.Parent = leaderstats

	local deaths = Instance.new("IntValue")
	deaths.Name = "Deaths"
	deaths.Parent = leaderstats

	leaderstats.Parent = player

	loadAsync(player)
end

function PlayerData.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[PlayerData] DataStore nicht verfügbar, Stats werden nicht gespeichert: {result}`)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
end

function PlayerData.saveNow(player: Player)
	task.spawn(save, player)
end

function PlayerData.addDeath(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.deaths += 1
	updateLeaderstats(player)
end

function PlayerData.addKnockback(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.knockbacks += 1
	updateLeaderstats(player)
end

function PlayerData.getKnockbacks(player: Player): number
	local profile = profiles[player]
	return if profile then profile.knockbacks else 0
end

function PlayerData.owns(player: Player, weaponId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and table.find(profile.owned, weaponId) ~= nil
end

function PlayerData.grant(player: Player, weaponId: string)
	local profile = profiles[player]
	if profile and not table.find(profile.owned, weaponId) then
		table.insert(profile.owned, weaponId)
	end
end

function PlayerData.getEquipped(player: Player): string
	local profile = profiles[player]
	return if profile then profile.equipped else WeaponConfig.StarterId
end

function PlayerData.setEquipped(player: Player, weaponId: string)
	local profile = profiles[player]
	if profile and table.find(profile.owned, weaponId) then
		profile.equipped = weaponId
	end
end

return PlayerData
