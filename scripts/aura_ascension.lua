--// Aurora v2.0 — Aura Ascension Auto-Farm
--// Made by notCitruss
--// Auto-train, auto-rebirth, auto-chest, anti-AFK, zone selector
--// All UI uses Frames (anti-cheat proof)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer
local Comm = RS:WaitForChild("Communication")

for _, n in {"Aurora", "AuraFarm"} do local old = Player.PlayerGui:FindFirstChild(n); if old then old:Destroy() end end

---------- CONFIG ----------
local CFG = {
    AutoTrain = false, AutoRebirth = false, AutoChest = false,
    AntiAFK = true, SpeedBoost = false,
}

---------- ZONES ----------
local ZONES = {
    {name = "Fire Bath", pos = Vector3.new(83, 14, -119), mult = 1, req = 0},
    {name = "Dark Lava", pos = Vector3.new(12, 22, -75), mult = 10000, req = 10000},
    {name = "Frost Heaven", pos = Vector3.new(-228, 18, -51), mult = 100000, req = 100000},
    {name = "Ancient Ruins", pos = Vector3.new(252, 19, -76), mult = 1000000, req = 1000000},
    {name = "Electra Field", pos = Vector3.new(54, 17, 103), mult = 100000000, req = 100000000},
    {name = "Divine Realm", pos = Vector3.new(65, 45, -301), mult = 10000000000, req = 10000000000},
    {name = "Fallen Star", pos = Vector3.new(294, 21, 132), mult = 1000000000000, req = 1000000000000},
}
local _selectedZone = #ZONES

-- Learn actual zone requirements from Area Status events
local Comm_AreaStatus = Comm:FindFirstChild("Area Status")
if Comm_AreaStatus then
    Comm_AreaStatus.OnClientEvent:Connect(function(zoneName, requirement)
        if zoneName and requirement then
            for _, z in ipairs(ZONES) do
                if z.name == zoneName then z.req = requirement; break end
            end
        end
    end)
end

---------- STATE ----------
local _rebirths = 0
local _auraStart = Player:GetAttribute("Aura") or 0
local S = {rebirths = 0, chests = 0}

---------- HELPERS ----------
local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e27 then return string.format("%.2f Oc", n / 1e27)
    elseif n >= 1e24 then return string.format("%.2f Sp", n / 1e24)
    elseif n >= 1e21 then return string.format("%.2f Sx", n / 1e21)
    elseif n >= 1e18 then return string.format("%.2f Qi", n / 1e18)
    elseif n >= 1e15 then return string.format("%.2f Qa", n / 1e15)
    elseif n >= 1e12 then return string.format("%.2f T", n / 1e12)
    elseif n >= 1e9 then return string.format("%.2f B", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1f M", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1f K", n / 1e3)
    else return tostring(math.floor(n)) end
end

---------- CORE FUNCTIONS ----------
local function claimChest()
    local ready = Player:GetAttribute("Chest_ClaimReadyAt")
    local now = workspace:GetServerTimeNow()
    if ready and now >= ready then
        pcall(function() Comm.ChestCommunication:FireServer("Claim") end)
        S.chests += 1
        return true
    end
    return false
end

local function doRebirth()
    local ok, result = pcall(function()
        return Comm.RequestRebirth:InvokeServer()
    end)
    if ok and result then S.rebirths += 1 end
    return ok and result
end

