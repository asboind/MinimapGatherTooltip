-- Builds MGT_Spawns from GatherMate2_Data when present; otherwise uses embedded fallback.

MGT_Spawns = MGT_Spawns or {}
MGT_SpawnSource = MGT_SpawnSource or "pending"

local DATA_ADDON = "GatherMate2_Data"
local nodeItems = MGT_NodeItems

local function ParseGatherMateCoord(coord)
    local packed = math.floor(tonumber(coord) / 100)
    if not packed then
        return nil
    end
    return math.floor(packed / 10000), packed % 10000
end

local function AppendNodes(out, zoneDB)
    if type(zoneDB) ~= "table" then
        return
    end
    for zoneID, nodes in pairs(zoneDB) do
        if type(zoneID) == "number" and type(nodes) == "table" then
            local list = out[zoneID]
            if not list then
                list = {}
                out[zoneID] = list
            end
            for coord, nodeID in pairs(nodes) do
                local itemID = nodeItems[nodeID]
                local x, y = ParseGatherMateCoord(coord)
                if itemID and x and y then
                    list[#list + 1] = x
                    list[#list + 1] = y
                    list[#list + 1] = itemID
                end
            end
        end
    end
end

local function BuildFromGatherMate()
    local out = {}
    AppendNodes(out, _G.GatherMateData2HerbDB)
    AppendNodes(out, _G.GatherMateData2MineDB)
    return out
end

local function GatherMateDataVersion()
    if not (C_AddOns and C_AddOns.GetAddOnMetadata) then
        return nil
    end
    return C_AddOns.GetAddOnMetadata(DATA_ADDON, "Version")
        or C_AddOns.GetAddOnMetadata("GatherMate2Data", "Version")
end

local function EnsureGatherMateDataLoaded()
    if not C_AddOns then
        return false
    end
    if C_AddOns.GetAddOnEnableState then
        local state = C_AddOns.GetAddOnEnableState(DATA_ADDON)
        if state ~= nil and state <= 0 then
            return false
        end
    end
    if C_AddOns.IsAddOnLoaded(DATA_ADDON) then
        return true
    end
    if C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn(DATA_ADDON)
    end
    return C_AddOns.IsAddOnLoaded(DATA_ADDON)
end

local function UseFallback()
    MGT_Spawns = MGT_FallbackSpawns or {}
    MGT_SpawnSource = "embedded"
end

local function UseCachedSpawns(db)
    if type(db.spawns) ~= "table" or next(db.spawns) == nil then
        return false
    end
    MGT_Spawns = db.spawns
    MGT_SpawnSource = "cache"
    return true
end

function MGT_InitSpawnDatabase()
    MinimapGatherTooltipDB = MinimapGatherTooltipDB or {}
    local db = MinimapGatherTooltipDB

    local gmVersion = GatherMateDataVersion()
    if MGT_SpawnSource == "gathermate" and db.gatherMateVersion == gmVersion and gmVersion then
        return
    end

    if EnsureGatherMateDataLoaded()
        and type(_G.GatherMateData2HerbDB) == "table"
        and type(_G.GatherMateData2MineDB) == "table" then
        local version = gmVersion or "unknown"
        if db.gatherMateVersion == version and UseCachedSpawns(db) then
            return
        end
        local built = BuildFromGatherMate()
        if next(built) ~= nil then
            MGT_Spawns = built
            MGT_SpawnSource = "gathermate"
            db.gatherMateVersion = version
            db.spawns = built
            db.source = "gathermate"
            return
        end
    end

    if UseCachedSpawns(db) then
        return
    end

    UseFallback()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= "MinimapGatherTooltip" and addonName ~= DATA_ADDON then
        return
    end
    MGT_InitSpawnDatabase()
end)

MGT_InitSpawnDatabase()