--// Aurora v3 — +1 Skill Point Legends Auto-Farm
--// Made by notCitruss | Dark Glass Theme
--// All interactive elements use Frames (game anti-cheat kills TextButtons)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local ok1, Interactions = pcall(require, RS:FindFirstChild("Source") and RS.Source:FindFirstChild("Packets") and RS.Source.Packets:FindFirstChild("Interactions") and RS.Source.Packets.Interactions)
if not ok1 or not Interactions then warn("[Aurora] Interactions module not found"); return end
local ok2, fusion = pcall(require, RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("fusion") and RS.Packages.fusion)
if not ok2 then fusion = nil end
local ok3, Values = pcall(require, RS:FindFirstChild("Source") and RS.Source:FindFirstChild("Utils") and RS.Source.Utils:FindFirstChild("Values") and RS.Source.Utils.Values)
if not ok3 then Values = nil end
local fus = fusion

-- ─── CONFIG ──────────────────────────────────────────────────────────────────

local CFG = {
    AutoFarm = false,
    TeleportToNPC = false,
    AntiAFK = false,
    AutoDaily = false,
    AutoStat = false,
    Noclip = false,
    AutoHeal = false,
    AutoChest = false,
    AutoPotion = false,
    AttackSpeed = 0.3,
    TargetMobs = {},
    StatTarget = "Physical Damage",
    AutoSave = true,
}

-- ─── TOGGLE SAVE/LOAD ────────────────────────────────────────────────────────
local _cfgFileName = "aurora_cfg_skill_point_legends.json"
local HttpService = game:GetService("HttpService")

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_skill_point_legends"] end
    if saved and type(saved) == "table" then
        for k, v in saved do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
    end
end

local function saveCFG()
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end)
    getgenv()["AuroraCFG_skill_point_legends"] = CFG
end

loadSavedCFG()

-- ─── CONSTANTS ────────────────────────────────────────────────────────────────

local STAT_NAMES = {
    "Physical Damage",
    "Magic Damage",
    "Health",
    "Regeneration",
    "Speed",
    "Jump Power",
}

local MOB_LIST = {
    "Any","Snail","Pig","Turtle","Caveman","Spider","Mammoth","Viperbloom",
    "Warlock","Spartan","Chief","Reaper","Dino","Angel","Arachinex","Cowboy",
    "Grimroot","Leonidas","Ghost","Totem Sentinel","Mummy","Lightning God",
    "Blightleap","Bonepicker","Sand Golem","Oculon","Magmaton","Hydra Worm",
    "Knobble","Dragon","Puffcap","Nevermore","Minotaur","Simba","Winxy",
    "Anubis","Shellthorn","Ashgor","Eyegor","Bloodroot Witch","Queen of Serpents",
}

local NPC_SPAWN_POS = {
    Snail = Vector3.new(502, 8, 539),
    Pig = Vector3.new(767, 5, 220),
    Turtle = Vector3.new(897, 4, -101),
    Caveman = Vector3.new(497, 5, -449),
    Spider = Vector3.new(911, 5, 609),
    Mammoth = Vector3.new(1244, 6, 301),
    Chief = Vector3.new(350, 8, 490),
    Dino = Vector3.new(1294, 6, 642),
    Arachinex = Vector3.new(1386, 6, -51),
    Ashgor = Vector3.new(1100, 6, 300),
    Viperbloom = Vector3.new(885, 6, -468),
    Warlock = Vector3.new(1972, 14, -710),
    Spartan = Vector3.new(2097, 191, -665),
    Grimroot = Vector3.new(1277, 18, -611),
    Leonidas = Vector3.new(2750, 83, -660),
    Reaper = Vector3.new(889, 384, -1611),
    Angel = Vector3.new(525, 384, -1891),
    ["Lightning God"] = Vector3.new(616, 407, -2165),
    Cowboy = Vector3.new(782, 40, -3365),
    Ghost = Vector3.new(278, 40, -3169),
    ["Totem Sentinel"] = Vector3.new(380, 40, -3476),
    Mummy = Vector3.new(684, 40, -3789),
    ["Sand Golem"] = Vector3.new(600, 40, -3600),
    ["Hydra Worm"] = Vector3.new(603, 40, -3465),
    Dragon = Vector3.new(649, 320, -3575),
    Blightleap = Vector3.new(1320, -433, -3057),
    Bonepicker = Vector3.new(1320, -433, -3200),
    Oculon = Vector3.new(1400, -433, -3100),
    Magmaton = Vector3.new(1200, -433, -3300),
    Simba = Vector3.new(1320, -433, -3400),
    Nevermore = Vector3.new(1500, -433, -3100),
    Anubis = Vector3.new(1320, -433, -3500),
}

