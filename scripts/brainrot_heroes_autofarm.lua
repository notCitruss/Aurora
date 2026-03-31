--// Aurora v2.0 — Brainrot Heroes Auto-Farm
--// Made by notCitruss
--// Multi-select sell/hero filters, circle tracker, anti-cheat proof UI
--// All interactive elements use Frames (game anti-cheat kills TextButtons)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

for _, n in {"Aurora"} do local old = Player.PlayerGui:FindFirstChild(n); if old then old:Destroy() end end

---------- REMOTES ----------
local Remotes = RS:WaitForChild("Remotes")

---------- CONFIG ----------
local CFG = {
    AutoCollect = false, AutoSell = false, AutoRebirth = false,
    AutoBuyHeroes = false, AutoEquip = false, AutoLucky = false,
    AutoBuyGear = false, SpeedBoost = false, AntiAFK = false,
}

---------- RARITY DATA ----------
local RARITY_ORDER = {"Rare", "Epic", "Legendary", "Mythic", "Godly", "Secret", "Celestial"}

local SELL_FILTER = {Rare = true, Epic = true, Legendary = false, Mythic = false, Godly = false, Secret = false, Celestial = false}
local HERO_BUY = {Rare = true, Epic = true, Legendary = true, Mythic = true, Godly = true, Secret = false, Celestial = false}

---------- HERO DATA (from Config.Hero) ----------
local HERO_DATA = {}
pcall(function()
    local cfg = require(RS.Get.Config)
    if cfg and cfg.Hero then
        for k, v in pairs(cfg.Hero) do
            if typeof(v) == "table" and v.Cost then
                HERO_DATA[k] = {Name = v.Name or k, Cost = v.Cost, Rarity = v.Rarity, Damage = v.Damage}
            end
        end
    end
end)

local HERO_PRICE_RANGE = {}
for _, r in RARITY_ORDER do
    local lo, hi = math.huge, 0
    for _, h in pairs(HERO_DATA) do
        if h.Rarity == r then lo = math.min(lo, h.Cost); hi = math.max(hi, h.Cost) end
    end
    HERO_PRICE_RANGE[r] = lo < math.huge and {lo, hi} or nil
end

---------- STATE ----------
local _cash, _rebirths = 0, 0
local _circleSpawns = {}
local _lastBrainrot = nil
local _bestCircleHero = nil
local S = {collects = 0, sells = 0, sellCash = 0, rebirths = 0, heroes = 0, lucky = 0, gears = 0}

