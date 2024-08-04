--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameTypes = require(ReplicatedFirst.Shared.GameTypes)
local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)
local moduleBaseConstructor = require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineModule"))

local FightingBridge: GameTypes.FightingBridge

local module = moduleBaseConstructor.new() :: EngineTypes.BaseEngineModule & GameTypes.CombatTool

module.ModuleName = "Tools/Combat"

function module:PreInitialize(envManager: EngineTypes.EngineEnvironmentManager)
	print("Pre-Initiaialization step...")
	FightingBridge = (envManager:GetEngineModule("Shared/Bridges/FightingBridge") :: any) :: GameTypes.FightingBridge

	module.LoadedAnimationPack = {} :: any
	module.Connections = {} :: any

	local function onCharacterAdded(_: Model)
		local combatTool = Players.LocalPlayer.Backpack:WaitForChild("Combat")
		if combatTool.Name == "Combat" and combatTool:IsA("Tool") then
			module:ConnectTool(combatTool)
		end
	end

	if Players.LocalPlayer.Character then
		onCharacterAdded(Players.LocalPlayer.Character)
	end

	Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager) end

function module:ReloadCurrentAnimationPack()
	local currentAnimationPack = Players.LocalPlayer:FindFirstChild("FightingStyle") :: StringValue?
	if not currentAnimationPack then
		error("Player not initialized? Cannot reload animation pack.")
	end

	local animations = self:GetAnimationPack(currentAnimationPack.Value :: GameTypes.CombatStyle)

	if animations then
		local playerAnimator = (
				Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
			):WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator

		local function preloadAnimation(animation: Animation)
			local track = playerAnimator:LoadAnimation(animation)
			track:Destroy()
		end
		-- Preload animations

		preloadAnimation(animations.MouseOnes[1])
		preloadAnimation(animations.MouseOnes[2])
		preloadAnimation(animations.MouseOnes[3])
		preloadAnimation(animations.MouseOnes[4])
		preloadAnimation(animations.MouseOnes[5])

		preloadAnimation(animations.HeavyAttack)
		preloadAnimation(animations.Block)
		preloadAnimation(animations.Idle)
		preloadAnimation(animations.Walk)
	end

	self.LoadedAnimationPack = animations
end

function module:GetAnimationPack(packName: GameTypes.CombatStyle)
	local animations = ReplicatedStorage:WaitForChild("Fighting"):WaitForChild("Animations")
	if not animations:FindFirstChild(packName) then
		error("Invalid animation pack;")
	end

	local animationPack = animations:WaitForChild(packName)
	local mainAttacks = animationPack:WaitForChild("MainAttacks")

	return {
		PackName = packName,
		MouseOnes = {
			[1] = mainAttacks:WaitForChild("Attack_1") :: Animation,
			[2] = mainAttacks:WaitForChild("Attack_2") :: Animation,
			[3] = mainAttacks:WaitForChild("Attack_3") :: Animation,
			[4] = mainAttacks:WaitForChild("Attack_4") :: Animation,
			[5] = mainAttacks:WaitForChild("Attack_5") :: Animation,
		},
		HeavyAttack = animationPack:WaitForChild("HeavyAttack") :: Animation,
		Idle = animationPack:WaitForChild("Idle") :: Animation,
		Block = animationPack:WaitForChild("Block") :: Animation,
		Walk = animationPack:WaitForChild("Walk") :: Animation,
	}
end

