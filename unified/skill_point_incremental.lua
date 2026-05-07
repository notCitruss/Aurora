--// Aurora v5 — +1 Skill Point Incremental RPG
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 125007306703268 (+ 125007306703270 creator copy)
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// rajden28_packet networking + getgc(true) range patch — PRESERVED VERBATIM

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- Cleanup old UI (Xeno-safe: each parent chain in its own pcall)
for _, n in ipairs({"Aurora", "AuroraPill"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- COMPAT (cross-executor support) ----------
local _HAS = {
    gethui    = typeof(gethui) == "function",
    writefile = writefile ~= nil,
    firepp    = fireproximityprompt ~= nil,
    hookfn    = hookfunction ~= nil,
    getgc     = getgc ~= nil,
    vim       = pcall(function() return game:GetService("VirtualInputManager") end),
}
local function _promptAlive(p)
    local ok, r = pcall(function() return p and p.Parent and p.Enabled end)
    return ok and r
end
-- Cross-executor prompt firing: fireproximityprompt on Wave/Potassium/Delta,
-- InputHoldBegin + VIM E-key hold as fallback for Xeno and others that lack the helper.
local function safeFirePrompt(prompt)
    if not _promptAlive(prompt) then return end
    local holdTime = prompt.HoldDuration or 0
    pcall(function() if _HAS.firepp then fireproximityprompt(prompt) end end)
    task.wait(0.1)
    if not _promptAlive(prompt) then return end
    pcall(function()
        local oh = prompt.HoldDuration
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        task.wait(math.max(0.15, holdTime + 0.2))
        prompt:InputHoldEnd()
        prompt.HoldDuration = oh
    end)
    if not _promptAlive(prompt) then return end
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(math.max(0.2, holdTime + 0.2))
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_SPI_CFG2 then
    for k, v in pairs(getgenv().__AURORA_SPI_CFG2) do
        if type(v) == "boolean" then getgenv().__AURORA_SPI_CFG2[k] = false end
    end
end
-- Also zombie-kill any legacy v4 CFG (pre-v5 key was __AURORA_SPI_CFG)
if getgenv().__AURORA_SPI_CFG then
    for k, v in pairs(getgenv().__AURORA_SPI_CFG) do
        if type(v) == "boolean" then getgenv().__AURORA_SPI_CFG[k] = false end
    end
end
task.wait(0.15)

---------- SESSION GUARD ----------
getgenv().__AURORA_SPI_SESSION = tick()
local _mySession = getgenv().__AURORA_SPI_SESSION
local function alive() return getgenv().__AURORA_SPI_SESSION == _mySession end

---------- PACKETS (preserved verbatim from v4 — rajden28_packet module) ----------
local _sharedMod = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Packets")
local ok, Packets = pcall(require, _sharedMod)
if not ok or not Packets then warn("[Aurora] Packets module not found"); return end

local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- CONFIG (v5: getgenv-backed for zombie-kill) ----------
if not getgenv().__AURORA_SPI_CFG2 then
    getgenv().__AURORA_SPI_CFG2 = {
        -- v4 keys preserved exactly
        AutoFarm       = false,
        AutoEquip      = false,
        AutoSacrifice  = false,
        AutoClaim      = false,
        AutoXP         = false,
        AutoSP         = false,
        TargetSkill    = "strength",
        SpeedBoost     = false,
        AntiAFK        = false,
        NPCESP         = false,
        AutoSave       = true,
        -- v5 UI state (only additions)
        ActiveTab      = "Farm",
        PanelOpen      = true,
    }
else
    local c = getgenv().__AURORA_SPI_CFG2
    if c.ActiveTab == nil then c.ActiveTab = "Farm" end
    if c.PanelOpen == nil then c.PanelOpen = true end
end
local CFG = getgenv().__AURORA_SPI_CFG2

---------- SKILLS / NPC DATA (preserved verbatim from v4) ----------
local SKILLS = {"strength", "vitality", "speed", "precision", "regen", "wisdom", "lifesteal"}
local _skillIdx = 1

local ZONE_NPCS = {
    Forest = {"chicken", "goblin", "cow", "imp", "giantchicken", "giantgoblin", "giantcow", "giantimp"},
    Swamp = {"snail", "bear", "mossgoblin", "terrorbird", "generalbonecrusherboss", "giantsnail", "giantbear", "giantmossgoblin", "giantterrorbird"},
    Desert = {"rockgolem", "camel", "dustdevil", "scorpion", "giantrockgolem", "giantcamel", "giantdustdevil", "giantscorpion"},
    Wilderness = {"spider", "darkgolem", "mammoth", "minotaur", "blackdragonboss", "giantspider", "giantdarkgolem", "giantmammoth", "giantminotaur"},
}

local NPC_LABELS = {
    chicken = "Chicken", goblin = "Goblin", cow = "Cow", imp = "Imp",
    giantchicken = "Giant Chicken", giantgoblin = "Giant Goblin", giantcow = "Giant Cow", giantimp = "Giant Imp",
    snail = "Snail", bear = "Bear", mossgoblin = "Moss Goblin", terrorbird = "Terrorbird",
    generalbonecrusherboss = "General Bonecrusher", giantsnail = "Giant Snail", giantbear = "Giant Bear",
    giantmossgoblin = "Giant Moss Goblin", giantterrorbird = "Giant Terrorbird",
    rockgolem = "Rock Golem", camel = "Camel", dustdevil = "Dust Devil", scorpion = "Scorpion",
    giantrockgolem = "Giant Rock Golem", giantcamel = "Giant Camel", giantdustdevil = "Giant Dust Devil", giantscorpion = "Giant Scorpion",
    spider = "Spider", darkgolem = "Dark Golem", mammoth = "Mammoth", minotaur = "Minotaur",
    blackdragonboss = "Black Dragon", giantspider = "Giant Spider", giantdarkgolem = "Giant Dark Golem",
    giantmammoth = "Giant Mammoth", giantminotaur = "Giant Minotaur",
}

local ALL_MOBS = {
    "chicken", "giantchicken", "goblin", "giantgoblin", "cow", "giantcow", "imp", "giantimp",
    "snail", "giantsnail", "bear", "giantbear", "mossgoblin", "giantmossgoblin", "terrorbird", "giantterrorbird", "generalbonecrusherboss",
    "rockgolem", "giantrockgolem", "camel", "giantcamel", "dustdevil", "giantdustdevil", "scorpion", "giantscorpion",
    "spider", "giantspider", "darkgolem", "giantdarkgolem", "mammoth", "giantmammoth", "minotaur", "giantminotaur", "blackdragonboss",
}

local SelMobs = {["__ALL__"] = false}
for _, id in pairs(ALL_MOBS) do SelMobs[id] = false end

---------- SAVE/LOAD (preserved v4 filename) ----------
local _cfgFileName = "aurora_cfg_skill_point_incremental.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_skill_point_incremental"] end
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
        if saved._skillIdx then _skillIdx = saved._skillIdx end
        if saved._SelMobs and type(saved._SelMobs) == "table" then
            for k, _ in pairs(SelMobs) do SelMobs[k] = nil end
            for k, v in pairs(saved._SelMobs) do SelMobs[k] = v end
        end
    end
end

local function saveCFG()
    local d = {}
    for k, v in pairs(CFG) do d[k] = v end
    d._skillIdx = _skillIdx
    d._SelMobs = SelMobs
    pcall(function() if _HAS.writefile then writefile(_cfgFileName, HttpService:JSONEncode(d)) end end)
    getgenv()["AuroraCFG_skill_point_incremental"] = d
end

loadSavedCFG()
CFG.TargetSkill = SKILLS[_skillIdx] or "strength"

---------- HELPERS (preserved verbatim from v4) ----------
local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e15 then return string.format("%.1fQ", n / 1e15)
    elseif n >= 1e12 then return string.format("%.1fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local function getHRP()
    local c = Player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

---------- STATE (preserved verbatim from v4) ----------
local _sp, _level, _damage = 0, 1, "0"
local S = {kills = 0, attacks = 0, equips = 0, sacrifices = 0, claims = 0, spSpent = 0, session = tick()}
local _target = nil
local _farmStatus = "Idle"

pcall(function()
    local ls = Player:WaitForChild("leaderstats", 5)
    if ls then
        local sp = ls:FindFirstChild("SP Gained")
        if sp then _sp = sp.Value; sp.Changed:Connect(function(v) _sp = v end) end
        local lv = ls:FindFirstChild("Level")
        if lv then _level = lv.Value; lv.Changed:Connect(function(v) _level = v end) end
        local dm = ls:FindFirstChild("Damage")
        if dm then _damage = dm.Value; dm.Changed:Connect(function(v) _damage = v end) end
    end
end)

---------- NPC HELPERS (preserved verbatim from v4) ----------
local function getMatchingNPCs()
    local npcs = workspace:FindFirstChild("SpawnedNPCs")
    if not npcs then return {} end
    local list = {}
    for _, npc in npcs:GetChildren() do
        local guid = npc:GetAttribute("guid")
        local npcId = npc:GetAttribute("npcId")
        if not (not guid or not npcId) then
            if not (not SelMobs["__ALL__"] and not SelMobs[npcId]) then
                if npc:FindFirstChild("HumanoidRootPart") then
                    table.insert(list, npc)
                end
            end
        end
    end
    return list
end

local function getAllNPCs()
    local npcs = workspace:FindFirstChild("SpawnedNPCs")
    if not npcs then return {} end
    local list = {}
    for _, npc in npcs:GetChildren() do
        if npc:GetAttribute("guid") and npc:FindFirstChild("HumanoidRootPart") then
            table.insert(list, npc)
        end
    end
    return list
end

---------- GAME SERVICE HOOKS (getgc exploit — preserved verbatim, Xeno-guarded) ----------
local _atkSvc = nil
local _targetSvc = nil
local VIM = game:GetService("VirtualInputManager")

-- CRITICAL: getgc(true) is the exploit core. Gate on _HAS.getgc so Xeno degrades gracefully.
local function patchRanges()
    pcall(function()
        if not _HAS.getgc then return end
        if not getgc then return end; for _, obj in getgc(true) do
            if typeof(obj) == "table" then
                if rawget(obj, "playerAttackRange") then obj.playerAttackRange = 99999 end
                if rawget(obj, "selfNpcRadius") then obj.selfNpcRadius = 99999 end
                if rawget(obj, "autoAttackEnabled") ~= nil then obj.autoAttackEnabled = true end
            end
        end
    end)
end
patchRanges()

local _needRetarget = false
pcall(function()
    Packets.NPCDeath.OnClientEvent:Connect(function()
        S.kills = S.kills + 1
        _needRetarget = true
    end)
end)

local function attackTarget(npc)
    if not npc or not npc.Parent then return end
    local npcHrp = npc:FindFirstChild("HumanoidRootPart")
    local hrp = getHRP()
    if not hrp or not npcHrp then return end
    hrp.CFrame = npcHrp.CFrame * CFrame.new(0, 0, 3)
    local cam = workspace.CurrentCamera
    if not cam then return end
    local sp = cam:WorldToViewportPoint(npcHrp.Position)
    -- Jitter mouse position slightly so game doesn't deduplicate clicks
    local jx = sp.X + math.random(-3, 3)
    local jy = sp.Y + math.random(-3, 3)
    -- Move mouse to NPC first, then click
    VIM:SendMouseMoveEvent(jx, jy, nil, 0)
    task.wait()
    VIM:SendMouseButtonEvent(jx, jy, 0, true, nil, 0)
    task.wait()
    VIM:SendMouseButtonEvent(jx, jy, 0, false, nil, 0)
    S.attacks = S.attacks + 1
end

---------- AUTO-FARM (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoFarm then
            patchRanges()
            local hrp = getHRP()
            if hrp then

                local matches = getMatchingNPCs()
                if #matches == 0 then
                    _farmStatus = "No NPCs"; _target = nil; task.wait(0.3)
                else
                    table.sort(matches, function(a, b)
                        local aHrp = a:FindFirstChild("HumanoidRootPart")
                        local bHrp = b:FindFirstChild("HumanoidRootPart")
                        if not aHrp then return false end; if not bHrp then return true end
                        local aGiant = (a:GetAttribute("npcId") or ""):sub(1, 5) == "giant"
                        local bGiant = (b:GetAttribute("npcId") or ""):sub(1, 5) == "giant"
                        if aGiant and not bGiant then return true end
                        if bGiant and not aGiant then return false end
                        return (aHrp.Position - hrp.Position).Magnitude < (bHrp.Position - hrp.Position).Magnitude
                    end)

                    for _, npc in ipairs(matches) do
                        if not CFG.AutoFarm then break end
                        if npc.Parent then
                            local npcHrp = npc:FindFirstChild("HumanoidRootPart")
                            if npcHrp then
                                _target = npc.Name
                                _farmStatus = "Killing " .. npc.Name .. " | Kills: " .. S.kills
                                _needRetarget = false
                                patchRanges()
                                local t0 = tick()
                                while CFG.AutoFarm and not _needRetarget and (tick() - t0) < 30 do
                                    if not npc.Parent then S.kills = S.kills + 1; break end
                                    if not npc:FindFirstChild("HumanoidRootPart") then S.kills = S.kills + 1; break end
                                    attackTarget(npc)
                                    task.wait(0.15)
                                end
                            end
                        end
                        task.wait(0.3)
                    end
                    task.wait()
                end
            else
                task.wait(jitter(0.5, 0.5))
            end
        else
            _farmStatus = "Idle"; _target = nil; task.wait(0.5)
        end
    end
end)

---------- FARM LOOPS (preserved verbatim from v4) ----------
task.spawn(function() while alive() do if CFG.AutoEquip then pcall(function() Packets.PlayerEquipBestItems:Fire() end); S.equips = S.equips + 1 end; task.wait(jitter(10, 3.0)) end end)
task.spawn(function() while alive() do if CFG.AutoSacrifice then pcall(function() Packets.PlayerSacrificeAllInventoryItems:Fire() end); S.sacrifices = S.sacrifices + 1 end; task.wait(jitter(15, 4.5)) end end)
task.spawn(function()
    while alive() do
        if CFG.AutoClaim then
            pcall(function() Packets.PlayerClaimDailyReward:Fire() end)
            pcall(function() Packets.PlayerClaimOfflineReward:Fire() end)
            pcall(function() Packets.PlayerClaimForgeBonuses:Fire() end)
            pcall(function() Packets.PlayerClaimJoinGroupReward:Fire() end)
            pcall(function()
                local chests = workspace:FindFirstChild("RewardChests")
                if chests then for _, chest in chests:GetChildren() do local cid = chest:GetAttribute("chestId"); if cid then pcall(function() Packets.PlayerClaimRewardChest:Fire(cid) end) end end end
            end)
            S.claims = S.claims + 1
        end
        task.wait(jitter(30, 9.0))
    end
end)
task.spawn(function() while alive() do if CFG.AutoXP then pcall(function() Packets.RequestXPOrb:Fire() end); pcall(function() Packets.ConfirmXPOrbCollected:Fire() end) end; task.wait(jitter(0.5, 0.5)) end end)

---------- AUTO SPEND SP (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoSP then
            pcall(function()
                local spendTable = {}
                for _, s in pairs(SKILLS) do spendTable[s] = 0 end
                spendTable[CFG.TargetSkill] = 1
                local result = Packets.PlayerSpendSkillPoints:Fire(spendTable)
                if result ~= false then S.spSpent = S.spSpent + 1 end
            end)
        end
        task.wait(0.5)
    end
end)

---------- SPEED / ANTI-AFK (preserved verbatim from v4) ----------
local _sOn = false
task.spawn(function()
    while alive() do
        pcall(function()
            local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if CFG.SpeedBoost then hum.WalkSpeed = 80; _sOn = true
            elseif _sOn then hum.WalkSpeed = 16; _sOn = false end
        end)
        task.wait(0.5)
    end
end)

task.spawn(function()
    while alive() do
        if CFG.AntiAFK then
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController(); vu:ClickButton2(Vector2.new())
            end)
        end
        task.wait(60)
    end
end)

---------- NPC ESP (preserved verbatim from v4) ----------
local _espParts = {}
task.spawn(function()
    while alive() do
        if CFG.NPCESP then
            pcall(function()
                local npcs = getAllNPCs()
                for guid, bb in pairs(_espParts) do if not bb.Parent then _espParts[guid] = nil end end
                for _, npc in pairs(npcs) do
                    local guid = npc:GetAttribute("guid"); local npcHrp = npc:FindFirstChild("HumanoidRootPart")
                    if guid and npcHrp and not _espParts[guid] then
                        local bb = Instance.new("BillboardGui"); bb.Name = "AuroraESP"; bb.Size = UDim2.fromOffset(100, 30)
                        bb.StudsOffset = Vector3.new(0, 4, 0); bb.AlwaysOnTop = true; bb.Adornee = npcHrp
                        local txt = Instance.new("TextLabel"); txt.Size = UDim2.new(1, 0, 1, 0); txt.BackgroundTransparency = 1
                        txt.Text = npc.Name; txt.TextColor3 = Color3.fromRGB(60, 120, 255); txt.TextStrokeTransparency = 0.5
                        txt.Font = Enum.Font.GothamBold; txt.TextSize = 12; txt.Parent = bb; bb.Parent = npcHrp
                        _espParts[guid] = bb
                    end
                end
            end)
        else
            for guid, bb in pairs(_espParts) do pcall(function() bb:Destroy() end) end; _espParts = {}
        end
        task.wait(2)
    end
end)

-- ========================================================================
-- ========================================================================
-- V5 3-COLUMN UI (Sidebar + Panel Alpha + Panel Beta + Live Game + Pill)
-- ========================================================================
-- ========================================================================

--========================================================================
-- PALETTE
--========================================================================
local C = {
    bg       = Color3.fromRGB(8,   8,  15),
    bg2      = Color3.fromRGB(12, 12,  24),
    bg3      = Color3.fromRGB(19, 19,  42),
    panel    = Color3.fromRGB(12, 12,  24),
    border   = Color3.fromRGB(22, 22,  42),
    border2  = Color3.fromRGB(42, 42,  68),
    text     = Color3.fromRGB(245,245, 250),
    text2    = Color3.fromRGB(160,160, 180),
    text3    = Color3.fromRGB(98,  98, 122),
    pink     = Color3.fromRGB(252,110, 142),
    purple   = Color3.fromRGB(192,132, 252),
    green    = Color3.fromRGB(0,  200, 100),
    red      = Color3.fromRGB(255,80,  80),
    white    = Color3.fromRGB(255,255, 255),
}

local F_SANS      = Enum.Font.Gotham
local F_SANS_SEMI = Enum.Font.GothamMedium
local F_SANS_BOLD = Enum.Font.GothamBold
local F_MONO      = Enum.Font.Code

--========================================================================
-- UI HELPERS
--========================================================================
local function create(cls, props, parent)
    local i = Instance.new(cls)
    if props then for k, v in pairs(props) do i[k] = v end end
    if parent then i.Parent = parent end
    return i
end
local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p; return c
end
local function stroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or C.border; s.Thickness = th or 1; s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end
local function grad(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
    g.Rotation = rot or 0; g.Parent = p; return g
end
local function padAll(p, v)
    local pp = Instance.new("UIPadding")
    pp.PaddingTop = UDim.new(0, v); pp.PaddingBottom = UDim.new(0, v)
    pp.PaddingLeft = UDim.new(0, v); pp.PaddingRight = UDim.new(0, v); pp.Parent = p; return pp
end

--========================================================================
-- LAYOUT CONSTANTS
--========================================================================
local TOTAL_W   = 1080
local TOTAL_H   = 620
local SIDEBAR_W = 168
local PA_W      = 350
local PB_W      = 350
local LG_W      = TOTAL_W - SIDEBAR_W - PA_W - PB_W  -- 212

--========================================================================
-- SCREENGUI + PARENT (Xeno-safe: each parent in own pcall)
--========================================================================
local screenGui = create("ScreenGui", {
    Name = "Aurora", DisplayOrder = 9999, ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
local _pOk = false
if _HAS.gethui then _pOk = pcall(function() screenGui.Parent = gethui() end) end
if not _pOk then _pOk = pcall(function() screenGui.Parent = game:GetService("CoreGui") end) end
if not _pOk then pcall(function() screenGui.Parent = Player:WaitForChild("PlayerGui") end) end

local _vp     = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local _mobile = UIS.TouchEnabled and (_vp.X < 1200)
local _scale  = _mobile and math.clamp(_vp.X / 1200, 0.5, 0.85) or 1

--========================================================================
-- MAIN PANEL
--========================================================================
local main = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    ClipsDescendants = true, Visible = CFG.PanelOpen,
}, screenGui)
corner(main, 14)
stroke(main, C.border2, 1, 0)

if _scale ~= 1 then
    local sc = Instance.new("UIScale"); sc.Scale = _scale; sc.Parent = main
end

-- Centered brand watermark (bleeds through transparent panels/scrolls)
local watermark = create("TextLabel", {
    Name = "Watermark",
    Size = UDim2.fromOffset(800, 120),
    Position = UDim2.fromOffset(TOTAL_W / 2, TOTAL_H / 2),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Text = "Aurorahub.net",
    Font = F_SANS_BOLD,
    TextSize = 72,
    TextColor3 = C.pink,
    TextTransparency = 0.82,
    TextStrokeTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 1,
}, main)
watermark.RichText = true
watermark.Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>'

local content = create("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2,
}, main)

--========================================================================
-- SIDEBAR
--========================================================================
local sidebar = create("Frame", {
    Name = "Sidebar", Size = UDim2.fromOffset(SIDEBAR_W, TOTAL_H),
    BackgroundColor3 = C.bg2, BackgroundTransparency = 1,
    BorderSizePixel = 0, ClipsDescendants = true,
}, content)

create("Frame", {
    Size = UDim2.fromOffset(1, TOTAL_H), Position = UDim2.fromOffset(SIDEBAR_W - 1, 0),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, content)

local wordmarkRow = create("Frame", {
    Name = "Wordmark", Size = UDim2.fromOffset(SIDEBAR_W, 54),
    BackgroundTransparency = 1, Active = true,
}, sidebar)

create("ImageLabel", {
    Name = "Logo", Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(14, 15),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181",
    ScaleType = Enum.ScaleType.Fit, ImageColor3 = C.white,
}, wordmarkRow)

local wordmark = create("TextLabel", {
    Size = UDim2.fromOffset(SIDEBAR_W - 44, 24), Position = UDim2.fromOffset(42, 15),
    BackgroundTransparency = 1, Font = F_SANS_BOLD, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    TextColor3 = C.text, Text = "Aurorahub.net",
}, wordmarkRow)
wordmark.RichText = true
wordmark.Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>'

create("Frame", {
    Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, 54),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, sidebar)

--========================================================================
-- TABS
--========================================================================
local TABS = {
    { name = "Farm",    icon = "⚔" },
    { name = "Skills",  icon = "◆" },
    { name = "Visuals", icon = "◉" },
    { name = "Utility", icon = "≡" },
}

local tabMap = {}
local function paintTabs()
    for name, t in pairs(tabMap) do
        local on     = (CFG.ActiveTab == name)
        local offCol = t.dimInactive and C.text3 or C.text2
        t.accent.Visible            = on
        t.bg.BackgroundTransparency = on and 0.85 or 1
        t.label.TextColor3          = on and C.text or offCol
        t.label.Font                = on and F_SANS_SEMI or F_SANS
        t.icon.TextColor3           = on and C.pink or C.text3
    end
end

local TAB_Y0  = 66
local TAB_H   = 34
local TAB_GAP = 3
local function makeTabRow(tinfo, yPos, dimInactive)
    local row = create("Frame", {
        Name = "Tab_" .. tinfo.name, Size = UDim2.fromOffset(SIDEBAR_W - 20, TAB_H),
        Position = UDim2.fromOffset(10, yPos),
        BackgroundColor3 = C.pink, BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = true,
    }, sidebar)
    corner(row, 6)

    local bgGrad = Instance.new("UIGradient")
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.pink),
        ColorSequenceKeypoint.new(1, C.bg2),
    })
    bgGrad.Rotation = 0
    bgGrad.Parent = row

    local accent = create("Frame", {
        Size = UDim2.fromOffset(2, TAB_H - 14), Position = UDim2.fromOffset(0, 7),
        BackgroundColor3 = C.pink, BorderSizePixel = 0, Visible = false,
    }, row)
    corner(accent, 1)

    local icon = create("TextLabel", {
        Size = UDim2.fromOffset(18, TAB_H), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = tinfo.icon,
        Font = F_SANS_BOLD, TextSize = 12, TextColor3 = C.text3,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, row)

    local label = create("TextLabel", {
        Size = UDim2.fromOffset(SIDEBAR_W - 64, TAB_H), Position = UDim2.fromOffset(36, 0),
        BackgroundTransparency = 1, Text = tinfo.name,
        Font = F_SANS, TextSize = 12, TextColor3 = C.text2,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    tabMap[tinfo.name] = {
        bg = row, accent = accent, icon = icon, label = label, dimInactive = dimInactive or false,
    }

    return row
end

-- Forward-declare switchTab / popup helpers
local switchTab        = function(_) end
local _openPopup       = nil
local _skipNextOutside = false
local closeOpenPopup   = function() end

for idx, tinfo in ipairs(TABS) do
    local y = TAB_Y0 + (idx - 1) * (TAB_H + TAB_GAP)
    local row = makeTabRow(tinfo, y, false)
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            switchTab(tinfo.name)
        end
    end)
end

-- Settings tab (pinned at bottom)
local SET_H    = 36
local SET_PAD  = 10
local SET_Y    = TOTAL_H - SET_H - SET_PAD

create("Frame", {
    Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, SET_Y - 6),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, sidebar)

local setRow = makeTabRow({ name = "Settings", icon = "⚙" }, SET_Y, true)
setRow.Size = UDim2.fromOffset(SIDEBAR_W - 20, SET_H)
setRow.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        switchTab("Settings")
    end
end)

--========================================================================
-- PANEL FACTORY
--========================================================================
local panels = {}
local liveScroll

local function makePanel(tabName, which, xPos, width, accent, title)
    local p = create("Frame", {
        Name = tabName .. "_" .. which, Size = UDim2.fromOffset(width, TOTAL_H),
        Position = UDim2.fromOffset(xPos, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
        Visible = (tabName == CFG.ActiveTab),
    }, content)

    if xPos > SIDEBAR_W then
        create("Frame", {
            Size = UDim2.fromOffset(1, TOTAL_H),
            BackgroundColor3 = C.border, BorderSizePixel = 0,
        }, p)
    end

    create("TextLabel", {
        Size = UDim2.fromOffset(width - 32, 36), Position = UDim2.fromOffset(16, 14),
        BackgroundTransparency = 1, Text = title,
        Font = F_MONO, TextSize = 10, TextColor3 = accent,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    }, p)

    create("Frame", {
        Size = UDim2.fromOffset(width, 1), Position = UDim2.fromOffset(0, 48),
        BackgroundColor3 = C.border, BorderSizePixel = 0,
    }, p)

    local scroll = create("ScrollingFrame", {
        Size = UDim2.fromOffset(width, TOTAL_H - 50), Position = UDim2.fromOffset(0, 50),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = accent,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, p)
    padAll(scroll, 14)

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 2); list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = scroll

    panels[tabName] = panels[tabName] or {}
    panels[tabName][which] = { frame = p, scroll = scroll }
    return scroll
end

local TAB_NAMES = { "Farm", "Skills", "Visuals", "Utility", "Settings" }
local TAB_ACCENT = {
    Farm     = C.pink,
    Skills   = C.purple,
    Visuals  = C.pink,
    Utility  = C.purple,
    Settings = C.pink,
}
local PANEL_TITLES = {
    Farm     = { alpha = "AUTO FARM",  beta = "FARM STATUS" },
    Skills   = { alpha = "SKILL SPEND", beta = "SKILL INFO"  },
    Visuals  = { alpha = "ESP",        beta = "VISUAL INFO" },
    Utility  = { alpha = "PLAYER",     beta = "STATS"       },
    Settings = { alpha = "CONFIG",     beta = "ABOUT"       },
}

local scrolls = {}
for _, tn in ipairs(TAB_NAMES) do
    local acc = TAB_ACCENT[tn]
    local t   = PANEL_TITLES[tn]
    scrolls[tn .. "_alpha"] = makePanel(tn, "alpha", SIDEBAR_W,        PA_W, acc, t.alpha)
    scrolls[tn .. "_beta"]  = makePanel(tn, "beta",  SIDEBAR_W + PA_W, PB_W, acc, t.beta)
end

-- Persistent Live Game panel
local liveFrame = create("Frame", {
    Name = "LiveGame", Size = UDim2.fromOffset(LG_W, TOTAL_H),
    Position = UDim2.fromOffset(SIDEBAR_W + PA_W + PB_W, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
}, content)
create("Frame", {
    Size = UDim2.fromOffset(1, TOTAL_H),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, liveFrame)
create("TextLabel", {
    Size = UDim2.fromOffset(LG_W - 32, 36), Position = UDim2.fromOffset(16, 14),
    BackgroundTransparency = 1, Text = "LIVE GAME",
    Font = F_MONO, TextSize = 10, TextColor3 = C.pink,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
}, liveFrame)
create("Frame", {
    Size = UDim2.fromOffset(LG_W, 1), Position = UDim2.fromOffset(0, 48),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, liveFrame)
liveScroll = create("ScrollingFrame", {
    Size = UDim2.fromOffset(LG_W, TOTAL_H - 50), Position = UDim2.fromOffset(0, 50),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 2, ScrollBarImageColor3 = C.pink,
    CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, liveFrame)
padAll(liveScroll, 14)
local _liveList = Instance.new("UIListLayout")
_liveList.Padding = UDim.new(0, 2); _liveList.SortOrder = Enum.SortOrder.LayoutOrder
_liveList.Parent = liveScroll

--========================================================================
-- TAB SWITCHER
--========================================================================
switchTab = function(tabName)
    if not panels[tabName] then tabName = "Farm" end
    CFG.ActiveTab = tabName
    paintTabs()
    for _, tn in ipairs(TAB_NAMES) do
        local pair = panels[tn]
        if pair then
            if pair.alpha then pair.alpha.frame.Visible = (tn == tabName) end
            if pair.beta  then pair.beta.frame.Visible  = (tn == tabName) end
        end
    end
    closeOpenPopup()
    if CFG.AutoSave then saveCFG() end
end

--========================================================================
-- COMPONENT BUILDERS
--========================================================================
local function sectionHeader(parent, icon, label, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = order,
    }, parent)
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 35),
        BackgroundColor3 = C.border, BorderSizePixel = 0,
    }, row)
    local bar = create("Frame", {
        Size = UDim2.fromOffset(3, 12), Position = UDim2.fromOffset(0, 14),
        BackgroundColor3 = C.white, BorderSizePixel = 0,
    }, row)
    corner(bar, 1); grad(bar, C.pink, C.purple, 90)
    create("TextLabel", {
        Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = icon .. "  " .. label,
        Font = F_SANS_BOLD, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    }, row)
    return row
end

local function toggleRow(parent, label, cfgKey, order, cb)
    if CFG[cfgKey] == nil then CFG[cfgKey] = false end
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local track = create("Frame", {
        Size = UDim2.fromOffset(36, 20), Position = UDim2.new(1, -36, 0.5, -10),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(track, 10)
    local trackStroke = stroke(track, C.border2, 1, 0)
    local trackGrad = Instance.new("UIGradient")
    trackGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.pink), ColorSequenceKeypoint.new(1, C.purple),
    })
    trackGrad.Rotation = 0; trackGrad.Enabled = false; trackGrad.Parent = track
    local knob = create("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3,
    }, track)
    corner(knob, 7)
    local function paint()
        local on = CFG[cfgKey] == true
        if on then
            track.BackgroundColor3 = C.white
            trackGrad.Enabled = true; trackStroke.Transparency = 1
        else
            track.BackgroundColor3 = C.bg3
            trackGrad.Enabled = false; trackStroke.Transparency = 0
        end
        TweenService:Create(knob, TweenInfo.new(0.15),
            { Position = UDim2.fromOffset(on and 19 or 3, 3) }):Play()
    end
    paint()
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            CFG[cfgKey] = not CFG[cfgKey]; paint()
            if CFG.AutoSave then saveCFG() end
            if cb then cb(CFG[cfgKey]) end
        end
    end)
    return row, paint
