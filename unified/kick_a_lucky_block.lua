--// Aurora v5 — Kick a Lucky Block
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 89469502395769
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// 60 remotes mapped — auto kick cycle, auto collect/upgrade/sell, rebirth, spin, shop buys

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- Cleanup old UI (Xeno-safe: each parent chain in its own pcall)
for _, n in ipairs({"Aurora", "AuroraPill", "TestAurora"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_KAL_CFG2 then
    for k, v in pairs(getgenv().__AURORA_KAL_CFG2) do
        if type(v) == "boolean" then getgenv().__AURORA_KAL_CFG2[k] = false end
    end
end
task.wait(0.15)

getgenv().__AURORA_KAL_SESSION = tick()
local _mySession = getgenv().__AURORA_KAL_SESSION
local function alive() return getgenv().__AURORA_KAL_SESSION == _mySession end

---------- COMPAT (cross-executor support) ----------
local _HAS = {
    gethui    = typeof(gethui) == "function",
    writefile = writefile ~= nil,
    readfile  = readfile ~= nil,
    hookfn    = hookfunction ~= nil,
    getgc     = getgc ~= nil,
    vim       = pcall(function() return game:GetService("VirtualInputManager") end),
}

---------- REMOTES (captured from Aurora Spy — ReplicatedStorage.Shared.Packages.Network) ----------
-- Type-safe remote lookup: returns the child only if it's the expected class
local function safeRE(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteEvent")) and obj or nil
end
local function safeRF(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteFunction")) and obj or nil
end
local function safeUnreliable(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return obj or nil
end

local Shared  = RS:WaitForChild("Shared", 20)
if not Shared then warn("[Aurora] Shared folder missing"); return end
local Packages = Shared:WaitForChild("Packages", 15)
if not Packages then warn("[Aurora] Packages folder missing"); return end
local Net = Packages:WaitForChild("Network", 15)
if not Net then warn("[Aurora] Network folder missing"); return end

-- Kick cycle
local rev_TaviMishkal   = safeRE(Net, "rev_TaviMishkal")
local rev_KickEvent     = safeRE(Net, "rev_KickEvent")
local rev_KickZman      = safeRE(Net, "rev_KickZman")
local rev_Transformed   = safeRE(Net, "rev_Transformed")
local rev_KickCollect   = safeRE(Net, "rev_KickCollect")
-- Plot economy
local rev_B_Collect     = safeRE(Net, "rev_B_Collect")
local rev_B_Upgrade     = safeRE(Net, "rev_B_Upgrade")
local rev_S_Interact    = safeRE(Net, "rev_S_Interact")
-- Sell (RemoteFunctions)
local ref_B_Sell        = safeRF(Net, "ref_B_Sell")
local ref_B_SellAll     = safeRF(Net, "ref_B_SellAll")
-- Shop + speed
local rev_Shop_Buy      = safeRE(Net, "rev_Shop_Buy")
local rev_SPEED_UPGRADE = safeRE(Net, "rev_SPEED_UPGRADE")
local rev_WeightEquip   = safeRE(Net, "rev_WeightEquip")
local rev_bs_upgrade    = safeRE(Net, "rev_bs_upgrade")
-- Rewards
local rev_RebirthRequest = safeRE(Net, "rev_RebirthRequest")
local rev_Offline_Claim  = safeRE(Net, "rev_Offline_Claim")
local rev_ClaimFree      = safeRE(Net, "rev_ClaimFree")
local rev_GroupClaim     = safeRE(Net, "rev_GroupClaim")
local rev_RequestSpin    = safeRE(Net, "rev_RequestSpin")
local rev_SpinWheel      = safeRE(Net, "rev_SpinWheel")
local rev_open_random    = safeRE(Net, "rev_open_random")
local rev_LB_OpenRequest = safeRE(Net, "rev_LB_OpenRequest")
-- Tutorial + misc
local rev_TutorialStep  = safeRE(Net, "rev_TutorialStep")

---------- CONFIG (v5: getgenv-backed for zombie-kill) ----------
if not getgenv().__AURORA_KAL_CFG2 then
    getgenv().__AURORA_KAL_CFG2 = {
        -- Kick loop
        AutoKick              = false,
        AutoCollect           = false,
        AutoUpgrade           = false,
        AutoInteract          = false,
        AutoSellAll           = false,
        -- Shop + upgrades
        AutoSpeedUpgrade      = false,
        AutoBuyWeight         = false,
        AutoBSUpgrade         = false,
        AutoEquipBest         = false,
        -- Rewards
        AutoRebirth           = false,
        AutoSpinWheel         = false,
        AutoClaimFree         = false,
        AutoOfflineClaim      = false,
        AutoGroupClaim        = false,
        AutoOpenRandom        = false,
        -- Utility
        AntiAFK               = false,
        WalkSpeedBoost        = false,
        SkipTutorial          = false,
        -- Targets / values (default to top-tier weight; user overrides via dropdown)
        TargetWeight          = "Giant Gold Star Barbell",
        WalkSpeedValue        = 40,
        AutoSave              = false,
        -- v5 UI state
        ActiveTab             = "Kick",
        PanelOpen             = true,
    }
else
    local c = getgenv().__AURORA_KAL_CFG2
    if c.ActiveTab == nil then c.ActiveTab = "Kick" end
    if c.PanelOpen == nil then c.PanelOpen = true end
    if c.TargetWeight == nil then c.TargetWeight = "Giant Gold Star Barbell" end
    if c.WalkSpeedValue == nil then c.WalkSpeedValue = 40 end
    if c.AutoSave == nil then c.AutoSave = false end
end
local CFG = getgenv().__AURORA_KAL_CFG2

---------- TOGGLE SAVE/LOAD ----------
local _cfgFileName = "aurora_cfg_kick_a_lucky_block.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() if _HAS.readfile then saved = HttpService:JSONDecode(readfile(_cfgFileName)) end end)
    if not saved then saved = getgenv()["AuroraCFG_kick_a_lucky_block"] end
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
    end
end

local function saveCFG()
    pcall(function() if _HAS.writefile then writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end end)
    getgenv()["AuroraCFG_kick_a_lucky_block"] = CFG
end

loadSavedCFG()

---------- STATE ----------
local S = {
    kicks = 0, collects = 0, upgrades = 0, interacts = 0, sells = 0,
    speedUps = 0, shopBuys = 0, rebirths = 0, spins = 0, claims = 0, openBoxes = 0,
}
local _sessionStart = tick()
local _kickPos = nil  -- CFrame captured on AutoKick enable / Set Kick Zone Here

---------- ANTI-ANTICHEAT: disable client-side WalkSpeed monitor ----------
task.spawn(function()
    task.wait(0.4)
    pcall(function()
        local ak = Player.PlayerScripts:FindFirstChild("AntiKick")
        if ak then ak.Disabled = true end
    end)
    -- Re-disable on respawn (AntiKick may reinit)
    Player.CharacterAdded:Connect(function()
        task.wait(0.3)
        pcall(function()
            local ak = Player.PlayerScripts:FindFirstChild("AntiKick")
            if ak then ak.Disabled = true end
        end)
    end)
end)

---------- GAME DATA (from ReplicatedStorage.Shared.Data modules) ----------
-- Slots are PER-PLAYER plots. rev_B_* args are slot numbers within YOUR plot.
-- Fallback range covers end-game players with 20+ unlocked slots.
local SLOT_FALLBACK = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}
local SPEED_SLOTS = {1, 2, 3, 4, 5}  -- SPEED_UPGRADE takes slot index
local BS_SLOTS = {1, 2, 3, 4, 5}  -- bs_upgrade takes similar index

-- Dynamically find slot numbers the player actually has placed in their owned plot.
-- Falls back to 1..20 if detection fails (e.g. owner attribute missing).
local function getMySlots()
    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then return SLOT_FALLBACK end
    local myName = Player.Name
    for _, plot in ipairs(Plots:GetChildren()) do
        if plot:GetAttribute("Owner") == myName then
            local folder = plot:FindFirstChild("Slots")
            if folder then
                local found = {}
                for _, slot in ipairs(folder:GetChildren()) do
                    if slot:FindFirstChild("PlacedPart") then
                        local n = tonumber(tostring(slot.Name):match("%d+"))
                        if n then table.insert(found, n) end
                    end
                end
                if #found > 0 then return found end
            end
            -- Owner matched but no placed slots detected; still return fallback
            return SLOT_FALLBACK
        end
    end
    return SLOT_FALLBACK  -- owner not matched (loading / unassigned)
end

-- Weight catalog (from WeightsData module — sorted by power)
local WEIGHTS = {
    "Wooden Stick", "Bone Barbell", "Stone Block", "Copper Plate",
    "Iron Plate", "Ice Barbell", "Donut Barbell", "Golden Barbell",
    "Heaven Plate", "Mega Golden Barbell", "Neon Pulse", "Giant Gold Star Barbell",
}

local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- CORE ACTIONS ----------

-- Save/restore kick position helpers
local function captureKickPos()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then _kickPos = hrp.CFrame end
end
local function tpToKickPos()
    if not _kickPos then return end
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then pcall(function() hrp.CFrame = _kickPos end) end
end

-- Safe-zone check: is HumanoidRootPart inside workspace.Zones.CollectZone?
local _cachedZone
local function getSafeZone()
    if _cachedZone and _cachedZone.Parent then return _cachedZone end
    local Z = workspace:FindFirstChild("Zones")
    _cachedZone = Z and Z:FindFirstChild("CollectZone") or nil
    return _cachedZone
end
local function isInSafeZone()
    local cz = getSafeZone()
    if not cz then return true end  -- fail open if zone not found
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local p = hrp.Position
    local cp, cs = cz.Position, cz.Size
    return math.abs(p.X - cp.X) <= cs.X / 2
        and math.abs(p.Y - cp.Y) <= cs.Y / 2 + 15
        and math.abs(p.Z - cp.Z) <= cs.Z / 2
end
-- Block until we're back inside the safe zone (re-TP each cycle)
local function waitForSafeZone(maxWait)
    local deadline = tick() + (maxWait or 4)
    while tick() < deadline do
        if not alive() then return false end
        if isInSafeZone() then return true end
        tpToKickPos()
        task.wait(0.15)
    end
    return isInSafeZone()
end

-- Kick cycle (fixed-time, measured): full flow observed on live probe from T=0 KickZman fire:
--   T≈3.7s-9.5s  My rarity roll shows in Debris (Common→Rare→Epic→Legendary→named brainrot)
--   T≈9.5s-13s   Celebration burst: confetti + brainrot placement animations
-- Because Debris is SHARED with other players (their named brainrots also spawn there), event
-- detection misfires. Instead we use a fixed 13s cycle and spam KickCollect on every new Model
-- in Debris during the wait — that acks both our roll reveals and (harmlessly) others' spawns.
local RARITY_NAMES = {
    Common=true, Rare=true, Epic=true, Legendary=true, Mythic=true,
    Godly=true, Secret=true, Divine=true, Rainbow=true, Hacked=true,
    Demon=true, OG=true,
}

local function doKickCycle()
    if not rev_KickZman then return end
    if not _kickPos then captureKickPos() end

    -- Ensure we're inside CollectZone before firing — server rejects kicks from outside
    -- and stale _kickPos after respawn can leave us in a bad spot. This re-TPs if needed.
    waitForSafeZone(2)

    local debris = workspace:FindFirstChild("Debris")

    -- Hook Debris for KickCollect acks (fires for every Model spawn during our roll window)
    local conn
    if debris and rev_KickCollect then
        conn = debris.ChildAdded:Connect(function(c)
            if c:IsA("Model") then
                task.defer(function() pcall(function() rev_KickCollect:FireServer() end) end)
            end
        end)
    end

    -- Fire the kick — each remote exactly once
    if rev_KickEvent then pcall(function() rev_KickEvent:FireServer(1) end) end
    pcall(function() rev_KickZman:FireServer() end)

    -- Full cycle wait: 13s covers fly (3.7s) + roll (5.5s) + transform (1s) + celebration (2.8s)
    task.wait(13)
    if conn then conn:Disconnect() end
    if not alive() then return end

    -- Ceremony fully done — Transformed ack + final KickCollect
    if rev_Transformed then pcall(function() rev_Transformed:FireServer() end) end
    task.wait(0.1)
    if rev_KickCollect then pcall(function() rev_KickCollect:FireServer() end) end

    -- Safely return to kick zone for the next cycle
    tpToKickPos()
    task.wait(0.2)

    S.kicks += 1
end

-- Collect from every placed slot in your plot
local function doCollect()
    if not rev_B_Collect then return end
    for _, id in ipairs(getMySlots()) do
        pcall(function() rev_B_Collect:FireServer(id) end)
    end
    S.collects += 1
end

-- Upgrade every placed slot (spam — server caps via cost)
local function doUpgrade()
    if not rev_B_Upgrade then return end
    for _, id in ipairs(getMySlots()) do
        for _ = 1, 3 do
            pcall(function() rev_B_Upgrade:FireServer(id) end)
        end
    end
    S.upgrades += 1
end

-- Interact with every placed slot
local function doInteract()
    if not rev_S_Interact then return end
    for _, id in ipairs(getMySlots()) do
        pcall(function() rev_S_Interact:FireServer(id) end)
    end
    S.interacts += 1
end

-- Sell all weights (RemoteFunction)
local function doSellAll()
    if not ref_B_SellAll then return end
    pcall(function() ref_B_SellAll:InvokeServer() end)
    S.sells += 1
end

-- Speed upgrade: spam every slot (server enforces cost)
local function doSpeedUpgrade()
    if not rev_SPEED_UPGRADE then return end
    for _, slot in ipairs(SPEED_SLOTS) do
        for _ = 1, 3 do
            pcall(function() rev_SPEED_UPGRADE:FireServer(slot) end)
        end
    end
    S.speedUps += 1
end

-- bs_upgrade: spam every slot
local function doBSUpgrade()
    if not rev_bs_upgrade then return end
    for _, slot in ipairs(BS_SLOTS) do
        for _ = 1, 3 do
            pcall(function() rev_bs_upgrade:FireServer(slot) end)
        end
    end
end

-- Buy target weight from WeightShop
local function doBuyTargetWeight()
    if not rev_Shop_Buy then return end
    pcall(function() rev_Shop_Buy:FireServer("WeightShop", CFG.TargetWeight) end)
    S.shopBuys += 1
end

-- Try to buy every weight we don't own (server rejects owned ones via cost)
local function doBuyAllWeights()
    if not rev_Shop_Buy then return end
    for _, wname in ipairs(WEIGHTS) do
        pcall(function() rev_Shop_Buy:FireServer("WeightShop", wname) end)
        task.wait(0.15)
        if not alive() then return end
    end
    S.shopBuys += 1
end

-- Equip best weight (fires WeightEquip with target name)
local function doEquipBest()
    if not rev_WeightEquip then return end
    pcall(function() rev_WeightEquip:FireServer(CFG.TargetWeight) end)
end

-- Rebirth
local function doRebirth()
    if not rev_RebirthRequest then return end
    pcall(function() rev_RebirthRequest:FireServer() end)
    S.rebirths += 1
end

-- Spin wheel
local function doSpinWheel()
    if rev_RequestSpin then pcall(function() rev_RequestSpin:FireServer() end) end
    task.wait(0.2)
    if rev_SpinWheel then pcall(function() rev_SpinWheel:FireServer() end) end
    S.spins += 1
end

-- Claim free reward
local function doClaimFree()
    if not rev_ClaimFree then return end
    pcall(function() rev_ClaimFree:FireServer() end)
    S.claims += 1
end

-- Offline claim
local function doOfflineClaim()
    if not rev_Offline_Claim then return end
    pcall(function() rev_Offline_Claim:FireServer() end)
    S.claims += 1
end

-- Group claim
local function doGroupClaim()
    if not rev_GroupClaim then return end
    pcall(function() rev_GroupClaim:FireServer() end)
    S.claims += 1
end

-- Open random box
local function doOpenRandom()
    if not rev_open_random then return end
    pcall(function() rev_open_random:FireServer() end)
    S.openBoxes += 1
end

-- Skip tutorial: fire step 16 (max captured)
local function doSkipTutorial()
    if not rev_TutorialStep then return end
    for step = 1, 20 do
        pcall(function() rev_TutorialStep:FireServer(step) end)
        task.wait(0.05)
    end
end

---------- LOOPS ----------
-- Auto Kick: full ~9-10s cycle per kick (rolling reveal + brainrot + TP back)
task.spawn(function()
    while alive() do
        if CFG.AutoKick then pcall(doKickCycle) end
        task.wait(jitter(0.3, 0.15))
        if not alive() then break end
    end
end)

-- Auto Collect: every 2s
task.spawn(function()
    while alive() do
        if CFG.AutoCollect then pcall(doCollect) end
        task.wait(jitter(2, 0.6))
        if not alive() then break end
    end
end)

-- Auto Upgrade: every 3s
task.spawn(function()
    while alive() do
        if CFG.AutoUpgrade then pcall(doUpgrade) end
        task.wait(jitter(3, 0.9))
        if not alive() then break end
    end
end)

-- Auto Interact: every 5s
task.spawn(function()
    while alive() do
        if CFG.AutoInteract then pcall(doInteract) end
        task.wait(jitter(5, 1.5))
        if not alive() then break end
    end
end)

-- Auto Sell: every 8s
task.spawn(function()
    while alive() do
        if CFG.AutoSellAll then pcall(doSellAll) end
        task.wait(jitter(8, 2.4))
        if not alive() then break end
    end
end)

-- Auto Speed Upgrade: every 6s
task.spawn(function()
    while alive() do
        if CFG.AutoSpeedUpgrade then pcall(doSpeedUpgrade) end
        task.wait(jitter(6, 1.8))
        if not alive() then break end
    end
end)

-- Auto BS Upgrade: every 6s
task.spawn(function()
    while alive() do
        if CFG.AutoBSUpgrade then pcall(doBSUpgrade) end
        task.wait(jitter(6, 1.8))
        if not alive() then break end
    end
end)

-- Auto Buy Weight: every 12s
task.spawn(function()
    while alive() do
        if CFG.AutoBuyWeight then pcall(doBuyTargetWeight) end
        task.wait(jitter(12, 3.6))
        if not alive() then break end
    end
end)

-- Auto Equip Best: every 30s
task.spawn(function()
    while alive() do
        if CFG.AutoEquipBest then pcall(doEquipBest) end
        task.wait(jitter(30, 9))
        if not alive() then break end
    end
end)

-- Auto Rebirth: every 20s
task.spawn(function()
    while alive() do
        if CFG.AutoRebirth then pcall(doRebirth) end
        task.wait(jitter(20, 6))
        if not alive() then break end
    end
end)

-- Auto Spin: every 25s
task.spawn(function()
    while alive() do
        if CFG.AutoSpinWheel then pcall(doSpinWheel) end
        task.wait(jitter(25, 7.5))
        if not alive() then break end
    end
end)

-- Auto Claim Free: every 45s
task.spawn(function()
    while alive() do
        if CFG.AutoClaimFree then pcall(doClaimFree) end
        task.wait(jitter(45, 13))
        if not alive() then break end
    end
end)

-- Auto Offline Claim: every 60s
task.spawn(function()
    while alive() do
        if CFG.AutoOfflineClaim then pcall(doOfflineClaim) end
        task.wait(jitter(60, 18))
        if not alive() then break end
    end
end)

-- Auto Group Claim: every 90s
task.spawn(function()
    while alive() do
        if CFG.AutoGroupClaim then pcall(doGroupClaim) end
        task.wait(jitter(90, 27))
        if not alive() then break end
    end
end)

-- Auto Open Random: every 15s
task.spawn(function()
    while alive() do
        if CFG.AutoOpenRandom then pcall(doOpenRandom) end
        task.wait(jitter(15, 4.5))
        if not alive() then break end
    end
end)

-- Skip Tutorial: one-shot when toggled ON
task.spawn(function()
    local _last = false
    while alive() do
        if CFG.SkipTutorial and not _last then
            pcall(doSkipTutorial)
            _last = true
        elseif not CFG.SkipTutorial then
            _last = false
        end
        task.wait(1)
        if not alive() then break end
    end
end)

-- Anti-AFK
task.spawn(function()
    while alive() do
        if CFG.AntiAFK then
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.Space, false, nil)
                task.wait(0.1)
                vim:SendKeyEvent(false, Enum.KeyCode.Space, false, nil)
            end)
        end
        task.wait(120)
        if not alive() then break end
    end
end)

-- WalkSpeed boost — Heartbeat loop beats the AntiKick reset
task.spawn(function()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not alive() then if conn then conn:Disconnect() end return end
        if CFG.WalkSpeedBoost then
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.WalkSpeed ~= CFG.WalkSpeedValue then
                    pcall(function() hum.WalkSpeed = CFG.WalkSpeedValue or 40 end)
                end
            end
        end
    end)
end)

-- One-shot claims on load (small gaps so server doesn't rate-limit-drop any)
task.spawn(function()
    task.wait(3)
    if not alive() then return end
    pcall(function() if rev_Offline_Claim then rev_Offline_Claim:FireServer() end end)
    task.wait(0.3); if not alive() then return end
    pcall(function() if rev_ClaimFree then rev_ClaimFree:FireServer() end end)
    task.wait(0.3); if not alive() then return end
    pcall(function() if rev_GroupClaim then rev_GroupClaim:FireServer() end end)
end)

-- Respawn handler: after death, re-TP to the captured kick spot so auto-kick loop
-- doesn't get stuck firing from spawn point (which would fail the safe-zone check).
Player.CharacterAdded:Connect(function()
    task.wait(1.5)  -- let character finish loading
    if not alive() then return end
    if CFG.AutoKick and _kickPos then
        pcall(tpToKickPos)
    end
end)

-- ========================================================================
-- ========================================================================
-- V5 3-COLUMN UI (Sidebar + Panel Alpha + Panel Beta + Live Game + Pill)
-- ========================================================================
-- ========================================================================

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

local function create(cls, props, parent)
    local i = Instance.new(cls)
    if props then for k, v in pairs(props) do i[k] = v end end
    if parent then i.Parent = parent end
    return i
end
local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p; return c end
local function stroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or C.border; s.Thickness = th or 1; s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end
local function grad(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2)})
    g.Rotation = rot or 0; g.Parent = p; return g
