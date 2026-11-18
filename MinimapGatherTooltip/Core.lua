-- MinimapGatherTooltip
-- Hover a gathering icon on the minimap to see vendor and auction prices.
-- Herbs require Find Herbs. Ore requires Find Minerals.

local issecretvalue = issecretvalue

local sortedNames = {}
local itemIDs = {}
local priceFrame
local shownID

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function PlainString(value)
    if value == nil or IsSecret(value) or type(value) ~= "string" then
        return nil
    end
    return value
end

local function PlainNumber(value)
    if value == nil or IsSecret(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

for nodeName, itemID in pairs(MGT_NodeDB) do
    itemIDs[itemID] = true
    sortedNames[#sortedNames + 1] = { name = nodeName:lower(), id = itemID, len = #nodeName }
end
table.sort(sortedNames, function(a, b)
    return a.len > b.len
end)

local function ItemFromName(text)
    text = PlainString(text)
    if not text then
        return nil
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
    if text == "" then
        return nil
    end
    for i = 1, #sortedNames do
        local entry = sortedNames[i]
        if text:find(entry.name, 1, true) then
            return entry.id
        end
    end
    return nil
end

-- A secret link cannot be compared, but the item API may still resolve it
-- to a normal item id. A secret result is ignored.
local function ItemFromValue(value)
    if not IsSecret(value) then
        if type(value) ~= "string" and type(value) ~= "number" then
            return nil
        end
    end
    if not (C_Item and C_Item.GetItemInfoInstant) then
        return nil
    end
    local ok, itemID = pcall(C_Item.GetItemInfoInstant, value)
    itemID = ok and PlainNumber(itemID) or nil
    if itemID and itemIDs[itemID] then
        return itemID
    end
    return nil
end

local function LineCount(data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then
        return 0
    end
    local count = 0
    for i = 1, #data.lines do
        local line = data.lines[i]
        if type(line) == "table" then
            local text = line.leftText
            if IsSecret(text) or text ~= nil then
                count = count + 1
            end
        end
    end
    return count
end

local function CursorOnMinimap()
    if not Minimap or not Minimap.GetCenter or not GetCursorPosition then
        return false
    end
    local cx, cy = Minimap:GetCenter()
    local width = Minimap:GetWidth()
    local scale = Minimap:GetEffectiveScale()
    if not cx or not width or not scale or scale <= 0 then
        return false
    end
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    local dx, dy = x - cx, y - cy
    local radius = (width * 0.5) + 4
    return (dx * dx + dy * dy) <= (radius * radius)
end

local function CoinString(copper)
    copper = PlainNumber(copper)
    if not copper or copper <= 0 then
        return nil
    end
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    end
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    return tostring(copper)
end

local function EnsureFrame()
    if priceFrame then
        return priceFrame
    end
    local frame = CreateFrame("Frame", "MGTPriceFrame", UIParent, "BackdropTemplate")
    frame:SetSize(40, 40)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(900)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    frame:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", 10, -8)
    frame.title:SetJustifyH("LEFT")

    frame.vendor = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.vendor:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    frame.vendor:SetJustifyH("LEFT")

    frame.auction = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.auction:SetPoint("TOPLEFT", frame.vendor, "BOTTOMLEFT", 0, -2)
    frame.auction:SetJustifyH("LEFT")

    frame:Hide()
    priceFrame = frame
    return frame
end

local function PlaceFrame(frame)
    frame:ClearAllPoints()
    if Minimap then
        frame:SetPoint("RIGHT", Minimap, "LEFT", -12, 0)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -160)
    end
end

local function HideFrame()
    shownID = nil
    if priceFrame then
        priceFrame:Hide()
    end
end

local function AuctionCopper(itemID)
    if not (Auctionator and Auctionator.Database and Auctionator.Utilities and Auctionator.Utilities.DBKeyFromLink) then
        return nil
    end
    local link
    if C_Item and C_Item.GetItemInfo then
        link = select(2, C_Item.GetItemInfo(itemID))
    elseif GetItemInfo then
        link = select(2, GetItemInfo(itemID))
    end
    link = PlainString(link)
    if not link then
        return nil
    end
    local keys
    Auctionator.Utilities.DBKeyFromLink(link, function(dbKeys)
        keys = dbKeys
    end)
    if type(keys) ~= "table" or not keys[1] then
        return nil
    end
    local price = Auctionator.Database:GetFirstPrice(keys)
    if type(price) == "number" and price > 0 then
        return price
    end
    return nil
end

local function LineWidth(fs)
    if fs.GetUnboundedStringWidth then
        return fs:GetUnboundedStringWidth()
    end
    return fs:GetStringWidth()
end

local function FitFrame(frame)
    local width = 0
    for _, fs in ipairs({ frame.title, frame.vendor, frame.auction }) do
        local line = LineWidth(fs) or 0
        if line > width then
            width = line
        end
    end
    local height = 8
        + (frame.title:GetStringHeight() or 0) + 4
        + (frame.vendor:GetStringHeight() or 0) + 2
        + (frame.auction:GetStringHeight() or 0) + 10
    frame:SetSize(math.max(48, width + 22), math.max(36, height))
end

local function FillFrame(itemID)
    local frame = EnsureFrame()
    local name, sellPrice
    if C_Item and C_Item.GetItemInfo then
        name, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemID)
    elseif GetItemInfo then
        name, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
    end
    name = PlainString(name) or ("Item " .. itemID)
    frame.title:SetText(name)
    local vendor = CoinString(sellPrice)
    frame.vendor:SetText(vendor and ("Vendor  " .. vendor) or "Vendor  —")
    local auction = CoinString(AuctionCopper(itemID))
    frame.auction:SetText(auction and ("|cff00ccffAuction|r  " .. auction) or "|cff00ccffAuction|r  —")
    FitFrame(frame)
    PlaceFrame(frame)
    frame:Show()
    -- Coin icons finish loading a frame later and widen the auction line.
    frame:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        FitFrame(self)
    end)
    shownID = itemID
