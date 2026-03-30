-- +1 Skill Point Legends Auto-Farm
-- Aurora v2 UI | by notCitruss | +1 SPL v2
-- Tank Pink theme | Frame-based inputs (anti-cheat safe)
-- All interactive elements use Active=true + InputBegan (NO TextButtons)
-- All sizing uses UDim2.fromOffset (NO Scale-based sizes)

local Players         = game:GetService("Players")
local RS              = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser     = game:GetService("VirtualUser")

local Player    = Players.LocalPlayer
local Mouse     = Player:GetMouse()

local Interactions = require(RS.Source.Packets.Interactions)
local fusion       = require(RS.Packages.fusion)
local Values       = require(RS.Source.Utils.Values)
local fus          = fusion

-- ─── CONFIG ──────────────────────────────────────────────────────────────────

local CFG = {
    AutoFarm      = false,
    TeleportToNPC = false,
    AntiAFK       = false,
    AutoDaily     = false,
    AutoStat      = false,
    Noclip        = false,
    AutoHeal      = false,
    AutoChest     = false,
    AutoPotion    = false,
    AttackSpeed   = 0.3,
    TargetMobs    = {},
    StatTarget    = "Physical Damage",
}

-- ─── CONSTANTS ────────────────────────────────────────────────────────────────

local PINK       = Color3.fromRGB(252, 110, 142)
local WHITE      = Color3.fromRGB(245, 245, 248)
local PANEL_BG   = Color3.fromRGB(255, 255, 255)
local SECTION_BG = Color3.fromRGB(240, 240, 246)
local TEXT_DARK  = Color3.fromRGB(22, 22, 28)
local TEXT_MID   = Color3.fromRGB(105, 105, 118)
local BORDER     = Color3.fromRGB(218, 218, 228)
local GREEN      = Color3.fromRGB(72, 199, 116)
local OFF_GRAY   = Color3.fromRGB(178, 178, 190)

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
    Snail              = Vector3.new(502, 8, 539),
    Pig                = Vector3.new(767, 5, 220),
    Turtle             = Vector3.new(897, 4, -101),
    Caveman            = Vector3.new(497, 5, -449),
    Spider             = Vector3.new(911, 5, 609),
    Mammoth            = Vector3.new(1244, 6, 301),
    Chief              = Vector3.new(350, 8, 490),
    Dino               = Vector3.new(1294, 6, 642),
    Arachinex          = Vector3.new(1386, 6, -51),
    Ashgor             = Vector3.new(1100, 6, 300),
    Viperbloom         = Vector3.new(885, 6, -468),
    Warlock            = Vector3.new(1972, 14, -710),
    Spartan            = Vector3.new(2097, 191, -665),
    Grimroot           = Vector3.new(1277, 18, -611),
    Leonidas           = Vector3.new(2750, 83, -660),
    Reaper             = Vector3.new(889, 384, -1611),
    Angel              = Vector3.new(525, 384, -1891),
    ["Lightning God"]  = Vector3.new(616, 407, -2165),
    Cowboy             = Vector3.new(782, 40, -3365),
    Ghost              = Vector3.new(278, 40, -3169),
    ["Totem Sentinel"] = Vector3.new(380, 40, -3476),
    Mummy              = Vector3.new(684, 40, -3789),
    ["Sand Golem"]     = Vector3.new(600, 40, -3600),
    ["Hydra Worm"]     = Vector3.new(603, 40, -3465),
    Dragon             = Vector3.new(649, 320, -3575),
    Blightleap         = Vector3.new(1320, -433, -3057),
    Bonepicker         = Vector3.new(1320, -433, -3200),
    Oculon             = Vector3.new(1400, -433, -3100),
    Magmaton           = Vector3.new(1200, -433, -3300),
    Simba              = Vector3.new(1320, -433, -3400),
    Nevermore          = Vector3.new(1500, -433, -3100),
    Anubis             = Vector3.new(1320, -433, -3500),
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

local _running   = false
local _stopFlag  = false
local _thread    = nil
local _kills     = 0
local _spGained  = 0
local _spStart   = 0
local _lastNPC   = "None"

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
    local mod = RS.Source.Weapons:FindFirstChild(weaponName) or RS.Source.Weapons:FindFirstChild("Punch")
    if mod then
        local ok, result = pcall(require, mod)
        return ok and result or nil, weaponName
    end
    return nil, weaponName
end

