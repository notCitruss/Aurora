--// Aurora v4.1 — Oil Empire Auto-Farm
--// Made by notCitruss
--// Tank Pink (#FC6E8E) + white theme, dual panel, live gas price
--// Features: auto-sell, auto-buy, auto-place, auto-steal, instant steal,
--//           anti-steal, speed boost, anti-AFK, code redemption, prompt collect
--// FIX v4.1: Speed boost properly resets to default when toggled off

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

for _, n in {"Aurora"} do local old = Player.PlayerGui:FindFirstChild(n); if old then old:Destroy() end end

---------- REMOTES ----------
local Knit = RS.Packages.Knit.Services
local SellGas = Knit.BaseService.RE.SellGas
local Purchase = Knit.StoresService.RE.Purchase
local PlaceBuilding = Knit.BaseService.RE.PlaceBuilding
local CodeRemote = Knit.CodeService.RE.Code
local GasPrice = RS:FindFirstChild("GasPrice")

---------- CONFIG ----------
local CFG = {
    AutoSell = false,
    AutoBuy = false,
    AutoPlace = false,
    AutoSteal = false,
    AntiSteal = false,
    SpeedBoost = false,
    AntiAFK = false,
}

---------- UPGRADE PATH ----------
local UPG = {
    {"DrillShop","Basic Drill",500},{"RefineryShop","Basic Refinery",500},
    {"DrillShop","Strong Drill",1800},{"RefineryShop","Enhanced Refinery",2500},
    {"TotemShop","Stone Cash Totem",2500},{"DrillShop","Enhanced Drill",3600},
    {"RefineryShop","Reinforced Refinery",6250},{"DrillShop","Speed Drill",7200},
    {"DrillShop","Reinforced Drill",12000},{"TotemShop","Copper Cash Totem",15000},
    {"TotemShop","Golden Afk Totem",15000},{"DrillShop","Industrial Drill",20000},
    {"RefineryShop","Advanced Refinery",20000},{"DrillShop","Double Industrial Drill",30000},
    {"RefineryShop","Plasma Refinery",50000},{"DrillShop","Turbo Drill",80000},
    {"TotemShop","Golden Cash Totem",100000},{"TotemShop","Diamond Afk Totem",100000},
    {"DrillShop","Mega Drill",140000},{"RefineryShop","Industrial Refinery",200000},
    {"TotemShop","Ruby Afk Totem",350000},{"TotemShop","Diamond Cash Totem",350000},
    {"RefineryShop","Energy Refinery",700000},{"MerchantShop","Angel Pack",800000},
    {"MerchantShop","Devil Pack",800000},{"DrillShop","Hell Drill",1225000},
    {"TotemShop","Ruby Cash Totem",1500000},{"TotemShop","Plant Afk Totem",1500000},
    {"RefineryShop","Mega Refinery",3000000},{"DrillShop","Plasma Drill",4500000},
    {"RefineryShop","Quantum Refinery",5000000},{"RefineryShop","Ice Refinery",8000000},
    {"RefineryShop","Hell Refinery",16000000},{"DrillShop","Huge Long Drill",40000000},
    {"DrillShop","Mega Plasma Drill",95000000},{"RefineryShop","Mega Energy Refinery",150000000},
    {"DrillShop","Multi Drill",280000000},{"RefineryShop","Lava Refinery",360000000},
    {"DrillShop","Lava Drill",900000000},{"RefineryShop","Crystal Refinery",600000000},
    {"DrillShop","Crystal Drill",9000000000},{"DrillShop","Diamond Drill",27500000000},
    {"RefineryShop","Diamond Refinery",5000000000},
}

---------- STATE ----------
local S = {sells = 0, purchases = 0, steals = 0, startCash = Player.leaderstats.Cash.Value}
local uIdx = 1
local lastSell, lastBuy = 0, 0

