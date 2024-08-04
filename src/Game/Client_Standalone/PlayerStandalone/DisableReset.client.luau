local starterGui = game:GetService("StarterGui")

local success: boolean
while not success do
	task.wait()
	success = pcall(function()
		starterGui:SetCore("ResetButtonCallback", false)
	end)
end