end
local function padAll(p, v)
    local pp = Instance.new("UIPadding")
    pp.PaddingTop = UDim.new(0, v); pp.PaddingBottom = UDim.new(0, v)
    pp.PaddingLeft = UDim.new(0, v); pp.PaddingRight = UDim.new(0, v); pp.Parent = p; return pp
end
local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local TOTAL_W   = 1080
local TOTAL_H   = 620
local SIDEBAR_W = 168
local PA_W      = 350
local PB_W      = 350
local LG_W      = TOTAL_W - SIDEBAR_W - PA_W - PB_W

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

local main = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    ClipsDescendants = true, Visible = CFG.PanelOpen,
}, screenGui)
corner(main, 14); stroke(main, C.border2, 1, 0)
if _scale ~= 1 then local sc = Instance.new("UIScale"); sc.Scale = _scale; sc.Parent = main end

local watermark = create("TextLabel", {
    Size = UDim2.fromOffset(800, 120),
    Position = UDim2.fromOffset(TOTAL_W / 2, TOTAL_H / 2),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
    Font = F_SANS_BOLD, TextSize = 72, TextColor3 = C.pink,
    TextTransparency = 0.82, TextStrokeTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 1,
}, main)
watermark.RichText = true
watermark.Text = '<font color="#FC6E8E">Dallaswebstudio</font><font color="#F5F5FA">.net</font>'

