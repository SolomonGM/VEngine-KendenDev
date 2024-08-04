--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)
local GameTypes = require(ReplicatedFirst.Shared.GameTypes)

local module = moduleBaseConstructor.new() :: EngineTypes.BaseEngineModule & GameTypes.PlayerBridge

module.ModuleName = "Shared/Bridges/PlayerBridge"

function module:PreInitialize(envManager: EngineTypes.EngineEnvironmentManager)
	-- Init events.
	local replicatedEventFactory = envManager.GetEngineGlobals().EngineSharedReplicatedEvent
	module.Events = {
		SetRunning = replicatedEventFactory:CreateEvent("__set_running", function(uid: number, b: boolean)
			if typeof(uid) ~= "number" or typeof(b) ~= "boolean" then
				error("Invalid type for given arguments.")
			end

			return uid, b
		end),

		SetRagdoll = replicatedEventFactory:CreateEvent("__set_ragdoll", function(uid: number, b: boolean)
			if typeof(uid) ~= "number" or typeof(b) ~= "boolean" then
				error("Invalid type for given arguments.")
			end

			return uid, b
		end),

		PerformDash = replicatedEventFactory:CreateEvent(
			"__perform_dash",
			replicatedEventFactory.Validators.NoArgumentsValidator
		),

		PerformDash_Acknowledgement = replicatedEventFactory:CreateEvent("__perform_dash_ack", function(canPerform)
			assert(typeof(canPerform) == "boolean", "Invalid type for given argument")

			return canPerform
		end),

		--[[SetClan = replicatedEventFactory:CreateEvent("__set_clan", function(uid: number, clanName: string)
            if typeof(uid) ~= "number" or typeof(clanName) ~= "string" then
                error("Invalid type for given arguments.")
            end
            return uid, clanName
        end),]]
	}
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager)
	print("Initializing server...")
end

function module:SetIsRunning(targetUserId: number, mode: boolean)
	if RunService:IsClient() and Players.LocalPlayer.UserId ~= targetUserId then
		warn("Cannot set a player to run when it is not yourself.") -- If this check is skipped, most likely a cheater...
		return
	end

	if targetUserId == Players.LocalPlayer.UserId and Players.LocalPlayer.Character then
		local isRunning = Players.LocalPlayer.Character:FindFirstChild("IsRunning") :: BoolValue?
		if isRunning and isRunning:IsA("BoolValue") and isRunning.Value == mode then
			return -- We don't need to waste resources. It is unnecessary.
		end
	end

	self.Events.SetRunning:FireServer(targetUserId, mode)
end

function module:SetRagdoll(targetUserId: number, mode: boolean)
	if RunService:IsClient() and Players.LocalPlayer.UserId ~= targetUserId then
		warn("Cannot set a player to ragdoll when it is not yourself.") -- If this check is skipped, most likely a cheater...
		return
	end

	if targetUserId == Players.LocalPlayer.UserId and Players.LocalPlayer.Character then
		local isRagdolled = Players.LocalPlayer.Character:FindFirstChild("IsRagdolled") :: BoolValue?
		if isRagdolled and isRagdolled:IsA("BoolValue") and isRagdolled.Value == mode then
			return -- We don't need to waste resources. It is unnecessary.
		end
	end

	self.Events.SetRagdoll:FireServer(targetUserId, mode)
end

function module:TryPerformDash()
	self.Events.PerformDash:FireServer()
	return self.Events.PerformDash_Acknowledgement:WaitRemote()
end

--[[
	--! This event should not be really exposed.
	function module:SetClan(targetUserId: number, clanName: string)
		if RunService:IsClient() and Players.LocalPlayer.UserId ~= targetUserId then
			warn("Cannot set a player clan when it is not yourself.")
			return
		end

		if targetUserId == Players.LocalPlayer.UserId and Players.LocalPlayer.Character then
			local clan = Players.LocalPlayer.Character:FindFirstChild("Clan") :: StringValue?
			if clan and clan:IsA("StringValue") and clan.Value == clanName then
				return
			end
		end

		self.Events.SetClan:FireServer(targetUserId, clanName)
	end
]]
return module
