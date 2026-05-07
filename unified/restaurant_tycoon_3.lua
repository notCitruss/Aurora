--// Aurora v5 — Restaurant Tycoon 3
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 119048529960596
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// Auto Grab+Serve · Collect Dishes · Collect Tips · Take Orders · Collect Bill · Auto Cook · Auto Daily

local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UIS           = game:GetService("UserInputService")
local HttpService   = game:GetService("HttpService")
local Player        = Players.LocalPlayer

-- Cleanup old UI (Xeno-safe)
for _, n in ipairs({"Aurora", "AuroraPill"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_RT3_CFG then
    for k, v in pairs(getgenv().__AURORA_RT3_CFG) do
        if type(v) == "boolean" then getgenv().__AURORA_RT3_CFG[k] = false end
    end
end
task.wait(0.15)

getgenv().__AURORA_RT3_SESSION = tick()
local _mySession = getgenv().__AURORA_RT3_SESSION
local function alive() return getgenv().__AURORA_RT3_SESSION == _mySession end

---------- COMPAT ----------
local _HAS = {
    gethui    = typeof(gethui) == "function",
    writefile = writefile ~= nil,
    firepp    = fireproximityprompt ~= nil,
    hookfn    = hookfunction ~= nil,
    getgc     = getgc ~= nil,
}
local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- REMOTE REFS ----------
local Events = RS:WaitForChild("Events", 10)
if not Events then warn("[Aurora] Events folder missing"); return end
local RestaurantEv = Events:WaitForChild("Restaurant", 5)
local FoodEv       = Events:WaitForChild("Food", 5)

local R_GrabFood        = RestaurantEv:WaitForChild("GrabFood", 5)
local R_TaskCompleted   = RestaurantEv:WaitForChild("TaskCompleted", 5)
local R_CancelGrab      = RestaurantEv:WaitForChild("CancelGrabRequested", 5)
local R_TipsCollected   = RestaurantEv:WaitForChild("TipsCollected", 5)
local R_GrabEnded       = RestaurantEv:WaitForChild("GrabEnded", 5)
local R_ChefCookInput   = Events.Cook:WaitForChild("ChefCookInputRequested", 5)
local R_DailyReward     = Events.DailyRewards:WaitForChild("DailyRewardClaimed", 5)
local R_UnlockUpgrade   = Events.Upgrades:WaitForChild("UnlockUpgradeRequested", 5)
local R_LevelFranchise  = Events.Upgrades:WaitForChild("LevelUpFranchiseRequested", 5)

-- Client-side modules (GroupId/CustomerId lookup + FurnitureUtility + Tasks for click-sim)
local CustomersMod = nil
local FurnitureUtility = nil
local TaskEnum = nil
local CustomerStateEnum = nil
local TasksSystem = nil       -- Systems.Restaurant.Tasks — HandleInput simulates a click
local GrabFoodSystem = nil    -- Systems.Restaurant.GrabFood — reads Storage to see what we're holding
local SendToTableSystem = nil -- Modules.Tasks.SendToTable — AskToSend + CompleteSend seat flow
local FarmingSystem = nil     -- Systems.Farming — has GetState(tile) + .Plot reference
local CropUtility = nil       -- Utility.Farming.CropUtility — crop names + grow times
pcall(function()
    local psi = Player:WaitForChild("PlayerScripts", 10)
    local src = psi:WaitForChild("Source", 10)
    CustomersMod = require(src.Systems.Restaurant.Customers)
    TasksSystem = require(src.Systems.Restaurant.Tasks)
    GrabFoodSystem = require(src.Systems.Restaurant.GrabFood)
    SendToTableSystem = require(src.Modules.Tasks.SendToTable)
    FarmingSystem = require(src.Systems.Farming)
    CropUtility = require(RS.Source.Utility.Farming.CropUtility)
end)
pcall(function()
    FurnitureUtility = require(RS.Source.Utility.FurnitureUtility)
end)
pcall(function() TaskEnum = require(RS.Source.Enums.Restaurant.Task) end)
pcall(function() CustomerStateEnum = require(RS.Source.Enums.Restaurant.Customer.CustomerState) end)

local function isTableFurniture(model)
    if not model or not model:IsA("Model") then return false end
    if FurnitureUtility and FurnitureUtility.IsTable then
        local ok, r = pcall(function() return FurnitureUtility:IsTable(model.Name) end)
        if ok then return r == true end
    end
    return false
end
local function isChairFurniture(model)
    if not model or not model:IsA("Model") then return false end
    if FurnitureUtility and FurnitureUtility.IsChair then
        local ok, r = pcall(function() return FurnitureUtility:IsChair(model.Name) end)
        if ok then return r == true end
    end
    return false
end

---------- CONFIG ----------
if not getgenv().__AURORA_RT3_CFG then
    getgenv().__AURORA_RT3_CFG = {
        AutoServe        = false, -- grab food + deliver to matching customer/car
        AutoCollectDish  = false, -- clear dirty tables
        AutoCollectTips  = false, -- money pile
        AutoTakeOrder    = false, -- take seated group's order
        AutoCollectBill  = false, -- after customer leaves
        AutoSendToTable  = false, -- seat waiting groups
        AutoCook         = false, -- chef + barista taps
        AutoDaily        = false,
        AutoPlant        = false, -- plant CFG.PlantCrop on all Empty tiles
        AutoHarvest      = false, -- harvest all Completed tiles
        PlantCrop        = "Onion", -- crop type for AutoPlant (cycle via UI button)
        SpeedBoost       = false,
        InfJump          = false,
        AntiAFK          = false,
        HighlightPlates  = false,
        HighlightCusts   = false,
        AutoSave         = true,
        ActiveTab        = "Farm",
        PanelOpen        = true,
    }
else
    local c = getgenv().__AURORA_RT3_CFG
    if c.ActiveTab == nil then c.ActiveTab = "Farm" end
    if c.PanelOpen == nil then c.PanelOpen = true end
end
local CFG = getgenv().__AURORA_RT3_CFG

---------- SAVE/LOAD ----------
local _cfgFileName = "aurora_cfg_restaurant_tycoon_3.json"
local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_restaurant_tycoon_3"] end
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
    end
end
local function saveCFG()
    pcall(function() if _HAS.writefile then writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end end)
    getgenv()["AuroraCFG_restaurant_tycoon_3"] = CFG
end
loadSavedCFG()

---------- STATE ----------
local S = {
    served = 0, dishesCleared = 0, tipsCollected = 0,
    ordersTaken = 0, billsCollected = 0, cooksFinished = 0,
    session = tick(),
}
local _currentAction = "Idle"

---------- TYCOON RESOLUTION ----------
local function myTycoon()
    local tycoons = workspace:FindFirstChild("Tycoons")
    if not tycoons then return nil end
    for _, t in ipairs(tycoons:GetChildren()) do
        local pv = t:FindFirstChild("Player")
        if pv and pv:IsA("ObjectValue") and pv.Value == Player then return t end
    end
    return nil
end

local function tpTo(cframeOrPos)
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if typeof(cframeOrPos) == "CFrame" then hrp.CFrame = cframeOrPos
    elseif typeof(cframeOrPos) == "Vector3" then hrp.CFrame = CFrame.new(cframeOrPos)
    else return false end
    return true
end

---------- FOOD / SERVE ----------
-- Each child of Tycoon.Objects.Food is a slot Model whose Name is the foodKey
-- (e.g. "1", "10"). Slot has attributes: Taken (bool), EatMethod (str). No PrimaryPart.
-- FoodModel passed to GrabFood is the slot itself.
local function slotAnchor(slot)
    local head = slot:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head.CFrame end
    local plate = slot:FindFirstChild("TestNewPlate")
    if plate and plate:IsA("BasePart") then return plate.CFrame end
    for _, d in ipairs(slot:GetChildren()) do
        if d:IsA("BasePart") then return d.CFrame end
    end
    local ok, pivot = pcall(function() return slot:GetPivot() end)
    if ok then return pivot end
    return nil
end

local function getReadyPlates(tyc)
    local out = {}
    local food = tyc and tyc:FindFirstChild("Objects") and tyc.Objects:FindFirstChild("Food")
    if not food then return out end
    for _, slot in ipairs(food:GetChildren()) do
        -- Real plate: Taken == false (empty slots have Taken == nil, grabbed ones == true)
        if slot:IsA("Model") and slot:GetAttribute("Taken") == false then
            table.insert(out, slot)
        end
    end
    return out
end

-- Find ALL NPC customers matching foodKey + kid flag (all WaitingForDish).
-- Returns a sorted list {gId, cId} ascending by group id so we always try the
-- earliest-ordered customer first, cycling to later ones if the server rejects.
local function findAllWaitingCustomers(tyc, foodKey, isKid)
    local out = {}
    if not CustomersMod then return out end
    local storage = nil
    pcall(function() storage = CustomersMod:GetStorage(tyc) end)
    if not (storage and storage.Groups) then return out end
    for groupId, group in pairs(storage.Groups) do
        for cid, cust in pairs(group.Customers or {}) do
            if cust.State == "WaitingForDish" and cust.Order == foodKey then
                local kidTruth = (cust.CustomerType == "Kid")
                if isKid == nil or isKid == kidTruth then
                    table.insert(out, {gId = groupId, cId = cid, sortKey = tonumber(groupId) or 0})
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.sortKey < b.sortKey end)
    return out
end

-- Single-match helper (backward compat for places that only need one)
local function findWaitingCustomer(tyc, foodKey, isKid)
    local all = findAllWaitingCustomers(tyc, foodKey, isKid)
    if #all == 0 then return nil, nil end
    return all[1].gId, all[1].cId
end

-- TakeOrder fires when a customer's State == "Ordering" (CustomerState.Ordering).
-- See decompiled Modules.Tasks.TakeOrder.Init
local function findOrderingCustomer(tyc)
    if not CustomersMod then return nil, nil end
    local storage = nil
    pcall(function() storage = CustomersMod:GetStorage(tyc) end)
    if not (storage and storage.Groups) then return nil, nil end
    for groupId, group in pairs(storage.Groups) do
        for cid, cust in pairs(group.Customers or {}) do
            if cust.State == "Ordering" then
                return groupId, cid
            end
        end
    end
    return nil, nil
end

local function findUnseatedGroup(tyc)
    if not CustomersMod then return nil end
    local storage = nil
    pcall(function() storage = CustomersMod:GetStorage(tyc) end)
    if not (storage and storage.Groups) then return nil end
    for groupId, group in pairs(storage.Groups) do
        local s = tostring(group.State)
        if s == "WaitingToBeSeated" or s == "Entering" or s == "Entered"
            or s == "WaitingForSeat" or s == "Idle" then
            -- Only seat groups that aren't already linked to a table
            if not group.FurnitureModel and not group.TableId then
                return groupId
            end
        end
    end
    return nil
end

-- Tycoon furniture layout (confirmed live 2026-04-22):
--   Tycoon.Items.Surface   — tables + counters (Trash/Bill live here)
--   Tycoon.Items.Furniture — chairs + misc props
--   Tycoon.Items.Walls     — walls (skip)
-- Return the list of roots to scan for serviceable models.
local function furnitureRoots(tyc)
    local roots = {}
    if not tyc then return roots end
    local items = tyc:FindFirstChild("Items")
    if items then
        local surf = items:FindFirstChild("Surface")
        if surf then table.insert(roots, surf) end
        local furn = items:FindFirstChild("Furniture")
        if furn then table.insert(roots, furn) end
    end
    -- Fallback: old Objects.Furniture path (not present on build-your-own)
    local obj = tyc:FindFirstChild("Objects")
    if obj and obj:FindFirstChild("Furniture") then
        table.insert(roots, obj.Furniture)
    end
    return roots
end

-- CollectBill is furniture-based — scan all furniture for unpaid Bill child.
local function findTablesWithBill(tyc)
    local out = {}
    for _, root in ipairs(furnitureRoots(tyc)) do
        for _, f in ipairs(root:GetChildren()) do
            if f:IsA("Model") then
                local bill = f:FindFirstChild("Bill")
                if bill and not bill:GetAttribute("Taken") then
                    table.insert(out, f)
                end
            end
        end
    end
    return out
end

-- Drive-thru car match via workspace scan (fallback when GrabFood returns TargetCarId)
local function findCarChassis(tyc, carId)
    local dt = tyc and tyc:FindFirstChild("Objects") and tyc.Objects:FindFirstChild("DriveThru")
    if not dt then return nil end
    local cars = dt:FindFirstChild("Cars")
    if not cars then return nil end
    local car = cars:FindFirstChild(tostring(carId))
    if not car then return nil end
    return car:FindFirstChild("Chassis", true) or car.PrimaryPart
end

---------- TABLE + TP HELPERS (v5.3) ----------
-- Chair proximity heuristic for table capacity. Live scan (plot 7, 76 chairs)
-- shows chairs cluster 6-10 studs from table pivot; 12 gives margin.
local CHAIR_RADIUS = 12
local function tableCapacity(tableModel, tyc)
    local okPv, pv = pcall(function() return tableModel:GetPivot() end)
    if not okPv or not pv then return 1 end
    local tPos = pv.Position
    local furn = tyc.Items and tyc.Items:FindFirstChild("Furniture")
    if not furn then return 1 end
    local count = 0
    for _, f in ipairs(furn:GetChildren()) do
        if f:IsA("Model") and isChairFurniture(f) then
            local ok2, p2 = pcall(function() return f:GetPivot() end)
            if ok2 and p2 and (p2.Position - tPos).Magnitude <= CHAIR_RADIUS then
                count = count + 1
            end
        end
    end
    return math.max(count, 1)
end

-- All tables for a tycoon, sorted by capacity ascending (smallest first).
local function listTablesWithCapacity(tyc)
    local out = {}
    local surface = tyc.Items and tyc.Items:FindFirstChild("Surface")
    if not surface then return out end
    for _, f in ipairs(surface:GetChildren()) do
        if f:IsA("Model") and isTableFurniture(f) then
            table.insert(out, {model = f, capacity = tableCapacity(f, tyc)})
        end
    end
    table.sort(out, function(a, b) return a.capacity < b.capacity end)
    return out
end

local function tpToTable(tableModel)
    local ok, pv = pcall(function() return tableModel:GetPivot() end)
    if ok and pv then pcall(function() tpTo(pv * CFrame.new(0, 2, 2)) end) end
end

local function tpToCustomerModel(tyc, groupId, customerId)
    local cc = tyc:FindFirstChild("ClientCustomers")
    if not cc then return end
    local grp = cc:FindFirstChild(tostring(groupId))
    if not grp then return end
    local c = customerId and grp:FindFirstChild(tostring(customerId)) or grp:GetChildren()[1]
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
    if hrp then pcall(function() tpTo(hrp.CFrame * CFrame.new(0, 0, 3)) end) end
end

local function saveHRP()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.CFrame or nil
end
local function restoreHRP(saved)
    if not saved then return end
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then pcall(function() hrp.CFrame = saved end) end
end

---------- AUTO SERVE — event-driven, TP, NPC retry, never cancel (v5.3) ----------
-- Slot lifecycle: Taken=nil (empty) → Taken=false (plate ready) → Taken=true (grabbed)
-- Strategy: listen to slot Taken attr changes + Food.ChildAdded. When ready, TP→grab→
-- retry-find-customer→TP→serve. Per-plate debounce prevents double-grab. Never cancel.
local _serveActive = {}

local function attemptServe(plate)
    if _serveActive[plate] then return end
    _serveActive[plate] = true
    local tyc = myTycoon()
    if not tyc or not plate.Parent then _serveActive[plate] = nil; return end
    if not TasksSystem then _serveActive[plate] = nil; return end
    local foodKey = plate.Name
    local saved = saveHRP()

    -- Pick a BasePart on the plate for the simulated click (Head = hold anchor)
    local platePart = plate:FindFirstChild("Head")
    if not (platePart and platePart:IsA("BasePart")) then
        platePart = plate:FindFirstChildWhichIsA("BasePart", true)
    end
    if not platePart then restoreHRP(saved); _serveActive[plate] = nil; return end

    -- TP near plate (HandleInput has a 32-stud distance check)
    _currentAction = "Grab click " .. foodKey
    pcall(function() tpTo(platePart.CFrame * CFrame.new(0, 2, 2)) end)
    task.wait(0.05)

    -- Simulate the left-click: Tasks:HandleInput(clickedPart, worldPos) — same path
    -- the game uses when the user clicks. Routes through InputUtility:GetFoodModel
    -- → TaskInputReceived → GrabFood:AttemptGrab → GrabFood:InvokeServer.
    pcall(function() TasksSystem:HandleInput(platePart, platePart.Position) end)

    -- Poll GrabFood.Storage up to 1s for our plate to appear. Server InvokeServer
    -- yields; we can't know its latency, so poll instead of fixed wait.
    local holding
    for attempt = 1, 20 do
        if GrabFoodSystem and GrabFoodSystem.Storage then
            for _, h in ipairs(GrabFoodSystem.Storage) do
                if h.Model == plate then holding = h; break end
            end
        end
        if holding then break end
        task.wait(0.05)
    end
    if not holding then
        restoreHRP(saved); _serveActive[plate] = nil; return
    end

    -- Helper: is the plate still in our Storage? (i.e. serve hasn't succeeded yet)
    local function stillHolding()
        if not (GrabFoodSystem and GrabFoodSystem.Storage) then return false end
        for _, h in ipairs(GrabFoodSystem.Storage) do
            if h.Model == plate then return true end
        end
        return false
    end

    -- Helper: fire serve with a given target spec + TP + wait to see if it sticks
    local function trySendTo(payload, tpTarget, label)
        if tpTarget and tpTarget:IsA("BasePart") then
            pcall(function() tpTo(tpTarget.CFrame * CFrame.new(0, 0, 3)) end)
            task.wait(0.05)
        end
        _currentAction = "Serving " .. foodKey .. " → " .. label
        pcall(function() R_TaskCompleted:FireServer(payload) end)
        -- Wait 0.6s for server to clear Storage on success
        for w = 1, 12 do
            task.wait(0.05)
            if not stillHolding() then return true end
        end
        return false
    end

    local served = false

    -- PLAYER target — single shot
    if holding.TargetPlayerName then
        local p = Players:FindFirstChild(holding.TargetPlayerName)
        if p then
            local part = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            served = trySendTo({Name="Serve", FoodModel=plate, Tycoon=tyc, Player=p}, part, "P:"..p.Name)
        end
    -- CAR target — single shot
    elseif holding.TargetCarId then
        local part = findCarChassis(tyc, holding.TargetCarId)
        served = trySendTo({Name="Serve", FoodModel=plate, Tycoon=tyc, CarId=holding.TargetCarId}, part, "Car:"..tostring(holding.TargetCarId))
    -- NPC target — cycle through all matching customers until server accepts one
    else
        -- Wait for customer list to populate (up to 3s if replication is lagging)
        local candidates = findAllWaitingCustomers(tyc, foodKey, holding.KidFlag)
        if #candidates == 0 then
            for attempt = 1, 20 do
                task.wait(0.15)
                candidates = findAllWaitingCustomers(tyc, foodKey, holding.KidFlag)
                if #candidates > 0 then break end
                if not (plate.Parent and CFG.AutoServe) then break end
            end
        end
        -- Try each candidate until Storage clears (= server accepted)
        for _, cand in ipairs(candidates) do
            if served or not CFG.AutoServe or not plate.Parent then break end
            local cc = tyc:FindFirstChild("ClientCustomers")
            local grp = cc and cc:FindFirstChild(tostring(cand.gId))
            local cm = grp and grp:FindFirstChild(tostring(cand.cId))
            local part = cm and (cm:FindFirstChild("HumanoidRootPart") or cm.PrimaryPart)
            served = trySendTo({
                Name = "Serve", FoodModel = plate, Tycoon = tyc,
                GroupId = cand.gId, CustomerId = cand.cId,
            }, part, "G"..cand.gId.."C"..cand.cId)
        end
    end

    if served then
        S.served = S.served + 1
    else
        -- All attempts failed — last-ditch click-sim on first candidate's Head
        -- (click simulation may unlock a server code path direct fire can't)
        if not holding.TargetPlayerName and not holding.TargetCarId then
            local candidates = findAllWaitingCustomers(tyc, foodKey, holding.KidFlag)
            if candidates[1] then
                local cc = tyc:FindFirstChild("ClientCustomers")
                local grp = cc and cc:FindFirstChild(tostring(candidates[1].gId))
                local cm = grp and grp:FindFirstChild(tostring(candidates[1].cId))
                local head = cm and cm:FindFirstChild("Head")
                if head and head:IsA("BasePart") then
                    pcall(function() tpTo(head.CFrame * CFrame.new(0, 0, 3)) end)
                    task.wait(0.05)
                    _currentAction = "Serve click-sim fallback " .. foodKey
                    pcall(function() TasksSystem:HandleInput(head, head.Position) end)
                    task.wait(0.5)
                    if not stillHolding() then S.served = S.served + 1 end
                end
            end
        end
    end

    restoreHRP(saved)
    _serveActive[plate] = nil
end

-- High-rate polling — 20Hz covers the narrow window before workers claim plates.
-- Event-listener approach (GetAttributeChangedSignal) missed zero-duration Taken
-- transitions empirically. Cheap — ~29 slots × 20Hz = 580 reads/s.
task.spawn(function()
    while alive() do
        task.wait(0.05)
        if not alive() then break end
        if not CFG.AutoServe then continue end
        local tyc = myTycoon()
        local food = tyc and tyc.Objects and tyc.Objects:FindFirstChild("Food")
        if not food then continue end
        for _, slot in ipairs(food:GetChildren()) do
            if not (alive() and CFG.AutoServe) then break end
            -- Taken ~= true catches ready (false) AND pre-ready (nil) plates.
            -- Server-side worker claim often skips client's Taken=false window.
            -- Tasks:HandleInput has its own gates; invalid plates fail fast.
            if slot:IsA("Model") and slot:GetAttribute("Taken") ~= true
                and not _serveActive[slot] then
                task.spawn(attemptServe, slot)
            end
        end
    end
end)

---------- AUTO COLLECT DISHES — table scan with per-table debounce (v5.3) ----------
-- Tables live at Tycoon.Items.Surface. A table Model has Trash child with Collectable=true
-- when ready to bus. FurnitureUtility:IsTable(name) is the correct discriminator.
local _dishDebounce = {}
local function fireDishes(tableModel, tyc)
    if _dishDebounce[tableModel] then return end
    _dishDebounce[tableModel] = true
    _currentAction = "Bussing " .. tableModel.Name
    local saved = saveHRP()
    tpToTable(tableModel)
    pcall(function()
        R_TaskCompleted:FireServer({Name = "CollectDishes", FurnitureModel = tableModel, Tycoon = tyc})
    end)
    S.dishesCleared = S.dishesCleared + 1
    restoreHRP(saved)
    task.delay(1, function() _dishDebounce[tableModel] = nil end)
end

task.spawn(function()
    while alive() do
        task.wait(0.5)
        if not alive() then break end
        if not CFG.AutoCollectDish then continue end
        local tyc = myTycoon()
        local surface = tyc and tyc.Items and tyc.Items:FindFirstChild("Surface")
        if not surface then continue end
        for _, f in ipairs(surface:GetChildren()) do
            if not (alive() and CFG.AutoCollectDish) then break end
            if f:IsA("Model") and isTableFurniture(f) then
                local trash = f:FindFirstChild("Trash")
                if trash and trash:GetAttribute("Collectable") == true then
                    fireDishes(f, tyc)
                end
            end
        end
    end
end)

---------- CORE LOOP: AUTO COLLECT TIPS (money pile) ----------
task.spawn(function()
    while alive() do
        task.wait(3)
        if not alive() then break end
        if not CFG.AutoCollectTips then continue end
        local tyc = myTycoon()
        if not tyc then continue end
        _currentAction = "Collecting tips"
        pcall(function() R_TipsCollected:FireServer(tyc) end)
        S.tipsCollected = S.tipsCollected + 1
    end
end)

---------- CORE LOOP: AUTO COLLECT BILL (restored v5.2 behavior) ----------
-- Bill is placed on the table (FurnitureModel.Bill child) after group leaves.
-- Payload: {Name="CollectBill", FurnitureModel=table, Tycoon=t}
task.spawn(function()
    while alive() do
        task.wait(1.2)
        if not alive() then break end
        if not CFG.AutoCollectBill then continue end
        local tyc = myTycoon()
        if not tyc then continue end
        local tables = findTablesWithBill(tyc)
        for _, f in ipairs(tables) do
            if not (alive() and CFG.AutoCollectBill) then break end
            _currentAction = "Collecting bill " .. f.Name
            pcall(function()
                R_TaskCompleted:FireServer({
                    Name = "CollectBill",
                    FurnitureModel = f,
                    Tycoon = tyc,
                })
            end)
            S.billsCollected = S.billsCollected + 1
            task.wait(0.15)
        end
    end
end)

---------- AUTO PLANT — plant CFG.PlantCrop on all Empty tiles (v5.3d) ----------
-- RequestCropPlant:InvokeServer(cropType, tileName) — server returns (msg, success, debug).
-- Tile states via Farming:GetState(tile): Locked / Empty / Growing / Completed.
local _plantDebounce = {}  -- [tile] = true briefly to avoid double-plant races
task.spawn(function()
    while alive() do
        task.wait(1)
        if not alive() then break end
        if not CFG.AutoPlant then continue end
        if not (FarmingSystem and FarmingSystem.Plot) then continue end
        local tiles = FarmingSystem.Plot:FindFirstChild("Tiles")
        if not tiles then continue end
        local crop = CFG.PlantCrop or "Onion"
        for _, tile in ipairs(tiles:GetChildren()) do
            if not (alive() and CFG.AutoPlant) then break end
            if not _plantDebounce[tile] then
                local state = FarmingSystem:GetState(tile)
                if state == FarmingSystem.States.Empty then
                    _plantDebounce[tile] = true
                    _currentAction = "Planting " .. crop .. " on " .. tile.Name
                    pcall(function()
                        RS.Events.Farming.RequestCropPlant:InvokeServer(crop, tile.Name)
                    end)
                    task.delay(2, function() _plantDebounce[tile] = nil end)
                    task.wait(0.2)
                end
            end
        end
    end
end)

---------- AUTO HARVEST — harvest all Completed tiles (v5.3d) ----------
local _harvestDebounce = {}
task.spawn(function()
    while alive() do
        task.wait(1)
        if not alive() then break end
        if not CFG.AutoHarvest then continue end
        if not (FarmingSystem and FarmingSystem.Plot) then continue end
        local tiles = FarmingSystem.Plot:FindFirstChild("Tiles")
        if not tiles then continue end
        for _, tile in ipairs(tiles:GetChildren()) do
            if not (alive() and CFG.AutoHarvest) then break end
            if not _harvestDebounce[tile] then
                local state = FarmingSystem:GetState(tile)
                if state == FarmingSystem.States.Completed then
                    _harvestDebounce[tile] = true
                    _currentAction = "Harvesting " .. tile.Name
                    pcall(function()
                        RS.Events.Farming.RequestHarvest:InvokeServer(tile.Name)
                    end)
                    task.delay(2, function() _harvestDebounce[tile] = nil end)
                    task.wait(0.2)
                end
            end
        end
    end
end)

---------- CORE LOOP: AUTO TAKE ORDER ----------
task.spawn(function()
    while alive() do
        task.wait(0.8)
        if not alive() then break end
        if not CFG.AutoTakeOrder then continue end
        local tyc = myTycoon()
        if not tyc then continue end
        local gId, cId = findOrderingCustomer(tyc)
        if not gId then continue end
        _currentAction = "Taking order G" .. tostring(gId)
        pcall(function()
            R_TaskCompleted:FireServer({
                Name = "TakeOrder",
                GroupId = gId,
                CustomerId = cId,
                Tycoon = tyc,
            })
        end)
        S.ordersTaken = S.ordersTaken + 1
        task.wait(0.25)
    end
end)

---------- AUTO SEAT GROUPS — game-module flow, cycle tables until server accepts (v5.3c) ----------
-- The server requires an active SendToTable task state before accepting the completion
-- (same pattern as GrabFood needing click context). So we call the game's own
-- SendToTable module methods:
--   1. AskToSend(tyc, gId)   — sets Tasks.CurrentTask = {Name="SendToTable", ...}
--   2. CompleteSend(tblModel) — fires TaskCompleted with FurnitureModel attached
-- Between candidates, Tasks:ResetTask() clears stale state so the next AskToSend is clean.
-- Success detection: poll group.State — if it leaves unseated set, server accepted.
local _seatDebounce = {}  -- [groupId] = lastFullCycleTick

local function isUnseatedState(s)
    s = tostring(s or "")
    return s == "Idle" or s == "Entering"
end

local function attemptSeat(tyc, groupId, grp)
    -- Per-group debounce: don't retry more than once every 2s
    local lastTry = _seatDebounce[groupId]
    if lastTry and tick() - lastTry < 2 then return end

    if not SendToTableSystem or not TasksSystem then return end

    local numCust = grp.NumCustomers or 1
    local all = listTablesWithCapacity(tyc)
    local fitting = {}
    for _, t in ipairs(all) do
        if t.capacity >= numCust and not t.model:GetAttribute("InUse") then
            table.insert(fitting, t)
        end
    end
    if #fitting == 0 then return end

    _seatDebounce[groupId] = tick()

    -- Cycle all candidates (smallest-fit first, bigger on rejection)
    for _, cand in ipairs(fitting) do
        if not (alive() and CFG.AutoSendToTable) then break end

        _currentAction = string.format("Seating G%s (%d) → %s cap %d",
            tostring(groupId), numCust, cand.model.Name, cand.capacity)

        -- TP near group NPC first (server may check proximity when it validates)
        tpToCustomerModel(tyc, groupId, nil)
        task.wait(0.05)

        -- Step 1: AskToSend sets Tasks.CurrentTask = {Name="SendToTable", GroupId, Tycoon}
        pcall(function() SendToTableSystem:AskToSend(tyc, groupId) end)
        task.wait(0.05)

        -- TP to table for the completion click's proximity
        tpToTable(cand.model)
        task.wait(0.05)

        -- Step 2: CompleteSend reads Tasks.CurrentTask, adds FurnitureModel, fires TaskCompleted
        pcall(function() SendToTableSystem:CompleteSend(cand.model) end)

        -- Poll group.State up to 0.7s — if it changes, server accepted
        local ok = false
        for w = 1, 14 do
            task.wait(0.05)
            local st
            pcall(function() st = CustomersMod:GetStorage(tyc) end)
            local g = st and st.Groups and st.Groups[groupId]
            if not g then ok = true; break end  -- group removed = edge-case success
            if not isUnseatedState(g.State) then ok = true; break end
        end
        if ok then
            _seatDebounce[groupId] = nil  -- group is gone, clear tracker
            return
        end

        -- Failed — reset task state before trying next table
        pcall(function() TasksSystem:ResetTask() end)
    end
end

task.spawn(function()
    while alive() do
        task.wait(0.5)
        if not alive() then break end
        if not CFG.AutoSendToTable then _seatDebounce = {}; continue end
        local tyc = myTycoon()
        if not tyc or not CustomersMod then continue end
        local storage
        pcall(function() storage = CustomersMod:GetStorage(tyc) end)
        if not (storage and storage.Groups) then continue end
        for gId, grp in pairs(storage.Groups) do
            if not (alive() and CFG.AutoSendToTable) then break end
            if isUnseatedState(grp.State) then
                attemptSeat(tyc, gId, grp)
            else
                _seatDebounce[gId] = nil
            end
        end
    end
end)

---------- CORE LOOP: AUTO COOK (Chef + Barista stations) ----------
task.spawn(function()
    while alive() do
        task.wait(0.4)
        if not alive() then break end
        if not CFG.AutoCook then continue end
        local tyc = myTycoon()
        if not tyc then continue end
        local cr = tyc:FindFirstChild("Objects") and tyc.Objects:FindFirstChild("CookingResources")
        if not cr then continue end
        for _, station in ipairs(cr:GetChildren()) do
            if not (alive() and CFG.AutoCook) then break end
            local role, index = nil, nil
            if station.Name:find("^Chef(%d+)$") then
                role = "Chef"; index = station.Name
            elseif station.Name:find("^Barista(%d+)$") then
                role = "Barista"; index = station.Name
            end
            if role then
                _currentAction = role .. " " .. index
                pcall(function() R_ChefCookInput:FireServer("Interact", role, index) end)
                task.wait(0.08)
                pcall(function() R_ChefCookInput:FireServer("CompleteTask", role, index) end)
                S.cooksFinished = S.cooksFinished + 1
                task.wait(0.05)
            end
        end
    end
end)

---------- CORE LOOP: AUTO DAILY ----------
task.spawn(function()
    while alive() do
        if not alive() then break end
        if CFG.AutoDaily then
            pcall(function() R_DailyReward:FireServer() end)
        end
        task.wait(120)
    end
end)

---------- SPEED / INF JUMP / ANTI-AFK ----------
local _speedOn = false
task.spawn(function()
    while alive() do
        task.wait(jitter(0.5, 0.5))
        if not alive() then break end
        pcall(function()
            local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if CFG.SpeedBoost then hum.WalkSpeed = 40; hum.JumpPower = 60; _speedOn = true
            elseif _speedOn then hum.WalkSpeed = 16; hum.JumpPower = 50; _speedOn = false end
        end)
    end
end)

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

task.spawn(function()
    while alive() do
        if not alive() then break end
        if CFG.AntiAFK then
            pcall(function() local v = game:GetService("VirtualUser"); v:CaptureController(); v:ClickButton2(Vector2.new()) end)
        end
        task.wait(60)
    end
end)

---------- HIGHLIGHT (ready plates + waiting customers) ----------
local _highlights = {}
local function clearHighlights()
    for k, v in pairs(_highlights) do
        pcall(function() if v.h then v.h:Destroy() end end)
        _highlights[k] = nil
    end
end
task.spawn(function()
    while alive() do
        task.wait(0.5)
        if not alive() then break end
        if (not CFG.HighlightPlates) and (not CFG.HighlightCusts) then
            clearHighlights()
            continue
        end
        local tyc = myTycoon()
        if not tyc then continue end
        local wanted = {}
        if CFG.HighlightPlates then
            for _, p in ipairs(getReadyPlates(tyc)) do
                wanted[p] = {type = "plate", color = Color3.fromRGB(252,110,142)}
            end
        end
        if CFG.HighlightCusts and CustomersMod then
            local storage = nil
            pcall(function() storage = CustomersMod:GetStorage(tyc) end)
            if storage and storage.Groups then
                local cFolder = tyc:FindFirstChild("Customers", true)
                for groupId, group in pairs(storage.Groups) do
                    for cid, cust in pairs(group.Customers or {}) do
                        if cust.State == "WaitingForDish" or cust.State == "WaitingForOrder" or cust.State == "WaitingForBillCollection" then
                            local color = Color3.fromRGB(255, 200, 80)
                            if cust.State == "WaitingForBillCollection" then color = Color3.fromRGB(0, 200, 100) end
                            local model = nil
                            if cFolder then
                                local grp = cFolder:FindFirstChild(tostring(groupId))
                                if grp then model = grp:FindFirstChild(tostring(cid)) end
                            end
                            if model then wanted[model] = {type = "cust", color = color} end
                        end
                    end
                end
            end
        end
        -- Add new
        for inst, meta in pairs(wanted) do
            if not _highlights[inst] then
                local h = Instance.new("Highlight")
                h.Name = "AuroraHL"
                h.FillColor = meta.color
                h.OutlineColor = Color3.fromRGB(255,255,255)
                h.FillTransparency = 0.6
                h.OutlineTransparency = 0.1
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                pcall(function() h.Adornee = inst; h.Parent = inst end)
                _highlights[inst] = {h = h}
            end
        end
        -- Remove stale
        for inst, rec in pairs(_highlights) do
            if not wanted[inst] or not inst.Parent then
                pcall(function() rec.h:Destroy() end)
                _highlights[inst] = nil
            end
        end
    end
end)

-- ========================================================================
-- V5 3-COLUMN UI (shared with Timber v5.2 template)
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

local _vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local _mobile = UIS.TouchEnabled and (_vp.X < 1200)
local _scale = _mobile and math.clamp(_vp.X / 1200, 0.5, 0.85) or 1

local main = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    ClipsDescendants = true, Visible = CFG.PanelOpen,
}, screenGui)
corner(main, 14); stroke(main, C.border2, 1, 0)
if _scale ~= 1 then local sc = Instance.new("UIScale"); sc.Scale = _scale; sc.Parent = main end

local watermark = create("TextLabel", {
    Name = "Watermark", Size = UDim2.fromOffset(800, 120),
    Position = UDim2.fromOffset(TOTAL_W / 2, TOTAL_H / 2),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
    Font = F_SANS_BOLD, TextSize = 72, TextColor3 = C.pink,
    TextTransparency = 0.82, TextStrokeTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 1,
}, main)
watermark.RichText = true
watermark.Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>'

local content = create("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2,
}, main)

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

