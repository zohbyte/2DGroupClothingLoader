local InsertService = game:GetService("InsertService")

local assetId = tonumber(script.Parent.Name:match("%d+"))
if not assetId then return end

local ok, model = pcall(function()
	return InsertService:LoadAsset(assetId)
end)

if not ok or not model then
	warn("Failed to load asset:", assetId)
	return
end

local item = model:GetChildren()[1]
if item then
	item.Parent = script.Parent
end
