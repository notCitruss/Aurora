--// Aurora v3 — Timber! Auto-Farm
--// Made by notCitruss | Dark Glass Theme
--// Direct ByteNet buffer bypass — auto-chop, collect, sell
--// All interactive elements use Frames (game anti-cheat kills TextButtons)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Player = Players.LocalPlayer

-- Cleanup old UI
for _, n in {"Aurora"} do
    pcall(function() if gethui then local old = gethui():FindFirstChild(n); if old then old:Destroy() end end end)
    pcall(function() local old = game:GetService("CoreGui"):FindFirstChild(n); if old then old:Destroy() end end)
    pcall(function() local old = Player.PlayerGui:FindFirstChild(n); if old then old:Destroy() end end)
end
task.wait(0.1)

---------- BYTENET DIRECT SEND ----------
local ByteNetEvent = RS:FindFirstChild("ByteNetReliable")
local ok1, Packets = pcall(require, RS:FindFirstChild("Lists") and RS.Lists:FindFirstChild("Packets") and RS.Lists.Packets)
if not ok1 or not Packets then warn("[Aurora] Packets module not found"); return end
local ok2, packetIDs = pcall(require, RS.Lists.Packets:FindFirstChild("ByteNet") and RS.Lists.Packets.ByteNet:FindFirstChild("namespaces") and RS.Lists.Packets.ByteNet.namespaces:FindFirstChild("packetIDs") and RS.Lists.Packets.ByteNet.namespaces.packetIDs)
if not ok2 or not packetIDs then warn("[Aurora] packetIDs module not found"); return end
local idMap = packetIDs.ref()

-- Map packet names to IDs
local PID = {}
for id, pkt in idMap do
    for name, pkt2 in Packets do
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

local function sendQuestClaim()
    local buf = buffer.create(1)
    buffer.writeu8(buf, 0, PID.quest_claim_reward)
    ByteNetEvent:FireServer(buf)
end

local function sendJoinedGroup()
    local buf = buffer.create(1)
    buffer.writeu8(buf, 0, PID.joined_group)
    ByteNetEvent:FireServer(buf)
end

local function sendFreeSapling()
    local buf = buffer.create(1)
    buffer.writeu8(buf, 0, PID.claim_free_sapling)
    ByteNetEvent:FireServer(buf)
end

local function sendAfkRejoin()
    local buf = buffer.create(1)
    buffer.writeu8(buf, 0, PID.afk_rejoin)
    ByteNetEvent:FireServer(buf)
end


---------- COMPAT (cross-executor support) ----------
local _HAS = {
    gethui    = typeof(gethui) == "function",
    writefile = writefile ~= nil,
    firepp    = fireproximityprompt ~= nil,
    hookfn    = hookfunction ~= nil,
    getgc     = getgc ~= nil,
    vim       = pcall(function() return game:GetService("VirtualInputManager") end),
}
local function safeFirePrompt(prompt)
    if _HAS.firepp then
        fireproximityprompt(prompt)
    else
        local od, oh = prompt.MaxActivationDistance, prompt.HoldDuration
        prompt.MaxActivationDistance = 9999; prompt.HoldDuration = 0
        prompt:InputHoldBegin(); task.wait(0.05); prompt:InputHoldEnd()
        prompt.MaxActivationDistance = od; prompt.HoldDuration = oh
    end
end
local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- CONFIG ----------
local CFG = {
    AutoChop = false, ChopNoTP = false, AutoCollect = false, AutoSell = false,
    AutoQuest = false, SpeedBoost = false, AntiAFK = false,
    SelectedZone = 1, AutoSave = true,
}

---------- TOGGLE SAVE/LOAD ----------
local _cfgFileName = "aurora_cfg_timber_autofarm.json"
local HttpService = game:GetService("HttpService")

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_timber_autofarm"] end
    if saved and type(saved) == "table" then
        for k, v in saved do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
    end
end

local function saveCFG()
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end)
    getgenv()["AuroraCFG_timber_autofarm"] = CFG
end

loadSavedCFG()