local TABS = {
    { name = "Farm",    icon = "●" },
    { name = "Staff",   icon = "◆" },
    { name = "Utility", icon = "≡" },
}
local tabMap = {}
local function paintTabs()
    for name, t in pairs(tabMap) do
        local on = (CFG.ActiveTab == name)
        local offCol = t.dimInactive and C.text3 or C.text2
        t.accent.Visible = on
        t.bg.BackgroundTransparency = on and 0.85 or 1
        t.label.TextColor3 = on and C.text or offCol
        t.label.Font = on and F_SANS_SEMI or F_SANS
        t.icon.TextColor3 = on and C.pink or C.text3
    end
end
local TAB_Y0 = 66; local TAB_H = 34; local TAB_GAP = 3

local switchTab = function(_) end
local _openPopup = nil
local _skipNextOutside = false
local closeOpenPopup = function() end

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
    bgGrad.Rotation = 0; bgGrad.Parent = row
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
    tabMap[tinfo.name] = {bg = row, accent = accent, icon = icon, label = label, dimInactive = dimInactive or false}
    return row
end

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
local SET_H = 36; local SET_PAD = 10; local SET_Y = TOTAL_H - SET_H - SET_PAD
create("Frame", {
    Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, SET_Y - 6),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, sidebar)
local setRow = makeTabRow({name = "Settings", icon = "⚙"}, SET_Y, true)
setRow.Size = UDim2.fromOffset(SIDEBAR_W - 20, SET_H)
setRow.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        switchTab("Settings")
    end
