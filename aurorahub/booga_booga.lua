--// Aurora v5.1 — Booga Booga Reborn
--// AuroraHub Edition (Wave / Potassium)
--// PlaceId: 11729688377 · Game: Booga Booga [Easter! ðŸ¥š]
--// v5.1: Nilhub-parity pass — adds 20 features using our own Aurora code:
--//   Typing Check, Auto Heal, Auto Eat, Auto Voodoo Shield/Bolt, Auto Equip Armor,
--//   Auto Tool Swap, Better Mountain Climber, Auto Farm Gold, Auto Fish,
--//   Auto Chest Open, Auto Egg/Heart/Gold Hunt, Fly, Noclip, HitBox Expander,
--//   Face/Move Closest, Teleport Portals, Full ESP (6 cats), Expanded Pickup.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local runs = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local marketservice = game:GetService("MarketplaceService")
local rbxservice = game:GetService("RbxAnalyticsService")
local tspmo = TweenService
local Player = Players.LocalPlayer

-- Cleanup prior UI
for _, n in ipairs({"Aurora", "AuroraPill", "Fluent", "Herkle"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- ZOMBIE KILL ----------
if getgenv().__AURORAHUB_BOOGA_CFG then
    for k, v in pairs(getgenv().__AURORAHUB_BOOGA_CFG) do
        if type(v) == "boolean" then getgenv().__AURORAHUB_BOOGA_CFG[k] = false end
    end
end
task.wait(0.15)

getgenv().__AURORAHUB_BOOGA_SESSION = tick()
local _mySession = getgenv().__AURORAHUB_BOOGA_SESSION
local function alive() return getgenv().__AURORAHUB_BOOGA_SESSION == _mySession end

---------- CONFIG ----------
if not getgenv().__AURORAHUB_BOOGA_CFG then
    getgenv().__AURORAHUB_BOOGA_CFG = {
        -- Main — movement
        Walkspeed = false, WalkspeedValue = 16,
        JumpPower = false, JumpPowerValue = 50,
        HipHeight = false, HipHeightValue = 2,
        NoMountainSlip = false,
        BetterClimber = false,
        Fly = false, FlySpeed = 50,
        Noclip = false,

        -- Main — survival
        AutoHeal = false, HealThreshold = 50,
        AutoEat = false, EatThreshold = 60,
        AutoEquipArmor = false,
        TypingCheck = false,

        -- Combat
        KillAura = false, KillAuraRange = 15, KillAuraMaxTargets = "6", KillAuraCooldown = 0.05,
        LegitKillAura = false,
        FaceClosest = false, MoveToClosest = false,
        ResourceAura = false, ResourceAuraRange = 20, ResourceMaxTargets = "1", ResourceCooldown = 0.1,
        CritterAura = false, CritterAuraRange = 20, CritterMaxTargets = "1", CritterCooldown = 0.1,
        AutoHitEverything = false,
        AutoToolSwap = false,

        -- Voodoo
        AutoVoodooShield = false,
        AutoVoodooBolt = false, VoodooBoltRange = 60,

        -- HitBox expander
        HitboxPlayers = false, HitboxPlayersSize = 10,
        HitboxBirds = false, HitboxBirdsSize = 10,

        -- PvP trap
        AutoWallPlayer = false, AutoHutPlayer = false,
        PvPTrapRange = 15,

        -- Pickup
        AutoPickup = false, AutoChestPickup = false, PickupRange = 20,
        PickupItems = { Leaves = true, Log = true },
        AutoDrop = false, DropItem = "Bloodfruit",
        AutoDropCustom = false, DropItemCustom = "Bloodfruit",

        -- Farming
        Fruit = "Bloodfruit",
        AutoPlant = false, PlantRange = 30, PlantDelay = 0.1,
        AutoHarvest = false, HarvestRange = 30,
        TweenPlantBox = false, TweenBush = false, TweenRange = 250,

        -- Extra — orbit (existing)
        ItemOrbit = false, OrbitRange = 20, OrbitRadius = 10, OrbitSpeed = 5, ItemHeight = 3,

        -- Extra — new autos
        AutoFarmGold = false, AutoFishing = false,
        AutoCoinPress = false, AutoCampfire = false, AutoChestOpen = false,
        AutoEggHunt = false, AutoHeartHunt = false, AutoGoldHunt = false,
        AutoRebirth = false,

        -- ESP
        ESPPlayers = false, ESPCritters = false, ESPResources = false, ESPItems = false,
        ESPChests = false, ESPBosses = false, ESPRange = 500,

        -- Persistence + UI
        AutoSave = false, ActiveTab = "Main", PanelOpen = true,
    }
else
    local c = getgenv().__AURORAHUB_BOOGA_CFG
    local defaults = {
        WalkspeedValue=16, JumpPowerValue=50, HipHeightValue=2, FlySpeed=50,
        HealThreshold=50, EatThreshold=60, VoodooBoltRange=60,
        KillAuraRange=5, KillAuraMaxTargets="1", KillAuraCooldown=0.1,
        ResourceAuraRange=20, ResourceMaxTargets="1", ResourceCooldown=0.1,
        CritterAuraRange=20, CritterMaxTargets="1", CritterCooldown=0.1,
        HitboxPlayersSize=10, HitboxBirdsSize=10, PvPTrapRange=15,
        PickupRange=20, DropItem="Bloodfruit", DropItemCustom="Bloodfruit",
        Fruit="Bloodfruit", PlantRange=30, PlantDelay=0.1, HarvestRange=30,
        TweenRange=250, OrbitRange=20, OrbitRadius=10, OrbitSpeed=5, ItemHeight=3,
        ESPRange=500,
        ActiveTab="Main", PanelOpen=true,
    }
    for k, v in pairs(defaults) do if c[k] == nil then c[k] = v end end
    if type(c.PickupItems) ~= "table" then c.PickupItems = { Leaves = true, Log = true } end
    if c.TypingCheck == nil then c.TypingCheck = false end
end
local CFG = getgenv().__AURORAHUB_BOOGA_CFG

---------- CFG SAVE/LOAD ----------
local _cfgFileName = "aurorahub_cfg_booga_booga.json"

local function deepCopySets(src)
    local out = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            local t = {}
            for k2, v2 in pairs(v) do t[k2] = v2 end
            out[k] = t
        else out[k] = v end
    end
    return out
end

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AurorahubCFG_booga_booga"] end
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil then
                if type(CFG[k]) == "table" and type(v) == "table" then
                    CFG[k] = {}
                    for k2, v2 in pairs(v) do CFG[k][k2] = v2 end
                elseif type(CFG[k]) == type(v) then
                    CFG[k] = v
                end
            end
        end
    end
end

local function saveCFG()
    pcall(function() if writefile then writefile(_cfgFileName, HttpService:JSONEncode(deepCopySets(CFG))) end end)
    getgenv()["AurorahubCFG_booga_booga"] = CFG
end

loadSavedCFG()

---------- STATE ----------
local S = { swings = 0, pickups = 0, drops = 0, plants = 0, harvests = 0, placed = 0,
            heals = 0, eats = 0, voodoos = 0, fish = 0, eggs = 0, hearts = 0, golds = 0, chests = 0 }
local _sessionStart = tick()

-- ESP state (separate table to avoid cluttering locals)
local E = { highlights = {}, billboards = {}, origHitbox = {} }

-- Typing guard
local _typing = false
UIS.TextBoxFocused:Connect(function() _typing = true end)
UIS.TextBoxFocusReleased:Connect(function() _typing = false end)
local function typingGuard()
    return CFG.TypingCheck and _typing
end

-- ============================================================
-- ORIGINAL BOOGA LOGIC (preserved verbatim, Options.* → CFG.*)
-- ============================================================

local packets = require(RS:WaitForChild("Modules"):WaitForChild("Packets"))
local plr = Player
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")
local placestructure

-- Fruit → item id map (v5.1 BUG FIX: Coconut was 1 (wood), Carrot was 147 (dock); fixed from ItemIDS module)
local fruittoitemid = {
    Bloodfruit = 94, Bluefruit = 377, Lemon = 99,
    Coconut = 4,   -- was 1 in v5.0 (wrong — 1 is Wood); verified from RS.Modules.ItemIDS
    Jelly = 604, Banana = 606, Orange = 602, Oddberry = 32, Berry = 35, Strangefruit = 302,
    Strawberry = 282, Sunfruit = 128, Pumpkin = 80, ["Prickly Pear"] = 378,
    Apple = 243, Barley = 247, Cloudberry = 101,
    Carrot = 149,  -- was 147 in v5.0 (wrong — 147 is Dock); verified
}

-- Encoding helpers (verbatim from v5.0)
local function decode(str)
    local b1, b2, b3 = string.byte(str, -4, -2)
    return b1 + b2 * 256 + b3 * 65536
end
local function swingencode(ids)
    if typeof(ids) ~= "table" then ids = {ids} end
    local count = #ids
    local out = {string.char(0x00, 0x11, count, 0x00)}
    for i = 1, count do
        local num = ids[i]
        out[#out + 1] = string.char(num % 256, math.floor(num / 256) % 256, math.floor(num / 65536) % 256, 0x00)
    end
    return table.concat(out)
end
local function pickupencode(entityid)
    local b1 = entityid % 256
    local b2 = math.floor(entityid / 256) % 256
    local b3 = math.floor(entityid / 65536) % 256
    return string.char(0x00, 0xD5, b1, b2, b3, 0x00)
end
local function toggledoorencode(entityid)
    local b1 = entityid % 256
    local b2 = math.floor(entityid / 256) % 256
    local b3 = math.floor(entityid / 65536) % 256
    return string.char(0x00, 0x07, b1, b2, b3, 0x00)
end
local function interactstructureencode(entityid, itemid)
    local b1 = entityid % 256
    local b2 = math.floor(entityid / 256) % 256
    local b3 = math.floor(entityid / 65536) % 256
    local i1 = itemid % 256
    local i2 = math.floor(itemid / 256) % 256
    return string.char(0x00, 0xC9, b1, b2, b3, 0x00, i1, i2)
end
local function run(stringg, packett, itemid)
    local id = typeof(stringg) == "string" and decode(stringg) or stringg
    local packet
    if packett == "swing" then packet = swingencode(id)
    elseif packett == "pickup" then packet = pickupencode(id)
    elseif packett == "interactstructure" then packet = interactstructureencode(id, typeof(itemid) == "number" and itemid or nil)
    elseif packett == "toggledoor" then packet = toggledoorencode(id)
    else return end
    pcall(function() RS:WaitForChild("ByteNetReliable"):FireServer(buffer.fromstring(packet)) end)
end

-- v5.2: Multi-channel swing fire (3 paths — one MUST work)
local _EventsSwingTool = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("SwingTool")
local function fireSwing(targets)
    if not targets or #targets == 0 then return end
    -- Normalize to array
    local arr = typeof(targets) == "table" and targets or { targets }
    -- Coerce each to number (attributes sometimes string)
    local nums = {}
    for _, v in ipairs(arr) do
        local n = tonumber(v)
        if n then table.insert(nums, n) end
    end
    if #nums == 0 then return end
    -- Channel 1: custom byte protocol (Herkle source path)
    pcall(function() run(nums, "swing") end)
    -- Channel 2: typed packet — try array form
    if packets.SwingTool and packets.SwingTool.send then
        pcall(function() packets.SwingTool.send(nums) end)
        if #nums == 1 then
            pcall(function() packets.SwingTool.send(nums[1]) end)
        end
    end
    -- Channel 3: named Events remote
    if _EventsSwingTool then
        pcall(function() _EventsSwingTool:FireServer(nums) end)
        if #nums == 1 then
            pcall(function() _EventsSwingTool:FireServer(nums[1]) end)
        end
    end
end

-- v5.2: Auto-equip a weapon/pick if nothing equipped (by scanning inventory)
local _lastAutoEquip = 0
local function autoEquipForAura()
    if tick() - _lastAutoEquip < 1 then return end  -- throttle 1 per sec
    _lastAutoEquip = tick()
    -- Check if tool is equipped (current character has a Tool child)
    local hasTool = false
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") then hasTool = true; break end
        end
    end
    if hasTool then return end
    -- Pick first tool from priority
    local list = getInventoryList(); if not list then return end
    local priority = {"Emerald Blade","Pink Diamond Axe","Crossbow","Battle Axe","God Pick","Pink Diamond Pick",
        "Mace","Iron Bow","Emerald Axe","Emerald Pick","Crystal Pick","Crystal Axe","Adurite Pick","Adurite Axe",
        "Steel Axe","Steel Pick","Iron Axe","Iron Pick","Stone Axe","Stone Pick","Club","Sling","Wood Pick","Wood Axe"}
    for _, tname in ipairs(priority) do
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("ImageLabel") and child.Name == tname then
                if packets.UseBagItem and packets.UseBagItem.send then
                    pcall(function() packets.UseBagItem.send(child.LayoutOrder) end)
                end
                return
            end
        end
    end
end

local function getInventoryList()
    local p = plr:FindFirstChild("PlayerGui")
    local mg = p and p:FindFirstChild("MainGui")
    local rp = mg and mg:FindFirstChild("RightPanel")
    local inv = rp and rp:FindFirstChild("Inventory")
    return inv and inv:FindFirstChild("List")
end

local function drop(itemname)
    local list = getInventoryList(); if not list then return end
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == itemname then
            if packets and packets.DropBagItem and packets.DropBagItem.send then
                pcall(function() packets.DropBagItem.send(child.LayoutOrder) end)
                S.drops = S.drops + 1
            end
        end
    end
end

-- Find inventory item by name (returns LayoutOrder or nil)
local function findInvItem(name)
    local list = getInventoryList(); if not list then return nil end
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == name then return child.LayoutOrder, child end
    end
    return nil
end

---------- CHARACTER HANDLING (v5.1 fix: always-on loop reads CFG every frame) ----------
plr.CharacterAdded:Connect(function(newChar)
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
end)
local function updmsa() end  -- kept as no-op for existing callback signatures
runs.RenderStepped:Connect(function()
    if not alive() or not hum then return end
    hum.WalkSpeed = CFG.Walkspeed and (tonumber(CFG.WalkspeedValue) or 16) or 16
    hum.JumpPower = CFG.JumpPower and (tonumber(CFG.JumpPowerValue) or 50) or 50
    hum.HipHeight = CFG.HipHeight and (tonumber(CFG.HipHeightValue) or 2) or 2
    hum.MaxSlopeAngle = (CFG.NoMountainSlip or CFG.BetterClimber) and 89 or 46
end)

---------- KILL AURA ----------
task.spawn(function()
    while alive() do
        if (not CFG.KillAura) or typingGuard() then task.wait(0.1); continue end
        local range = tonumber(CFG.KillAuraRange) or 5
        local targetCount = tonumber(CFG.KillAuraMaxTargets) or 1
        local cooldown = tonumber(CFG.KillAuraCooldown) or 0.1
        if CFG.LegitKillAura then cooldown = cooldown + math.random() * 0.3 end
        local targets = {}
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= plr then
                local pf = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(player.Name)
                if pf then
                    local rp = pf:FindFirstChild("HumanoidRootPart")
                    local eid = pf:GetAttribute("EntityID")
                    if rp and eid and root then
                        local dist = (rp.Position - root.Position).Magnitude
                        if dist <= range then table.insert(targets, { eid = eid, dist = dist }) end
                    end
                end
            end
        end
        if #targets > 0 then
            table.sort(targets, function(a, b) return a.dist < b.dist end)
            local selected = {}
            for i = 1, math.min(targetCount, #targets) do table.insert(selected, targets[i].eid) end
            autoEquipForAura()
            fireSwing(selected); S.swings = S.swings + 1
        end
        task.wait(cooldown)
    end
end)

---------- RESOURCE AURA ----------
task.spawn(function()
    while alive() do
        if (not CFG.ResourceAura) or typingGuard() then task.wait(0.1); continue end
        local range = tonumber(CFG.ResourceAuraRange) or 20
        local targetCount = tonumber(CFG.ResourceMaxTargets) or 1
        local cooldown = tonumber(CFG.ResourceCooldown) or 0.1
        local targets = {}
        local allresources = {}
        local resFolder = workspace:FindFirstChild("Resources")
        if resFolder then for _, r in pairs(resFolder:GetChildren()) do table.insert(allresources, r) end end
        for _, r in pairs(workspace:GetChildren()) do
            if r:IsA("Model") and (r.Name == "Gold Node" or r.Name == "Iron Node") then table.insert(allresources, r) end
        end
        for _, res in pairs(allresources) do
            if res:IsA("Model") and res:GetAttribute("EntityID") and root then
                local eid = res:GetAttribute("EntityID")
                local ppart = res.PrimaryPart or res:FindFirstChildWhichIsA("BasePart")
                if ppart then
                    local dist = (ppart.Position - root.Position).Magnitude
                    if dist <= range then table.insert(targets, { eid = eid, dist = dist }) end
                end
            end
        end
        if #targets > 0 then
            table.sort(targets, function(a, b) return a.dist < b.dist end)
            local selected = {}
            for i = 1, math.min(targetCount, #targets) do table.insert(selected, targets[i].eid) end
            autoEquipForAura()
            fireSwing(selected); S.swings = S.swings + 1
        end
        task.wait(cooldown)
    end
end)

---------- CRITTER AURA ----------
task.spawn(function()
    while alive() do
        if (not CFG.CritterAura) or typingGuard() then task.wait(0.1); continue end
        local range = tonumber(CFG.CritterAuraRange) or 20
        local targetCount = tonumber(CFG.CritterMaxTargets) or 1
        local cooldown = tonumber(CFG.CritterCooldown) or 0.1
        local targets = {}
        local crittersFolder = workspace:FindFirstChild("Critters")
        if crittersFolder then
            for _, c in pairs(crittersFolder:GetChildren()) do
                if c:IsA("Model") and c:GetAttribute("EntityID") and root then
                    local eid = c:GetAttribute("EntityID")
                    local ppart = c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")
                    if ppart then
                        local dist = (ppart.Position - root.Position).Magnitude
                        if dist <= range then table.insert(targets, { eid = eid, dist = dist }) end
                    end
                end
            end
        end
        if #targets > 0 then
            table.sort(targets, function(a, b) return a.dist < b.dist end)
            local selected = {}
            for i = 1, math.min(targetCount, #targets) do table.insert(selected, targets[i].eid) end
            autoEquipForAura()
            fireSwing(selected); S.swings = S.swings + 1
        end
        task.wait(cooldown)
    end
end)

---------- AUTO HIT EVERYTHING (combined) ----------
task.spawn(function()
    while alive() do
        if (not CFG.AutoHitEverything) or typingGuard() then task.wait(0.1); continue end
        if not root then task.wait(0.1); continue end
        local range = tonumber(CFG.ResourceAuraRange) or 20
        local targets = {}
        local folders = {workspace:FindFirstChild("Resources"), workspace:FindFirstChild("Critters")}
        for _, folder in ipairs(folders) do
            if folder then
                for _, r in pairs(folder:GetChildren()) do
                    if r:IsA("Model") and r:GetAttribute("EntityID") then
                        local pp = r.PrimaryPart or r:FindFirstChildWhichIsA("BasePart")
                        if pp and (pp.Position - root.Position).Magnitude <= range then
                            table.insert(targets, r:GetAttribute("EntityID"))
                        end
                    end
                end
            end
        end
        for _, r in pairs(workspace:GetChildren()) do
            if r:IsA("Model") and (r.Name == "Gold Node" or r.Name == "Iron Node") and r:GetAttribute("EntityID") then
                local pp = r.PrimaryPart or r:FindFirstChildWhichIsA("BasePart")
                if pp and (pp.Position - root.Position).Magnitude <= range then
                    table.insert(targets, r:GetAttribute("EntityID"))
                end
            end
        end
        if #targets > 0 then
            autoEquipForAura()
            local batch = {}
            for i = 1, math.min(#targets, 6) do table.insert(batch, targets[i]) end
            fireSwing(batch); S.swings = S.swings + 1
        end
        task.wait(0.15)
    end
end)

---------- AUTO PICKUP ----------
task.spawn(function()
    while alive() do
        local range = tonumber(CFG.PickupRange) or 35
        local selectedItems = {}
        for k, v in pairs(CFG.PickupItems) do if v then table.insert(selectedItems, k) end end

        if CFG.AutoPickup and root and (not typingGuard()) then
            local items = workspace:FindFirstChild("Items")
            if items then
                for _, item in ipairs(items:GetChildren()) do
                    if item:IsA("BasePart") or item:IsA("MeshPart") then
                        local name = item.Name
                        local eid = item:GetAttribute("EntityID")
                        if eid and table.find(selectedItems, name) then
                            local dist = (item.Position - root.Position).Magnitude
                            if dist <= range then
                                run(eid, "pickup"); S.pickups = S.pickups + 1
                            end
                        end
                    end
                end
            end
        end

        if CFG.AutoChestPickup and root and (not typingGuard()) then
            local deps = workspace:FindFirstChild("Deployables")
            if deps then
                for _, chest in ipairs(deps:GetChildren()) do
                    if chest:IsA("Model") and chest:FindFirstChild("Contents") then
                        for _, item in ipairs(chest.Contents:GetChildren()) do
                            if item:IsA("BasePart") or item:IsA("MeshPart") then
                                local name = item.Name
                                local eid = item:GetAttribute("EntityID")
                                if eid and table.find(selectedItems, name) and chest.PrimaryPart then
                                    local dist = (chest.PrimaryPart.Position - root.Position).Magnitude
                                    if dist <= range then
                                        run(eid, "pickup"); S.pickups = S.pickups + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.01)
    end
end)

---------- AUTO DROP ----------
local debounceDrop, cd = 0, 0
runs.Heartbeat:Connect(function()
    if not alive() then return end
    if CFG.AutoDrop and tick() - debounceDrop >= cd then
        drop(CFG.DropItem); debounceDrop = tick()
    end
end)
runs.Heartbeat:Connect(function()
    if not alive() then return end
    if CFG.AutoDropCustom and tick() - debounceDrop >= cd then
        drop(CFG.DropItemCustom); debounceDrop = tick()
    end
end)

---------- FARMING HELPERS ----------
local plantedboxes = {}

local function getpbs(range)
    local list = {}
    local deps = workspace:FindFirstChild("Deployables")
    if not deps or not root then return list end
    for _, deployable in ipairs(deps:GetChildren()) do
        if deployable:IsA("Model") and deployable.Name == "Plant Box" then
            local eid = deployable:GetAttribute("EntityID")
            local ppart = deployable.PrimaryPart or deployable:FindFirstChildWhichIsA("BasePart")
            if eid and ppart then
                local dist = (ppart.Position - root.Position).Magnitude
                if dist <= range then
                    table.insert(list, { entityid = eid, deployable = deployable, dist = dist })
                end
            end
        end
    end
    return list
end

local function getbushes(range, fruitname)
    local list = {}
    if not fruitname or not root then return list end
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model.Name:find(fruitname) then
            local ppart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if ppart then
                local dist = (ppart.Position - root.Position).Magnitude
                if dist <= range then
                    local eid = model:GetAttribute("EntityID")
                    if eid then table.insert(list, { entityid = eid, model = model, dist = dist }) end
                end
            end
        end
    end
    return list
end

local tweening = nil
local function tween(target)
    if not root then return end
    if tweening then pcall(function() tweening:Cancel() end) end
    local distance = (root.Position - target.Position).Magnitude
    local duration = math.max(0.2, distance / 100)  -- v5.1: faster (was /21)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local t = tspmo:Create(root, tweenInfo, { CFrame = target })
    t:Play()
    tweening = t
    return duration
end

local function tweenplantbox(range)
    while CFG.TweenPlantBox and alive() do
        local boxes = getpbs(range)
        table.sort(boxes, function(a, b) return a.dist < b.dist end)
        for _, box in ipairs(boxes) do
            if box.deployable.PrimaryPart and not box.deployable:FindFirstChild("Seed") then
                tween(box.deployable.PrimaryPart.CFrame + Vector3.new(0, 5, 0))
                break
            end
        end
        task.wait(0.1)
    end
end

local function tweenpbs(range, fruitname)
    while CFG.TweenBush and alive() do
        local bushes = getbushes(range, fruitname)
        table.sort(bushes, function(a, b) return a.dist < b.dist end)
        if #bushes > 0 then
            for _, bush in ipairs(bushes) do
                if bush.model.PrimaryPart then
                    tween(bush.model.PrimaryPart.CFrame + Vector3.new(0, 5, 0))
                    break
                end
            end
        else
            local boxes = getpbs(range)
            table.sort(boxes, function(a, b) return a.dist < b.dist end)
            for _, box in ipairs(boxes) do
                if box.deployable.PrimaryPart and not box.deployable:FindFirstChild("Seed") then
                    tween(box.deployable.PrimaryPart.CFrame + Vector3.new(0, 5, 0))
                    break
                end
            end
        end
        task.wait(0.1)
    end
end

---------- AUTO PLANT ----------
task.spawn(function()
    while alive() do
        if (not CFG.AutoPlant) or typingGuard() then task.wait(0.1); continue end
        local range = tonumber(CFG.PlantRange) or 30
        local pdelay = tonumber(CFG.PlantDelay) or 0.1
        local fruit = CFG.Fruit or "Bloodfruit"
        local itemID = fruittoitemid[fruit] or 94
        local boxes = getpbs(range)
        table.sort(boxes, function(a, b) return a.dist < b.dist end)
        for _, box in ipairs(boxes) do
            if not box.deployable:FindFirstChild("Seed") then
                run(box.entityid, "interactstructure", itemID); S.plants = S.plants + 1
            else plantedboxes[box.entityid] = true end
        end
        task.wait(pdelay)
    end
end)

---------- AUTO HARVEST ----------
task.spawn(function()
    while alive() do
        if (not CFG.AutoHarvest) or typingGuard() then task.wait(0.1); continue end
        local range = tonumber(CFG.HarvestRange) or 30
        local fruit = CFG.Fruit or "Bloodfruit"
        local bushes = getbushes(range, fruit)
        table.sort(bushes, function(a, b) return a.dist < b.dist end)
        for _, bush in ipairs(bushes) do
            run(bush.entityid, "pickup"); S.harvests = S.harvests + 1
        end
        task.wait(0.1)
    end
end)

---------- TWEEN LOOPS ----------
task.spawn(function()
    while alive() do
        if not CFG.TweenPlantBox then task.wait(0.1); continue end
        tweenplantbox(tonumber(CFG.TweenRange) or 250)
    end
end)
task.spawn(function()
    while alive() do
        if not CFG.TweenBush then task.wait(0.1); continue end
        tweenpbs(tonumber(CFG.TweenRange) or 20, CFG.Fruit or "Bloodfruit")
    end
end)

---------- PLACE STRUCTURE (grid) ----------
placestructure = function(gridsize)
    if not plr or not plr.Character then return end
    local torso = plr.Character:FindFirstChild("HumanoidRootPart")
    if not torso then return end
    local startpos = torso.Position - Vector3.new(0, 3, 0)
    local spacing = 6.04
    for x = 0, gridsize - 1 do
        for z = 0, gridsize - 1 do
            task.wait(0.05)  -- v5.1 fix: was 0.3s (77s for 16x16) → 0.05s (~13s)
            if not alive() then return end
            local position = startpos + Vector3.new(x * spacing, 0, z * spacing)
            if packets.PlaceStructure and packets.PlaceStructure.send then
                pcall(function()
                    packets.PlaceStructure.send{
                        buildingName = "Plant Box",
                        yrot = 45, vec = position, isMobile = false,
                    }
                end)
                S.placed = S.placed + 1
            end
        end
    end
end

---------- ITEM ORBIT (existing) ----------
local attacheditems, itemangles, lastpositions = {}, {}, {}
local itemsfolder = workspace:WaitForChild("Items")
local _prevOrbit = false

task.spawn(function()
    while alive() do
        if CFG.ItemOrbit ~= _prevOrbit then
            _prevOrbit = CFG.ItemOrbit
            if not CFG.ItemOrbit then
                for _, bp in pairs(attacheditems) do pcall(function() bp:Destroy() end) end
                table.clear(attacheditems); table.clear(itemangles); table.clear(lastpositions)
            else
                task.spawn(function()
                    while CFG.ItemOrbit and alive() do
                        for item, bp in pairs(attacheditems) do
                            if item then
                                local currentpos = item.Position
                                local lastpos = lastpositions[item]
                                if lastpos and (currentpos - lastpos).Magnitude < 0.1 then
                                    if packets.ForceInteract and packets.ForceInteract.send then
                                        pcall(function() packets.ForceInteract.send(item:GetAttribute("EntityID")) end)
                                    end
                                end
                                lastpositions[item] = currentpos
                            end
                        end
                        task.wait(0.1)
                    end
                end)
            end
        end
        task.wait(0.1)
    end
end)

runs.RenderStepped:Connect(function()
    if not alive() or not CFG.ItemOrbit or not root then return end
    local t = tick() * (CFG.OrbitSpeed or 5)
    for item, bp in pairs(attacheditems) do
        if item then
            local angle = (itemangles[item] or 0) + t
            bp.Position = root.Position + Vector3.new(math.cos(angle) * (CFG.OrbitRadius or 10), CFG.ItemHeight or 3, math.sin(angle) * (CFG.OrbitRadius or 10))
        end
    end
end)

task.spawn(function()
    while alive() do
        if CFG.ItemOrbit and root then
            local children = itemsfolder:GetChildren()
            local anglestep = (math.pi * 2) / math.max(#children, 1)
            local idx = 0
            for _, item in pairs(children) do
                local primary = item:IsA("BasePart") and item or (item:IsA("Model") and item.PrimaryPart)
                if primary and (primary.Position - root.Position).Magnitude <= (CFG.OrbitRange or 20) then
                    if not attacheditems[primary] then
                        local bp = Instance.new("BodyPosition")
                        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bp.D = 1500; bp.P = 25000; bp.Parent = primary
                        attacheditems[primary] = bp
                        itemangles[primary] = idx * anglestep
                        lastpositions[primary] = primary.Position
                        idx = idx + 1
                    end
                end
            end
        end
        task.wait()
    end
end)

-- ============================================================
-- v5.1 NEW FEATURES
-- ============================================================

---------- HELPERS ----------
local function nearestEnemy()
    if not root then return nil end
    local best, bestDist
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= plr then
            local pf = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(p.Name)
            local rp = pf and pf:FindFirstChild("HumanoidRootPart")
            if rp then
                local d = (rp.Position - root.Position).Magnitude
                if not bestDist or d < bestDist then best = pf; bestDist = d end
            end
        end
    end
    return best, bestDist
end

local function fireVoodoo(spellName)
    if packets.VoodooSpell and packets.VoodooSpell.send then
        pcall(function() packets.VoodooSpell.send(spellName) end)
        S.voodoos = S.voodoos + 1
    end
end

-- Food priority (skip anything with negative health)
local FOOD_PRIORITY = {
    "Cooked Squid","Cooked Eel","Cooked Baracuda","Cooked Fish","Fried Egg","Cooked Morsel",
    "Pumpkin","Bread","Jelly Sandwich","Cooked Meat","Peeper Popsicle","Coconut","Mango",
    "Apple","Bluefruit","Bloodfruit","Sunfruit","Fried Cactus","Berry","Oddberry","Orange",
    "Strangefruit","Strawberry","Banana","Cloudberry","Corn","Cactus Bit","Blossom","Jelly",
}
-- Armor priority per locus
local ARMOR_BY_LOCUS = {
    head  = {"God Halo","Pink Diamond Hood","Emerald Helmet","Void Shroud","Magnetite Mask","Crystal Crown","Adurite Helmet","Steel Helmet","Iron Helmet"},
    torso = {"God Chestplate","Pink Diamond Chestplate","Emerald Chestplate","Void Chestplate","Magnetite Chestplate","Crystal Chestplate","Adurite Chestplate","Steel Chestplate","Iron Chestplate","Hide Shirt","Leaf Shirt"},
    legs  = {"God Legs","Pink Diamond Greaves","Emerald Greaves","Void Greaves","Magnetite Greaves","Crystal Greaves","Adurite Greaves","Steel Greaves","Iron Greaves","Hide Pants","Leaf Pants"},
}
-- Best tool/weapon by task
local TOOL_PRIORITY = {
    mob = {"Emerald Blade","Crossbow","Battle Axe","God Pick","Pink Diamond Axe","Mace","Iron Bow","Sling","Club"},
    stone = {"God Pick","Pink Diamond Pick","Emerald Pick","Magnetite Pick","Crystal Pick","Adurite Pick","Steel Pick","Iron Pick","Stone Pick","Wood Pick"},
    wood = {"Pink Diamond Axe","Emerald Axe","Magnetite Axe","Crystal Axe","Adurite Axe","Steel Axe","Iron Axe","Stone Axe","Wood Axe"},
    rod = {"Fishing Rod"},
}

---------- AUTO HEAL (v5.1 fix: 1.0s → 0.1s interval, spam-fire while low HP) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoHeal and hum and hum.MaxHealth > 0 then
            local pct = (hum.Health / hum.MaxHealth) * 100
            if pct <= (tonumber(CFG.HealThreshold) or 50) then
                local ord = findInvItem("Healing") or findInvItem("Greater Healing") or findInvItem("Lesser Healing")
                if ord and packets.UseBagItem and packets.UseBagItem.send then
                    pcall(function() packets.UseBagItem.send(ord) end); S.heals = S.heals + 1
                else
                    fireVoodoo("Energy Shield")
                end
            end
        end
        task.wait(0.1)
    end
end)

---------- AUTO EAT (v5.2: Bloodfruit always, 0.01s interval) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoEat then
            local list = getInventoryList()
            if list then
                local ord
                for _, child in ipairs(list:GetChildren()) do
                    if child:IsA("ImageLabel") and child.Name == "Bloodfruit" then
                        ord = child.LayoutOrder; break
                    end
                end
                if ord and packets.UseBagItem and packets.UseBagItem.send then
                    pcall(function() packets.UseBagItem.send(ord) end); S.eats = S.eats + 1
                end
            end
        end
        task.wait(0.01)
    end
end)

---------- AUTO VOODOO SHIELD (renew every 28s for near-godmode) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoVoodooShield then fireVoodoo("Energy Shield") end
        task.wait(28)
    end
end)

---------- AUTO VOODOO BOLT (spam at nearest) ----------
task.spawn(function()
    while alive() do
        if CFG.AutoVoodooBolt and (not typingGuard()) then
            local e, d = nearestEnemy()
            if e and d and d <= (tonumber(CFG.VoodooBoltRange) or 60) then
                fireVoodoo("Energy Bolt")
            end
        end
        task.wait(1.2)
    end
end)

---------- AUTO EQUIP ARMOR ----------
task.spawn(function()
    while alive() do
        if CFG.AutoEquipArmor then
            local list = getInventoryList()
            if list then
                for locus, priority in pairs(ARMOR_BY_LOCUS) do
                    for _, armorName in ipairs(priority) do
                        local ord = nil
                        for _, child in ipairs(list:GetChildren()) do
                            if child:IsA("ImageLabel") and child.Name == armorName then ord = child.LayoutOrder; break end
                        end
                        if ord and packets.UseBagItem and packets.UseBagItem.send then
                            pcall(function() packets.UseBagItem.send(ord) end)
                            break  -- equipped this locus, move to next
                        end
                    end
                end
            end
        end
        task.wait(30)  -- re-check every 30s
    end
end)

---------- AUTO TOOL SWAP ----------
local _lastToolSwap = 0
task.spawn(function()
    while alive() do
        if CFG.AutoToolSwap and tick() - _lastToolSwap >= 3 then
            local priority
            if CFG.KillAura or CFG.CritterAura or CFG.AutoHitEverything then priority = TOOL_PRIORITY.mob
            elseif CFG.ResourceAura then priority = TOOL_PRIORITY.stone
            elseif CFG.AutoHarvest or CFG.AutoPlant then priority = nil  -- no tool needed
            elseif CFG.AutoFishing then priority = TOOL_PRIORITY.rod
            end
            if priority then
                local list = getInventoryList()
                if list then
                    for _, tname in ipairs(priority) do
                        for _, child in ipairs(list:GetChildren()) do
                            if child:IsA("ImageLabel") and child.Name == tname then
                                if packets.UseBagItem and packets.UseBagItem.send then
                                    pcall(function() packets.UseBagItem.send(child.LayoutOrder) end)
                                end
                                _lastToolSwap = tick(); break
                            end
                        end
                    end
                end
            end
        end
        task.wait(2)
    end
end)

---------- AUTO FARM GOLD (4-node AFK loop, research-derived) ----------
local GOLD_NODES = {
    Vector3.new(700, 9, 969), Vector3.new(613, -9, -388),
    Vector3.new(474, 10, 156), Vector3.new(296, -3, 1148),
}
task.spawn(function()
    local idx = 1
    while alive() do
        if CFG.AutoFarmGold and root then
            local pos = GOLD_NODES[idx]
            local dur = tween(CFrame.new(pos + Vector3.new(0, 3, 0)))
            task.wait(dur + 0.3)
            -- Swing at node — find Gold Node nearest to pos
            for _, r in ipairs(workspace.Resources:GetChildren()) do
                if r.Name == "Gold Node" then
                    local pp = r.PrimaryPart or r:FindFirstChildWhichIsA("BasePart")
                    if pp and (pp.Position - pos).Magnitude < 40 then
                        for _ = 1, 12 do
                            if not CFG.AutoFarmGold or not alive() then break end
                            autoEquipForAura()
                            fireSwing({ r:GetAttribute("EntityID") }); S.swings = S.swings + 1
                            task.wait(0.3)
                        end
                        break
                    end
                end
            end
            idx = (idx % #GOLD_NODES) + 1
        end
        task.wait(0.5)
    end
end)

---------- AUTO FISH ----------
task.spawn(function()
    while alive() do
        if CFG.AutoFishing and root and (not typingGuard()) then
            -- Cast bobber at water in front
            local castPos = root.Position + root.CFrame.LookVector * 20 - Vector3.new(0, 5, 0)
            if packets.CreateBobber and packets.CreateBobber.send then
                pcall(function() packets.CreateBobber.send(castPos) end)
            end
            task.wait(3.5)
            if packets.RodSwing and packets.RodSwing.send then
                pcall(function() packets.RodSwing.send() end); S.fish = S.fish + 1
            end
        end
        task.wait(2)
    end
end)

---------- AUTO CHEST OPEN ----------
task.spawn(function()
    while alive() do
        if CFG.AutoChestOpen and root then
            for _, c in ipairs(workspace:FindFirstChild("dropChests") and workspace.dropChests:GetChildren() or {}) do
                local eid = c:GetAttribute("EntityID")
                local pp = c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")
                if eid and pp and (pp.Position - root.Position).Magnitude <= 100 then
                    if packets.ChestDrop and packets.ChestDrop.send then
                        pcall(function() packets.ChestDrop.send(eid) end); S.chests = S.chests + 1
                    end
                end
            end
        end
        task.wait(2)
    end
end)

---------- AUTO EGG/HEART/GOLD HUNT ----------
local function fireHuntPickup(huntName, entityID)
    if huntName == "Egg" and packets.EasterEggPickupRequest and packets.EasterEggPickupRequest.send then
        pcall(function() packets.EasterEggPickupRequest.send(entityID) end)
    else
        -- Generic pickup fallback
        pcall(function() run(entityID, "pickup") end)
    end
end

task.spawn(function()
    while alive() do
        local H = RS:FindFirstChild("Hunts")
        if H and root then
            if CFG.AutoEggHunt then
                local f = H:FindFirstChild("Egg")
                if f then
                    for _, e in ipairs(f:GetChildren()) do
                        local eid = e:GetAttribute("EntityID")
                        if eid then fireHuntPickup("Egg", eid); S.eggs = S.eggs + 1 end
                    end
                end
            end
            if CFG.AutoHeartHunt then
                local f = H:FindFirstChild("Heart")
                if f then
                    for _, e in ipairs(f:GetChildren()) do
                        local eid = e:GetAttribute("EntityID")
                        if eid then fireHuntPickup("Heart", eid); S.hearts = S.hearts + 1 end
                    end
                end
            end
            if CFG.AutoGoldHunt then
                local f = H:FindFirstChild("Gold")
                if f then
                    for _, e in ipairs(f:GetChildren()) do
                        local eid = e:GetAttribute("EntityID")
                        if eid then fireHuntPickup("Gold", eid); S.golds = S.golds + 1 end
                    end
                end
            end
        end
        task.wait(4)
    end
end)

---------- AUTO REBIRTH ----------
task.spawn(function()
    while alive() do
        if CFG.AutoRebirth and packets.Rebirth and packets.Rebirth.send then
            pcall(function() packets.Rebirth.send() end)
        end
        task.wait(60)
    end
end)

---------- FLY ----------
local _flyBV, _flyBG
task.spawn(function()
    while alive() do
        if CFG.Fly and root then
            if not _flyBV or not _flyBV.Parent then
                _flyBV = Instance.new("BodyVelocity")
                _flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                _flyBV.Velocity = Vector3.new()
                _flyBV.Parent = root
                _flyBG = Instance.new("BodyGyro")
                _flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                _flyBG.P = 10000; _flyBG.D = 500
                _flyBG.CFrame = workspace.CurrentCamera.CFrame
                _flyBG.Parent = root
            end
            local cam = workspace.CurrentCamera
            local move = Vector3.new()
            if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
            _flyBV.Velocity = move.Unit.Magnitude == math.huge and Vector3.new() or (move * (tonumber(CFG.FlySpeed) or 50))
            _flyBG.CFrame = cam.CFrame
        else
            if _flyBV then pcall(function() _flyBV:Destroy() end); _flyBV = nil end
            if _flyBG then pcall(function() _flyBG:Destroy() end); _flyBG = nil end
        end
        task.wait(0.05)
    end
end)

---------- NOCLIP ----------
runs.Stepped:Connect(function()
    if alive() and CFG.Noclip and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end
end)

---------- HITBOX EXPANDER (players + birds) ----------
local function applyHitbox(inst, size)
    if not E.origHitbox[inst] then E.origHitbox[inst] = { size = inst.Size, trans = inst.Transparency } end
    pcall(function() inst.Size = Vector3.new(size, size, size); inst.Transparency = 0.8 end)
end
local function restoreHitbox(inst)
    if E.origHitbox[inst] then
        pcall(function() inst.Size = E.origHitbox[inst].size; inst.Transparency = E.origHitbox[inst].trans end)
        E.origHitbox[inst] = nil
    end
end

task.spawn(function()
    while alive() do
        if CFG.HitboxPlayers then
            local pf = workspace:FindFirstChild("Players")
            if pf then
                for _, p in ipairs(pf:GetChildren()) do
                    if p.Name ~= plr.Name then
                        local rp = p:FindFirstChild("HumanoidRootPart")
                        if rp then applyHitbox(rp, CFG.HitboxPlayersSize or 10) end
                    end
                end
            end
        else
            for inst in pairs(E.origHitbox) do
                if inst.Parent and inst.Parent.Name ~= "Bird" then restoreHitbox(inst) end
            end
        end
        if CFG.HitboxBirds then
            local cf = workspace:FindFirstChild("Critters")
            if cf then
                for _, c in ipairs(cf:GetChildren()) do
                    if c.Name == "Bird" then
                        local rp = c:FindFirstChild("HumanoidRootPart")
                        if rp then applyHitbox(rp, CFG.HitboxBirdsSize or 10) end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

---------- FACE / MOVE CLOSEST PLAYER ----------
runs.Heartbeat:Connect(function()
    if not alive() or not root then return end
    if CFG.FaceClosest then
        local e = nearestEnemy()
        if e then
            local rp = e:FindFirstChild("HumanoidRootPart")
            if rp then
                local lookCF = CFrame.new(root.Position, Vector3.new(rp.Position.X, root.Position.Y, rp.Position.Z))
                root.CFrame = lookCF
            end
        end
    end
    if CFG.MoveToClosest and hum then
        local e = nearestEnemy()
        if e then
            local rp = e:FindFirstChild("HumanoidRootPart")
            if rp then hum:MoveTo(rp.Position) end
        end
    end
end)

---------- AUTO WALL / HUT PLAYER (PvP trap) ----------
local _lastTrap = 0
task.spawn(function()
    while alive() do
        if (CFG.AutoWallPlayer or CFG.AutoHutPlayer) and root and tick() - _lastTrap >= 3 then
            local e, d = nearestEnemy()
            if e and d and d <= (tonumber(CFG.PvPTrapRange) or 15) then
                local rp = e:FindFirstChild("HumanoidRootPart")
                if rp and packets.PlaceStructure and packets.PlaceStructure.send then
                    local bname = CFG.AutoHutPlayer and "Hut" or "Wood Wall"
                    -- 4 walls around target
                    local offsets = CFG.AutoHutPlayer and { Vector3.new(0,0,0) } or
                        { Vector3.new(0,0,6), Vector3.new(0,0,-6), Vector3.new(6,0,0), Vector3.new(-6,0,0) }
                    for _, off in ipairs(offsets) do
                        pcall(function()
                            packets.PlaceStructure.send{ buildingName = bname, yrot = 0, vec = rp.Position + off, isMobile = false }
                        end)
                        S.placed = S.placed + 1
                    end
                    _lastTrap = tick()
                end
            end
        end
        task.wait(1)
    end
end)

---------- AUTO COIN PRESS / AUTO CAMPFIRE (structure interact) ----------
local _lastCoinPress, _lastCampfire = 0, 0
task.spawn(function()
    while alive() do
        local deps = workspace:FindFirstChild("Deployables")
        if not deps or not root then task.wait(5); continue end

        if CFG.AutoCoinPress and tick() - _lastCoinPress >= 10 then
            for _, d in ipairs(deps:GetChildren()) do
                if d.Name == "Coin Press" and d:GetAttribute("owner") == tostring(plr.UserId) then
                    local eid = d:GetAttribute("EntityID")
                    if eid then
                        -- Feed gold (item id 258 = Raw Gold, 70 = Coin)
                        run(eid, "interactstructure", 258)
                        _lastCoinPress = tick()
                    end
                end
            end
        end

        if CFG.AutoCampfire and tick() - _lastCampfire >= 10 then
            for _, d in ipairs(deps:GetChildren()) do
                if d.Name == "Campfire" and d:GetAttribute("owner") == tostring(plr.UserId) then
                    local eid = d:GetAttribute("EntityID")
                    if eid then
                        -- Refuel with Wood (id 1)
                        run(eid, "interactstructure", 1)
                        _lastCampfire = tick()
                    end
                end
            end
        end
        task.wait(3)
    end
end)

---------- ESP ----------
local function ensureHighlight(inst, color, key)
    local h = E.highlights[key]
    if not h or not h.Parent then
        h = Instance.new("Highlight")
        h.Adornee = inst; h.FillTransparency = 0.7; h.OutlineTransparency = 0
        h.FillColor = color; h.OutlineColor = color
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        local ok = pcall(function() h.Parent = inst end)
        if not ok then pcall(function() h.Parent = gethui and gethui() or game:GetService("CoreGui") end) end
        E.highlights[key] = h
    else
        h.Adornee = inst; h.FillColor = color; h.OutlineColor = color
    end
end

local function clearESP(prefix)
    local keys = {}
    for k in pairs(E.highlights) do if not prefix or k:sub(1, #prefix) == prefix then table.insert(keys, k) end end
    for _, k in ipairs(keys) do
        pcall(function() E.highlights[k]:Destroy() end)
        E.highlights[k] = nil
    end
end

local BOSS_NAMES = { "Ancient God","Wealthy God","Sleeping God","Furious God","Hateful God","Lonely God","Queen Ant","Shellington","Shelbert","Golden Banto","Giant Shelly","Ancient Tree","Spirit Lock","Sky Rope" }
local BOSS_LOOKUP = {}
for _, n in ipairs(BOSS_NAMES) do BOSS_LOOKUP[n] = true end

task.spawn(function()
    while alive() do
        -- Clear if toggle OFF
        if not CFG.ESPPlayers then clearESP("P_") end
        if not CFG.ESPCritters then clearESP("C_") end
        if not CFG.ESPResources then clearESP("R_") end
        if not CFG.ESPItems then clearESP("I_") end
        if not CFG.ESPChests then clearESP("CH_") end
        if not CFG.ESPBosses then clearESP("B_") end

        -- Build active ESP
        if CFG.ESPPlayers then
            local pf = workspace:FindFirstChild("Players")
            if pf then
                for _, p in ipairs(pf:GetChildren()) do
                    if p.Name ~= plr.Name then ensureHighlight(p, Color3.fromRGB(252,110,142), "P_" .. p.Name) end
                end
            end
        end
        if CFG.ESPCritters then
            local cf = workspace:FindFirstChild("Critters")
            if cf then
                for _, c in ipairs(cf:GetChildren()) do
                    local eid = c:GetAttribute("EntityID")
                    if eid then
                        local col = BOSS_LOOKUP[c.Name] and Color3.fromRGB(255,80,80) or Color3.fromRGB(192,132,252)
                        ensureHighlight(c, col, "C_" .. tostring(eid))
                    end
                end
            end
        end
        if CFG.ESPResources then
            local rf = workspace:FindFirstChild("Resources")
            if rf then
                for _, r in ipairs(rf:GetChildren()) do
                    local eid = r:GetAttribute("EntityID")
                    if eid then
                        local col = (r.Name:find("Emerald") or r.Name:find("Adurite") or r.Name:find("Crystal") or r.Name:find("Meteor") or r.Name:find("Gold")) and Color3.fromRGB(0,200,100) or Color3.fromRGB(160,160,180)
                        ensureHighlight(r, col, "R_" .. tostring(eid))
                    end
                end
            end
        end
        if CFG.ESPItems then
            local itf = workspace:FindFirstChild("Items")
            if itf then
                for _, it in ipairs(itf:GetChildren()) do
                    local eid = it:GetAttribute("EntityID")
                    if eid then ensureHighlight(it, Color3.fromRGB(255,255,0), "I_" .. tostring(eid)) end
                end
            end
        end
        if CFG.ESPChests then
            local df = workspace:FindFirstChild("Deployables")
            if df then
                for _, d in ipairs(df:GetChildren()) do
                    if d.Name:lower():find("chest") then
                        local eid = d:GetAttribute("EntityID")
                        if eid then ensureHighlight(d, Color3.fromRGB(255,165,0), "CH_" .. tostring(eid)) end
                    end
                end
            end
            local dc = workspace:FindFirstChild("dropChests")
            if dc then
                for _, c in ipairs(dc:GetChildren()) do
                    local eid = c:GetAttribute("EntityID")
                    if eid then ensureHighlight(c, Color3.fromRGB(255,215,0), "CH_drop_" .. tostring(eid)) end
                end
            end
        end
        if CFG.ESPBosses then
            local rf = workspace:FindFirstChild("Resources")
            if rf then
                for _, r in ipairs(rf:GetChildren()) do
                    if BOSS_LOOKUP[r.Name] then
                        local eid = r:GetAttribute("EntityID")
                        if eid then ensureHighlight(r, Color3.fromRGB(255,0,128), "B_" .. tostring(eid)) end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

-- ============================================================
-- AURORA V5 UI
-- ============================================================
local U = {}
local C = {
    bg = Color3.fromRGB(8,8,15), bg2 = Color3.fromRGB(12,12,24), bg3 = Color3.fromRGB(19,19,42),
    border = Color3.fromRGB(22,22,42), border2 = Color3.fromRGB(42,42,68),
    text = Color3.fromRGB(245,245,250), text2 = Color3.fromRGB(160,160,180), text3 = Color3.fromRGB(98,98,122),
    pink = Color3.fromRGB(252,110,142), purple = Color3.fromRGB(192,132,252),
    green = Color3.fromRGB(0,200,100), red = Color3.fromRGB(255,80,80), white = Color3.fromRGB(255,255,255),
}
local F_SANS, F_SANS_SEMI, F_SANS_BOLD, F_MONO = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold, Enum.Font.Code

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
    g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,c1), ColorSequenceKeypoint.new(1,c2)})
    g.Rotation = rot or 0; g.Parent = p; return g
end
local function padAll(p, v)
    local pp = Instance.new("UIPadding")
    pp.PaddingTop = UDim.new(0, v); pp.PaddingBottom = UDim.new(0, v)
    pp.PaddingLeft = UDim.new(0, v); pp.PaddingRight = UDim.new(0, v); pp.Parent = p; return pp
end

local TOTAL_W, TOTAL_H = 1080, 620
local SIDEBAR_W, PA_W, PB_W = 168, 350, 350
local LG_W = TOTAL_W - SIDEBAR_W - PA_W - PB_W

local screenGui = create("ScreenGui", { Name = "Aurora", DisplayOrder = 9999, ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true })
local _pOk = false
if typeof(gethui) == "function" then _pOk = pcall(function() screenGui.Parent = gethui() end) end
if not _pOk then _pOk = pcall(function() screenGui.Parent = game:GetService("CoreGui") end) end
if not _pOk then pcall(function() screenGui.Parent = plr:WaitForChild("PlayerGui") end) end

local _vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local _mobile = UIS.TouchEnabled and (_vp.X < 1200)
local _scale = _mobile and math.clamp(_vp.X / 1200, 0.5, 0.85) or 1

local main = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true, Visible = CFG.PanelOpen,
}, screenGui)
corner(main, 14); stroke(main, C.border2, 1, 0)
if _scale ~= 1 then local sc = Instance.new("UIScale"); sc.Scale = _scale; sc.Parent = main end

local watermark = create("TextLabel", {
    Name = "Watermark", Size = UDim2.fromOffset(800, 120),
    Position = UDim2.fromOffset(TOTAL_W / 2, TOTAL_H / 2), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1, Font = F_SANS_BOLD, TextSize = 72, TextColor3 = C.pink,
    TextTransparency = 0.82, TextStrokeTransparency = 1, ZIndex = 1,
}, main)
watermark.RichText = true
watermark.Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>'

local content = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, main)

-- Sidebar
local sidebar = create("Frame", {
    Name = "Sidebar", Size = UDim2.fromOffset(SIDEBAR_W, TOTAL_H),
    BackgroundColor3 = C.bg2, BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
}, content)
create("Frame", { Size = UDim2.fromOffset(1, TOTAL_H), Position = UDim2.fromOffset(SIDEBAR_W - 1, 0),
    BackgroundColor3 = C.border, BorderSizePixel = 0 }, content)

local wordmarkRow = create("Frame", { Name = "Wordmark", Size = UDim2.fromOffset(SIDEBAR_W, 54),
    BackgroundTransparency = 1, Active = true }, sidebar)
create("ImageLabel", { Name = "Logo", Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(14, 15),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181",
    ScaleType = Enum.ScaleType.Fit, ImageColor3 = C.white }, wordmarkRow)
local wordmark = create("TextLabel", {
    Size = UDim2.fromOffset(SIDEBAR_W - 44, 24), Position = UDim2.fromOffset(42, 15),
    BackgroundTransparency = 1, Font = F_SANS_BOLD, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextColor3 = C.text,
}, wordmarkRow)
wordmark.RichText = true
wordmark.Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>'

create("Frame", { Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, 54),
    BackgroundColor3 = C.border, BorderSizePixel = 0 }, sidebar)

local TABS = {
    { name = "Main",    icon = "●" },
    { name = "Combat",  icon = "⚔" },
    { name = "Map",     icon = "◆" },
    { name = "Pickup",  icon = "▣" },
    { name = "Farming", icon = "✿" },
    { name = "Extra",   icon = "+" },
    { name = "ESP",     icon = "◎" },
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

local TAB_Y0, TAB_H, TAB_GAP = 66, 32, 3
local function makeTabRow(tinfo, yPos, dimInactive)
    local row = create("Frame", { Name = "Tab_" .. tinfo.name, Size = UDim2.fromOffset(SIDEBAR_W - 20, TAB_H),
        Position = UDim2.fromOffset(10, yPos), BackgroundColor3 = C.pink, BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = true }, sidebar)
    corner(row, 6)
    local bgGrad = Instance.new("UIGradient")
    bgGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,C.pink), ColorSequenceKeypoint.new(1,C.bg2)})
    bgGrad.Rotation = 0; bgGrad.Parent = row
    local accent = create("Frame", { Size = UDim2.fromOffset(2, TAB_H - 14), Position = UDim2.fromOffset(0, 7),
        BackgroundColor3 = C.pink, BorderSizePixel = 0, Visible = false }, row)
    corner(accent, 1)
    local icon = create("TextLabel", { Size = UDim2.fromOffset(18, TAB_H), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = tinfo.icon, Font = F_SANS_BOLD, TextSize = 12,
        TextColor3 = C.text3, TextXAlignment = Enum.TextXAlignment.Center }, row)
    local label = create("TextLabel", { Size = UDim2.fromOffset(SIDEBAR_W - 64, TAB_H), Position = UDim2.fromOffset(36, 0),
        BackgroundTransparency = 1, Text = tinfo.name, Font = F_SANS, TextSize = 12, TextColor3 = C.text2,
        TextXAlignment = Enum.TextXAlignment.Left }, row)
    tabMap[tinfo.name] = { bg = row, accent = accent, icon = icon, label = label, dimInactive = dimInactive or false }
    return row
