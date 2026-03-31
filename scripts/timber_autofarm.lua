--// Aurora v2.0 — Timber! Auto-Farm
--// Made by notCitruss
--// Direct ByteNet buffer bypass — auto-chop, collect, sell
--// All UI uses Frames (anti-cheat proof)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

for _, n in {"Aurora"} do local old = Player.PlayerGui:FindFirstChild(n); if old then old:Destroy() end end

---------- BYTENET DIRECT SEND ----------
local ByteNetEvent = RS:FindFirstChild("ByteNetReliable")
local Packets = require(RS.Lists.Packets)
local packetIDs = require(RS.Lists.Packets.ByteNet.namespaces.packetIDs)
local idMap = packetIDs.ref()

-- Map packet names to IDs
local PID = {}
for id, pkt in pairs(idMap) do
    for name, pkt2 in pairs(Packets) do
        if pkt == pkt2 then PID[name] = tonumber(id); break end
    end
end

-- Direct send functions (bypass broken ByteNet buffer writer)
-- ByteNet struct fields serialize ALPHABETICALLY: prog before seed
-- Prog range: 0-100. Green zone (Perfect) = ~85-100. 15 green hits = 2x LUCK
local function sendAxeHit(seed)
    local buf = buffer.create(6)
    buffer.writeu8(buf, 0, PID.axe_hit)
    buffer.writeu8(buf, 1, math.random(90, 98))  -- Always green zone = Perfect
    buffer.writeu32(buf, 2, seed)
    ByteNetEvent:FireServer(buf)
end

local function sendCollectAll()
    local buf = buffer.create(1)
    buffer.writeu8(buf, 0, PID.collect_all)
    ByteNetEvent:FireServer(buf)
end

local function sendSell()
    local buf = buffer.create(3)
    buffer.writeu8(buf, 0, PID.sell)
    buffer.writeu8(buf, 1, 1)  -- has value
    buffer.writeu8(buf, 2, 0)  -- value = false (matches game)
    ByteNetEvent:FireServer(buf)
end

local function sendCollectTree(seed)
    local buf = buffer.create(5)
    buffer.writeu8(buf, 0, PID.collect_tree)
    buffer.writeu32(buf, 1, seed)
    ByteNetEvent:FireServer(buf)
end

local function sendBoatTravel(destination)
    -- ByteNet string format: [packetID:u8][length:u16 LE][string bytes]
    local len = #destination
    local buf = buffer.create(1 + 2 + len)
    buffer.writeu8(buf, 0, PID.boat_travel)
    buffer.writeu16(buf, 1, len)
    for i = 1, len do
        buffer.writeu8(buf, 2 + i, string.byte(destination, i))
    end
    ByteNetEvent:FireServer(buf)
end

local function sendBoatReturn()
    local buf = buffer.create(1)
    buffer.writeu8(buf, 0, PID.boat_return)
    ByteNetEvent:FireServer(buf)
end

---------- CONFIG ----------
local CFG = {
    AutoChop = false, ChopNoTP = false, AutoCollect = false, AutoSell = false,
    SpeedBoost = false, AntiAFK = false,
}

---------- ZONE DATA ----------
local ZONE_NAMES = {"All Zones", "Timber Town", "Birch Glade", "Scarlet Canopy", "Winterneedle", "Koi Lanterns", "Thornveil", "Palm Cove"}
local _selectedZone = 1

-- TP targets for each zone (to trigger streaming)
local ZONE_TP = {
    ["Timber Town"]    = Vector3.new(-117, 35, -767),
    ["Birch Glade"]    = Vector3.new(440, 60, -732),
    ["Scarlet Canopy"] = Vector3.new(-150, 45, 4),
    ["Winterneedle"]   = Vector3.new(-531, 40, -190),
    ["Koi Lanterns"]   = Vector3.new(443, 135, -141),
    ["Thornveil"]      = Vector3.new(-98, 75, 28),
    ["Palm Cove"]      = Vector3.new(77, 15, -1760),
}

---------- STATE ----------
local _currentTree = nil
local S = {hits = 0, treesDown = 0, collected = 0, sold = 0}