local content = create("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2,
}, main)

---------- SIDEBAR ----------
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
    Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(14, 15),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181",
    ScaleType = Enum.ScaleType.Fit, ImageColor3 = C.white,
}, wordmarkRow)
local wordmark = create("TextLabel", {
    Size = UDim2.fromOffset(SIDEBAR_W - 44, 24), Position = UDim2.fromOffset(42, 15),
    BackgroundTransparency = 1, Font = F_SANS_BOLD, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    TextColor3 = C.text,
}, wordmarkRow)
wordmark.RichText = true
wordmark.Text = '<font color="#FC6E8E">Dallaswebstudio</font><font color="#F5F5FA">.net</font>'

create("Frame", {
    Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, 54),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, sidebar)

---------- TABS ----------
local TABS = {
    { name = "Kick",     icon = "●" },
    { name = "Shop",     icon = "▣" },
    { name = "Rewards",  icon = "◆" },
    { name = "Utility",  icon = "≡" },
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

local TAB_Y0, TAB_H, TAB_GAP = 66, 34, 3
local function makeTabRow(tinfo, yPos, dimInactive)
    local row = create("Frame", {
        Name = "Tab_" .. tinfo.name, Size = UDim2.fromOffset(SIDEBAR_W - 20, TAB_H),
        Position = UDim2.fromOffset(10, yPos),
        BackgroundColor3 = C.pink, BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = true,
    }, sidebar)
    corner(row, 6)
    local bgGrad = Instance.new("UIGradient")
    bgGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C.pink), ColorSequenceKeypoint.new(1, C.bg2)})
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
    tabMap[tinfo.name] = { bg = row, accent = accent, icon = icon, label = label, dimInactive = dimInactive or false }
    return row