end

local switchTab = function(_) end
local _openPopup = nil
local _skipNextOutside = false
local closeOpenPopup = function() end

for idx, tinfo in ipairs(TABS) do
    local y = TAB_Y0 + (idx - 1) * (TAB_H + TAB_GAP)
    local row = makeTabRow(tinfo, y, false)
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            switchTab(tinfo.name)
        end
    end)
end

local SET_Y = TOTAL_H - 36 - 10
create("Frame", { Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, SET_Y - 6),
    BackgroundColor3 = C.border, BorderSizePixel = 0 }, sidebar)
local setRow = makeTabRow({ name = "Settings", icon = "⚙" }, SET_Y, true)
setRow.Size = UDim2.fromOffset(SIDEBAR_W - 20, 36)
setRow.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        switchTab("Settings")
    end
end)

-- Panel factory
local panels = {}
local liveScroll

local function makePanel(tabName, which, xPos, width, accent, title)
    local p = create("Frame", {
        Name = tabName .. "_" .. which, Size = UDim2.fromOffset(width, TOTAL_H),
        Position = UDim2.fromOffset(xPos, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ClipsDescendants = true, Visible = (tabName == CFG.ActiveTab),
    }, content)
    if xPos > SIDEBAR_W then
        create("Frame", { Size = UDim2.fromOffset(1, TOTAL_H), BackgroundColor3 = C.border, BorderSizePixel = 0 }, p)
    end
    create("TextLabel", { Size = UDim2.fromOffset(width - 32, 36), Position = UDim2.fromOffset(16, 14),
        BackgroundTransparency = 1, Text = title, Font = F_MONO, TextSize = 10, TextColor3 = accent,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }, p)
    create("Frame", { Size = UDim2.fromOffset(width, 1), Position = UDim2.fromOffset(0, 48),
        BackgroundColor3 = C.border, BorderSizePixel = 0 }, p)
    local scroll = create("ScrollingFrame", { Size = UDim2.fromOffset(width, TOTAL_H - 50),
        Position = UDim2.fromOffset(0, 50), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = accent,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, p)
    padAll(scroll, 14)
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 2); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = scroll
    panels[tabName] = panels[tabName] or {}
    panels[tabName][which] = { frame = p, scroll = scroll }
    return scroll
end

local TAB_NAMES = { "Main", "Combat", "Map", "Pickup", "Farming", "Extra", "ESP", "Settings" }
local TAB_ACCENT = {
    Main=C.pink, Combat=C.purple, Map=C.pink, Pickup=C.purple,
    Farming=C.pink, Extra=C.purple, ESP=C.green, Settings=C.pink,
}
local PANEL_TITLES = {
    Main     = { alpha = "CHARACTER",  beta = "SURVIVAL"     },
    Combat   = { alpha = "AURAS",      beta = "VOODOO + PVP" },
    Map      = { alpha = "RESOURCES",  beta = "WAYPOINTS"    },
    Pickup   = { alpha = "AUTO PICKUP",beta = "AUTO DROP"    },
    Farming  = { alpha = "FARMING",    beta = "TWEEN + BUILD" },
    Extra    = { alpha = "AUTOS",      beta = "ORBIT + FLY"  },
    ESP      = { alpha = "CATEGORIES", beta = "LEGEND"       },
    Settings = { alpha = "CONFIG",     beta = "ABOUT"        },
}

local scrolls = {}
for _, tn in ipairs(TAB_NAMES) do
    local acc = TAB_ACCENT[tn]
    local t = PANEL_TITLES[tn]
    scrolls[tn .. "_alpha"] = makePanel(tn, "alpha", SIDEBAR_W,        PA_W, acc, t.alpha)
    scrolls[tn .. "_beta"]  = makePanel(tn, "beta",  SIDEBAR_W + PA_W, PB_W, acc, t.beta)
end

-- Live panel
local liveFrame = create("Frame", { Name = "LiveGame", Size = UDim2.fromOffset(LG_W, TOTAL_H),
    Position = UDim2.fromOffset(SIDEBAR_W + PA_W + PB_W, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true }, content)
create("Frame", { Size = UDim2.fromOffset(1, TOTAL_H), BackgroundColor3 = C.border, BorderSizePixel = 0 }, liveFrame)
create("TextLabel", { Size = UDim2.fromOffset(LG_W - 32, 36), Position = UDim2.fromOffset(16, 14),
    BackgroundTransparency = 1, Text = "LIVE GAME", Font = F_MONO, TextSize = 10, TextColor3 = C.pink,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }, liveFrame)
create("Frame", { Size = UDim2.fromOffset(LG_W, 1), Position = UDim2.fromOffset(0, 48),
    BackgroundColor3 = C.border, BorderSizePixel = 0 }, liveFrame)
liveScroll = create("ScrollingFrame", { Size = UDim2.fromOffset(LG_W, TOTAL_H - 50),
    Position = UDim2.fromOffset(0, 50), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 2, ScrollBarImageColor3 = C.pink,
    CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, liveFrame)
padAll(liveScroll, 14)
local _liveList = Instance.new("UIListLayout")
_liveList.Padding = UDim.new(0, 2); _liveList.SortOrder = Enum.SortOrder.LayoutOrder; _liveList.Parent = liveScroll

switchTab = function(tabName)
    if not panels[tabName] then tabName = "Main" end
    CFG.ActiveTab = tabName
    paintTabs()
    for _, tn in ipairs(TAB_NAMES) do
        local pair = panels[tn]
        if pair then
            if pair.alpha then pair.alpha.frame.Visible = (tn == tabName) end
            if pair.beta then pair.beta.frame.Visible = (tn == tabName) end
        end
    end
    closeOpenPopup()
    if CFG.AutoSave then saveCFG() end
end

-- Components
local function sectionHeader(parent, icon, label, order)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = order }, parent)
    create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 35),
        BackgroundColor3 = C.border, BorderSizePixel = 0 }, row)
    local bar = create("Frame", { Size = UDim2.fromOffset(3, 12), Position = UDim2.fromOffset(0, 14),
        BackgroundColor3 = C.white, BorderSizePixel = 0 }, row)
    corner(bar, 1); grad(bar, C.pink, C.purple, 90)
    create("TextLabel", { Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = icon .. "  " .. label,
        Font = F_SANS_BOLD, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }, row)
    return row
