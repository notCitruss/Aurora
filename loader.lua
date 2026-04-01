--// Aurora Universal Loader — with Key System
--// Made by notCitruss
--// Usage: loadstring(game:HttpGet("https://keys.dallaswebstudio.net/loader.lua"))()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

---------- GAME REGISTRY ----------
local GAMES_BY_ID = {
    [107095834793267] = "oil_empire_autofarm",
    [96840410521899]  = "timber_autofarm",
    [75251063577391]  = "brainrot_heroes_autofarm",
    [77393318863643]  = "aura_ascension",
    [135668295983945] = "skill_point_legends",
    [138665815682498] = "aim_incremental",
    [124311897657957] = "break_a_lucky_block",
    [124473577469410] = "be_a_lucky_block",
    [77595602575472]  = "zombie_game",
}

local GAMES_BY_NAME = {
    ["oil empire"]           = "oil_empire_autofarm",
    ["timber"]               = "timber_autofarm",
    ["aura ascension"]       = "aura_ascension",
    ["+1 skill point legends"]= "skill_point_legends",
    ["brainrot heroes"]       = "brainrot_heroes_autofarm",
    ["skill point legends"]   = "skill_point_legends",
    ["aim incremental"]      = "aim_incremental",
    ["break a lucky block"]  = "break_a_lucky_block",
    ["be a lucky block"]     = "be_a_lucky_block",
    ["zombie"]               = "zombie_game",
}

local BASE_URL = "https://keys.dallaswebstudio.net/script/"
local KEY_API = "https://keys.dallaswebstudio.net"
local KEY_LINK = "https://work.ink/2sxb/aurora"
local KEY_FILE = "aurora_key.txt"

---------- DETECT GAME ----------
local placeId = game.PlaceId
local placeName = game:GetService("MarketplaceService"):GetProductInfo(placeId).Name or ""
local placeNameLower = placeName:lower()
local scriptName = GAMES_BY_ID[placeId]
if not scriptName then
    for pattern, name in pairs(GAMES_BY_NAME) do
        if placeNameLower:find(pattern) then scriptName = name; break end
    end
end

---------- KEY SYSTEM ----------
local function readKey()
    local ok, key = pcall(function()
        if isfile and isfile(KEY_FILE) then return readfile(KEY_FILE) end
        return nil
    end)
    return ok and key or nil
end

local function saveKey(key)
    pcall(function()
        if writefile then writefile(KEY_FILE, key) end
    end)
end

local function validateKey(key)
    if not key or #key < 10 then return false, nil end
    local ok, result = pcall(function()
        local uid = tostring(Player.UserId)
        local resp = game:HttpGet(KEY_API .. "/validate?key=" .. key .. "&uid=" .. uid, true)
        local data = HttpService:JSONDecode(resp)
        if data and data.valid == true then return true end
        return false, data and data.error or nil
    end)
    return ok and result
end

---------- THEME ----------
local PINK = Color3.fromRGB(252, 110, 142)
local PINK_D = Color3.fromRGB(220, 75, 110)
local PINK_XL = Color3.fromRGB(255, 230, 238)
local WHITE = Color3.fromRGB(255, 255, 255)
local BG = Color3.fromRGB(245, 245, 248)
local BG_CARD = Color3.fromRGB(255, 255, 255)
local TEXT_D = Color3.fromRGB(40, 40, 50)
local TEXT_M = Color3.fromRGB(100, 100, 115)
local GREEN = Color3.fromRGB(50, 190, 90)
local RED = Color3.fromRGB(220, 60, 60)

---------- CLEANUP ----------
for _, n in {"AuroraLoader", "AuroraKey"} do
    local old = Player.PlayerGui:FindFirstChild(n)
    if old then old:Destroy() end
end

---------- KEY CHECK ----------
local savedKey = readKey()
if savedKey and validateKey(savedKey) then
    -- Key is valid — skip key UI, go straight to loading