-- NPC zone map
local NPC_ZONE_MAP = {}
pcall(function()
    local NpcTable = require(RS.Source.Utils.NpcTable)
    for k, v in NpcTable do
        if type(v) == "table" and v.zone then
            NPC_ZONE_MAP[k] = v.zone
        end
    end
end)

-- ─── STATE ────────────────────────────────────────────────────────────────────

local _running = false
local _stopFlag = false
local _thread = nil
local _kills = 0
local _spGained = 0
local _spStart = 0
local _lastNPC = "None"
local _stuckTarget = nil
local _stuckTime = 0
local _blacklist = {}
local STUCK_TIMEOUT = 4

-- ─── HELPER FUNCTIONS ────────────────────────────────────────────────────────

local function getHRP()
    local char = Player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function formatNum(n: number): string
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local function getWeaponModule()
    local weaponName = "Punch"
    pcall(function()
        local inv = fus.peek(Values.inventory)
        local equipped = fus.peek(Values.equippedItems)
        if equipped and equipped.Weapon and inv[equipped.Weapon] then
            weaponName = inv[equipped.Weapon].n or "Punch"
        end
    end)
    local mod = RS.Source.Weapons:FindFirstChild(weaponName) or RS.Source.Weapons:FindFirstChild(weaponName:gsub(" ", "")) or RS.Source.Weapons:FindFirstChild("Punch")
    if mod then
        local ok, result = pcall(require, mod)
        return ok and result or nil, weaponName
    end
    return nil, weaponName
end

local function getNpcName(npc): string
    for _, desc in npc:GetDescendants() do
        if desc:IsA("TextLabel") and desc.Text ~= "" and not desc.Text:find("/") then
            -- Strip emoji prefixes (💀, ⚡, etc.) for clean name matching
            local text = desc.Text:gsub("^[^%w]+%s*", "")
            return text ~= "" and text or desc.Text
        end
    end
    return nil
end

local function findNearestNPC()
    local hrp = getHRP()
    if not hrp then return nil end
    local npcsFolder = workspace:FindFirstChild("Npcs")
    if not npcsFolder then return nil end
    local best, bestDist, bestName = nil, math.huge, nil
    local hasFilter = next(CFG.TargetMobs) ~= nil
    for _, npc in npcsFolder:GetChildren() do
        if npc:IsA("Model") and not npc:GetAttribute("Dead") and not _blacklist[npc] then
            local npcHrp = npc:FindFirstChild("HumanoidRootPart")
            if npcHrp then
                if hasFilter then
                    local name = getNpcName(npc)
                    local matched = false
                    if name then
                        for mob, _ in CFG.TargetMobs do
                            if name == mob or name:find(mob) then matched = true; break end
                        end
                    end
                    if not matched then continue end
                end
                local d = (npcHrp.Position - hrp.Position).Magnitude
                if d < bestDist then
                    best = npc; bestDist = d; bestName = getNpcName(npc) or npc.Name
                end
            end
        end
    end
    return best, bestDist, bestName
end

local _lastTP = 0
local TP_COOLDOWN = 1.5

local function tpToNPC(npc)
    if not npc then return end
    if tick() - _lastTP < TP_COOLDOWN then return end
    local hrp = getHRP()
    local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Root")
    if hrp and root then
        hrp.CFrame = root.CFrame + Vector3.new(4, 0, 0)
        _lastTP = tick()
    end
end

local function teleportToMobArea(mobName: string)
    if tick() - _lastTP < TP_COOLDOWN then task.wait(TP_COOLDOWN) end
    -- First: try to find a LIVE NPC with this name and TP directly to it
    local npcsFolder = workspace:FindFirstChild("Npcs")
    if npcsFolder then
        for _, npc in npcsFolder:GetChildren() do
            if npc:IsA("Model") and not npc:GetAttribute("Dead") then
                local nm = getNpcName(npc)
                if nm and (nm == mobName or nm:find(mobName)) then
                    local nhrp = npc:FindFirstChild("HumanoidRootPart")
                    if nhrp then
                        local hrp = getHRP()
                        if hrp then
                            hrp.CFrame = CFrame.new(nhrp.Position + Vector3.new(0, 3, -4), nhrp.Position)
                            _lastTP = tick()
                            return
                        end
                    end
                end
            end
        end
    end
    -- Fallback: hardcoded spawn position
    if NPC_SPAWN_POS[mobName] then
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(NPC_SPAWN_POS[mobName])
            _lastTP = tick()
            return
        end
    end
    -- Last resort: zone teleport
    local zone = NPC_ZONE_MAP[mobName]
    if zone then
        pcall(function()
            Interactions.teleportRequest.send(zone)
        end)
        _lastTP = tick()
    end