local function getNpcName(npc): string
    for _, desc in npc:GetDescendants() do
        if desc:IsA("TextLabel") and desc.Text ~= "" and not desc.Text:find("/") then
            return desc.Text
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
        if npc:IsA("Model") and not npc:GetAttribute("Dead") then
            local npcHrp = npc:FindFirstChild("HumanoidRootPart")
            if npcHrp then
                if hasFilter then
                    local name = getNpcName(npc)
                    local matched = false
                    if name then
                        for mob, _ in pairs(CFG.TargetMobs) do
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
local TP_COOLDOWN = 1.5 -- seconds between teleports to avoid anti-cheat kicks

local function tpToNPC(npc)
    if not npc then return end
    if tick() - _lastTP < TP_COOLDOWN then return end
    local hrp  = getHRP()
    local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Root")
    if hrp and root then
        hrp.CFrame = root.CFrame + Vector3.new(4, 0, 0)
        _lastTP = tick()
    end
end

local function teleportToMobArea(mobName: string)
    if tick() - _lastTP < TP_COOLDOWN then task.wait(TP_COOLDOWN) end
    if NPC_SPAWN_POS[mobName] then
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(NPC_SPAWN_POS[mobName])
            _lastTP = tick()
            return
        end
    end
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
    _running  = true
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
                if not hrp then task.wait(2) return end
                local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then task.wait(2) return end

                if CFG.AutoDaily and tick() - lastDaily > 60 then
                    pcall(function() Interactions.claimDailyReward.send() end)
                    pcall(function() Interactions.claimLikeReward.send() end)
                    lastDaily = tick()
                end

                local npc, dist, npcName = findNearestNPC()

                -- No target: cycle through selected mobs and TP to their areas
                if not npc and CFG.TeleportToNPC and next(CFG.TargetMobs) then
                    -- First check all loaded NPCs
                    local npcsFolder = workspace:FindFirstChild("Npcs")
                    if npcsFolder then
                        for _, n in npcsFolder:GetChildren() do
                            if n:IsA("Model") and not n:GetAttribute("Dead") then
                                local nHrp = n:FindFirstChild("HumanoidRootPart")
                                if nHrp then
                                    local nm = getNpcName(n)
                                    if nm then
                                        for mob, _ in pairs(CFG.TargetMobs) do
                                            if nm == mob or nm:find(mob) then
                                                if tick() - _lastTP >= TP_COOLDOWN then
                                                    hrp.CFrame = CFrame.new(nHrp.Position + Vector3.new(0, 3, -4), nHrp.Position)
                                                    _lastTP = tick()
                                                end
                                                task.wait(1)
                                                npc = n; npcName = nm
                                                break
                                            end
                                        end
                                    end
                                    if npc then break end
                                end
                            end
                        end
                    end
                    -- Still no NPC: cycle through each selected mob and TP to spawn area
                    if not npc then
                        for mob, _ in pairs(CFG.TargetMobs) do
                            if _stopFlag then break end
                            _lastNPC = "Searching " .. mob .. "..."
                            teleportToMobArea(mob)
                            task.wait(3) -- longer wait to avoid anti-cheat detection
                            if _stopFlag then break end
                            npc, dist, npcName = findNearestNPC()
                            if npc then break end
                        end
                    end
                end

                if not npc then return end
                _lastNPC = npcName or npc.Name

                -- TP to NPC if far
                if CFG.TeleportToNPC and (dist or 999) > 25 then
                    tpToNPC(npc)
                    task.wait(0.15)
                end

                -- Attack
                pcall(function()
                    local weapon = getWeaponModule()
                    if weapon and weapon.onActivated then
                        weapon.onActivated(Mouse)
                    end
                end)

                -- Track kills
                if npc:GetAttribute("Dead") then _kills += 1 end

                -- Track SP
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

-- ─── ANTI-AFK LOOP ───────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if CFG.AntiAFK then
            pcall(function() VirtualUser:CaptureController() end)
            pcall(function() VirtualUser:ClickButton2(Vector2.new()) end)
        end
        task.wait(30)
    end
end)

-- ─── AUTO STAT LOOP ──────────────────────────────────────────────────────────

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

-- ─── AUTO CHEST LOOP ─────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if CFG.AutoChest then
            pcall(function() Interactions.chestOpenRequest.send() end)
        end
        task.wait(5)
    end
end)

-- ─── AUTO POTION LOOP ────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if CFG.AutoPotion then
            pcall(function() Interactions.potionUseRequest.send() end)
        end
        task.wait(10)
    end
end)

-- ─── NOCLIP + AUTO HEAL (RunService.Stepped) ─────────────────────────────────