end

closeOpenPopup = function()
    if _openPopup and _openPopup.frame then
        _openPopup.frame.Visible = false
        if _openPopup.onClose then _openPopup.onClose() end
    end
    _openPopup = nil
end

local function actionBtn(parent, label, color, order, cb)
    local btn = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = color or C.bg3,
        BorderSizePixel = 0, LayoutOrder = order, Active = true,
    }, parent)
    corner(btn, 6); stroke(btn, C.border2, 1, 0)
    local lbl = create("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_BOLD, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, btn)
    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            if cb then pcall(cb) end
            local orig = lbl.Text; lbl.Text = label .. " ..."
            lbl.TextColor3 = C.green
            task.delay(1.2, function()
                if lbl.Parent then lbl.Text = orig; lbl.TextColor3 = C.text end
            end)
        end
    end)
    return btn
end

local function infoRow(parent, label, initialVal, valColor, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order,
    }, parent)
    create("TextLabel", {
        Size = UDim2.fromScale(0.55, 1), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local val = create("TextLabel", {
        Size = UDim2.fromScale(0.45, 1), Position = UDim2.fromScale(0.55, 0),
        BackgroundTransparency = 1, Text = tostring(initialVal or "—"),
        Font = F_MONO, TextSize = 10, TextColor3 = valColor or C.text2,
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    return val
end

-- Skill cycle selector (preserves v4 _skillIdx/TargetSkill semantics)
local function skillCycleRow(parent, order, onChange)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Text = "Target Skill",
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local pill = create("Frame", {
        Size = UDim2.fromOffset(150, 22), Position = UDim2.new(1, -150, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)
    local skillLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = CFG.TargetSkill,
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)
    create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▶",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            _skillIdx = (_skillIdx % #SKILLS) + 1
            CFG.TargetSkill = SKILLS[_skillIdx]
            skillLabel.Text = CFG.TargetSkill
            if CFG.AutoSave then saveCFG() end
            if onChange then onChange() end
        end
    end)
    return row, skillLabel
end

-- Multi-select dropdown with popup (mob filter)
local function dropdownMapRow(parent, label, options, labelMap, setMap, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
        LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(1, -140, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local pill = create("Frame", {
        Size = UDim2.fromOffset(130, 22), Position = UDim2.new(1, -130, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)

    local function displayText()
        if setMap["__ALL__"] then return "ALL (" .. #options .. ")" end
        local count, firstKey = 0, nil
        for _, nm in ipairs(options) do
            if setMap[nm] then count = count + 1; if not firstKey then firstKey = nm end end
        end
        if count == 0 then return "None" end
        if count == 1 then return labelMap and labelMap[firstKey] or tostring(firstKey) end
        return count .. "/" .. #options
    end

    local valLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = displayText(),
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)

    local arrow = create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▼",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)

    local POPUP_W  = 220
    local OPT_H    = 24
    local POPUP_H  = math.min(300, (#options + 1) * (OPT_H + 2) + 8)

    local popup = create("Frame", {
        Name = "DDMapPopup_" .. label,
        Size = UDim2.fromOffset(POPUP_W, POPUP_H),
        BackgroundColor3 = C.bg, BorderSizePixel = 0,
        Visible = false, ZIndex = 50,
    }, screenGui)
    corner(popup, 8); stroke(popup, C.border2, 1, 0)

    local popScroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = C.pink,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 51,
    }, popup)
    padAll(popScroll, 4)
    local popList = Instance.new("UIListLayout")
    popList.Padding = UDim.new(0, 2); popList.SortOrder = Enum.SortOrder.LayoutOrder
    popList.Parent = popScroll

    local optBtns = {}
    local function isSelected(opt) return setMap[opt] == true end

    -- ALL row first
    local allBtn = create("Frame", {
        Name = "Opt_ALL",
        Size = UDim2.new(1, 0, 0, OPT_H),
        BackgroundColor3 = C.bg3, BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = true,
        LayoutOrder = 0, ZIndex = 52,
    }, popScroll)
    corner(allBtn, 4)
    local allCheck = create("Frame", {
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new(0, 6, 0.5, -6),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0, ZIndex = 53,
    }, allBtn)
    corner(allCheck, 2)
    stroke(allCheck, C.border2, 1, 0)
    local allFill = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.green, BorderSizePixel = 0,
        Visible = false, ZIndex = 54,
    }, allCheck)
    corner(allFill, 2)
    create("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(26, 0),
        BackgroundTransparency = 1, Text = "ALL MOBS",
        Font = F_SANS_BOLD, TextSize = 11, TextColor3 = C.green,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
    }, allBtn)

    for i, opt in ipairs(options) do
        local btn = create("Frame", {
            Name = "Opt_" .. tostring(opt),
            Size = UDim2.new(1, 0, 0, OPT_H),
            BackgroundColor3 = C.bg3, BackgroundTransparency = 1,
            BorderSizePixel = 0, Active = true,
            LayoutOrder = i, ZIndex = 52,
        }, popScroll)
        corner(btn, 4)

        local check = create("Frame", {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.new(0, 6, 0.5, -6),
            BackgroundColor3 = C.bg3, BorderSizePixel = 0, ZIndex = 53,
        }, btn)
        corner(check, 2)
        stroke(check, C.border2, 1, 0)
        local fill = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = C.pink, BorderSizePixel = 0,
            Visible = false, ZIndex = 54,
        }, check)
        corner(fill, 2)

        create("TextLabel", {
            Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(26, 0),
            BackgroundTransparency = 1, Text = labelMap and labelMap[opt] or tostring(opt),
            Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
        }, btn)

        optBtns[i] = { frame = btn, fill = fill, opt = opt }
    end

    local function paintOpts()
        allFill.Visible = setMap["__ALL__"] == true
        allBtn.BackgroundTransparency = setMap["__ALL__"] and 0.85 or 1
        for _, o in ipairs(optBtns) do
            local sel = isSelected(o.opt)
            o.fill.Visible = sel
            o.frame.BackgroundTransparency = sel and 0.85 or 1
        end
    end
    paintOpts()

    allBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            setMap["__ALL__"] = not setMap["__ALL__"]
            paintOpts()
            valLabel.Text = displayText()
            if CFG.AutoSave then saveCFG() end
        end
    end)

    for _, o in ipairs(optBtns) do
        o.frame.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                if setMap[o.opt] then setMap[o.opt] = nil
                else setMap[o.opt] = true end
                paintOpts()
                valLabel.Text = displayText()
                if CFG.AutoSave then saveCFG() end
            end
        end)
    end

    local function openPopup()
        if _openPopup and _openPopup.frame ~= popup then closeOpenPopup() end
        local pp = pill.AbsolutePosition
        local ps = pill.AbsoluteSize
        popup.Position = UDim2.fromOffset(
            pp.X + ps.X - POPUP_W,
            pp.Y + ps.Y + 4
        )
        popup.Visible = true
        arrow.Text = "▲"
        paintOpts()
        _openPopup = {
            frame = popup,
            onClose = function() arrow.Text = "▼" end,
        }
        _skipNextOutside = true
    end

    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            if _openPopup and _openPopup.frame == popup then
                closeOpenPopup()
            else
                openPopup()
            end
        end
    end)

    return row, function() valLabel.Text = displayText(); paintOpts() end