end

local function toggleRow(parent, label, cfgKey, order, cb)
    if CFG[cfgKey] == nil then CFG[cfgKey] = false end
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true }, parent)
    create("TextLabel", { Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
    local track = create("Frame", { Size = UDim2.fromOffset(36, 20), Position = UDim2.new(1, -36, 0.5, -10),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0 }, row)
    corner(track, 10)
    local trackStroke = stroke(track, C.border2, 1, 0)
    local trackGrad = Instance.new("UIGradient")
    trackGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,C.pink), ColorSequenceKeypoint.new(1,C.purple)})
    trackGrad.Rotation = 0; trackGrad.Enabled = false; trackGrad.Parent = track
    local knob = create("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3 }, track)
    corner(knob, 7)
    local function paint()
        local on = CFG[cfgKey] == true
        if on then track.BackgroundColor3 = C.white; trackGrad.Enabled = true; trackStroke.Transparency = 1
        else track.BackgroundColor3 = C.bg3; trackGrad.Enabled = false; trackStroke.Transparency = 0 end
        TweenService:Create(knob, TweenInfo.new(0.15), { Position = UDim2.fromOffset(on and 19 or 3, 3) }):Play()
    end
    paint()
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            CFG[cfgKey] = not CFG[cfgKey]; paint()
            if CFG.AutoSave then saveCFG() end
            if cb then pcall(cb, CFG[cfgKey]) end
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
    local btn = create("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = color or C.bg3,
        BorderSizePixel = 0, LayoutOrder = order, Active = true }, parent)
    corner(btn, 6); stroke(btn, C.border2, 1, 0)
    local lbl = create("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_BOLD, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center }, btn)
    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if cb then task.spawn(function() pcall(cb) end) end
            local orig = lbl.Text; lbl.Text = label .. " ..."; lbl.TextColor3 = C.green
            task.delay(1.2, function() if lbl.Parent then lbl.Text = orig; lbl.TextColor3 = C.text end end)
        end
    end)
    return btn