RunService.Stepped:Connect(function()
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

-- Hook HealthChanged for instant heal
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

-- ─── UI FACTORY HELPERS ──────────────────────────────────────────────────────

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = inst
end

local function listLayout(inst, dir, gap, ha, va)
    local l = Instance.new("UIListLayout")
    l.FillDirection       = dir or Enum.FillDirection.Vertical
    l.SortOrder           = Enum.SortOrder.LayoutOrder
    l.Padding             = UDim.new(0, gap or 4)
    l.HorizontalAlignment = ha or Enum.HorizontalAlignment.Left
    l.VerticalAlignment   = va or Enum.VerticalAlignment.Top
    l.Parent = inst
    return l
end

local function frame(p, bg, sz, pos, z, clips)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = bg or WHITE
    f.BorderSizePixel  = 0
    f.Size             = sz or UDim2.fromOffset(100, 30)
    f.Position         = pos or UDim2.fromOffset(0, 0)
    f.ZIndex           = z or 1
    f.ClipsDescendants = clips or false
    f.Parent           = p
    return f
end

local function label(p, text, sz, pos, tc, ts, font, xa, z)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size             = sz or UDim2.fromOffset(100, 20)
    l.Position         = pos or UDim2.fromOffset(0, 0)
    l.Text             = text or ""
    l.TextColor3       = tc or TEXT_DARK
    l.Font             = font or Enum.Font.GothamMedium
    l.TextSize         = ts or 12
    l.TextXAlignment   = xa or Enum.TextXAlignment.Left
    l.TextYAlignment   = Enum.TextYAlignment.Center
    l.TextTruncate     = Enum.TextTruncate.AtEnd
    l.ZIndex           = z or 2
    l.Parent           = p
    return l
end

-- Frame-based hitbox overlay (anti-cheat safe click handler)
local function hitbox(p, w, h, z, fn)
    local h2 = frame(p, Color3.new(0, 0, 0), UDim2.fromOffset(w, h), UDim2.fromOffset(0, 0), z or 20)
    h2.BackgroundTransparency = 1
    h2.Active = true
    h2.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            fn()
        end
    end)
    return h2
end

local TI_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad)

-- Toggle row: returns (row, getState, setState)
local function makeToggle(parent, labelText, cfgKey, z, onChanged)
    local Z = z or 12
    local row = frame(parent, Color3.fromRGB(250, 250, 253), UDim2.fromOffset(280, 30), nil, Z)
    corner(row, 6)
    label(row, labelText, UDim2.fromOffset(205, 30), UDim2.fromOffset(10, 0), TEXT_DARK, 12, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, Z + 1)
    local track = frame(row, OFF_GRAY, UDim2.fromOffset(36, 18), UDim2.fromOffset(234, 6), Z + 1)
    corner(track, 9)
    local knob = frame(track, WHITE, UDim2.fromOffset(14, 14), UDim2.fromOffset(2, 2), Z + 2)
    corner(knob, 7)

    local state = CFG[cfgKey] or false

    local function setState(val)
        state = val
        if cfgKey then CFG[cfgKey] = val end
        TweenService:Create(track, TI_FAST, { BackgroundColor3 = val and PINK or OFF_GRAY }):Play()
        TweenService:Create(knob,  TI_FAST, { Position = val and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2) }):Play()
        if onChanged then onChanged(val) end
    end

    hitbox(row, 280, 30, Z + 3, function() setState(not state) end)
    return row, function() return state end, setState
end

-- Pink action button (Frame-based)
local function makeBtn(parent, text, w, h, z, fn)
    local Z = z or 12
    local btn = frame(parent, PINK, UDim2.fromOffset(w or 120, h or 26), nil, Z)
    corner(btn, 6)
    label(btn, text, UDim2.fromOffset(w or 120, h or 26), UDim2.fromOffset(0, 0), WHITE, 11, Enum.Font.GothamBold, Enum.TextXAlignment.Center, Z + 1)
    hitbox(btn, w or 120, h or 26, Z + 2, function()
        TweenService:Create(btn, TI_FAST, { BackgroundColor3 = Color3.fromRGB(218, 78, 112) }):Play()
        task.delay(0.12, function()
            if btn and btn.Parent then
                TweenService:Create(btn, TI_FAST, { BackgroundColor3 = PINK }):Play()
            end
        end)
        if fn then fn() end
    end)
    return btn
end