---------- HELPERS ----------
local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e15 then return string.format("%.1fQ", n / 1e15)
    elseif n >= 1e12 then return string.format("%.1fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local function updateBestCircleHero()
    local best = nil
    for _, data in pairs(_circleSpawns) do
        local h = HERO_DATA[data.Id]
        if h then
            if not best or h.Cost > best.Cost then best = {Id = data.Id, Cost = h.Cost, Rarity = h.Rarity, SpawnId = data.SpawnId} end
        end
    end
    _bestCircleHero = best
end

---------- LISTENERS ----------
Remotes.CurrencyUpdated.OnClientEvent:Connect(function(c, a) if c == "Cash" then _cash = a end end)

Remotes.HeroCircleUpdate.OnClientEvent:Connect(function(action, data)
    if action == "Spawn" and typeof(data) == "table" then
        _circleSpawns[data.SpawnId] = data
        -- Reactive buy: teleport NOW, buy after 3s
        local spawnId = data.SpawnId
        local heroId = data.Id
        task.spawn(function()
            if not CFG.AutoBuyHeroes then return end
            local h = HERO_DATA[heroId]
            if h and not HERO_BUY[h.Rarity] then return end
            if h and h.Cost > _cash then return end
            -- Teleport to circle center IMMEDIATELY (gives server 3s to sync position)
            pcall(function()
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(0, 3, 0) end
            end)
            -- Wait 3s for TooEarly cooldown + server position sync
            task.wait(3)
            -- Buy
            local ok, s = pcall(function() return Remotes.PurchaseCircleHero:InvokeServer(spawnId, heroId) end)
            if ok and s then
                _circleSpawns[spawnId] = nil
                S.heroes += 1
                updateBestCircleHero()
            end
        end)
    elseif action == "Remove" then
        _circleSpawns[tonumber(data)] = nil
    end
    updateBestCircleHero()
end)

Remotes.RenderBrainrot.OnClientEvent:Connect(function(data)
    if typeof(data) == "table" then _lastBrainrot = data end
end)

task.spawn(function()
    pcall(function()
        local d = Remotes.GetPlayerData:InvokeServer()
        if typeof(d) == "table" then
            if typeof(d.Currency) == "table" then _cash = d.Currency.Cash or _cash end
            _rebirths = d.Rebirth or _rebirths
        end
    end)
end)

---------- CORE FUNCTIONS ----------
local function collectIncome()
    for i = 1, 20 do
        local ok, r = pcall(function() return Remotes.CollectBrainrotIncome:InvokeServer(i) end)
        if ok and r then S.collects += 1 end
    end
end

local function sellBulk()
    local filter = {}
    for r, on in pairs(SELL_FILTER) do if on then filter[r] = true end end
    if not next(filter) then return end
    local ok, s, e = pcall(function() return Remotes.SellBulk:InvokeServer("Brainrot", filter) end)
    if ok and s then S.sells += 1; S.sellCash += (e or 0) end
end

local function doRebirth()
    local ok, r = pcall(function() return Remotes.AttemptRebirth:InvokeServer() end)
    if ok and r then S.rebirths += 1; _rebirths += 1 end
end

local function buyHero(data)
    local h = HERO_DATA[data.Id]
    if h and not HERO_BUY[h.Rarity] then return end
    local ok, s = pcall(function() return Remotes.PurchaseCircleHero:InvokeServer(data.SpawnId, data.Id) end)
    if ok and s then _circleSpawns[data.SpawnId] = nil; S.heroes += 1; updateBestCircleHero() end
end

local function equipBest()
    pcall(function() Remotes.EquipBestHeroes:InvokeServer() end)
    pcall(function() Remotes.EquipBestBrainrots:InvokeServer() end)
end

local function buyAllGear()
    local ok, stock = pcall(function() return Remotes.GetShopStock:InvokeServer() end)
    if not ok or typeof(stock) ~= "table" then return end
    for gearName, count in pairs(stock) do
        if count > 0 then
            for _ = 1, count do
                local ok2, r = pcall(function() return Remotes.PurchaseShopGear:InvokeServer(gearName) end)
                if ok2 and r then S.gears += 1 end
                task.wait(0.3)
            end
        end
    end
end

---------- LOOPS ----------
task.spawn(function() while true do if CFG.AutoCollect then collectIncome() end; task.wait(15) end end)
task.spawn(function() while true do if CFG.AutoSell then sellBulk() end; task.wait(8) end end)
task.spawn(function() while true do if CFG.AutoRebirth then doRebirth() end; task.wait(10) end end)
-- Hero buying is now reactive (triggered on spawn event with 3s delay)
task.spawn(function() while true do if CFG.AutoEquip then equipBest() end; task.wait(15) end end)
task.spawn(function() while true do if CFG.AutoBuyGear then buyAllGear() end; task.wait(10) end end)
task.spawn(function()
    while true do
        if CFG.AutoLucky then pcall(function() Remotes.UseLuckyBlock:InvokeServer() end); S.lucky += 1 end
        task.wait(3)
    end
end)

local _speedOn = false
RunService.Heartbeat:Connect(function()
    pcall(function()
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if CFG.SpeedBoost then hum.WalkSpeed = 80; hum.JumpPower = 80; _speedOn = true
        elseif _speedOn then hum.WalkSpeed = 16; hum.JumpPower = 50; _speedOn = false end
    end)
end)

task.spawn(function()
    while true do
        if CFG.AntiAFK then pcall(function() local v = game:GetService("VirtualUser"); v:CaptureController(); v:ClickButton2(Vector2.new()) end) end
        task.wait(60)
    end
end)

---------- THEME ----------
local PINK = Color3.fromRGB(252, 110, 142)
local PINK_D = Color3.fromRGB(220, 75, 110)
local PINK_L = Color3.fromRGB(255, 200, 215)
local PINK_XL = Color3.fromRGB(255, 230, 238)
local WHITE = Color3.fromRGB(255, 255, 255)
local BG = Color3.fromRGB(245, 245, 248)
local BG_CARD = Color3.fromRGB(255, 255, 255)
local TEXT_D = Color3.fromRGB(40, 40, 50)
local TEXT_M = Color3.fromRGB(100, 100, 115)
local OFF_BG = Color3.fromRGB(218, 218, 225)
local GREEN = Color3.fromRGB(50, 190, 90)

local RARITY_COLORS = {
    Rare = Color3.fromRGB(80, 160, 255), Epic = Color3.fromRGB(180, 80, 255),
    Legendary = Color3.fromRGB(255, 180, 30), Mythic = Color3.fromRGB(255, 60, 80),
    Godly = Color3.fromRGB(255, 50, 200), Secret = Color3.fromRGB(50, 220, 180),
    Celestial = Color3.fromRGB(255, 220, 80), Limited = Color3.fromRGB(200, 200, 200),
}

local LEFT_W, RIGHT_W = 320, 240
local TOTAL_W = LEFT_W + RIGHT_W

---------- GUI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "Aurora"; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50; gui.Parent = Player.PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(TOTAL_W, 0); main.Position = UDim2.fromOffset(16, 60)
main.BackgroundColor3 = BG; main.BackgroundTransparency = 0.04; main.BorderSizePixel = 0
main.Parent = gui; main.Active = true; main.Draggable = true; main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

local sh = Instance.new("ImageLabel", main)
sh.Size = UDim2.new(1, 44, 1, 44); sh.Position = UDim2.fromOffset(-22, -22)
sh.BackgroundTransparency = 1; sh.Image = "rbxassetid://6014261993"
sh.ImageColor3 = Color3.fromRGB(180, 120, 140); sh.ImageTransparency = 0.5
sh.ScaleType = Enum.ScaleType.Slice; sh.SliceCenter = Rect.new(49, 49, 450, 450); sh.ZIndex = 0

---------- TITLE BAR ----------
local tBar = Instance.new("Frame", main)
tBar.Size = UDim2.new(1, 0, 0, 48); tBar.BackgroundColor3 = PINK; tBar.BorderSizePixel = 0
Instance.new("UICorner", tBar).CornerRadius = UDim.new(0, 14)
local tFix = Instance.new("Frame", tBar)
tFix.Size = UDim2.new(1, 0, 0, 14); tFix.Position = UDim2.new(0, 0, 1, -14); tFix.BackgroundColor3 = PINK; tFix.BorderSizePixel = 0

local lf = Instance.new("Frame", tBar)
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

local tLbl = Instance.new("TextLabel", tBar)
tLbl.Size = UDim2.new(0, 180, 0, 22); tLbl.Position = UDim2.fromOffset(52, 4)
tLbl.BackgroundTransparency = 1; tLbl.Text = "Aurora"; tLbl.TextColor3 = WHITE
tLbl.TextSize = 20; tLbl.Font = Enum.Font.GothamBold; tLbl.TextXAlignment = Enum.TextXAlignment.Left

local sLbl2 = Instance.new("TextLabel", tBar)
sLbl2.Size = UDim2.new(0, 250, 0, 12); sLbl2.Position = UDim2.fromOffset(52, 28)
sLbl2.BackgroundTransparency = 1; sLbl2.Text = "by notCitruss  \xE2\x80\x94  Brainrot Heroes v2"
sLbl2.TextColor3 = PINK_XL; sLbl2.TextSize = 9; sLbl2.Font = Enum.Font.Gotham; sLbl2.TextXAlignment = Enum.TextXAlignment.Left

---------- PANELS ----------
local TITLE_H = 48
local leftP = Instance.new("Frame", main)
leftP.Size = UDim2.new(0, LEFT_W, 1, -TITLE_H); leftP.Position = UDim2.fromOffset(0, TITLE_H)
leftP.BackgroundTransparency = 1; leftP.BorderSizePixel = 0

local rightScroll = Instance.new("ScrollingFrame", main)
rightScroll.Size = UDim2.new(0, RIGHT_W, 1, -TITLE_H); rightScroll.Position = UDim2.fromOffset(LEFT_W, TITLE_H)
rightScroll.BackgroundColor3 = PINK_XL; rightScroll.BackgroundTransparency = 0.3; rightScroll.BorderSizePixel = 0
rightScroll.ScrollBarThickness = 3; rightScroll.ScrollBarImageColor3 = PINK
rightScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; rightScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local rightLayout = Instance.new("UIListLayout", rightScroll)
rightLayout.SortOrder = Enum.SortOrder.LayoutOrder; rightLayout.Padding = UDim.new(0, 2)
Instance.new("UIPadding", rightScroll).PaddingTop = UDim.new(0, 6)

local divLine = Instance.new("Frame", main)
divLine.Size = UDim2.new(0, 1, 1, -TITLE_H); divLine.Position = UDim2.fromOffset(LEFT_W, TITLE_H)
divLine.BackgroundColor3 = PINK; divLine.BackgroundTransparency = 0.6; divLine.BorderSizePixel = 0

---------- STATUS BAR ----------
local sB = Instance.new("Frame", leftP)
sB.Size = UDim2.fromOffset(LEFT_W - 16, 24); sB.Position = UDim2.fromOffset(8, 4)
sB.BackgroundColor3 = BG_CARD; sB.BorderSizePixel = 0
Instance.new("UICorner", sB).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", sB).Color = PINK_L

local sDot = Instance.new("Frame", sB)
sDot.Size = UDim2.fromOffset(6, 6); sDot.Position = UDim2.fromOffset(8, 9)
sDot.BackgroundColor3 = TEXT_M; Instance.new("UICorner", sDot).CornerRadius = UDim.new(1, 0)

local sLbl = Instance.new("TextLabel", sB)
sLbl.Size = UDim2.new(1, -22, 1, 0); sLbl.Position = UDim2.fromOffset(20, 0)
sLbl.BackgroundTransparency = 1; sLbl.Text = "Idle"; sLbl.TextColor3 = TEXT_M
sLbl.TextSize = 9; sLbl.Font = Enum.Font.GothamSemibold; sLbl.TextXAlignment = Enum.TextXAlignment.Left

---------- LEFT BUILDERS ----------
local ly = 32

local function hdr(t)
    local h = Instance.new("TextLabel", leftP)
    h.Size = UDim2.fromOffset(LEFT_W - 20, 13); h.Position = UDim2.fromOffset(10, ly)
    h.BackgroundTransparency = 1; h.Text = string.upper(t)
    h.TextColor3 = PINK_D; h.TextSize = 9; h.Font = Enum.Font.GothamBold
    h.TextXAlignment = Enum.TextXAlignment.Left; ly += 15
end

local function tog(label, key)
    local row = Instance.new("Frame", leftP)
    row.Size = UDim2.fromOffset(LEFT_W - 20, 28); row.Position = UDim2.fromOffset(10, ly)
    row.BackgroundColor3 = BG_CARD; row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
    local st = Instance.new("UIStroke", row); st.Color = PINK_L; st.Transparency = 0.5
    local l = Instance.new("TextLabel", row)
    l.Size = UDim2.new(1, -54, 1, 0); l.Position = UDim2.fromOffset(10, 0)
    l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = TEXT_D
    l.TextSize = 10; l.Font = Enum.Font.GothamSemibold; l.TextXAlignment = Enum.TextXAlignment.Left
    local tb = Instance.new("Frame", row)
    tb.Size = UDim2.fromOffset(38, 20); tb.Position = UDim2.new(1, -46, 0.5, -10)
    tb.BorderSizePixel = 0; tb.Active = true
    Instance.new("UICorner", tb).CornerRadius = UDim.new(1, 0)
    local c = Instance.new("Frame", tb)
    c.Size = UDim2.fromOffset(14, 14); c.BorderSizePixel = 0
    Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
    local function r()
        local on = CFG[key]
        tb.BackgroundColor3 = on and PINK or OFF_BG
        c.Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3)
        c.BackgroundColor3 = on and WHITE or Color3.fromRGB(170, 170, 180)
    end
    tb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            CFG[key] = not CFG[key]; r()
        end
    end); r(); ly += 31
