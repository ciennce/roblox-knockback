--!strict

-- Shotgun-Varianten und Schuss-Parameter. Wird von Server (Bau, Simulation,
-- Freischaltung) und Client (Feuer-Script im Tool) gelesen.

export type Variant = {
	id: string,
	name: string,
	cost: number, -- benötigte Knockback-Punkte (Schwelle, wird nicht ausgegeben)
	knockback: number, -- Wucht in Studs/s
	reloadTime: number, -- Sekunden zwischen Schüssen
	bodyColor: BrickColor,
}

local WeaponConfig = {}

WeaponConfig.FireRemoteName = "ShotgunFire"
WeaponConfig.StarterId = "rookie"

-- Ragdoll bei Treffern: Dauer = BaseTime + knockback * TimePerKnockback.
-- Während des Flugs wirkt nur GravityFactor der normalen Gravitation.
WeaponConfig.Ragdoll = {
	BaseTime = 1.6,
	TimePerKnockback = 0.01,
	GravityFactor = 0.12,
}

WeaponConfig.Pellets = {
	Count = 9,
	Speed = 140,
	SpreadAngle = 6, -- Halbwinkel in Grad
	Size = 0.45,
	LifeTime = 1.0, -- Sekunden -> effektive Reichweite = Speed * LifeTime
	UpwardFactor = 0.18, -- Anteil Aufwärts-Schub beim Knockback (klein, da kaum Gravitation wirkt)
}

WeaponConfig.Variants = {
	{ id = "rookie", name = "Rookie", cost = 0, knockback = 42, reloadTime = 2.0, bodyColor = BrickColor.new("Medium stone grey") },
	{ id = "pusher", name = "Pusher", cost = 3, knockback = 55, reloadTime = 1.8, bodyColor = BrickColor.new("Bright blue") },
	{ id = "blaster", name = "Blaster", cost = 8, knockback = 68, reloadTime = 1.5, bodyColor = BrickColor.new("Bright green") },
	{ id = "launcher", name = "Launcher", cost = 15, knockback = 82, reloadTime = 1.3, bodyColor = BrickColor.new("Bright violet") },
	{ id = "meteor", name = "Meteor", cost = 25, knockback = 98, reloadTime = 1.1, bodyColor = BrickColor.new("Bright orange") },
	{ id = "goliath", name = "Goliath", cost = 40, knockback = 118, reloadTime = 0.85, bodyColor = BrickColor.new("Bright red") },
} :: { Variant }

local byId: { [string]: Variant } = {}
for _, variant in WeaponConfig.Variants do
	byId[variant.id] = variant
end

function WeaponConfig.byId(id: string?): Variant?
	return if id then byId[id] else nil
end

return WeaponConfig