end)

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
    panels[tabName][which] = {frame = p, scroll = scroll}
    return scroll
end

local TAB_NAMES = {"Farm", "Staff", "Utility", "Settings"}
local TAB_ACCENT = {Farm = C.pink, Staff = C.purple, Utility = C.pink, Settings = C.pink}
local PANEL_TITLES = {
    Farm     = {alpha = "AUTO FARM",   beta = "FARM STATUS"},
    Staff    = {alpha = "STAFF",       beta = "STATIONS"},
    Utility  = {alpha = "PLAYER",      beta = "ACTIONS"},
    Settings = {alpha = "CONFIG",      beta = "ABOUT"},
}
local scrolls = {}
for _, tn in ipairs(TAB_NAMES) do
    local acc = TAB_ACCENT[tn]; local t = PANEL_TITLES[tn]
    scrolls[tn .. "_alpha"] = makePanel(tn, "alpha", SIDEBAR_W, PA_W, acc, t.alpha)
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
            {Position = UDim2.fromOffset(on and 19 or 3, 3)}):Play()
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

---------- POPULATE: FARM ----------
local oF_a, oF_b = 0, 0
local function nFa() oF_a = oF_a + 1; return oF_a end
local function nFb() oF_b = oF_b + 1; return oF_b end

sectionHeader(scrolls["Farm_alpha"], "●", "Service Loop", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Serve (Grab + Deliver)", "AutoServe", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Take Orders",            "AutoTakeOrder", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Seat Groups",            "AutoSendToTable", nFa())

sectionHeader(scrolls["Farm_alpha"], "◉", "Money & Cleanup", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Collect Tips",   "AutoCollectTips", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Collect Dishes", "AutoCollectDish", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Collect Bill",   "AutoCollectBill", nFa())

sectionHeader(scrolls["Farm_alpha"], "✿", "Farming", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Plant",   "AutoPlant",   nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Harvest", "AutoHarvest", nFa())

-- Crop cycle button (click to cycle through available crops)
local CROPS_LIST = {"Onion", "Flour", "Sugar", "Pepper", "Tomato", "Potato", "Carrot", "Banana", "Lettuce", "Berries", "Pumpkin", "Apple"}
local _cropBtnLabel
_cropBtnLabel = actionBtn(scrolls["Farm_alpha"], "Crop: " .. (CFG.PlantCrop or "Onion"), C.bg3, nFa(), function()
    local cur = CFG.PlantCrop or "Onion"
    local idx = 1
    for i, c in ipairs(CROPS_LIST) do if c == cur then idx = i; break end end
    idx = (idx % #CROPS_LIST) + 1
    CFG.PlantCrop = CROPS_LIST[idx]
    if CFG.AutoSave then saveCFG() end
    -- Update the button label (actionBtn returns the frame; find its TextLabel child)
    if _cropBtnLabel then
        for _, c in ipairs(_cropBtnLabel:GetDescendants()) do
            if c:IsA("TextLabel") then c.Text = "Crop: " .. CFG.PlantCrop; break end
        end
    end
end)

sectionHeader(scrolls["Farm_alpha"], "◆", "Highlights", nFa())
toggleRow    (scrolls["Farm_alpha"], "Highlight Ready Plates",   "HighlightPlates", nFa())
toggleRow    (scrolls["Farm_alpha"], "Highlight Waiting Customers", "HighlightCusts", nFa())

sectionHeader(scrolls["Farm_alpha"], "▣", "Manual", nFa())
actionBtn(scrolls["Farm_alpha"], "Collect Tips Now", C.bg3, nFa(), function()
    local tyc = myTycoon(); if tyc then pcall(function() R_TipsCollected:FireServer(tyc) end) end
end)
actionBtn(scrolls["Farm_alpha"], "Cancel Grab", C.bg3, nFa(), function()
    pcall(function() R_CancelGrab:FireServer() end)
end)
actionBtn(scrolls["Farm_alpha"], "Claim Daily Reward", C.bg3, nFa(), function()
    pcall(function() R_DailyReward:FireServer() end)
end)

sectionHeader(scrolls["Farm_alpha"], "✦", "Notes", nFa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "Auto Serve grabs ready plates\nand fires TaskCompleted to the\nmatching customer/car/player.\n\nNote: if you have hired workers,\nthey'll claim plates first. Best\nwith workers fired or solo start.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = nFa(),
}, scrolls["Farm_alpha"])

sectionHeader(scrolls["Farm_beta"], "●", "Current", nFb())
local _infoAction = infoRow(scrolls["Farm_beta"], "Action", "Idle", C.pink, nFb())
local _infoTycoon = infoRow(scrolls["Farm_beta"], "Tycoon", "—", C.text, nFb())

sectionHeader(scrolls["Farm_beta"], "◉", "Session Totals", nFb())
local _infoServed  = infoRow(scrolls["Farm_beta"], "Served",          "0", C.pink, nFb())
local _infoDishes  = infoRow(scrolls["Farm_beta"], "Dishes Bussed",   "0", C.pink, nFb())
local _infoTips    = infoRow(scrolls["Farm_beta"], "Tips Collected",  "0", C.pink, nFb())
local _infoOrders  = infoRow(scrolls["Farm_beta"], "Orders Taken",    "0", C.pink, nFb())
local _infoBills   = infoRow(scrolls["Farm_beta"], "Bills Collected", "0", C.pink, nFb())
local _infoCooks   = infoRow(scrolls["Farm_beta"], "Cook Ticks",      "0", C.purple, nFb())

sectionHeader(scrolls["Farm_beta"], "◆", "Queue", nFb())
local _infoPlates  = infoRow(scrolls["Farm_beta"], "Ready Plates", "0", C.text, nFb())
local _infoWaitDish = infoRow(scrolls["Farm_beta"], "Waiting Dish", "0", C.text2, nFb())
local _infoWaitOrd = infoRow(scrolls["Farm_beta"], "Waiting Order", "0", C.text2, nFb())

sectionHeader(scrolls["Farm_beta"], "▣", "Restaurant", nFb())
local _infoTables     = infoRow(scrolls["Farm_beta"], "Tables",      "0", C.text,  nFb())
local _infoTablesFree = infoRow(scrolls["Farm_beta"], "Tables Free", "0", C.green, nFb())
local _infoTablesFull = infoRow(scrolls["Farm_beta"], "Tables Full", "0", C.pink,  nFb())
local _infoChairs     = infoRow(scrolls["Farm_beta"], "Chairs",      "0", C.text2, nFb())
local _infoSeatTarget = infoRow(scrolls["Farm_beta"], "Seat Target", "—", C.purple, nFb())

sectionHeader(scrolls["Farm_beta"], "✦", "Session", nFb())
local _infoRuntime = infoRow(scrolls["Farm_beta"], "Runtime", "0m", C.text2, nFb())

---------- POPULATE: STAFF ----------
local oS_a = 0
local function nSa() oS_a = oS_a + 1; return oS_a end

sectionHeader(scrolls["Staff_alpha"], "●", "Auto Cook", nSa())
toggleRow    (scrolls["Staff_alpha"], "Auto Cook (Chef + Barista)", "AutoCook", nSa())

sectionHeader(scrolls["Staff_alpha"], "◆", "Manual Station Tap", nSa())
for _, name in ipairs({"Chef1", "Chef2", "Chef3"}) do
    actionBtn(scrolls["Staff_alpha"], "Tap " .. name, C.bg3, nSa(), function()
        pcall(function() R_ChefCookInput:FireServer("Interact", "Chef", name) end)
        task.wait(0.1)
        pcall(function() R_ChefCookInput:FireServer("CompleteTask", "Chef", name) end)
    end)
end
for _, name in ipairs({"Barista1", "Barista2"}) do
    actionBtn(scrolls["Staff_alpha"], "Tap " .. name, C.bg3, nSa(), function()
        pcall(function() R_ChefCookInput:FireServer("Interact", "Barista", name) end)
        task.wait(0.1)
        pcall(function() R_ChefCookInput:FireServer("CompleteTask", "Barista", name) end)
    end)
end

sectionHeader(scrolls["Staff_beta"], "●", "Stations", nSa())
local _infoStaff = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1,
    Text = "Loading stations...",
    Font = F_MONO, TextSize = 10, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = 99,
}, scrolls["Staff_beta"])