end

local function btn(label, cb)
    local b = Instance.new("Frame", leftP)
    b.Size = UDim2.fromOffset(LEFT_W - 20, 26); b.Position = UDim2.fromOffset(10, ly)
    b.BackgroundColor3 = BG_CARD; b.BorderSizePixel = 0; b.Active = true
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    local s2 = Instance.new("UIStroke", b); s2.Color = PINK; s2.Transparency = 0.5
    local lbl = Instance.new("TextLabel", b)
    lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextColor3 = PINK_D; lbl.TextSize = 10; lbl.Font = Enum.Font.GothamSemibold
    b.MouseEnter:Connect(function() b.BackgroundColor3 = PINK_XL; s2.Transparency = 0.2 end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = BG_CARD; s2.Transparency = 0.5 end)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            lbl.TextColor3 = GREEN; lbl.Text = label .. " ..."
            task.spawn(function() pcall(cb); task.wait(1.5); lbl.TextColor3 = PINK_D; lbl.Text = label end)
        end
    end); ly += 30
end

local function sep() local s = Instance.new("Frame", leftP)
    s.Size = UDim2.fromOffset(LEFT_W - 28, 1); s.Position = UDim2.fromOffset(14, ly)
    s.BackgroundColor3 = PINK_L; s.BorderSizePixel = 0; ly += 5
