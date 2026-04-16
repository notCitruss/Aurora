--// Aurora Loader v4
--// loadstring(game:HttpGet("https://raw.githubusercontent.com/notCitruss/Aurora/main/loader.lua"))()

print("[Aurora] Loader starting...")

local _loaderOk, _loaderErr = pcall(function()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local Player = Players.LocalPlayer

local API = "https://keys.dallaswebstudio.net"
local KEY_FILE = "aurora_key.txt"
local KEY_LINK = "https://work.ink/2sxb/aurora"

---------- GAME REGISTRY ----------
local GAMES = {
    [107095834793267] = "oil_empire_autofarm",
    [96840410521899]  = "timber_autofarm",
    [75251063577391]  = "brainrot_heroes_autofarm",
    [77393318863643]  = "aura_ascension",
    [135668295983945] = "skill_point_legends",
    [125007306703268] = "skill_point_incremental",
    [125007306703270] = "skill_point_incremental",
    [138665815682498] = "aim_incremental",
    [124311897657957] = "break_a_lucky_block",
    [124473577469410] = "be_a_lucky_block",
    [77595602575472]  = "zombie_game",
    [126763981794917] = "timber_spin_simulator",
    [105555311806207] = "build_a_zoo",
    [133832344745984] = "shovel_it",
    [98642908897459]  = "larp_roblox_ceo_tycoon",
    [122079988266644] = "idle_potato_game",
    [131756752872026] = "dive_down",
    [83622406313819]  = "loot_up",
    [286090429]       = "arsenal",
    [2133507413]      = "arsenal",
    [127794225497302] = "abyss",
    [606849621]       = "jailbreak",
    [109073199927285] = "tsunami",
    [109983668079237] = "sab",
    [109397169461300] = "sniper_duels",
    [16653555262]     = "swing_obby",
    [4924922222]      = "brookhaven",
    [79546208627805]  = "ninety_nine_nights",
    [2753915549]      = "blox_fruits",
    [70845479499574]  = "bite_by_night",
    [80003276594057]  = "pixel_quest",
    [92173115378522]  = "split_the_sea",
    [132391015411211] = "split_or_steal",
    [77747658251236]  = "sailor_piece",
    [81535567274521]  = "bee_garden",
    [139831748498498] = "container_rng",
}

---------- COLORS ----------
local C = {
    bg       = Color3.fromRGB(8, 8, 14),
    panel    = Color3.fromRGB(25, 25, 40),
    card     = Color3.fromRGB(22, 22, 35),
    input    = Color3.fromRGB(18, 18, 30),
    accent   = Color3.fromRGB(252, 110, 142),
    text     = Color3.fromRGB(235, 235, 245),
    dim      = Color3.fromRGB(120, 120, 135),
    green    = Color3.fromRGB(80, 200, 120),
    red      = Color3.fromRGB(255, 80, 80),
}

---------- HELPERS ----------
local scriptName = GAMES[game.PlaceId]
local uid = tostring(Player.UserId)
local hwid = "nohwid"
pcall(function() if gethwid then hwid = gethwid() end end)
pcall(function() if hwid == "nohwid" and getexecutorhwid then hwid = getexecutorhwid() end end)
pcall(function() if hwid == "nohwid" and identifyexecutor then hwid = tostring(identifyexecutor()) .. "_" .. uid end end)

local gameName = "Unknown"
pcall(function() gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name end)

local function readKey()
    local ok, k = pcall(function()
        if isfile and isfile(KEY_FILE) then return readfile(KEY_FILE):match("^%s*(.-)%s*$") end
    end)
    return ok and k and #k > 5 and k or nil
end

local function saveKey(k)
    pcall(function() if writefile then writefile(KEY_FILE, k) end end)
end

local function validate(k)
    local ok, resp = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(API .. "/validate?key=" .. k .. "&uid=" .. uid .. "&lock=" .. hwid))
    end)
    if ok and resp and resp.valid then return true, resp.tier or "free" end
    return false, (ok and resp and resp.error) or "Invalid key"
end