---------- ZONE DATA ----------
local ZONE_NAMES = {"All Zones", "Timber Town", "Birch Glade", "Scarlet Canopy", "Winterneedle", "Koi Lanterns", "Thornveil", "Palm Cove"}
local _selectedZone = (CFG.SelectedZone >= 1 and CFG.SelectedZone <= #ZONE_NAMES) and CFG.SelectedZone or 1

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
local S = {hits = 0, treesDown = 0, collected = 0, sold = 0, session = tick()}

---------- HELPERS ----------
local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local function isTreeInZone(treePos)
    if _selectedZone == 1 then return true end
    local zoneName = ZONE_NAMES[_selectedZone]
    local zonesFolder = workspace:FindFirstChild("Zones")
    local zone = zonesFolder and zonesFolder:FindFirstChild(zoneName)
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
    local candidates = {}
    local treesFolder = workspace:FindFirstChild("Trees")
    if not treesFolder then return nil, 0 end
    for _, tree in treesFolder:GetChildren() do
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
    for _, c in candidates do
        if not isTreeOccupied(c.tree) then
            return c.tree, c.rate
        end
    end
    if #candidates > 0 then return candidates[1].tree, candidates[1].rate end
    return nil, 0
end

---------- LISTENERS ----------
pcall(function() Packets.tree_lumberjack_update.listen(function() S.hits += 1 end) end)
pcall(function() Packets.tree_despawn.listen(function() S.treesDown += 1 end) end)

---------- CORE LOOPS ----------
task.spawn(function()
    local _target = nil
    while task.wait(0.3) do
        if not CFG.AutoChop then _target = nil; _currentTree = nil; continue end
        if _target then
            if not _target.tree.Parent then
                S.treesDown += 1
                _target = nil
            elseif isTreeOccupied(_target.tree) then
                _target = nil
            end
        end
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
                local zoneName = ZONE_NAMES[_selectedZone]
                if zoneName == "Palm Cove" then
                    _currentTree = "Traveling to Palm Cove..."
                    pcall(function()
                        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = CFrame.new(-41, 10, -707) end
                    end)
                    task.wait(0.5)
                    pcall(function() sendBoatTravel("PalmCove") end)
                    task.wait(5)
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
        if _target then
            pcall(function() sendAxeHit(_target.seed) end)
            S.hits += 1
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
task.spawn(function()
    while task.wait(jitter(0.5, 0.5)) do
        pcall(function()
            local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if CFG.SpeedBoost then hum.WalkSpeed = 80; hum.JumpPower = 80; _speedOn = true
            elseif _speedOn then hum.WalkSpeed = 16; hum.JumpPower = 50; _speedOn = false end
        end)
    end
end)

task.spawn(function()
    while true do
        if CFG.AntiAFK then
            pcall(sendAfkRejoin)
            pcall(function() local v = game:GetService("VirtualUser"); v:CaptureController(); v:ClickButton2(Vector2.new()) end)
        end
        task.wait(60)
    end
end)

task.spawn(function()
    while true do
        if CFG.AutoQuest then
            pcall(sendQuestClaim)
        end
        task.wait(15)
    end
end)

-- ============================================================
-- V2 SIDEBAR UI
-- ============================================================

local C = {
    bg       = Color3.fromRGB(20, 20, 20),
    sidebar  = Color3.fromRGB(25, 25, 25),
    panel    = Color3.fromRGB(30, 30, 30),
    card     = Color3.fromRGB(35, 35, 35),
    accent   = Color3.fromRGB(252, 110, 142),
    accentDim = Color3.fromRGB(180, 80, 110),
    text     = Color3.fromRGB(255, 255, 255),
    dim      = Color3.fromRGB(150, 150, 150),
    green    = Color3.fromRGB(0, 200, 100),
    red      = Color3.fromRGB(255, 80, 80),
    trackOff = Color3.fromRGB(60, 60, 60),
    knobOff  = Color3.fromRGB(90, 90, 90),
    stroke   = Color3.fromRGB(80, 80, 80),
    sliderBg = Color3.fromRGB(45, 45, 45),
}

---------- UI HELPERS ----------
local function create(class, props, parent)
    local inst = Instance.new(class)
    for k, v in props do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end
local function corner(p, r) return create("UICorner", { CornerRadius = UDim.new(0, r) }, p) end
local function stroke(p, col, th, tr)
    return create("UIStroke", { Color = col, Thickness = th or 1, Transparency = tr or 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end
local function lbl(parent, props)
    local d = { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = C.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, BorderSizePixel = 0, Active = false }
    for k, v in d do if props[k] == nil then props[k] = v end end
    return create("TextLabel", props, parent)
end
local function connectClick(frame, cb)
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then cb() end
    end)
end

---------- SCREEN GUI ----------
local gui = create("ScreenGui", {
    Name = "Aurora", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50, IgnoreGuiInset = true,
})
local parentOk = false
if not parentOk and typeof(gethui) == "function" then
    parentOk = pcall(function() gui.Parent = gethui() end)
end
if not parentOk then
    parentOk = pcall(function() gui.Parent = game:GetService("CoreGui") end)
end
if not parentOk then
    pcall(function() gui.Parent = Player.PlayerGui end)
end

---------- MOBILE DETECTION + SCALING ----------
local _viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local _isMobile = UIS.TouchEnabled and (_viewport.X < 1200)
local _scale = _isMobile and math.clamp(_viewport.X / 700, 0.55, 0.85) or 1

---------- LAYOUT ----------
local SIDEBAR_W  = 110
local TOTAL_W    = 660
local TOTAL_H    = 455
local TOP_H      = 40
local GAP        = 6
local CONTENT_X  = SIDEBAR_W + GAP
local CONTENT_Y  = TOP_H + 4
local CONTENT_H  = TOTAL_H - CONTENT_Y - 6
local AVAIL_W    = TOTAL_W - CONTENT_X - 6
local LEFT_PW    = math.floor(AVAIL_W * 0.58)
local RIGHT_PW   = AVAIL_W - LEFT_PW - GAP

---------- MAIN ----------
local main = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
    Position = _isMobile and UDim2.new(0.5, -TOTAL_W * _scale / 2, 0, 40) or UDim2.fromOffset(16, 60),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0, BorderSizePixel = 0, Active = true, ClipsDescendants = true,
}, gui)
corner(main, 12)
stroke(main, C.stroke, 1, 0.2)
if _scale ~= 1 then create("UIScale", { Scale = _scale }, main) end

---------- TOP BAR ----------
local topBar = create("Frame", {
    Name = "TopBar", Size = UDim2.new(1, 0, 0, TOP_H), Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = C.sidebar, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 5,
}, main)
corner(topBar, 12)
create("Frame", {
    Name = "TopDivider", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = C.stroke, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5,
}, topBar)

create("ImageLabel", {
    Name = "Logo", Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(10, 6),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181", ScaleType = Enum.ScaleType.Fit, ZIndex = 6,
}, topBar)

lbl(topBar, {
    Name = "Title", Size = UDim2.new(0, 80, 1, 0), Position = UDim2.fromOffset(44, 0),
    Text = "Aurora", TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = C.accent, ZIndex = 6,
})

local gameName = "Timber!"
pcall(function() gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
lbl(topBar, {
    Name = "Game", Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(1, -310, 0, 0),
    Text = gameName, TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
})

local minBtn = create("Frame", {
    Name = "Min", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -72, 0.5, -15),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, topBar)
lbl(minBtn, { Size = UDim2.new(1,0,1,0), Text = "\xE2\x80\x93", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })

local closeBtn = create("Frame", {
    Name = "Close", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0.5, -15),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, topBar)
lbl(closeBtn, { Size = UDim2.new(1,0,1,0), Text = "x", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })

-- Drag handle
local dragHandle = create("Frame", {
    Name = "DragHandle", Size = UDim2.new(1, -80, 1, 0),
    BackgroundTransparency = 1, Active = true, ZIndex = 5,
}, topBar)
do
    local dragging, dragStart, startPos = false, nil, nil
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

---------- MINIMIZE FLOWER ----------
local flower = create("Frame", {
    Name = "Flower", Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(16, 60),
    BackgroundColor3 = C.accent, BackgroundTransparency = 0.3,
    BorderSizePixel = 0, Visible = false, Active = true,
}, gui)
corner(flower, 22)
stroke(flower, C.accent, 2, 0.2)
create("ImageLabel", {
    Size = UDim2.new(0.7, 0, 0.7, 0), Position = UDim2.new(0.15, 0, 0.15, 0),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181",
    ScaleType = Enum.ScaleType.Fit,
}, flower)

connectClick(flower, function()
    flower.Visible = false
    main.Position = flower.Position
end)

connectClick(minBtn, function()
    flower.Position = main.Position
    main.Position = UDim2.fromOffset(-9999, -9999)
    flower.Visible = true
end)
connectClick(closeBtn, function() gui:Destroy() end)

---------- SIDEBAR ----------
local sidebar = create("Frame", {
    Name = "Sidebar", Size = UDim2.new(0, SIDEBAR_W, 1, -TOP_H),
    Position = UDim2.fromOffset(0, TOP_H), BackgroundColor3 = C.sidebar, BackgroundTransparency = 0, BorderSizePixel = 0,
    ClipsDescendants = true,
}, main)
corner(sidebar, 12)
create("Frame", { Name = "Divider", Size = UDim2.new(0, 1, 1, -8), Position = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C.stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0 }, sidebar)

local TAB_DEFS = {
    { name = "Farm",    color = Color3.fromRGB(80, 200, 120) },
    { name = "Zones",   color = Color3.fromRGB(100, 180, 255) },
    { name = "Utility", color = Color3.fromRGB(255, 200, 80) },
}
local CONFIG_TAB = { name = "Config", color = Color3.fromRGB(130, 130, 155) }

local tabBtns = {}
local leftContainers = {}
local rightContainers = {}

local tabList = create("Frame", {
    Name = "TabList", Size = UDim2.new(1, -8, 0, #TAB_DEFS * 40 + 4),
    Position = UDim2.fromOffset(4, 8), BackgroundTransparency = 1, BorderSizePixel = 0,
}, sidebar)
create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, tabList)

local function makeTabBtn(def, idx, parent)
    local btn = create("Frame", {
        Name = "Tab_" .. def.name, Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.card, BackgroundTransparency = 0.5, BorderSizePixel = 0, Active = true, LayoutOrder = idx,
    }, parent)
    corner(btn, 8)
    local indicator = create("Frame", {
        Name = "Indicator", Size = UDim2.new(0, 3, 0, 22), Position = UDim2.fromOffset(0, 7),
        BackgroundColor3 = def.color or C.accent, BackgroundTransparency = 1, BorderSizePixel = 0,
    }, btn)
    corner(indicator, 2)
    lbl(btn, {
        Name = "Label", Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 0),
        Text = def.name, TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    return btn, indicator
end

local allTabs = {}
for i, def in TAB_DEFS do
    local btn, ind = makeTabBtn(def, i, tabList)
    allTabs[i] = { btn = btn, indicator = ind, name = def.name }
end

local configBtn, configInd = makeTabBtn(CONFIG_TAB, 99, nil)
configBtn.Parent = sidebar
configBtn.Position = UDim2.new(0, 4, 1, -44)
configBtn.Size = UDim2.new(1, -8, 0, 36)
allTabs[#TAB_DEFS + 1] = { btn = configBtn, indicator = configInd, name = "Config" }

---------- CONTENT PANELS ----------
local function makePanel(name, xPos, width)
    local p = create("ScrollingFrame", {
        Name = name, Size = UDim2.new(0, width, 0, CONTENT_H),
        Position = UDim2.fromOffset(xPos, CONTENT_Y),
        BackgroundColor3 = C.panel, BackgroundTransparency = 0.10, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
        TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    }, main)
    corner(p, 10)
    stroke(p, C.stroke, 1, 0.4)
    create("UIPadding", { PaddingTop = UDim.new(0,8), PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10), PaddingBottom = UDim.new(0,10) }, p)
    local layout = create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, p)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        p.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
    end)
    return p
end

local TOTAL_TABS = #TAB_DEFS + 1
for i = 1, TOTAL_TABS do
    local tabName = (i <= #TAB_DEFS) and TAB_DEFS[i].name or "Config"
    local lp = makePanel("L_" .. tabName, CONTENT_X, LEFT_PW)
    local rp = makePanel("R_" .. tabName, CONTENT_X + LEFT_PW + GAP, RIGHT_PW)
    lp.Visible = (i == 1)
    rp.Visible = (i == 1)
    leftContainers[i] = lp
    rightContainers[i] = rp
end

---------- SWITCH TAB ----------
local activeTabIdx = 1
local function switchTab(idx)
    activeTabIdx = idx
    for i, t in allTabs do
        local active = (i == idx)
        t.btn.BackgroundTransparency = active and 0.15 or 0.5
        t.indicator.BackgroundTransparency = active and 0 or 1
        local lblInst = t.btn:FindFirstChild("Label")
        if lblInst then lblInst.TextColor3 = active and C.text or C.dim end
    end
    for i = 1, TOTAL_TABS do
        leftContainers[i].Visible = (i == idx)
        rightContainers[i].Visible = (i == idx)
    end
end

for i, t in allTabs do
    local ci = i
    connectClick(t.btn, function() switchTab(ci) end)
end

---------- COMPONENT BUILDERS ----------
local _order = {}
local _curLeft, _curRight = nil, nil

local function setPanel(leftP, rightP)
    _curLeft = leftP; _curRight = rightP
    _order[leftP] = 0; _order[rightP] = 0
end

local function nextOrder(panel)
    _order[panel] = (_order[panel] or 0) + 1
    return _order[panel]
end

local function sectionHeader(title, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    create("Frame", { Size = UDim2.new(1,0,0,2), BackgroundTransparency = 1, LayoutOrder = o }, panel)
    o = nextOrder(panel)
    local row = create("Frame", { Size = UDim2.new(1,0,0,24), BackgroundTransparency = 1, LayoutOrder = o, BorderSizePixel = 0 }, panel)
    create("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, row)
    corner(row:FindFirstChild("Frame"), 2)
    lbl(row, { Size = UDim2.new(1,-12,1,0), Position = UDim2.fromOffset(12, 0), Text = string.upper(title), TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = C.accent })
end

local function toggleRow(name, cfgKey, panel, callback)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local row = create("Frame", {
        Name = "T_" .. name, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(row, 8)
    lbl(row, { Size = UDim2.new(1,-60,1,0), Position = UDim2.fromOffset(10,0), Text = name, TextSize = 13, Font = Enum.Font.Gotham })
    local track = create("Frame", {
        Name = "Track", Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1,-48, 0.5,-10),
        BackgroundColor3 = CFG[cfgKey] and C.accent or C.trackOff, BorderSizePixel = 0,
    }, row)
    corner(track, 10)
    local knob = create("Frame", {
        Name = "Knob", Size = UDim2.fromOffset(16, 16),
        Position = CFG[cfgKey] and UDim2.new(1,-18, 0.5,-8) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = CFG[cfgKey] and Color3.new(1,1,1) or C.knobOff, BorderSizePixel = 0,
    }, track)
    corner(knob, 8)
    local function updateVisual()
        local on = CFG[cfgKey]
        TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = on and C.accent or C.trackOff }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = on and UDim2.new(1,-18, 0.5,-8) or UDim2.fromOffset(2, 2),
            BackgroundColor3 = on and Color3.new(1,1,1) or C.knobOff,
        }):Play()
    end
    connectClick(row, function()
        CFG[cfgKey] = not CFG[cfgKey]
        updateVisual()
        if CFG.AutoSave then saveCFG() end
        if callback then callback(CFG[cfgKey]) end
    end)
    return row, updateVisual
end

local function infoRow(name, initialValue, panel)
    panel = panel or _curRight
    local o = nextOrder(panel)
    local row = create("Frame", { Size = UDim2.new(1,0,0,22), BackgroundTransparency = 1, LayoutOrder = o, BorderSizePixel = 0 }, panel)
    lbl(row, { Size = UDim2.new(0.5,0,1,0), Position = UDim2.fromOffset(4,0), Text = name, TextSize = 10, Font = Enum.Font.GothamSemibold, TextColor3 = C.dim })
    local val = lbl(row, {
        Name = "Val", Size = UDim2.new(0.5,-4,1,0), Position = UDim2.new(0.5,0,0,0),
        Text = initialValue or "---", TextSize = 10, Font = Enum.Font.GothamBold,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Right,
    })
    return val
end

local function actionButton(name, color, panel, callback)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local btn = create("Frame", {
        Name = "A_" .. name, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = color or C.accent,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(btn, 8)
    local btnLabel = lbl(btn, {
        Size = UDim2.new(1,0,1,0), Text = name, TextSize = 11, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.text,
    })
    connectClick(btn, function()
        if callback then callback() end
        local orig = btnLabel.Text
        btnLabel.Text = name .. " ..."
        btnLabel.TextColor3 = C.green
        task.delay(1.5, function() btnLabel.Text = orig; btnLabel.TextColor3 = C.text end)
    end)
    return btn
end

---------- TAB 1: FARM ----------
setPanel(leftContainers[1], rightContainers[1])

sectionHeader("Tree Chopping", _curLeft)
toggleRow("Auto Chop", "AutoChop", _curLeft)
toggleRow("Chop Nearby (No TP)", "ChopNoTP", _curLeft)

sectionHeader("Resources", _curLeft)
toggleRow("Auto Collect", "AutoCollect", _curLeft)
toggleRow("Auto Sell", "AutoSell", _curLeft)
toggleRow("Auto Quest", "AutoQuest", _curLeft)

sectionHeader("Farm Stats", _curRight)
local _infoTree = infoRow("Current Tree", "None", _curRight)
local _infoHits = infoRow("Hits", "0", _curRight)
local _infoTreesDown = infoRow("Trees Down", "0", _curRight)
local _infoCollected = infoRow("Collected", "0", _curRight)
local _infoSold = infoRow("Sold", "0", _curRight)

sectionHeader("Session", _curRight)
local _infoRuntime = infoRow("Runtime", "0m", _curRight)
local _infoStatus = infoRow("Status", "Idle", _curRight)

---------- TAB 2: ZONES ----------
setPanel(leftContainers[2], rightContainers[2])

sectionHeader("Zone Select", _curLeft)

-- Zone cycling selector
do
    local o = nextOrder(_curLeft)
    local row = create("Frame", {
        Name = "ZoneSelector", Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, _curLeft)
    corner(row, 8)
    lbl(row, { Size = UDim2.new(0.4,0,1,0), Position = UDim2.fromOffset(10,0), Text = "Zone", TextSize = 13, Font = Enum.Font.Gotham })
    local zoneLabel = lbl(row, {
        Name = "Val", Size = UDim2.new(0.6,-20,1,0), Position = UDim2.new(0.4,10,0,0),
        Text = ZONE_NAMES[_selectedZone], TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Right,
    })
    connectClick(row, function()
        _selectedZone = (_selectedZone % #ZONE_NAMES) + 1
        CFG.SelectedZone = _selectedZone
        zoneLabel.Text = ZONE_NAMES[_selectedZone]
        if CFG.AutoSave then saveCFG() end
    end)
end

sectionHeader("Zone Teleports", _curLeft)
for zName, zPos in ZONE_TP do
    actionButton(zName, C.card, _curLeft, function()
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = CFrame.new(zPos + Vector3.new(0, 5, 0)) end
        end)
    end)
end

sectionHeader("Travel", _curLeft)
actionButton("Boat to Palm Cove", C.card, _curLeft, function()
    pcall(function()
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(-41, 10, -707) end
    end)
    task.wait(0.5)
    pcall(sendBoatTravel, "PalmCove")
end)
actionButton("Boat Return", C.card, _curLeft, function()
    pcall(sendBoatReturn)
end)

sectionHeader("Zone Info", _curRight)
local _infoZone = infoRow("Selected", ZONE_NAMES[_selectedZone], _curRight)
for _, zn in ZONE_NAMES do
    if zn ~= "All Zones" then
        infoRow(zn, ZONE_TP[zn] and "Available" or "---", _curRight)
    end
end

---------- TAB 3: UTILITY ----------
setPanel(leftContainers[3], rightContainers[3])

sectionHeader("Player", _curLeft)
toggleRow("Speed Boost", "SpeedBoost", _curLeft)

sectionHeader("Safety", _curLeft)
toggleRow("Anti-AFK", "AntiAFK", _curLeft)

sectionHeader("Actions", _curLeft)
actionButton("Claim Free Sapling", C.card, _curLeft, function() pcall(sendFreeSapling) end)
actionButton("Claim Group Reward", C.card, _curLeft, function() pcall(sendJoinedGroup) end)
actionButton("Collect All Now", C.accent, _curLeft, function() pcall(sendCollectAll) end)
actionButton("Sell All Now", C.accent, _curLeft, function() pcall(sendSell) end)

sectionHeader("Player Stats", _curRight)
local _infoHealth = infoRow("Health", "---", _curRight)
local _infoSpeed = infoRow("Speed", "16", _curRight)

---------- TAB 4: CONFIG ----------
setPanel(leftContainers[4], rightContainers[4])

sectionHeader("Config Management", _curLeft)
toggleRow("Auto-Save", "AutoSave", _curLeft)

actionButton("Save Config", C.green, _curLeft, function() saveCFG() end)
actionButton("Load Config", C.accent, _curLeft, function() loadSavedCFG() end)
actionButton("Reset All", C.red, _curLeft, function()
    for k, v in CFG do if type(v) == "boolean" then CFG[k] = false end end
    CFG.SelectedZone = 1; _selectedZone = 1
    CFG.AutoSave = true
    saveCFG()
end)

sectionHeader("Config Info", _curRight)
infoRow("File", _cfgFileName, _curRight)

sectionHeader("Active Features", _curRight)
local _cfgActiveList = lbl(rightContainers[4], {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 120),
    Text = "None", TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    LayoutOrder = nextOrder(rightContainers[4]),
})

---------- STATUS UPDATE LOOP ----------
task.spawn(function()
    while task.wait(jitter(1, 0.5)) do
        pcall(function()
            _infoTree.Text = _currentTree or "None"
            _infoHits.Text = fmt(S.hits)
            _infoTreesDown.Text = tostring(S.treesDown)
            _infoCollected.Text = tostring(S.collected)
            _infoSold.Text = tostring(S.sold)
            _infoZone.Text = ZONE_NAMES[_selectedZone]

            if CFG.AutoChop then _infoStatus.Text = "Chopping"
            elseif CFG.ChopNoTP then _infoStatus.Text = "Chop (Near)"
            elseif CFG.AutoCollect then _infoStatus.Text = "Collecting"
            elseif CFG.AutoSell then _infoStatus.Text = "Selling"
            else _infoStatus.Text = "Idle" end

            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    _infoHealth.Text = string.format("%.0f/%.0f", hum.Health, hum.MaxHealth)
                    _infoSpeed.Text = tostring(math.floor(hum.WalkSpeed))
                end
            end

            local elapsed = tick() - S.session
            local mins = math.floor(elapsed / 60)
            local hrs = math.floor(mins / 60)
            _infoRuntime.Text = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            local active = {}
            for k, v in CFG do if type(v) == "boolean" and v and k ~= "AutoSave" then table.insert(active, k) end end
            _cfgActiveList.Text = #active > 0 and table.concat(active, "\n") or "None"
            _cfgActiveList.Size = UDim2.new(1, 0, 0, math.max(60, #active * 14 + 10))
        end)
    end
end)

---------- INIT ----------
switchTab(1)
print("[Aurora] Timber! v3 loaded")