end

local function infoRow(parent, label, initialVal, valColor, order)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order }, parent)
    create("TextLabel", { Size = UDim2.fromScale(0.55, 1), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
    local val = create("TextLabel", { Size = UDim2.fromScale(0.45, 1), Position = UDim2.fromScale(0.55, 0),
        BackgroundTransparency = 1, Text = tostring(initialVal or "—"),
        Font = F_MONO, TextSize = 10, TextColor3 = valColor or C.text2,
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd }, row)
    return val
end

local function sliderRow(parent, label, cfgKey, minV, maxV, step, order)
    if CFG[cfgKey] == nil then CFG[cfgKey] = minV end
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = order, Active = true }, parent)
    create("TextLabel", { Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.fromOffset(0, 2),
        BackgroundTransparency = 1, Text = label, Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left }, row)
    local valLbl = create("TextLabel", { Size = UDim2.new(0.4, 0, 0, 20), Position = UDim2.new(0.6, 0, 0, 2),
        BackgroundTransparency = 1, Text = tostring(CFG[cfgKey]), Font = F_MONO, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Right }, row)
    local trackF = create("Frame", { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 30),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true }, row)
    corner(trackF, 3); stroke(trackF, C.border2, 1, 0)
    local frac = math.clamp((CFG[cfgKey] - minV) / (maxV - minV), 0, 1)
    local fill = create("Frame", { Size = UDim2.new(frac, 0, 1, 0), BackgroundColor3 = C.pink, BorderSizePixel = 0 }, trackF)
    corner(fill, 3)
    local knob = create("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(frac, -7, 0.5, -7),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3 }, trackF)
    corner(knob, 7)
    local sliding = false
    local function updateSlider(x)
        local absPos = trackF.AbsolutePosition.X
        local absSize = trackF.AbsoluteSize.X
        if absSize <= 0 then return end
        local f = math.clamp((x - absPos) / absSize, 0, 1)
        local v = minV + (maxV - minV) * f
        if step and step > 0 then v = math.floor(v / step + 0.5) * step end
        v = math.clamp(v, minV, maxV)
        CFG[cfgKey] = v
        fill.Size = UDim2.new(f, 0, 1, 0); knob.Position = UDim2.new(f, -7, 0.5, -7)
        local digits = (step and step < 1) and 2 or 0
        valLbl.Text = string.format("%." .. digits .. "f", v)
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

local function dropdownRow(parent, label, cfgKey, options, order, multi)
    if multi then
        if type(CFG[cfgKey]) ~= "table" then CFG[cfgKey] = {} end
    else
        if CFG[cfgKey] == nil then CFG[cfgKey] = options[1] end
    end
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true }, parent)
    create("TextLabel", { Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
    local pill = create("Frame", { Size = UDim2.fromOffset(92, 22), Position = UDim2.new(1, -92, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0 }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)
    local function displayText()
        if multi then
            local count, firstKey = 0, nil
            for k in pairs(CFG[cfgKey]) do count = count + 1; if not firstKey then firstKey = k end end
            if count == 0 then return "None" end
            if count == 1 then return tostring(firstKey) end
            return count .. " selected"
        else return tostring(CFG[cfgKey] or "—") end
    end
    local valLabel = create("TextLabel", { Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = displayText(), Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, pill)
    local arrow = create("TextLabel", { Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▼", Font = F_SANS, TextSize = 8, TextColor3 = C.pink }, pill)
    local POPUP_W, OPT_H = 220, 26
    local POPUP_H = math.min(340, #options * (OPT_H + 2) + 8)
    local popup = create("Frame", { Name = "DropdownPopup_" .. cfgKey, Size = UDim2.fromOffset(POPUP_W, POPUP_H),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false, ZIndex = 50 }, screenGui)
    corner(popup, 8); stroke(popup, C.border2, 1, 0)
    local popScroll = create("ScrollingFrame", { Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.pink,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 51 }, popup)
    padAll(popScroll, 4)
    local popList = Instance.new("UIListLayout")
    popList.Padding = UDim.new(0, 2); popList.SortOrder = Enum.SortOrder.LayoutOrder; popList.Parent = popScroll
    local optBtns = {}
    local function isSelected(opt)
        if multi then return CFG[cfgKey][opt] == true end
        return CFG[cfgKey] == opt
    end
    for i, opt in ipairs(options) do
        local btn = create("Frame", { Name = "Opt_" .. tostring(opt), Size = UDim2.new(1, 0, 0, OPT_H),
            BackgroundColor3 = C.bg3, BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
            LayoutOrder = i, ZIndex = 52 }, popScroll)
        corner(btn, 4)
        local check = create("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 6, 0.5, -6),
            BackgroundColor3 = C.bg3, BorderSizePixel = 0, ZIndex = 53 }, btn)
        corner(check, multi and 2 or 6); stroke(check, C.border2, 1, 0)
        local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.pink,
            BorderSizePixel = 0, Visible = false, ZIndex = 54 }, check)
        corner(fill, multi and 2 or 6)
        create("TextLabel", { Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(26, 0),
            BackgroundTransparency = 1, Text = tostring(opt), Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53, TextTruncate = Enum.TextTruncate.AtEnd }, btn)
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
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                if multi then
                    if CFG[cfgKey][o.opt] then CFG[cfgKey][o.opt] = nil else CFG[cfgKey][o.opt] = true end
                else CFG[cfgKey] = o.opt end
                paintOpts(); valLabel.Text = displayText()
                if CFG.AutoSave then saveCFG() end
                if not multi then closeOpenPopup() end
            end
        end)
    end
    local function openPopup()
        if _openPopup and _openPopup.frame ~= popup then closeOpenPopup() end
        local pp = pill.AbsolutePosition; local ps = pill.AbsoluteSize
        popup.Position = UDim2.fromOffset(pp.X + ps.X - POPUP_W, pp.Y + ps.Y + 4)
        popup.Visible = true; arrow.Text = "▲"; paintOpts()
        _openPopup = { frame = popup, onClose = function() arrow.Text = "▼"; valLabel.Text = displayText() end }
        _skipNextOutside = true
    end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if _openPopup and _openPopup.frame == popup then closeOpenPopup() else openPopup() end
        end
    end)
    return row, valLabel
end

local function inputRow(parent, label, cfgKey, placeholder, order)
    if CFG[cfgKey] == nil then CFG[cfgKey] = "" end
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = order }, parent)
    create("TextLabel", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
    local inputBox = create("TextBox", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 20),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0, Text = tostring(CFG[cfgKey] or ""),
        PlaceholderText = placeholder or "",
        Font = F_MONO, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false }, row)
    corner(inputBox, 5); stroke(inputBox, C.border2, 1, 0)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = inputBox
    inputBox.FocusLost:Connect(function()
        CFG[cfgKey] = inputBox.Text
        if CFG.AutoSave then saveCFG() end
    end)
    return row, inputBox