---------- MAIN LOOP ----------
task.spawn(function()
    local lastChest, lastRebirth, lastTP = 0, 0, 0
    while task.wait(1) do
        -- Auto-Train: keep player in best affordable zone
        if CFG.AutoTrain then
            pcall(function()
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                local isDead = Player:GetAttribute("Dead")
                if not hrp or isDead then return end
                local aura = Player:GetAttribute("Aura") or 0

                -- Find best zone player can handle (selected or lower)
                local targetZone = nil
                for i = _selectedZone, 1, -1 do
                    if aura >= ZONES[i].req then
                        targetZone = ZONES[i]
                        break
                    end
                end
                if not targetZone then targetZone = ZONES[1] end -- fallback to Fire Bath

                local dist = (hrp.Position - targetZone.pos).Magnitude
                if dist > 20 and tick() - lastTP > 5 then
                    hrp.CFrame = CFrame.new(targetZone.pos + Vector3.new(0, 3, 0))
                    lastTP = tick()
                end
            end)
        end

        -- Auto-Chest
        if CFG.AutoChest and tick() - lastChest > 5 then
            claimChest()
            lastChest = tick()
        end

        -- Auto-Rebirth
        if CFG.AutoRebirth and tick() - lastRebirth > 3 then
            local didRebirth = doRebirth()
            lastRebirth = tick()
            if didRebirth and CFG.AutoTrain then
                task.wait(2) -- Wait for aura to reset on server
                pcall(function()
                    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp or Player:GetAttribute("Dead") then return end
                    local aura = Player:GetAttribute("Aura") or 0
                    -- Find best safe zone after rebirth
                    local safeZone = ZONES[1]
                    for i = _selectedZone, 1, -1 do
                        if aura >= ZONES[i].req then safeZone = ZONES[i]; break end
                    end
                    hrp.CFrame = CFrame.new(safeZone.pos + Vector3.new(0, 3, 0))
                end)
            end
        end
    end
end)

-- Anti-AFK
task.spawn(function()
    while true do
        if CFG.AntiAFK then
            pcall(function()
                local vu = game:GetService("VirtualUser"); vu:CaptureController(); vu:ClickButton2(Vector2.new())
            end)
            pcall(function() Comm.ActivePing:FireServer() end)
        end
        task.wait(30)
    end
end)

-- Speed Boost
local _speedOn = false
RunService.Heartbeat:Connect(function()
    pcall(function()
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if CFG.SpeedBoost then hum.WalkSpeed = 80; hum.JumpPower = 80; _speedOn = true
        elseif _speedOn then hum.WalkSpeed = 16; hum.JumpPower = 50; _speedOn = false end
    end)
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

local LEFT_W, RIGHT_W = 300, 220
local TOTAL_W = LEFT_W + RIGHT_W
local TITLE_H = 48

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
tBar.Size = UDim2.new(1, 0, 0, TITLE_H); tBar.BackgroundColor3 = PINK; tBar.BorderSizePixel = 0
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
tLbl.Size = UDim2.fromOffset(180, 22); tLbl.Position = UDim2.fromOffset(52, 4)
tLbl.BackgroundTransparency = 1; tLbl.Text = "Aurora"; tLbl.TextColor3 = WHITE
tLbl.TextSize = 20; tLbl.Font = Enum.Font.GothamBold; tLbl.TextXAlignment = Enum.TextXAlignment.Left

local sLbl2 = Instance.new("TextLabel", tBar)
sLbl2.Size = UDim2.fromOffset(250, 12); sLbl2.Position = UDim2.fromOffset(52, 28)
sLbl2.BackgroundTransparency = 1; sLbl2.Text = "by notCitruss  \xE2\x80\x94  Aura Ascension v2"
sLbl2.TextColor3 = PINK_XL; sLbl2.TextSize = 9; sLbl2.Font = Enum.Font.Gotham; sLbl2.TextXAlignment = Enum.TextXAlignment.Left

---------- PANELS ----------
local leftP = Instance.new("Frame", main)
leftP.Size = UDim2.new(0, LEFT_W, 1, -TITLE_H); leftP.Position = UDim2.fromOffset(0, TITLE_H)
leftP.BackgroundTransparency = 1; leftP.BorderSizePixel = 0

local rightScroll = Instance.new("ScrollingFrame", main)
rightScroll.Size = UDim2.new(0, RIGHT_W, 1, -TITLE_H); rightScroll.Position = UDim2.fromOffset(LEFT_W, TITLE_H)
rightScroll.BackgroundColor3 = PINK_XL; rightScroll.BackgroundTransparency = 0.3; rightScroll.BorderSizePixel = 0
rightScroll.ScrollBarThickness = 3; rightScroll.ScrollBarImageColor3 = PINK
rightScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; rightScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UIListLayout", rightScroll).SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", rightScroll).PaddingTop = UDim.new(0, 6)

