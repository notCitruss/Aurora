--// Aurora Universal Loader
--// Made by notCitruss
--// One loadstring to rule them all
--//
--// Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/notCitruss/Aurora/main/loader.lua"))()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

---------- GAME REGISTRY ----------
-- Map PlaceId -> script filename (without .lua)
-- Also map by PlaceName as fallback
local GAMES_BY_ID = {
    [107095834793267] = "oil_empire_autofarm",       -- Oil Empire
    [96840410521899]  = "timber_autofarm",            -- Timber!
    [75251063577391]  = "brainrot_heroes_autofarm",   -- Brainrot Heroes
    [77393318863643]  = "aura_ascension",             -- Aura Ascension
    [135668295983945] = "skill_point_legends",        -- +1 Skill Point Legends
}

local GAMES_BY_NAME = {
    ["oil empire"]           = "oil_empire_autofarm",
    ["timber"]               = "timber_autofarm",
    ["aura ascension"]       = "aura_ascension",
    ["+1 skill point legends"]= "skill_point_legends",
    ["brainrot heroes"]       = "brainrot_heroes_autofarm",
    ["skill point legends"]   = "skill_point_legends",
    ["rts"]                   = "rts_godmode",
}

local BASE_URL = "https://raw.githubusercontent.com/notCitruss/Aurora/main/scripts/"

---------- DETECT GAME ----------
local placeId = game.PlaceId
local placeName = game:GetService("MarketplaceService"):GetProductInfo(placeId).Name or ""
local placeNameLower = placeName:lower()

-- Try exact PlaceId match first
local scriptName = GAMES_BY_ID[placeId]

-- Fallback: match by name
if not scriptName then
    for pattern, name in pairs(GAMES_BY_NAME) do
        if placeNameLower:find(pattern) then
            scriptName = name
            break
        end
    end
end

---------- THEME ----------
local PINK = Color3.fromRGB(252, 110, 142)
local WHITE = Color3.fromRGB(255, 255, 255)
local BG = Color3.fromRGB(245, 245, 248)
local TEXT_D = Color3.fromRGB(40, 40, 50)
local GREEN = Color3.fromRGB(50, 190, 90)
local RED = Color3.fromRGB(220, 60, 60)

---------- SPLASH SCREEN ----------
for _, n in {"AuroraLoader"} do
    local old = Player.PlayerGui:FindFirstChild(n)
    if old then old:Destroy() end
end

local gui = Instance.new("ScreenGui")
gui.Name = "AuroraLoader"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Player.PlayerGui

local splash = Instance.new("Frame", gui)
splash.Size = UDim2.fromOffset(300, 120)
splash.Position = UDim2.new(0.5, -150, 0.5, -60)
splash.BackgroundColor3 = BG
splash.BackgroundTransparency = 0.04
splash.BorderSizePixel = 0
Instance.new("UICorner", splash).CornerRadius = UDim.new(0, 14)

-- Shadow
local sh = Instance.new("ImageLabel", splash)
sh.Size = UDim2.new(1, 40, 1, 40)
sh.Position = UDim2.fromOffset(-20, -20)
sh.BackgroundTransparency = 1
sh.Image = "rbxassetid://6014261993"
sh.ImageColor3 = Color3.fromRGB(180, 120, 140)
sh.ImageTransparency = 0.5
sh.ScaleType = Enum.ScaleType.Slice
sh.SliceCenter = Rect.new(49, 49, 450, 450)
sh.ZIndex = 0

-- Pink header
local header = Instance.new("Frame", splash)
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = PINK
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)
local hFix = Instance.new("Frame", header)
hFix.Size = UDim2.new(1, 0, 0, 12)
hFix.Position = UDim2.new(0, 0, 1, -12)
hFix.BackgroundColor3 = PINK
hFix.BorderSizePixel = 0