---------- THEME: TANK PINK + WHITE ----------
local PINK = Color3.fromRGB(252, 110, 142)     -- #FC6E8E
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
local GOLD = Color3.fromRGB(240, 180, 30)
local RED = Color3.fromRGB(220, 60, 60)

local function getPriceTier(price: number): (string, Color3)
    if price >= 16 then return "INSANE", Color3.fromRGB(255, 60, 255) end
    if price >= 10 then return "GOOD", GREEN end
    if price >= 5 then return "AVERAGE", GOLD end
    return "LOW", RED
end

local LEFT_W, RIGHT_W = 340, 220
local TOTAL_W = LEFT_W + RIGHT_W

---------- GUI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "Aurora"; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Player.PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(TOTAL_W, 0); main.Position = UDim2.fromOffset(16, 80)
main.BackgroundColor3 = BG; main.BackgroundTransparency = 0.04; main.BorderSizePixel = 0
main.Parent = gui; main.Active = true; main.Draggable = true; main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

local sh = Instance.new("ImageLabel", main)
sh.Size = UDim2.new(1,44,1,44); sh.Position = UDim2.fromOffset(-22,-22)
sh.BackgroundTransparency = 1; sh.Image = "rbxassetid://6014261993"
sh.ImageColor3 = Color3.fromRGB(180,120,140); sh.ImageTransparency = 0.5
sh.ScaleType = Enum.ScaleType.Slice; sh.SliceCenter = Rect.new(49,49,450,450); sh.ZIndex = 0

---------- TITLE BAR ----------
local tBar = Instance.new("Frame", main)
tBar.Size = UDim2.new(1,0,0,56); tBar.BackgroundColor3 = PINK; tBar.BorderSizePixel = 0
Instance.new("UICorner", tBar).CornerRadius = UDim.new(0, 14)
local tFix = Instance.new("Frame", tBar)
tFix.Size = UDim2.new(1,0,0,16); tFix.Position = UDim2.new(0,0,1,-16)
tFix.BackgroundColor3 = PINK; tFix.BorderSizePixel = 0

-- Blossom petals logo
local lf = Instance.new("Frame", tBar)
lf.Size = UDim2.fromOffset(40,40); lf.Position = UDim2.fromOffset(14,8); lf.BackgroundTransparency = 1
for i = 0, 4 do
    local a = math.rad(i * 72 - 90)
    local p = Instance.new("Frame", lf)
    p.Size = UDim2.fromOffset(16,16)
    p.Position = UDim2.fromOffset(20+math.cos(a)*11-8, 20+math.sin(a)*11-8)
    p.BackgroundColor3 = Color3.fromRGB(255, 210, 225); p.BackgroundTransparency = 0.1
    p.BorderSizePixel = 0; p.Rotation = i * 72
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, 7)
end
local ct = Instance.new("Frame", lf)
ct.Size = UDim2.fromOffset(10,10); ct.Position = UDim2.fromOffset(15,15)
ct.BackgroundColor3 = WHITE; ct.BackgroundTransparency = 0.1; ct.BorderSizePixel = 0
Instance.new("UICorner", ct).CornerRadius = UDim.new(1, 0)

local tLbl = Instance.new("TextLabel", tBar)
tLbl.Size = UDim2.new(0,200,0,28); tLbl.Position = UDim2.fromOffset(60,6)
tLbl.BackgroundTransparency = 1; tLbl.Text = "Aurora"; tLbl.TextColor3 = WHITE
tLbl.TextSize = 24; tLbl.Font = Enum.Font.GothamBold; tLbl.TextXAlignment = Enum.TextXAlignment.Left

local sLbl2 = Instance.new("TextLabel", tBar)
sLbl2.Size = UDim2.new(0,280,0,14); sLbl2.Position = UDim2.fromOffset(60,34)
sLbl2.BackgroundTransparency = 1; sLbl2.Text = "by notCitruss  \xE2\x80\x94  Oil Empire"
sLbl2.TextColor3 = Color3.fromRGB(255, 230, 238); sLbl2.TextSize = 11
sLbl2.Font = Enum.Font.Gotham; sLbl2.TextXAlignment = Enum.TextXAlignment.Left