end

-- ============================================================
-- TAB POPULATIONS
-- ============================================================

-- MAIN
local oMa, oMb = 0, 0
local function nMa() oMa = oMa + 1; return oMa end
local function nMb() oMb = oMb + 1; return oMb end

sectionHeader(scrolls["Main_alpha"], "●", "Movement", nMa())
toggleRow    (scrolls["Main_alpha"], "Walkspeed",  "Walkspeed", nMa())
sliderRow    (scrolls["Main_alpha"], "Value",      "WalkspeedValue", 1, 150, 1, nMa())
toggleRow    (scrolls["Main_alpha"], "JumpPower",  "JumpPower", nMa())
sliderRow    (scrolls["Main_alpha"], "Value",      "JumpPowerValue", 1, 200, 1, nMa())
toggleRow    (scrolls["Main_alpha"], "HipHeight",  "HipHeight", nMa())
sliderRow    (scrolls["Main_alpha"], "Value",      "HipHeightValue", 0.1, 10, 0.1, nMa())
toggleRow    (scrolls["Main_alpha"], "No Mountain Slip", "NoMountainSlip", nMa(), updmsa)
toggleRow    (scrolls["Main_alpha"], "Better Mountain Climber", "BetterClimber", nMa(), updmsa)
toggleRow    (scrolls["Main_alpha"], "Fly (WASD + Space/Ctrl)", "Fly", nMa())
sliderRow    (scrolls["Main_alpha"], "Fly Speed", "FlySpeed", 10, 250, 5, nMa())
toggleRow    (scrolls["Main_alpha"], "Noclip", "Noclip", nMa())