local function fetchScript(name, key, tier)
    local prefix = (tier == "private") and "private/" or ""
    local url = API .. "/script/" .. prefix .. name .. "?key=" .. key .. "&uid=" .. uid .. "&lock=" .. hwid
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if tier == "private" and (not ok or not src or #src < 50 or src:find("not found")) then
        url = API .. "/script/" .. name .. "?key=" .. key .. "&uid=" .. uid .. "&lock=" .. hwid
        ok, src = pcall(function() return game:HttpGet(url) end)
    end
    if ok and src and #src > 50 then return src end
    return nil
end

local function create(cl, pr, pa)
    local i = Instance.new(cl)
    for k, v in pairs(pr) do i[k] = v end
    if pa then i.Parent = pa end
    return i
end

local function corner(p, r) return create("UICorner", {CornerRadius = UDim.new(0, r)}, p) end

local function tween(obj, dur, props)
    TweenService:Create(obj, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

---------- GUI ----------
local gui = create("ScreenGui", {Name = "Aurora", ResetOnSpawn = false, DisplayOrder = 100, IgnoreGuiInset = true})
local _parentOk = false
if typeof(gethui) == "function" then _parentOk = pcall(function() gui.Parent = gethui() end) end
if not _parentOk then _parentOk = pcall(function() gui.Parent = game:GetService("CoreGui") end) end
if not _parentOk then gui.Parent = Player.PlayerGui end

---------- PHASE 1: SPLASH ----------
local overlay = create("Frame", {Size = UDim2.new(1,0,1,0), BackgroundColor3 = C.bg, BorderSizePixel = 0}, gui)

local logo = create("ImageLabel", {
    Size = UDim2.new(0,50,0,50), Position = UDim2.new(0.5,-25,0.36,0),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181", ScaleType = Enum.ScaleType.Fit,
    ImageTransparency = 1
}, overlay)

local titleLabel = create("TextLabel", {
    Size = UDim2.new(1,0,0,32), Position = UDim2.new(0,0,0.36,58),
    BackgroundTransparency = 1, TextColor3 = C.accent, TextTransparency = 1,
    TextSize = 24, Font = Enum.Font.GothamBold, Text = "Aurora"
}, overlay)

local subLabel = create("TextLabel", {
    Size = UDim2.new(1,0,0,20), Position = UDim2.new(0,0,0.36,90),
    BackgroundTransparency = 1, TextColor3 = C.dim, TextTransparency = 1,
    TextSize = 13, Font = Enum.Font.Gotham, Text = gameName
}, overlay)

-- Fade in splash
tween(logo, 0.6, {ImageTransparency = 0})
tween(titleLabel, 0.6, {TextTransparency = 0})
tween(subLabel, 0.6, {TextTransparency = 0})
task.wait(1.8)

---------- PHASE 2: KEY CHECK ----------
local savedKey = readKey()
local tier = "free"

if savedKey then
    local valid, t = validate(savedKey)
    if valid then
        tier = t or "free"
    else
        savedKey = nil
    end
end

---------- PHASE 3: KEY UI ----------
if not savedKey then
    -- Fade splash text out, keep overlay
    tween(logo, 0.3, {ImageTransparency = 1})
    tween(titleLabel, 0.3, {TextTransparency = 1})
    tween(subLabel, 0.3, {TextTransparency = 1})
    task.wait(0.4)
    logo:Destroy(); titleLabel:Destroy(); subLabel:Destroy()

    -- Key panel
    local panel = create("Frame", {
        Size = UDim2.new(0, 340, 0, 260), Position = UDim2.new(0.5, -170, 0.5, -130),
        BackgroundColor3 = C.panel, BorderSizePixel = 0, BackgroundTransparency = 1
    }, overlay)
    corner(panel, 14)
    create("UIStroke", {Color = C.accent, Thickness = 1, Transparency = 0.7}, panel)

    -- Fade panel in
    tween(panel, 0.4, {BackgroundTransparency = 0})

    -- Logo small
    create("ImageLabel", {
        Size = UDim2.new(0,28,0,28), Position = UDim2.new(0.5,-14,0,16),
        BackgroundTransparency = 1, Image = "rbxassetid://77299357494181", ScaleType = Enum.ScaleType.Fit
    }, panel)

    -- Title
    create("TextLabel", {
        Size = UDim2.new(1,0,0,24), Position = UDim2.new(0,0,0,48),
        BackgroundTransparency = 1, TextColor3 = C.text,
        TextSize = 18, Font = Enum.Font.GothamBold, Text = "Aurora Hub"
    }, panel)

    -- Subtitle
    create("TextLabel", {
        Size = UDim2.new(1,0,0,16), Position = UDim2.new(0,0,0,72),
        BackgroundTransparency = 1, TextColor3 = C.dim,
        TextSize = 11, Font = Enum.Font.Gotham, Text = "Enter your key to continue"
    }, panel)

    -- Input box
    local inputFrame = create("Frame", {
        Size = UDim2.new(1,-40,0,36), Position = UDim2.new(0,20,0,100),
        BackgroundColor3 = C.input, BorderSizePixel = 0
    }, panel)
    corner(inputFrame, 8)
    create("UIStroke", {Color = C.dim, Thickness = 1, Transparency = 0.6}, inputFrame)

    local box = create("TextBox", {
        Size = UDim2.new(1,-16,1,0), Position = UDim2.new(0,8,0,0),
        BackgroundTransparency = 1, TextColor3 = C.text,
        PlaceholderText = "Paste key here...", PlaceholderColor3 = Color3.fromRGB(80,80,95),
        TextSize = 13, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left
    }, inputFrame)

    -- Redeem button
    local btn = create("Frame", {
        Size = UDim2.new(1,-40,0,36), Position = UDim2.new(0,20,0,146),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Active = true
    }, panel)
    corner(btn, 8)
    local btnText = create("TextLabel", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        TextColor3 = Color3.new(1,1,1), TextSize = 14, Font = Enum.Font.GothamBold, Text = "Redeem"
    }, btn)

    -- Get Key link
    local getKeyBtn = create("Frame", {
        Size = UDim2.new(1,-40,0,28), Position = UDim2.new(0,20,0,190),
        BackgroundColor3 = C.card, BorderSizePixel = 0, Active = true
    }, panel)
    corner(getKeyBtn, 6)
    create("TextLabel", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        TextColor3 = C.dim, TextSize = 12, Font = Enum.Font.Gotham, Text = "Get a Free Key"
    }, getKeyBtn)

    -- Status label
    local status = create("TextLabel", {
        Size = UDim2.new(1,0,0,18), Position = UDim2.new(0,0,0,225),
        BackgroundTransparency = 1, TextColor3 = C.dim,
        TextSize = 11, Font = Enum.Font.Gotham, Text = ""
    }, panel)

    -- Get key click → copy link
    getKeyBtn.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        pcall(function() setclipboard(KEY_LINK) end)
        status.Text = "Link copied! Open in browser"
        status.TextColor3 = C.green
        task.delay(3, function() pcall(function() status.Text = "" end) end)
    end)

    -- Redeem click
    btn.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local k = box.Text:match("^%s*(.-)%s*$")
        if not k or #k < 5 then
            status.Text = "Enter a valid key"
            status.TextColor3 = C.red
            return
        end
        btnText.Text = "Validating..."
        tween(btn, 0.15, {BackgroundColor3 = Color3.fromRGB(200, 90, 120)})
        local valid, t = validate(k)
        if valid then
            status.Text = (t == "private" and "Private" or "Premium") .. " Key Valid!"
            status.TextColor3 = C.green
            tween(btn, 0.15, {BackgroundColor3 = C.green})
            btnText.Text = "Success"
            saveKey(k)
            savedKey = k
            tier = t or "free"
            task.wait(0.8)
            tween(panel, 0.3, {BackgroundTransparency = 1})
            task.wait(0.4)
            panel:Destroy()
        else
            status.Text = tostring(t)
            status.TextColor3 = C.red
            tween(btn, 0.15, {BackgroundColor3 = C.accent})
            btnText.Text = "Redeem"
        end
    end)

    -- Wait for key
    while not savedKey do task.wait(0.5) end
