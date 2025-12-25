local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

local StandTemplate = ServerStorage:WaitForChild("Stand")
local StandContainer = workspace:WaitForChild("StandContainer")

local standCount = 0
local maxPerRow = 10
local xSpacing = 13
local ySpacing = 8

local API_COOLDOWN = 8
local cacheStore = DataStoreService:GetDataStore("StoreItemCache")
local CACHE_KEY = "CachedItems"

local cachedItems = {}
local cachedLookup = {}
local spawnedStands = {}

local function placeModel(model)
	local origin = workspace:FindFirstChild("Origin") or StandContainer or model
	local row = math.floor(standCount / maxPerRow)
	local col = standCount % maxPerRow
	local pos = origin.CFrame * CFrame.new(col * xSpacing, 1, row * ySpacing)

	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not model.PrimaryPart and primary then
		model.PrimaryPart = primary
	end

	if model.PrimaryPart then
		model:SetPrimaryPartCFrame(pos)
	else
		local offset = pos.Position - select(1, model:GetBoundingBox())
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CFrame += offset
			end
		end
	end

	standCount += 1
end

local function spawnItem(plr, assetId)
	local InsertService = game:GetService("InsertService")

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
		item.Parent = plr.Character
	end
end

local function equipClothing(plr, assetId, assetType)
	local char = plr.Character
	if not char then return end

	if assetType == "Pants" then
		local old = char:FindFirstChildOfClass("Pants")
		if old then old:Destroy() end
		spawnItem(plr, assetId)
	elseif assetType == "Shirt" then
		local old = char:FindFirstChildOfClass("Shirt")
		if old then old:Destroy() end
		spawnItem(plr, assetId)
	elseif assetType == "ClassicTShirt" then
		local old = char:FindFirstChildOfClass("ShirtGraphic")
		if old then old:Destroy() end
		spawnItem(plr, assetId)
	end
end

local TryItemRemote = Instance.new("RemoteEvent")
TryItemRemote.Name = "TryItem"
TryItemRemote.Parent = ReplicatedStorage

local BuyItemRemote = Instance.new("RemoteEvent")
BuyItemRemote.Name = "BuyItem"
BuyItemRemote.Parent = ReplicatedStorage

TryItemRemote.OnServerEvent:Connect(function(plr, assetId)
	if not assetId or type(assetId) ~= "number" then return end

	local item = cachedLookup[assetId]
	if not item then return end

	equipClothing(plr, assetId, item.AssetType)
end)

BuyItemRemote.OnServerEvent:Connect(function(plr, assetId)
	if not assetId or type(assetId) ~= "number" then return end

	MarketplaceService:PromptPurchase(plr, assetId)
end)

local function createStand(info)
	if spawnedStands[info.AssetId] then return end

	if StandContainer:FindFirstChild(tostring(info.AssetId)) then
		spawnedStands[info.AssetId] = true
		return
	end

	local stand = StandTemplate:Clone()
	stand.Parent = StandContainer
	stand.Name = info.AssetId

	local buttons = stand.Buttons
	local buyButton = buttons.Buy
	local buyGui = buttons.Buy.Buy
	local tryButton = buttons.Try
	local tryGui = buttons.Try.Try

	buyGui.Name = "Buy_" .. info.AssetId
	tryGui.Name = "Try_" .. info.AssetId

	buyGui.Adornee = buyButton
	tryGui.Adornee = tryButton

	buyGui.Parent = game.StarterGui
	tryGui.Parent = game.StarterGui

	spawnedStands[info.AssetId] = true
	placeModel(stand)
end

local function loadCache()
	local ok, data = pcall(function()
		return cacheStore:GetAsync(CACHE_KEY)
	end)
	if ok and data then
		for _, item in ipairs(data) do
			cachedItems[#cachedItems+1] = item
			cachedLookup[item.AssetId] = item
		end
		print("Loaded", #cachedItems, "items from cache")
	else
		print("No cache found")
	end
end

local function saveCache()
	local ok, err = pcall(function()
		cacheStore:SetAsync(CACHE_KEY, cachedItems)
	end)
	if not ok then
		warn("Cache save failed:", err)
	end
end

local function addCache(item)
	if cachedLookup[item.AssetId] then return end
	cachedLookup[item.AssetId] = item
	cachedItems[#cachedItems+1] = item
end

local function spawnCached()
	for _, item in ipairs(cachedItems) do
		createStand(item)
	end
end

local function mapAssetType(num)
	return ({
		[2] = "ClassicTShirt",
		[11] = "Shirt",
		[12] = "Pants",
	})[num]
end

local function fetch()
	local nextCursor = nil
	local newCount = 0
	local baseURL = "https://REDACTED.REDACTED.workers.dev/catalog/v2/search/items/details?Category=3&CreatorType=Group&CreatorTargetId=REDACTED&IncludeNotForSale=false&limit=120"

	while true do
		local url = nextCursor and (baseURL .. "&Cursor=" .. nextCursor) or baseURL

		local ok, raw = pcall(function()
			return HttpService:GetAsync(url)
		end)
		if not ok then
			task.wait(API_COOLDOWN)
			continue
		end

		local data = HttpService:JSONDecode(raw)
		if not data or not data.data then break end

		for _, item in ipairs(data.data) do
			local t = mapAssetType(item.assetType)
			if not t then continue end

			if not cachedLookup[item.id] then
				local info = {
					AssetId = item.id,
					AssetType = t,
					Name = item.name or "Unknown"
				}
				createStand(info)
				addCache(info)
				newCount += 1
			end
		end

		saveCache()

		if not data.nextPageCursor then break end
		nextCursor = data.nextPageCursor
		task.wait(API_COOLDOWN)
	end

	print("New items:", newCount)
end

loadCache()
spawnCached()
fetch()


print("Successfully completed loading!")