end

---------- LEFT BUILD ----------
hdr("Farming")
tog("Auto-Collect Income", "AutoCollect")
tog("Auto-Sell Brainrots", "AutoSell")
tog("Auto-Rebirth", "AutoRebirth")
sep()
hdr("Heroes")
tog("Auto-Buy Circle Heroes", "AutoBuyHeroes")
tog("Auto-Equip Best", "AutoEquip")
sep()
hdr("Utility")
tog("Auto-Lucky Blocks", "AutoLucky")
tog("Auto-Buy Gear Shop", "AutoBuyGear")
tog("Speed Boost", "SpeedBoost")
tog("Anti-AFK", "AntiAFK")
sep()
hdr("Quick Actions")
btn("\xF0\x9F\x92\xB0  Collect All Income", collectIncome)
btn("\xF0\x9F\x92\xB8  Sell All Now", sellBulk)
btn("\xE2\xAD\x90  Rebirth Now", doRebirth)
btn("\xE2\x9A\xA1  Equip Best All", equipBest)
btn("\xF0\x9F\x91\x8D  Claim Like Reward", function() pcall(function() Remotes.ClaimLikeReward:InvokeServer() end) end)

ly += 2
local cr = Instance.new("TextLabel", leftP)
cr.Size = UDim2.fromOffset(LEFT_W, 10); cr.Position = UDim2.fromOffset(0, ly)
cr.BackgroundTransparency = 1; cr.Text = "\xF0\x9F\x8C\xB8 Aurora v2.0"
cr.TextColor3 = PINK; cr.TextTransparency = 0.4; cr.TextSize = 8; cr.Font = Enum.Font.Gotham
ly += 12