sectionHeader(scrolls["Main_beta"], "♥", "Survival", nMb())
toggleRow    (scrolls["Main_beta"], "Auto Heal", "AutoHeal", nMb())
sliderRow    (scrolls["Main_beta"], "Heal Threshold %", "HealThreshold", 10, 90, 5, nMb())
toggleRow    (scrolls["Main_beta"], "Auto Eat (smart priority)", "AutoEat", nMb())
toggleRow    (scrolls["Main_beta"], "Auto Equip Armor", "AutoEquipArmor", nMb())
toggleRow    (scrolls["Main_beta"], "Typing Check (pauses autos)", "TypingCheck", nMb())

sectionHeader(scrolls["Main_beta"], "◉", "Utilities", nMb())
actionBtn(scrolls["Main_beta"], "Copy Job ID", C.bg3, nMb(), function() if setclipboard then setclipboard(game.JobId) end end)
actionBtn(scrolls["Main_beta"], "Copy HWID",   C.bg3, nMb(), function() if setclipboard then setclipboard(rbxservice:GetClientId()) end end)

sectionHeader(scrolls["Main_beta"], "◉", "Status", nMb())
U.infoMode    = infoRow(scrolls["Main_beta"], "Mode",    "Idle", C.pink,  nMb())
U.infoRuntime = infoRow(scrolls["Main_beta"], "Runtime", "0m",   C.text2, nMb())
U.infoHealth  = infoRow(scrolls["Main_beta"], "Health",  "—",    C.text,  nMb())
U.infoSpeed   = infoRow(scrolls["Main_beta"], "Speed",   "16",   C.text,  nMb())

-- COMBAT
local oCa, oCb = 0, 0
local function nCa() oCa = oCa + 1; return oCa end
local function nCb() oCb = oCb + 1; return oCb end

sectionHeader(scrolls["Combat_alpha"], "⚔", "Kill Aura", nCa())
toggleRow    (scrolls["Combat_alpha"], "Kill Aura",        "KillAura", nCa())
toggleRow    (scrolls["Combat_alpha"], "Legit (jitter)",   "LegitKillAura", nCa())
sliderRow    (scrolls["Combat_alpha"], "Range",            "KillAuraRange", 1, 30, 1, nCa())
dropdownRow  (scrolls["Combat_alpha"], "Max Targets",      "KillAuraMaxTargets", {"1","2","3","4","5","6"}, nCa(), false)
sliderRow    (scrolls["Combat_alpha"], "Attack Cooldown",  "KillAuraCooldown", 0.01, 1.01, 0.01, nCa())

sectionHeader(scrolls["Combat_alpha"], "◆", "Resource + Critter", nCa())
toggleRow    (scrolls["Combat_alpha"], "Resource Aura",   "ResourceAura", nCa())
sliderRow    (scrolls["Combat_alpha"], "Range",           "ResourceAuraRange", 1, 40, 1, nCa())
toggleRow    (scrolls["Combat_alpha"], "Critter Aura",    "CritterAura", nCa())
sliderRow    (scrolls["Combat_alpha"], "Range",           "CritterAuraRange", 1, 40, 1, nCa())
toggleRow    (scrolls["Combat_alpha"], "Auto Hit Everything", "AutoHitEverything", nCa())
toggleRow    (scrolls["Combat_alpha"], "Auto Tool Swap",  "AutoToolSwap", nCa())

sectionHeader(scrolls["Combat_beta"], "✧", "Voodoo", nCb())
toggleRow    (scrolls["Combat_beta"], "Auto Energy Shield (godmode)", "AutoVoodooShield", nCb())
toggleRow    (scrolls["Combat_beta"], "Auto Energy Bolt (nearest)", "AutoVoodooBolt", nCb())
sliderRow    (scrolls["Combat_beta"], "Voodoo Range", "VoodooBoltRange", 10, 120, 5, nCb())
actionBtn    (scrolls["Combat_beta"], "Cast Void Cloak (30s invis)", C.purple, nCb(), function() fireVoodoo("Void Cloak") end)
actionBtn    (scrolls["Combat_beta"], "Cast Shadow Warp (15s)", C.purple, nCb(), function() fireVoodoo("Shadow Warp") end)
actionBtn    (scrolls["Combat_beta"], "Cast Voodoo Vortex", C.purple, nCb(), function() fireVoodoo("Voodoo Vortex") end)

sectionHeader(scrolls["Combat_beta"], "👥", "PvP Assist", nCb())
toggleRow    (scrolls["Combat_beta"], "Face Closest Player", "FaceClosest", nCb())
toggleRow    (scrolls["Combat_beta"], "Move To Closest",     "MoveToClosest", nCb())
toggleRow    (scrolls["Combat_beta"], "HitBox Expander (Players)", "HitboxPlayers", nCb())
sliderRow    (scrolls["Combat_beta"], "Player Hitbox Size", "HitboxPlayersSize", 5, 40, 1, nCb())
toggleRow    (scrolls["Combat_beta"], "HitBox Expander (Birds)", "HitboxBirds", nCb())
sliderRow    (scrolls["Combat_beta"], "Bird Hitbox Size",   "HitboxBirdsSize", 5, 40, 1, nCb())
toggleRow    (scrolls["Combat_beta"], "Auto Wall Player",   "AutoWallPlayer", nCb())
toggleRow    (scrolls["Combat_beta"], "Auto Hut Player",    "AutoHutPlayer", nCb())
sliderRow    (scrolls["Combat_beta"], "Trap Range",         "PvPTrapRange", 5, 40, 1, nCb())

sectionHeader(scrolls["Combat_beta"], "◉", "Session Totals", nCb())
U.infoSwings = infoRow(scrolls["Combat_beta"], "Swings",   "0", C.pink,   nCb())
U.infoVoodoo = infoRow(scrolls["Combat_beta"], "Voodoos",  "0", C.purple, nCb())
U.infoHeals  = infoRow(scrolls["Combat_beta"], "Heals",    "0", C.green,  nCb())

-- MAP (Waypoints + Auto Farm Gold)
local oRa, oRb = 0, 0
local function nRa() oRa = oRa + 1; return oRa end
local function nRb() oRb = oRb + 1; return oRb end