else
    -- Show key UI
    local gui = Instance.new("ScreenGui")
    gui.Name = "AuroraKey"; gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = Player.PlayerGui

    local main = Instance.new("Frame", gui)
    main.Size = UDim2.fromOffset(340, 280); main.Position = UDim2.new(0.5, -170, 0.5, -140)
    main.BackgroundColor3 = BG; main.BackgroundTransparency = 0.02; main.BorderSizePixel = 0
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

    -- Shadow
    local sh = Instance.new("ImageLabel", main)
    sh.Size = UDim2.new(1, 40, 1, 40); sh.Position = UDim2.fromOffset(-20, -20)
    sh.BackgroundTransparency = 1; sh.Image = "rbxassetid://6014261993"
    sh.ImageColor3 = Color3.fromRGB(180, 120, 140); sh.ImageTransparency = 0.5
    sh.ScaleType = Enum.ScaleType.Slice; sh.SliceCenter = Rect.new(49, 49, 450, 450); sh.ZIndex = 0

    -- Header
    local header = Instance.new("Frame", main)
    header.Size = UDim2.new(1, 0, 0, 48); header.BackgroundColor3 = PINK; header.BorderSizePixel = 0
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)
    local hFix = Instance.new("Frame", header)
    hFix.Size = UDim2.new(1, 0, 0, 14); hFix.Position = UDim2.new(0, 0, 1, -14)
    hFix.BackgroundColor3 = PINK; hFix.BorderSizePixel = 0

    -- Blossom logo
    local lf = Instance.new("Frame", header)
    lf.Size = UDim2.fromOffset(34, 34); lf.Position = UDim2.fromOffset(12, 7); lf.BackgroundTransparency = 1
    for i = 0, 4 do
        local a = math.rad(i * 72 - 90)
        local p = Instance.new("Frame", lf)
        p.Size = UDim2.fromOffset(14, 14)
        p.Position = UDim2.fromOffset(17 + math.cos(a) * 10 - 7, 17 + math.sin(a) * 10 - 7)
        p.BackgroundColor3 = Color3.fromRGB(255, 210, 225); p.BackgroundTransparency = 0.1; p.BorderSizePixel = 0; p.Rotation = i * 72
        Instance.new("UICorner", p).CornerRadius = UDim.new(0, 6)
    end
    local ct = Instance.new("Frame", lf)
    ct.Size = UDim2.fromOffset(8, 8); ct.Position = UDim2.fromOffset(13, 13)
    ct.BackgroundColor3 = WHITE; ct.BackgroundTransparency = 0.1; ct.BorderSizePixel = 0
    Instance.new("UICorner", ct).CornerRadius = UDim.new(1, 0)

    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(0, 180, 0, 22); title.Position = UDim2.fromOffset(52, 4)
    title.BackgroundTransparency = 1; title.Text = "Aurora"; title.TextColor3 = WHITE
    title.TextSize = 20; title.Font = Enum.Font.GothamBold; title.TextXAlignment = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", header)
    sub.Size = UDim2.new(0, 200, 0, 12); sub.Position = UDim2.fromOffset(52, 28)
    sub.BackgroundTransparency = 1; sub.Text = "Key System"; sub.TextColor3 = PINK_XL
    sub.TextSize = 9; sub.Font = Enum.Font.Gotham; sub.TextXAlignment = Enum.TextXAlignment.Left

    -- Instructions
    local instr = Instance.new("TextLabel", main)
    instr.Size = UDim2.new(1, -32, 0, 30); instr.Position = UDim2.fromOffset(16, 58)
    instr.BackgroundTransparency = 1; instr.Text = "Get a key to use Aurora scripts"
    instr.TextColor3 = TEXT_D; instr.TextSize = 12; instr.Font = Enum.Font.GothamSemibold
    instr.TextXAlignment = Enum.TextXAlignment.Center

    -- Get Key button
    local getBtn = Instance.new("Frame", main)
    getBtn.Size = UDim2.new(1, -32, 0, 36); getBtn.Position = UDim2.fromOffset(16, 94)
    getBtn.BackgroundColor3 = PINK; getBtn.BorderSizePixel = 0; getBtn.Active = true
    Instance.new("UICorner", getBtn).CornerRadius = UDim.new(0, 8)
    local getBtnLbl = Instance.new("TextLabel", getBtn)
    getBtnLbl.Size = UDim2.new(1, 0, 1, 0); getBtnLbl.BackgroundTransparency = 1
    getBtnLbl.Text = "Get Key (opens browser)"; getBtnLbl.TextColor3 = WHITE
    getBtnLbl.TextSize = 13; getBtnLbl.Font = Enum.Font.GothamBold

    getBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pcall(function()
                if setclipboard then setclipboard(KEY_LINK) end
            end)
            pcall(function()
                if (request or http_request or syn and syn.request) then
                    -- Try to open in browser
                    local openUrl = request or http_request or (syn and syn.request)
                    if openUrl then
                        pcall(function() openUrl({Url = KEY_LINK, Method = "GET"}) end)
                    end
                end
            end)
            getBtnLbl.Text = "Link copied! Paste in browser"
            getBtnLbl.TextColor3 = Color3.fromRGB(255, 220, 230)
            task.delay(3, function()
                getBtnLbl.Text = "Get Key (opens browser)"
                getBtnLbl.TextColor3 = WHITE
            end)
        end
    end)

    -- Divider
    local div = Instance.new("Frame", main)
    div.Size = UDim2.new(1, -32, 0, 1); div.Position = UDim2.fromOffset(16, 140)
    div.BackgroundColor3 = Color3.fromRGB(220, 215, 225); div.BorderSizePixel = 0

    -- Key input label
    local inputLbl = Instance.new("TextLabel", main)
    inputLbl.Size = UDim2.new(1, -32, 0, 16); inputLbl.Position = UDim2.fromOffset(16, 150)
    inputLbl.BackgroundTransparency = 1; inputLbl.Text = "PASTE YOUR KEY"
    inputLbl.TextColor3 = PINK_D; inputLbl.TextSize = 9; inputLbl.Font = Enum.Font.GothamBold
    inputLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Key input box
    local inputBox = Instance.new("TextBox", main)
    inputBox.Size = UDim2.new(1, -32, 0, 36); inputBox.Position = UDim2.fromOffset(16, 170)
    inputBox.BackgroundColor3 = BG_CARD; inputBox.BorderSizePixel = 0
    inputBox.Text = ""; inputBox.PlaceholderText = "AURORA-XXXX-XXXX-XXXX"
    inputBox.TextColor3 = TEXT_D; inputBox.PlaceholderColor3 = TEXT_M
    inputBox.TextSize = 14; inputBox.Font = Enum.Font.GothamSemibold; inputBox.ClearTextOnFocus = false
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", inputBox).Color = Color3.fromRGB(200, 195, 210)
    Instance.new("UIPadding", inputBox).PaddingLeft = UDim.new(0, 12)

    -- Status label
    local statusLbl = Instance.new("TextLabel", main)
    statusLbl.Size = UDim2.new(1, -32, 0, 14); statusLbl.Position = UDim2.fromOffset(16, 212)
    statusLbl.BackgroundTransparency = 1; statusLbl.Text = ""
    statusLbl.TextColor3 = TEXT_M; statusLbl.TextSize = 10; statusLbl.Font = Enum.Font.GothamSemibold
    statusLbl.TextXAlignment = Enum.TextXAlignment.Center

    -- Verify button
    local verBtn = Instance.new("Frame", main)
    verBtn.Size = UDim2.new(1, -32, 0, 36); verBtn.Position = UDim2.fromOffset(16, 232)
    verBtn.BackgroundColor3 = BG_CARD; verBtn.BorderSizePixel = 0; verBtn.Active = true
    Instance.new("UICorner", verBtn).CornerRadius = UDim.new(0, 8)
    local verStroke = Instance.new("UIStroke", verBtn); verStroke.Color = PINK; verStroke.Transparency = 0.3
    local verLbl = Instance.new("TextLabel", verBtn)
    verLbl.Size = UDim2.new(1, 0, 1, 0); verLbl.BackgroundTransparency = 1
    verLbl.Text = "Verify Key"; verLbl.TextColor3 = PINK_D
    verLbl.TextSize = 13; verLbl.Font = Enum.Font.GothamBold

    verBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local key = inputBox.Text:gsub("%s+", "")
            if #key < 10 then
                statusLbl.Text = "Invalid key format"
                statusLbl.TextColor3 = RED
                return
            end

            statusLbl.Text = "Validating..."
            statusLbl.TextColor3 = TEXT_M
            verLbl.Text = "Checking..."

            task.spawn(function()
                local ok, result = pcall(function()
                    local uid = tostring(Player.UserId)
                    local resp = game:HttpGet(KEY_API .. "/validate?key=" .. key .. "&uid=" .. uid, true)
                    return HttpService:JSONDecode(resp)
                end)

                if ok and result and result.valid then
                    saveKey(key)
                    statusLbl.Text = "Key valid! Loading..."
                    statusLbl.TextColor3 = GREEN
                    verBtn.BackgroundColor3 = GREEN
                    verLbl.Text = "Valid!"
                    verLbl.TextColor3 = WHITE
                    task.wait(1)
                    gui:Destroy()
                    savedKey = key
                else
                    local errMsg = (ok and result and result.error) or "Invalid or expired key"
                    statusLbl.Text = errMsg
                    statusLbl.TextColor3 = RED
                    verLbl.Text = "Verify Key"
                    verLbl.TextColor3 = PINK_D
                    verBtn.BackgroundColor3 = BG_CARD
                end
            end)
        end
    end)

    -- Wait for valid key
    while not savedKey or not validateKey(savedKey) do
        task.wait(0.5)
        savedKey = readKey()
    end

    pcall(function() gui:Destroy() end)