---------- RIGHT PANEL BUILDERS ----------
local function rHdr(text, order)
    local h = Instance.new("TextLabel", rightScroll)
    h.Size = UDim2.new(1, -16, 0, 14); h.BackgroundTransparency = 1
    h.Text = text; h.TextColor3 = PINK_D; h.TextSize = 9; h.Font = Enum.Font.GothamBold
    h.TextXAlignment = Enum.TextXAlignment.Left; h.LayoutOrder = order
    Instance.new("UIPadding", h).PaddingLeft = UDim.new(0, 8)
    return h
end

local function rStat(name, order)
    local f = Instance.new("Frame", rightScroll)
    f.Size = UDim2.new(1, -16, 0, 32); f.BackgroundColor3 = BG_CARD; f.BorderSizePixel = 0; f.LayoutOrder = order
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", f); s.Color = PINK_L; s.Transparency = 0.6
    Instance.new("UIPadding", f).PaddingLeft = UDim.new(0, 8)
    local n2 = Instance.new("TextLabel", f)
    n2.Size = UDim2.new(1, -8, 0, 10); n2.Position = UDim2.fromOffset(0, 2)
    n2.BackgroundTransparency = 1; n2.Text = name; n2.TextColor3 = TEXT_M
    n2.TextSize = 7; n2.Font = Enum.Font.GothamBold; n2.TextXAlignment = Enum.TextXAlignment.Left
    local v = Instance.new("TextLabel", f)
    v.Name = "Value"; v.Size = UDim2.new(1, -8, 0, 14); v.Position = UDim2.fromOffset(0, 14)
    v.BackgroundTransparency = 1; v.Text = "\xE2\x80\x94"; v.TextColor3 = TEXT_D
    v.TextSize = 12; v.Font = Enum.Font.GothamBold; v.TextXAlignment = Enum.TextXAlignment.Left
    return v