-- Section header
local function sectionHeader(parent, text, z)
    local Z = z or 12
    local hdr = frame(parent, SECTION_BG, UDim2.fromOffset(280, 22), nil, Z)
    corner(hdr, 4)
    label(hdr, "  " .. text, UDim2.fromOffset(280, 22), UDim2.fromOffset(0, 0), PINK, 10, Enum.Font.GothamBold, Enum.TextXAlignment.Left, Z + 1)
    return hdr
end

-- Right panel stat row: returns (row, valueLbl)
local function statRow(parent, lText, initVal, z)
    local Z = z or 12
    local row = frame(parent, Color3.fromRGB(252, 252, 255), UDim2.fromOffset(196, 26), nil, Z)
    corner(row, 5)
    label(row, lText, UDim2.fromOffset(108, 26), UDim2.fromOffset(8, 0), TEXT_MID, 10, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, Z + 1)
    local val = label(row, initVal or "--", UDim2.fromOffset(76, 26), UDim2.fromOffset(112, 0), TEXT_DARK, 10, Enum.Font.GothamBold, Enum.TextXAlignment.Right, Z + 1)
    return row, val
end

-- Right panel section header
local function rightHeader(parent, text, z)
    local Z = z or 12
    local hdr = frame(parent, SECTION_BG, UDim2.fromOffset(196, 20), nil, Z)
    corner(hdr, 4)
    label(hdr, "  " .. text, UDim2.fromOffset(196, 20), UDim2.fromOffset(0, 0), PINK, 9, Enum.Font.GothamBold, Enum.TextXAlignment.Left, Z + 1)
    return hdr
end

-- Transparent spacer
local function spacer(parent, w, h, z)
    local s = frame(parent, Color3.new(), UDim2.fromOffset(w, h), nil, z or 2)
    s.BackgroundTransparency = 1
    return s
end

-- ─── BUILD GUI ────────────────────────────────────────────────────────────────

local existing = Player.PlayerGui:FindFirstChild("AuroraSPL")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name           = "AuroraSPL"
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 50
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = Player.PlayerGui

-- ─── MAIN FRAME ──────────────────────────────────────────────────────────────

local MAIN_W = 556
local MAIN_H = 524
local TITLE_H = 44
local STATUS_H = 28
local CONTENT_Y = TITLE_H + STATUS_H + 1  -- 73

local main = frame(gui, PANEL_BG, UDim2.fromOffset(MAIN_W, MAIN_H), UDim2.fromOffset(60, 80), 10, false)
corner(main, 10)

-- Drop shadow
do
    local sh = frame(main, Color3.new(), UDim2.fromOffset(MAIN_W + 12, MAIN_H + 12), UDim2.fromOffset(-6, 5), 9)
    sh.BackgroundTransparency = 0.84
    corner(sh, 12)
end

-- ─── TITLE BAR ───────────────────────────────────────────────────────────────

local titleBar = frame(main, PINK, UDim2.fromOffset(MAIN_W, TITLE_H), UDim2.fromOffset(0, 0), 11)
corner(titleBar, 10)
-- patch bottom rounded corners of title bar
do
    local fix = frame(main, PINK, UDim2.fromOffset(MAIN_W, 10), UDim2.fromOffset(0, TITLE_H - 2), 11)
end

label(titleBar, "🌸", UDim2.fromOffset(34, TITLE_H), UDim2.fromOffset(10, 0), WHITE, 18, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 12)
label(titleBar, "+1 Skill Point Legends", UDim2.fromOffset(340, 24), UDim2.fromOffset(46, 2), WHITE, 14, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 12)
label(titleBar, "by notCitruss  —  +1 SPL v2", UDim2.fromOffset(340, 18), UDim2.fromOffset(46, 24), Color3.fromRGB(255, 215, 228), 10, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 12)

-- Minimize button
local minFrame = frame(titleBar, Color3.fromRGB(255, 255, 255), UDim2.fromOffset(24, 24), UDim2.fromOffset(MAIN_W - 62, 10), 13)
minFrame.BackgroundTransparency = 0.3
corner(minFrame, 6)
local minLbl = label(minFrame, "—", UDim2.fromOffset(24, 24), UDim2.fromOffset(0, 0), WHITE, 12, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 14)

-- Close button
local closeFrame = frame(titleBar, Color3.fromRGB(255, 255, 255), UDim2.fromOffset(24, 24), UDim2.fromOffset(MAIN_W - 34, 10), 13)
closeFrame.BackgroundTransparency = 0.3
corner(closeFrame, 6)
label(closeFrame, "x", UDim2.fromOffset(24, 24), UDim2.fromOffset(0, 0), WHITE, 12, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 14)