end

--========================================================================
-- POPULATE: FARM
--========================================================================
local oF_a, oF_b = 0, 0
local function nFa() oF_a = oF_a + 1; return oF_a end
local function nFb() oF_b = oF_b + 1; return oF_b end

sectionHeader(scrolls["Farm_alpha"], "⚔", "Auto Farm", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Farm",          "AutoFarm",     nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Equip Best",    "AutoEquip",    nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Sacrifice",     "AutoSacrifice", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Claim Rewards", "AutoClaim",    nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto XP Orbs",       "AutoXP",       nFa())

sectionHeader(scrolls["Farm_alpha"], "◉", "Mob Filter", nFa())
local _mobDD, _mobRefresh = dropdownMapRow(scrolls["Farm_alpha"], "Targets", ALL_MOBS, NPC_LABELS, SelMobs, nFa())

sectionHeader(scrolls["Farm_alpha"], "✦", "Notes", nFa())
local _farmNotes = "Auto Farm teleports to nearest selected\nmob and uses VIM click + getgc range\npatch exploit.\n\nGiants are prioritized over regular mobs."
if not _HAS.getgc then
    _farmNotes = _farmNotes .. "\n\n[!] Xeno detected — getgc(true) missing.\nRange patches won't apply. Attacks\nmay miss at distance."
end
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 120), BackgroundTransparency = 1,
    Text = _farmNotes,
    Font = F_SANS, TextSize = 11, TextColor3 = _HAS.getgc and C.text3 or C.red,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nFa(),
}, scrolls["Farm_alpha"])