end

local function rCheck(label, filterTable, key, order, priceRange)
    local f = Instance.new("Frame", rightScroll)
    f.Size = UDim2.new(1, -16, 0, 20); f.BackgroundTransparency = 1; f.Active = true; f.LayoutOrder = order
    Instance.new("UIPadding", f).PaddingLeft = UDim.new(0, 8)

    local box = Instance.new("Frame", f)
    box.Size = UDim2.fromOffset(14, 14); box.Position = UDim2.fromOffset(0, 3)
    box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)

    local mark = Instance.new("Frame", box)
    mark.Size = UDim2.fromOffset(8, 8); mark.Position = UDim2.fromOffset(3, 3)
    mark.BackgroundColor3 = WHITE; mark.BorderSizePixel = 0
    Instance.new("UICorner", mark).CornerRadius = UDim.new(0, 2)

    local rc = RARITY_COLORS[key] or TEXT_D
    local lbl = Instance.new("TextLabel", f)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = rc
    lbl.TextSize = 9; lbl.Font = Enum.Font.GothamBold; lbl.TextXAlignment = Enum.TextXAlignment.Left

    if priceRange then
        lbl.Size = UDim2.new(0, 70, 1, 0); lbl.Position = UDim2.fromOffset(20, 0); lbl.Text = label
        local pr = Instance.new("TextLabel", f)
        pr.Size = UDim2.new(1, -98, 1, 0); pr.Position = UDim2.fromOffset(90, 0)
        pr.BackgroundTransparency = 1; pr.TextColor3 = TEXT_M
        pr.TextSize = 8; pr.Font = Enum.Font.Gotham; pr.TextXAlignment = Enum.TextXAlignment.Right
        pr.Text = "$" .. fmt(priceRange[1]) .. "-$" .. fmt(priceRange[2])
    else
        lbl.Size = UDim2.new(1, -24, 1, 0); lbl.Position = UDim2.fromOffset(20, 0); lbl.Text = label
    end

    local function refresh()
        local on = filterTable[key]
        box.BackgroundColor3 = on and rc or OFF_BG
        mark.Visible = on
    end

    f.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            filterTable[key] = not filterTable[key]; refresh()
        end
    end); refresh()
end

---------- RIGHT BUILD ----------
local ord = 0
local function nextOrd() ord += 1; return ord end

rHdr("BALANCE", nextOrd())
local cashV = rStat("CASH", nextOrd())
local rebV = rStat("REBIRTHS", nextOrd())

rHdr("SELL FILTER (tap to toggle)", nextOrd())
for _, r in RARITY_ORDER do rCheck(r, SELL_FILTER, r, nextOrd()) end

rHdr("HERO BUY FILTER", nextOrd())
for _, r in RARITY_ORDER do rCheck(r, HERO_BUY, r, nextOrd(), HERO_PRICE_RANGE[r]) end

rHdr("CIRCLE TRACKER", nextOrd())
local circleV = rStat("BEST BUYABLE", nextOrd())
local circleCountV = rStat("IN CIRCLE", nextOrd())