-- ─── STATUS BAR ──────────────────────────────────────────────────────────────

local statusBar = frame(main, Color3.fromRGB(248, 248, 252), UDim2.fromOffset(MAIN_W, STATUS_H), UDim2.fromOffset(0, TITLE_H), 11)
local statusDot = frame(statusBar, OFF_GRAY, UDim2.fromOffset(8, 8), UDim2.fromOffset(12, 10), 12)
corner(statusDot, 4)
local statusLbl = label(statusBar, "Idle  |  SP: --  |  Kills: 0", UDim2.fromOffset(524, STATUS_H), UDim2.fromOffset(26, 0), TEXT_MID, 10, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 12)
-- 1px separator
frame(main, BORDER, UDim2.fromOffset(MAIN_W, 1), UDim2.fromOffset(0, TITLE_H + STATUS_H), 11)

-- ─── LEFT PANEL ──────────────────────────────────────────────────────────────

local LEFT_W   = 308
local SCROLL_H = MAIN_H - CONTENT_Y - 8

local leftScroll = Instance.new("ScrollingFrame")
leftScroll.BackgroundTransparency = 1
leftScroll.Size                   = UDim2.fromOffset(LEFT_W, SCROLL_H)
leftScroll.Position               = UDim2.fromOffset(8, CONTENT_Y + 4)
leftScroll.CanvasSize             = UDim2.fromOffset(0, 0)
leftScroll.ScrollBarThickness     = 3
leftScroll.ScrollBarImageColor3   = PINK
leftScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
leftScroll.ZIndex                 = 11
leftScroll.Parent                 = main

local leftC = frame(leftScroll, Color3.new(), UDim2.fromOffset(LEFT_W - 6, 10), nil, 12)
leftC.BackgroundTransparency = 1
local leftList = listLayout(leftC, Enum.FillDirection.Vertical, 5)

-- Add to left panel
local function L(inst)
    inst.Parent = leftC
end

-- ── FARMING ──────────────────────────────────────────────────────────────────

L(sectionHeader(nil, "FARMING", 12))
local farmRow = makeToggle(nil, "Auto Farm", "AutoFarm", 12, function(val)
    if val then startFarm() else stopFarm() end
end)
L(farmRow)
L(makeToggle(nil, "Teleport to NPCs", "TeleportToNPC", 12))

-- ── TARGET MOB ───────────────────────────────────────────────────────────────

L(sectionHeader(nil, "TARGET MOB", 12))

-- Dropdown toggle row
local dropToggleRow = frame(nil, SECTION_BG, UDim2.fromOffset(280, 30), nil, 12)
corner(dropToggleRow, 6)
local mobDropLbl = label(dropToggleRow, "Select Mobs  (all)", UDim2.fromOffset(240, 30), UDim2.fromOffset(10, 0), TEXT_DARK, 11, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 13)
label(dropToggleRow, "v", UDim2.fromOffset(28, 30), UDim2.fromOffset(248, 0), PINK, 11, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 13)
L(dropToggleRow)

local function updateMobLabel()
    local n = 0
    for _ in pairs(CFG.TargetMobs) do n += 1 end
    mobDropLbl.Text = n == 0 and "Select Mobs  (all)" or ("Select Mobs  (" .. n .. " selected)")
end

-- Dropdown panel parented to main (high ZIndex so it overlays all panels)
local dropOpen  = false
local dropPanel = frame(main, WHITE, UDim2.fromOffset(280, 200), UDim2.fromOffset(16, 200), 50, true)
corner(dropPanel, 8)
dropPanel.Visible = false

-- Shadow under dropdown
do
    local sh = frame(dropPanel, Color3.new(), UDim2.fromOffset(290, 210), UDim2.fromOffset(-5, 3), 49)
    sh.BackgroundTransparency = 0.82
    corner(sh, 10)
end

local dropScroll = Instance.new("ScrollingFrame")
dropScroll.BackgroundTransparency = 1
dropScroll.Size                   = UDim2.fromOffset(280, 200)
dropScroll.CanvasSize             = UDim2.fromOffset(0, 0)
dropScroll.ScrollBarThickness     = 3
dropScroll.ScrollBarImageColor3   = PINK
dropScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
dropScroll.ZIndex                 = 51
dropScroll.Parent                 = dropPanel

listLayout(dropScroll, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left)

do
    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 4)
    pad.PaddingLeft   = UDim.new(0, 4)
    pad.PaddingRight  = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent        = dropScroll
end

local mobCheckState = {}
for _, mob in MOB_LIST do
    mobCheckState[mob] = false
