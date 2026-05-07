--// Aurora v5 — Split or Steal
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 132391015411211
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// Auto-Farm decision, auto-spin wheel, auto-claim rewards, max stats — PRESERVED VERBATIM

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local Player       = Players.LocalPlayer

-- Cleanup old UI (Xeno-safe: each parent chain in its own pcall)
for _, n in ipairs({"Aurora", "AuroraPill", "TestAurora"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_SOS_CFG2 then
    for k, v in pairs(getgenv().__AURORA_SOS_CFG2) do
        if type(v) == "boolean" then getgenv().__AURORA_SOS_CFG2[k] = false end
    end
end
-- Also clear legacy v4 key
if getgenv().__AURORA_SOS_CFG then
    for k, v in pairs(getgenv().__AURORA_SOS_CFG) do
        if type(v) == "boolean" then getgenv().__AURORA_SOS_CFG[k] = false end
    end
end
task.wait(0.15)

getgenv().__AURORA_SOS_SESSION = tick()
local _mySession = getgenv().__AURORA_SOS_SESSION
local function alive() return getgenv().__AURORA_SOS_SESSION == _mySession end

---------- CHARACTER ----------
local function getChar() return Player.Character end
local function getHRP() local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

---------- REMOTES ----------
local RE = RS:WaitForChild("RemoteEvents", 10)

-- Type-safe remote lookup: returns the child only if it's the expected class
local function safeRE(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteEvent")) and obj or nil
end
local function safeRF(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteFunction")) and obj or nil
end

local PlayerDecision = safeRE(RE and RE:FindFirstChild("GameTable") and RE.GameTable:FindFirstChild("PlayerDecision"), "PlayerDecision")
local ClaimQuest     = safeRE(RE and RE:FindFirstChild("DailyQuest"), "RequestClaimReward")
local BounceCheck    = safeRE(RE and RE:FindFirstChild("NewPlayer"), "AcceptBounceCheckReward")
local GroupJoin      = safeRE(RE and RE:FindFirstChild("JoinedGroup"), "JoinedGroup")
local EggTouched     = safeRE(RE, "EggTouched")
local DailyRewards   = safeRE(RE, "DailyRewards")
local EasterRewards  = safeRE(RE, "EasterRewards")

-- v5 new: shop + event + troll
local RequestNameTagUpgrade = safeRF(RE and RE:FindFirstChild("Shop"), "RequestNameTagUpgrade")
local RequestDeathUpgrade   = safeRF(RE and RE:FindFirstChild("Shop"), "RequestDeathUpgrade")
-- The real ticket-spin remote is a RemoteEvent under DeveloperProducts (yes, confusing name).
-- SpinButton click fires this with no args; the server validates tickets.
-- The RF `RequestEventSpinnerPurchase` at .Event is a Robux-purchase endpoint — do NOT call that.
local Request1EventSpin     = safeRE(RE and RE:FindFirstChild("DeveloperProducts"), "Request1EventSpin")
local TrollEvent            = safeRE(RE, "TrollEvent")

---------- GAME UI REFS ----------
local pgui     = Player:WaitForChild("PlayerGui", 10)
local stateGui = pgui and pgui:WaitForChild("PlayerStateGui", 10)
local resultGui = pgui and pgui:WaitForChild("PlayerResultGui", 10)

local DecisionFrame = stateGui and stateGui:FindFirstChild("DecisionStateFrame")
local TopHalf       = DecisionFrame and DecisionFrame:FindFirstChild("TopHalf")
local StealBtn      = TopHalf and TopHalf:FindFirstChild("StealButton")
local SplitBtn      = TopHalf and TopHalf:FindFirstChild("SplitButton")
local ConfirmBtn    = DecisionFrame and DecisionFrame:FindFirstChild("ConfirmButton")

local IdleFrame     = stateGui and stateGui:FindFirstChild("IdleStateFrame")
local IdleInner     = IdleFrame and IdleFrame:FindFirstChild("Frame")
local QuickPlayBtn  = IdleInner and IdleInner:FindFirstChild("QuickPlayButton")

local FriendFrame    = resultGui and resultGui:FindFirstChild("Friend_Frame")
local StealBackFrame = resultGui and resultGui:FindFirstChild("StealBack_Frame")

---------- PLAYER STATS ----------
local pstats = Player:WaitForChild("playerstats", 10)
local lstats = Player:WaitForChild("leaderstats", 10)


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
if not getgenv().__AURORA_SOS_CFG2 then
    getgenv().__AURORA_SOS_CFG2 = {
        -- v4 keys preserved exactly
        AutoFarm   = false,
        AutoSteal  = true,
        AutoClaim  = false,
        MaxStats   = false,
        SpeedBoost = false,
        AntiAFK    = true,
        PlayerESP  = false,
        AutoSpin   = false,
        AutoSave   = true,
        -- v5 additions (all default OFF)
        AutoNameTag = false,
        AutoDeath   = false,
        AutoTroll   = false,
        -- v5 UI state
        ActiveTab  = "Farm",
        PanelOpen  = true,
    }
else
    local c = getgenv().__AURORA_SOS_CFG2
    if c.ActiveTab == nil then c.ActiveTab = "Farm" end
    if c.PanelOpen == nil then c.PanelOpen = true end
    if c.AutoNameTag == nil then c.AutoNameTag = false end
    if c.AutoDeath   == nil then c.AutoDeath   = false end
    if c.AutoTroll   == nil then c.AutoTroll   = false end
end
local CFG = getgenv().__AURORA_SOS_CFG2

---------- TOGGLE SAVE/LOAD (preserved v4 filename) ----------
local _cfgFileName = "aurora_cfg_split_or_steal.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_split_or_steal"] end
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
    end
end

local function saveCFG()
    pcall(function() if _HAS.writefile then writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end end)
    getgenv()["AuroraCFG_split_or_steal"] = CFG
end

loadSavedCFG()

---------- STAT MAXING ----------
local function maxAllStats()
    pcall(function() lstats.Cash.Value = 999999999 end)
    pcall(function() lstats.Wins.Value = 99999 end)
    pcall(function() pstats.Keys.Value = 99999 end)
    pcall(function() pstats.LuckyRolls.Value = 99999 end)
    pcall(function() pstats.SuperRolls.Value = 99999 end)
    pcall(function() pstats.GuaranteedJackpots.Value = 99999 end)
    pcall(function() pstats.EventSpinnerTickets.Value = 99999 end)
    pcall(function() pstats.WinStreak.Value = 99999 end)
    pcall(function() pstats.TotalLuck.Value = 999.0 end)
    pcall(function() pstats.TotalLuck_Friend.Value = 999.0 end)
    pcall(function() pstats.TotalLuck_Group.Value = 999.0 end)
    pcall(function() pstats.NameTag_Level.Value = 100 end)
end

---------- FARM STATE ----------
local S = {
    matches  = 0,
    earned   = 0,
    startCash = (lstats and lstats:FindFirstChild("Cash") and lstats.Cash.Value) or 0,
    session  = tick(),
}
local _sessionStart = tick()

---------- HELPERS ----------
local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

---------- GAME LOOPS (preserved verbatim from v4) ----------

-- Auto-Farm loop: re-resolves GUI refs each tick to avoid stale references
task.spawn(function()
    local function getMyTable()
        local hum = getHum()
        if not hum then return nil end
        for _, folder in ipairs({workspace:FindFirstChild("GameTables"), workspace:FindFirstChild("GoldGameTables")}) do
            if folder then
                for _, gt in folder:GetChildren() do
                    if gt:IsA("Model") then
                        for _, seat in gt:GetDescendants() do
                            if seat:IsA("Seat") and seat.Occupant == hum then
                                return gt
                            end
                    end
                    end
            end
            end
        end
        return nil
    end

    local function fireButton(btn)
        if not btn then return end
        if typeof(getconnections) == "function" then
            for _, c in getconnections(btn.Activated) do pcall(function() c:Fire() end) end
        elseif typeof(firesignal) == "function" then
            pcall(function() firesignal(btn.Activated) end)
        end
    end

    while alive() do
        task.wait(jitter(2, 0.5))
        if not alive() then break end
        if CFG.AutoFarm then
            -- Re-resolve GUI refs every tick (handles respawn/teleport)
            local _pgui = Player:FindFirstChild("PlayerGui")
            local _stateGui = _pgui and _pgui:FindFirstChild("PlayerStateGui")
            local _idleFrame = _stateGui and _stateGui:FindFirstChild("IdleStateFrame")
            local _decFrame = _stateGui and _stateGui:FindFirstChild("DecisionStateFrame")
            local _waitFrame = _stateGui and _stateGui:FindFirstChild("WaitingStateFrame")
            local _resultGui = _pgui and _pgui:FindFirstChild("PlayerResultGui")

            local seated = getMyTable() ~= nil
            local idle = _idleFrame and _idleFrame.Visible
            local waiting = _waitFrame and _waitFrame.Visible
            local deciding = _decFrame and _decFrame.Visible

            if deciding then
                -- IN DECISION PHASE: pick steal/split + confirm
                pcall(function()
                    local myTable = getMyTable()
                    if myTable and PlayerDecision then
                        local decision = CFG.AutoSteal and "STEAL" or "SPLIT"
                        PlayerDecision:FireServer(myTable, decision)
                        task.wait(jitter(1.5, 0.5))
                        PlayerDecision:FireServer(myTable, "CONFIRM")
                        S.matches = S.matches + 1
                    end
                end)
            elseif seated or waiting then
                -- SEATED or WAITING: game in progress, do nothing
            else
                -- NOT SEATED: dismiss result screens first, then sit at gold table
                pcall(function()
                    if _resultGui then
                        for _, d in _resultGui:GetDescendants() do
                            if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible then
                                if d.Name:find("PlayAgain") or d.Name:find("Steal") or d.Name:find("Continue") or d.Name:find("Claim") then
                                    fireButton(d)
                                end
                            end
                        end
                    end
                end)
                task.wait(0.5)
                -- Sit at gold/VIP table directly (skip QuickPlay)
                pcall(function()
                    local hum = getHum()
                    if not hum or hum.Sit then return end
                    local goldFolder = workspace:FindFirstChild("GoldGameTables")
                    if not goldFolder then return end
                    -- Prefer table with 1 player (instant match)
                    local targetSeat = nil
                    for _, gt in goldFolder:GetChildren() do
                        if not gt:IsA("Model") then continue end
                        local s1 = gt:FindFirstChild("Seat1")
                        local s2 = gt:FindFirstChild("Seat2")
                        if not s1 or not s2 then continue end
                        if s1.Occupant and not s2.Occupant then targetSeat = s2; break end
                        if s2.Occupant and not s1.Occupant then targetSeat = s1; break end
                    end
                    -- If no half-full gold tables, pick any empty one
                    if not targetSeat then
                        for _, gt in goldFolder:GetChildren() do
                            if not gt:IsA("Model") then continue end
                            local s1 = gt:FindFirstChild("Seat1")
                            if s1 and not s1.Occupant then targetSeat = s1; break end
                        end
                    end
                    if targetSeat then targetSeat:Sit(hum) end
                end)
            end
        end
    end
end)

-- Auto-Claim loop
task.spawn(function()
    while alive() do
        task.wait(jitter(30, 10))
        if not alive() then break end
        if CFG.AutoClaim then
            pcall(function() if ClaimQuest then ClaimQuest:FireServer() end end)
            pcall(function() if BounceCheck then BounceCheck:FireServer() end end)
            pcall(function() if GroupJoin then GroupJoin:FireServer() end end)
            pcall(function() if EggTouched then EggTouched:FireServer() end end)
            pcall(function() if DailyRewards then DailyRewards:FireServer() end end)
            pcall(function() if EasterRewards then EasterRewards:FireServer() end end)
        end
    end
end)

-- Auto Spin Wheel loop (uses event tickets — 10 per spin)
-- Fires Request1EventSpin:FireServer() DIRECTLY. No UI signal dispatch —
-- firing SpinButton.Activated via getconnections/firesignal triggers the
-- game's handler AND its ButtonAnimations.OnClick chain, which visually
-- presses the wrong button when AutoSpin toggle state is non-default.
-- Direct RE fire is bulletproof: server does the ticket validation, no UI side effects.
task.spawn(function()
    while alive() do
        task.wait(jitter(3, 1))
        if not alive() then break end
        if CFG.AutoSpin then
            pcall(function()
                -- Tickets gate: server requires 10 tickets per spin
                local pstats2 = Player:FindFirstChild("playerstats")
                local tickets = pstats2 and pstats2:FindFirstChild("EventSpinnerTickets")
                if not tickets or tickets.Value < 10 then return end

                -- Primary: direct RE fire. No args. No UI. No side effects.
                if Request1EventSpin then
                    pcall(function() Request1EventSpin:FireServer() end)
                end
            end)
        end
    end
end)

-- Speed Boost loop
task.spawn(function()
    while alive() do
        task.wait(0.5)
        if not alive() then break end
        if CFG.SpeedBoost then
            pcall(function()
                local hum = getHum()
                if hum then hum.WalkSpeed = 50 end
            end)
        end
    end
end)

-- Anti-AFK loop
task.spawn(function()
    while alive() do
        task.wait(60)
        if not alive() then break end
        if CFG.AntiAFK then
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController(); vu:ClickButton2(Vector2.new())
            end)
        end
    end
end)

-- Max Stats loop
task.spawn(function()
    while alive() do
        task.wait(5)
        if not alive() then break end
        if CFG.MaxStats then maxAllStats() end
    end
end)

-- ========================================================================
-- v5 NEW LOOPS
-- ========================================================================

-- Player ESP (Opponent Cash + NameTag level + Wins) — full implementation
-- Registry uses weak keys so removed players don't leak
do
    local espRegistry = setmetatable({}, { __mode = "k" }) -- player -> {hl=Highlight, bg=BillboardGui, labels=...}
    local espGui

    local function ensureEspGui()
        if espGui and espGui.Parent then return espGui end
        espGui = Instance.new("ScreenGui")
        espGui.Name = "AuroraESP_SOS"
        espGui.ResetOnSpawn = false
        espGui.IgnoreGuiInset = true
        espGui.DisplayOrder = 9997
        local parented = false
        if _HAS.gethui then parented = pcall(function() espGui.Parent = gethui() end) end
        if not parented then parented = pcall(function() espGui.Parent = game:GetService("CoreGui") end) end
        if not parented then pcall(function() espGui.Parent = Player:WaitForChild("PlayerGui") end) end
        return espGui
    end

    local function makeEspFor(plr)
        if plr == Player then return nil end
        local char = plr.Character
        if not char then return nil end
        local head = char:FindFirstChild("Head")
        if not head then return nil end

        ensureEspGui()

        -- Highlight (outline)
        local hl = Instance.new("Highlight")
        hl.Name = "AuroraESP_HL"
        hl.FillTransparency = 1
        hl.OutlineTransparency = 0
        hl.OutlineColor = Color3.fromRGB(252, 110, 142)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = char
        hl.Parent = espGui

        -- BillboardGui above head
        local bg = Instance.new("BillboardGui")
        bg.Name = "AuroraESP_BG"
        bg.Adornee = head
        bg.Size = UDim2.fromOffset(160, 56)
        bg.StudsOffset = Vector3.new(0, 3.2, 0)
        bg.AlwaysOnTop = true
        bg.MaxDistance = 500
        bg.LightInfluence = 0
        bg.Parent = espGui

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, 0, 0, 18)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 13
        nameLbl.TextColor3 = Color3.fromRGB(252, 110, 142)
        nameLbl.TextStrokeTransparency = 0.3
        nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLbl.Text = plr.Name
        nameLbl.Parent = bg

        local cashLbl = Instance.new("TextLabel")
        cashLbl.Size = UDim2.new(1, 0, 0, 16)
        cashLbl.Position = UDim2.fromOffset(0, 18)
        cashLbl.BackgroundTransparency = 1
        cashLbl.Font = Enum.Font.Code
        cashLbl.TextSize = 11
        cashLbl.TextColor3 = Color3.fromRGB(240, 180, 30)
        cashLbl.TextStrokeTransparency = 0.4
        cashLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        cashLbl.Text = "$0"
        cashLbl.Parent = bg

        local infoLbl = Instance.new("TextLabel")
        infoLbl.Size = UDim2.new(1, 0, 0, 16)
        infoLbl.Position = UDim2.fromOffset(0, 34)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Font = Enum.Font.Gotham
        infoLbl.TextSize = 10
        infoLbl.TextColor3 = Color3.fromRGB(192, 132, 252)
        infoLbl.TextStrokeTransparency = 0.4
        infoLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        infoLbl.Text = ""
        infoLbl.Parent = bg

        return { hl = hl, bg = bg, cashLbl = cashLbl, infoLbl = infoLbl, nameLbl = nameLbl }
    end

    local function removeEspFor(plr)
        local r = espRegistry[plr]
        if r then
            if r.hl then pcall(function() r.hl:Destroy() end) end
            if r.bg then pcall(function() r.bg:Destroy() end) end
            espRegistry[plr] = nil
        end
    end

    local function clearAllEsp()
        for p in pairs(espRegistry) do removeEspFor(p) end
        if espGui then pcall(function() espGui:Destroy() end); espGui = nil end
    end

    -- Cleanup on leave
    Players.PlayerRemoving:Connect(function(plr)
        if alive() then removeEspFor(plr) end
    end)

    -- Main loop
    task.spawn(function()
        while alive() do
            task.wait(1)
            if not alive() then break end
            if CFG.PlayerESP then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= Player then
                        local char = plr.Character
                        local head = char and char:FindFirstChild("Head")
                        local r = espRegistry[plr]
                        if head then
                            if not r or not r.bg or not r.bg.Parent then
                                local new = makeEspFor(plr)
                                if new then espRegistry[plr] = new; r = new end
                            end
                            if r and r.bg and r.bg.Parent then
                                -- Update cash
                                local ls = plr:FindFirstChild("leaderstats")
                                local cash = ls and ls:FindFirstChild("Cash")
                                local wins = ls and ls:FindFirstChild("Wins")
                                if cash then r.cashLbl.Text = "$" .. fmt(cash.Value) end
                                -- NameTag level + chair
                                local ps = plr:FindFirstChild("playerstats")
                                local ntl = ps and ps:FindFirstChild("NameTag_Level")
                                local ch = ps and ps:FindFirstChild("Equipped_Chair")
                                local infoParts = {}
                                if wins then table.insert(infoParts, fmt(wins.Value) .. "W") end
                                if ntl then table.insert(infoParts, "NT" .. tostring(ntl.Value)) end
                                if ch and ch.Value ~= "" then table.insert(infoParts, tostring(ch.Value)) end
                                r.infoLbl.Text = table.concat(infoParts, " · ")
                                -- Re-adornee if head changed
                                if r.bg.Adornee ~= head then r.bg.Adornee = head end
                                if r.hl.Adornee ~= char then r.hl.Adornee = char end
                            end
                        end
                    end
                end
                -- Clean up entries whose player is gone from registry
                for plr, r in pairs(espRegistry) do
                    if not plr or not plr.Parent then removeEspFor(plr) end
                end
            else
                if next(espRegistry) ~= nil or espGui then clearAllEsp() end
            end
        end
    end)
end

-- Auto NameTag Upgrade: fire RequestNameTagUpgrade RF every 4s (server validates cash)
task.spawn(function()
    while alive() do
        task.wait(jitter(4, 1))
        if not alive() then break end
        if CFG.AutoNameTag and RequestNameTagUpgrade then
            local ntl = pstats and pstats:FindFirstChild("NameTag_Level")
            if ntl and ntl.Value >= 15 then
                -- maxed, skip
            else
                pcall(function() RequestNameTagUpgrade:InvokeServer() end)
            end
        end
    end
end)

-- Auto Death Upgrade: fire RequestDeathUpgrade RF every 4s (server validates cash)
task.spawn(function()
    while alive() do
        task.wait(jitter(4, 1))
        if not alive() then break end
        if CFG.AutoDeath and RequestDeathUpgrade then
            local dl = pstats and pstats:FindFirstChild("Death_Level")
            if dl and dl.Value >= 5 then
                -- maxed, skip
            else
                pcall(function() RequestDeathUpgrade:InvokeServer() end)
            end
        end
    end
end)

-- Auto Troll: fire TrollEvent every 12s (server-gated reward)
task.spawn(function()
    while alive() do
        task.wait(jitter(12, 3))
        if not alive() then break end
        if CFG.AutoTroll and TrollEvent then
            pcall(function() TrollEvent:FireServer() end)
        end
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
    gold     = Color3.fromRGB(240,180, 30),
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
    { name = "Rewards", icon = "◆" },
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

local TAB_NAMES = { "Farm", "Rewards", "Utility", "Settings" }
local TAB_ACCENT = {
    Farm     = C.pink,
    Rewards  = C.purple,
    Utility  = C.pink,
    Settings = C.purple,
}
local PANEL_TITLES = {
    Farm     = { alpha = "FARMING",   beta = "FARM STATUS" },
    Rewards  = { alpha = "REWARDS",   beta = "STATS"       },
    Utility  = { alpha = "UTILITY",   beta = "PLAYER"      },
    Settings = { alpha = "CONFIG",    beta = "ABOUT"       },
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
        BackgroundTransparency = 1, Text = tostring(initialVal or "---"),
        Font = F_MONO, TextSize = 10, TextColor3 = valColor or C.text2,
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    return val
end

--========================================================================
-- POPULATE: FARM
--========================================================================
local oF_a, oF_b = 0, 0
local function nFa() oF_a = oF_a + 1; return oF_a end
local function nFb() oF_b = oF_b + 1; return oF_b end

sectionHeader(scrolls["Farm_alpha"], "●", "Auto-Farm", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Farm (Gold)", "AutoFarm",  nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Steal",       "AutoSteal", nFa())

sectionHeader(scrolls["Farm_alpha"], "◈", "Auto Upgrade", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Name Tag (Luck)", "AutoNameTag", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Death (Luck)",    "AutoDeath",   nFa())

sectionHeader(scrolls["Farm_alpha"], "✦", "Notes", nFa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1,
    Text = "Auto Farm sits at Gold tables\nautomatically, dismisses result\nscreens, and picks Steal/Split\neach decision phase.\n\nAuto Steal OFF = picks SPLIT.\n\nAuto Upgrade spends Cash to\nmax Name Tag (+Luck) and\nDeath Effect (+Luck). Server\nvalidates funds.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nFa(),
}, scrolls["Farm_alpha"])

sectionHeader(scrolls["Farm_beta"], "●", "Status", nFb())
local _infoStatus    = infoRow(scrolls["Farm_beta"], "Status",  "Idle", C.pink,  nFb())
local _infoMatches   = infoRow(scrolls["Farm_beta"], "Matches", "0",    C.pink,  nFb())
local _infoEarned    = infoRow(scrolls["Farm_beta"], "Earned",  "0",    C.pink,  nFb())

sectionHeader(scrolls["Farm_beta"], "◉", "Session", nFb())
local _infoRuntime   = infoRow(scrolls["Farm_beta"], "Runtime", "0m",   C.text2, nFb())
local _infoCash      = infoRow(scrolls["Farm_beta"], "Cash",    "---",  C.text,  nFb())
local _infoWins      = infoRow(scrolls["Farm_beta"], "Wins",    "---",  C.text,  nFb())

sectionHeader(scrolls["Farm_beta"], "✦", "Decision", nFb())
local _infoDecision  = infoRow(scrolls["Farm_beta"], "Pick", CFG.AutoSteal and "STEAL" or "SPLIT", C.pink, nFb())

--========================================================================
-- POPULATE: REWARDS
--========================================================================
local oR_a, oR_b = 0, 0
local function nRa() oR_a = oR_a + 1; return oR_a end
local function nRb() oR_b = oR_b + 1; return oR_b end

sectionHeader(scrolls["Rewards_alpha"], "●", "Auto Claim", nRa())
toggleRow    (scrolls["Rewards_alpha"], "Auto Spin Wheel", "AutoSpin",  nRa())
toggleRow    (scrolls["Rewards_alpha"], "Auto Claim",      "AutoClaim", nRa())
toggleRow    (scrolls["Rewards_alpha"], "Auto Troll",      "AutoTroll", nRa())

sectionHeader(scrolls["Rewards_alpha"], "▣", "Stats", nRa())
toggleRow    (scrolls["Rewards_alpha"], "Max Stats (Client)", "MaxStats", nRa(), function(on)
    if on then maxAllStats() end
end)

sectionHeader(scrolls["Rewards_alpha"], "⚙", "Manual", nRa())
actionBtn(scrolls["Rewards_alpha"], "Claim Daily Quest",   C.gold, nRa(), function()
    if ClaimQuest then pcall(function() ClaimQuest:FireServer() end) end
end)
actionBtn(scrolls["Rewards_alpha"], "Claim Bounce Check",  C.gold, nRa(), function()
    if BounceCheck then pcall(function() BounceCheck:FireServer() end) end
end)
actionBtn(scrolls["Rewards_alpha"], "Claim Group Reward",  C.gold, nRa(), function()
    if GroupJoin then pcall(function() GroupJoin:FireServer() end) end
end)
actionBtn(scrolls["Rewards_alpha"], "Claim Daily Rewards", C.gold, nRa(), function()
    if DailyRewards then pcall(function() DailyRewards:FireServer() end) end
end)
actionBtn(scrolls["Rewards_alpha"], "Claim Easter Rewards", C.gold, nRa(), function()
    if EasterRewards then pcall(function() EasterRewards:FireServer() end) end
end)

sectionHeader(scrolls["Rewards_alpha"], "✦", "Notes", nRa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 120), BackgroundTransparency = 1,
    Text = "Auto Spin Wheel fires every 3s\nwhen you have 10+ event\ntickets.\n\nAuto Claim hits all 6 reward\nremotes every 30s.\n\nAuto Troll fires the Troll\nevent every ~12s.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nRa(),
}, scrolls["Rewards_alpha"])

