--!strict
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)
local GameTypes = require(ReplicatedFirst.Shared.GameTypes)

local module = moduleBaseConstructor.new() :: EngineTypes.BaseEngineModule & GameTypes.FightingBridge

module.ModuleName = "Shared/Bridges/FightingBridge"

function module:PreInitialize(envManager: EngineTypes.EngineEnvironmentManager)
	-- Init events.
	local replicatedEventFactory = envManager.GetEngineGlobals().EngineSharedReplicatedEvent
	module.Events = {
		CreateHitbox = replicatedEventFactory:CreateEvent(
			"__create__hitbox",
			function(
				hitboxType: GameTypes.HitboxType,
				cameraPosition: CFrame,
				hitboxPosition: CFrame,
				hitboxSize: Vector3,
				hitboxProjection: string
			)
				if
					typeof(hitboxType) ~= "string"
					or typeof(cameraPosition) ~= "CFrame"
					or typeof(hitboxPosition) ~= "CFrame"
					or typeof(hitboxSize) ~= "Vector3"
					or typeof(hitboxProjection) ~= "string"
				then
					error("Invalid type for given arguments.")
				end

				-- Type issues cause this cast to any.
				return hitboxType :: any, cameraPosition, hitboxPosition, hitboxSize, hitboxProjection
			end
		),
	}
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager) end

function module:CreateRemoteHitbox(
	hitboxType: GameTypes.HitboxType,
	cameraPosition: CFrame,
	hitboxPosition: CFrame,
	hitboxSize: Vector3,
	hitboxProjection: Enum.PartType
)
	if RunService:IsServer() then
		warn("Cannot set a player to ragdoll when it is not yourself.") -- If this check is skipped, most likely a cheater...
		return
	end

	self.Events.CreateHitbox:FireServer(hitboxType, cameraPosition, hitboxPosition, hitboxSize, hitboxProjection.Name)
end

return module :: GameTypes.FightingBridge