---------- HELPERS ----------
local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local function isTreeInZone(treePos)
    if _selectedZone == 1 then return true end -- All Zones
    local zoneName = ZONE_NAMES[_selectedZone]
    local zone = game.Workspace.Zones:FindFirstChild(zoneName)
    if not zone then return true end
    local bounds = zone:FindFirstChild("TreeBounds")
    if not bounds then return true end
    for _, bound in bounds:GetChildren() do
        if bound:IsA("BasePart") then
            local bP, bS = bound.Position, bound.Size / 2
            if math.abs(treePos.X - bP.X) <= bS.X and math.abs(treePos.Z - bP.Z) <= bS.Z then
                return true
            end
        end
    end
    return false
end

local function getTreeRate(tree)
    for _, c in tree:GetDescendants() do
        if c:IsA("TextLabel") and c.Name == "Rate" then
            local num = tonumber(c.Text:match("(%d+)"))
            return num or 0
        end
    end
    return 0
end

local function isTreeOccupied(tree)
    if not tree.PrimaryPart then return false end
    local tPos = tree.PrimaryPart.Position
    for _, p in Players:GetPlayers() do
        if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if (p.Character.HumanoidRootPart.Position - tPos).Magnitude < 15 then
                return true
            end
        end
    end
    return false
end

local function findBestTree()
    -- Build sorted list by rate, skip occupied trees
    local candidates = {}
    for _, tree in game.Workspace.Trees:GetChildren() do
        if tree:IsA("Model") and tree.PrimaryPart and tree:GetAttribute("Seed") then
            if isTreeInZone(tree.PrimaryPart.Position) then
                local rate = getTreeRate(tree)
                if rate > 0 then
                    table.insert(candidates, {tree = tree, rate = rate})
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.rate > b.rate end)
    -- Return first unoccupied tree
    for _, c in ipairs(candidates) do
        if not isTreeOccupied(c.tree) then
            return c.tree, c.rate
        end
    end
    -- All occupied — return best anyway
    if #candidates > 0 then return candidates[1].tree, candidates[1].rate end
    return nil, 0
end

---------- LISTENERS ----------
Packets.tree_lumberjack_update.listen(function() S.hits += 1 end)
Packets.tree_despawn.listen(function() S.treesDown += 1 end)

---------- CORE LOOPS ----------
task.spawn(function()
    local _target = nil -- {seed, tree, rate}

    while task.wait(0.3) do
        if not CFG.AutoChop then _target = nil; _currentTree = nil; continue end

        -- Check if target tree is still alive or got taken by another player
        if _target then
            if not _target.tree.Parent then
                S.treesDown += 1
                _target = nil
            elseif isTreeOccupied(_target.tree) then
                _target = nil -- Someone else started chopping, find next best
            end
        end

        -- Find new target if needed
        if not _target then
            local tree, rate = findBestTree()
            if tree and tree.PrimaryPart and tree:GetAttribute("Seed") then
                _target = {seed = tree:GetAttribute("Seed"), tree = tree, rate = rate}
                _currentTree = (tree:GetAttribute("TreeName") or tree.Name) .. " (" .. rate .. "\xC2\xA2/s)"
                pcall(function()
                    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = tree.PrimaryPart.CFrame * CFrame.new(0, 0, 4) end
                end)
            else
                -- No trees found — zone might not be loaded
                local zoneName = ZONE_NAMES[_selectedZone]
                if zoneName == "Palm Cove" then
                    -- Palm Cove requires boat travel (direct TP kills you)
                    _currentTree = "Traveling to Palm Cove..."
                    pcall(function()
                        -- TP to dock first
                        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = CFrame.new(-41, 10, -707) end
                    end)
                    task.wait(0.5)
                    pcall(function() sendBoatTravel("PalmCove") end)
                    task.wait(5) -- Wait for boat travel + island loading
                else
                    local zonePos = zoneName and ZONE_TP[zoneName]
                    if zonePos then
                        _currentTree = "Loading " .. zoneName .. "..."
                        pcall(function()
                            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                            if hrp then hrp.CFrame = CFrame.new(zonePos + Vector3.new(0, 5, 0)) end
                        end)
                        task.wait(2)
                    else
                        _currentTree = "No trees found"
                    end
                end
            end
        end

        -- Hit
        if _target then
            pcall(function() sendAxeHit(_target.seed) end)
            S.hits += 1
            -- Re-TP if too far (collect TP recovery)
            pcall(function()
                if _target.tree.Parent and _target.tree.PrimaryPart then
                    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - _target.tree.PrimaryPart.Position).Magnitude > 15 then
                        hrp.CFrame = _target.tree.PrimaryPart.CFrame * CFrame.new(0, 0, 4)
                    end
                end
            end)
        end
    end