sectionHeader(scrolls["Rewards_beta"], "●", "Rewards", nRb())
local _infoKeys       = infoRow(scrolls["Rewards_beta"], "Keys",        "---", C.pink,  nRb())
local _infoLuckyRolls = infoRow(scrolls["Rewards_beta"], "Lucky Rolls", "---", C.pink,  nRb())
local _infoSuperRolls = infoRow(scrolls["Rewards_beta"], "Super Rolls", "---", C.pink,  nRb())
local _infoTickets    = infoRow(scrolls["Rewards_beta"], "Tickets",     "---", C.pink,  nRb())

sectionHeader(scrolls["Rewards_beta"], "◉", "Performance", nRb())
local _infoWinStreak  = infoRow(scrolls["Rewards_beta"], "Win Streak",  "---", C.text,  nRb())
local _infoLuck       = infoRow(scrolls["Rewards_beta"], "Total Luck",  "---", C.text,  nRb())
local _infoJackpots   = infoRow(scrolls["Rewards_beta"], "Jackpots",    "---", C.text,  nRb())

sectionHeader(scrolls["Rewards_beta"], "✦", "Tips", nRb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Max Stats (Client) only updates\nvisually on your screen.\n\nServer-side stats are authoritative\nand override client changes on\nnext sync.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nRb(),
}, scrolls["Rewards_beta"])

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "●", "Movement", nUa())
toggleRow    (scrolls["Utility_alpha"], "Speed Boost (50)", "SpeedBoost", nUa())

