--!strict
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local LoggerModule = require(ReplicatedFirst.EngineShared.Logger)
local EngineTypes = require(game:GetService("ReplicatedFirst"):WaitForChild("EngineShared"):WaitForChild("EngineTypes"))

local moduleBaseConstructor = require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineModule"))

local AudioManager: EngineTypes.EngineAudioManager = moduleBaseConstructor.new() :: EngineTypes.EngineAudioManager

local IsInitialized = false

local function InitializeIfUninitialized()
	if not IsInitialized then
		AudioManager:Initialize(require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineEnvironment")))
	end
end

AudioManager.ModuleName = "Engine/EngineAudioManager"

function AudioManager:Initialize(_: EngineTypes.EngineEnvironmentManager)
	if IsInitialized then
		return -- Avoid Re-Initialization.
	end
	for _, func in AudioManager :: { () -> () } do
		if typeof(func) == "function" then
			local l =
				LoggerModule.new(string.format("VEngine::Module::Client::'%s'", AudioManager.ModuleName), false, 4)
			l:PolluteEnvironment(func)
		end
	end

	AudioManager.SfxFolder = Instance.new("Folder")
	AudioManager.SfxFolder.Parent = workspace
	AudioManager.SfxFolder.Name = "Sound__AudioManagerManaged"

	AudioManager.SoundCache = {} :: { [string]: Sound }
	IsInitialized = true
end

--- Obtain a sound from the AudioManager cache.
--- @param soundName string The name of the sound.
--- @return Sound? sound The sound that was cached. May be nil if it is not loaded.
function AudioManager:GetSound(soundName: string): Sound?
	InitializeIfUninitialized()
	task.synchronize()
	return self.SoundCache[soundName]
end

function AudioManager:FadeIn(
	soundName: string,
	targetVolume: number,
	fadeInTime: number,
	fadeEasing: Enum.EasingStyle
): RBXScriptSignal?
	InitializeIfUninitialized()
	if not soundName then
		error("No sound name provided.")
		return
	end
	if not targetVolume then
		targetVolume = 0.5
	end
	if not fadeInTime then
		fadeInTime = 0
	end
	if not fadeEasing then
		fadeEasing = Enum.EasingStyle.Sine
	end
	if not self.SoundCache[soundName] then
		error(
			`Cannot obtain sound {soundName} as the AudioManager does not acknowledge it as a loaded sound! Have you forgotten to initialize the AudioManager?`
		)
		return nil
	end

	local sound = self.SoundCache[soundName]
	sound:Stop()
	local t = TweenService:Create(sound, TweenInfo.new(fadeInTime, fadeEasing), {
		Volume = targetVolume,
	})
	sound.Volume = 0.00001
	sound:Play()
	task.wait()
	t:Play()
	return t.Completed
end

function AudioManager:FadeOut(soundName: string, fadeOutTime: number, fadeEasing: Enum.EasingStyle): RBXScriptSignal?
	InitializeIfUninitialized()
	if not soundName then
		error("No sound name provided.")
		return
	end
	if not fadeOutTime then
		fadeOutTime = 0
	end
	if not fadeEasing then
		fadeEasing = Enum.EasingStyle.Sine
	end
	if not self.SoundCache[soundName] then
		error(
			`Cannot obtain sound {soundName} as the AudioManager does not acknowledge it as a loaded sound! Have you forgotten to initialize the AudioManager?`
		)
		return nil
	end
	task.synchronize()

	local sound = self.SoundCache[soundName]
	local t = TweenService:Create(sound, TweenInfo.new(fadeOutTime, fadeEasing), {
		Volume = 0,
	})
	t:Play()
	t.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			sound:Pause()
			sound.Volume = 0.5 -- Set volume to default.
		end
	end)
	return t.Completed
end

function AudioManager:GetSoundContainer(): Folder
	InitializeIfUninitialized()
	return self.SfxFolder
end

function AudioManager:StopAllSounds(exclusionList: { string })
	task.synchronize()
	for soundName, sound in self.SoundCache do
		if table.find(exclusionList, soundName) then
			continue
		end
		sound:Stop()
	end
end

function AudioManager:FadeOutAllSounds(exclusionList: { string })
	task.synchronize()
	for soundName, _ in self.SoundCache do
		if table.find(exclusionList, soundName) then
			continue
		end
		self:FadeOut(soundName, 1.5, Enum.EasingStyle.Sine)
	end
	task.wait(1.5)
end

function AudioManager:CreateSound(soundName: string, soundId: string): Sound
	InitializeIfUninitialized()

	if self.SoundCache[soundName] or self:GetSoundContainer():FindFirstChild(soundName) then
		if not self.SoundCache[soundName] then
			local sound = self:GetSoundContainer():FindFirstChild(soundName) :: Sound
			self.SoundCache[soundName] = sound
		end
		return self.SoundCache[soundName] -- Sound already created.
	end

	task.synchronize()
	local newSound = Instance.new("Sound")
	newSound.Name = soundName
	newSound.Parent = self:GetSoundContainer() -- Only one SFX Container should be ever present in-game.
	newSound.SoundId = soundId

	self.SoundCache[soundName] = newSound
	return self.SoundCache[soundName]
end

return AudioManager :: EngineTypes.EngineAudioManager
