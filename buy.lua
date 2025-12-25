local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local BuyItemRemote = ReplicatedStorage:WaitForChild("BuyItem")

local buttonPart = script.Parent.Parent
local button = script.Parent:FindFirstChildWhichIsA("TextButton")
if not button then return end

local assetId = tonumber(script.Parent.Name:match("_(%d+)"))
if not assetId then return end

button.MouseButton1Click:Connect(function()
	BuyItemRemote:FireServer(assetId)
end)