rHdr("SESSION", nextOrd())
local colV = rStat("INCOME COLLECTED", nextOrd())
local soldV = rStat("BRAINROTS SOLD", nextOrd())
local rebSV = rStat("REBIRTHS DONE", nextOrd())
local heroV = rStat("HEROES BOUGHT", nextOrd())
local luckyV = rStat("LUCKY BLOCKS", nextOrd())
local gearV = rStat("GEARS BOUGHT", nextOrd())

rHdr("LATEST DROP", nextOrd())
local dropCard = Instance.new("Frame", rightScroll)
dropCard.Size = UDim2.new(1, -16, 0, 36); dropCard.BackgroundColor3 = BG_CARD; dropCard.BorderSizePixel = 0; dropCard.LayoutOrder = nextOrd()
Instance.new("UICorner", dropCard).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", dropCard).Color = PINK_L
Instance.new("UIPadding", dropCard).PaddingLeft = UDim.new(0, 8)

local dropName = Instance.new("TextLabel", dropCard)
dropName.Size = UDim2.new(1, -8, 0, 14); dropName.Position = UDim2.fromOffset(0, 3)
dropName.BackgroundTransparency = 1; dropName.Text = "Waiting..."
dropName.TextColor3 = TEXT_D; dropName.TextSize = 10; dropName.Font = Enum.Font.GothamBold
dropName.TextXAlignment = Enum.TextXAlignment.Left

local dropInfo = Instance.new("TextLabel", dropCard)
dropInfo.Size = UDim2.new(1, -8, 0, 10); dropInfo.Position = UDim2.fromOffset(0, 19)
dropInfo.BackgroundTransparency = 1; dropInfo.Text = ""
dropInfo.TextColor3 = TEXT_M; dropInfo.TextSize = 8; dropInfo.Font = Enum.Font.GothamSemibold
dropInfo.TextXAlignment = Enum.TextXAlignment.Left

-- Bottom spacer
local spacer = Instance.new("Frame", rightScroll)
spacer.Size = UDim2.new(1, 0, 0, 6); spacer.BackgroundTransparency = 1; spacer.LayoutOrder = nextOrd()

---------- SIZE ----------
local fullH = ly + TITLE_H
main.Size = UDim2.fromOffset(TOTAL_W, fullH)

---------- MINI FLOWER ----------
local miniBtn = Instance.new("Frame", gui)
miniBtn.Size = UDim2.fromOffset(44, 44)
miniBtn.Position = main.Position
miniBtn.BackgroundColor3 = PINK
miniBtn.BorderSizePixel = 0
miniBtn.Visible = false
miniBtn.Active = true
Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(1, 0)
do
    local mf = Instance.new("Frame", miniBtn)
    mf.Size = UDim2.fromOffset(30, 30); mf.Position = UDim2.fromOffset(7, 7); mf.BackgroundTransparency = 1
    for i = 0, 4 do
        local a = math.rad(i * 72 - 90)
        local p = Instance.new("Frame", mf)
        p.Size = UDim2.fromOffset(11, 11)
        p.Position = UDim2.fromOffset(15 + math.cos(a) * 8 - 5, 15 + math.sin(a) * 8 - 5)
        p.BackgroundColor3 = Color3.fromRGB(255, 210, 225); p.BackgroundTransparency = 0.1; p.BorderSizePixel = 0; p.Rotation = i * 72
        Instance.new("UICorner", p).CornerRadius = UDim.new(0, 5)
    end
    local mc = Instance.new("Frame", mf)
    mc.Size = UDim2.fromOffset(6, 6); mc.Position = UDim2.fromOffset(12, 12)
    mc.BackgroundColor3 = WHITE; mc.BackgroundTransparency = 0.1; mc.BorderSizePixel = 0
    Instance.new("UICorner", mc).CornerRadius = UDim.new(1, 0)
end