---------- POPULATE: UTILITY ----------
local oU_a = 0
local function nUa() oU_a = oU_a + 1; return oU_a end

sectionHeader(scrolls["Utility_alpha"], "●", "Player", nUa())
toggleRow    (scrolls["Utility_alpha"], "Speed Boost",  "SpeedBoost", nUa())
toggleRow    (scrolls["Utility_alpha"], "Infinite Jump", "InfJump",   nUa())

sectionHeader(scrolls["Utility_alpha"], "◉", "Safety", nUa())
toggleRow    (scrolls["Utility_alpha"], "Anti-AFK", "AntiAFK", nUa())

sectionHeader(scrolls["Utility_alpha"], "◆", "Auto Claim", nUa())
toggleRow    (scrolls["Utility_alpha"], "Auto Daily Reward", "AutoDaily", nUa())

sectionHeader(scrolls["Utility_alpha"], "▣", "Stats", nUa())
local _infoHealth = infoRow(scrolls["Utility_alpha"], "Health", "---", C.text, nUa())
local _infoSpeed  = infoRow(scrolls["Utility_alpha"], "Speed",  "16",  C.text, nUa())

sectionHeader(scrolls["Utility_beta"], "●", "Teleport", nUa())
actionBtn(scrolls["Utility_beta"], "TP to Kitchen", C.bg3, nUa(), function()
    local tyc = myTycoon()
    if not tyc then return end
    local cr = tyc:FindFirstChild("Objects") and tyc.Objects:FindFirstChild("CookingResources")
    local chef = cr and cr:FindFirstChild("Chef1")
    if chef and chef.PrimaryPart then tpTo(chef.PrimaryPart.CFrame * CFrame.new(0, 0, 4)) end
end)
actionBtn(scrolls["Utility_beta"], "TP to Tycoon Base", C.bg3, nUa(), function()
    local tyc = myTycoon()
    if not tyc then return end
    local loc = tyc:FindFirstChild("Locations")
    local base = loc and (loc:FindFirstChild("DefaultEntrance") or loc:FindFirstChild("Base"))
    if base and base.Value then pcall(function() tpTo(base.Value) end) end
end)
actionBtn(scrolls["Utility_beta"], "Reset Character", C.bg3, nUa(), function()
    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
end)