sectionHeader(scrolls["Map_alpha"], "●", "AFK Gold Farm", nRa())
toggleRow    (scrolls["Map_alpha"], "Auto Farm Gold (4-node loop)", "AutoFarmGold", nRa())
create("TextLabel", { Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1,
    Text = "Teleports between 4 surface Gold Nodes,\nmines each for 12 swings, rotates.\nFully AFK-able. Use with Auto Pickup + Auto Heal.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nRa() }, scrolls["Map_alpha"])

sectionHeader(scrolls["Map_beta"], "◆", "Portals (TP to)", nRb())
local function tpTo(pos)
    if root then root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) end
end
actionBtn(scrolls["Map_beta"], "Queen's Cave Portal", C.bg3, nRb(), function() tpTo(Vector3.new(336, -306, -1034)) end)
actionBtn(scrolls["Map_beta"], "Lava Portal 1", C.bg3, nRb(), function() tpTo(Vector3.new(815, -45, -343)) end)
actionBtn(scrolls["Map_beta"], "Lava Portal 2", C.bg3, nRb(), function() tpTo(Vector3.new(219, -141, 1082)) end)
actionBtn(scrolls["Map_beta"], "Lava Portal 3", C.bg3, nRb(), function() tpTo(Vector3.new(876, -144, -142)) end)
actionBtn(scrolls["Map_beta"], "Haven Portal (Void World)", C.green, nRb(), function() tpTo(Vector3.new(-1062, -201, -428)) end)

sectionHeader(scrolls["Map_beta"], "◆", "Biome Quick TP", nRb())
actionBtn(scrolls["Map_beta"], "Sky Rope (Sky Island)", C.bg3, nRb(), function() tpTo(Vector3.new(-491, 306, -1105)) end)
actionBtn(scrolls["Map_beta"], "Spirit Lock", C.bg3, nRb(), function() tpTo(Vector3.new(-766, 310, -1193)) end)
actionBtn(scrolls["Map_beta"], "Ancient Tree", C.bg3, nRb(), function() tpTo(Vector3.new(-557, 311, -1197)) end)
actionBtn(scrolls["Map_beta"], "Queen Ant Boss", C.red, nRb(), function() tpTo(Vector3.new(157, -317, -861)) end)
actionBtn(scrolls["Map_beta"], "Meteor Cave", C.bg3, nRb(), function() tpTo(Vector3.new(134, -313, -758)) end)
actionBtn(scrolls["Map_beta"], "Emerald Cave", C.bg3, nRb(), function() tpTo(Vector3.new(984, -122, -44)) end)
actionBtn(scrolls["Map_beta"], "Crystal Lode (Sky)", C.bg3, nRb(), function() tpTo(Vector3.new(-1069, 339, -1300)) end)
actionBtn(scrolls["Map_beta"], "Adurite Nodes Cluster", C.bg3, nRb(), function() tpTo(Vector3.new(592, -50, -274)) end)

-- PICKUP
local oPa, oPb = 0, 0
local function nPa() oPa = oPa + 1; return oPa end
local function nPb() oPb = oPb + 1; return oPb end

-- v5.1 expanded pickup list — 54 items covering ALL live drops
local PICKUP_ITEMS = {
    "Wood","Log","Stone","Leaves","Vine","Hide","Coal","Steel","Steel Mix","Iron","Raw Iron",
    "Gold","Raw Gold","Adurite","Raw Adurite","Crystal Chunk","Emerald","Raw Emerald","Pink Diamond","Raw Pink Diamond",
    "Magnetite","Raw Magnetite","Void Shard","Essence","Spirit Key","Ice Cube","Cactus Bit",
    "Berry","Bloodfruit","Bluefruit","Lemon","Strawberry","Sunfruit","Pumpkin","Apple","Carrot","Banana","Orange","Coconut",
    "Cloudberry","Oddberry","Strangefruit","Barley","Jelly",
    "Egg","Cooked Egg","Raw Meat","Cooked Meat","Raw Morsel","Raw Fish","Cooked Fish",
    "Coin","Coins","Coin2","Coin Stack","Bolt","Arrow","Pie",
    "Stone Axe","Stone Pick","Club","Sling","Hide Bag","Leaf Bag","Leaf Pouch",
    "Pleb Chest","Easter Chest","Food Chest","Resource Chest","Good Chest","Great Chest","OMG Chest","Essence Chest",
    "Adurite Chest","Reinforced Chest","Treasure Chest","Magnetite Chest","Party Chest","Prop Hunt: Essence Chest",
    "Ancient Chest","Mythic Chest"
}
local DROP_ITEMS = {"Bloodfruit", "Jelly", "Bluefruit", "Log", "Leaves", "Wood", "Stone", "Hide"}

sectionHeader(scrolls["Pickup_alpha"], "▣", "Auto Pickup", nPa())
toggleRow    (scrolls["Pickup_alpha"], "Auto Pickup",              "AutoPickup", nPa())
toggleRow    (scrolls["Pickup_alpha"], "Auto Pickup From Chests",  "AutoChestPickup", nPa())
sliderRow    (scrolls["Pickup_alpha"], "Pickup Range",             "PickupRange", 1, 100, 1, nPa())
dropdownRow  (scrolls["Pickup_alpha"], "Items",                    "PickupItems", PICKUP_ITEMS, nPa(), true)

sectionHeader(scrolls["Pickup_beta"], "▼", "Auto Drop", nPb())
toggleRow    (scrolls["Pickup_beta"], "Auto Drop",              "AutoDrop", nPb())
dropdownRow  (scrolls["Pickup_beta"], "Drop Item",              "DropItem", DROP_ITEMS, nPb(), false)
toggleRow    (scrolls["Pickup_beta"], "Auto Drop Custom",       "AutoDropCustom", nPb())
inputRow     (scrolls["Pickup_beta"], "Custom Item Name",       "DropItemCustom", "Bloodfruit", nPb())

sectionHeader(scrolls["Pickup_beta"], "◉", "Counters", nPb())
U.infoPickups = infoRow(scrolls["Pickup_beta"], "Pickups", "0", C.pink, nPb())
U.infoDrops   = infoRow(scrolls["Pickup_beta"], "Drops",   "0", C.pink, nPb())

-- FARMING
local oFa, oFb = 0, 0
local function nFa() oFa = oFa + 1; return oFa end
local function nFb() oFb = oFb + 1; return oFb end

local FRUITS = {"Bloodfruit", "Bluefruit", "Lemon", "Coconut", "Jelly", "Banana", "Orange", "Oddberry", "Berry", "Strangefruit", "Strawberry", "Sunfruit", "Pumpkin", "Prickly Pear", "Apple", "Barley", "Cloudberry", "Carrot"}

sectionHeader(scrolls["Farming_alpha"], "✿", "Plant + Harvest", nFa())
dropdownRow  (scrolls["Farming_alpha"], "Fruit",         "Fruit", FRUITS, nFa(), false)
toggleRow    (scrolls["Farming_alpha"], "Auto Plant",    "AutoPlant", nFa())
sliderRow    (scrolls["Farming_alpha"], "Plant Range",   "PlantRange", 1, 60, 1, nFa())
sliderRow    (scrolls["Farming_alpha"], "Plant Delay",   "PlantDelay", 0.01, 1, 0.01, nFa())
toggleRow    (scrolls["Farming_alpha"], "Auto Harvest",  "AutoHarvest", nFa())
sliderRow    (scrolls["Farming_alpha"], "Harvest Range", "HarvestRange", 1, 60, 1, nFa())

sectionHeader(scrolls["Farming_beta"], "◆", "Tween", nFb())
toggleRow    (scrolls["Farming_beta"], "Tween to Plant Box",       "TweenPlantBox", nFb())
toggleRow    (scrolls["Farming_beta"], "Tween to Bush + Plant Box", "TweenBush", nFb())
sliderRow    (scrolls["Farming_beta"], "Tween Range",              "TweenRange", 1, 400, 1, nFb())

sectionHeader(scrolls["Farming_beta"], "▣", "Place Plantboxes", nFb())
actionBtn(scrolls["Farming_beta"], "Place 16x16 (256)", C.bg3, nFb(), function() placestructure(16) end)
actionBtn(scrolls["Farming_beta"], "Place 15x15 (225)", C.bg3, nFb(), function() placestructure(15) end)
actionBtn(scrolls["Farming_beta"], "Place 10x10 (100)", C.bg3, nFb(), function() placestructure(10) end)
actionBtn(scrolls["Farming_beta"], "Place 5x5 (25)",    C.bg3, nFb(), function() placestructure(5) end)

-- EXTRA
local oEa, oEb = 0, 0
local function nEa() oEa = oEa + 1; return oEa end
local function nEb() oEb = oEb + 1; return oEb end

sectionHeader(scrolls["Extra_alpha"], "+", "Auto Everything", nEa())
toggleRow    (scrolls["Extra_alpha"], "Auto Fishing",      "AutoFishing", nEa())
toggleRow    (scrolls["Extra_alpha"], "Auto Coin Press",   "AutoCoinPress", nEa())
toggleRow    (scrolls["Extra_alpha"], "Auto Campfire",     "AutoCampfire", nEa())
toggleRow    (scrolls["Extra_alpha"], "Auto Chest Open",   "AutoChestOpen", nEa())
toggleRow    (scrolls["Extra_alpha"], "Auto Rebirth",      "AutoRebirth", nEa())

sectionHeader(scrolls["Extra_alpha"], "★", "Event Hunts", nEa())
toggleRow    (scrolls["Extra_alpha"], "Auto Egg Hunt (Easter)",  "AutoEggHunt", nEa())
toggleRow    (scrolls["Extra_alpha"], "Auto Heart Hunt (Valentine)", "AutoHeartHunt", nEa())
toggleRow    (scrolls["Extra_alpha"], "Auto Gold Hunt",      "AutoGoldHunt", nEa())

sectionHeader(scrolls["Extra_beta"], "●", "Item Orbit", nEb())
toggleRow    (scrolls["Extra_beta"], "Item Orbit",   "ItemOrbit", nEb())
sliderRow    (scrolls["Extra_beta"], "Grab Range",   "OrbitRange", 1, 100, 1, nEb())
sliderRow    (scrolls["Extra_beta"], "Orbit Radius", "OrbitRadius", 0, 50, 1, nEb())
sliderRow    (scrolls["Extra_beta"], "Orbit Speed",  "OrbitSpeed", 0, 20, 1, nEb())
sliderRow    (scrolls["Extra_beta"], "Item Height",  "ItemHeight", -5, 15, 1, nEb())

sectionHeader(scrolls["Extra_beta"], "▣", "Launcher", nEb())
actionBtn(scrolls["Extra_beta"], "Infinite Yield Chat", C.bg3, nEb(), function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/decryp1/herklesiy/refs/heads/main/hiy"))()
end)

sectionHeader(scrolls["Extra_beta"], "◉", "Counters", nEb())
U.infoEggs    = infoRow(scrolls["Extra_beta"], "Eggs picked",   "0", C.purple, nEb())
U.infoHearts  = infoRow(scrolls["Extra_beta"], "Hearts picked", "0", C.red,    nEb())
U.infoFish    = infoRow(scrolls["Extra_beta"], "Fish caught",   "0", C.text2,  nEb())
U.infoChests  = infoRow(scrolls["Extra_beta"], "Chests opened", "0", C.text2,  nEb())

-- ESP
local oSPa, oSPb = 0, 0
local function nSPa() oSPa = oSPa + 1; return oSPa end
local function nSPb() oSPb = oSPb + 1; return oSPb end

sectionHeader(scrolls["ESP_alpha"], "◎", "Categories", nSPa())
toggleRow    (scrolls["ESP_alpha"], "Players (pink)",          "ESPPlayers", nSPa())
toggleRow    (scrolls["ESP_alpha"], "Critters (purple/red boss)", "ESPCritters", nSPa())
toggleRow    (scrolls["ESP_alpha"], "Resources (green = rare)", "ESPResources", nSPa())
toggleRow    (scrolls["ESP_alpha"], "Items (yellow)",           "ESPItems", nSPa())
toggleRow    (scrolls["ESP_alpha"], "Chests (orange/gold)",     "ESPChests", nSPa())
toggleRow    (scrolls["ESP_alpha"], "Bosses only (magenta)",    "ESPBosses", nSPa())
sliderRow    (scrolls["ESP_alpha"], "Max Range",                "ESPRange", 100, 2000, 50, nSPa())

sectionHeader(scrolls["ESP_alpha"], "▣", "Quick Actions", nSPa())
actionBtn(scrolls["ESP_alpha"], "Clear All ESP", C.red, nSPa(), function()
    CFG.ESPPlayers = false; CFG.ESPCritters = false; CFG.ESPResources = false
    CFG.ESPItems = false; CFG.ESPChests = false; CFG.ESPBosses = false
end)

sectionHeader(scrolls["ESP_beta"], "✦", "Color Legend", nSPb())
infoRow(scrolls["ESP_beta"], "Players",          "pink",        C.pink,                   nSPb())
infoRow(scrolls["ESP_beta"], "Critters",         "purple",      C.purple,                 nSPb())
infoRow(scrolls["ESP_beta"], "Boss critters",    "red",         C.red,                    nSPb())
infoRow(scrolls["ESP_beta"], "Rare resources",   "green",       C.green,                  nSPb())
infoRow(scrolls["ESP_beta"], "Normal resources", "grey",        C.text2,                  nSPb())
infoRow(scrolls["ESP_beta"], "Items",            "yellow",      Color3.fromRGB(255,255,0), nSPb())
infoRow(scrolls["ESP_beta"], "Chests",           "orange",      Color3.fromRGB(255,165,0), nSPb())
infoRow(scrolls["ESP_beta"], "Drop chests",      "gold",        Color3.fromRGB(255,215,0), nSPb())
infoRow(scrolls["ESP_beta"], "World bosses",     "magenta",     Color3.fromRGB(255,0,128), nSPb())

sectionHeader(scrolls["ESP_beta"], "◉", "Live Count", nSPb())
U.espActive = infoRow(scrolls["ESP_beta"], "Highlights", "0", C.green, nSPb())

-- SETTINGS
local oSa, oSb = 0, 0
local function nSa() oSa = oSa + 1; return oSa end
local function nSb() oSb = oSb + 1; return oSb end

sectionHeader(scrolls["Settings_alpha"], "●", "Config", nSa())
toggleRow    (scrolls["Settings_alpha"], "Auto Save", "AutoSave", nSa())
actionBtn    (scrolls["Settings_alpha"], "Save Config Now", C.green, nSa(), saveCFG)
actionBtn    (scrolls["Settings_alpha"], "Load Config",     C.bg3,   nSa(), loadSavedCFG)
actionBtn    (scrolls["Settings_alpha"], "Reset Config",    C.red,   nSa(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" and k ~= "AutoSave" and k ~= "TypingCheck" then CFG[k] = false end
        if type(v) == "table" and k == "PickupItems" then CFG[k] = { Leaves = true, Log = true } end
    end
    saveCFG()
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSa())
actionBtn(scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function() main.Position = UDim2.fromScale(0.5, 0.5) end)
actionBtn(scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.15)
    getgenv().__AURORAHUB_BOOGA_SESSION = 0
    pcall(function() screenGui:Destroy() end)
    -- Clean up ESP
    for _, h in pairs(E.highlights) do pcall(function() h:Destroy() end) end
    for inst in pairs(E.origHitbox) do
        pcall(function() inst.Size = E.origHitbox[inst].size; inst.Transparency = E.origHitbox[inst].trans end)
    end
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "Booga Booga Reborn",       C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),     C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion), C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",            C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v5.1 — Nilhub Parity",     C.green, nSb())
infoRow(scrolls["Settings_beta"], "Features","50+",                      C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,               C.text3, nSb())
infoRow(scrolls["Settings_beta"], "Network", "ByteNet + Packets",        C.text3, nSb())