end

local switchTab        = function(_) end
local _openPopup       = nil
local _skipNextOutside = false
local closeOpenPopup   = function() end

for idx, tinfo in ipairs(TABS) do
    local y = TAB_Y0 + (idx - 1) * (TAB_H + TAB_GAP)
    local row = makeTabRow(tinfo, y, false)
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            switchTab(tinfo.name)
        end
    end)
end

local SET_H, SET_PAD = 36, 10
local SET_Y = TOTAL_H - SET_H - SET_PAD
create("Frame", {
    Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, SET_Y - 6),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, sidebar)
local setRow = makeTabRow({ name = "Settings", icon = "⚙" }, SET_Y, true)
setRow.Size = UDim2.fromOffset(SIDEBAR_W - 20, SET_H)
setRow.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        switchTab("Settings")
    end
end)

---------- PANEL FACTORY ----------
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

local TAB_NAMES = { "Kick", "Shop", "Rewards", "Utility", "Settings" }
local TAB_ACCENT = {
    Kick     = C.pink,
    Shop     = C.purple,
    Rewards  = C.pink,
    Utility  = C.purple,
    Settings = C.pink,
}
local PANEL_TITLES = {
    Kick     = { alpha = "KICK LOOP",  beta = "KICK STATUS"   },
    Shop     = { alpha = "UPGRADES",   beta = "SHOP STATUS"   },
    Rewards  = { alpha = "REWARDS",    beta = "CLAIM STATUS"  },
    Utility  = { alpha = "UTILITY",    beta = "PLAYER"        },
    Settings = { alpha = "CONFIG",     beta = "ABOUT"         },
}

local scrolls = {}
for _, tn in ipairs(TAB_NAMES) do
    local acc = TAB_ACCENT[tn]
    local t   = PANEL_TITLES[tn]
    scrolls[tn .. "_alpha"] = makePanel(tn, "alpha", SIDEBAR_W,        PA_W, acc, t.alpha)
    scrolls[tn .. "_beta"]  = makePanel(tn, "beta",  SIDEBAR_W + PA_W, PB_W, acc, t.beta)
end

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