end

getgenv().AuroraTier = tier
getgenv().AuroraKeyTier = tier

---------- PHASE 4: LOADING ----------
-- Clear overlay, show loading
for _, ch in overlay:GetChildren() do ch:Destroy() end
overlay.BackgroundTransparency = 0

local loadLogo = create("ImageLabel", {
    Size = UDim2.new(0,40,0,40), Position = UDim2.new(0.5,-20,0.4,-30),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181", ScaleType = Enum.ScaleType.Fit
}, overlay)

local loadTitle = create("TextLabel", {
    Size = UDim2.new(1,0,0,24), Position = UDim2.new(0,0,0.4,16),
    BackgroundTransparency = 1, TextColor3 = C.text,
    TextSize = 16, Font = Enum.Font.GothamBold, Text = "Aurora"
}, overlay)

local loadStatus = create("TextLabel", {
    Size = UDim2.new(1,0,0,18), Position = UDim2.new(0,0,0.4,42),
    BackgroundTransparency = 1, TextColor3 = C.accent,
    TextSize = 12, Font = Enum.Font.Gotham, Text = "Loading " .. (scriptName or "universal"):gsub("_", " ") .. "..."
}, overlay)

task.wait(0.3)

if not scriptName then scriptName = "universal" end
local src = fetchScript(scriptName, savedKey, tier)