sectionHeader(scrolls["Farm_beta"], "●", "Target", nFb())
local _infoTarget    = infoRow(scrolls["Farm_beta"], "Target",  "None", C.text, nFb())
local _infoStatus    = infoRow(scrolls["Farm_beta"], "Status",  "Idle", C.pink, nFb())

sectionHeader(scrolls["Farm_beta"], "◉", "Session Totals", nFb())
local _infoKills     = infoRow(scrolls["Farm_beta"], "Kills",      "0", C.pink, nFb())
local _infoAttacks   = infoRow(scrolls["Farm_beta"], "Attacks",    "0", C.pink, nFb())
local _infoEquips    = infoRow(scrolls["Farm_beta"], "Equips",     "0", C.pink, nFb())
local _infoSacrifices= infoRow(scrolls["Farm_beta"], "Sacrifices", "0", C.pink, nFb())
local _infoClaims    = infoRow(scrolls["Farm_beta"], "Claims",     "0", C.pink, nFb())

sectionHeader(scrolls["Farm_beta"], "✦", "Session", nFb())
local _infoRuntime   = infoRow(scrolls["Farm_beta"], "Runtime", "0m", C.text2, nFb())
local _infoLevel     = infoRow(scrolls["Farm_beta"], "Level",   "---", C.text,  nFb())
local _infoSP        = infoRow(scrolls["Farm_beta"], "SP Gained", "---", C.text, nFb())
local _infoDamage    = infoRow(scrolls["Farm_beta"], "Damage",  "---", C.text,  nFb())