end

local function ShowPrices(itemID)
    if type(itemID) ~= "number" then
        return
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    FillFrame(itemID)
end

local nodeCache
local cacheMap
local scaleX, scaleY
local lastRadius

local function MapScale(uiMap)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
        return nil
    end
    local function World(x, y)
        local ok, _, world = pcall(C_Map.GetWorldPosFromMapPos, uiMap, CreateVector2D(x, y))
        if not ok or type(world) ~= "table" then
            return nil
        end
        local wx, wy = PlainNumber(world.x), PlainNumber(world.y)
        if not wx or not wy then
            return nil
        end
        return wx, wy
    end
    local ox, oy = World(0, 0)
    local ex, ey = World(1, 0)
    local sx, sy = World(0, 1)
    if not ox or not ex or not sx then
        return nil
    end
    local ypx = math.sqrt((ex - ox) * (ex - ox) + (ey - oy) * (ey - oy))
    local ypy = math.sqrt((sx - ox) * (sx - ox) + (sy - oy) * (sy - oy))
    if ypx < 1 or ypy < 1 then
        return nil
    end
    return ypx, ypy
end

local function PlayerMapXY(mapID)
    if not (C_Map and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local a, b = C_Map.GetPlayerMapPosition(mapID, "player")
    if type(a) == "number" and type(b) == "number" then
        return PlainNumber(a), PlainNumber(b)
    end
    if type(a) == "table" then
        local x, y = PlainNumber(a.x), PlainNumber(a.y)
        if x and y then
            return x, y
        end
        if a.GetXY then
            local ok, x2, y2 = pcall(a.GetXY, a)
            if ok then
                return PlainNumber(x2), PlainNumber(y2)
            end
        end
    end
    return nil
end

local function SpawnMap()
    if not (C_Map and C_Map.GetBestMapForUnit and MGT_Spawns) then
        return nil
    end
    local id = C_Map.GetBestMapForUnit("player")
    for _ = 1, 4 do
        if type(id) ~= "number" then
            return nil
        end
        if MGT_Spawns[id] then
            return id
        end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        id = info and info.parentMapID
    end
    return nil
end

local function LoadSpawns(mapID)
    nodeCache = {}
    cacheMap = mapID
    scaleX, scaleY = MapScale(mapID)
    local list = MGT_Spawns[mapID]
    if not list then
        return
    end
    for i = 1, #list, 3 do
        nodeCache[#nodeCache + 1] = {
            x = list[i] / 10000,
            y = list[i + 1] / 10000,
            item = list[i + 2],
        }
    end
end

local function MinimapYards()
    local radius = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
    radius = PlainNumber(radius)
    if not radius then
        local zoom = Minimap.GetZoom and Minimap:GetZoom() or 0
        local indoor = IsIndoors and IsIndoors()
        local outdoor = { [0] = 466.67, [1] = 400, [2] = 333.33, [3] = 266.67, [4] = 200, [5] = 133.33 }
        local inside = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 }
        radius = (indoor and inside[zoom]) or outdoor[zoom] or 200
    end
    lastRadius = radius
    local cx, cy = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local half = Minimap:GetWidth() * 0.5
    if not cx or not scale or scale <= 0 or half <= 0 then
        return nil
    end
    local x, y = GetCursorPosition()
    local dx = (x / scale - cx) / half * radius
    local dy = (y / scale - cy) / half * radius
    if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then
        local facing = GetPlayerFacing() or 0
        local dist = math.sqrt(dx * dx + dy * dy)
        local angle = math.atan2(dx, dy) + facing
        dx = math.sin(angle) * dist
        dy = math.cos(angle) * dist
    end
    return dx, dy
