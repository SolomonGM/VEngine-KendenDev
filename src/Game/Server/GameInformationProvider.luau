--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)

local module = moduleBaseConstructor.new()

module.ModuleName = "GameInformationProvider"

function module:PreInitialize(_: EngineTypes.EngineEnvironmentManager) end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager)
	-- Location information is stripped on studio.
	if not RunService:IsStudio() then
		-- GetAsync, for obvious reasons, yields, as such it can hang indefinitely, we don't want this to annoy our existance!
		task.spawn(function()
			local ipApi = HttpService:GetAsync("http://ip-api.com/json/")
			local ipApiResponse = HttpService:JSONDecode(ipApi)
			ReplicatedStorage.ServerInformation.ServerLocation = (ipApiResponse["city"] or "Unknown")
				.. ", "
				.. (ipApiResponse["country"] or "Earth")
		end)
	end

	if RunService:IsStudio() then
		ReplicatedStorage.ServerInformation.GameVersion.Value = "indev"
	end

	ReplicatedStorage.ServerInformation.ServerStartTime.Value = math.round(workspace:GetServerTimeNow()) -- Seconds
end

return module