---------- PANELS ----------
local leftP = Instance.new("Frame", main)
leftP.Size = UDim2.new(0,LEFT_W,1,-56); leftP.Position = UDim2.fromOffset(0,56)
leftP.BackgroundTransparency = 1; leftP.BorderSizePixel = 0

local rightP = Instance.new("Frame", main)
rightP.Size = UDim2.new(0,RIGHT_W,1,-56); rightP.Position = UDim2.fromOffset(LEFT_W,56)
rightP.BackgroundColor3 = PINK_XL; rightP.BackgroundTransparency = 0.3; rightP.BorderSizePixel = 0

local div = Instance.new("Frame", main)
div.Size = UDim2.new(0,1,1,-56); div.Position = UDim2.fromOffset(LEFT_W,56)
div.BackgroundColor3 = PINK; div.BackgroundTransparency = 0.6; div.BorderSizePixel = 0

---------- STATUS BAR ----------
local sB = Instance.new("Frame", leftP)
sB.Size = UDim2.new(1,-16,0,26); sB.Position = UDim2.fromOffset(8,6)
sB.BackgroundColor3 = BG_CARD; sB.BorderSizePixel = 0
Instance.new("UICorner", sB).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", sB).Color = PINK_L

local sDot = Instance.new("Frame", sB)
sDot.Size = UDim2.fromOffset(7,7); sDot.Position = UDim2.fromOffset(10,9.5)
sDot.BackgroundColor3 = TEXT_M; Instance.new("UICorner", sDot).CornerRadius = UDim.new(1,0)

local sLbl = Instance.new("TextLabel", sB)
sLbl.Size = UDim2.new(1,-26,1,0); sLbl.Position = UDim2.fromOffset(24,0)
sLbl.BackgroundTransparency = 1; sLbl.Text = "Idle"; sLbl.TextColor3 = TEXT_M
sLbl.TextSize = 10; sLbl.Font = Enum.Font.GothamSemibold; sLbl.TextXAlignment = Enum.TextXAlignment.Left

---------- LEFT LAYOUT ----------
local ly = 38
local items = {}
local function tr(o) table.insert(items, o) return o end

local function hdr(t)
    local h = tr(Instance.new("TextLabel", leftP))
    h.Size = UDim2.new(1,-20,0,14); h.Position = UDim2.new(0,10,0,ly)
    h.BackgroundTransparency = 1; h.Text = string.upper(t)
    h.TextColor3 = PINK_D; h.TextSize = 9; h.Font = Enum.Font.GothamBold
    h.TextXAlignment = Enum.TextXAlignment.Left; ly += 16
end

local function tog(label, key)
    local row = tr(Instance.new("Frame", leftP))
    row.Size = UDim2.new(1,-20,0,32); row.Position = UDim2.new(0,10,0,ly)
    row.BackgroundColor3 = BG_CARD; row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", row).Color = PINK_L; row:FindFirstChildOfClass("UIStroke").Transparency = 0.5
    local l = Instance.new("TextLabel", row)
    l.Size = UDim2.new(1,-58,1,0); l.Position = UDim2.fromOffset(12,0)
    l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = TEXT_D
    l.TextSize = 11; l.Font = Enum.Font.GothamSemibold; l.TextXAlignment = Enum.TextXAlignment.Left
    local tb = Instance.new("Frame", row)
    tb.Size = UDim2.fromOffset(42,22); tb.Position = UDim2.new(1,-50,0.5,-11)
    tb.BorderSizePixel = 0; tb.Active = true
    Instance.new("UICorner", tb).CornerRadius = UDim.new(1, 0)
    local c = Instance.new("Frame", tb)
    c.Size = UDim2.fromOffset(16,16); c.BorderSizePixel = 0
    Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
    local function r()
        local on = CFG[key]
        tb.BackgroundColor3 = on and PINK or OFF_BG
        c.Position = on and UDim2.new(1,-19,0.5,-8) or UDim2.fromOffset(3,3)
        c.BackgroundColor3 = on and WHITE or Color3.fromRGB(170,170,180)
    end
    tb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            CFG[key] = not CFG[key]; r()
        end
    end); r()
    ly += 36