sectionHeader(scrolls["Utility_beta"], "✦", "Notes", nUa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Speed Boost = 40 (soft cap).\nInf Jump is client-side.\nAuto Daily fires every 2 min —\nserver silently rejects cooldown.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = nUa(),
}, scrolls["Utility_beta"])

---------- POPULATE: SETTINGS ----------
local oSe_a, oSe_b = 0, 0
local function nSeA() oSe_a = oSe_a + 1; return oSe_a end
local function nSeB() oSe_b = oSe_b + 1; return oSe_b end

sectionHeader(scrolls["Settings_alpha"], "●", "Config", nSeA())
toggleRow    (scrolls["Settings_alpha"], "Auto Save", "AutoSave", nSeA())
actionBtn    (scrolls["Settings_alpha"], "Save Config Now", C.green, nSeA(), function() saveCFG() end)
actionBtn    (scrolls["Settings_alpha"], "Load Config",     C.bg3,   nSeA(), function() loadSavedCFG() end)
actionBtn    (scrolls["Settings_alpha"], "Reset Config",    C.red,   nSeA(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    CFG.AutoSave = true
    saveCFG()
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSeA())
actionBtn    (scrolls["Settings_alpha"], "Reset Position", C.bg3, nSeA(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn    (scrolls["Settings_alpha"], "Destroy UI", C.red, nSeA(), function()
    task.wait(0.3)
    getgenv().__AURORA_RT3_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSeB())
infoRow(scrolls["Settings_beta"], "Game",    "Restaurant Tycoon 3",        C.text,  nSeB())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),       C.text2, nSeB())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion),  C.text2, nSeB())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",              C.pink,  nSeB())
infoRow(scrolls["Settings_beta"], "Build",   "v5.3d",                      C.text2, nSeB())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,                 C.text3, nSeB())
infoRow(scrolls["Settings_beta"], "Network", "Named RemoteEvents",         C.text3, nSeB())