end

for _, mob in MOB_LIST do
    local row = frame(dropScroll, Color3.fromRGB(252, 252, 255), UDim2.fromOffset(262, 24), nil, 52)
    corner(row, 4)
    local chk = frame(row, OFF_GRAY, UDim2.fromOffset(14, 14), UDim2.fromOffset(6, 5), 53)
    corner(chk, 3)
    label(row, mob, UDim2.fromOffset(232, 24), UDim2.fromOffset(26, 0), TEXT_DARK, 11, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 53)
    hitbox(row, 262, 24, 54, function()
        mobCheckState[mob] = not mobCheckState[mob]
        chk.BackgroundColor3 = mobCheckState[mob] and PINK or OFF_GRAY
        CFG.TargetMobs = {}
        for m, sel in mobCheckState do
            if sel then CFG.TargetMobs[m] = true end
        end
        updateMobLabel()
    end)
end

-- Toggle dropdown open/close
hitbox(dropToggleRow, 280, 30, 14, function()
    dropOpen = not dropOpen
    dropPanel.Visible = dropOpen
    if dropOpen then
        local rowAbs  = dropToggleRow.AbsolutePosition
        local mainAbs = main.AbsolutePosition
        dropPanel.Position = UDim2.fromOffset(
            rowAbs.X - mainAbs.X,
            rowAbs.Y - mainAbs.Y + 32
        )
    end
end)

-- Close dropdown on outside click
UserInputService.InputBegan:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    if not dropOpen then return end
    local pos     = inp.Position
    local dpAbs   = dropPanel.AbsolutePosition
    local dpSz    = dropPanel.AbsoluteSize
    local rowAbs  = dropToggleRow.AbsolutePosition
    local rowSz   = dropToggleRow.AbsoluteSize
    local inDrop  = pos.X >= dpAbs.X  and pos.X <= dpAbs.X  + dpSz.X  and pos.Y >= dpAbs.Y  and pos.Y <= dpAbs.Y  + dpSz.Y
    local inRow   = pos.X >= rowAbs.X and pos.X <= rowAbs.X + rowSz.X and pos.Y >= rowAbs.Y and pos.Y <= rowAbs.Y + rowSz.Y
    if not inDrop and not inRow then
        dropOpen = false
        dropPanel.Visible = false
    end
end)

-- ── STATS & SPEED ────────────────────────────────────────────────────────────

L(sectionHeader(nil, "STATS & SPEED", 12))
L(makeToggle(nil, "Auto Add Stats", "AutoStat", 12))

-- Stat target row
local statRowF = frame(nil, SECTION_BG, UDim2.fromOffset(280, 30), nil, 12)
corner(statRowF, 6)
L(statRowF)
label(statRowF, "Stat Target", UDim2.fromOffset(100, 30), UDim2.fromOffset(10, 0), TEXT_MID, 11, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 13)
local statValLbl = label(statRowF, CFG.StatTarget, UDim2.fromOffset(120, 30), UDim2.fromOffset(108, 0), PINK, 10, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 13)

local cycleF = frame(statRowF, PINK, UDim2.fromOffset(28, 20), UDim2.fromOffset(248, 5), 13)
corner(cycleF, 5)
label(cycleF, ">", UDim2.fromOffset(28, 20), UDim2.fromOffset(0, 0), WHITE, 10, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 14)
local statIdx = 1
hitbox(cycleF, 28, 20, 15, function()
    statIdx = statIdx % #STAT_NAMES + 1
    CFG.StatTarget = STAT_NAMES[statIdx]
    statValLbl.Text = CFG.StatTarget
end)

-- Attack Speed row
local atkRowF = frame(nil, SECTION_BG, UDim2.fromOffset(280, 30), nil, 12)
corner(atkRowF, 6)
L(atkRowF)
label(atkRowF, "Attack Speed", UDim2.fromOffset(100, 30), UDim2.fromOffset(10, 0), TEXT_MID, 11, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 13)
local atkLbl = label(atkRowF, CFG.AttackSpeed .. "s", UDim2.fromOffset(70, 30), UDim2.fromOffset(108, 0), TEXT_DARK, 11, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 13)

-- minus button
local minusF = frame(atkRowF, PINK, UDim2.fromOffset(26, 20), UDim2.fromOffset(180, 5), 13)
corner(minusF, 5)
label(minusF, "-", UDim2.fromOffset(26, 20), UDim2.fromOffset(0, 0), WHITE, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 14)
hitbox(minusF, 26, 20, 15, function()
    CFG.AttackSpeed = math.max(0.1, math.floor((CFG.AttackSpeed - 0.1) * 10 + 0.5) / 10)
    atkLbl.Text = CFG.AttackSpeed .. "s"
end)