-- Blossom petals
local lf = Instance.new("Frame", header)
lf.Size = UDim2.fromOffset(32, 32)
lf.Position = UDim2.fromOffset(10, 6)
lf.BackgroundTransparency = 1
for i = 0, 4 do
    local a = math.rad(i * 72 - 90)
    local p = Instance.new("Frame", lf)
    p.Size = UDim2.fromOffset(13, 13)
    p.Position = UDim2.fromOffset(16 + math.cos(a) * 9 - 6, 16 + math.sin(a) * 9 - 6)
    p.BackgroundColor3 = Color3.fromRGB(255, 210, 225)
    p.BackgroundTransparency = 0.1
    p.BorderSizePixel = 0
    p.Rotation = i * 72
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, 6)
end
local ct = Instance.new("Frame", lf)
ct.Size = UDim2.fromOffset(8, 8)
ct.Position = UDim2.fromOffset(12, 12)
ct.BackgroundColor3 = WHITE
ct.BorderSizePixel = 0
Instance.new("UICorner", ct).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(0, 180, 0, 22)
title.Position = UDim2.fromOffset(48, 4)
title.BackgroundTransparency = 1
title.Text = "Aurora"
title.TextColor3 = WHITE
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left

local sub = Instance.new("TextLabel", header)
sub.Size = UDim2.new(0, 200, 0, 12)
sub.Position = UDim2.fromOffset(48, 26)
sub.BackgroundTransparency = 1
sub.Text = "by notCitruss"
sub.TextColor3 = Color3.fromRGB(255, 225, 235)
sub.TextSize = 10
sub.Font = Enum.Font.Gotham
sub.TextXAlignment = Enum.TextXAlignment.Left

-- Status text
local statusLbl = Instance.new("TextLabel", splash)
statusLbl.Size = UDim2.new(1, -20, 0, 16)
statusLbl.Position = UDim2.fromOffset(10, 52)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Detecting game..."
statusLbl.TextColor3 = TEXT_D
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.GothamSemibold
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Game name
local gameLbl = Instance.new("TextLabel", splash)
gameLbl.Size = UDim2.new(1, -20, 0, 14)
gameLbl.Position = UDim2.fromOffset(10, 70)
gameLbl.BackgroundTransparency = 1
gameLbl.Text = placeName
gameLbl.TextColor3 = PINK
gameLbl.TextSize = 10
gameLbl.Font = Enum.Font.Gotham
gameLbl.TextXAlignment = Enum.TextXAlignment.Left
gameLbl.TextTruncate = Enum.TextTruncate.AtEnd

-- Progress bar
local barBg = Instance.new("Frame", splash)
barBg.Size = UDim2.new(1, -20, 0, 4)
barBg.Position = UDim2.fromOffset(10, 100)
barBg.BackgroundColor3 = Color3.fromRGB(230, 225, 230)
barBg.BorderSizePixel = 0
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

local barFill = Instance.new("Frame", barBg)
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = PINK
barFill.BorderSizePixel = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

---------- LOAD ----------
task.spawn(function()
    -- Animate progress bar
    TweenService:Create(barFill, TweenInfo.new(0.5), {Size = UDim2.new(0.3, 0, 1, 0)}):Play()

    if scriptName then
        statusLbl.Text = "Loading " .. scriptName:gsub("_", " ") .. "..."
        statusLbl.TextColor3 = TEXT_D
        task.wait(0.5)

        TweenService:Create(barFill, TweenInfo.new(0.3), {Size = UDim2.new(0.6, 0, 1, 0)}):Play()

        local url = BASE_URL .. scriptName .. ".lua"
        local success, result = pcall(function()
            return game:HttpGet(url)
        end)

        if success and result then
            TweenService:Create(barFill, TweenInfo.new(0.3), {Size = UDim2.new(0.9, 0, 1, 0)}):Play()
            statusLbl.Text = "Executing..."

            local loadSuccess, loadErr = pcall(function()
                loadstring(result)()
            end)

            if loadSuccess then
                TweenService:Create(barFill, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = GREEN}):Play()
                statusLbl.Text = "Loaded!"
                statusLbl.TextColor3 = GREEN
                task.wait(1.5)
                TweenService:Create(splash, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
                task.wait(0.4)
                gui:Destroy()
            else
                barFill.BackgroundColor3 = RED
                statusLbl.Text = "Error: " .. tostring(loadErr):sub(1, 60)
                statusLbl.TextColor3 = RED
            end
        else
            barFill.BackgroundColor3 = RED
            statusLbl.Text = "Failed to download script"
            statusLbl.TextColor3 = RED
        end
    else
        TweenService:Create(barFill, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = RED}):Play()
        statusLbl.Text = "No script for this game"
        statusLbl.TextColor3 = RED
        gameLbl.Text = placeName .. " (ID: " .. placeId .. ")"

        task.wait(4)
        TweenService:Create(splash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        task.wait(0.6)
        gui:Destroy()
    end
end)