switchTab = function(tabName)
    if not panels[tabName] then tabName = "Kick" end
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

;(function()  -- IIFE: separate function scope to escape Luau's 200-local cap
---------- COMPONENTS ----------
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
    trackGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C.pink), ColorSequenceKeypoint.new(1, C.purple)})
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
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
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
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
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
        BackgroundTransparency = 1, Text = tostring(initialVal or "---"),
        Font = F_MONO, TextSize = 10, TextColor3 = valColor or C.text2,
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    return val
end

-- Weight cycle-pill (cycles through WEIGHTS list)
local function weightCycleRow(parent, order, onChange)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Text = "Target",
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local pill = create("Frame", {
        Size = UDim2.fromOffset(200, 22), Position = UDim2.new(1, -200, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)
    local wLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = CFG.TargetWeight or "Bone Barbell",
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)
    create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▶",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)
    local _idx = 1
    for i, wn in ipairs(WEIGHTS) do if wn == CFG.TargetWeight then _idx = i; break end end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            _idx = (_idx % #WEIGHTS) + 1
            CFG.TargetWeight = WEIGHTS[_idx]
            wLabel.Text = CFG.TargetWeight
            if CFG.AutoSave then saveCFG() end
            if onChange then onChange() end
        end
    end)
    return row, wLabel
end

-- WalkSpeed slider (20-200)
local function walkSpeedSlider(parent, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.fromOffset(0, 2),
        BackgroundTransparency = 1, Text = "WalkSpeed",
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local valLabel = create("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.new(0.5, 0, 0, 2),
        BackgroundTransparency = 1, Text = tostring(CFG.WalkSpeedValue),
        Font = F_MONO, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local trackFrame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 30),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true,
    }, row)
    corner(trackFrame, 3); stroke(trackFrame, C.border2, 1, 0)
    local initFrac = math.clamp((CFG.WalkSpeedValue - 20) / 180, 0, 1)
    local fill = create("Frame", {
        Size = UDim2.new(initFrac, 0, 1, 0), BackgroundColor3 = C.pink, BorderSizePixel = 0,
    }, trackFrame)
    corner(fill, 3)
    local knob = create("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.new(initFrac, -7, 0.5, -7),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3,
    }, trackFrame)
    corner(knob, 7)
    local sliding = false
    local function updateSlider(inputX)
        local absPos = trackFrame.AbsolutePosition.X
        local absSize = trackFrame.AbsoluteSize.X
        if absSize <= 0 then return end
        local frac = math.clamp((inputX - absPos) / absSize, 0, 1)
        local val = math.floor(20 + frac * 180)
        CFG.WalkSpeedValue = val
        fill.Size = UDim2.new(frac, 0, 1, 0)
        knob.Position = UDim2.new(frac, -7, 0.5, -7)
        valLabel.Text = tostring(val)
        if CFG.AutoSave then saveCFG() end
    end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = true; updateSlider(inp.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(inp.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    return row
end

---------- POPULATE: KICK ----------
local oK_a, oK_b = 0, 0
local function nKa() oK_a = oK_a + 1; return oK_a end
local function nKb() oK_b = oK_b + 1; return oK_b end

sectionHeader(scrolls["Kick_alpha"], "●", "Kick Loop", nKa())
toggleRow    (scrolls["Kick_alpha"], "Auto Kick",          "AutoKick",     nKa(), function(on)
    if on then captureKickPos() end
end)
toggleRow    (scrolls["Kick_alpha"], "Auto Collect Plots", "AutoCollect",  nKa())
toggleRow    (scrolls["Kick_alpha"], "Auto Upgrade Plots", "AutoUpgrade",  nKa())
toggleRow    (scrolls["Kick_alpha"], "Auto Interact",      "AutoInteract", nKa())
toggleRow    (scrolls["Kick_alpha"], "Auto Sell All",      "AutoSellAll",  nKa())

sectionHeader(scrolls["Kick_alpha"], "▣", "Kick Zone", nKa())
actionBtn(scrolls["Kick_alpha"], "Set Kick Zone Here",  C.purple, nKa(), captureKickPos)
actionBtn(scrolls["Kick_alpha"], "TP to Kick Zone",     C.bg3,    nKa(), tpToKickPos)

sectionHeader(scrolls["Kick_alpha"], "⚙", "Manual", nKa())
actionBtn(scrolls["Kick_alpha"], "Kick Now",      C.bg3, nKa(), doKickCycle)
actionBtn(scrolls["Kick_alpha"], "Collect All",   C.bg3, nKa(), doCollect)
actionBtn(scrolls["Kick_alpha"], "Upgrade All",   C.bg3, nKa(), doUpgrade)
actionBtn(scrolls["Kick_alpha"], "Sell All",      C.green, nKa(), doSellAll)

sectionHeader(scrolls["Kick_alpha"], "✦", "Notes", nKa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 130), BackgroundTransparency = 1,
    Text = "Stand in the kick zone, then\ntoggle Auto Kick — position is\ncaptured on enable.\n\nFlow: TP to zone → KickEvent(1)\n→ KickZman → wait → TP back\n→ Transformed → KickCollect x2",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nKa(),
}, scrolls["Kick_alpha"])

sectionHeader(scrolls["Kick_beta"], "●", "Status", nKb())
local _infoMode     = infoRow(scrolls["Kick_beta"], "Mode",        "Idle", C.pink,  nKb())
local _infoRuntime  = infoRow(scrolls["Kick_beta"], "Runtime",     "0m",   C.text2, nKb())
local _infoCoins    = infoRow(scrolls["Kick_beta"], "Coins",       "---",  C.green, nKb())
local _infoKickPos  = infoRow(scrolls["Kick_beta"], "Kick Zone",   "Not set", C.pink, nKb())

sectionHeader(scrolls["Kick_beta"], "◉", "Session", nKb())
local _infoKicks    = infoRow(scrolls["Kick_beta"], "Kicks",       "0",    C.pink,  nKb())
local _infoCollects = infoRow(scrolls["Kick_beta"], "Collects",    "0",    C.pink,  nKb())
local _infoUpgrades = infoRow(scrolls["Kick_beta"], "Upgrades",    "0",    C.pink,  nKb())
local _infoInteracts = infoRow(scrolls["Kick_beta"], "Interacts",  "0",    C.pink,  nKb())
local _infoSells    = infoRow(scrolls["Kick_beta"], "Sell Cycles", "0",    C.pink,  nKb())

sectionHeader(scrolls["Kick_beta"], "✦", "Slots", nKb())
local _infoSlotCount = infoRow(scrolls["Kick_beta"], "Placed Slots", "---", C.pink, nKb())
local _infoSlotList  = infoRow(scrolls["Kick_beta"], "Slot IDs",     "---", C.text2, nKb())

---------- POPULATE: SHOP ----------
local oSh_a, oSh_b = 0, 0
local function nShA() oSh_a = oSh_a + 1; return oSh_a end
local function nShB() oSh_b = oSh_b + 1; return oSh_b end