end

local function btn(label, cb)
    local b = tr(Instance.new("Frame", leftP))
    b.Size = UDim2.new(1,-20,0,30); b.Position = UDim2.new(0,10,0,ly)
    b.BackgroundColor3 = BG_CARD; b.BorderSizePixel = 0; b.Active = true
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local s2 = Instance.new("UIStroke", b); s2.Color = PINK; s2.Transparency = 0.5
    local lbl = Instance.new("TextLabel", b)
    lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextColor3 = PINK_D; lbl.TextSize = 11; lbl.Font = Enum.Font.GothamSemibold
    b.MouseEnter:Connect(function() b.BackgroundColor3 = PINK_XL; s2.Transparency = 0.2 end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = BG_CARD; s2.Transparency = 0.5 end)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            lbl.TextColor3 = GREEN; lbl.Text = label .. " ..."
            task.spawn(function() pcall(cb); task.wait(1.5); lbl.TextColor3 = PINK_D; lbl.Text = label end)
        end
    end); ly += 34
end

local function sep()
    local s2 = tr(Instance.new("Frame", leftP))
    s2.Size = UDim2.new(1,-28,0,1); s2.Position = UDim2.new(0,14,0,ly)
    s2.BackgroundColor3 = PINK_L; s2.BorderSizePixel = 0; ly += 7
end

---------- LEFT BUILD ----------
hdr("Production")
tog("Auto-Sell Gasoline", "AutoSell")
tog("Auto-Buy Upgrades", "AutoBuy")
tog("Auto-Place Buildings", "AutoPlace")
sep()
hdr("Movement")
tog("Speed Boost", "SpeedBoost")
sep()
hdr("Combat")
tog("Auto-Steal (safe)", "AutoSteal")
tog("Anti-Steal Defense", "AntiSteal")
btn("\xF0\x9F\x92\x80  Instant Steal (nearest)", function()
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local pos = hrp.Position; local bp, bd = nil, 999
    for _, plot in game.Workspace.Plots:GetChildren() do
        for _, v in plot:GetDescendants() do
            if v:IsA("ProximityPrompt") and v.Name == "Steal" then
                local amt = tonumber(string.match(v.ActionText, "(%d+)")) or 0
                if amt <= 0 then continue end
                local pp = v.Parent; if pp:IsA("Attachment") then pp = pp.Parent end
                if not pp:IsA("BasePart") then continue end
                local d = (pp.Position - pos).Magnitude
                if d < bd then bd = d; bp = v end
            end
        end
    end
    if bp and bd < 80 then
        task.wait(0.5)
        pcall(function()
            if fireproximityprompt then fireproximityprompt(bp)
            else local h = bp.HoldDuration; bp.HoldDuration = 0; bp.MaxActivationDistance = 9999
                bp:InputHoldBegin(); task.wait(0.2); bp:InputHoldEnd(); bp.HoldDuration = h end
        end); S.steals += 1
    end
end)
sep()
hdr("Actions")
tog("Anti-AFK", "AntiAFK")
btn("\xF0\x9F\x92\xB0  Sell All Now", function() SellGas:FireServer(); S.sells += 1 end)
btn("\xF0\x9F\x8E\x81  Redeem All Codes", function()
    for _, c in {"RELEASE","UPDATE","1KLIKES","5KLIKES","10KLIKES","25KLIKES","50KLIKES","100KLIKES","OILEMPIRE","FREECASH","OIL","GASOLINE","CASH","MONEY","FREE","LAUNCH","NEWUPDATE","SORRY","THANKYOU","1MVISITS","5MVISITS","10MVISITS","EASTER","SPRING","100KFAV","OILKING","TYCOON","BOOST","2XBOOST","MEGA","LEGENDARY"} do
        pcall(function() CodeRemote:FireServer(c) end); task.wait(0.5) end
end)
btn("\xE2\x9A\xA1  Collect All Prompts", function()
    local mp = game.Workspace.Plots:FindFirstChild(Player:GetAttribute("Plot")); if not mp then return end
    for _, v in mp:GetDescendants() do
        if v:IsA("ProximityPrompt") and v.Name ~= "Steal" then
            pcall(function()
                if fireproximityprompt then fireproximityprompt(v)
                else local h = v.HoldDuration; v.HoldDuration = 0; v.MaxActivationDistance = 9999
                    v:InputHoldBegin(); task.wait(0.1); v:InputHoldEnd(); v.HoldDuration = h end
            end); task.wait(0.3) end
    end
end)
ly += 6
local cr = tr(Instance.new("TextLabel", leftP))
cr.Size = UDim2.new(1,0,0,12); cr.Position = UDim2.new(0,0,0,ly)
cr.BackgroundTransparency = 1; cr.Text = "\xF0\x9F\x8C\xB8 Aurora v4.1"
cr.TextColor3 = PINK; cr.TextTransparency = 0.4; cr.TextSize = 9; cr.Font = Enum.Font.Gotham
ly += 14