-- plus button
local plusF = frame(atkRowF, PINK, UDim2.fromOffset(26, 20), UDim2.fromOffset(248, 5), 13)
corner(plusF, 5)
label(plusF, "+", UDim2.fromOffset(26, 20), UDim2.fromOffset(0, 0), WHITE, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 14)
hitbox(plusF, 26, 20, 15, function()
    CFG.AttackSpeed = math.min(3.0, math.floor((CFG.AttackSpeed + 0.1) * 10 + 0.5) / 10)
    atkLbl.Text = CFG.AttackSpeed .. "s"
end)

-- ── UTILITY ──────────────────────────────────────────────────────────────────

L(sectionHeader(nil, "UTILITY", 12))
L(makeToggle(nil, "Anti-AFK",          "AntiAFK",    12))
L(makeToggle(nil, "Noclip",            "Noclip",     12))
L(makeToggle(nil, "Auto Heal",         "AutoHeal",   12))
L(makeToggle(nil, "Auto Open Chests",  "AutoChest",  12))
L(makeToggle(nil, "Auto Use Potions",  "AutoPotion", 12))
L(makeToggle(nil, "Auto Claim Daily",  "AutoDaily",  12))

-- ── QUICK ACTIONS ────────────────────────────────────────────────────────────

L(sectionHeader(nil, "QUICK ACTIONS", 12))

