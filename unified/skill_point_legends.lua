--// Aurora v6 — +1 Skill Point Legends
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 135668295983945
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// ByteNet via Interactions module (67 packets) — PRESERVED verbatim + new features

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Cleanup old UI (Xeno-safe: each parent chain in its own pcall)
for _, n in ipairs({"Aurora", "AuroraSPL", "AuroraPill"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- MODULES (preserved verbatim from v4) ----------
local ok1, Interactions = pcall(require, RS:FindFirstChild("Source") and RS.Source:FindFirstChild("Packets") and RS.Source.Packets:FindFirstChild("Interactions") and RS.Source.Packets.Interactions)
if not ok1 or not Interactions then warn("[Aurora] Interactions module not found"); return end
local ok2, fusion = pcall(require, RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("fusion") and RS.Packages.fusion)
if not ok2 then fusion = nil end
local ok3, Values = pcall(require, RS:FindFirstChild("Source") and RS.Source:FindFirstChild("Utils") and RS.Source.Utils:FindFirstChild("Values") and RS.Source.Utils.Values)
if not ok3 then Values = nil end
local fus = fusion

---------- ZOMBIE KILL ----------
if getgenv().AURORA_SPL_CFG2 then
    for k, v in pairs(getgenv().AURORA_SPL_CFG2) do
        if type(v) == "boolean" then getgenv().AURORA_SPL_CFG2[k] = false end
    end
end
task.wait(0.15)

getgenv().AURORA_SPL_SESSION = tick()
local _mySession = getgenv().AURORA_SPL_SESSION
local function alive() return getgenv().AURORA_SPL_SESSION == _mySession end

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

---------- CONFIG (v5: getgenv-backed for zombie-kill) ----------
if not getgenv().AURORA_SPL_CFG2 then
    getgenv().AURORA_SPL_CFG2 = {
        -- v4 keys preserved exactly
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
        AutoSave      = true,
        -- v5 UI state
        ActiveTab     = "Farm",
        PanelOpen     = true,
        -- v6 additions (all default off)
        FastAttack         = true,   -- use server-auth weaponActivate instead of onActivated (faster)
        AutoOfflineReward  = false,
        AutoRankReward     = false,
        AutoGate           = false,
        AutoBossRevive     = false,
        MobESP             = false,
        BossESP            = false,
        SpeedCap           = 0,   -- 0 = disabled
        JumpCap            = 0,
        PinnedBoss         = "",  -- boss name pinned for tracker
    }
else
    local c = getgenv().AURORA_SPL_CFG2
    if c.ActiveTab == nil then c.ActiveTab = "Farm" end
    if c.PanelOpen == nil then c.PanelOpen = true end
    -- v6 backfill
    if c.FastAttack         == nil then c.FastAttack         = true  end
    if c.AutoOfflineReward  == nil then c.AutoOfflineReward  = false end
    if c.AutoRankReward     == nil then c.AutoRankReward     = false end
    if c.AutoGate           == nil then c.AutoGate           = false end
    if c.AutoBossRevive     == nil then c.AutoBossRevive     = false end
    if c.MobESP             == nil then c.MobESP             = false end
    if c.BossESP            == nil then c.BossESP            = false end
    if c.SpeedCap           == nil then c.SpeedCap           = 0     end
    if c.JumpCap            == nil then c.JumpCap            = 0     end
    if c.PinnedBoss         == nil then c.PinnedBoss         = ""    end
end
local CFG = getgenv().AURORA_SPL_CFG2

---------- TOGGLE SAVE/LOAD (preserved v4 filename) ----------
local _cfgFileName = "aurora_cfg_skill_point_legends.json"

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
    pcall(function() if _HAS.writefile then writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end end)
    getgenv()["AuroraCFG_skill_point_legends"] = CFG
end

loadSavedCFG()

---------- CONSTANTS (preserved verbatim from v4) ----------
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

---------- STATE (preserved verbatim from v4) ----------
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

---------- HELPER FUNCTIONS (preserved verbatim from v4) ----------
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
            -- Strip emoji prefixes (skull, lightning, etc.) for clean name matching
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
local _sessionStart = tick()
local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

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

---------- FARM LOOP (preserved verbatim from v4) ----------
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
                        if CFG.FastAttack then
                            -- Server-authoritative: send weaponActivate directly with NPC id
                            local nid = tonumber(target.npc.Name)
                            if nid then
                                pcall(function()
                                    Interactions.weaponActivate.send({
                                        targets = {nid},
                                        comboIndex = 1,
                                    })
                                end)
                            end
                        else
                            pcall(function()
                                local weapon = getWeaponModule()
                                if weapon and weapon.onActivated then
                                    weapon.onActivated(Mouse)
                                end
                            end)
                        end
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

---------- ANTI-AFK LOOP (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() do
        if CFG.AntiAFK then
            pcall(function() VirtualUser:CaptureController() end)
            pcall(function() VirtualUser:ClickButton2(Vector2.new()) end)
        end
        task.wait(30)
    end
end)

---------- AUTO STAT LOOP (v6: dump ALL SP into target stat every cycle) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoStat and fus and Values then
            pcall(function()
                local currentSP = fus.peek(Values.skillPoints)
                if type(currentSP) == "number" and currentSP >= 1 then
                    Interactions.statUpdateRequest.send({
                        stat   = CFG.StatTarget,
                        amount = currentSP,
                    })
                end
            end)
        end
        task.wait(1.5)
    end
end)

---------- AUTO CHEST LOOP (v6: proper struct args) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoChest and fus and Values then
            pcall(function()
                local inv = fus.peek(Values.inventory)
                if type(inv) == "table" then
                    for _, item in pairs(inv) do
                        if type(item) == "table" and item.t == 3 and item.n and (item.a or 0) > 0 then
                            Interactions.chestOpenRequest.send({
                                chestName = item.n,
                                amount    = math.min(10, item.a or 1),
                            })
                            task.wait(0.2)
                        end
                    end
                end
            end)
        end
        task.wait(5)
    end
end)

