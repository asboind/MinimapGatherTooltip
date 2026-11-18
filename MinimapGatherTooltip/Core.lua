-- ============================================================================
-- MinimapGatherTooltip - Core.lua (v1.2.0)
-- Intercepts Minimap gathering node tooltips and replaces them with full
-- Item Tooltips so Auctionator & ElvUI inject prices, Item ID, and bag counts.
-- ============================================================================

local isMutating = false
local lastUnmatchedRawText = nil
local MUTATED_MARKER = "|r|r"

-- Pre-build sorted list of node names (longest first) for fallback substring matching
local sortedNodeNames = {}
for nodeName, itemID in pairs(MGT_NodeDB) do
    table.insert(sortedNodeNames, { name = nodeName, id = itemID, len = #nodeName })
end
table.sort(sortedNodeNames, function(a, b) return a.len > b.len end)

-- Strip inline texture icons (|T...|t), atlas icons (|A...|a), color codes, and trim whitespace
local function CleanTooltipLine(text)
    if not text then return "" end
    local cleaned = text
    cleaned = cleaned:gsub("|T.-|t", "")
    cleaned = cleaned:gsub("|A.-|a", "")
    cleaned = cleaned:gsub("|c%x%x%x%x%x%x%x%x", "")
    cleaned = cleaned:gsub("|cn.-:", "")
    cleaned = cleaned:gsub("|r", "")
    cleaned = cleaned:match("^[%s%c]*(.-)[%s%c]*$") or ""
    return cleaned
end

-- Match a raw or cleaned tooltip line to an ItemID from MGT_NodeDB
local function FindNodeMatch(rawLine)
    if not rawLine or rawLine == "" then return nil, nil end
    local cleaned = CleanTooltipLine(rawLine)
    if cleaned == "" then return nil, nil end

    -- 1. Fast exact match
    local exactID = MGT_NodeDB[cleaned] or MGT_NodeDB[rawLine]
    if exactID then
        return cleaned, exactID
    end

    -- 2. Fallback substring match (handles custom arrows/prefixes from ElvUI or server)
    for i = 1, #sortedNodeNames do
        local entry = sortedNodeNames[i]
        if cleaned:find(entry.name, 1, true) then
            return entry.name, entry.id
        end
    end

    return nil, nil
end

-- Check whether GameTooltip is currently displaying a Minimap tooltip
local function IsMinimapContext(tooltip)
    local owner = tooltip:GetOwner()
    if owner then
        if owner == Minimap or owner == MinimapCluster or owner == MinimapBackdrop then
            return true
        end
        local ownerName = owner.GetName and owner:GetName()
        if ownerName and ownerName:find("Minimap") then
            return true
        end
    end
    if Minimap and MouseIsOver(Minimap) then
        return true
    end
    return false
end

-- Retrieve localized item name and itemLink
local function GetCachedItemData(itemID)
    if GetItemInfo then
        local name, link = GetItemInfo(itemID)
        if name and link then
            return name, link
        end
    end
    if C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(itemID)
        if name then
            return name, nil
        end
    end
    return nil, nil
end

-- Request item data preload from the server
local function PreloadItemData(itemID)
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

-- Collect all raw lines currently displayed in GameTooltip
local function ExtractRawLines(tooltip)
    local lines = {}
    local numLines = tooltip:NumLines() or 0
    for i = 1, numLines do
        local fontString = _G["GameTooltipTextLeft" .. i]
        local text = fontString and fontString:GetText()
        if text and text ~= "" then
            for subLine in text:gmatch("([^\r\n]+)") do
                table.insert(lines, subLine)
            end
        end
    end
    return lines
end

-- Main inspection & replacement routine
local function ProcessMinimapTooltip(tooltip)
    if isMutating then return end
    if not tooltip or not tooltip:IsShown() then return end

    if not IsMinimapContext(tooltip) then
        lastUnmatchedRawText = nil
        return
    end

    local firstLineObj = GameTooltipTextLeft1
    local rawFirstText = firstLineObj and firstLineObj:GetText()
    if not rawFirstText or rawFirstText == "" then return end

    -- If our invisible marker is still on line 1 and tooltip has multiple lines,
    -- the full Item Tooltip is already displayed (prevents flickering)
    if rawFirstText:sub(-4) == MUTATED_MARKER and (tooltip:NumLines() or 0) > 1 then
        return
    end

    if lastUnmatchedRawText == rawFirstText then
        return
    end

    local rawLines = ExtractRawLines(tooltip)
    if #rawLines == 0 then return end

    local primaryNodeName = nil
    local primaryItemID = nil
    local extraLines = {}

    for _, line in ipairs(rawLines) do
        local matchedName, matchedID = FindNodeMatch(line)
        if matchedID and not primaryItemID then
            primaryNodeName = matchedName
            primaryItemID = matchedID
        else
            table.insert(extraLines, line)
        end
    end

    if not primaryItemID then
        lastUnmatchedRawText = rawFirstText
        return
    end

    lastUnmatchedRawText = nil
    PreloadItemData(primaryItemID)

    local itemName, itemLink = GetCachedItemData(primaryItemID)

    isMutating = true

    -- Replace Minimap plain text with full Item Tooltip
    -- Triggers TooltipDataProcessor & OnTooltipSetItem for Auctionator and ElvUI
    if itemLink then
        tooltip:SetHyperlink(itemLink)
    elseif tooltip.SetItemByID then
        tooltip:SetItemByID(primaryItemID)
    else
        tooltip:SetHyperlink("item:" .. primaryItemID)
    end

    itemName = itemName or GetCachedItemData(primaryItemID)

    -- Update title line (append vein name if different from ore name + invisible anti-flicker marker)
    local titleObj = GameTooltipTextLeft1
    if titleObj then
        local currentTitle = titleObj:GetText() or itemName or primaryNodeName or ""
        if itemName and primaryNodeName and itemName:lower() ~= primaryNodeName:lower() then
            titleObj:SetText(itemName .. " |cffaaaaaa(" .. primaryNodeName .. ")|r" .. MUTATED_MARKER)
        else
            titleObj:SetText(currentTitle .. MUTATED_MARKER)
        end
    end

    -- Re-append any additional overlapping minimap blips at the bottom of the tooltip
    if #extraLines > 0 then
        tooltip:AddLine(" ")
        for _, extraLine in ipairs(extraLines) do
            local extraNodeName, extraItemID = FindNodeMatch(extraLine)
            if extraItemID then
                local extraItemName = GetCachedItemData(extraItemID)
                if extraItemName and extraNodeName and extraItemName:lower() ~= extraNodeName:lower() then
                    tooltip:AddLine(extraLine .. " |cffaaaaaa(" .. extraItemName .. ")|r", 0.85, 0.85, 0.85)
                else
                    tooltip:AddLine(extraLine, 0.85, 0.85, 0.85)
                end
            else
                tooltip:AddLine(extraLine, 0.75, 0.75, 0.75)
            end
        end
    end

    tooltip:Show()
    isMutating = false
end

-- Hook GameTooltip & Minimap updates
GameTooltip:HookScript("OnShow", function(self)
    ProcessMinimapTooltip(self)
end)

GameTooltip:HookScript("OnUpdate", function(self)
    ProcessMinimapTooltip(self)
end)

GameTooltip:HookScript("OnHide", function()
    lastUnmatchedRawText = nil
end)

if hooksecurefunc then
    hooksecurefunc(GameTooltip, "SetText", function(self)
        ProcessMinimapTooltip(self)
    end)
end

if Minimap and Minimap.HookScript then
    Minimap:HookScript("OnUpdate", function()
        if GameTooltip:IsShown() then
            ProcessMinimapTooltip(GameTooltip)
        end
    end)
end

local loaderFrame = CreateFrame("Frame")
loaderFrame:RegisterEvent("PLAYER_LOGIN")
loaderFrame:SetScript("OnEvent", function()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MinimapGatherTooltip|r v1.2.0 loaded.")
end)