-- Row 1: TP + Claim All
local actRow1 = frame(nil, Color3.new(), UDim2.fromOffset(280, 30), nil, 12)
actRow1.BackgroundTransparency = 1
L(actRow1)
listLayout(actRow1, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
makeBtn(actRow1, "TP to Nearest NPC", 135, 26, 13, function()
    local npc = findNearestNPC()
    if npc then tpToNPC(npc) end
end)
makeBtn(actRow1, "Claim All Rewards", 135, 26, 13, function()
    pcall(function() Interactions.claimLikeReward.send() end)
    pcall(function() Interactions.onOfflineRewardClaim.send() end)
    pcall(function() Interactions.onRankRewardClaim.send() end)
    pcall(function() Interactions.dailyRewardClaim.send() end)
end)

-- Row 2: Individual claim buttons
local actRow2 = frame(nil, Color3.new(), UDim2.fromOffset(280, 30), nil, 12)
actRow2.BackgroundTransparency = 1
L(actRow2)
listLayout(actRow2, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
makeBtn(actRow2, "Offline Reward", 89, 26, 13, function()
    pcall(function() Interactions.onOfflineRewardClaim.send() end)
end)
makeBtn(actRow2, "Rank Reward", 89, 26, 13, function()
    pcall(function() Interactions.onRankRewardClaim.send() end)
end)
makeBtn(actRow2, "Like Reward", 89, 26, 13, function()
    pcall(function() Interactions.claimLikeReward.send() end)
end)

spacer(leftC, 280, 8, 12)

-- ─── VERTICAL DIVIDER ────────────────────────────────────────────────────────

frame(main, BORDER, UDim2.fromOffset(1, SCROLL_H), UDim2.fromOffset(LEFT_W + 10, CONTENT_Y + 4), 11)

-- ─── RIGHT PANEL (Stats) ──────────────────────────────────────────────────────

local RIGHT_X = LEFT_W + 16
local RIGHT_W = 220

local rightScroll = Instance.new("ScrollingFrame")
rightScroll.BackgroundTransparency = 1
rightScroll.Size                   = UDim2.fromOffset(RIGHT_W, SCROLL_H)
rightScroll.Position               = UDim2.fromOffset(RIGHT_X + 4, CONTENT_Y + 4)
rightScroll.CanvasSize             = UDim2.fromOffset(0, 0)
rightScroll.ScrollBarThickness     = 3
rightScroll.ScrollBarImageColor3   = PINK
rightScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
rightScroll.ZIndex                 = 11
rightScroll.Parent                 = main

local rightC = frame(rightScroll, Color3.new(), UDim2.fromOffset(RIGHT_W - 4, 10), nil, 12)
rightC.BackgroundTransparency = 1
listLayout(rightC, Enum.FillDirection.Vertical, 4)

local function R(inst)
    inst.Parent = rightC
end

-- PLAYER section
R(rightHeader(nil, "PLAYER", 12))
local _, rSP   = statRow(nil, "Skill Points", "--",  12); R(_)
local _, rRank = statRow(nil, "Rank",          "--",  12); R(_)
local _, rZone = statRow(nil, "Zone",          "--",  12); R(_)
local _, rWep  = statRow(nil, "Weapon",        "--",  12); R(_)

-- SESSION section
R(rightHeader(nil, "SESSION", 12))
local _, rKills   = statRow(nil, "Kills",      "0",   12); R(_)
local _, rSPGain  = statRow(nil, "SP Gained",  "0",   12); R(_)
local _, rTarget  = statRow(nil, "Stat Target", CFG.StatTarget, 12); R(_)
local _, rSpeed   = statRow(nil, "Atk Speed",  CFG.AttackSpeed .. "s", 12); R(_)

-- NPC INFO section
R(rightHeader(nil, "NPC INFO", 12))
local _, rNearNPC = statRow(nil, "Nearest NPC", "--", 12); R(_)
local _, rDist    = statRow(nil, "Distance",    "--", 12); R(_)
local _, rFarmSt  = statRow(nil, "Farm Status", "Off", 12); R(_)

spacer(rightC, 196, 8, 12)

-- ─── STATUS UPDATER ──────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        pcall(function()
            local ls   = Player:FindFirstChild("leaderstats")
            local sp   = ls and ls:FindFirstChild("SP")   and ls.SP.Value   or 0
            local rank = ls and ls:FindFirstChild("Rank") and ls.Rank.Value or "--"
            local zone = Player:GetAttribute("Zone") or "--"

            -- Weapon name
            local wepName = "--"
            pcall(function()
                local inv      = fus.peek(Values.inventory)
                local equipped = fus.peek(Values.equippedItems)
                if inv and equipped then
                    for _, item in equipped do
                        if inv[item] and inv[item].type == "weapon" then
                            wepName = item
                            break
                        end
                    end
                end
            end)

            -- Nearest NPC
            local nearNPC  = findNearestNPC()
            local nearName = "--"
            local nearDist = "--"
            if nearNPC then
                nearName = getNpcName(nearNPC)
                local hrp  = getHRP()
                local root = nearNPC:FindFirstChild("HumanoidRootPart") or nearNPC:FindFirstChild("Root")
                if hrp and root then
                    nearDist = math.floor((hrp.Position - root.Position).Magnitude) .. "m"
                end
            end

            -- Status bar
            local farmStr = CFG.AutoFarm and "Farming" or "Idle"
            statusLbl.Text = farmStr .. "  |  SP: " .. formatNum(sp) .. "  |  Kills: " .. _kills
            statusDot.BackgroundColor3 = CFG.AutoFarm and GREEN or OFF_GRAY

            -- Right panel values
            rSP.Text    = formatNum(sp)
            rRank.Text  = tostring(rank)
            rZone.Text  = tostring(zone)
            rWep.Text   = wepName

            rKills.Text  = tostring(_kills)
            rSPGain.Text = formatNum(math.max(0, _spGained))
            rTarget.Text = CFG.StatTarget
            rSpeed.Text  = CFG.AttackSpeed .. "s"

            rNearNPC.Text = nearName
            rDist.Text    = nearDist
            rFarmSt.Text  = CFG.AutoFarm and "Active" or "Off"
            rFarmSt.TextColor3 = CFG.AutoFarm and GREEN or OFF_GRAY
        end)
        task.wait(1)
    end
end)

-- ─── DRAG ────────────────────────────────────────────────────────────────────

local dragging   = false
local dragStart  = nil
local dragOrigin = nil

titleBar.Active = true
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging   = true
        dragStart  = inp.Position
        dragOrigin = main.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
        local delta = inp.Position - dragStart
        main.Position = UDim2.fromOffset(
            dragOrigin.X.Offset + delta.X,
            dragOrigin.Y.Offset + delta.Y
        )
    end
end)

-- ─── MINIMIZE ────────────────────────────────────────────────────────────────

local _minimized = false
hitbox(minFrame, 24, 24, 15, function()
    _minimized = not _minimized
    TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = UDim2.fromOffset(MAIN_W, _minimized and TITLE_H or MAIN_H)
    }):Play()
    minLbl.Text = _minimized and "+" or "—"
end)

-- ─── CLOSE ───────────────────────────────────────────────────────────────────

hitbox(closeFrame, 24, 24, 15, function()
    stopFarm()
    gui:Destroy()
end)

print("[SPL] Aurora v2 loaded — +1 Skill Point Legends by notCitruss")