---------- AUTO POTION LOOP (v6: proper struct args) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoPotion and fus and Values then
            pcall(function()
                local inv = fus.peek(Values.inventory)
                if type(inv) == "table" then
                    for _, item in pairs(inv) do
                        if type(item) == "table" and item.n
                            and (item.t == 2 or tostring(item.n):lower():find("potion"))
                            and (item.a or 0) > 0
                        then
                            Interactions.potionUseRequest.send({
                                potionId = item.n,
                                amount   = 1,
                            })
                            task.wait(0.3)
                        end
                    end
                end
            end)
        end
        task.wait(10)
    end
end)

---------- AUTO OFFLINE REWARD LOOP (v6 new) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoOfflineReward and fus and Values then
            pcall(function()
                if fus.peek(Values.rewardReady) == true then
                    Interactions.onOfflineRewardClaim.send()
                end
            end)
        end
        task.wait(8)
    end
end)

---------- AUTO RANK REWARD LOOP (v6 new) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoRankReward then
            pcall(function() Interactions.onRankRewardClaim.send() end)
        end
        task.wait(60)
    end
end)

---------- AUTO GATE UNLOCK LOOP (v6 new) ----------
-- Auto-activate the gate the player is currently in front of (advances zone)
task.spawn(function()
    local lastSent = 0
    while alive() do
        if CFG.AutoGate and fus and Values then
            pcall(function()
                local gate = fus.peek(Values.activeGate)
                if gate and tick() - lastSent > 3 then
                    Interactions.gateActivationRequest.send(tostring(gate))
                    lastSent = tick()
                end
            end)
        end
        task.wait(2)
    end
end)

---------- AUTO BOSS REVIVE LOOP (v6 new) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoBossRevive then
            pcall(function() Interactions.bossReviveRequest.send() end)
        end
        task.wait(30)
    end
end)

---------- SPEED / JUMP CAP APPLIER (v6 new) ----------
task.spawn(function()
    local lastSpeedCap, lastJumpCap = -1, -1
    while alive() do
        if CFG.SpeedCap and CFG.SpeedCap > 0 and CFG.SpeedCap ~= lastSpeedCap then
            pcall(function()
                Interactions.updateSlotSpeedCap.send({ slotIndex = 1, speedCap = math.floor(CFG.SpeedCap) })
                Interactions.capUpdateRequest.send({ statName = "Speed", capped = math.floor(CFG.SpeedCap) })
            end)
            lastSpeedCap = CFG.SpeedCap
        end
        if CFG.JumpCap and CFG.JumpCap > 0 and CFG.JumpCap ~= lastJumpCap then
            pcall(function()
                Interactions.updateSlotJumpCap.send({ slotIndex = 1, jumpCap = math.floor(CFG.JumpCap) })
                Interactions.capUpdateRequest.send({ statName = "Jump Power", capped = math.floor(CFG.JumpCap) })
            end)
            lastJumpCap = CFG.JumpCap
        end
        task.wait(2)
    end
end)

