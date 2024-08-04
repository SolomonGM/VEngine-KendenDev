--!strict
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)
local GameTypes = require(ReplicatedFirst.Shared.GameTypes)

local module = moduleBaseConstructor.new() :: EngineTypes.BaseEngineModule & GameTypes.BanIdentifiers

module.ModuleName = "BanIdentifiers"

function module:PreInitialize(_: EngineTypes.EngineEnvironmentManager)
	module.BanIdentifiers = table.freeze({
		SuspectedCheating = "0x0",
		ValidationBypass = "0x1",
	})
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager) end

function module:GetBanIdentifiers()
	return self.BanIdentifiers
end

return module :: GameTypes.BanIdentifiers