sectionHeader(scrolls["Utility_alpha"], "◆", "Visuals", nUa())
toggleRow    (scrolls["Utility_alpha"], "Opponent ESP", "PlayerESP", nUa())

sectionHeader(scrolls["Utility_alpha"], "▣", "Safety", nUa())
toggleRow    (scrolls["Utility_alpha"], "Anti-AFK", "AntiAFK", nUa())

sectionHeader(scrolls["Utility_alpha"], "✦", "Notes", nUa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 130), BackgroundTransparency = 1,
    Text = "Speed Boost locks WalkSpeed\nto 50 every 0.5s.\n\nAnti-AFK fires VirtualUser\nclick every 60s.\n\nOpponent ESP highlights all\nother players with Cash, Wins,\nand Name Tag level overhead.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUa(),
}, scrolls["Utility_alpha"])

sectionHeader(scrolls["Utility_beta"], "●", "Player", nUb())
local _infoHealth  = infoRow(scrolls["Utility_beta"], "Health",     "---", C.text, nUb())
local _infoWalkSpd = infoRow(scrolls["Utility_beta"], "Walk Speed", "---", C.text, nUb())

sectionHeader(scrolls["Utility_beta"], "◉", "Session", nUb())
local _infoStartCash = infoRow(scrolls["Utility_beta"], "Start Cash", fmt(S.startCash), C.text2, nUb())

