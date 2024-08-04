--!strict
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local LocalPlayerCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() :: Model
local LocalPlayerHumanoid = LocalPlayerCharacter:WaitForChild("Humanoid") :: Humanoid
local LocalPlayerAnimator = LocalPlayerHumanoid:WaitForChild("Animator") :: Animator

local jumpTime = 0
local currentPose = "Idle"
local animationList: { [string]: { { id: string, weight: number, looping: boolean } } } = {
	Idle = {
		{ id = "rbxassetid://18459709103", weight = 9, looping = true },
	},
	Walk = { { id = "rbxassetid://18459797958", weight = 9, looping = true } },
	Running = { { id = "rbxassetid://18459226543", weight = 9, looping = true } },
	Jump = { { id = "rbxassetid://125750702", weight = 9, looping = false } },
	FreeFall = { { id = "rbxassetid://180436148", weight = 9, looping = true } },
}
local transitionTimes = {
	FreeFall = 0.3,
	Tool = 0.1,
	Jump = 0.1,
}
local jumpAnimationDuration: number = 0.667
local currentAnimationName: string = ""
-- local currentAnimSpeed: number = 1.0
local currentAnimation: Animation? = nil
local currentAnimationTrack: AnimationTrack? = nil

local animationTable: {
	[string]: {
		[number | string]: {
			anim: Animation,
			weight: number,
			looping: boolean,
		},
		connections: { RBXScriptConnection },
		count: number,
		totalWeight: number,
	},
} =
	{}

-- Avoid regression relating to multiple animations being loaded on the same humanoid, repeatedly.
for _, anim in LocalPlayerAnimator:GetPlayingAnimationTracks() do
	anim:Stop(0)
	anim:Destroy()
end

local preloaded = {}
local function preloadAnimation(animation: Animation, animator: Animator)
	if not preloaded[animation.AnimationId] then
		preloaded[animation.AnimationId] = true
	end
	local track = animator:LoadAnimation(animation)
	track:Destroy()
end

local function configureAnimationSet(
	name,
	fileList: { [string]: { { id: string, weight: number, looping: boolean } } },
	animator: Animator
)
	if animationTable[name] ~= nil then
		for _, connection in pairs(animationTable[name].connections) do
			connection:Disconnect()
		end
	end
	animationTable[name] = {} :: {
		[number]: {
			anim: Animation,
			weight: number,
			looping: boolean,
		},
		connections: { RBXScriptConnection },
		count: number,
		totalWeight: number,
	}
	animationTable[name].count = 0
	animationTable[name].totalWeight = 0
	animationTable[name].connections = {}

	-- check for config values
	local config = animator:FindFirstChild(name)
	if config then
		--		print("Loading anims " .. name)
		table.insert(
			animationTable[name].connections,
			config.ChildAdded:Connect(function(_)
				configureAnimationSet(name, fileList, animator)
			end)
		)
		table.insert(
			animationTable[name].connections,
			config.ChildRemoved:Connect(function(_)
				configureAnimationSet(name, fileList, animator)
			end)
		)
		local idx = 1
		for _, childPart in pairs(config:GetChildren()) do
			if childPart:IsA("Animation") then
				table.insert(
					animationTable[name].connections,
					childPart.Changed:Connect(function(_)
						configureAnimationSet(name, fileList, animator)
					end)
				)
				animationTable[name][idx] = { looping = false, weight = 1 } :: {
					anim: Animation,
					weight: number,
					looping: boolean,
				}

				preloadAnimation(childPart, animator)

				animationTable[name][idx].anim = childPart
				local weightObject = childPart:FindFirstChild("Weight") :: NumberValue
				if weightObject then
					animationTable[name][idx].weight = weightObject.Value
				end
				local shouldLoop = childPart:FindFirstChild("LoopAnimation") :: BoolValue
				if shouldLoop then
					animationTable[name][idx].looping = shouldLoop.Value
				end
				animationTable[name].count = animationTable[name].count + 1
				animationTable[name].totalWeight = animationTable[name].totalWeight + animationTable[name][idx].weight
				--			print(name .. " [" .. idx .. "] " .. animTable[name][idx].anim.AnimationId .. " (" .. animTable[name][idx].weight .. ")")
				idx = idx + 1
			end
		end
	end

	-- fallback to defaults
	if animationTable[name].count <= 0 then
		for idx, _anim in pairs(fileList) do
			local anim = _anim :: { id: string, weight: number, looping: boolean }
			animationTable[name][idx] = {} :: { anim: Animation, weight: number, looping: boolean }
			animationTable[name][idx].anim = Instance.new("Animation")
			animationTable[name][idx].anim.Name = name
			animationTable[name][idx].anim.AnimationId = anim.id
			animationTable[name][idx].weight = anim.weight
			animationTable[name][idx].looping = anim.looping
			animationTable[name].count = animationTable[name].count + 1
			animationTable[name].totalWeight = animationTable[name].totalWeight + anim.weight
			--			print(name .. " [" .. idx .. "] " .. anim.id .. " (" .. anim.weight .. ")")

			preloadAnimation(animationTable[name][idx].anim, animator)
		end
	end