---------- RIGHT BUILD ----------
local ry = 8

local function dHdr(t)
    local h = Instance.new("TextLabel", rightP)
    h.Size = UDim2.new(1,-16,0,14); h.Position = UDim2.new(0,8,0,ry)
    h.BackgroundTransparency = 1; h.Text = t; h.TextColor3 = PINK_D
    h.TextSize = 9; h.Font = Enum.Font.GothamBold; h.TextXAlignment = Enum.TextXAlignment.Left
    table.insert(items, h); ry += 15
end

local function dStat(name)
    local f = Instance.new("Frame", rightP)
    f.Size = UDim2.new(1,-16,0,34); f.Position = UDim2.fromOffset(8,ry)
    f.BackgroundColor3 = BG_CARD; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", f).Color = PINK_L; f:FindFirstChildOfClass("UIStroke").Transparency = 0.6
    table.insert(items, f)
    local n = Instance.new("TextLabel", f)
    n.Size = UDim2.new(1,-10,0,11); n.Position = UDim2.fromOffset(8,2)
    n.BackgroundTransparency = 1; n.Text = name; n.TextColor3 = TEXT_M
    n.TextSize = 8; n.Font = Enum.Font.GothamBold; n.TextXAlignment = Enum.TextXAlignment.Left
    local v = Instance.new("TextLabel", f)
    v.Name = "Value"; v.Size = UDim2.new(1,-10,0,15); v.Position = UDim2.fromOffset(8,15)
    v.BackgroundTransparency = 1; v.Text = "\xE2\x80\x94"; v.TextColor3 = TEXT_D
    v.TextSize = 13; v.Font = Enum.Font.GothamBold; v.TextXAlignment = Enum.TextXAlignment.Left
    ry += 38; return v
end

-- Gas price widget
dHdr("GAS PRICE")
local priceFrame = Instance.new("Frame", rightP)
priceFrame.Size = UDim2.new(1,-16,0,52); priceFrame.Position = UDim2.fromOffset(8,ry)
priceFrame.BackgroundColor3 = BG_CARD; priceFrame.BorderSizePixel = 0
Instance.new("UICorner", priceFrame).CornerRadius = UDim.new(0, 8)
local priceStroke = Instance.new("UIStroke", priceFrame); priceStroke.Thickness = 2
table.insert(items, priceFrame)

