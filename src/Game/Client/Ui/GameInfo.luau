--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EngineTimeSpan = require(ReplicatedFirst.EngineShared.EngineTimeSpan)
local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)
local moduleBaseConstructor = require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineModule"))

local module = moduleBaseConstructor.new()

module.ModuleName = "Ui/GameInformation"

function module:PreInitialize(_: EngineTypes.EngineEnvironmentManager) end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager)
	local gameInformationFrame = Players.LocalPlayer.PlayerGui
		:WaitForChild("GameInformation")
		:WaitForChild("GameInformation")
		:WaitForChild("GameInformation")

	ReplicatedStorage.ServerInformation.ServerLocation.Changed:Connect(function(newValue: string)
		gameInformationFrame.ActualServerLocation.Text = newValue
	end)
	gameInformationFrame.ActualServerLocation.Text = ReplicatedStorage.ServerInformation.ServerLocation.Value

	ReplicatedStorage.ServerInformation.GameVersion.Changed:Connect(function(newValue: string)
		gameInformationFrame.GameVersion.Text = newValue
	end)

	gameInformationFrame.GameVersion.Text = ReplicatedStorage.ServerInformation.GameVersion.Value

	RunService.Heartbeat:Connect(function(deltaTime: number)
		local currentFps = 1 / deltaTime
		gameInformationFrame.Counter.Text = tostring(math.round(currentFps))
	end)

	task.spawn(function()
		repeat
			task.wait()
		until ReplicatedStorage.ServerInformation.ServerStartTime.Value ~= 0

		local gameStartTime = ReplicatedStorage.ServerInformation.ServerStartTime.Value
		local gameStart = EngineTimeSpan.fromSeconds(gameStartTime)
		while task.wait(1) do
			local currentTime = EngineTimeSpan.fromSeconds(DateTime.now().UnixTimestamp)
			local timeDifference = gameStart:GetDifference(currentTime)
			gameInformationFrame.ServerAgeValue.Text = string.format(
				"%02d:%02d:%02d:%02d",
				timeDifference:ToDays(),
				timeDifference:ToHours(),
				timeDifference:ToMinutes(),
				timeDifference:ToSeconds()
			)
		end
	end)
end

return module
