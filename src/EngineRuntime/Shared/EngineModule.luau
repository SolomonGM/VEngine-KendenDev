--!strict

local moduleConstructor = {}

local Types = require(game:GetService("ReplicatedFirst"):WaitForChild("EngineShared"):WaitForChild("EngineTypes"))

function moduleConstructor.new(): Types.BaseEngineModule
	--- The base of a module in VEngine, containing the minimum required methods and properties to initialize one.
	--- @class BaseEngineModule
	local module = {}

	module.ModuleName = "EngineModule"
	module.LoadOrder = 0

	function module:PreInitialize(_: Types.EngineEnvironmentManager)
		error(
			"This has to be overriden by you, the developer. You should override it to give your module functionality!"
		)
	end

	function module:Initialize(_: Types.EngineEnvironmentManager)
		print(
			"This has not been overriden by you, the developer. You should override it to give your module functionality!"
		)
	end

	return module :: Types.BaseEngineModule
end

return moduleConstructor