local priceLbl = Instance.new("TextLabel", priceFrame)
priceLbl.Name = "PriceValue"; priceLbl.Size = UDim2.new(0,80,1,0)
priceLbl.Position = UDim2.fromOffset(10,0); priceLbl.BackgroundTransparency = 1
priceLbl.Text = "$0"; priceLbl.TextColor3 = TEXT_D; priceLbl.TextSize = 26
priceLbl.Font = Enum.Font.GothamBold; priceLbl.TextXAlignment = Enum.TextXAlignment.Left

local tierLbl = Instance.new("TextLabel", priceFrame)
tierLbl.Name = "TierValue"; tierLbl.Size = UDim2.new(0,90,0,22)
tierLbl.Position = UDim2.new(1,-98,0.5,-11); tierLbl.BackgroundTransparency = 0
tierLbl.Text = "LOW"; tierLbl.TextColor3 = WHITE; tierLbl.TextSize = 11
tierLbl.Font = Enum.Font.GothamBold
Instance.new("UICorner", tierLbl).CornerRadius = UDim.new(0, 6)

local barBg = Instance.new("Frame", priceFrame)
barBg.Size = UDim2.new(1,-20,0,4); barBg.Position = UDim2.new(0,10,1,-8)
barBg.BackgroundColor3 = PINK_L; barBg.BorderSizePixel = 0
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1,0)
local barFill = Instance.new("Frame", barBg)
barFill.Name = "Fill"; barFill.Size = UDim2.new(0.1,0,1,0)
barFill.BackgroundColor3 = RED; barFill.BorderSizePixel = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1,0)
ry += 58

dHdr("BALANCE")
local cashV = dStat("CASH")
local gasV = dStat("GASOLINE")
local gpsV = dStat("PRODUCTION")
dHdr("STATS")
local bldgV = dStat("BUILDINGS")
local earnV = dStat("EARNED")
local actV = dStat("ACTIONS")
dHdr("NEXT UPGRADE")
local nextV = dStat("TARGET")
dHdr("STEAL TARGET")
local tgtV = dStat("RICHEST")
ry += 6

---------- SIZE ----------
local fullH = math.max(ly, ry) + 56
main.Size = UDim2.fromOffset(TOTAL_W, fullH)
rightP.Size = UDim2.new(0, RIGHT_W, 0, fullH - 56)

---------- MINIMIZE ----------
local minimized = false
local mb = Instance.new("Frame", tBar)
mb.Size = UDim2.fromOffset(32,32); mb.Position = UDim2.new(1,-40,0.5,-16)
mb.BackgroundTransparency = 1; mb.Active = true
local mbLbl = Instance.new("TextLabel", mb)
mbLbl.Size = UDim2.new(1, 0, 1, 0); mbLbl.BackgroundTransparency = 1
mbLbl.Text = "\xE2\x88\x92"; mbLbl.TextColor3 = WHITE; mbLbl.TextSize = 26; mbLbl.Font = Enum.Font.GothamBold
mb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        minimized = not minimized
        TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quart),
            {Size = minimized and UDim2.fromOffset(TOTAL_W, 56) or UDim2.fromOffset(TOTAL_W, fullH)}):Play()
        mbLbl.Text = minimized and "+" or "\xE2\x88\x92"
        task.delay(minimized and 0 or 0.05, function()
            leftP.Visible = not minimized; rightP.Visible = not minimized; div.Visible = not minimized
        end)
    end
end)

---------- CORE LOOPS ----------

