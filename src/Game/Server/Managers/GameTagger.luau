--!strict
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)

local module = moduleBaseConstructor.new()

module.ModuleName = "Managers/GameTagger"

function module:PreInitialize(_: EngineTypes.EngineEnvironmentManager)
	game.DescendantAdded:Connect(function(instance: Instance)
		if instance:IsA("Humanoid") and instance.Parent and not instance.Parent:HasTag("HumanoidContainer") then
			instance.Parent:AddTag("HumanoidContainer")
		end
	end)

	for _, model in workspace:GetDescendants() do
		if model:FindFirstChildWhichIsA("Humanoid") and not model:HasTag("HumanoidContainer") then
			model:AddTag("HumanoidContainer")
		end
	end
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager) end

return module