end

local animationLock = false

local function playAnimation(
	animationName: string,
	transitionTime: number,
	animator: Animator,
	trackPriority: Enum.AnimationPriority
)
	if animationLock then
		return
	end
	animationLock = true
	if not animationTable[animationName] then
		warn("Unknown animation " .. animationName .. ". playAnimation call ignored.")
		animationLock = false
		return
	end

	local roll = math.random(1, animationTable[animationName].totalWeight)
	local idx = 1
	while roll > animationTable[animationName][idx].weight do
		roll = roll - animationTable[animationName][idx].weight
		idx = idx + 1
	end

	local selectedAnimation = animationTable[animationName][idx].anim
	local shouldLoop = animationTable[animationName][idx].looping

	if currentAnimation and currentAnimation.AnimationId == selectedAnimation.AnimationId then
		local tracks = animator:GetPlayingAnimationTracks()
		if #tracks > 200 then
			warn("Clearning playing animations; +200 playing tracks!")
			for _, track in tracks do
				track:Stop(0)
				track:Destroy()
			end
		end
		animationLock = false
		return
	end

	if currentAnimationTrack then
		currentAnimationTrack:Stop(transitionTime)
		currentAnimationTrack:Destroy()
	end

	-- currentAnimSpeed = 1.0

	-- load it to the humanoid; get AnimationTrack
	currentAnimationTrack = animator:LoadAnimation(selectedAnimation)
	if not currentAnimationTrack then
		warn("Failed to load animation track?")
		animationLock = false
		return
	end
	currentAnimationTrack.Priority = trackPriority or Enum.AnimationPriority.Core
	if shouldLoop then
		currentAnimationTrack.Looped = true
	end

	-- play the animation
	currentAnimationTrack:Play(transitionTime)
	currentAnimationName = animationName
	currentAnimation = selectedAnimation:Clone() -- Clone it to prevent it being by reference. Allows us to compare AnimationIds instead.
	animationLock = false
end

--#region hi

--#endregion

local function reloadFromSettings()
	local nList = {}
	for _, _instanceList in LocalPlayerAnimator:GetChildren() do
		local instanceList = _instanceList :: Configuration
		nList[instanceList.Name] = {}

		for _, _animation in instanceList:GetChildren() do
			local animation = _animation :: { LoopAnimation: BoolValue, Weight: NumberValue } & Animation
			local newTable = {}
			newTable.id = animation.AnimationId
			newTable.looping = animation.LoopAnimation.Value
			newTable.weight = animation.Weight.Value

			table.insert(nList[instanceList.Name], newTable)
		end
	end

	for name, l in nList do
		configureAnimationSet(name, l :: any, LocalPlayerAnimator)
	end

	-- The animations have been mutated. We must reload the animations to play again, therefore, we will load in Idle, and then swap back to the old one asap.
	-- We will add a smooth transition time to prevent pop-ins.

	local priority: Enum.AnimationPriority = Enum.AnimationPriority.Core

	if currentAnimationName == "Running" or currentAnimationName == "Walk" then
		priority = Enum.AnimationPriority.Movement
	elseif currentAnimationName == "Idle" then
		priority = Enum.AnimationPriority.Idle
	end

	for _, animationTrack in LocalPlayerAnimator:GetPlayingAnimationTracks() do
		animationTrack:Stop(0.2)
		animationTrack:Destroy()
	end
	currentAnimationTrack = nil
	currentAnimation = nil

	playAnimation(currentAnimationName, 0.2, LocalPlayerAnimator, priority)
end

local function stopAllAnimations()
	local oldAnimationName = currentAnimationName
	currentAnimationName = ""

	if currentAnimationTrack then
		currentAnimationTrack:Stop()
		currentAnimationTrack:Destroy()
		currentAnimationTrack = nil
	end
	return oldAnimationName