end

local ORE_ITEM = {
    [2770] = true, [2771] = true, [2772] = true, [2775] = true, [2776] = true,
    [3858] = true, [7911] = true, [10620] = true, [11370] = true,
    [4278] = true, [3340] = true, [5833] = true, [248815] = true,
}

local function TrackingOn()
    local herbs, ore = false, false
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then
        return herbs, ore
    end
    local count = PlainNumber(C_Minimap.GetNumTrackingTypes()) or 0
    for i = 1, count do
        local first, _, active = C_Minimap.GetTrackingInfo(i)
        local spell, name
        if type(first) == "table" then
            spell = PlainNumber(first.spellID or first.spellId)
            name = PlainString(first.name)
            active = first.active
        else
            name = PlainString(first)
            local extra = select(6, C_Minimap.GetTrackingInfo(i))
            spell = PlainNumber(extra) or PlainNumber(select(7, C_Minimap.GetTrackingInfo(i)))
        end
        if not IsSecret(active) and active then
            if spell == 2383 or name == "Find Herbs" or name == "Поиск трав" then
                herbs = true
            elseif spell == 2580 or name == "Find Minerals" or name == "Поиск минералов" then
                ore = true
            end
        end
    end
    return herbs, ore
end

local function TrackingAllows(itemID)
    local herbs, ore = TrackingOn()
    if ORE_ITEM[itemID] then
        return ore
    end
    return herbs
end

-- Only a cursor sitting on the node icon counts. Quest pins a short
-- distance away stay outside this cap.
local function NearestSpawn()
    local dx, dy = MinimapYards()
    if not dx then
        return nil
    end
    local mapID = SpawnMap()
    if not mapID then
        return nil
    end
    if mapID ~= cacheMap then
        LoadSpawns(mapID)
    end
    if not scaleX or not scaleY or #nodeCache == 0 then
        return nil
    end
    local px, py = PlayerMapXY(mapID)
    if not px or not py then
        return nil
    end
    local herbsOn, oreOn = TrackingOn()
    if not herbsOn and not oreOn then
        return nil
    end
    local cx = px + (dx / scaleX)
    local cy = py - (dy / scaleY)
    local half = Minimap:GetWidth() * 0.5
    local threshold = (lastRadius or 200) * (5 / math.max(half, 1))
    if threshold < 5 then
        threshold = 5
    elseif threshold > 10 then
        threshold = 10
    end
    local bestDist, bestItem
    for i = 1, #nodeCache do
        local node = nodeCache[i]
        local ddx = (node.x - cx) * scaleX
        local ddy = (node.y - cy) * scaleY
        local dist = math.sqrt(ddx * ddx + ddy * ddy)
        local oreNode = ORE_ITEM[node.item]
        if (oreNode and oreOn) or (not oreNode and herbsOn) then
            if not bestDist or dist < bestDist then
                bestDist = dist
                bestItem = node.item
            end
        end
    end
    if bestDist and bestDist <= threshold then
        return bestItem
    end
    return nil
end

local function ItemFromTooltip(data)
    local line = data.lines and data.lines[1]
    local text = line and line.leftText
    return ItemFromName(text) or ItemFromValue(text) or ItemFromValue(data.hyperlink) or ItemFromValue(data.id)
end

local function Poll()
    if not CursorOnMinimap() then
        HideFrame()
        return
    end
    if not (C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover) then
        return
    end
    local ok, data = pcall(C_TooltipInfo.GetMinimapMouseover)
    if not ok or type(data) ~= "table" or LineCount(data) ~= 1 then
        HideFrame()
        return
    end
    -- A quest pin tooltip has a title and an objective. A node tooltip is one line.
    if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() and GameTooltip.NumLines then
        local shownLines = GameTooltip:NumLines()
        if type(shownLines) == "number" and shownLines > 1 then
            HideFrame()
            return
        end
    end
    local itemID = ItemFromTooltip(data) or NearestSpawn()
    if itemID and not TrackingAllows(itemID) then
        itemID = nil
    end
    if not itemID then
        HideFrame()
        return
    end
    if shownID ~= itemID or not priceFrame or not priceFrame:IsShown() then
        ShowPrices(itemID)
    end
end

local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.12 then
        return
    end
    elapsed = 0
    pcall(Poll)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, _, itemID)
    if shownID and itemID == shownID and priceFrame and priceFrame:IsShown() then
        FillFrame(shownID)
    end
end)