-- Auto-Sell + Auto-Buy
RunService.Heartbeat:Connect(function()
    local now = tick()
    local cash = Player.leaderstats.Cash.Value
    local gas = Player.leaderstats.Gasoline.Value
    if CFG.AutoSell and gas > 0 and (now - lastSell) > 8 then
        pcall(function() SellGas:FireServer() end); S.sells += 1; lastSell = now
    end
    if CFG.AutoBuy and (now - lastBuy) > 5 and uIdx <= #UPG then
        local u = UPG[uIdx]
        if cash >= u[3] then
            pcall(function() Purchase:FireServer(u[1], u[2]) end)
            S.purchases += 1; uIdx += 1; lastBuy = now
        end
    end
end)

-- Speed Boost (FIX v4.1: properly resets when toggled off)
local _speedWasOn = false
RunService.Heartbeat:Connect(function()
    pcall(function()
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if CFG.SpeedBoost then
            hum.WalkSpeed = 80
            hum.JumpPower = 80
            _speedWasOn = true
        elseif _speedWasOn then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            _speedWasOn = false
        end
    end)
end)

-- Anti-AFK
task.spawn(function()
    while true do
        task.wait(240)
        if CFG.AntiAFK then
            pcall(function()
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame *= CFrame.new(0, 0.1, 0) end
            end)
        end
    end
end)

-- Auto-Place
Player.Backpack.ChildAdded:Connect(function(tool)
    if not CFG.AutoPlace then return end; task.wait(1)
    pcall(function()
        local mp = game.Workspace.Plots:FindFirstChild(Player:GetAttribute("Plot"))
        local a = mp and mp:FindFirstChild("PlaceArea"); if not a then return end
        local bp = a.Position
        local id = tool:GetAttribute("Id") or tool:GetAttribute("BuildingId") or tool.Name
        PlaceBuilding:FireServer(id, CFrame.new(bp.X + math.random(-3,3)*8, bp.Y + 3, bp.Z + math.random(-3,3)*8))
    end)
end)

-- Anti-Steal Defense
task.spawn(function()
    while true do
        task.wait(10)
        if CFG.AntiSteal then
            pcall(function()
                local mp = game.Workspace.Plots:FindFirstChild(Player:GetAttribute("Plot"))
                if mp then
                    for _, v in mp:GetDescendants() do
                        if v:IsA("ProximityPrompt") and v.Name == "Steal" then
                            v.HoldDuration = 999; v.MaxActivationDistance = 0.1
                        end
                    end
                end
            end)
        end
    end
end)

-- Auto-Steal (safe: 1 per 45-60s)
task.spawn(function()
    while true do
        task.wait(45 + math.random(0, 15))
        if not CFG.AutoSteal then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local plots = game.Workspace.Plots
            local bp, ba = nil, 0
            for _, p in Players:GetPlayers() do
                if p == Player then continue end
                local plot = plots:FindFirstChild(p:GetAttribute("Plot") or "")
                if not plot then continue end
                for _, v in plot:GetDescendants() do
                    if v:IsA("ProximityPrompt") and v.Name == "Steal" then
                        local a = tonumber(string.match(v.ActionText, "(%d+)")) or 0
                        if a > ba then ba = a; bp = v end
                    end
                end
            end
            if bp and ba > 1000 then
                local home = plots:FindFirstChild(Player:GetAttribute("Plot"))
                local ht = home and home:FindFirstChild("TpHere")
                local pp = bp.Parent; if pp:IsA("Attachment") then pp = pp.Parent end
                if pp:IsA("BasePart") then hrp.CFrame = pp.CFrame + Vector3.new(0, 3, 0) end
                task.wait(1.5 + math.random() * 1.5)
                if fireproximityprompt then fireproximityprompt(bp)
                else bp.HoldDuration = 0; bp.MaxActivationDistance = 9999
                    bp:InputHoldBegin(); task.wait(0.2); bp:InputHoldEnd()
                end
                S.steals += 1
                task.wait(2 + math.random() * 2)
                if ht then hrp.CFrame = ht.CFrame + Vector3.new(0, 5, 0) end
            end
        end)
    end
end)

