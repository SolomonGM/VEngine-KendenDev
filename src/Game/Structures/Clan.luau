  local ReplicatedFirst = game:GetService("ReplicatedFirst")

local GameTypes = require(ReplicatedFirst.Shared.GameTypes)
local struct = {}

function struct.GetClans()
	return {
		NoClan = {
			Id = 0,
			Name = "No Clan",
			Tag = "+NoClan+",
			Chance = 0,
		},
		Common = {
			Id = 1,
			Name = "Common",
			Tag = "+Common+",
			Chance = 71.9,
		},
		Rare = {
			Id = 2,
			Name = "Rare",
			Tag = "+Rare+",
			Chance = 25.6,
		},
		Legendary = {
			Id = 3,
			Name = "Legendary",
			Tag = "+Legendary+",
			Chance = 2,
		},
		Transcendent = {
			Id = 4,
			Name = "Transcendent",
			Tag = "+Transcendent+",
			Chance = 0.5,
		},
		Kure = {
			Id = 5,
			Name = "Kure",
			Tag = "+KURE+",
			Chance = 0,
		},
		Wu = {
			Id = 6,
			Name = "Wu",
			Tag = "+WU+",
			Chance = 0,
		},
		Mikazuchi = {
			Id = 7,
			Name = "Mikazuchi",
			Tag = "+MIKAZUCHI",
			Chance = 0,
		},
		Wongsawat = {
			Id = 8,
			Name = "Wongsawat",
			Tag = "+Wongsawat+",
			Chance = 0,
		},
		Jun = {
			Id = 9,
			Name = "Jun",
			Tag = "+JUN+",
			Chance = 0,
		},
		Dudley = {
			Id = 10,
			Name = "Dudley",
			Tag = "+DUDLEY+",
			Chance = 0,
		},
	}
end

function struct.isClan(clan: GameTypes.Clan)
	if
		typeof(clan) ~= "table"
		or typeof(getmetatable(clan :: any)) ~= "nil"
		or typeof(clan.Id) ~= "number"
		or typeof(clan.Chance) ~= "number"
		or typeof(clan.Name) ~= "string"
		or typeof(clan.Tag) ~= "string"
	then
		return false
	end

	return true
end

return struct