--========================================================================
-- POPULATE: SKILLS
--========================================================================
local oK_a, oK_b = 0, 0
local function nKa() oK_a = oK_a + 1; return oK_a end
local function nKb() oK_b = oK_b + 1; return oK_b end

sectionHeader(scrolls["Skills_alpha"], "◆", "Auto Spend", nKa())
toggleRow    (scrolls["Skills_alpha"], "Auto SP Spend", "AutoSP", nKa())

sectionHeader(scrolls["Skills_alpha"], "●", "Target Skill", nKa())
local _skillRow, _skillLabel = skillCycleRow(scrolls["Skills_alpha"], nKa(), nil)

sectionHeader(scrolls["Skills_alpha"], "✦", "Notes", nKa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1,
    Text = "Auto SP fires PlayerSpendSkillPoints\nevery 0.5s with 1 point into the\nselected skill.\n\nClick the pill to cycle skills.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nKa(),
}, scrolls["Skills_alpha"])

sectionHeader(scrolls["Skills_beta"], "●", "Spend Stats", nKb())
local _infoSPSpent    = infoRow(scrolls["Skills_beta"], "SP Spent", "0", C.pink, nKb())
local _infoTargetSkill= infoRow(scrolls["Skills_beta"], "Target",   CFG.TargetSkill, C.pink, nKb())