sectionHeader(scrolls["Settings_beta"], "◆", "Active Features", nSeB())
local _cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 200),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nSeB(),
}, scrolls["Settings_beta"])

---------- LIVE GAME PANEL ----------
local oL = 0
local function nL() oL = oL + 1; return oL end

sectionHeader(liveScroll, "◉", "Session", nL())
local _liveRuntime = infoRow(liveScroll, "Runtime", "0m", C.text2, nL())
local _liveAction  = infoRow(liveScroll, "Action",  "Idle", C.pink, nL())

sectionHeader(liveScroll, "●", "Queue", nL())
local _livePlates = infoRow(liveScroll, "Plates",  "0", C.text,  nL())
local _liveOrders = infoRow(liveScroll, "Orders",  "0", C.text2, nL())

sectionHeader(liveScroll, "✦", "Totals", nL())
local _liveServed = infoRow(liveScroll, "Served", "0", C.pink, nL())
local _liveTips   = infoRow(liveScroll, "Tips",   "0", C.pink, nL())
local _liveDishes = infoRow(liveScroll, "Dishes", "0", C.pink, nL())

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
}, pill); corner(pillDotGlow, 9)
local pillDotGlowInner = create("Frame", {
    Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(12, 12),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.55,
    BorderSizePixel = 0, ZIndex = 2,
}, pill); corner(pillDotGlowInner, 6)
local pillDot = create("Frame", {
    Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(14, 14),
    BackgroundColor3 = C.green, BorderSizePixel = 0, ZIndex = 3,
}, pill); corner(pillDot, 4)
task.spawn(function()
    local outerTween = TweenService:Create(pillDotGlow,
        TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BackgroundTransparency = 0.55, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(7, 7)})
    local innerTween = TweenService:Create(pillDotGlowInner,
        TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BackgroundTransparency = 0.35})
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
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        CFG.PanelOpen = not CFG.PanelOpen
        main.Visible = CFG.PanelOpen
    end