sectionHeader(scrolls["Shop_alpha"], "●", "Upgrades", nShA())
toggleRow    (scrolls["Shop_alpha"], "Auto Speed Upgrade", "AutoSpeedUpgrade", nShA())
toggleRow    (scrolls["Shop_alpha"], "Auto BS Upgrade",    "AutoBSUpgrade",    nShA())

sectionHeader(scrolls["Shop_alpha"], "▣", "Weight Shop", nShA())
local _weightRow, _weightLabel = weightCycleRow(scrolls["Shop_alpha"], nShA(), nil)
toggleRow    (scrolls["Shop_alpha"], "Auto Buy Target",    "AutoBuyWeight",    nShA())
toggleRow    (scrolls["Shop_alpha"], "Auto Equip Target",  "AutoEquipBest",    nShA())

sectionHeader(scrolls["Shop_alpha"], "⚙", "Manual", nShA())
actionBtn(scrolls["Shop_alpha"], "Buy Target Weight", C.bg3, nShA(), doBuyTargetWeight)
actionBtn(scrolls["Shop_alpha"], "Buy All Weights",   C.bg3, nShA(), doBuyAllWeights)
actionBtn(scrolls["Shop_alpha"], "Equip Target",      C.bg3, nShA(), doEquipBest)
actionBtn(scrolls["Shop_alpha"], "Speed Upgrade Now", C.bg3, nShA(), doSpeedUpgrade)

sectionHeader(scrolls["Shop_alpha"], "✦", "Notes", nShA())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "ValidShops = WeightShop only.\nSpeedShop uses rev_SPEED_UPGRADE\ndirectly with slot 1-5.\n\nServer checks coins before\ngranting — spamming is safe.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nShA(),
}, scrolls["Shop_alpha"])

sectionHeader(scrolls["Shop_beta"], "●", "Shop Status", nShB())
local _infoSpeed    = infoRow(scrolls["Shop_beta"], "Speed Cycles", "0", C.pink, nShB())
local _infoShopBuys = infoRow(scrolls["Shop_beta"], "Shop Buys",    "0", C.pink, nShB())
local _infoTarget   = infoRow(scrolls["Shop_beta"], "Target",       CFG.TargetWeight or "---", C.pink, nShB())

sectionHeader(scrolls["Shop_beta"], "◉", "Weight Catalog", nShB())
local WEIGHT_INFO = {
    {"Wooden Stick",           "Common",     "2"},
    {"Bone Barbell",           "Rare",       "5"},
    {"Stone Block",            "Epic",       "10"},
    {"Copper Plate",           "Legendary",  "50"},
    {"Iron Plate",             "Mythic",     "150"},
    {"Ice Barbell",            "Godly",      "400"},
    {"Donut Barbell",          "Secret",     "1K"},
    {"Golden Barbell",         "Divine",     "2.5K"},
    {"Heaven Plate",           "Rainbow",    "6.25K"},
    {"Mega Golden Barbell",    "Hacked",     "15K"},
    {"Neon Pulse",             "Demon",      "40K"},
    {"Giant Gold Star Barbell","OG",         "100K"},
}
for _, w in ipairs(WEIGHT_INFO) do
    infoRow(scrolls["Shop_beta"], w[1], w[3] .. " PPS", w[1] == CFG.TargetWeight and C.pink or C.text2, nShB())
end

---------- POPULATE: REWARDS ----------
local oR_a, oR_b = 0, 0
local function nRa() oR_a = oR_a + 1; return oR_a end
local function nRb() oR_b = oR_b + 1; return oR_b end

sectionHeader(scrolls["Rewards_alpha"], "●", "Rebirth & Spins", nRa())
toggleRow    (scrolls["Rewards_alpha"], "Auto Rebirth",   "AutoRebirth",    nRa())
toggleRow    (scrolls["Rewards_alpha"], "Auto Spin Wheel","AutoSpinWheel",  nRa())
toggleRow    (scrolls["Rewards_alpha"], "Auto Open Random","AutoOpenRandom", nRa())

sectionHeader(scrolls["Rewards_alpha"], "◆", "Free Claims", nRa())
toggleRow    (scrolls["Rewards_alpha"], "Auto Claim Free",    "AutoClaimFree",    nRa())
toggleRow    (scrolls["Rewards_alpha"], "Auto Offline Claim", "AutoOfflineClaim", nRa())
toggleRow    (scrolls["Rewards_alpha"], "Auto Group Claim",   "AutoGroupClaim",   nRa())

sectionHeader(scrolls["Rewards_alpha"], "⚙", "Manual", nRa())
actionBtn(scrolls["Rewards_alpha"], "Rebirth Now",    C.green, nRa(), doRebirth)
actionBtn(scrolls["Rewards_alpha"], "Spin Wheel Now", C.bg3,   nRa(), doSpinWheel)
actionBtn(scrolls["Rewards_alpha"], "Open Random",    C.bg3,   nRa(), doOpenRandom)
actionBtn(scrolls["Rewards_alpha"], "Claim Free",     C.bg3,   nRa(), doClaimFree)
actionBtn(scrolls["Rewards_alpha"], "Claim Offline",  C.bg3,   nRa(), doOfflineClaim)
actionBtn(scrolls["Rewards_alpha"], "Claim Group",    C.bg3,   nRa(), doGroupClaim)

sectionHeader(scrolls["Rewards_beta"], "●", "Session", nRb())
local _infoRebirths = infoRow(scrolls["Rewards_beta"], "Rebirths", "0", C.pink,  nRb())
local _infoSpins    = infoRow(scrolls["Rewards_beta"], "Spins",    "0", C.pink,  nRb())
local _infoClaims   = infoRow(scrolls["Rewards_beta"], "Claims",   "0", C.pink,  nRb())
local _infoBoxes    = infoRow(scrolls["Rewards_beta"], "Boxes",    "0", C.pink,  nRb())

sectionHeader(scrolls["Rewards_beta"], "◉", "Wheel Rewards", nRb())
local WHEEL_REWARDS = {
    {"Brainrot Entity", "0.5%"},
    {"x10 Kick Power",  "1.5%"},
    {"x5 Kick Power",   "5%"},
    {"+50% Cash",       "8%"},
    {"+20% Cash",       "10%"},
    {"x2 Kick Power",   "15%"},
    {"+3 Speed",        "25%"},
    {"+1 Speed",        "35%"},
}
for _, w in ipairs(WHEEL_REWARDS) do
    infoRow(scrolls["Rewards_beta"], w[1], w[2], C.text2, nRb())
end

---------- POPULATE: UTILITY ----------
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "●", "Safety", nUa())
toggleRow    (scrolls["Utility_alpha"], "Anti-AFK",         "AntiAFK",        nUa())
toggleRow    (scrolls["Utility_alpha"], "Skip Tutorial",    "SkipTutorial",   nUa())

sectionHeader(scrolls["Utility_alpha"], "◉", "Movement", nUa())
toggleRow    (scrolls["Utility_alpha"], "WalkSpeed Boost",  "WalkSpeedBoost", nUa())
walkSpeedSlider(scrolls["Utility_alpha"], nUa())