sectionHeader(scrolls["Skills_beta"], "◆", "All Skills", nKb())
for _, sk in ipairs(SKILLS) do
    local cap = sk:sub(1,1):upper() .. sk:sub(2)
    infoRow(scrolls["Skills_beta"], cap, "---", C.text2, nKb())
end

sectionHeader(scrolls["Skills_beta"], "✦", "Tips", nKb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Skill values sync from leaderstats.\nAdjust Target to funnel SP into one\nstat at a time.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nKb(),
}, scrolls["Skills_beta"])

--========================================================================
-- POPULATE: VISUALS
--========================================================================
local oV_a, oV_b = 0, 0
local function nVa() oV_a = oV_a + 1; return oV_a end
local function nVb() oV_b = oV_b + 1; return oV_b end

sectionHeader(scrolls["Visuals_alpha"], "◉", "ESP", nVa())
toggleRow    (scrolls["Visuals_alpha"], "NPC ESP", "NPCESP", nVa())

sectionHeader(scrolls["Visuals_alpha"], "✦", "Notes", nVa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Billboard labels appear above every\nNPC in SpawnedNPCs. Color is blue\n(60, 120, 255). Updates every 2s.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nVa(),
}, scrolls["Visuals_alpha"])

sectionHeader(scrolls["Visuals_beta"], "●", "ESP Info", nVb())
infoRow(scrolls["Visuals_beta"], "Type",   "Billboard",           C.text2, nVb())
infoRow(scrolls["Visuals_beta"], "Source", "SpawnedNPCs",         C.text2, nVb())
infoRow(scrolls["Visuals_beta"], "Color",  "60, 120, 255",        C.text2, nVb())
infoRow(scrolls["Visuals_beta"], "Refresh", "2s",                 C.text2, nVb())

