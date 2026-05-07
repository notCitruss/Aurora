--// Aurora v5.1 — Timber!
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 96840410521899
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// ByteNet direct buffer bypass — auto-chop, collect, sell — PRESERVED VERBATIM
--// v5.1: +AutoDaily +AutoFreeSap +AutoGroupReward +AutoMarketRestock
--//       +AutoHiddenTrees +AutoDismissChangelog +InfJump +HighlightTarget
--//       +NPC TPs +Mutation counter +Item reward counter

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

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_TIMBER_CFG2 then
    for k, v in pairs(getgenv().__AURORA_TIMBER_CFG2) do
        if type(v) == "boolean" then getgenv().__AURORA_TIMBER_CFG2[k] = false end
    end
end
task.wait(0.15)

getgenv().__AURORA_TIMBER_SESSION = tick()
local _mySession = getgenv().__AURORA_TIMBER_SESSION
local function alive() return getgenv().__AURORA_TIMBER_SESSION == _mySession end

---------- BYTENET DIRECT SEND (preserved verbatim from v4) ----------
-- Type-safe remote lookup: returns the child only if it's the expected class
local function safeRE(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteEvent")) and obj or nil
end
local function safeRF(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteFunction")) and obj or nil
end

local ByteNetEvent = safeRE(RS, "ByteNetReliable")
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

-- v5.1: new 1-byte send functions (all confirmed accepted by server)
local function sendLoginBonus()
    if not PID.login_bonus_claim then return end
    local buf = buffer.create(1)
    buffer.writeu8(buf, 0, PID.login_bonus_claim)
    ByteNetEvent:FireServer(buf)
end

local function sendViewedChangelog()
    if not PID.viewed_changelog then return end
    local buf = buffer.create(1)
    buffer.writeu8(buf, 0, PID.viewed_changelog)
    ByteNetEvent:FireServer(buf)
end

local function sendMarketRestock()
    if not PID.market_restock then return end
    local buf = buffer.create(1)
    buffer.writeu8(buf, 0, PID.market_restock)
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
local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- CONFIG (v5: getgenv-backed for zombie-kill) ----------
if not getgenv().__AURORA_TIMBER_CFG2 then
    getgenv().__AURORA_TIMBER_CFG2 = {
        -- v4 keys preserved exactly
        AutoChop     = false,
        ChopNoTP     = false,
        AutoCollect  = false,
        AutoSell     = false,
        AutoQuest    = false,
        SpeedBoost   = false,
        AntiAFK      = false,
        SelectedZone = 1,
        ChopTreeTypes = {},
        AutoSave     = true,
        -- v5 UI state
        ActiveTab    = "Farm",
        PanelOpen    = true,
        -- v5.1 additions (all default OFF)
        AutoDaily          = false,
        AutoFreeSapling    = false,
        AutoGroupReward    = false,
        AutoHiddenTrees    = false,
        AutoDismissChangelog = false,
        AutoMarketRestock  = false,
        InfJump            = false,
        HighlightTarget    = false,
    }
else
    local c = getgenv().__AURORA_TIMBER_CFG2
    if c.ActiveTab == nil then c.ActiveTab = "Farm" end
    if c.PanelOpen == nil then c.PanelOpen = true end
    -- v5.1 back-compat: only set if nil (preserve user toggle state on re-run)
    if c.AutoDaily == nil then c.AutoDaily = false end
    if c.AutoFreeSapling == nil then c.AutoFreeSapling = false end
    if c.AutoGroupReward == nil then c.AutoGroupReward = false end
    if c.AutoHiddenTrees == nil then c.AutoHiddenTrees = false end
    if c.AutoDismissChangelog == nil then c.AutoDismissChangelog = false end
    if c.AutoMarketRestock == nil then c.AutoMarketRestock = false end
    if c.InfJump == nil then c.InfJump = false end
    if c.HighlightTarget == nil then c.HighlightTarget = false end
    if type(c.ChopTreeTypes) ~= "table" then c.ChopTreeTypes = {} end
end
local CFG = getgenv().__AURORA_TIMBER_CFG2

---------- TOGGLE SAVE/LOAD (preserved v4 filename) ----------
local _cfgFileName = "aurora_cfg_timber_autofarm.json"

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
    pcall(function() if _HAS.writefile then writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end end)
    getgenv()["AuroraCFG_timber_autofarm"] = CFG
end

loadSavedCFG()

---------- ZONE DATA (preserved verbatim from v4) ----------
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

---------- TREE TYPE FILTER (v5.2) ----------
-- Dropdown categories map to Workspace.Trees Name prefix (e.g. oak_1047274677 → Oak)
local TREE_CATEGORIES = {"Oak", "Birch", "Palm", "Sakura", "Redwood", "Blackthorn", "Ceiba", "Cedar", "Hazel", "Mushroom"}
local TREE_PREFIX_TO_CAT = {
    oak = "Oak", birch = "Birch", palm = "Palm", sakura = "Sakura",
    redwood = "Redwood", blackthorn = "Blackthorn", ceiba = "Ceiba",
    cedar = "Cedar", hazel = "Hazel", mushroom = "Mushroom",
}
-- Empty selection = allow all (preserves prior behavior). Unknown prefix falls through as allowed.
local function isTreeTypeAllowed(tree)
    local filt = CFG.ChopTreeTypes
    if type(filt) ~= "table" then return true end
    local any = false
    for _ in pairs(filt) do any = true; break end
    if not any then return true end
    local prefix = tree.Name:match("^([^_]+)")
    local cat = prefix and TREE_PREFIX_TO_CAT[prefix:lower()]
    if not cat then return true end
    return filt[cat] == true
end

---------- STATE (preserved verbatim from v4) ----------
local _currentTree = nil
local S = {hits = 0, treesDown = 0, collected = 0, sold = 0, session = tick()}

---------- HELPERS (preserved verbatim from v4) ----------
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
            if isTreeInZone(tree.PrimaryPart.Position) and isTreeTypeAllowed(tree) then
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

---------- LISTENERS (preserved verbatim from v4) ----------
pcall(function() Packets.tree_lumberjack_update.listen(function() S.hits += 1 end) end)
pcall(function() Packets.tree_despawn.listen(function() S.treesDown += 1 end) end)

-- v5.1: mutation tracker
S.mutations = 0
pcall(function()
    Packets.tree_mutation.listen(function() S.mutations += 1 end)
end)
-- v5.1: item reward notifier (free sapling result, etc.)
S.itemRewards = 0
pcall(function()
    Packets.item_reward_notify.listen(function() S.itemRewards += 1 end)
end)
pcall(function()
    Packets.free_sapling_result.listen(function() S.itemRewards += 1 end)
end)

---------- CORE LOOPS (preserved verbatim from v4) ----------
task.spawn(function()
    local _target = nil
    while alive() do
        task.wait(0.3)
        if not alive() then break end
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
    while alive() do
        task.wait(0.3)
        if not alive() then break end
        if not CFG.ChopNoTP then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local nearest, nearDist = nil, 30
            for _, t in game.Workspace.Trees:GetChildren() do
                if t:IsA("Model") and t.PrimaryPart and t:GetAttribute("Seed") and isTreeTypeAllowed(t) then
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
    while alive() do
        if not alive() then break end
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
    while alive() do
        if not alive() then break end
        if CFG.AutoSell then
            pcall(sendSell)
            S.sold += 1
        end
        task.wait(8)
    end
end)

local _speedOn = false
task.spawn(function()
    while alive() do
        task.wait(jitter(0.5, 0.5))
        if not alive() then break end
        pcall(function()
            local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if CFG.SpeedBoost then hum.WalkSpeed = 80; hum.JumpPower = 80; _speedOn = true
            elseif _speedOn then hum.WalkSpeed = 16; hum.JumpPower = 50; _speedOn = false end
        end)
    end
end)

task.spawn(function()
    while alive() do
        if not alive() then break end
        if CFG.AntiAFK then
            pcall(sendAfkRejoin)
            pcall(function() local v = game:GetService("VirtualUser"); v:CaptureController(); v:ClickButton2(Vector2.new()) end)
        end
        task.wait(60)
    end
end)

task.spawn(function()
    while alive() do
        if not alive() then break end
        if CFG.AutoQuest then
            pcall(sendQuestClaim)
        end
        task.wait(15)
    end
end)

---------- v5.1 LOOPS (all default OFF) ----------
-- Auto Claim Daily Login Bonus
task.spawn(function()
    while alive() do
        if not alive() then break end
        if CFG.AutoDaily then pcall(sendLoginBonus) end
        task.wait(90)
    end
end)

-- Auto Claim Free Sapling (5 min cycle; server will silently reject if cooldown)
task.spawn(function()
    while alive() do
        if not alive() then break end
        if CFG.AutoFreeSapling then pcall(sendFreeSapling) end
        task.wait(300)
    end
end)

-- Auto Claim Group Reward (5 min cycle)
task.spawn(function()
    while alive() do
        if not alive() then break end
        if CFG.AutoGroupReward then pcall(sendJoinedGroup) end
        task.wait(300)
    end
end)

-- Auto Market Restock (3 min cycle)
task.spawn(function()
    while alive() do
        if not alive() then break end
        if CFG.AutoMarketRestock then pcall(sendMarketRestock) end
        task.wait(180)
    end
end)

-- Auto Collect Hidden Trees (plot-side tree cultivation rewards)
task.spawn(function()
    while alive() do
        if not alive() then break end
        if CFG.AutoHiddenTrees then
            pcall(function()
                local hidden = RS:FindFirstChild("HiddenTrees")
                if hidden then
                    for _, t in hidden:GetChildren() do
                        if t:GetAttribute("Owner") == Player.UserId and t:GetAttribute("Seed") then
                            pcall(sendCollectTree, t:GetAttribute("Seed"))
                        end
                    end
                end
            end)
        end
        task.wait(20)
    end
end)

-- Auto Dismiss Changelog (one-shot per session; harmless retries if key stays on)
task.spawn(function()
    local fired = false
    while alive() do
        if not alive() then break end
        if CFG.AutoDismissChangelog and not fired then
            pcall(sendViewedChangelog)
            fired = true
        elseif not CFG.AutoDismissChangelog then
            fired = false
        end
        task.wait(5)
    end
end)

-- Infinite Jump (client-side, no packet, no AC risk)
local _infJumpConn = nil
task.spawn(function()
    while alive() do
        task.wait(0.25)
        if not alive() then break end
        if CFG.InfJump and not _infJumpConn then
            _infJumpConn = UIS.JumpRequest:Connect(function()
                pcall(function()
                    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                end)
            end)
        elseif (not CFG.InfJump) and _infJumpConn then
            pcall(function() _infJumpConn:Disconnect() end)
            _infJumpConn = nil
        end
    end
end)

-- Highlight current AutoChop target (visual ESP-lite; managed orphan cleanup)
local _targetHighlight = nil
local _highlightedTree = nil
task.spawn(function()
    while alive() do
        task.wait(0.3)
        if not alive() then break end
        pcall(function()
            if not CFG.HighlightTarget then
                if _targetHighlight then
                    pcall(function() _targetHighlight:Destroy() end)
                    _targetHighlight = nil
                    _highlightedTree = nil
                end
                return
            end
            -- Find the current _currentTree reference via parsing name
            local trees = workspace:FindFirstChild("Trees")
            if not trees then return end
            -- Target the nearest highest-rate tree in selected zone (same as findBestTree)
            local best, bestRate = nil, 0
            for _, t in trees:GetChildren() do
                if t:IsA("Model") and t.PrimaryPart and t:GetAttribute("Seed") then
                    if isTreeInZone(t.PrimaryPart.Position) and isTreeTypeAllowed(t) then
                        local r = getTreeRate(t)
                        if r > bestRate and not isTreeOccupied(t) then
                            best, bestRate = t, r
                        end
                    end
                end
            end
            if best ~= _highlightedTree then
                if _targetHighlight then pcall(function() _targetHighlight:Destroy() end); _targetHighlight = nil end
                if best then
                    local h = Instance.new("Highlight")
                    h.Name = "AuroraTargetHL"
                    h.FillColor = Color3.fromRGB(252, 110, 142)
                    h.OutlineColor = Color3.fromRGB(255, 255, 255)
                    h.FillTransparency = 0.6
                    h.OutlineTransparency = 0.1
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Adornee = best
                    h.Parent = best
                    _targetHighlight = h
                    _highlightedTree = best
                end
            elseif best and _targetHighlight and not _targetHighlight.Parent then
                _targetHighlight = nil
                _highlightedTree = nil
            end
        end)
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
    { name = "Farm",    icon = "●" },
    { name = "Zones",   icon = "◆" },
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

local TAB_NAMES = { "Farm", "Zones", "Utility", "Settings" }
local TAB_ACCENT = {
    Farm     = C.pink,
    Zones    = C.purple,
    Utility  = C.pink,
    Settings = C.pink,
}
local PANEL_TITLES = {
    Farm     = { alpha = "AUTO FARM",   beta = "FARM STATUS" },
    Zones    = { alpha = "ZONES",       beta = "ZONE INFO"   },
    Utility  = { alpha = "PLAYER",      beta = "ACTIONS"     },
    Settings = { alpha = "CONFIG",      beta = "ABOUT"       },
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

-- dropdownRow(parent, label, cfgKey, options, order, multi?)
--   options: array of strings
--   multi=true → CFG[cfgKey] is a {[opt]=true,...} set (multi-select)
--   multi=false/nil → CFG[cfgKey] is a string (single-select)
local function dropdownRow(parent, label, cfgKey, options, order, multi)
    if multi then
        if type(CFG[cfgKey]) ~= "table" then CFG[cfgKey] = {} end
    else
        if CFG[cfgKey] == nil then CFG[cfgKey] = options[1] end
    end

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
        LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local pill = create("Frame", {
        Size = UDim2.fromOffset(92, 22), Position = UDim2.new(1, -92, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)

    local function displayText()
        if multi then
            local count, firstKey = 0, nil
            for k in pairs(CFG[cfgKey]) do
                count = count + 1
                if not firstKey then firstKey = k end
            end
            if count == 0 then return "All" end
            if count == 1 then return tostring(firstKey) end
            return count .. " selected"
        else
            return tostring(CFG[cfgKey] or "—")
        end
    end

    local valLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = displayText(),
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)

    local arrow = create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▼",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)

    -- Popup lives at screenGui root so it escapes panel/scroll clipping
    local POPUP_W = 140
    local OPT_H   = 26
    local POPUP_H = math.min(220, #options * (OPT_H + 2) + 8)

    local popup = create("Frame", {
        Name = "DropdownPopup_" .. cfgKey,
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
    local function isSelected(opt)
        if multi then return CFG[cfgKey][opt] == true end
        return CFG[cfgKey] == opt
    end

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
        corner(check, multi and 2 or 6)
        stroke(check, C.border2, 1, 0)
        local fill = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = C.pink, BorderSizePixel = 0,
            Visible = false, ZIndex = 54,
        }, check)
        corner(fill, multi and 2 or 6)

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
                if multi then
                    if CFG[cfgKey][o.opt] then CFG[cfgKey][o.opt] = nil
                    else CFG[cfgKey][o.opt] = true end
                else
                    CFG[cfgKey] = o.opt
                end
                paintOpts()
                valLabel.Text = displayText()
                if CFG.AutoSave then saveCFG() end
                if not multi then closeOpenPopup() end
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
            onClose = function() arrow.Text = "▼"; valLabel.Text = displayText() end,
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

    return row
end

-- Zone cycling selector (preserves v4 _selectedZone semantics)
local function zoneCycleRow(parent, order, onChange)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Text = "Zone",
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local pill = create("Frame", {
        Size = UDim2.fromOffset(180, 22), Position = UDim2.new(1, -180, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)
    local zoneLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = ZONE_NAMES[_selectedZone],
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
            _selectedZone = (_selectedZone % #ZONE_NAMES) + 1
            CFG.SelectedZone = _selectedZone
            zoneLabel.Text = ZONE_NAMES[_selectedZone]
            if CFG.AutoSave then saveCFG() end
            if onChange then onChange() end
        end
    end)
    return row, zoneLabel
end

--========================================================================
-- POPULATE: FARM
--========================================================================
local oF_a, oF_b = 0, 0
local function nFa() oF_a = oF_a + 1; return oF_a end
local function nFb() oF_b = oF_b + 1; return oF_b end

sectionHeader(scrolls["Farm_alpha"], "●", "Tree Chopping", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Chop",            "AutoChop",  nFa())
toggleRow    (scrolls["Farm_alpha"], "Chop Nearby (No TP)",  "ChopNoTP",  nFa())
dropdownRow  (scrolls["Farm_alpha"], "Tree Types",           "ChopTreeTypes", TREE_CATEGORIES, nFa(), true)

sectionHeader(scrolls["Farm_alpha"], "◉", "Resources", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Collect",          "AutoCollect",     nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Sell",             "AutoSell",        nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Quest",            "AutoQuest",       nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Hidden Trees",     "AutoHiddenTrees", nFa())
toggleRow    (scrolls["Farm_alpha"], "Highlight Best Tree",   "HighlightTarget", nFa())

sectionHeader(scrolls["Farm_alpha"], "▣", "Manual", nFa())
actionBtn(scrolls["Farm_alpha"], "Collect All Now", C.bg3, nFa(), function() pcall(sendCollectAll) end)
actionBtn(scrolls["Farm_alpha"], "Sell All Now",    C.bg3, nFa(), function() pcall(sendSell) end)

sectionHeader(scrolls["Farm_alpha"], "✦", "Notes", nFa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1,
    Text = "Auto Chop targets highest Rate tree\nin the zone + selected types.\nEmpty = all types allowed.\nChop Nearby uses any tree within\n30 studs matching the type filter.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nFa(),
}, scrolls["Farm_alpha"])

sectionHeader(scrolls["Farm_beta"], "●", "Target", nFb())
local _infoTree       = infoRow(scrolls["Farm_beta"], "Current Tree", "None", C.text,  nFb())
local _infoStatus     = infoRow(scrolls["Farm_beta"], "Status",       "Idle", C.pink,  nFb())

sectionHeader(scrolls["Farm_beta"], "◉", "Session Totals", nFb())
local _infoHits       = infoRow(scrolls["Farm_beta"], "Hits",         "0", C.pink,  nFb())
local _infoTreesDown  = infoRow(scrolls["Farm_beta"], "Trees Down",   "0", C.pink,  nFb())
local _infoCollected  = infoRow(scrolls["Farm_beta"], "Collected",    "0", C.pink,  nFb())
local _infoSold       = infoRow(scrolls["Farm_beta"], "Sold",         "0", C.pink,  nFb())
local _infoMutations  = infoRow(scrolls["Farm_beta"], "Mutations",    "0", C.purple, nFb())
local _infoRewards    = infoRow(scrolls["Farm_beta"], "Rewards",      "0", C.purple, nFb())

sectionHeader(scrolls["Farm_beta"], "✦", "Session", nFb())
local _infoRuntime    = infoRow(scrolls["Farm_beta"], "Runtime", "0m", C.text2, nFb())

--========================================================================
-- POPULATE: ZONES
--========================================================================
local oZ_a, oZ_b = 0, 0
local function nZa() oZ_a = oZ_a + 1; return oZ_a end
local function nZb() oZ_b = oZ_b + 1; return oZ_b end

sectionHeader(scrolls["Zones_alpha"], "●", "Zone Select", nZa())
local _zoneRow, _zoneLabel = zoneCycleRow(scrolls["Zones_alpha"], nZa(), nil)

sectionHeader(scrolls["Zones_alpha"], "◉", "Zone Teleports", nZa())
-- v5.1: deterministic order (ipairs over ZONE_NAMES) + skip "All Zones"
for _, zName in ipairs(ZONE_NAMES) do
    local zPos = ZONE_TP[zName]
    if zPos then
        actionBtn(scrolls["Zones_alpha"], zName, C.bg3, nZa(), function()
            pcall(function()
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(zPos + Vector3.new(0, 5, 0)) end
            end)
        end)
    end
end

sectionHeader(scrolls["Zones_alpha"], "▣", "Travel", nZa())
actionBtn(scrolls["Zones_alpha"], "Boat to Palm Cove", C.bg3, nZa(), function()
    pcall(function()
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(-41, 10, -707) end
    end)
    task.wait(0.5)
    pcall(sendBoatTravel, "PalmCove")
end)
actionBtn(scrolls["Zones_alpha"], "Boat Return", C.bg3, nZa(), function()
    pcall(sendBoatReturn)
end)

-- v5.1: NPC teleports (quest givers + market shopkeepers)
sectionHeader(scrolls["Zones_alpha"], "✦", "NPC Teleports", nZa())
local NPC_NAMES = {"Marcus", "Logan", "Lil Tin", "Kae", "Nelly", "Ayla", "Mimi",
                   "Lucas", "Lila", "Vince", "Kit", "Kerin", "Zee"}
for _, npcName in ipairs(NPC_NAMES) do
    actionBtn(scrolls["Zones_alpha"], "TP: " .. npcName, C.bg3, nZa(), function()
        pcall(function()
            local npcs = workspace:FindFirstChild("NPCs")
            if not npcs then return end
            local npc = npcs:FindFirstChild(npcName)
            if not npc then return end
            local root = npc:FindFirstChild("HumanoidRootPart")
                or npc:FindFirstChild("Head")
                or npc.PrimaryPart
            if not root then return end
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = root.CFrame * CFrame.new(0, 0, 4) end
        end)
    end)
end

sectionHeader(scrolls["Zones_beta"], "●", "Selected", nZb())
local _infoZone = infoRow(scrolls["Zones_beta"], "Zone", ZONE_NAMES[_selectedZone], C.pink, nZb())

sectionHeader(scrolls["Zones_beta"], "◉", "Zone List", nZb())
for _, zn in ipairs(ZONE_NAMES) do
    if zn ~= "All Zones" then
        infoRow(scrolls["Zones_beta"], zn, ZONE_TP[zn] and "Available" or "—", C.text2, nZb())
    end
end

sectionHeader(scrolls["Zones_beta"], "✦", "Tips", nZb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Click the Zone pill to cycle.\n'All Zones' picks the best Rate\ntree anywhere.\n\nPalm Cove requires the boat.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nZb(),
}, scrolls["Zones_beta"])

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "●", "Player", nUa())
toggleRow    (scrolls["Utility_alpha"], "Speed Boost",  "SpeedBoost", nUa())
toggleRow    (scrolls["Utility_alpha"], "Infinite Jump", "InfJump",   nUa())

sectionHeader(scrolls["Utility_alpha"], "◉", "Safety", nUa())
toggleRow    (scrolls["Utility_alpha"], "Anti-AFK", "AntiAFK", nUa())

sectionHeader(scrolls["Utility_alpha"], "◆", "Auto Claim", nUa())
toggleRow    (scrolls["Utility_alpha"], "Auto Daily Bonus",    "AutoDaily",           nUa())
toggleRow    (scrolls["Utility_alpha"], "Auto Free Sapling",   "AutoFreeSapling",     nUa())
toggleRow    (scrolls["Utility_alpha"], "Auto Group Reward",   "AutoGroupReward",     nUa())
toggleRow    (scrolls["Utility_alpha"], "Auto Market Restock", "AutoMarketRestock",   nUa())
toggleRow    (scrolls["Utility_alpha"], "Auto Dismiss Change", "AutoDismissChangelog", nUa())

sectionHeader(scrolls["Utility_alpha"], "▣", "Stats", nUa())
local _infoHealth = infoRow(scrolls["Utility_alpha"], "Health", "---", C.text,  nUa())
local _infoSpeed  = infoRow(scrolls["Utility_alpha"], "Speed",  "16",  C.text,  nUa())

sectionHeader(scrolls["Utility_beta"], "●", "Claim", nUb())
actionBtn(scrolls["Utility_beta"], "Claim Daily Bonus",  C.bg3, nUb(), function() pcall(sendLoginBonus) end)
actionBtn(scrolls["Utility_beta"], "Claim Free Sapling", C.bg3, nUb(), function() pcall(sendFreeSapling) end)
actionBtn(scrolls["Utility_beta"], "Claim Group Reward", C.bg3, nUb(), function() pcall(sendJoinedGroup) end)
actionBtn(scrolls["Utility_beta"], "Claim Quest Reward", C.bg3, nUb(), function() pcall(sendQuestClaim) end)
actionBtn(scrolls["Utility_beta"], "Market Restock",     C.bg3, nUb(), function() pcall(sendMarketRestock) end)
actionBtn(scrolls["Utility_beta"], "Dismiss Changelog",  C.bg3, nUb(), function() pcall(sendViewedChangelog) end)

sectionHeader(scrolls["Utility_beta"], "◉", "Resources", nUb())
actionBtn(scrolls["Utility_beta"], "Collect All",   C.bg3, nUb(), function() pcall(sendCollectAll) end)
actionBtn(scrolls["Utility_beta"], "Sell All",      C.bg3, nUb(), function() pcall(sendSell) end)

sectionHeader(scrolls["Utility_beta"], "✦", "Notes", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Speed Boost sets WalkSpeed=80\nand JumpPower=80.\n\nAnti-AFK fires the afk_rejoin\npacket every 60s.",
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
    CFG.SelectedZone = 1; _selectedZone = 1
    CFG.ChopTreeTypes = {}
    CFG.AutoSave = true
    if _zoneLabel then _zoneLabel.Text = ZONE_NAMES[_selectedZone] end
    saveCFG()
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSa())
actionBtn    (scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn    (scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.3)
    getgenv().__AURORA_TIMBER_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "Timber!",                    C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),       C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion),  C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",        C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v5.2",                       C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,                 C.text3, nSb())
infoRow(scrolls["Settings_beta"], "Network", "ByteNet (direct buffer)",    C.text3, nSb())

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

sectionHeader(liveScroll, "◆", "Chopping", nL())
local _liveTree    = infoRow(liveScroll, "Tree",   "None", C.text,  nL())
local _liveZone    = infoRow(liveScroll, "Zone",   "---",  C.text2, nL())

sectionHeader(liveScroll, "✦", "Session Totals", nL())
local _liveHits    = infoRow(liveScroll, "Hits",         "0", C.pink, nL())
local _liveDown    = infoRow(liveScroll, "Trees Down",   "0", C.pink, nL())
local _liveColl    = infoRow(liveScroll, "Collected",    "0", C.pink, nL())
local _liveSells   = infoRow(liveScroll, "Sold",         "0", C.pink, nL())

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
        getgenv().__AURORA_TIMBER_SESSION = 0
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
            local mode = "Idle"
            if CFG.AutoChop then mode = "Chopping"
            elseif CFG.ChopNoTP then mode = "Chop (Near)"
            elseif CFG.AutoCollect then mode = "Collecting"
            elseif CFG.AutoHiddenTrees then mode = "Hidden Trees"
            elseif CFG.AutoSell then mode = "Selling"
            elseif CFG.AutoDaily or CFG.AutoFreeSapling or CFG.AutoGroupReward then mode = "Claiming" end

            local zoneTxt = ZONE_NAMES[_selectedZone] or "---"
            local treeTxt = _currentTree or "None"

            -- Farm tab
            _infoTree.Text       = treeTxt
            _infoStatus.Text     = mode
            _infoHits.Text       = fmt(S.hits)
            _infoTreesDown.Text  = tostring(S.treesDown)
            _infoCollected.Text  = tostring(S.collected)
            _infoSold.Text       = tostring(S.sold)
            _infoMutations.Text  = tostring(S.mutations or 0)
            _infoRewards.Text    = tostring(S.itemRewards or 0)
            _infoRuntime.Text    = rtime

            -- Zones tab
            _infoZone.Text       = zoneTxt

            -- Utility tab
            _infoHealth.Text     = hpTxt
            _infoSpeed.Text      = spTxt

            -- Live Game
            _liveRuntime.Text    = rtime
            _liveStatus.Text     = mode
            _liveHealth.Text     = hpTxt
            _liveSpeed.Text      = spTxt
            _liveTree.Text       = treeTxt
            _liveZone.Text       = zoneTxt
            _liveHits.Text       = fmt(S.hits)
            _liveDown.Text       = tostring(S.treesDown)
            _liveColl.Text       = tostring(S.collected)
            _liveSells.Text      = tostring(S.sold)

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

print("[Aurora v5.2] Timber! loaded")