---------- MOB / BOSS ESP (v6 new) ----------
-- Billboard tags over every live NPC in workspace.Npcs: name + HP + distance
-- Uses NpcTable.boss to highlight bosses in accent color
local _espTags = {} -- npc -> BillboardGui
local _npcTableCache = nil
pcall(function() _npcTableCache = require(RS.Source.Utils.NpcTable) end)

local function ensureESPTag(npc)
    if _espTags[npc] then return _espTags[npc] end
    local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Root")
    if not hrp then return nil end
    local bb = Instance.new("BillboardGui")
    bb.Name = "AuroraESP"
    bb.Adornee = hrp
    bb.Size = UDim2.new(0, 140, 0, 34)
    bb.StudsOffset = Vector3.new(0, 3.8, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 600
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Parent = bb
    pcall(function() bb.Parent = hrp end)
    _espTags[npc] = {bb = bb, lbl = lbl}
    return _espTags[npc]
end

local function destroyESPTag(npc)
    local e = _espTags[npc]
    if e then
        pcall(function() e.bb:Destroy() end)
        _espTags[npc] = nil
    end
end

local function destroyAllESP()
    for npc, e in pairs(_espTags) do
        pcall(function() e.bb:Destroy() end)
        _espTags[npc] = nil
    end
end

task.spawn(function()
    while alive() do
        local anyESP = CFG.MobESP or CFG.BossESP
        if anyESP then
            pcall(function()
                local npcsFolder = workspace:FindFirstChild("Npcs")
                if not npcsFolder then return end
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                for _, npc in ipairs(npcsFolder:GetChildren()) do
                    if npc:IsA("Model") and not npc:GetAttribute("Dead") then
                        local name = nil
                        for _, desc in ipairs(npc:GetDescendants()) do
                            if desc:IsA("TextLabel") and desc.Text ~= "" and not desc.Text:find("/") then
                                name = desc.Text:gsub("^[^%w]+%s*", "")
                                break
                            end
                        end
                        if name and name ~= "" then
                            local isBoss = _npcTableCache and _npcTableCache[name] and _npcTableCache[name].boss
                            local showIt = (CFG.BossESP and isBoss) or (CFG.MobESP and not isBoss)
                            if showIt then
                                local e = ensureESPTag(npc)
                                if e then
                                    local hum = npc:FindFirstChildOfClass("Humanoid")
                                    local hp = hum and string.format("%d%%", math.clamp(hum.Health / math.max(1, hum.MaxHealth) * 100, 0, 100)) or "?"
                                    local nhrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Root")
                                    local dist = (hrp and nhrp) and math.floor((nhrp.Position - hrp.Position).Magnitude) or 0
                                    e.lbl.Text = string.format("%s  [%s]  %dm", name, hp, dist)
                                    e.lbl.TextColor3 = isBoss and Color3.fromRGB(252, 110, 142) or Color3.fromRGB(200, 220, 255)
                                end
                            else
                                destroyESPTag(npc)
                            end
                        end
                    else
                        destroyESPTag(npc)
                    end
                end
                -- cleanup orphans
                for npc, _ in pairs(_espTags) do
                    if not npc or not npc.Parent then destroyESPTag(npc) end
                end
            end)
        else
            destroyAllESP()
        end
        task.wait(0.5)
    end
    destroyAllESP()
end)

---------- BOSS TRACKER (v6 new) ----------
-- Sends addPinnedBoss / removePinnedBoss when CFG.PinnedBoss changes
task.spawn(function()
    local lastPinned = ""
    while alive() do
        if CFG.PinnedBoss ~= lastPinned then
            if lastPinned ~= "" then
                pcall(function() Interactions.removePinnedBoss.send(lastPinned) end)
            end
            if CFG.PinnedBoss ~= "" then
                pcall(function() Interactions.addPinnedBoss.send(CFG.PinnedBoss) end)
            end
            lastPinned = CFG.PinnedBoss
        end
        task.wait(1.5)
    end
end)

---------- NOCLIP + AUTO HEAL (preserved verbatim from v4) ----------
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
        local _healing = false
        hum.HealthChanged:Connect(function()
            if _healing then return end
            if CFG.AutoHeal and hum.Health < hum.MaxHealth then
                _healing = true
                pcall(function() hum.Health = hum.MaxHealth end)
                task.wait(0.1)
                _healing = false
            end
        end)
    end
end
Player.CharacterAdded:Connect(hookHeal)
if Player.Character then
    pcall(hookHeal, Player.Character)
end

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
    { name = "Farm",    icon = "●" },
    { name = "Combat",  icon = "⚔" },
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

local TAB_NAMES = { "Farm", "Combat", "Utility", "Settings" }
local TAB_ACCENT = {
    Farm     = C.pink,
    Combat   = C.pink,
    Utility  = C.purple,
    Settings = C.pink,
}
local PANEL_TITLES = {
    Farm     = { alpha = "AUTO FARM",     beta = "FARM STATUS" },
    Combat   = { alpha = "COMBAT ASSIST", beta = "COMBAT INFO" },
    Utility  = { alpha = "MOVEMENT",      beta = "PLAYER INFO" },
    Settings = { alpha = "CONFIG",        beta = "ABOUT"       },
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

-- Slider for AttackSpeed (0.1-1.0 step 0.1)
local function sliderRow(parent, label, cfgKey, min, max, step, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.fromOffset(0, 2),
        BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local valLabel = create("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.new(0.5, 0, 0, 2),
        BackgroundTransparency = 1, Text = string.format("%.1f", CFG[cfgKey] or min),
        Font = F_MONO, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local trackFrame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 30),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true,
    }, row)
    corner(trackFrame, 3)
    stroke(trackFrame, C.border2, 1, 0)
    local pct = math.clamp(((CFG[cfgKey] or min) - min) / (max - min), 0, 1)
    local fill = create("Frame", {
        Size = UDim2.new(pct, 0, 1, 0), BackgroundColor3 = C.pink, BorderSizePixel = 0,
    }, trackFrame)
    corner(fill, 3)
    local knob = create("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.new(pct, -7, 0.5, -7),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3,
    }, trackFrame)
    corner(knob, 7)
    local sliding = false
    local function updateSlider(inputX)
        local absPos = trackFrame.AbsolutePosition.X
        local absSize = trackFrame.AbsoluteSize.X
        if absSize <= 0 then return end
        local raw = math.clamp((inputX - absPos) / absSize, 0, 1)
        local val = min + raw * (max - min)
        val = math.floor(val / step + 0.5) * step
        val = math.clamp(val, min, max)
        if step >= 1 then val = math.floor(val) end
        CFG[cfgKey] = val
        local newPct = math.clamp((val - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(newPct, 0, 1, 0)
        knob.Position = UDim2.new(newPct, -7, 0.5, -7)
        valLabel.Text = (step < 1) and string.format("%.1f", val) or tostring(val)
        if CFG.AutoSave then saveCFG() end
    end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = true; updateSlider(inp.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(inp.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    return row
end

-- Stat Target cycler (preserves CFG.StatTarget semantics)
local function statCycleRow(parent, order, onChange)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Text = "Stat Target",
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local pill = create("Frame", {
        Size = UDim2.fromOffset(180, 22), Position = UDim2.new(1, -180, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)
    local statLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = CFG.StatTarget,
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)
    create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▶",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)
    local _statIdx = 1
    for i, sn in ipairs(STAT_NAMES) do if sn == CFG.StatTarget then _statIdx = i; break end end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            _statIdx = (_statIdx % #STAT_NAMES) + 1
            CFG.StatTarget = STAT_NAMES[_statIdx]
            statLabel.Text = CFG.StatTarget
            if CFG.AutoSave then saveCFG() end
            if onChange then onChange() end
        end
    end)
    return row, statLabel
end

-- Multi-select dropdown for Target Mobs (parented to screenGui for popup escape)
local function dropdownMapRow(parent, label, options, setMap, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
        LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(1, -130, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local pill = create("Frame", {
        Size = UDim2.fromOffset(120, 22), Position = UDim2.new(1, -120, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)

    local function displayText()
        local count, firstKey = 0, nil
        for _, nm in ipairs(options) do
            if setMap[nm] then count = count + 1; if not firstKey then firstKey = nm end end
        end
        if count == 0 then return "Any" end
        if count == #options then return "All (" .. count .. ")" end
        if count == 1 then return tostring(firstKey) end
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
    local OPT_H    = 26
    local POPUP_H  = math.min(320, #options * (OPT_H + 2) + 8)

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
            BackgroundTransparency = 1, Text = tostring(opt),
            Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
        }, btn)

        optBtns[i] = { frame = btn, fill = fill, opt = opt }
    end

    local function paintOpts()
        for _, o in ipairs(optBtns) do
            local sel = isSelected(o.opt)
            o.fill.Visible = sel
            o.frame.BackgroundTransparency = sel and 0.85 or 1
        end
    end
    paintOpts()

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

-- Filter out "Any" from mob list for dropdown (empty selection = any mob semantics preserved)
local MOB_OPTIONS = {}
for _, m in ipairs(MOB_LIST) do
    if m ~= "Any" then table.insert(MOB_OPTIONS, m) end
end

-- Build BOSS_OPTIONS from NpcTable boss=true entries (v6 new for BossTracker)
local BOSS_OPTIONS = {}
pcall(function()
    local NpcTable = require(RS.Source.Utils.NpcTable)
    local tmp = {}
    for k, v in pairs(NpcTable) do
        if type(v) == "table" and v.boss then
            table.insert(tmp, tostring(k))
        end
    end
    table.sort(tmp)
    BOSS_OPTIONS = tmp
end)

-- Single-select cycler helper (v6 new) — cycles an option list, writes string to CFG[key]
local function cycleRow(parent, label, cfgKey, options, order, onChange)
    if #options == 0 then return nil end
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local pill = create("Frame", {
        Size = UDim2.fromOffset(180, 22), Position = UDim2.new(1, -180, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)
    local lbl = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1,
        Text = (CFG[cfgKey] ~= nil and tostring(CFG[cfgKey]) ~= "" and tostring(CFG[cfgKey])) or "— none —",
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)
    create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▶",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)
    -- "None" option is index 0
    local _idx = 0
    for i, v in ipairs(options) do if v == CFG[cfgKey] then _idx = i; break end end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            _idx = _idx + 1
            if _idx > #options then _idx = 0 end
            CFG[cfgKey] = _idx == 0 and "" or options[_idx]
            lbl.Text = _idx == 0 and "— none —" or options[_idx]
            if CFG.AutoSave then saveCFG() end
            if onChange then onChange() end
        end
    end)
    return row, lbl
end

--========================================================================
-- POPULATE: FARM
--========================================================================
local oF_a, oF_b = 0, 0
local function nFa() oF_a = oF_a + 1; return oF_a end
local function nFb() oF_b = oF_b + 1; return oF_b end

sectionHeader(scrolls["Farm_alpha"], "●", "Auto-Farm", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Farm",         "AutoFarm",      nFa(), function(on)
    if on then startFarm() else stopFarm() end
end)
toggleRow    (scrolls["Farm_alpha"], "Teleport to NPC",   "TeleportToNPC", nFa())
toggleRow    (scrolls["Farm_alpha"], "Fast Attack (server)", "FastAttack", nFa())

sectionHeader(scrolls["Farm_alpha"], "◉", "Tuning", nFa())
sliderRow    (scrolls["Farm_alpha"], "Attack Speed", "AttackSpeed", 0.1, 1.0, 0.1, nFa())

sectionHeader(scrolls["Farm_alpha"], "▣", "Targets", nFa())
local _mobDrop, _mobRepaint = dropdownMapRow(scrolls["Farm_alpha"], "Target Mobs", MOB_OPTIONS, CFG.TargetMobs, nFa())

sectionHeader(scrolls["Farm_alpha"], "◎", "Auto-Claim", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Offline Reward", "AutoOfflineReward", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Rank Reward",    "AutoRankReward",    nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Gate Unlock",    "AutoGate",          nFa())

sectionHeader(scrolls["Farm_alpha"], "✦", "Notes", nFa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 140), BackgroundTransparency = 1,
    Text = "Select mobs to filter farming,\nor leave empty for any mob.\n\nFast Attack uses server\nweaponActivate for instant damage.\n\nAuto Gate activates the gate\nyou are currently in front of.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nFa(),
}, scrolls["Farm_alpha"])

sectionHeader(scrolls["Farm_beta"], "●", "Target", nFb())
local _infoTarget     = infoRow(scrolls["Farm_beta"], "Current NPC",  "None", C.text,  nFb())
local _infoStatus     = infoRow(scrolls["Farm_beta"], "Status",       "Idle", C.pink,  nFb())

sectionHeader(scrolls["Farm_beta"], "◉", "Session Totals", nFb())
local _infoKills      = infoRow(scrolls["Farm_beta"], "Kills",        "0",    C.pink,  nFb())
local _infoSPGained   = infoRow(scrolls["Farm_beta"], "SP Gained",    "0",    C.pink,  nFb())

sectionHeader(scrolls["Farm_beta"], "✦", "Session", nFb())
local _infoRuntime    = infoRow(scrolls["Farm_beta"], "Runtime",      "0m",   C.text2, nFb())
local _infoLevel      = infoRow(scrolls["Farm_beta"], "Level",        "---",  C.text,  nFb())
local _infoSP         = infoRow(scrolls["Farm_beta"], "SP",           "---",  C.text,  nFb())

--========================================================================
-- POPULATE: COMBAT
--========================================================================
local oC_a, oC_b = 0, 0
local function nCa() oC_a = oC_a + 1; return oC_a end
local function nCb() oC_b = oC_b + 1; return oC_b end

sectionHeader(scrolls["Combat_alpha"], "●", "Combat Assist", nCa())
toggleRow    (scrolls["Combat_alpha"], "Auto Heal",    "AutoHeal",   nCa())
toggleRow    (scrolls["Combat_alpha"], "Auto Potion",  "AutoPotion", nCa())
toggleRow    (scrolls["Combat_alpha"], "Auto Chest",   "AutoChest",  nCa())
toggleRow    (scrolls["Combat_alpha"], "Auto Daily",   "AutoDaily",  nCa())
toggleRow    (scrolls["Combat_alpha"], "Auto Boss Revive", "AutoBossRevive", nCa())

sectionHeader(scrolls["Combat_alpha"], "◉", "Stats", nCa())
toggleRow    (scrolls["Combat_alpha"], "Auto Stat",    "AutoStat",   nCa())
local _statRow, _statLabel = statCycleRow(scrolls["Combat_alpha"], nCa(), nil)

sectionHeader(scrolls["Combat_alpha"], "◈", "Boss Tracker", nCa())
local _bossCycleRow, _bossLabel = cycleRow(scrolls["Combat_alpha"], "Pinned Boss", "PinnedBoss", BOSS_OPTIONS, nCa())

sectionHeader(scrolls["Combat_alpha"], "◆", "ESP", nCa())
toggleRow    (scrolls["Combat_alpha"], "Boss ESP",     "BossESP",   nCa())
toggleRow    (scrolls["Combat_alpha"], "Mob ESP",      "MobESP",    nCa())

sectionHeader(scrolls["Combat_alpha"], "✦", "Notes", nCa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "Auto Stat dumps all your SP into\nthe target stat every 1.5s.\n\nAuto Chest and Auto Potion pull\nfrom your inventory automatically.\n\nESP shows HP + distance over NPCs.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nCa(),
}, scrolls["Combat_alpha"])

sectionHeader(scrolls["Combat_beta"], "●", "Combat Info", nCb())
local _infoWeapon     = infoRow(scrolls["Combat_beta"], "Weapon",      "---", C.text,  nCb())
local _infoHealth     = infoRow(scrolls["Combat_beta"], "Health",      "---", C.text,  nCb())
local _infoStatTarget = infoRow(scrolls["Combat_beta"], "Stat Target", CFG.StatTarget, C.pink, nCb())
local _infoSkillPts   = infoRow(scrolls["Combat_beta"], "Skill Points", "---", C.pink, nCb())

sectionHeader(scrolls["Combat_beta"], "◉", "Manual", nCb())
actionBtn(scrolls["Combat_beta"], "Open All Chests", C.bg3, nCb(), function()
    pcall(function()
        if not (fus and Values) then return end
        local inv = fus.peek(Values.inventory)
        if type(inv) ~= "table" then return end
        for _, item in pairs(inv) do
            if type(item) == "table" and item.t == 3 and item.n and (item.a or 0) > 0 then
                Interactions.chestOpenRequest.send({ chestName = item.n, amount = math.min(25, item.a or 1) })
                task.wait(0.1)
            end
        end
    end)
end)
actionBtn(scrolls["Combat_beta"], "Use All Potions", C.bg3, nCb(), function()
    pcall(function()
        if not (fus and Values) then return end
        local inv = fus.peek(Values.inventory)
        if type(inv) ~= "table" then return end
        for _, item in pairs(inv) do
            if type(item) == "table" and item.n
                and (item.t == 2 or tostring(item.n):lower():find("potion"))
                and (item.a or 0) > 0
            then
                Interactions.potionUseRequest.send({ potionId = item.n, amount = 1 })
                task.wait(0.1)
            end
        end
    end)
end)
actionBtn(scrolls["Combat_beta"], "Claim Daily",   C.bg3, nCb(), function()
    pcall(function() Interactions.claimDailyReward.send() end)
    pcall(function() Interactions.claimLikeReward.send() end)
end)
actionBtn(scrolls["Combat_beta"], "Claim Offline", C.bg3, nCb(), function()
    pcall(function() Interactions.onOfflineRewardClaim.send() end)
end)
actionBtn(scrolls["Combat_beta"], "Claim Rank",    C.bg3, nCb(), function()
    pcall(function() Interactions.onRankRewardClaim.send() end)
end)
actionBtn(scrolls["Combat_beta"], "Reset Stats",   C.red, nCb(), function()
    pcall(function() Interactions.statResetRequest.send() end)
end)

sectionHeader(scrolls["Combat_beta"], "✦", "Tips", nCb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1,
    Text = "Tap the Stat Target pill to cycle\nthrough all 6 stats.\n\nPinned Boss tracks a boss in the\ngame's boss tracker HUD.\n\nReset Stats consumes 1 credit.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nCb(),
}, scrolls["Combat_beta"])

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "●", "Movement", nUa())
toggleRow    (scrolls["Utility_alpha"], "Noclip",   "Noclip", nUa())

sectionHeader(scrolls["Utility_alpha"], "◉", "Stat Caps (server)", nUa())
sliderRow    (scrolls["Utility_alpha"], "Speed Cap", "SpeedCap", 0, 500, 1, nUa())
sliderRow    (scrolls["Utility_alpha"], "Jump Cap",  "JumpCap",  0, 500, 1, nUa())

sectionHeader(scrolls["Utility_alpha"], "◈", "Safety", nUa())
toggleRow    (scrolls["Utility_alpha"], "Anti-AFK", "AntiAFK", nUa())

sectionHeader(scrolls["Utility_alpha"], "✦", "Notes", nUa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 120), BackgroundTransparency = 1,
    Text = "Noclip disables collision on\nall character parts.\n\nSpeed/Jump Cap locks the server\nto your chosen value (0 = off).\n\nAnti-AFK clicks every 30s.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUa(),
}, scrolls["Utility_alpha"])

sectionHeader(scrolls["Utility_beta"], "●", "Player Info", nUb())
local _infoHealthUtil = infoRow(scrolls["Utility_beta"], "Health",     "---", C.text,  nUb())
local _infoWalkSpd    = infoRow(scrolls["Utility_beta"], "Walk Speed", "---", C.text,  nUb())
local _infoJumpPwr    = infoRow(scrolls["Utility_beta"], "Jump Power", "---", C.text,  nUb())

sectionHeader(scrolls["Utility_beta"], "◉", "Character", nUb())
local _infoLevelUtil  = infoRow(scrolls["Utility_beta"], "Level",      "---", C.text2, nUb())
local _infoSPUtil     = infoRow(scrolls["Utility_beta"], "SP",         "---", C.text2, nUb())

sectionHeader(scrolls["Utility_beta"], "✦", "Tips", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Safe combinations: Noclip +\nAuto Heal for immortal farming.\n\nAnti-AFK is required for\novernight farming.",
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
    CFG.AttackSpeed = 0.3
    CFG.StatTarget  = "Physical Damage"
    CFG.TargetMobs  = {}
    CFG.AutoSave    = true
    CFG.FastAttack  = true
    CFG.SpeedCap    = 0
    CFG.JumpCap     = 0
    CFG.PinnedBoss  = ""
    saveCFG()
    stopFarm()
    if _mobRepaint then _mobRepaint() end
    if _statLabel then _statLabel.Text = CFG.StatTarget end
    if _bossLabel then _bossLabel.Text = "— none —" end
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSa())
actionBtn    (scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn    (scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.3)
    getgenv().AURORA_SPL_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "+1 Skill Point Legends",     C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),       C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion),  C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",        C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v6",                         C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,                 C.text3, nSb())