sectionHeader(scrolls["Utility_beta"], "✦", "Tips", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Safe for overnight farming\nwhen combined with Auto Farm\nand Anti-AFK.\n\nSpeed Boost helps reach Gold\ntables faster on idle servers.",
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
actionBtn    (scrolls["Settings_alpha"], "Load Config",     C.bg3,   nSa(), function()
    loadSavedCFG()
end)
actionBtn    (scrolls["Settings_alpha"], "Reset Config",    C.red,   nSa(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    CFG.AutoSteal   = true
    CFG.AntiAFK     = true
    CFG.AutoSave    = true
    CFG.AutoNameTag = false
    CFG.AutoDeath   = false
    CFG.AutoTroll   = false
    saveCFG()
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSa())
actionBtn    (scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn    (scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.3)
    getgenv().__AURORA_SOS_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "Split or Steal",             C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),       C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion),  C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",        C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v5",                         C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,                 C.text3, nSb())
infoRow(scrolls["Settings_beta"], "Network", "Standard Remotes",           C.text3, nSb())

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
local _liveHealth  = infoRow(liveScroll, "Health",  "---", C.text,  nL())
local _liveSpeed   = infoRow(liveScroll, "Speed",   "---", C.text,  nL())

sectionHeader(liveScroll, "▣", "Farm", nL())
local _liveMatches = infoRow(liveScroll, "Matches", "0",   C.pink,  nL())
local _liveEarned  = infoRow(liveScroll, "Earned",  "0",   C.pink,  nL())
local _livePick    = infoRow(liveScroll, "Pick",    CFG.AutoSteal and "STEAL" or "SPLIT", C.pink, nL())

