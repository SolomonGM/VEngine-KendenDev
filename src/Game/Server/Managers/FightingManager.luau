--!strict
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)
local GameTypes = require(ReplicatedFirst.Shared.GameTypes)

local RagdollManager: GameTypes.RagdollManager
local FightingBridge: GameTypes.FightingBridge

local module = moduleBaseConstructor.new() :: EngineTypes.BaseEngineModule & GameTypes.FightingManager

module.ModuleName = "Managers/FightingManager"

local function GetCharactersOfPlayers(denyList: { Player }): { Model }
	local denyIds = {} :: { number }
	for _, player in denyList do
		if typeof(player) == "Player" then
			table.insert(denyIds, player.UserId)
		end
	end

	local playersCharacters = {}
	for _, possibleCharacter in CollectionService:GetTagged("HumanoidContainer") do
		local player = Players:GetPlayerFromCharacter(possibleCharacter :: Model)
		if player and table.find(denyIds, player.UserId) then
			print("Skipped Blacklisted player with uid " .. player.UserId)
			continue -- Skip blacklisted player.
		end

		if player and not player.Character then
			continue
		end
		table.insert(playersCharacters, possibleCharacter)
	end

	return (playersCharacters :: { any }) :: { Model }
end

function module:PreInitialize(envManager: EngineTypes.EngineEnvironmentManager)
	FightingBridge = (envManager:GetEngineModule("Shared/Bridges/FightingBridge") :: any) :: GameTypes.FightingBridge
	RagdollManager = (envManager:GetEngineModule("Managers/RagdollManager") :: any) :: GameTypes.RagdollManager
	local hitboxName = RunService:IsStudio() and "Player_Fighting_Hitbox" or ""
	FightingBridge.Events.CreateHitbox:OnFire(
		function(
			player: Player,
			hitboxType: GameTypes.HitboxType,
			cameraPosition: CFrame,
			hitboxPosition: CFrame,
			hitboxSize: Vector3,
			hitboxProjection: string
		)
			if not player.Character then
				return -- Cannot create a hitbox when dead.
			end

			local hitboxAndPlayerVec = hitboxPosition.Position - player.Character:GetPivot().Position
			if hitboxAndPlayerVec.Magnitude > 10 then
				print(hitboxAndPlayerVec.Magnitude)
				warn("Player requested a hitbox too far away from them")
				return
			end

			if hitboxSize.Magnitude > 15 then
				print(hitboxSize.Magnitude)
				warn("Player requested a hitbox that was too big.")
				return
			end

			local possibleTypes = Enum.PartType:GetEnumItems()

			local partType: Enum.PartType

			for _, possibleEnum: EnumItem in possibleTypes do
				if hitboxProjection == possibleEnum.Name then
					partType = possibleEnum :: Enum.PartType
					break
				end
			end

			if not partType then
				error("Invalid hitbox projection")
			end

			local affectedCharacters: { Model & { Humanoid: Humanoid } }
			do
				local hitbox = Instance.new("Part")
				hitbox.Name = hitboxName
				hitbox.CFrame = hitboxPosition
				hitbox.Shape = partType
				hitbox.Size = hitboxSize
				hitbox.Anchored = true
				hitbox.Color = hitboxType == "KnockBack" and Color3.new(0.1, 1.000000, 0.564706)
					or hitboxType == "MouseOneNormal" and Color3.new(1, 0, 0)
					or hitboxType == "MouseOneHeavy" and Color3.new(1, 1, 0)
					or Color3.new(0, 0, 0)
				hitbox.Transparency = RunService:IsStudio() and 0.4 or 1
				hitbox.Parent = workspace
				hitbox.CanCollide = true
				hitbox.CanQuery = true

				local params = OverlapParams.new()
				params.FilterDescendantsInstances = { table.unpack(GetCharactersOfPlayers({ player })) }
				params.FilterType = Enum.RaycastFilterType.Include

				local parts = workspace:GetPartsInPart(hitbox, params)
				hitbox.CanCollide = false
				hitbox.CanQuery = false

				Debris:AddItem(hitbox, 1)

				if not parts or #parts == 0 then
					return
				end

				affectedCharacters = {} :: { Model & { Humanoid: Humanoid & { Animator: Animator } } }
				for _, part in parts do
					if not part.Parent or not part.Parent:FindFirstChild("Humanoid") then
						continue -- Ignore parts whose' parent is not a Model and the parent doesn't contain a humanoid
					end
					if table.find(affectedCharacters, part.Parent :: any) then
						continue -- Clean dupes
					end
					table.insert(affectedCharacters, part.Parent :: any)
				end
			end

			if hitboxType == "KnockBack" then
				for _, character in affectedCharacters do
					-- Play hit animation
					-- character.Humanoid:LoadAnimation()
					if not player.Character or player.Character and player.Character.Name == character.Name then
						continue
					end
					if
						not character:FindFirstChild("HumanoidRootPart")
						or not character.PrimaryPart
						or player.Character and not player.Character.PrimaryPart
					then
						warn("Malformed character or characters; Knockback will not be applied..")
						continue
					end

					local velocity: LinearVelocity = Instance.new("LinearVelocity")
					velocity.Attachment0 = (character:FindFirstChild("HumanoidRootPart") :: BasePart):FindFirstChild(
						"RootAttachment"
					) :: Attachment?
					if not velocity.Attachment0 then
						warn(
							"Cannot knockback: Missing RootAttachment under the characters' PrimaryPart, this is most likely caused by a bad rig; Knockback not applied"
						)
						continue
					end
					velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
					velocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
					velocity.VectorVelocity = cameraPosition.LookVector * 100
					velocity.ForceLimitsEnabled = false
					velocity.Parent = character
					for _, part in character:GetDescendants() do
						if part:IsA("BasePart") then
							part.Anchored = false
						end
					end

					(character.PrimaryPart :: BasePart).Touched:Once(function(_: BasePart)
						velocity:Destroy()
						RagdollManager:RagdollRig(character)
					end)

					if character.PrimaryPart then
						character.PrimaryPart:ApplyAngularImpulse(
							Vector3.new(math.random(10, 30), math.random(10, 30), math.random(10, 30))
						)
					end
					for _, part in character:GetDescendants() do
						-- Note: This is stupid. We must loop twice, as if any part that is welded to this one is anchored, this call will fail, and f us over.
						if part:IsA("BasePart") then
							part:SetNetworkOwner(nil)
						end
					end
					Debris:AddItem(velocity, 0.8)
					local isPlayerCharacter = Players:GetPlayerFromCharacter(character) and true or false
					local playerFromDynamicCharacter = Players:GetPlayerFromCharacter(character) :: Player?
					for _, part in character:GetDescendants() do
						if part:IsA("BasePart") then
							part.Anchored = false
							part:SetNetworkOwner(isPlayerCharacter and playerFromDynamicCharacter or nil) -- Set the net ownership appropiately.
						end
					end

					task.delay(1.5, function()
						RagdollManager:UnragdollRig(character)
					end)
				end
			elseif hitboxType == "MouseOneHeavy" then
				local sounds = { "rbxassetid://18500251268" }
				for _, character in affectedCharacters do
					-- Play hit animation
					-- character.Humanoid:LoadAnimation()
					if player.Character.Name == character.Name then
						continue
					end

					local hitSfx = Instance.new("Sound")
					local primaryPart = character.PrimaryPart
					if not primaryPart then
						warn("Invalid primary part, finding the first BasePart")
						hitSfx.Parent = character:FindFirstChildOfClass("BasePart")
					else
						hitSfx.Parent = primaryPart
					end

					hitSfx.SoundId = sounds[math.random(1, #sounds)]
					hitSfx.Volume = 0.7
					hitSfx:Play()
					Debris:AddItem(hitSfx, hitSfx.TimeLength + player:GetNetworkPing() * 2)

					if primaryPart then
						primaryPart:ApplyImpulse(cameraPosition.LookVector * 200)
					end

					character.Humanoid:TakeDamage(25)
				end
			elseif hitboxType == "MouseOneNormal" then
				local sounds = { "rbxassetid://8595980577", "rbxassetid://8595983255", "rbxassetid://9117969687" }
				for _, character in affectedCharacters do
					-- Play hit animation
					-- character.Humanoid:LoadAnimation()
					if player.Character.Name == character.Name then
						continue
					end

					local hitSfx = Instance.new("Sound")
					local primaryPart = character.PrimaryPart
					if not primaryPart then
						warn("Invalid primary part, finding the first BasePart")
						hitSfx.Parent = character:FindFirstChildOfClass("BasePart")
					else
						hitSfx.Parent = primaryPart
					end

					hitSfx.SoundId = sounds[math.random(1, #sounds)]
					hitSfx.Volume = 0.7
					hitSfx:Play()

					Debris:AddItem(hitSfx, hitSfx.TimeLength + player:GetNetworkPing() * 2)
					if primaryPart then
						primaryPart:ApplyImpulse(cameraPosition.LookVector * 200)
					end
					character.Humanoid:TakeDamage(15)
				end

				-- error("Not implemented")
			end
		end,
		false,
		false
	)
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager) end

return module :: GameTypes.FightingManager
