--!strict
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)

local ClanDataStore: GlobalDataStore

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)
local GameTypes = require(ReplicatedFirst.Shared.GameTypes)
local Clan = require(ReplicatedFirst.Shared.Structures.Clan)

local ClanManager = moduleBaseConstructor.new() :: EngineTypes.BaseEngineModule & GameTypes.ClanManager

ClanManager.ModuleName = "Managers/ClanManager"

local function exponentialBackoff(retries: number): number
    return math.min(60, math.pow(2, retries) + math.random())
end

-- Retry datastore operations with exponential backoff
local function retryDatastoreOperation(operation)
    local retries = 0
    local success, result

    repeat
        success, result = pcall(operation)
        if not success then
            task.wait(exponentialBackoff(retries))
            retries += 1
        end
    until success or retries >= 5

    return success, result
end

function ClanManager:PreInitialize(_: EngineTypes.EngineEnvironmentManager)
    ClanDataStore = DataStoreService:GetDataStore("PlayerClanData")

    local function onPlayerAdded(player: Player)
        local success, result = retryDatastoreOperation(function()
            return ClanDataStore:GetAsync("Player_" .. tostring(player.UserId))
        end)

        if not success then
            warn("Failed to retrieve clan information from datastore for player: " .. player.Name)
            result = ClanManager:GetDefaultClan().Name
        end

        if result == nil then
            result = ClanManager:GetDefaultClan().Name
        end

        local clanValue = Instance.new("StringValue")
        clanValue.Value = result :: string
        clanValue.Name = "Clan"
        clanValue.Parent = player
    end

    for _, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end

    Players.PlayerAdded:Connect(onPlayerAdded)

    Players.PlayerRemoving:Connect(function(player: Player)
        local clanValue = player:FindFirstChild("Clan") :: StringValue?
        if not clanValue then
            warn("Player " .. player.Name .. " does not have a Clan value.")
            return
        end

        local success = retryDatastoreOperation(function()
            return ClanDataStore:SetAsync("Player_" .. tostring(player.UserId), clanValue.Value)
        end)

        if not success then
            warn("Failed to save clan information to datastore for player: " .. player.Name)
        end
    end)
end


function ClanManager:Initialize(_: EngineTypes.EngineEnvironmentManager)
	print("Initializing server...")
end

function ClanManager:GetDefaultClan()
	return Clan.GetClans().NoClan
end

function ClanManager:GetClanFromName(clanName: string): GameTypes.Clan?
	for name: string, clan: GameTypes.Clan in Clan.GetClans() do
		if name == clanName then
			return clan
		end
	end

	return nil
end

function ClanManager:GetPlayerClan(player: Player): GameTypes.Clan
	local clan = player:FindFirstChild("ClanName") :: StringValue?
	if not clan then
		warn("Cannot get clan for player " .. player.UserId .. " assuming to be clan-less.")
		return self:GetDefaultClan()
	end

	local clanObject = nil
	for name: string, _clan: GameTypes.Clan in Clan.GetClans() do
		if name == clan.Value then
			clanObject = _clan
			break
		end
	end

	if not clanObject then
		error("Player contains invalid clan name. Invalid clan name: " .. clan.Value)
	end

	return clanObject
end

function ClanManager:SetPlayerClan(player: Player, newClan: GameTypes.Clan)
	local clan = player:FindFirstChild("Clan") :: StringValue?
	if not clan then
		error("Player uninitialized for ClanManager.")
	end

	if Clan.isClan(newClan) then
		clan.Value = newClan.Name
	else
		error("Attempted to set newClan to an invalid clan.")
	end

	return clan.Value
end

return ClanManager :: GameTypes.ClanManager