sectionHeader(scrolls["Utility_alpha"], "✦", "Notes", nUa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "Skip Tutorial fires steps 1-20\nonce when toggled ON.\n\nWalkSpeed override: re-applied\nevery 1s (survives respawn).\n\nSome games reset WalkSpeed in\ntheir own loop — persistence\nkeeps it pinned.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUa(),
}, scrolls["Utility_alpha"])

sectionHeader(scrolls["Utility_beta"], "●", "Player", nUb())
local _infoHealth = infoRow(scrolls["Utility_beta"], "Health",    "---", C.text,  nUb())
local _infoWSpd   = infoRow(scrolls["Utility_beta"], "Speed",     "16",  C.text,  nUb())
local _infoPlace  = infoRow(scrolls["Utility_beta"], "PlaceId",   tostring(game.PlaceId), C.text2, nUb())
local _infoVer    = infoRow(scrolls["Utility_beta"], "Version",   tostring(game.PlaceVersion), C.text2, nUb())

sectionHeader(scrolls["Utility_beta"], "◉", "Server", nUb())
actionBtn(scrolls["Utility_beta"], "Rejoin Server", C.bg3, nUb(), function()
    pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, Player) end)
end)
actionBtn(scrolls["Utility_beta"], "Server Hop",    C.bg3, nUb(), function()
    pcall(function()
        local ts = game:GetService("TeleportService")
        local http = game:GetService("HttpService")
        local servers = game:HttpGetAsync("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        local data = http:JSONDecode(servers)
        if data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing and s.playing < s.maxPlayers and s.id ~= game.JobId then
                    ts:TeleportToPlaceInstance(game.PlaceId, s.id, Player)
                    return
                end
            end
        end
    end)
end)

sectionHeader(scrolls["Utility_beta"], "✦", "Tips", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Skip Tutorial is one-shot —\ntoggle OFF after firing.\n\nAnti-AFK sends Space every\n120s via VIM. Needs VIM\nsupport (most executors).",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUb(),
}, scrolls["Utility_beta"])

---------- POPULATE: SETTINGS ----------
local oS_a, oS_b = 0, 0
local function nSa() oS_a = oS_a + 1; return oS_a end
local function nSb() oS_b = oS_b + 1; return oS_b end

sectionHeader(scrolls["Settings_alpha"], "●", "Config", nSa())
toggleRow    (scrolls["Settings_alpha"], "Auto Save", "AutoSave", nSa())
actionBtn    (scrolls["Settings_alpha"], "Save Config Now", C.green, nSa(), function() saveCFG() end)
actionBtn    (scrolls["Settings_alpha"], "Load Config",     C.bg3,   nSa(), function()
    loadSavedCFG()
    if _weightLabel then _weightLabel.Text = CFG.TargetWeight or "Bone Barbell" end
end)
actionBtn    (scrolls["Settings_alpha"], "Reset Config",    C.red,   nSa(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    CFG.TargetWeight = "Giant Gold Star Barbell"
    CFG.WalkSpeedValue = 40
    CFG.AutoSave = true
    saveCFG()
    if _weightLabel then _weightLabel.Text = CFG.TargetWeight end
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSa())
actionBtn(scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn(scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.3)
    getgenv().__AURORA_KAL_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "Kick a Lucky Block",       C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),     C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion),C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Dallaswebstudio.net",      C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v5",                       C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,               C.text3, nSb())
infoRow(scrolls["Settings_beta"], "Network", "Shared.Packages.Network",  C.text3, nSb())
infoRow(scrolls["Settings_beta"], "Remotes", "60 mapped",                C.text3, nSb())

sectionHeader(scrolls["Settings_beta"], "◆", "Active Features", nSb())
local _cfgActiveLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 200),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nSb(),
}, scrolls["Settings_beta"])

---------- POPULATE: LIVE GAME ----------
local oL = 0
local function nL() oL = oL + 1; return oL end

sectionHeader(liveScroll, "◉", "Session", nL())
local _liveRuntime = infoRow(liveScroll, "Runtime", "0m",   C.text2, nL())
local _liveStatus  = infoRow(liveScroll, "Status",  "Idle", C.pink,  nL())
local _liveCoins   = infoRow(liveScroll, "Coins",   "---",  C.green, nL())

sectionHeader(liveScroll, "●", "Player", nL())
local _liveHealth  = infoRow(liveScroll, "Health", "---", C.text, nL())
local _liveSpeed   = infoRow(liveScroll, "Speed",  "16",  C.text, nL())

sectionHeader(liveScroll, "▣", "Kick", nL())
local _liveKicks    = infoRow(liveScroll, "Kicks",     "0", C.pink, nL())
local _liveCollects = infoRow(liveScroll, "Collects",  "0", C.pink, nL())
local _liveSells    = infoRow(liveScroll, "Sells",     "0", C.pink, nL())

sectionHeader(liveScroll, "◆", "Rewards", nL())
local _liveRebirths = infoRow(liveScroll, "Rebirths", "0", C.pink, nL())
local _liveSpins    = infoRow(liveScroll, "Spins",    "0", C.pink, nL())
local _liveClaims   = infoRow(liveScroll, "Claims",   "0", C.pink, nL())

sectionHeader(liveScroll, "✦", "Shop", nL())
local _liveShopBuys = infoRow(liveScroll, "Weights", "0", C.text2, nL())
local _liveSpeedUps = infoRow(liveScroll, "Speed",   "0", C.text2, nL())

---------- FLOATING PILL ----------
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

local pillDotGlow = create("Frame", {
    Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(9, 9),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.78,
    BorderSizePixel = 0, ZIndex = 1,
}, pill)
corner(pillDotGlow, 9)
local pillDotGlowInner = create("Frame", {
    Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(12, 12),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.55,
    BorderSizePixel = 0, ZIndex = 2,
}, pill)
corner(pillDotGlowInner, 6)
local pillDot = create("Frame", {
    Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(14, 14),
    BackgroundColor3 = C.green, BorderSizePixel = 0, ZIndex = 3,
}, pill)
corner(pillDot, 4)
task.spawn(function()
    local outerTween = TweenService:Create(pillDotGlow,
        TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.55, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(7, 7) })
    local innerTween = TweenService:Create(pillDotGlowInner,
        TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.35 })
    outerTween:Play(); innerTween:Play()
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
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        CFG.PanelOpen = not CFG.PanelOpen
        main.Visible = CFG.PanelOpen
    end
end)