end

--#region Humanoid Connections

LocalPlayerHumanoid.Died:Connect(function()
	currentPose = "Dead"
end)

LocalPlayerHumanoid.Climbing:Connect(function()
	currentPose = "Climbing"
end)

LocalPlayerHumanoid.GettingUp:Connect(function()
	currentPose = "GettingUp"
end)

LocalPlayerHumanoid.FallingDown:Connect(function()
	currentPose = "FallingDown"
end)

LocalPlayerHumanoid.Seated:Connect(function()
	currentPose = "Seated"
end)

LocalPlayerHumanoid.PlatformStanding:Connect(function()
	currentPose = "PlatformStanding"
end)

LocalPlayerHumanoid.FreeFalling:Connect(function()
	currentPose = "FreeFall" -- TODO: Implement freefall behaviour.
end)

LocalPlayerHumanoid.Running:Connect(function(speed)
	if speed > 0.01 then
		if speed <= 17 then
			playAnimation("Walk", 0.1, LocalPlayerAnimator, Enum.AnimationPriority.Movement)
		else
			playAnimation("Running", 0.1, LocalPlayerAnimator, Enum.AnimationPriority.Movement)
		end
		currentPose = "Running"
	else
		playAnimation("Idle", 0.1, LocalPlayerAnimator, Enum.AnimationPriority.Idle)
		currentPose = "Standing"
	end
end)

LocalPlayerHumanoid.Jumping:Connect(function()
	playAnimation("Jump", transitionTimes.Jump, LocalPlayerAnimator, Enum.AnimationPriority.Movement)
	jumpTime = jumpAnimationDuration
	currentPose = "Jumping"
end)

--#endregion

local lastTick: number = 0
local function animation_tick(timePassed: number)
	-- local amplitude = 1
	-- local frequency = 1
	-- local setAngles = false
	local deltaTime = timePassed - lastTick
	lastTick = timePassed

	if jumpTime > 0 then
		jumpTime -= deltaTime
	end

	if currentPose == "FreeFall" and jumpTime <= 0 then
		playAnimation("FreeFall", transitionTimes.FreeFall, LocalPlayerAnimator, Enum.AnimationPriority.Core)
	elseif currentPose == "Seated" then
		playAnimation("Sit", 0.5, LocalPlayerAnimator, Enum.AnimationPriority.Core)
		return
		-- elseif currentPose == "Running" then

		-- playAnimation("Walk", 0.1, LocalPlayerAnimator, Enum.AnimationPriority.Movement)
	elseif
		currentPose == "Dead"
		or currentPose == "GettingUp"
		or currentPose == "FallingDown"
		or currentPose == "Seated"
		or currentPose == "PlatformStanding"
	then
		--		print("Wha " .. pose)
		stopAllAnimations()
		-- amplitude = 0.1
		-- frequency = 1
		-- setAngles = true
	end
end

for name, fileList in animationList do
	-- Compose the animation table into settings.
	local instanceContainer = Instance.new("Configuration")
	instanceContainer.Name = name
	instanceContainer.Parent = LocalPlayerAnimator
	for idx, tbl in fileList do
		local animation = Instance.new("Animation")
		animation.Name = "Animation" .. idx
		animation.AnimationId = tbl.id
		animation.Parent = instanceContainer

		local isLooping = Instance.new("BoolValue")
		isLooping.Parent = animation
		isLooping.Value = tbl.looping
		isLooping.Name = "LoopAnimation"

		local animationWeight = Instance.new("NumberValue")
		animationWeight.Parent = animation
		animationWeight.Value = tbl.weight
		animationWeight.Name = "Weight"

		animation.Changed:Connect(function(property: string)
			if property == "AnimationId" then
				-- Refresh animation fromconfig
				reloadFromSettings()
				preloadAnimation(animation, LocalPlayerAnimator)
			end
		end)
	end
end

for name, fileList in animationList do
	configureAnimationSet(name, fileList :: any, LocalPlayerAnimator)
end

-- LocalPlayerAnimator.DescendantAdded:Connect(reloadFromSettings)
-- LocalPlayerAnimator.DescendantRemoving:Connect(reloadFromSettings)

playAnimation("Idle", 0.1, LocalPlayerAnimator, Enum.AnimationPriority.Core)
currentPose = "Standing"

task.spawn(function()
	while true do
		task.wait()
		animation_tick(elapsedTime())
	end
end)