end

-- ─── FARM LOOP ───────────────────────────────────────────────────────────────

local function startFarm()
    if _running then return end
    _running = true
    _stopFlag = false
    pcall(function()
        local ls = Player:FindFirstChild("leaderstats")
        if ls and ls:FindFirstChild("SP") then
            _spStart = ls.SP.Value
        end
    end)
    _thread = task.spawn(function()
        local lastDaily = 0
        while not _stopFlag do
            local ok, err = pcall(function()
                local hrp = getHRP()
                if not hrp then task.wait(jitter(2, 0.6)) return end
                local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then task.wait(jitter(2, 0.6)) return end

                if CFG.AutoDaily and tick() - lastDaily > 60 then
                    pcall(function() Interactions.claimDailyReward.send() end)
                    pcall(function() Interactions.claimLikeReward.send() end)
                    lastDaily = tick()
                end

                local targets = {}
                local npcsFolder = workspace:FindFirstChild("Npcs")
                if npcsFolder then
                    local hasFilter = next(CFG.TargetMobs) ~= nil
                    for _, n in npcsFolder:GetChildren() do
                        if n:IsA("Model") and not n:GetAttribute("Dead") then
                            local nHrp = n:FindFirstChild("HumanoidRootPart")
                            if nHrp then
                                if hasFilter then
                                    local nm = getNpcName(n)
                                    if nm then
                                        for mob, _ in CFG.TargetMobs do
                                            if nm == mob or nm:find(mob) then
                                                table.insert(targets, {npc = n, hrp = nHrp, name = nm})
                                                break
                                            end
                                        end
                                    end
                                else
                                    table.insert(targets, {npc = n, hrp = nHrp, name = getNpcName(n) or n.Name})
                                end
                            end
                        end
                    end
                end

                if #targets == 0 and CFG.TeleportToNPC and next(CFG.TargetMobs) then
                    for mob, _ in CFG.TargetMobs do
                        if _stopFlag then break end
                        _lastNPC = "Searching " .. mob .. "..."
                        teleportToMobArea(mob)
                        task.wait(3)
                    end
                    return
                end

                for _, target in targets do
                    if _stopFlag then break end
                    if not target.npc or not target.npc.Parent or target.npc:GetAttribute("Dead") then continue end

                    _lastNPC = target.name or "Unknown"

                    if CFG.TeleportToNPC then
                        pcall(function()
                            hrp = getHRP()
                            if hrp and target.hrp and target.hrp.Parent then
                                hrp.CFrame = CFrame.new(target.hrp.Position + Vector3.new(0, 3, -4), target.hrp.Position)
                            end
                        end)
                        task.wait(0.2)
                    end

                    local attackStart = tick()
                    while not _stopFlag and target.npc and target.npc.Parent and not target.npc:GetAttribute("Dead") and tick() - attackStart < 6 do
                        pcall(function()
                            local weapon = getWeaponModule()
                            if weapon and weapon.onActivated then
                                weapon.onActivated(Mouse)
                            end
                        end)
                        task.wait(CFG.AttackSpeed)
                    end

                    if target.npc and target.npc:GetAttribute("Dead") then
                        _kills += 1
                    end
                end

                pcall(function()
                    local ls = Player:FindFirstChild("leaderstats")
                    if ls and ls:FindFirstChild("SP") then
                        _spGained = ls.SP.Value - _spStart
                    end
                end)
            end)
            if not ok then warn("[SPL] Farm error:", err) end
            task.wait(CFG.AttackSpeed)
        end
        _running = false
    end)
end

local function stopFarm()
    _stopFlag = true
    if _thread then
        pcall(task.cancel, _thread)
        _thread = nil
    end
    _running = false
end

-- ─── ANTI-AFK LOOP ──────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if CFG.AntiAFK then
            pcall(function() VirtualUser:CaptureController() end)
            pcall(function() VirtualUser:ClickButton2(Vector2.new()) end)
        end
        task.wait(30)
    end
end)