end)

-- Auto-Chop Near Tree (no TP) — hits nearest tree without teleporting
task.spawn(function()
    while task.wait(0.3) do
        if not CFG.ChopNoTP then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local nearest, nearDist = nil, 30
            for _, t in game.Workspace.Trees:GetChildren() do
                if t:IsA("Model") and t.PrimaryPart and t:GetAttribute("Seed") then
                    local d = (t.PrimaryPart.Position - hrp.Position).Magnitude
                    if d < nearDist then nearDist = d; nearest = t end
                end
            end
            if nearest then
                sendAxeHit(nearest:GetAttribute("Seed"))
                S.hits += 1
                _currentTree = (nearest:GetAttribute("TreeName") or nearest.Name) .. " (near)"
            end
        end)
    end
end)

task.spawn(function()
    while true do
        if CFG.AutoCollect then
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            local savedPos = hrp and hrp.CFrame or nil
            -- TP to plot
            pcall(function()
                local myPlot = nil
                for _, p in game.Workspace.Plots:GetChildren() do
                    if p:GetAttribute("Owner") == Player.UserId then myPlot = p; break end
                end
                if myPlot then
                    local spawn = myPlot:FindFirstChild("Spawn")
                    if spawn and hrp then hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0) end
                end
            end)
            task.wait(0.3)
            pcall(sendCollectAll)
            pcall(function()
                local hidden = RS:FindFirstChild("HiddenTrees")
                if hidden then
                    for _, t in hidden:GetChildren() do
                        if t:GetAttribute("Owner") == Player.UserId and t:GetAttribute("Seed") then
                            sendCollectTree(t:GetAttribute("Seed"))
                        end
                    end
                end
            end)
            task.wait(0.2)
            -- TP back to original position
            if savedPos and hrp then hrp.CFrame = savedPos end
            S.collected += 1
        end
        task.wait(10)
    end
end)