-- Respawn handler
Player.CharacterAdded:Connect(function(c)
    task.wait(1)
    if CFG.SpeedBoost then
        pcall(function()
            c:FindFirstChildOfClass("Humanoid").WalkSpeed = 80
            c:FindFirstChildOfClass("Humanoid").JumpPower = 80
        end)
    end
end)

---------- DASHBOARD UPDATER ----------
local function fmt(n)
    if n >= 1e9 then return string.format("$%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("$%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("$%.1fK", n / 1e3) end
    return "$" .. tostring(n)
end

local function fG(n)
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(n)
end

task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local cash = Player.leaderstats.Cash.Value
            local gas = Player.leaderstats.Gasoline.Value
            local gps = Player.Values.GasolinePerSecond.Value
            local mp = game.Workspace.Plots:FindFirstChild(Player:GetAttribute("Plot"))
            local bl = mp and mp:FindFirstChild("Buildings") and #mp.Buildings:GetChildren() or 0

            -- Status bar
            local act = {}
            if CFG.AutoSell then table.insert(act, "Sell") end
            if CFG.AutoBuy then table.insert(act, "Buy") end
            if CFG.AutoSteal then table.insert(act, "Steal") end
            if CFG.SpeedBoost then table.insert(act, "Spd") end
            if CFG.AntiAFK then table.insert(act, "AFK") end
            if CFG.AntiSteal then table.insert(act, "Def") end
            if #act > 0 then
                sLbl.Text = table.concat(act, " \xC2\xB7 ")
                sLbl.TextColor3 = PINK_D; sDot.BackgroundColor3 = GREEN
            else
                sLbl.Text = "All modules idle"
                sLbl.TextColor3 = TEXT_M; sDot.BackgroundColor3 = TEXT_M
            end

            -- Gas price widget
            local price = GasPrice and GasPrice.Value or 0
            local tier, tierColor = getPriceTier(price)
            priceLbl.Text = "$" .. price
            priceLbl.TextColor3 = tierColor
            tierLbl.Text = tier
            tierLbl.BackgroundColor3 = tierColor
            priceStroke.Color = tierColor
            local fill = math.clamp(price / 25, 0.05, 1)
            TweenService:Create(barFill, TweenInfo.new(0.3), {
                Size = UDim2.new(fill, 0, 1, 0),
                BackgroundColor3 = tierColor
            }):Play()

            -- Dashboard
            cashV.Text = fmt(cash); cashV.TextColor3 = PINK_D
            gasV.Text = fG(gas) .. " gal"
            gpsV.Text = gps .. "/s"; gpsV.TextColor3 = GREEN
            bldgV.Text = bl .. " placed"
            local e = cash - S.startCash
            earnV.Text = fmt(e); earnV.TextColor3 = e >= 0 and GREEN or RED
            actV.Text = S.sells .. "s \xC2\xB7 " .. S.purchases .. "b \xC2\xB7 " .. S.steals .. "st"

            if uIdx <= #UPG then
                local u = UPG[uIdx]; nextV.Text = u[2]; nextV.TextSize = 10
            else
                nextV.Text = "ALL DONE"; nextV.TextColor3 = GOLD
            end

            local best, bestA = "None", 0
            for _, p in Players:GetPlayers() do
                if p == Player then continue end
                local plot = game.Workspace.Plots:FindFirstChild(p:GetAttribute("Plot") or "")
                if not plot then continue end
                for _, v in plot:GetDescendants() do
                    if v:IsA("ProximityPrompt") and v.Name == "Steal" then
                        local a = tonumber(string.match(v.ActionText, "(%d+)")) or 0
                        if a > bestA then bestA = a; best = p.Name .. "\n" .. fG(a) .. " gas" end
                    end
                end
            end
            tgtV.Text = best; tgtV.TextSize = 10
        end)
    end
end)

print("[Aurora v4.1] Oil Empire loaded \xF0\x9F\x8C\xB8")