-- ─── AUTO STAT LOOP ─────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if CFG.AutoStat then
            pcall(function()
                local currentSP = fus.peek(Values.skillPoints)
                if currentSP and currentSP >= 3 then
                    local amount = math.min(currentSP, math.max(3, math.floor(currentSP * 0.5)))
                    Interactions.statUpdateRequest.send({ stat = CFG.StatTarget, amount = amount })
                end
            end)
        end
        task.wait(2)
    end
end)

-- ─── AUTO CHEST LOOP ────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if CFG.AutoChest then
            pcall(function() Interactions.chestOpenRequest.send() end)
        end
        task.wait(5)
    end
end)

-- ─── AUTO POTION LOOP ───────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if CFG.AutoPotion then
            pcall(function() Interactions.potionUseRequest.send() end)
        end
        task.wait(10)
    end
end)

-- ─── NOCLIP + AUTO HEAL ─────────────────────────────────────────────────────

RunService.Stepped:Connect(function()
    pcall(function()
        local char = Player.Character
        if not char then return end
        if CFG.Noclip then
            for _, p in char:GetDescendants() do
                if p:IsA("BasePart") then
                    p.CanCollide = false
                end
            end
        end
        if CFG.AutoHeal then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = hum.MaxHealth end
        end
    end)
end)