sectionHeader(scrolls["Settings_beta"], "◆", "Active Features", nSb())
U.cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 280), BackgroundTransparency = 1,
    Text = "None", Font = F_SANS, TextSize = 10, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nSb(),
}, scrolls["Settings_beta"])

-- LIVE panel
local oL = 0
local function nL() oL = oL + 1; return oL end
sectionHeader(liveScroll, "◉", "Session", nL())
U.liveRuntime = infoRow(liveScroll, "Runtime", "0m",   C.text2, nL())
U.liveStatus  = infoRow(liveScroll, "Status",  "Idle", C.pink,  nL())

sectionHeader(liveScroll, "●", "Player", nL())
U.liveHealth = infoRow(liveScroll, "Health", "—", C.text, nL())
U.liveSpeed  = infoRow(liveScroll, "Speed",  "16", C.text, nL())

sectionHeader(liveScroll, "⚔", "Combat", nL())
U.liveSwings = infoRow(liveScroll, "Swings",   "0", C.pink, nL())
U.liveVoodoo = infoRow(liveScroll, "Voodoos",  "0", C.purple, nL())
U.liveHeals  = infoRow(liveScroll, "Heals",    "0", C.green, nL())
U.liveEats   = infoRow(liveScroll, "Eats",     "0", C.green, nL())

sectionHeader(liveScroll, "▣", "Pickup", nL())
U.livePickups = infoRow(liveScroll, "Picked", "0", C.pink, nL())

sectionHeader(liveScroll, "★", "Event", nL())
U.liveEggs    = infoRow(liveScroll, "Eggs",   "0", C.purple, nL())
U.liveHearts  = infoRow(liveScroll, "Hearts", "0", C.red,    nL())
U.liveFish    = infoRow(liveScroll, "Fish",   "0", C.text2,  nL())
U.liveChests  = infoRow(liveScroll, "Chests", "0", C.text2,  nL())

-- PILL
local pillGui = create("ScreenGui", { Name = "AuroraPill", DisplayOrder = 9998, ResetOnSpawn = false, IgnoreGuiInset = true })
local _pillOk = false
if typeof(gethui) == "function" then _pillOk = pcall(function() pillGui.Parent = gethui() end) end
if not _pillOk then _pillOk = pcall(function() pillGui.Parent = game:GetService("CoreGui") end) end
if not _pillOk then pcall(function() pillGui.Parent = plr:WaitForChild("PlayerGui") end) end

local pill = create("Frame", { Name = "Pill", Size = UDim2.fromOffset(152, 36),
    Position = UDim2.new(1, -172, 0, 22), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15,
    BorderSizePixel = 0, Active = true }, pillGui)
corner(pill, 18); stroke(pill, C.border2, 1, 0)

local pillGlow = create("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(9, 9),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 1 }, pill)
corner(pillGlow, 9)
local pillGlowInner = create("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(12, 12),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 2 }, pill)
corner(pillGlowInner, 6)
local pillDot = create("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(14, 14),
    BackgroundColor3 = C.green, BorderSizePixel = 0, ZIndex = 3 }, pill)
corner(pillDot, 4)
task.spawn(function()
    TweenService:Create(pillGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.55, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(7, 7) }):Play()
    TweenService:Create(pillGlowInner, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.35 }):Play()
end)
create("TextLabel", { Size = UDim2.fromOffset(50, 36), Position = UDim2.fromOffset(28, 0),
    BackgroundTransparency = 1, Text = "Aurora", Font = F_SANS_BOLD, TextSize = 12, TextColor3 = C.pink,
    TextXAlignment = Enum.TextXAlignment.Left }, pill)
create("TextLabel", { Size = UDim2.fromOffset(10, 36), Position = UDim2.fromOffset(80, 0),
    BackgroundTransparency = 1, Text = "·", Font = F_SANS_BOLD, TextSize = 14, TextColor3 = C.text3 }, pill)
U.pillActive = create("TextLabel", { Size = UDim2.fromOffset(56, 36), Position = UDim2.fromOffset(92, 0),
    BackgroundTransparency = 1, Text = "0 active", Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left }, pill)
pill.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        CFG.PanelOpen = not CFG.PanelOpen; main.Visible = CFG.PanelOpen
    end
end)

-- DRAG
local topDragStrip = create("Frame", { Name = "TopDragStrip",
    Size = UDim2.fromOffset(TOTAL_W - SIDEBAR_W, 48), Position = UDim2.fromOffset(SIDEBAR_W, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ZIndex = 3 }, content)
local _drag = { active = false, start = nil, startPos = nil }
local function attachDrag(h)
    h.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            _drag.active = true; _drag.start = inp.Position; _drag.startPos = main.Position
            closeOpenPopup()
        end
    end)
end
attachDrag(wordmarkRow); attachDrag(topDragStrip)
UIS.InputChanged:Connect(function(inp)
    if not alive() then return end
    if _drag.active and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - _drag.start
        main.Position = UDim2.new(_drag.startPos.X.Scale, _drag.startPos.X.Offset + d.X,
            _drag.startPos.Y.Scale, _drag.startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        _drag.active = false
    end
end)
UIS.InputBegan:Connect(function(inp)
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

-- CLOSE + MINIMIZE
local minBtn = create("Frame", { Name = "Minimize", Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 62, 13), BackgroundColor3 = C.bg3,
    BorderSizePixel = 0, Active = true, ZIndex = 5 }, content)
corner(minBtn, 11); stroke(minBtn, C.border2, 1, 0)
local minLine = create("Frame", { Size = UDim2.fromOffset(10, 2), Position = UDim2.new(0.5, -5, 0.5, -1),
    BackgroundColor3 = C.text2, BorderSizePixel = 0, ZIndex = 6 }, minBtn)
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

local closeBtn = create("Frame", { Name = "Close", Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 32, 13), BackgroundColor3 = C.bg3,
    BorderSizePixel = 0, Active = true, ZIndex = 5 }, content)
corner(closeBtn, 11); stroke(closeBtn, C.border2, 1, 0)
local closeX = create("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Text = "×", Font = F_SANS_BOLD, TextSize = 16, TextColor3 = C.text2, ZIndex = 6 }, closeBtn)
closeBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.red; closeX.TextColor3 = C.white
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        getgenv().__AURORAHUB_BOOGA_SESSION = 0
        task.wait(0.05)
        pcall(function() screenGui:Destroy() end)
        pcall(function() pillGui:Destroy() end)
        for _, h in pairs(E.highlights) do pcall(function() h:Destroy() end) end
    end
end)
closeBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.bg3; closeX.TextColor3 = C.text2
    end
end)

-- STATUS UPDATE
task.spawn(function()
    while alive() do
        task.wait(1 + math.random() * 0.3)
        if not alive() then break end
        pcall(function()
            local hpTxt, spdTxt = "—", "16"
            if char then
                local h = char:FindFirstChildOfClass("Humanoid")
                if h then
                    hpTxt = string.format("%.0f/%.0f", h.Health, h.MaxHealth)
                    spdTxt = tostring(math.floor(h.WalkSpeed))
                end
            end
            local elapsed = tick() - _sessionStart
            local mins = math.floor(elapsed / 60)
            local hrs = math.floor(mins / 60)
            local rtime = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            local active = {}
            for _, check in ipairs({
                {"Walkspeed","WS"},{"JumpPower","JP"},{"HipHeight","HH"},{"NoMountainSlip","NMS"},
                {"BetterClimber","Climb"},{"Fly","Fly"},{"Noclip","Noclip"},
                {"AutoHeal","Heal"},{"AutoEat","Eat"},{"AutoEquipArmor","Armor"},
                {"KillAura","KA"},{"ResourceAura","RA"},{"CritterAura","CA"},{"AutoHitEverything","HitAll"},
                {"AutoToolSwap","Tool"},{"LegitKillAura","Legit"},
                {"FaceClosest","Face"},{"MoveToClosest","Move"},
                {"AutoVoodooShield","Shield"},{"AutoVoodooBolt","Bolt"},
                {"HitboxPlayers","HBp"},{"HitboxBirds","HBb"},
                {"AutoWallPlayer","Wall"},{"AutoHutPlayer","Hut"},
                {"AutoPickup","PU"},{"AutoChestPickup","PUc"},
                {"AutoDrop","DR"},{"AutoDropCustom","DRc"},
                {"AutoPlant","PL"},{"AutoHarvest","HV"},
                {"TweenPlantBox","TB"},{"TweenBush","TB+"},
                {"ItemOrbit","Orbit"},{"AutoFarmGold","Gold"},{"AutoFishing","Fish"},
                {"AutoCoinPress","CP"},{"AutoCampfire","CF"},{"AutoChestOpen","Chest"},
                {"AutoEggHunt","Egg"},{"AutoHeartHunt","Heart"},{"AutoGoldHunt","GldH"},
                {"AutoRebirth","RB"},
                {"ESPPlayers","EspP"},{"ESPCritters","EspC"},{"ESPResources","EspR"},
                {"ESPItems","EspI"},{"ESPChests","EspCh"},{"ESPBosses","EspB"},
            }) do
                if CFG[check[1]] then table.insert(active, check[2]) end
            end

            local mode = #active > 0 and table.concat(active, " ") or "Idle"
            if #mode > 40 then mode = #active .. " active" end

            U.infoMode.Text = mode
            U.infoRuntime.Text = rtime
            U.infoHealth.Text = hpTxt
            U.infoSpeed.Text = spdTxt
            U.infoSwings.Text = tostring(S.swings)
            U.infoVoodoo.Text = tostring(S.voodoos)
            U.infoHeals.Text  = tostring(S.heals)
            U.infoPickups.Text = tostring(S.pickups)
            U.infoDrops.Text = tostring(S.drops)
            U.infoEggs.Text = tostring(S.eggs)
            U.infoHearts.Text = tostring(S.hearts)
            U.infoFish.Text = tostring(S.fish)
            U.infoChests.Text = tostring(S.chests)

            local espCount = 0
            for _ in pairs(E.highlights) do espCount = espCount + 1 end
            U.espActive.Text = tostring(espCount)

            U.liveRuntime.Text = rtime
            U.liveStatus.Text = mode
            U.liveHealth.Text = hpTxt
            U.liveSpeed.Text = spdTxt
            U.liveSwings.Text = tostring(S.swings)
            U.liveVoodoo.Text = tostring(S.voodoos)
            U.liveHeals.Text = tostring(S.heals)
            U.liveEats.Text = tostring(S.eats)
            U.livePickups.Text = tostring(S.pickups)
            U.liveEggs.Text = tostring(S.eggs)
            U.liveHearts.Text = tostring(S.hearts)
            U.liveFish.Text = tostring(S.fish)
            U.liveChests.Text = tostring(S.chests)

            local sortedActive = {}
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" and k ~= "TypingCheck" then
                    table.insert(sortedActive, "· " .. k)
                end
            end
            table.sort(sortedActive)
            U.cfgActiveLabel.Text = #sortedActive > 0 and table.concat(sortedActive, "\n") or "None"
            U.pillActive.Text = #sortedActive .. " active"
        end)
    end
end)

-- INIT
switchTab(CFG.ActiveTab or "Main")
print("[Aurora v5.1] Booga Booga Reborn loaded · 50+ features · Nilhub parity")