if src then
    loadStatus.Text = "Ready"
    loadStatus.TextColor3 = C.green
    task.wait(0.4)

    -- Fade out
    tween(overlay, 0.6, {BackgroundTransparency = 1})
    tween(loadLogo, 0.6, {ImageTransparency = 1})
    tween(loadTitle, 0.6, {TextTransparency = 1})
    tween(loadStatus, 0.6, {TextTransparency = 1})
    task.wait(0.7)
    gui:Destroy()

    -- Execute
    local ok, err = pcall(function() loadstring(src)() end)
    if not ok then
        warn("[Aurora] " .. tostring(err))
        local eg = Instance.new("ScreenGui"); eg.Name = "AuroraErr"; eg.ResetOnSpawn = false
        local _eOk = false; if typeof(gethui) == "function" then _eOk = pcall(function() eg.Parent = gethui() end) end; if not _eOk then _eOk = pcall(function() eg.Parent = game:GetService("CoreGui") end) end; if not _eOk then eg.Parent = Player.PlayerGui end
        local ef = create("Frame", {Size=UDim2.new(0,380,0,60), Position=UDim2.new(0.5,-190,0.4,0), BackgroundColor3=Color3.fromRGB(30,10,10), BorderSizePixel=0}, eg)
        corner(ef, 10)
        create("TextLabel", {Size=UDim2.new(1,-16,1,0), Position=UDim2.new(0,8,0,0), BackgroundTransparency=1, TextColor3=C.red, TextSize=12, Font=Enum.Font.GothamBold, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, Text="[Aurora] "..tostring(err):sub(1,180)}, ef)
        task.delay(10, function() pcall(function() eg:Destroy() end) end)
    end
else
    loadStatus.Text = "Failed to download script"
    loadStatus.TextColor3 = C.red
    warn("[Aurora] Download failed for: " .. tostring(scriptName))
    task.wait(5)
    pcall(function() gui:Destroy() end)
end

-- Heartbeat
pcall(function()
    task.spawn(function()
        pcall(function()
            game:HttpGet(API .. "/api/heartbeat?game=" .. HttpService:UrlEncode(scriptName or "unknown") .. "&hwid=" .. HttpService:UrlEncode(hwid) .. "&version=4&executor=" .. HttpService:UrlEncode(tostring(identifyexecutor and identifyexecutor() or "unknown")))
        end)
    end)
end)

end) -- close outer pcall

if not _loaderOk then
    warn("[Aurora] Loader crashed: " .. tostring(_loaderErr))
    pcall(function()
        local Players = game:GetService("Players")
        local Player = Players.LocalPlayer
        if not Player then return end
        local eg = Instance.new("ScreenGui")
        eg.Name = "AuroraLoaderErr"
        eg.ResetOnSpawn = false
        local _pOk = false
        if typeof(gethui) == "function" then _pOk = pcall(function() eg.Parent = gethui() end) end
        if not _pOk then _pOk = pcall(function() eg.Parent = game:GetService("CoreGui") end) end
        if not _pOk then eg.Parent = Player.PlayerGui end
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 400, 0, 80)
        f.Position = UDim2.new(0.5, -200, 0.4, 0)
        f.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
        f.BorderSizePixel = 0
        f.Parent = eg
        local uic = Instance.new("UICorner")
        uic.CornerRadius = UDim.new(0, 10)
        uic.Parent = f
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -16, 1, 0)
        l.Position = UDim2.new(0, 8, 0, 0)
        l.BackgroundTransparency = 1
        l.TextColor3 = Color3.fromRGB(255, 80, 80)
        l.TextSize = 12
        l.Font = Enum.Font.GothamBold
        l.TextWrapped = true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = "[Aurora] Loader failed: " .. tostring(_loaderErr):sub(1, 200)
        l.Parent = f
        task.delay(10, function() pcall(function() eg:Destroy() end) end)
    end)
end