---------- DRAG ----------
local topDragStrip = create("Frame", {
    Name = "TopDragStrip",
    Size = UDim2.fromOffset(TOTAL_W - SIDEBAR_W, 48),
    Position = UDim2.fromOffset(SIDEBAR_W, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ZIndex = 3,
}, content)

local _drag = { active = false, start = nil, startPos = nil }
local function attachDrag(handle)
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
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
    if _drag.active and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - _drag.start
        main.Position = UDim2.new(
            _drag.startPos.X.Scale, _drag.startPos.X.Offset + d.X,
            _drag.startPos.Y.Scale, _drag.startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        _drag.active = false
    end
end)

UIS.InputBegan:Connect(function(inp, processed)
    if not alive() then return end
    if _skipNextOutside then _skipNextOutside = false; return end
    if _openPopup and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
        local popup = _openPopup.frame
        local p0, ps = popup.AbsolutePosition, popup.AbsoluteSize
        local cx, cy = inp.Position.X, inp.Position.Y
        local inside = cx >= p0.X and cx <= p0.X + ps.X and cy >= p0.Y and cy <= p0.Y + ps.Y
        if not inside then closeOpenPopup() end
    end
end)

---------- CLOSE + MINIMIZE ----------
local minBtn = create("Frame", {
    Name = "Minimize", Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 62, 13),
    BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true, ZIndex = 5,
}, content)
corner(minBtn, 11); stroke(minBtn, C.border2, 1, 0)
local minLine = create("Frame", {
    Size = UDim2.fromOffset(10, 2), Position = UDim2.new(0.5, -5, 0.5, -1),
    BackgroundColor3 = C.text2, BorderSizePixel = 0, ZIndex = 6,
}, minBtn)
corner(minLine, 1)
minBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        minBtn.BackgroundColor3 = C.pink; minLine.BackgroundColor3 = C.white
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        CFG.PanelOpen = false; main.Visible = false; closeOpenPopup()
    end
end)
minBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        minBtn.BackgroundColor3 = C.bg3; minLine.BackgroundColor3 = C.text2
    end
end)

local closeBtn = create("Frame", {
    Name = "Close", Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 32, 13),
    BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true, ZIndex = 5,
}, content)
corner(closeBtn, 11); stroke(closeBtn, C.border2, 1, 0)
local closeX = create("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "×",
    Font = F_SANS_BOLD, TextSize = 16, TextColor3 = C.text2, ZIndex = 6,
}, closeBtn)
closeBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.red; closeX.TextColor3 = C.white
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        getgenv().__AURORA_KAL_SESSION = 0
        task.wait(0.05)
        pcall(function() screenGui:Destroy() end)
        pcall(function() pillGui:Destroy() end)
    end
end)
closeBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.bg3; closeX.TextColor3 = C.text2
    end
end)

---------- STATUS UPDATE LOOP ----------
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.3))
        if not alive() then break end
        pcall(function()
            local hpTxt, spdTxt = "---", "16"
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hpTxt = string.format("%.0f/%.0f", hum.Health, hum.MaxHealth)
                    spdTxt = tostring(math.floor(hum.WalkSpeed))
                end
            end

            local coinsTxt = "---"
            pcall(function()
                local ls = Player:FindFirstChild("leaderstats")
                if ls then
                    local coins = ls:FindFirstChild("Coins")
                    if coins then coinsTxt = tostring(coins.Value) end
                end
            end)

            local slotsArr = getMySlots()
            local slotCountTxt, slotListTxt = "0", "---"
            if slotsArr and #slotsArr > 0 then
                slotCountTxt = tostring(#slotsArr)
                local sorted = {}
                for _, n in ipairs(slotsArr) do table.insert(sorted, n) end
                table.sort(sorted)
                local parts = {}
                for _, n in ipairs(sorted) do table.insert(parts, tostring(n)) end
                slotListTxt = table.concat(parts, ",")
                if #slotListTxt > 20 then slotListTxt = slotListTxt:sub(1, 18) .. ".." end
            end

            local elapsed = tick() - _sessionStart
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            local active = {}
            if CFG.AutoKick then table.insert(active, "Kick") end
            if CFG.AutoCollect then table.insert(active, "Col") end
            if CFG.AutoUpgrade then table.insert(active, "Upg") end
            if CFG.AutoInteract then table.insert(active, "Int") end
            if CFG.AutoSellAll then table.insert(active, "Sell") end
            if CFG.AutoSpeedUpgrade then table.insert(active, "Spd") end
            if CFG.AutoBuyWeight then table.insert(active, "Buy") end
            if CFG.AutoRebirth then table.insert(active, "Reb") end
            if CFG.AutoSpinWheel then table.insert(active, "Spin") end
            if CFG.AutoClaimFree then table.insert(active, "Free") end
            if CFG.AutoOfflineClaim then table.insert(active, "Off") end
            if CFG.AutoOpenRandom then table.insert(active, "Box") end

            local mode = #active > 0 and table.concat(active, " + ") or "Idle"
            if #mode > 28 then mode = (#active) .. " active" end

            _infoMode.Text        = mode
            _infoRuntime.Text     = rtime
            _infoCoins.Text       = coinsTxt
            if _kickPos then
                local p = _kickPos.Position
                _infoKickPos.Text = string.format("%.0f,%.0f,%.0f", p.X, p.Y, p.Z)
            else
                _infoKickPos.Text = "Not set"
            end
            _infoKicks.Text       = fmt(S.kicks)
            _infoSlotCount.Text   = slotCountTxt
            _infoSlotList.Text    = slotListTxt
            _infoCollects.Text    = fmt(S.collects)
            _infoUpgrades.Text    = fmt(S.upgrades)
            _infoInteracts.Text   = fmt(S.interacts)
            _infoSells.Text       = fmt(S.sells)

            _infoSpeed.Text       = fmt(S.speedUps)
            _infoShopBuys.Text    = fmt(S.shopBuys)
            _infoTarget.Text      = CFG.TargetWeight or "---"

            _infoRebirths.Text    = fmt(S.rebirths)
            _infoSpins.Text       = fmt(S.spins)
            _infoClaims.Text      = fmt(S.claims)
            _infoBoxes.Text       = fmt(S.openBoxes)

            _infoHealth.Text      = hpTxt
            _infoWSpd.Text        = spdTxt

            _liveRuntime.Text     = rtime
            _liveStatus.Text      = mode
            _liveCoins.Text       = coinsTxt
            _liveHealth.Text      = hpTxt
            _liveSpeed.Text       = spdTxt
            _liveKicks.Text       = fmt(S.kicks)
            _liveCollects.Text    = fmt(S.collects)
            _liveSells.Text       = fmt(S.sells)
            _liveRebirths.Text    = fmt(S.rebirths)
            _liveSpins.Text       = fmt(S.spins)
            _liveClaims.Text      = fmt(S.claims)
            _liveShopBuys.Text    = fmt(S.shopBuys)
            _liveSpeedUps.Text    = fmt(S.speedUps)

            local sortedActive = {}
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" then
                    table.insert(sortedActive, "· " .. k)
                end
            end
            table.sort(sortedActive)
            _cfgActiveLabel.Text = #sortedActive > 0 and table.concat(sortedActive, "\n") or "None"
            _pillActive.Text = #sortedActive .. " active"
        end)
    end
end)

end)()  -- close IIFE started before COMPONENTS

---------- INIT ----------
switchTab(CFG.ActiveTab or "Kick")