sectionHeader(liveScroll, "◆", "Stats", nL())
local _liveCash    = infoRow(liveScroll, "Cash",    "---", C.text2, nL())
local _liveWins    = infoRow(liveScroll, "Wins",    "---", C.text2, nL())
local _liveStreak  = infoRow(liveScroll, "Streak",  "---", C.pink,  nL())
local _liveKeys    = infoRow(liveScroll, "Keys",    "---", C.text2, nL())
local _liveLuck    = infoRow(liveScroll, "Luck",    "---", C.text2, nL())

sectionHeader(liveScroll, "✦", "Rolls", nL())
local _liveLR      = infoRow(liveScroll, "Lucky",   "---", C.text2, nL())
local _liveSR      = infoRow(liveScroll, "Super",   "---", C.text2, nL())
local _liveTickets = infoRow(liveScroll, "Tickets", "---", C.text2, nL())

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
        getgenv().__AURORA_SOS_SESSION = 0
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
            local hpTxt, spdTxt = "---", "---"
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hpTxt = string.format("%.0f/%.0f", hum.Health, hum.MaxHealth)
                    spdTxt = tostring(math.floor(hum.WalkSpeed))
                end
            end

            -- Runtime
            local elapsed = tick() - _sessionStart
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Status mode
            local active = {}
            if CFG.AutoFarm   then table.insert(active, "Farm")   end
            if CFG.AutoClaim  then table.insert(active, "Claim")  end
            if CFG.AutoSpin   then table.insert(active, "Spin")   end
            if CFG.MaxStats   then table.insert(active, "Max")    end
            if CFG.SpeedBoost then table.insert(active, "Speed")  end
            if CFG.PlayerESP  then table.insert(active, "ESP")    end

            local mode = #active > 0 and table.concat(active, " + ") or "Idle"
            if #mode > 28 then mode = (#active) .. " active" end

            -- Stats pulls
            local cashTxt, winsTxt = "---", "---"
            local keysTxt, lrTxt, srTxt, wsTxt, luckTxt, ticketsTxt, jackpotsTxt =
                "---", "---", "---", "---", "---", "---", "---"
            if lstats then
                local cash = lstats:FindFirstChild("Cash")
                local wins = lstats:FindFirstChild("Wins")
                if cash then
                    cashTxt = fmt(cash.Value)
                    S.earned = cash.Value - S.startCash
                end
                if wins then winsTxt = fmt(wins.Value) end
            end
            if pstats then
                local k  = pstats:FindFirstChild("Keys");                if k  then keysTxt     = fmt(k.Value) end
                local lr = pstats:FindFirstChild("LuckyRolls");          if lr then lrTxt       = fmt(lr.Value) end
                local sr = pstats:FindFirstChild("SuperRolls");          if sr then srTxt       = fmt(sr.Value) end
                local ws = pstats:FindFirstChild("WinStreak");           if ws then wsTxt       = fmt(ws.Value) end
                local tl = pstats:FindFirstChild("TotalLuck");           if tl then luckTxt     = string.format("%.1f", tl.Value) end
                local tk = pstats:FindFirstChild("EventSpinnerTickets"); if tk then ticketsTxt  = fmt(tk.Value) end
                local jp = pstats:FindFirstChild("GuaranteedJackpots");  if jp then jackpotsTxt = fmt(jp.Value) end
            end

            local pickTxt = CFG.AutoSteal and "STEAL" or "SPLIT"

            -- Farm tab
            _infoStatus.Text    = CFG.AutoFarm and "Farming" or "Idle"
            _infoMatches.Text   = tostring(S.matches)
            _infoEarned.Text    = fmt(S.earned)
            _infoRuntime.Text   = rtime
            _infoCash.Text      = cashTxt
            _infoWins.Text      = winsTxt
            _infoDecision.Text  = pickTxt

            -- Rewards tab
            _infoKeys.Text       = keysTxt
            _infoLuckyRolls.Text = lrTxt
            _infoSuperRolls.Text = srTxt
            _infoTickets.Text    = ticketsTxt
            _infoWinStreak.Text  = wsTxt
            _infoLuck.Text       = luckTxt
            _infoJackpots.Text   = jackpotsTxt

            -- Utility tab
            _infoHealth.Text     = hpTxt
            _infoWalkSpd.Text    = spdTxt

            -- Live Game
            _liveRuntime.Text    = rtime
            _liveStatus.Text     = mode
            _liveHealth.Text     = hpTxt
            _liveSpeed.Text      = spdTxt
            _liveMatches.Text    = tostring(S.matches)
            _liveEarned.Text     = fmt(S.earned)
            _livePick.Text       = pickTxt
            _liveCash.Text       = cashTxt
            _liveWins.Text       = winsTxt
            _liveStreak.Text     = wsTxt
            _liveKeys.Text       = keysTxt
            _liveLuck.Text       = luckTxt
            _liveLR.Text         = lrTxt
            _liveSR.Text         = srTxt
            _liveTickets.Text    = ticketsTxt

            -- Active features list + pill counter
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

--========================================================================
-- INIT
--========================================================================
switchTab(CFG.ActiveTab or "Farm")

print("[Aurora v5] Split or Steal loaded")