sectionHeader(scrolls["Visuals_beta"], "◉", "Active", nVb())
local _infoEspActive = infoRow(scrolls["Visuals_beta"], "Tracked", "0", C.pink, nVb())

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "●", "Player", nUa())
toggleRow    (scrolls["Utility_alpha"], "Speed Boost", "SpeedBoost", nUa())

sectionHeader(scrolls["Utility_alpha"], "◉", "Safety", nUa())
toggleRow    (scrolls["Utility_alpha"], "Anti-AFK", "AntiAFK", nUa())

sectionHeader(scrolls["Utility_alpha"], "✦", "Notes", nUa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1,
    Text = "Speed Boost sets WalkSpeed = 80\n(default is 16).\n\nAnti-AFK uses VirtualUser controller\nclick every 60s.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUa(),
}, scrolls["Utility_alpha"])

sectionHeader(scrolls["Utility_beta"], "●", "Player Stats", nUb())
local _infoHealth = infoRow(scrolls["Utility_beta"], "Health",     "---", C.text,  nUb())
local _infoSpeed  = infoRow(scrolls["Utility_beta"], "Walk Speed", "16",  C.text,  nUb())

sectionHeader(scrolls["Utility_beta"], "◆", "Exploit Status", nUb())
infoRow(scrolls["Utility_beta"], "getgc",     _HAS.getgc and "Available"  or "Missing",   _HAS.getgc and C.green or C.red, nUb())
infoRow(scrolls["Utility_beta"], "writefile", _HAS.writefile and "Available" or "Missing", _HAS.writefile and C.green or C.red, nUb())
infoRow(scrolls["Utility_beta"], "gethui",    _HAS.gethui and "Available"    or "Missing", _HAS.gethui and C.green or C.red, nUb())
infoRow(scrolls["Utility_beta"], "firepp",    _HAS.firepp and "Available"    or "Missing", _HAS.firepp and C.green or C.red, nUb())

sectionHeader(scrolls["Utility_beta"], "✦", "Compat", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Xeno lacks getgc(true) — range patches\nand autoAttackEnabled flag won't\napply. Auto Farm still works via VIM\nclicks but from closer distance.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUb(),
}, scrolls["Utility_beta"])

--========================================================================
-- POPULATE: SETTINGS
--========================================================================
local oS_a, oS_b = 0, 0
local function nSa() oS_a = oS_a + 1; return oS_a end
local function nSb() oS_b = oS_b + 1; return oS_b end

sectionHeader(scrolls["Settings_alpha"], "●", "Config", nSa())
toggleRow    (scrolls["Settings_alpha"], "Auto Save", "AutoSave", nSa())
actionBtn    (scrolls["Settings_alpha"], "Save Config Now", C.green, nSa(), function() saveCFG() end)
actionBtn    (scrolls["Settings_alpha"], "Load Config",     C.bg3,   nSa(), function() loadSavedCFG() end)
actionBtn    (scrolls["Settings_alpha"], "Reset Config",    C.red,   nSa(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    CFG.TargetSkill = "strength"; _skillIdx = 1
    CFG.AutoSave = true
    for k, _ in pairs(SelMobs) do SelMobs[k] = false end
    if _skillLabel then _skillLabel.Text = CFG.TargetSkill end
    if _mobRefresh then _mobRefresh() end
    saveCFG()
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSa())
actionBtn    (scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn    (scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.3)
    getgenv().__AURORA_SPI_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "+1 Skill Point Incremental", C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),       C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion),  C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",        C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v5",                         C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,                 C.text3, nSb())
infoRow(scrolls["Settings_beta"], "Network", "rajden28_packet",            C.text3, nSb())

sectionHeader(scrolls["Settings_beta"], "◆", "Active Features", nSb())
local _cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 200),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nSb(),
}, scrolls["Settings_beta"])

--========================================================================
-- POPULATE: LIVE GAME (persistent)
--========================================================================
local oL = 0
local function nL() oL = oL + 1; return oL end

sectionHeader(liveScroll, "◉", "Session", nL())
local _liveRuntime = infoRow(liveScroll, "Runtime", "0m",   C.text2, nL())
local _liveStatus  = infoRow(liveScroll, "Status",  "Idle", C.pink,  nL())

sectionHeader(liveScroll, "●", "Player", nL())
local _liveHealth  = infoRow(liveScroll, "Health", "---", C.text,  nL())
local _liveSpeed   = infoRow(liveScroll, "Speed",  "16",  C.text,  nL())
local _liveLevel   = infoRow(liveScroll, "Level",  "---", C.text,  nL())

sectionHeader(liveScroll, "◆", "Progress", nL())
local _liveSP      = infoRow(liveScroll, "SP Gained", "---", C.pink, nL())
local _liveDamage  = infoRow(liveScroll, "Damage",    "---", C.pink, nL())
local _liveSkill   = infoRow(liveScroll, "Target",    CFG.TargetSkill, C.purple, nL())

sectionHeader(liveScroll, "⚔", "Combat", nL())
local _liveTarget  = infoRow(liveScroll, "Target", "None", C.text,  nL())
local _liveKills   = infoRow(liveScroll, "Kills",  "0",    C.pink,  nL())
local _liveAtks    = infoRow(liveScroll, "Attacks", "0",   C.pink,  nL())

sectionHeader(liveScroll, "✦", "Actions", nL())
local _liveEquips  = infoRow(liveScroll, "Equips",     "0", C.pink, nL())
local _liveSacs    = infoRow(liveScroll, "Sacrifices", "0", C.pink, nL())
local _liveClaims  = infoRow(liveScroll, "Claims",     "0", C.pink, nL())
local _liveSpSpent = infoRow(liveScroll, "SP Spent",   "0", C.pink, nL())

--========================================================================
-- FLOATING PILL
--========================================================================
local pillGui = create("ScreenGui", {
    Name = "AuroraPill", DisplayOrder = 9998, ResetOnSpawn = false, IgnoreGuiInset = true,
})
local _pillOk = false
if _HAS.gethui then _pillOk = pcall(function() pillGui.Parent = gethui() end) end
if not _pillOk then _pillOk = pcall(function() pillGui.Parent = game:GetService("CoreGui") end) end
if not _pillOk then pcall(function() pillGui.Parent = Player:WaitForChild("PlayerGui") end) end

local pill = create("Frame", {
    Name = "Pill", Size = UDim2.fromOffset(152, 36),
    Position = UDim2.new(1, -172, 0, 22),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.15,
    BorderSizePixel = 0, Active = true,
}, pillGui)
corner(pill, 18); stroke(pill, C.border2, 1, 0)

-- Outer glow halo (behind the dot)
local pillDotGlow = create("Frame", {
    Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(9, 9),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.78,
    BorderSizePixel = 0, ZIndex = 1,
}, pill)
corner(pillDotGlow, 9)

-- Inner glow ring (middle layer)
local pillDotGlowInner = create("Frame", {
    Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(12, 12),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.55,
    BorderSizePixel = 0, ZIndex = 2,
}, pill)
corner(pillDotGlowInner, 6)

-- Solid dot on top
local pillDot = create("Frame", {
    Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(14, 14),
    BackgroundColor3 = C.green, BorderSizePixel = 0, ZIndex = 3,
}, pill)
corner(pillDot, 4)

-- Breathing pulse
task.spawn(function()
    local outerTween = TweenService:Create(
        pillDotGlow,
        TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.55, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(7, 7) }
    )
    local innerTween = TweenService:Create(
        pillDotGlowInner,
        TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.35 }
    )
    outerTween:Play()
    innerTween:Play()