end

---------- SPLASH + LOAD SCRIPT ----------
-- (same splash screen as current loader)
for _, n in {"AuroraLoader"} do
    local old = Player.PlayerGui:FindFirstChild(n)
    if old then old:Destroy() end
end

local gui2 = Instance.new("ScreenGui")
gui2.Name = "AuroraLoader"; gui2.ResetOnSpawn = false
gui2.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui2.Parent = Player.PlayerGui

local splash = Instance.new("Frame", gui2)
splash.Size = UDim2.fromOffset(300, 120); splash.Position = UDim2.new(0.5, -150, 0.5, -60)
splash.BackgroundColor3 = BG; splash.BackgroundTransparency = 0.04; splash.BorderSizePixel = 0
Instance.new("UICorner", splash).CornerRadius = UDim.new(0, 14)

local sh2 = Instance.new("ImageLabel", splash)
sh2.Size = UDim2.new(1, 40, 1, 40); sh2.Position = UDim2.fromOffset(-20, -20)
sh2.BackgroundTransparency = 1; sh2.Image = "rbxassetid://6014261993"
sh2.ImageColor3 = Color3.fromRGB(180, 120, 140); sh2.ImageTransparency = 0.5
sh2.ScaleType = Enum.ScaleType.Slice; sh2.SliceCenter = Rect.new(49, 49, 450, 450); sh2.ZIndex = 0

