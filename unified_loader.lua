--// Aurora Unified Loader (no key)
--// Made by notCitruss | 2026
--// Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/notCitruss/Aurora/main/unified_loader.lua"))()
--//
--// Serves the unified DWS+AH script set with cross-executor compat baked in.
--// Wave / Potassium / Xeno / Delta / Synapse Z / Krnl / Fluxus / Volt / Codex / Optiumware / Seliware.
--// No key system, no HWID, no validation. Direct GitHub raw fetch.

print("[Aurora] Unified loader starting...")

local _loaderOk, _loaderErr = pcall(function()

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService   = game:GetService("RunService")

local Player = Players.LocalPlayer

---------- CONSTANTS ----------
local SCRIPT_BASE = "https://raw.githubusercontent.com/notCitruss/Aurora/main/unified/"

---------- GAME REGISTRY ----------
-- PlaceId map (primary lookup)
local GAMES_BY_ID = {
    [75251063577391]  = "brainrot_heroes_autofarm",
    [77747658251236]  = "sailor_piece",
    [131756752872026] = "dive_down",
    [81535567274521]  = "bee_garden",
    [70845479499574]  = "bite_by_night",
    [89469502395769]  = "kick_a_lucky_block",
    [9192423027]      = "industrialist",
    [9312740628]      = "industrialist",
    [96840410521899]  = "timber_autofarm",
    [135668295983945] = "skill_point_legends",
    [125007306703268] = "skill_point_incremental",
    [122079988266644] = "idle_potato_game",
    [132391015411211] = "split_or_steal",
    [119048529960596] = "restaurant_tycoon_3",
}

-- Name fallback (substring match against MarketplaceService name)
local GAMES_BY_NAME = {
    ["brainrot heroes"]    = "brainrot_heroes_autofarm",
    ["sailor piece"]       = "sailor_piece",
    ["dive down"]          = "dive_down",
    ["bee garden"]         = "bee_garden",
    ["bite by night"]      = "bite_by_night",
    ["kick a lucky block"] = "kick_a_lucky_block",
    ["industrialist"]      = "industrialist",
    ["timber"]             = "timber_autofarm",
    ["skill point legends"] = "skill_point_legends",
    ["skill point"]        = "skill_point_incremental",
    ["idle potato"]        = "idle_potato_game",
    ["split or steal"]     = "split_or_steal",
    ["restaurant tycoon 3"] = "restaurant_tycoon_3",
}

---------- DETECT GAME ----------
local placeId = game.PlaceId
local placeName = "Unknown"
pcall(function() placeName = MarketplaceService:GetProductInfo(placeId).Name or "Unknown" end)
local placeNameLower = placeName:lower()

local scriptName = GAMES_BY_ID[placeId]
if not scriptName then
    for pattern, name in pairs(GAMES_BY_NAME) do
        if placeNameLower:find(pattern) then scriptName = name; break end
    end
end

---------- CLEANUP OLD GUIs ----------
local _cleanParents = { game:GetService("CoreGui"), Player.PlayerGui }
if typeof(gethui) == "function" then table.insert(_cleanParents, 1, gethui()) end
for _, n in ipairs({"Aurora", "AuroraLoader", "AuroraKey", "AuroraV3", "AuroraV3Loader", "AuroraLoading", "AuroraErr"}) do
    for _, p in ipairs(_cleanParents) do
        pcall(function() local o = p:FindFirstChild(n); if o then o:Destroy() end end)
    end
end

---------- ZOMBIE KILL / SESSION ----------
getgenv().__AURORA_LOADER_SESSION = tick()

---------- 3-TIER GUI PARENT ----------
local function parentGui(gui)
    local ok = false
    if typeof(gethui) == "function" then
        ok = pcall(function() gui.Parent = gethui() end)
    end
    if not ok then
        ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    end
    if not ok then
        gui.Parent = Player:WaitForChild("PlayerGui")
    end
    return ok
end

---------- ERROR DISPLAY ----------
local function showError(msg)
    pcall(function()
        local eg = Instance.new("ScreenGui")
        eg.Name = "AuroraErr"
        eg.ResetOnSpawn = false
        eg.DisplayOrder = 999
        parentGui(eg)
        local ef = Instance.new("Frame")
        ef.Size = UDim2.new(0, 500, 0, 80)
        ef.Position = UDim2.new(0.5, -250, 0.3, 0)
        ef.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
        ef.BorderSizePixel = 0
        ef.Parent = eg
        local ec = Instance.new("UICorner")
        ec.CornerRadius = UDim.new(0, 12)
        ec.Parent = ef
        local el = Instance.new("TextLabel")
        el.Size = UDim2.new(1, -20, 1, 0)
        el.Position = UDim2.fromOffset(10, 0)
        el.BackgroundTransparency = 1
        el.TextColor3 = Color3.fromRGB(255, 80, 80)
        el.TextSize = 13
        el.Font = Enum.Font.GothamBold
        el.TextWrapped = true
        el.TextXAlignment = Enum.TextXAlignment.Left
        el.Text = "[Aurora] " .. tostring(msg):sub(1, 250)
        el.Parent = ef
        task.delay(15, function() pcall(function() eg:Destroy() end) end)
    end)
end

---------- NO-MATCH ----------
if not scriptName then
    warn("[Aurora] No script available for this game (PlaceId " .. tostring(placeId) .. " / " .. placeName .. ")")
    showError("No Aurora script for this game (yet)")
    return
end

---------- LOADING SPLASH ----------
local loadGui = Instance.new("ScreenGui")
loadGui.Name = "AuroraLoading"
loadGui.DisplayOrder = 100
loadGui.IgnoreGuiInset = true
loadGui.ResetOnSpawn = false
parentGui(loadGui)

local loadOverlay = Instance.new("Frame")
loadOverlay.Size = UDim2.new(1, 0, 1, 0)
loadOverlay.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
loadOverlay.BackgroundTransparency = 0.3
loadOverlay.BorderSizePixel = 0
loadOverlay.Parent = loadGui

local loadTitle = Instance.new("TextLabel")
loadTitle.Size = UDim2.new(0.85, 0, 0, 110)
loadTitle.Position = UDim2.new(0.075, 0, 0.5, -55)
loadTitle.BackgroundTransparency = 1
loadTitle.Text = "AURORA"
loadTitle.TextColor3 = Color3.fromRGB(252, 110, 142)
loadTitle.TextTransparency = 0
loadTitle.TextSize = 180
loadTitle.Font = Enum.Font.GothamBlack
loadTitle.BorderSizePixel = 0
loadTitle.Parent = loadGui

local loadStatus = Instance.new("TextLabel")
loadStatus.Size = UDim2.new(0.4, 0, 0, 18)
loadStatus.Position = UDim2.new(0.3, 0, 0.5, 60)
loadStatus.BackgroundTransparency = 1
loadStatus.Text = "Loading " .. (scriptName:gsub("_", " ")) .. "..."
loadStatus.TextColor3 = Color3.fromRGB(200, 200, 215)
loadStatus.TextSize = 13
loadStatus.Font = Enum.Font.Gotham
loadStatus.BorderSizePixel = 0
loadStatus.Parent = loadGui

task.wait(0.4)

---------- FETCH SCRIPT ----------
loadStatus.Text = "Downloading..."
local url = SCRIPT_BASE .. scriptName .. ".lua"
local success, result = pcall(function() return game:HttpGet(url) end)

if not success or not result or #result < 50 then
    loadStatus.Text = "Failed to download script"
    loadStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
    task.wait(3)
    pcall(function() loadGui:Destroy() end)
    warn("[Aurora] Download failed for " .. scriptName .. ": " .. tostring(result):sub(1, 200))
    return
end

loadStatus.Text = "Executing..."
task.wait(0.25)
loadStatus.Text = "Ready"
loadStatus.TextColor3 = Color3.fromRGB(80, 200, 120)
task.wait(0.25)

-- Fade out splash
local fadeOut = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
TweenService:Create(loadOverlay, fadeOut, {BackgroundTransparency = 1}):Play()
TweenService:Create(loadTitle, fadeOut, {TextTransparency = 1}):Play()
TweenService:Create(loadStatus, fadeOut, {TextTransparency = 1}):Play()
task.wait(0.9)
pcall(function() loadGui:Destroy() end)

---------- EXECUTE ----------
local loadSuccess, loadErr = pcall(function() loadstring(result)() end)
if not loadSuccess then
    warn("[Aurora] Script execution error: " .. tostring(loadErr))
    showError("Script error: " .. tostring(loadErr))
end

end) -- end top-level pcall