task.spawn(function()
    while true do
        if CFG.AutoSell then
            pcall(sendSell)
            S.sold += 1
        end
        task.wait(8)
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

Instance.new("TextLabel", tBar).Size = UDim2.new(0, 180, 0, 22); local _t = tBar:GetChildren()[#tBar:GetChildren()]
_t.Position = UDim2.fromOffset(52, 4); _t.BackgroundTransparency = 1; _t.Text = "Aurora"
_t.TextColor3 = WHITE; _t.TextSize = 20; _t.Font = Enum.Font.GothamBold; _t.TextXAlignment = Enum.TextXAlignment.Left

local sLbl2 = Instance.new("TextLabel", tBar)
sLbl2.Size = UDim2.new(0, 250, 0, 12); sLbl2.Position = UDim2.fromOffset(52, 28)
sLbl2.BackgroundTransparency = 1; sLbl2.Text = "by notCitruss  \xE2\x80\x94  Timber! v2"
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
tog("Auto-Chop (TP + Hit)", "AutoChop")
tog("Auto-Chop Near (no TP)", "ChopNoTP")
tog("Auto-Collect Plot", "AutoCollect")
tog("Auto-Sell Logs", "AutoSell")
sep()
hdr("Utility")
tog("Speed Boost", "SpeedBoost")
tog("Anti-AFK", "AntiAFK")
sep()

-- Zone selector as dropdown-style list
hdr("Zone (tap to select)")
for i, zoneName in ipairs(ZONE_NAMES) do
    local zf = Instance.new("Frame", leftP)
    zf.Size = UDim2.fromOffset(LEFT_W - 20, 22); zf.Position = UDim2.fromOffset(10, ly)
    zf.BackgroundColor3 = i == _selectedZone and PINK_XL or BG_CARD; zf.BorderSizePixel = 0; zf.Active = true
    Instance.new("UICorner", zf).CornerRadius = UDim.new(0, 5)

    local dot = Instance.new("Frame", zf)
    dot.Size = UDim2.fromOffset(8, 8); dot.Position = UDim2.fromOffset(8, 7)
    dot.BackgroundColor3 = i == _selectedZone and PINK or OFF_BG; dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local zl = Instance.new("TextLabel", zf)
    zl.Size = UDim2.new(1, -24, 1, 0); zl.Position = UDim2.fromOffset(22, 0)
    zl.BackgroundTransparency = 1; zl.Text = zoneName
    zl.TextColor3 = i == _selectedZone and PINK_D or TEXT_M
    zl.TextSize = 9; zl.Font = Enum.Font.GothamSemibold; zl.TextXAlignment = Enum.TextXAlignment.Left

    -- Store refs for updating
    zf:SetAttribute("ZoneIdx", i)
    zf.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            _selectedZone = i
            -- Update all zone buttons
            for _, child in leftP:GetChildren() do
                if child:GetAttribute("ZoneIdx") then
                    local idx = child:GetAttribute("ZoneIdx")
                    local sel = idx == _selectedZone
                    child.BackgroundColor3 = sel and PINK_XL or BG_CARD
                    for _, d in child:GetChildren() do
                        if d:IsA("Frame") then d.BackgroundColor3 = sel and PINK or OFF_BG end
                        if d:IsA("TextLabel") then d.TextColor3 = sel and PINK_D or TEXT_M end
                    end
                end
            end
        end
    end)
    ly += 24
end

sep()
hdr("Quick Actions")
btn("\xF0\x9F\x92\xB0  Collect All", function()
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    local saved = hrp and hrp.CFrame or nil
    pcall(function()
        local myPlot = nil
        for _, p in game.Workspace.Plots:GetChildren() do
            if p:GetAttribute("Owner") == Player.UserId then myPlot = p; break end
        end
        if myPlot and myPlot:FindFirstChild("Spawn") and hrp then
            hrp.CFrame = myPlot.Spawn.CFrame + Vector3.new(0, 3, 0)
        end
    end)
    task.wait(0.3)
    pcall(sendCollectAll)
    pcall(function()
        local hidden = RS:FindFirstChild("HiddenTrees")
        if hidden then
            for _, t in hidden:GetChildren() do
                if t:GetAttribute("Owner") == Player.UserId and t:GetAttribute("Seed") then
                    sendCollectTree(t:GetAttribute("Seed"))
                end
            end
        end
    end)
    task.wait(0.2)
    if saved and hrp then hrp.CFrame = saved end
end)
btn("\xF0\x9F\x92\xB8  Sell All", function() pcall(sendSell) end)
btn("\xF0\x9F\x8C\xB2  TP to Nearest Tree", function()
    local tree = findBestTree()
    if tree and tree.PrimaryPart then
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = tree.PrimaryPart.CFrame * CFrame.new(0, 0, 4) end
    end
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

rHdr("CURRENT")
local treeV = rStat("CHOPPING")
local zoneV = rStat("ZONE")

rHdr("SESSION")
local hitsV = rStat("AXE HITS")
local downV = rStat("TREES FELLED")
local collectV = rStat("COLLECTIONS")
local sellV = rStat("SELLS")

rHdr("WORLD")
local worldV = rStat("TREES AVAILABLE")

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
            if CFG.AutoChop then table.insert(active, "Chop") end
            if CFG.AutoCollect then table.insert(active, "Collect") end
            if CFG.AutoSell then table.insert(active, "Sell") end

            if #active > 0 then
                sLbl.Text = table.concat(active, "+") .. " | " .. ZONE_NAMES[_selectedZone]
                sLbl.TextColor3 = PINK_D; sDot.BackgroundColor3 = GREEN
            else
                sLbl.Text = "Idle"; sLbl.TextColor3 = TEXT_M; sDot.BackgroundColor3 = TEXT_M
            end

            treeV.Text = _currentTree or "None"
            zoneV.Text = ZONE_NAMES[_selectedZone]
            hitsV.Text = tostring(S.hits)
            downV.Text = tostring(S.treesDown)
            collectV.Text = tostring(S.collected)
            sellV.Text = tostring(S.sold)
            worldV.Text = tostring(#game.Workspace.Trees:GetChildren()) .. " trees"
        end)
    end
end)