local header2 = Instance.new("Frame", splash)
header2.Size = UDim2.new(1, 0, 0, 44); header2.BackgroundColor3 = PINK; header2.BorderSizePixel = 0
Instance.new("UICorner", header2).CornerRadius = UDim.new(0, 14)
local hFix2 = Instance.new("Frame", header2)
hFix2.Size = UDim2.new(1, 0, 0, 12); hFix2.Position = UDim2.new(0, 0, 1, -12)
hFix2.BackgroundColor3 = PINK; hFix2.BorderSizePixel = 0

local lf2 = Instance.new("Frame", header2)
lf2.Size = UDim2.fromOffset(32, 32); lf2.Position = UDim2.fromOffset(10, 6); lf2.BackgroundTransparency = 1
for i = 0, 4 do
    local a = math.rad(i * 72 - 90)
    local p = Instance.new("Frame", lf2)
    p.Size = UDim2.fromOffset(13, 13)
    p.Position = UDim2.fromOffset(16 + math.cos(a) * 9 - 6, 16 + math.sin(a) * 9 - 6)
    p.BackgroundColor3 = Color3.fromRGB(255, 210, 225); p.BackgroundTransparency = 0.1; p.BorderSizePixel = 0; p.Rotation = i * 72
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, 6)
end
local ct2 = Instance.new("Frame", lf2)
ct2.Size = UDim2.fromOffset(8, 8); ct2.Position = UDim2.fromOffset(12, 12)
ct2.BackgroundColor3 = WHITE; ct2.BorderSizePixel = 0
Instance.new("UICorner", ct2).CornerRadius = UDim.new(1, 0)