end)

---------- DRAG ----------
local topDragStrip = create("Frame", {
    Name = "TopDragStrip",
    Size = UDim2.fromOffset(TOTAL_W - SIDEBAR_W, 48),
    Position = UDim2.fromOffset(SIDEBAR_W, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    Active = true, ZIndex = 3,
}, content)
local _drag = {active = false, start = nil, startPos = nil}
local function attachDrag(handle)
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            _drag.active = true
            _drag.start = inp.Position
            _drag.startPos = main.Position
            closeOpenPopup()
        end
    end)
end
attachDrag(wordmarkRow); attachDrag(topDragStrip)
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

---------- CLOSE + MINIMIZE BUTTONS ----------
local minBtn = create("Frame", {
    Name = "Minimize", Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 62, 13),
    BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true, ZIndex = 5,
}, content)
corner(minBtn, 11); stroke(minBtn, C.border2, 1, 0)
local minLine = create("Frame", {
    Size = UDim2.fromOffset(10, 2), Position = UDim2.new(0.5, -5, 0.5, -1),
    BackgroundColor3 = C.text2, BorderSizePixel = 0, ZIndex = 6,
}, minBtn); corner(minLine, 1)
minBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        minBtn.BackgroundColor3 = C.pink; minLine.BackgroundColor3 = C.white
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
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
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        getgenv().__AURORA_RT3_SESSION = 0
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
            local hpTxt, spTxt = "---", "16"
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hpTxt = string.format("%.0f/%.0f", hum.Health, hum.MaxHealth)
                    spTxt = tostring(math.floor(hum.WalkSpeed))
                end
            end

            local elapsed = tick() - S.session
            local mins = math.floor(elapsed / 60)
            local hrs = math.floor(mins / 60)
            local rtime = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            local tyc = myTycoon()
            local tName = tyc and (tyc.Name .. " #" .. tostring(tyc:GetAttribute("PlotId") or "?")) or "none"

            local plateCount = 0
            local waitDish, waitOrd = 0, 0
            if tyc then
                plateCount = #getReadyPlates(tyc)
                if CustomersMod then
                    local ok, storage = pcall(function() return CustomersMod:GetStorage(tyc) end)
                    if ok and storage and storage.Groups then
                        for _, grp in pairs(storage.Groups) do
                            for _, c in pairs(grp.Customers or {}) do
                                if c.State == "WaitingForDish" then waitDish = waitDish + 1
                                elseif c.State == "WaitingForOrder" then waitOrd = waitOrd + 1 end
                            end
                        end
                    end
                end
            end

            -- Restaurant counts (tables, chairs, seat target)
            local nTables, nTablesFree, nTablesFull, nChairs = 0, 0, 0, 0
            local seatTargetInfo = "—"
            if tyc then
                local surf = tyc.Items and tyc.Items:FindFirstChild("Surface")
                if surf then
                    for _, f in ipairs(surf:GetChildren()) do
                        if f:IsA("Model") and isTableFurniture(f) then
                            nTables = nTables + 1
                            if f:GetAttribute("InUse") then nTablesFull = nTablesFull + 1
                            else nTablesFree = nTablesFree + 1 end
                        end
                    end
                end
                local furn = tyc.Items and tyc.Items:FindFirstChild("Furniture")
                if furn then
                    for _, f in ipairs(furn:GetChildren()) do
                        if f:IsA("Model") and isChairFurniture(f) then
                            nChairs = nChairs + 1
                        end
                    end
                end
                -- Find smallest unseated group and show what we'd seat them at
                if CustomersMod then
                    local st
                    pcall(function() st = CustomersMod:GetStorage(tyc) end)
                    if st and st.Groups then
                        local smallestUnseatedSize
                        for gId, grp in pairs(st.Groups) do
                            local s = tostring(grp.State)
                            if s == "Entering" or s == "Entered" or s == "Idle"
                                or s == "WaitingToBeSeated" or s == "WaitingForSeat" then
                                local sz = grp.NumCustomers or 0
                                if not smallestUnseatedSize or sz < smallestUnseatedSize then
                                    smallestUnseatedSize = sz
                                end
                            end
                        end
                        if smallestUnseatedSize then
                            seatTargetInfo = "G" .. smallestUnseatedSize .. " need ≥" .. smallestUnseatedSize
                        elseif nTablesFree == 0 then
                            seatTargetInfo = "all tables full"
                        else
                            seatTargetInfo = "no unseated groups"
                        end
                    end
                end
            end

            -- Station summary
            local staffLines = {"Stations:"}
            if tyc then
                local cr = tyc:FindFirstChild("Objects") and tyc.Objects:FindFirstChild("CookingResources")
                if cr then
                    for _, st in ipairs(cr:GetChildren()) do
                        if st.Name:find("^Chef%d") or st.Name:find("^Barista%d") then
                            local fm = st:FindFirstChild("FoodModel")
                            local hasPlate = fm and (#fm:GetChildren() > 0)
                            table.insert(staffLines, "  " .. st.Name .. (hasPlate and " · ready" or " · idle"))
                        end
                    end
                end
            end

            _infoAction.Text  = _currentAction
            _infoTycoon.Text  = tName
            _infoServed.Text  = tostring(S.served)
            _infoDishes.Text  = tostring(S.dishesCleared)
            _infoTips.Text    = tostring(S.tipsCollected)
            _infoOrders.Text  = tostring(S.ordersTaken)
            _infoBills.Text   = tostring(S.billsCollected)
            _infoCooks.Text   = tostring(S.cooksFinished)
            _infoPlates.Text  = tostring(plateCount)
            _infoWaitDish.Text = tostring(waitDish)
            _infoWaitOrd.Text = tostring(waitOrd)
            _infoTables.Text     = tostring(nTables)
            _infoTablesFree.Text = tostring(nTablesFree)
            _infoTablesFull.Text = tostring(nTablesFull)
            _infoChairs.Text     = tostring(nChairs)
            _infoSeatTarget.Text = seatTargetInfo
            _infoRuntime.Text = rtime
            _infoHealth.Text  = hpTxt
            _infoSpeed.Text   = spTxt

            _infoStaff.Text   = table.concat(staffLines, "\n")

            _liveRuntime.Text = rtime
            _liveAction.Text  = _currentAction
            _livePlates.Text  = tostring(plateCount)
            _liveOrders.Text  = tostring(waitOrd)
            _liveServed.Text  = tostring(S.served)
            _liveTips.Text    = tostring(S.tipsCollected)
            _liveDishes.Text  = tostring(S.dishesCleared)

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

switchTab(CFG.ActiveTab or "Farm")

print("[Aurora v5.3d] Restaurant Tycoon 3 loaded")