function module:ConnectTool(tool: Tool)
	local m1Count = 1
	local currentTrack: AnimationTrack? = nil

	for _, connection in module.Connections do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end

	local originalIdleId: string
	local originalWalkId: string

	table.insert(
		module.Connections,
		tool.Equipped:Connect(function(_playerMouse: Mouse)
			-- Define Idle and Walk animations by manipulating the custom Animate script at RT.
			-- Still, for this we will need a little more time, because im lazy af LMAO.
			-- - Dottik, aka, Acetaminophen86.

			local currentAnimationPack = Players.LocalPlayer:FindFirstChild("FightingStyle") :: StringValue?
			if not currentAnimationPack then
				error("Player not initialized? Cannot use Fighting tool.")
			end

			local playerAnimator = (
					Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
				):WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator

			local animationPack = self.LoadedAnimationPack

			if
				not animationPack
				or not animationPack.PackName
				or not animationPack.MouseOnes
				or not animationPack.Idle
				or not animationPack.Walk
				or not animationPack.Block
				or not animationPack.HeavyAttack
			then
				print("Reloading animation pack...")
				self.LoadedAnimationPack = {} :: any
				module:ReloadCurrentAnimationPack()
				animationPack = self.LoadedAnimationPack

				if not animationPack then
					error("Cannot use fighting tool. Animation load failed.")
				end
			end

			print("Tool equipped")
			local idle = playerAnimator:WaitForChild("Idle") :: Configuration
			local original: Animation = idle:WaitForChild("Animation1") :: Animation
			originalIdleId = original.AnimationId

			original.AnimationId = animationPack.Idle.AnimationId

			local walk = playerAnimator:WaitForChild("Walk") :: Configuration
			original = walk:WaitForChild("Animation1") :: Animation
			originalWalkId = original.AnimationId

			original.AnimationId = animationPack.Walk.AnimationId
		end)
	)

	table.insert(
		module.Connections,
		tool.Unequipped:Connect(function(_playerMouse: Mouse)
			local currentAnimationPack = Players.LocalPlayer:FindFirstChild("FightingStyle") :: StringValue?
			if not currentAnimationPack then
				error("Player not initialized? Cannot use Fighting tool.")
			end

			print("Tool unequipped")
			local playerAnimator = (
					Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
				):WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator

			local idle = playerAnimator:WaitForChild("Idle") :: Configuration
			local original: Animation = idle:WaitForChild("Animation1") :: Animation

			original.AnimationId = originalIdleId

			local walk = playerAnimator:WaitForChild("Walk") :: Configuration
			original = walk:WaitForChild("Animation1") :: Animation

			original.AnimationId = originalWalkId
		end)
	)

	local hitMutex = false
	table.insert(
		module.Connections,
		tool.Activated:Connect(function()
			if
				hitMutex
				or not Players.LocalPlayer.Character
				or ((Players.LocalPlayer.Character :: any) :: GameTypes.PlayerCharacter).IsRagdolled.Value -- Player ragdolled, not allow to use tool
			then
				return
			end
			hitMutex = true
			local currentAnimationPack = Players.LocalPlayer:FindFirstChild("FightingStyle") :: StringValue?
			if not currentAnimationPack then
				hitMutex = false
				error("Player not initialized? Cannot use Fighting tool.")
			end

			local playerCharacter = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
			local playerAnimator = (playerCharacter):WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator

			local animationPack = self.LoadedAnimationPack

			if
				not animationPack
				or animationPack.PackName ~= currentAnimationPack.Value
				or not animationPack.PackName
				or not animationPack.MouseOnes
				or not animationPack.Idle
				or not animationPack.Walk
				or not animationPack.Block
				or not animationPack.HeavyAttack
			then
				print("Reloading animation pack...")
				self.LoadedAnimationPack = {} :: any
				module:ReloadCurrentAnimationPack()
				animationPack = self.LoadedAnimationPack

				if not animationPack then
					hitMutex = false
					error("Cannot use fighting tool. Animation load failed.")
				end
			end

			local currentM1 = animationPack.MouseOnes[m1Count]

			if currentTrack then
				currentTrack:Stop(0.1)
				currentTrack:Destroy()
				currentTrack = nil
			end

			currentTrack = playerAnimator:LoadAnimation(currentM1)
			if not currentTrack then
				hitMutex = false
				error("Error. Just, error.")
			end
			currentTrack:Play(0.1, 1, 1)

			local rootPart = playerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart
			local hitboxCframe = CFrame.new(
				(rootPart).CFrame.LookVector + rootPart.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -4))
			) * playerCharacter:GetPivot()

			m1Count += 1

			if m1Count == 6 then
				m1Count = 1
				FightingBridge:CreateRemoteHitbox(
					"KnockBack",
					workspace.CurrentCamera.CFrame,
					CFrame.new(hitboxCframe.Position) * CFrame.Angles(0, math.rad(hitboxCframe.Rotation.Y), 0),
					Vector3.new(6, 5.1, 6),
					Enum.PartType.Block
				)
			else
				FightingBridge:CreateRemoteHitbox(
					"MouseOneNormal",
					workspace.CurrentCamera.CFrame,
					CFrame.new(hitboxCframe.Position) * CFrame.Angles(0, math.rad(hitboxCframe.Rotation.Y), 0),
					Vector3.new(6, 5.1, 6),
					Enum.PartType.Block
				)
			end

			task.delay(
				(currentTrack.Length - currentTrack.Length / 7) - Players.LocalPlayer:GetNetworkPing(),
				function()
					hitMutex = false
				end
			)
		end)
	)
end

return module :: GameTypes.CombatTool