if not _loaderOk then
    warn("[Aurora] LOADER CRASHED: " .. tostring(_loaderErr))
    pcall(function()
        local Player = game:GetService("Players").LocalPlayer
        local eg = Instance.new("ScreenGui")
        eg.Name = "AuroraErr"
        eg.ResetOnSpawn = false
        eg.DisplayOrder = 999
        local _eOk = false
        if typeof(gethui) == "function" then _eOk = pcall(function() eg.Parent = gethui() end) end
        if not _eOk then _eOk = pcall(function() eg.Parent = game:GetService("CoreGui") end) end
        if not _eOk then eg.Parent = Player:WaitForChild("PlayerGui") end
        local ef = Instance.new("Frame")
        ef.Size = UDim2.new(0, 500, 0, 80)
        ef.Position = UDim2.new(0.5, -250, 0.3, 0)
        ef.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
        ef.BorderSizePixel = 0
        ef.Parent = eg
        local ec = Instance.new("UICorner")
        ec.CornerRadius = UDim.new(0, 12)
        ec.Parent = ef
        local el = Instance.new("TextLabel")
        el.Size = UDim2.new(1, -20, 1, 0)
        el.Position = UDim2.fromOffset(10, 0)
        el.BackgroundTransparency = 1
        el.TextColor3 = Color3.fromRGB(255, 80, 80)
        el.TextSize = 13
        el.Font = Enum.Font.GothamBold
        el.TextWrapped = true
        el.TextXAlignment = Enum.TextXAlignment.Left
        el.Text = "[Aurora] Loader error: " .. tostring(_loaderErr):sub(1, 250)
        el.Parent = ef
    end)
end