local divLine = Instance.new("Frame", main)
divLine.Size = UDim2.new(0, 1, 1, -TITLE_H); divLine.Position = UDim2.fromOffset(LEFT_W, TITLE_H)
divLine.BackgroundColor3 = PINK; divLine.BackgroundTransparency = 0.6; divLine.BorderSizePixel = 0

---------- STATUS BAR ----------
local sB = Instance.new("Frame", leftP)
sB.Size = UDim2.fromOffset(LEFT_W - 16, 24); sB.Position = UDim2.fromOffset(8, 4)
sB.BackgroundColor3 = BG_CARD; sB.BorderSizePixel = 0
Instance.new("UICorner", sB).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", sB).Color = PINK_L

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
    Instance.new("UIStroke", row).Color = PINK_L
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
        tb.BackgroundColor3 = CFG[key] and PINK or OFF_BG
        c.Position = CFG[key] and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3)
        c.BackgroundColor3 = CFG[key] and WHITE or Color3.fromRGB(170, 170, 180)
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

local function sep()
    local s = Instance.new("Frame", leftP)
    s.Size = UDim2.fromOffset(LEFT_W - 28, 1); s.Position = UDim2.fromOffset(14, ly)
    s.BackgroundColor3 = PINK_L; s.BorderSizePixel = 0; ly += 5
end

---------- LEFT BUILD ----------
hdr("Farming")
tog("Auto-Train (TP to Zone)", "AutoTrain")
tog("Auto-Rebirth", "AutoRebirth")
tog("Auto-Chest", "AutoChest")
sep()
hdr("Utility")
tog("Anti-AFK + Ping", "AntiAFK")
tog("Speed Boost", "SpeedBoost")
sep()
hdr("Quick Actions")
btn("\xE2\xAD\x90  Rebirth Now", doRebirth)
btn("\xF0\x9F\x93\xA6  Claim Chest", claimChest)
btn("\xF0\x9F\x93\x8D  TP to Best Zone", function()
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local aura = Player:GetAttribute("Aura") or 0
    local zone = ZONES[1]
    for i = #ZONES, 1, -1 do
        if aura >= ZONES[i].req then zone = ZONES[i]; break end
    end
    hrp.CFrame = CFrame.new(zone.pos + Vector3.new(0, 3, 0))
end)

ly += 2
local cr = Instance.new("TextLabel", leftP)
cr.Size = UDim2.fromOffset(LEFT_W, 10); cr.Position = UDim2.fromOffset(0, ly)
cr.BackgroundTransparency = 1; cr.Text = "\xF0\x9F\x8C\xB8 Aurora v2.0"
cr.TextColor3 = PINK; cr.TextTransparency = 0.4; cr.TextSize = 8; cr.Font = Enum.Font.Gotham
ly += 12

---------- RIGHT PANEL ----------
local ord = 0
local function nextOrd() ord += 1; return ord end

local function rHdr(text)
    local h = Instance.new("TextLabel", rightScroll)
    h.Size = UDim2.new(1, -16, 0, 14); h.BackgroundTransparency = 1
    h.Text = text; h.TextColor3 = PINK_D; h.TextSize = 9; h.Font = Enum.Font.GothamBold
    h.TextXAlignment = Enum.TextXAlignment.Left; h.LayoutOrder = nextOrd()
    Instance.new("UIPadding", h).PaddingLeft = UDim.new(0, 8)
end

local function rStat(name)
    local f = Instance.new("Frame", rightScroll)
    f.Size = UDim2.new(1, -16, 0, 32); f.BackgroundColor3 = BG_CARD; f.BorderSizePixel = 0; f.LayoutOrder = nextOrd()
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", f).Color = PINK_L
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

