--!strict
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)

local module = moduleBaseConstructor.new() :: any

module.ModuleName = "Shared/Bridges/ReplicatorBridge"

function module:PreInitialize(envManager: EngineTypes.EngineEnvironmentManager)
	-- Init events.
	local replicatedEventFactory = envManager.GetEngineGlobals().EngineSharedReplicatedEvent
	module.Events = {}

	print("Replicator bridge is ready to replicate, the world!")
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager) end

return module
