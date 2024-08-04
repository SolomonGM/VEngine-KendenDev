--!strict
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)
local moduleBaseConstructor = require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineModule"))

local module = moduleBaseConstructor.new()

module.ModuleName = "ClientInitialization"

function module:PreInitialize(_: EngineTypes.EngineEnvironmentManager?)
	ContentProvider:PreloadAsync({
		"",
		"",
	})
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager) end

return module