local title2 = Instance.new("TextLabel", header2)
title2.Size = UDim2.new(0, 180, 0, 22); title2.Position = UDim2.fromOffset(48, 4)
title2.BackgroundTransparency = 1; title2.Text = "Aurora"; title2.TextColor3 = WHITE
title2.TextSize = 20; title2.Font = Enum.Font.GothamBold; title2.TextXAlignment = Enum.TextXAlignment.Left

local sub2 = Instance.new("TextLabel", header2)
sub2.Size = UDim2.new(0, 200, 0, 12); sub2.Position = UDim2.fromOffset(48, 26)
sub2.BackgroundTransparency = 1; sub2.Text = "by notCitruss"; sub2.TextColor3 = Color3.fromRGB(255, 225, 235)
sub2.TextSize = 10; sub2.Font = Enum.Font.Gotham; sub2.TextXAlignment = Enum.TextXAlignment.Left

local statusLbl2 = Instance.new("TextLabel", splash)
statusLbl2.Size = UDim2.new(1, -20, 0, 16); statusLbl2.Position = UDim2.fromOffset(10, 52)
statusLbl2.BackgroundTransparency = 1; statusLbl2.Text = "Detecting game..."
statusLbl2.TextColor3 = TEXT_D; statusLbl2.TextSize = 12; statusLbl2.Font = Enum.Font.GothamSemibold
statusLbl2.TextXAlignment = Enum.TextXAlignment.Left

local gameLbl = Instance.new("TextLabel", splash)
gameLbl.Size = UDim2.new(1, -20, 0, 14); gameLbl.Position = UDim2.fromOffset(10, 70)
gameLbl.BackgroundTransparency = 1; gameLbl.Text = placeName; gameLbl.TextColor3 = PINK
gameLbl.TextSize = 10; gameLbl.Font = Enum.Font.Gotham; gameLbl.TextXAlignment = Enum.TextXAlignment.Left
gameLbl.TextTruncate = Enum.TextTruncate.AtEnd

local barBg = Instance.new("Frame", splash)
barBg.Size = UDim2.new(1, -20, 0, 4); barBg.Position = UDim2.fromOffset(10, 100)
barBg.BackgroundColor3 = Color3.fromRGB(230, 225, 230); barBg.BorderSizePixel = 0
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
local barFill = Instance.new("Frame", barBg)
barFill.Size = UDim2.new(0, 0, 1, 0); barFill.BackgroundColor3 = PINK; barFill.BorderSizePixel = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

task.spawn(function()
    TweenService:Create(barFill, TweenInfo.new(0.5), {Size = UDim2.new(0.3, 0, 1, 0)}):Play()

    if scriptName then
        statusLbl2.Text = "Loading " .. scriptName:gsub("_", " ") .. "..."
        task.wait(0.5)
        TweenService:Create(barFill, TweenInfo.new(0.3), {Size = UDim2.new(0.6, 0, 1, 0)}):Play()

        local uid = tostring(Player.UserId)
        local url = BASE_URL .. scriptName .. "?key=" .. (savedKey or "") .. "&uid=" .. uid
        local success, result = pcall(function() return game:HttpGet(url) end)

        if success and result then
            TweenService:Create(barFill, TweenInfo.new(0.3), {Size = UDim2.new(0.9, 0, 1, 0)}):Play()
            statusLbl2.Text = "Executing..."

            local loadSuccess, loadErr = pcall(function() loadstring(result)() end)

            if loadSuccess then
                TweenService:Create(barFill, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = GREEN}):Play()
                statusLbl2.Text = "Loaded!"; statusLbl2.TextColor3 = GREEN
                task.wait(1.5)
                TweenService:Create(splash, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
                task.wait(0.4); gui2:Destroy()
            else
                barFill.BackgroundColor3 = RED
                statusLbl2.Text = "Error: " .. tostring(loadErr):sub(1, 60); statusLbl2.TextColor3 = RED
            end
        else
            barFill.BackgroundColor3 = RED
            statusLbl2.Text = "Failed to download script"; statusLbl2.TextColor3 = RED
        end
    else
        TweenService:Create(barFill, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = RED}):Play()
        statusLbl2.Text = "No script for this game"; statusLbl2.TextColor3 = RED
        gameLbl.Text = placeName .. " (ID: " .. placeId .. ")"
        task.wait(4)
        TweenService:Create(splash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        task.wait(0.6); gui2:Destroy()
    end
end)