end)

create("TextLabel", {
    Size = UDim2.fromOffset(50, 36), Position = UDim2.fromOffset(28, 0),
    BackgroundTransparency = 1, Text = "Aurora",
    Font = F_SANS_BOLD, TextSize = 12, TextColor3 = C.pink,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pill)
create("TextLabel", {
    Size = UDim2.fromOffset(10, 36), Position = UDim2.fromOffset(80, 0),
    BackgroundTransparency = 1, Text = "·",
    Font = F_SANS_BOLD, TextSize = 14, TextColor3 = C.text3,
}, pill)
local _pillActive = create("TextLabel", {
    Size = UDim2.fromOffset(56, 36), Position = UDim2.fromOffset(92, 0),
    BackgroundTransparency = 1, Text = "0 active",
    Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pill)

pill.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        CFG.PanelOpen = not CFG.PanelOpen
        main.Visible = CFG.PanelOpen
    end
end)

--========================================================================
-- DRAG (unified — wordmark row + full-width top strip)
--========================================================================
local topDragStrip = create("Frame", {
    Name = "TopDragStrip",
    Size = UDim2.fromOffset(TOTAL_W - SIDEBAR_W, 48),
    Position = UDim2.fromOffset(SIDEBAR_W, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 3,
}, content)

local _drag = { active = false, start = nil, startPos = nil }
local function attachDrag(handle)
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            _drag.active   = true
            _drag.start    = inp.Position
            _drag.startPos = main.Position
            closeOpenPopup()
        end
    end)
end
attachDrag(wordmarkRow)
attachDrag(topDragStrip)

UIS.InputChanged:Connect(function(inp)
    if not alive() then return end
    if _drag.active and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - _drag.start
        main.Position = UDim2.new(
            _drag.startPos.X.Scale, _drag.startPos.X.Offset + d.X,
            _drag.startPos.Y.Scale, _drag.startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        _drag.active = false
    end
end)

-- Global outside-click handler for popups
UIS.InputBegan:Connect(function(inp, processed)
    if not alive() then return end
    if _skipNextOutside then _skipNextOutside = false; return end
    if _openPopup and (inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch) then
        local popup = _openPopup.frame
        local p0, ps = popup.AbsolutePosition, popup.AbsoluteSize
        local cx, cy = inp.Position.X, inp.Position.Y
        local inside = cx >= p0.X and cx <= p0.X + ps.X
                   and cy >= p0.Y and cy <= p0.Y + ps.Y
        if not inside then closeOpenPopup() end
    end
end)

--========================================================================
-- CLOSE + MINIMIZE BUTTONS (top-right)
--========================================================================
local minBtn = create("Frame", {
    Name = "Minimize",
    Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 62, 13),
    BackgroundColor3 = C.bg3,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 5,
}, content)
corner(minBtn, 11)
stroke(minBtn, C.border2, 1, 0)

local minLine = create("Frame", {
    Size = UDim2.fromOffset(10, 2),
    Position = UDim2.new(0.5, -5, 0.5, -1),
    BackgroundColor3 = C.text2,
    BorderSizePixel = 0,
    ZIndex = 6,
}, minBtn)
corner(minLine, 1)

minBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        minBtn.BackgroundColor3 = C.pink
        minLine.BackgroundColor3 = C.white
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        CFG.PanelOpen = false
        main.Visible = false
        closeOpenPopup()
    end
end)
minBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        minBtn.BackgroundColor3 = C.bg3
        minLine.BackgroundColor3 = C.text2
    end
end)

local closeBtn = create("Frame", {
    Name = "Close",
    Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 32, 13),
    BackgroundColor3 = C.bg3,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 5,
}, content)
corner(closeBtn, 11)
stroke(closeBtn, C.border2, 1, 0)

local closeX = create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "×",
    Font = F_SANS_BOLD,
    TextSize = 16,
    TextColor3 = C.text2,
    ZIndex = 6,
}, closeBtn)

closeBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.red
        closeX.TextColor3 = C.white
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        getgenv().__AURORA_SPI_SESSION = 0
        task.wait(0.05)
        pcall(function() screenGui:Destroy() end)
        pcall(function() pillGui:Destroy() end)
    end
end)
closeBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.bg3
        closeX.TextColor3 = C.text2
    end
end)

--========================================================================
-- STATUS UPDATE LOOP
--========================================================================
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.3))
        if not alive() then break end
        pcall(function()
            -- Player stats
            local hpTxt, spTxt = "---", "16"
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hpTxt = string.format("%.0f/%.0f", hum.Health, hum.MaxHealth)
                    spTxt = tostring(math.floor(hum.WalkSpeed))
                end
            end

            -- Runtime
            local elapsed = tick() - S.session
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Status mode
            local mode = _farmStatus
            if mode == "Idle" then
                if CFG.AutoFarm then mode = "Farming"
                elseif CFG.AutoSP then mode = "Spending SP"
                elseif CFG.AutoClaim then mode = "Claiming"
                elseif CFG.AutoEquip then mode = "Equipping"
                elseif CFG.AutoSacrifice then mode = "Sacrificing" end
            end

            local targetTxt = _target or "None"
            local killsTxt  = tostring(S.kills)
            local atksTxt   = tostring(S.attacks)
            local equipsTxt = tostring(S.equips)
            local sacsTxt   = tostring(S.sacrifices)
            local claimsTxt = tostring(S.claims)
            local spSpentTxt = tostring(S.spSpent)
            local levelTxt  = tostring(_level)
            local spTxtFmt  = fmt(_sp)
            local damageTxt = tostring(_damage)
            local skillTxt  = CFG.TargetSkill

            -- Farm tab
            _infoTarget.Text      = targetTxt
            _infoStatus.Text      = mode
            _infoKills.Text       = killsTxt
            _infoAttacks.Text     = atksTxt
            _infoEquips.Text      = equipsTxt
            _infoSacrifices.Text  = sacsTxt
            _infoClaims.Text      = claimsTxt
            _infoRuntime.Text     = rtime
            _infoLevel.Text       = levelTxt
            _infoSP.Text          = spTxtFmt
            _infoDamage.Text      = damageTxt

            -- Skills tab
            _infoSPSpent.Text     = spSpentTxt
            _infoTargetSkill.Text = skillTxt

            -- Visuals tab — ESP tracked count
            local espCount = 0
            for _, _ in pairs(_espParts) do espCount = espCount + 1 end
            _infoEspActive.Text   = tostring(espCount)

            -- Utility tab
            _infoHealth.Text      = hpTxt
            _infoSpeed.Text       = spTxt

            -- Live Game
            _liveRuntime.Text     = rtime
            _liveStatus.Text      = mode
            _liveHealth.Text      = hpTxt
            _liveSpeed.Text       = spTxt
            _liveLevel.Text       = levelTxt
            _liveSP.Text          = spTxtFmt
            _liveDamage.Text      = damageTxt
            _liveSkill.Text       = skillTxt
            _liveTarget.Text      = targetTxt
            _liveKills.Text       = killsTxt
            _liveAtks.Text        = atksTxt
            _liveEquips.Text      = equipsTxt
            _liveSacs.Text        = sacsTxt
            _liveClaims.Text      = claimsTxt
            _liveSpSpent.Text     = spSpentTxt

            -- Active features list + pill counter
            local active = {}
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" then
                    table.insert(active, "· " .. k)
                end
            end
            table.sort(active)
            _cfgActiveLabel.Text = #active > 0 and table.concat(active, "\n") or "None"
            _pillActive.Text = #active .. " active"
        end)
    end
end)

--========================================================================
-- INIT
--========================================================================
switchTab(CFG.ActiveTab or "Farm")

print("[Aurora v5] +1 Skill Point Incremental RPG loaded")