---------- MINIMIZE ----------
local mb = Instance.new("Frame", tBar)
mb.Size = UDim2.fromOffset(28, 28); mb.Position = UDim2.new(1, -68, 0.5, -14)
mb.BackgroundTransparency = 1; mb.Active = true
local mbLbl = Instance.new("TextLabel", mb)
mbLbl.Size = UDim2.new(1, 0, 1, 0); mbLbl.BackgroundTransparency = 1
mbLbl.Text = "\xE2\x88\x92"; mbLbl.TextColor3 = WHITE; mbLbl.TextSize = 22; mbLbl.Font = Enum.Font.GothamBold
mb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniBtn.Position = main.Position
        main.Visible = false
        miniBtn.Visible = true
    end
end)
miniBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        main.Position = miniBtn.Position
        miniBtn.Visible = false
        main.Visible = true
    end
end)

---------- CLOSE ----------
local xb = Instance.new("Frame", tBar)
xb.Size = UDim2.fromOffset(28, 28); xb.Position = UDim2.new(1, -36, 0.5, -14)
xb.BackgroundTransparency = 1; xb.Active = true
local xLbl = Instance.new("TextLabel", xb)
xLbl.Size = UDim2.new(1, 0, 1, 0); xLbl.BackgroundTransparency = 1
xLbl.Text = "x"; xLbl.TextColor3 = WHITE; xLbl.TextSize = 18; xLbl.Font = Enum.Font.GothamBold
xb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniBtn:Destroy(); gui:Destroy()
    end
end)

---------- STATUS UPDATER ----------
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local active = {}
            if CFG.AutoCollect then table.insert(active, "Collect") end
            if CFG.AutoSell then table.insert(active, "Sell") end
            if CFG.AutoRebirth then table.insert(active, "Rebirth") end
            if CFG.AutoBuyHeroes then table.insert(active, "Heroes") end
            if CFG.AutoEquip then table.insert(active, "Equip") end
            if CFG.AutoLucky then table.insert(active, "Lucky") end
            if CFG.AutoBuyGear then table.insert(active, "Gear") end

            if #active > 0 then
                sLbl.Text = table.concat(active, "+") .. " | $" .. fmt(_cash)
                sLbl.TextColor3 = PINK_D; sDot.BackgroundColor3 = GREEN
            else
                sLbl.Text = "Idle | $" .. fmt(_cash)
                sLbl.TextColor3 = TEXT_M; sDot.BackgroundColor3 = TEXT_M
            end

            cashV.Text = "$" .. fmt(_cash)
            rebV.Text = tostring(_rebirths)
            colV.Text = tostring(S.collects)
            soldV.Text = string.format("%d ($%s)", S.sells, fmt(S.sellCash))
            rebSV.Text = tostring(S.rebirths)
            heroV.Text = tostring(S.heroes)
            luckyV.Text = tostring(S.lucky)
            gearV.Text = tostring(S.gears)

            -- Circle tracker
            local cCount = 0
            for _ in pairs(_circleSpawns) do cCount += 1 end
            circleCountV.Text = tostring(cCount) .. " heroes"
            if _bestCircleHero then
                local rc = RARITY_COLORS[_bestCircleHero.Rarity] or TEXT_D
                circleV.Text = _bestCircleHero.Id .. " ($" .. fmt(_bestCircleHero.Cost) .. ")"
                circleV.TextColor3 = rc
            else
                circleV.Text = "None"; circleV.TextColor3 = TEXT_M
            end

            -- Latest brainrot
            if _lastBrainrot then
                dropName.Text = _lastBrainrot.Name or "Unknown"
                local rc = RARITY_COLORS[_lastBrainrot.Rarity] or TEXT_D
                dropName.TextColor3 = rc
                local parts = {}
                if _lastBrainrot.Rarity then table.insert(parts, _lastBrainrot.Rarity) end
                if _lastBrainrot.Size and _lastBrainrot.Size ~= "Normal" then table.insert(parts, _lastBrainrot.Size) end
                if _lastBrainrot.Mutation and _lastBrainrot.Mutation ~= "Normal" then table.insert(parts, _lastBrainrot.Mutation) end
                if _lastBrainrot.Health then table.insert(parts, fmt(_lastBrainrot.Health) .. " HP") end
                dropInfo.Text = table.concat(parts, " \xC2\xB7 ")
            end
        end)
    end
end)