local function hookHeal(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        hum = char:WaitForChild("Humanoid", 5)
    end
    if hum then
        hum.HealthChanged:Connect(function()
            if CFG.AutoHeal and hum.Health < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end)
    end
end
Player.CharacterAdded:Connect(hookHeal)
if Player.Character then
    pcall(hookHeal, Player.Character)
end

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

---------- DETECT GAME NAME ----------
local gameName = "+1 Skill Point Legends"
pcall(function()
    local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    if info and info.Name then gameName = info.Name end
end)

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

---------- CLEANUP OLD GUI ----------
for _, n in {"Aurora", "AuroraSPL"} do
    pcall(function() if gethui then local old = gethui():FindFirstChild(n); if old then old:Destroy() end end end)
    pcall(function() local old = game:GetService("CoreGui"):FindFirstChild(n); if old then old:Destroy() end end)
    pcall(function() local old = Player.PlayerGui:FindFirstChild(n); if old then old:Destroy() end end)
end
task.wait(0.1)

---------- SCREEN GUI ----------
local gui = create("ScreenGui", {
    Name = "Aurora", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50, IgnoreGuiInset = true,
})
local _isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local parentOk = false
if _isMobile then
    parentOk = pcall(function() gui.Parent = Player.PlayerGui end)
end
if not parentOk then
    parentOk = pcall(function()
        gui.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    end)
end
if not parentOk then pcall(function() gui.Parent = Player.PlayerGui end) end


local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
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
---------- SESSION KILL ----------
local _SESSION_KEY = "AURORA_SPL_SESSION"
getgenv()[_SESSION_KEY] = (getgenv()[_SESSION_KEY] or 0) + 1
local _mySession = getgenv()[_SESSION_KEY]
local function alive() return getgenv()[_SESSION_KEY] == _mySession and gui and gui.Parent end

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
create("Frame", {
    Name = "Divider", Size = UDim2.new(0, 1, 1, -8), Position = UDim2.new(1, 0, 0, 4),
    BackgroundColor3 = C.stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0,
}, sidebar)

local TAB_DEFS = {
    { name = "Farm",    color = Color3.fromRGB(80, 200, 120) },
    { name = "Combat",  color = Color3.fromRGB(255, 100, 100) },
    { name = "Utility", color = Color3.fromRGB(180, 130, 255) },
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

local configBtnTab, configInd = makeTabBtn(CONFIG_TAB, 99, nil)
configBtnTab.Parent = sidebar
configBtnTab.Position = UDim2.new(0, 4, 1, -44)
configBtnTab.Size = UDim2.new(1, -8, 0, 36)
allTabs[#TAB_DEFS + 1] = { btn = configBtnTab, indicator = configInd, name = "Config" }

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

local function sliderRow(name, cfgKey, min, max, step, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local row = create("Frame", {
        Name = "S_" .. name, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(row, 8)
    lbl(row, { Size = UDim2.new(0.5,0,0,20), Position = UDim2.fromOffset(10,2), Text = name, TextSize = 12, Font = Enum.Font.Gotham })
    local valLabel = lbl(row, {
        Name = "Val", Size = UDim2.new(0.5,-20,0,20), Position = UDim2.new(0.5,10,0,2),
        Text = tostring(CFG[cfgKey]), TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Right,
    })
    local trackFrame = create("Frame", {
        Name = "SlTrack", Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 30),
        BackgroundColor3 = C.sliderBg, BorderSizePixel = 0, Active = true,
    }, row)
    corner(trackFrame, 3)
    local pct = math.clamp((CFG[cfgKey] - min) / (max - min), 0, 1)
    local fill = create("Frame", {
        Name = "Fill", Size = UDim2.new(pct, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0,
    }, trackFrame)
    corner(fill, 3)
    local knobSize = 14
    local sKnob = create("Frame", {
        Name = "Knob", Size = UDim2.fromOffset(knobSize, knobSize),
        Position = UDim2.new(pct, -knobSize/2, 0.5, -knobSize/2),
        BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 3,
    }, trackFrame)
    corner(sKnob, knobSize/2)
    local sliding = false
    local function updateSlider(inputX)
        local absPos = trackFrame.AbsolutePosition.X
        local absSize = trackFrame.AbsoluteSize.X
        local raw = math.clamp((inputX - absPos) / absSize, 0, 1)
        local val = min + raw * (max - min)
        val = math.floor(val / step + 0.5) * step
        val = math.clamp(val, min, max)
        if step >= 1 then val = math.floor(val) end
        CFG[cfgKey] = val
        local newPct = math.clamp((val - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(newPct, 0, 1, 0)
        sKnob.Position = UDim2.new(newPct, -knobSize/2, 0.5, -knobSize/2)
        valLabel.Text = (step < 1) and string.format("%.1f", val) or tostring(val)
        if CFG.AutoSave then saveCFG() end
    end
    trackFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true; updateSlider(input.Position.X)
        end
    end)
    sKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    return row
end

local function infoRow(name, initialValue, panel)
    panel = panel or _curRight
    local o = nextOrder(panel)
    local row = create("Frame", {
        Size = UDim2.new(1,0,0,22), BackgroundTransparency = 1, LayoutOrder = o, BorderSizePixel = 0,
    }, panel)
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

sectionHeader("Auto-Farm", _curLeft)
toggleRow("Auto Farm", "AutoFarm", _curLeft, function(on)
    if on then startFarm() else stopFarm() end
end)
toggleRow("Teleport to NPC", "TeleportToNPC", _curLeft)
sliderRow("Attack Speed", "AttackSpeed", 0.1, 1.0, 0.1, _curLeft)

sectionHeader("Target Mobs", _curLeft)
for _, mobName in MOB_LIST do
    if mobName == "Any" then continue end
    local o = nextOrder(_curLeft)
    local row = create("Frame", {
        Name = "M_" .. mobName, Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, _curLeft)
    corner(row, 6)
    lbl(row, { Size = UDim2.new(1,-50,1,0), Position = UDim2.fromOffset(10,0), Text = mobName, TextSize = 11, Font = Enum.Font.Gotham })
    local isOn = CFG.TargetMobs[mobName] ~= nil
    local check = create("Frame", {
        Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1,-28, 0.5,-9),
        BackgroundColor3 = isOn and C.accent or C.trackOff, BorderSizePixel = 0,
    }, row)
    corner(check, 4)
    local checkMark = lbl(check, { Size = UDim2.new(1,0,1,0), Text = isOn and "X" or "", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.text })
    connectClick(row, function()
        if CFG.TargetMobs[mobName] then
            CFG.TargetMobs[mobName] = nil
        else
            CFG.TargetMobs[mobName] = true
        end
        local nowOn = CFG.TargetMobs[mobName] ~= nil
        check.BackgroundColor3 = nowOn and C.accent or C.trackOff
        checkMark.Text = nowOn and "X" or ""
        if CFG.AutoSave then saveCFG() end
    end)
end

sectionHeader("Farm Status", _curRight)
local _infoTarget = infoRow("Target", "None", _curRight)
local _infoStatus = infoRow("Status", "Idle", _curRight)
local _infoKills = infoRow("Kills", "0", _curRight)
local _infoSPGained = infoRow("SP Gained", "0", _curRight)

sectionHeader("Session", _curRight)
local _infoRuntime = infoRow("Runtime", "0m", _curRight)
local _infoLevel = infoRow("Level", "---", _curRight)
local _infoSP = infoRow("SP", "---", _curRight)

---------- TAB 2: COMBAT ----------
setPanel(leftContainers[2], rightContainers[2])

sectionHeader("Combat Assist", _curLeft)
toggleRow("Auto Heal", "AutoHeal", _curLeft)
toggleRow("Auto Potion", "AutoPotion", _curLeft)
toggleRow("Auto Chest", "AutoChest", _curLeft)
toggleRow("Auto Daily", "AutoDaily", _curLeft)

sectionHeader("Stats", _curLeft)
toggleRow("Auto Stat", "AutoStat", _curLeft)

sectionHeader("Stat Target", _curLeft)
do
    local o = nextOrder(_curLeft)
    local statRow = create("Frame", {
        Name = "StatSelector", Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, _curLeft)
    corner(statRow, 8)
    lbl(statRow, { Size = UDim2.new(0.35,0,1,0), Position = UDim2.fromOffset(10,0), Text = "Target", TextSize = 13, Font = Enum.Font.Gotham })
    local statValLabel = lbl(statRow, {
        Name = "Val", Size = UDim2.new(0.65,-20,1,0), Position = UDim2.new(0.35,10,0,0),
        Text = CFG.StatTarget, TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.accent,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local _statIdx = 1
    for si, sn in STAT_NAMES do if sn == CFG.StatTarget then _statIdx = si; break end end
    connectClick(statRow, function()
        _statIdx = (_statIdx % #STAT_NAMES) + 1
        CFG.StatTarget = STAT_NAMES[_statIdx]
        statValLabel.Text = CFG.StatTarget
        if CFG.AutoSave then saveCFG() end
    end)
end

sectionHeader("Combat Info", _curRight)
local _infoWeapon = infoRow("Weapon", "---", _curRight)
local _infoHealth = infoRow("Health", "---", _curRight)
local _infoStatTarget = infoRow("Stat Target", CFG.StatTarget, _curRight)

---------- TAB 3: UTILITY ----------
setPanel(leftContainers[3], rightContainers[3])

sectionHeader("Movement", _curLeft)
toggleRow("Noclip", "Noclip", _curLeft)

sectionHeader("Safety", _curLeft)
toggleRow("Anti-AFK", "AntiAFK", _curLeft)

sectionHeader("Player Info", _curRight)
local _infoHealthUtil = infoRow("Health", "---", _curRight)
local _infoWalkSpd = infoRow("Walk Speed", "---", _curRight)

---------- TAB 4: CONFIG ----------
setPanel(leftContainers[4], rightContainers[4])

sectionHeader("Config Management", _curLeft)
toggleRow("Auto-Save", "AutoSave", _curLeft)

actionButton("Save Config", C.green, _curLeft, function() saveCFG() end)
actionButton("Load Config", C.accent, _curLeft, function() loadSavedCFG() end)
actionButton("Reset All", C.red, _curLeft, function()
    for k, v in CFG do
        if type(v) == "boolean" then CFG[k] = false end
    end
    CFG.AttackSpeed = 0.3; CFG.StatTarget = "Physical Damage"
    CFG.TargetMobs = {}
    CFG.AutoSave = true
    saveCFG()
    stopFarm()
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
    while alive() do
        task.wait(jitter(1, 0.5))
        if not alive() then break end
        pcall(function()
            _infoTarget.Text = _lastNPC or "None"
            _infoStatus.Text = _running and "Farming" or "Idle"
            _infoKills.Text = tostring(_kills)
            _infoSPGained.Text = formatNum(_spGained)
            _infoStatTarget.Text = CFG.StatTarget

            local elapsed = tick() - (S and S.session or tick())
            local mins = math.floor(elapsed / 60)
            local hrs = math.floor(mins / 60)
            _infoRuntime.Text = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            local ls = Player:FindFirstChild("leaderstats")
            if ls then
                local lv = ls:FindFirstChild("Level")
                local sp = ls:FindFirstChild("SP")
                if lv then _infoLevel.Text = tostring(lv.Value) end
                if sp then _infoSP.Text = formatNum(sp.Value) end
            end

            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    _infoHealth.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                    _infoHealthUtil.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                    _infoWalkSpd.Text = tostring(math.floor(hum.WalkSpeed))
                end
            end

            pcall(function()
                local _, wName = getWeaponModule()
                if wName then _infoWeapon.Text = wName end
            end)

            local active = {}
            for k, v in CFG do
                if type(v) == "boolean" and v and k ~= "AutoSave" then table.insert(active, k) end
            end
            _cfgActiveList.Text = #active > 0 and table.concat(active, "\n") or "None"
            _cfgActiveList.Size = UDim2.new(1, 0, 0, math.max(60, #active * 14 + 10))
        end)
    end
end)

switchTab(1)
print("[Aurora v3] +1 Skill Point Legends loaded")