rHdr("AURA")
local auraV = rStat("CURRENT AURA")
local rankV = rStat("RANK")
local rebirthV = rStat("REBIRTHS")
local peakV = rStat("PEAK AURA")

rHdr("TRAINING")
local zoneV = rStat("CURRENT ZONE")
local multV = rStat("ZONE MULTIPLIER")
local boostV = rStat("AURA BOOST")

rHdr("SESSION")
local rebSV = rStat("REBIRTHS DONE")
local chestV = rStat("CHESTS CLAIMED")
local gainV = rStat("AURA GAINED")

local spacer = Instance.new("Frame", rightScroll)
spacer.Size = UDim2.new(1, 0, 0, 6); spacer.BackgroundTransparency = 1; spacer.LayoutOrder = nextOrd()

---------- SIZE ----------
local fullH = ly + TITLE_H
main.Size = UDim2.fromOffset(TOTAL_W, fullH)

---------- MINIMIZE ----------
local minimized = false
local mb = Instance.new("Frame", tBar)
mb.Size = UDim2.fromOffset(28, 28); mb.Position = UDim2.new(1, -36, 0.5, -14)
mb.BackgroundTransparency = 1; mb.Active = true
local mbLbl = Instance.new("TextLabel", mb)
mbLbl.Size = UDim2.new(1, 0, 1, 0); mbLbl.BackgroundTransparency = 1
mbLbl.Text = "\xE2\x88\x92"; mbLbl.TextColor3 = WHITE; mbLbl.TextSize = 22; mbLbl.Font = Enum.Font.GothamBold
mb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        minimized = not minimized
        TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quart),
            {Size = minimized and UDim2.fromOffset(TOTAL_W, TITLE_H) or UDim2.fromOffset(TOTAL_W, fullH)}):Play()
        mbLbl.Text = minimized and "+" or "\xE2\x88\x92"
        task.delay(minimized and 0 or 0.05, function()
            leftP.Visible = not minimized; rightScroll.Visible = not minimized; divLine.Visible = not minimized
        end)
    end
end)

---------- STATUS UPDATER ----------
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local aura = Player:GetAttribute("Aura") or 0
            local rebirths = Player:GetAttribute("Rebirths") or 0
            local peak = Player:GetAttribute("PeakAura") or 0
            local currentArea = Player:GetAttribute("CurrentArea") or ""
            local areaMult = Player:GetAttribute("AreaMultiplier") or 1
            local auraBoost = Player:GetAttribute("AuraBoost") or 1

            -- Status bar
            local active = {}
            if CFG.AutoTrain then table.insert(active, "Train") end
            if CFG.AutoRebirth then table.insert(active, "Rebirth") end
            if CFG.AutoChest then table.insert(active, "Chest") end

            if #active > 0 then
                sLbl.Text = table.concat(active, "+") .. " | " .. ZONES[_selectedZone].name
                sLbl.TextColor3 = PINK_D; sDot.BackgroundColor3 = GREEN
            else
                sLbl.Text = "Idle | " .. fmt(aura) .. " Aura"
                sLbl.TextColor3 = TEXT_M; sDot.BackgroundColor3 = TEXT_M
            end

            -- Right panel
            auraV.Text = fmt(aura)
            rankV.Text = Player.leaderstats["\xF0\x9F\x9F\xA3 Aura"].Value:match("%d+%.?%d*%s*%a+") or fmt(aura)
            rebirthV.Text = fmt(rebirths)
            peakV.Text = fmt(peak)
            zoneV.Text = currentArea ~= "" and currentArea or "None"
            multV.Text = "x" .. fmt(areaMult)
            boostV.Text = "x" .. tostring(auraBoost)
            rebSV.Text = tostring(S.rebirths)
            chestV.Text = tostring(S.chests)
            gainV.Text = fmt(aura - _auraStart)
        end)
    end
end)