infoRow(scrolls["Settings_beta"], "Network", "Interactions module",        C.text3, nSb())

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

sectionHeader(liveScroll, "◆", "Farm", nL())
local _liveTarget  = infoRow(liveScroll, "Target", "None", C.text,  nL())
local _liveKills   = infoRow(liveScroll, "Kills",  "0",    C.pink,  nL())
local _liveSP      = infoRow(liveScroll, "SP+",    "0",    C.pink,  nL())

sectionHeader(liveScroll, "✦", "Stats", nL())
local _liveLevel   = infoRow(liveScroll, "Level",  "---", C.text2, nL())
local _liveSPTotal = infoRow(liveScroll, "SP",     "---", C.text2, nL())

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
        getgenv().AURORA_SPL_SESSION = 0
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
            local hpTxt, spTxt, jpTxt = "---", "16", "---"
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hpTxt = string.format("%.0f/%.0f", hum.Health, hum.MaxHealth)
                    spTxt = tostring(math.floor(hum.WalkSpeed))
                    jpTxt = tostring(math.floor(hum.JumpPower))
                end
            end

            -- Runtime
            local elapsed = tick() - _sessionStart
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Status mode
            local mode = "Idle"
            if _running or CFG.AutoFarm then mode = "Farming"
            elseif CFG.AutoStat then mode = "Stat Pumping"
            elseif CFG.AutoChest then mode = "Chesting"
            elseif CFG.AutoHeal then mode = "Healing" end

            -- Leaderstats
            local lvlTxt, spTotalTxt = "---", "---"
            pcall(function()
                local ls = Player:FindFirstChild("leaderstats")
                if ls then
                    local lv = ls:FindFirstChild("Level")
                    local sp = ls:FindFirstChild("SP")
                    if lv then lvlTxt = tostring(lv.Value) end
                    if sp then spTotalTxt = formatNum(sp.Value) end
                end
            end)

            -- Weapon
            local wTxt = "---"
            pcall(function()
                local _, wName = getWeaponModule()
                if wName then wTxt = wName end
            end)

            -- Farm tab
            _infoTarget.Text      = _lastNPC or "None"
            _infoStatus.Text      = mode
            _infoKills.Text       = tostring(_kills)
            _infoSPGained.Text    = formatNum(_spGained)
            _infoRuntime.Text     = rtime
            _infoLevel.Text       = lvlTxt
            _infoSP.Text          = spTotalTxt

            -- Combat tab
            _infoWeapon.Text      = wTxt
            _infoHealth.Text      = hpTxt
            _infoStatTarget.Text  = CFG.StatTarget
            do
                local sp = nil
                pcall(function() if fus and Values then sp = fus.peek(Values.skillPoints) end end)
                _infoSkillPts.Text = type(sp) == "number" and formatNum(sp) or "---"
            end

            -- Utility tab
            _infoHealthUtil.Text  = hpTxt
            _infoWalkSpd.Text     = spTxt
            _infoJumpPwr.Text     = jpTxt
            _infoLevelUtil.Text   = lvlTxt
            _infoSPUtil.Text      = spTotalTxt

            -- Live Game
            _liveRuntime.Text     = rtime
            _liveStatus.Text      = mode
            _liveHealth.Text      = hpTxt
            _liveSpeed.Text       = spTxt
            _liveTarget.Text      = _lastNPC or "None"
            _liveKills.Text       = tostring(_kills)
            _liveSP.Text          = formatNum(_spGained)
            _liveLevel.Text       = lvlTxt
            _liveSPTotal.Text     = spTotalTxt

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

print("[Aurora v6] +1 Skill Point Legends loaded")
