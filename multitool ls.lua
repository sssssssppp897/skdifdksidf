local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local CurrentJobId = game.JobId
local PlaceId = game.PlaceId
local camera = workspace.CurrentCamera

local SG = Instance.new("ScreenGui")
SG.Name = "UnifiedTools"
SG.ResetOnSpawn = false
SG.Parent = game.CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 300, 0, 500)
Main.Position = UDim2.new(0.85, -150, 0.5, -250)
Main.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = SG
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
Header.BorderSizePixel = 0
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🛠️ Game Tools"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextYAlignment = Enum.TextYAlignment.Center
Title.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 28, 0, 28)
Close.Position = UDim2.new(1, -33, 0, 6)
Close.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
Close.Text = "×"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 18
Close.Parent = Header
Close.MouseButton1Click:Connect(function() SG:Destroy() end)
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 6)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -50)
Scroll.Position = UDim2.new(0, 10, 0, 45)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
Scroll.Parent = Main

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 15)
ListLayout.Parent = Scroll

local ServerSection = Instance.new("Frame")
ServerSection.Size = UDim2.new(1, 0, 0, 200)
ServerSection.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ServerSection.BorderSizePixel = 0
ServerSection.Parent = Scroll
Instance.new("UICorner", ServerSection).CornerRadius = UDim.new(0, 8)

local ServerHeader = Instance.new("TextLabel")
ServerHeader.Size = UDim2.new(1, -10, 0, 25)
ServerHeader.Position = UDim2.new(0, 5, 0, 5)
ServerHeader.BackgroundTransparency = 1
ServerHeader.Text = "🌐 Region Hopper"
ServerHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
ServerHeader.Font = Enum.Font.GothamBold
ServerHeader.TextSize = 16
ServerHeader.TextXAlignment = Enum.TextXAlignment.Left
ServerHeader.TextYAlignment = Enum.TextYAlignment.Center
ServerHeader.Parent = ServerSection

local ServerStatus = Instance.new("TextLabel")
ServerStatus.Size = UDim2.new(1, -10, 0, 32)
ServerStatus.Position = UDim2.new(0, 5, 0, 35)
ServerStatus.BackgroundTransparency = 1
ServerStatus.Text = "Loading..."
ServerStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
ServerStatus.Font = Enum.Font.Gotham
ServerStatus.TextSize = 12
ServerStatus.TextWrapped = true
ServerStatus.TextXAlignment = Enum.TextXAlignment.Left
ServerStatus.TextYAlignment = Enum.TextYAlignment.Center
ServerStatus.Parent = ServerSection

local ServerScroll = Instance.new("ScrollingFrame")
ServerScroll.Size = UDim2.new(1, -10, 1, -75)
ServerScroll.Position = UDim2.new(0, 5, 0, 70)
ServerScroll.BackgroundTransparency = 1
ServerScroll.ScrollBarThickness = 3
ServerScroll.Parent = ServerSection

local ServerListLayout = Instance.new("UIListLayout")
ServerListLayout.Padding = UDim.new(0, 5)
ServerListLayout.Parent = ServerScroll

local IntroLoad = nil
local EventsFolder = ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage:WaitForChild("Events", 3)
if EventsFolder then
    IntroLoad = EventsFolder:FindFirstChild("IntroLoad") or EventsFolder:WaitForChild("IntroLoad", 3)
end
if not IntroLoad then
    IntroLoad = ReplicatedStorage:FindFirstChild("IntroLoad") or ReplicatedStorage:WaitForChild("IntroLoad", 2)
end

local ServersList = ReplicatedStorage:FindFirstChild("Servers_List") or ReplicatedStorage:WaitForChild("Servers_List", 3)

local function GetJobId(serverObj)
    local jobId = serverObj:FindFirstChild("JobId")
    if jobId then return jobId.Value end
    local accessCode = serverObj:FindFirstChild("AccessCode")
    if accessCode then return accessCode.Value end
    if serverObj.Name:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") then
        return serverObj.Name
    end
    return serverObj.Name
end

local function IsValidServer(serverObj)
    if serverObj.Name:lower():find("template") or serverObj.Name:lower():find("newserver") then return false end
    local region = serverObj:FindFirstChild("Region")
    if not region then return false end
    local jobId = GetJobId(serverObj)
    if jobId == CurrentJobId then return false end
    return true, jobId
end

local function CreateRegionButton(regionName, servers, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -5, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    btn.Text = regionName .. " (" .. #servers .. ")"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextYAlignment = Enum.TextYAlignment.Center
    btn.AutoButtonColor = true
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local hovered = false
    local busy = false

    btn.MouseEnter:Connect(function()
        hovered = true
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 80, 95)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        hovered = false
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 75)}):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        if busy then return end
        busy = true
        btn.Active = false

        local pick = servers[math.random(1, #servers)]
        if not pick or not pick.JobId then
            ServerStatus.Text = "Error: invalid server"
            ServerStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
            task.delay(2, function()
                ServerStatus.Text = ""
            end)
            busy = false
            btn.Active = true
            return
        end

        if LocalPlayer:FindFirstChild("TryingToJoinDelay") then
            LocalPlayer.TryingToJoinDelay:Destroy()
        end

        ServerStatus.Text = "Joining " .. tostring(string.sub(tostring(pick.JobId), 1, 8)) .. "..."
        ServerStatus.TextColor3 = Color3.fromRGB(255, 200, 50)

        task.spawn(function()
            local ok, err = pcall(function()
                if IntroLoad and pick.Object and pick.Object.Parent then
                    IntroLoad:FireServer("RequestJoinServer", pick.Object)
                else
                    TeleportService:TeleportToPlaceInstance(PlaceId, pick.JobId, LocalPlayer)
                end
            end)

            if not ok then
                ServerStatus.Text = "Join failed"
                ServerStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
                task.wait(1.5)
            end

            busy = false
            btn.Active = true
        end)
    end)
end

local function LoadServerRegions()
    if not ServersList then
        ServerStatus.Text = "❌ Servers_List not found"
        return
    end
    
    for _, child in ipairs(ServerScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local regions = {}
    for _, server in ipairs(ServersList:GetChildren()) do
        if server:IsA("Folder") or server:IsA("Configuration") then
            local isValid, jobId = IsValidServer(server)
            if isValid then
                local regionName = server:FindFirstChild("Region").Value
                if not regions[regionName] then regions[regionName] = {} end
                table.insert(regions[regionName], {Object = server, JobId = jobId})
            end
        end
    end
    
    if next(regions) == nil then
        ServerStatus.Text = "⚠️ Click 'Servers' in main menu first"
        return
    end
    
    for regionName, servers in pairs(regions) do
        CreateRegionButton(regionName, servers, ServerScroll)
    end
    
    ServerScroll.CanvasSize = UDim2.new(0, 0, 0, ServerListLayout.AbsoluteContentSize.Y + 10)
    ServerStatus.Text = "✅ Loaded 6 regions"
    ServerStatus.TextColor3 = Color3.fromRGB(150, 255, 150)
end

task.spawn(function()
    task.wait(0.5)
    pcall(LoadServerRegions)
end)

local LootSection = Instance.new("Frame")
LootSection.Size = UDim2.new(1, 0, 0, 140)
LootSection.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
LootSection.BorderSizePixel = 0
LootSection.Parent = Scroll
Instance.new("UICorner", LootSection).CornerRadius = UDim.new(0, 8)

local LootHeader = Instance.new("TextLabel")
LootHeader.Size = UDim2.new(1, -10, 0, 25)
LootHeader.Position = UDim2.new(0, 5, 0, 5)
LootHeader.BackgroundTransparency = 1
LootHeader.Text = "💰 Auto Loot"
LootHeader.TextColor3 = Color3.new(1, 1, 1)
LootHeader.Font = Enum.Font.GothamBold
LootHeader.TextSize = 16
LootHeader.TextXAlignment = Enum.TextXAlignment.Left
LootHeader.TextYAlignment = Enum.TextYAlignment.Center
LootHeader.Parent = LootSection

local LootToggle = Instance.new("TextButton")
LootToggle.Size = UDim2.new(1, -20, 0, 36)
LootToggle.Position = UDim2.new(0, 10, 0, 35)
LootToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
LootToggle.Text = "START LOOTING"
LootToggle.TextColor3 = Color3.new(1, 1, 1)
LootToggle.Font = Enum.Font.GothamBold
LootToggle.TextSize = 16
LootToggle.TextXAlignment = Enum.TextXAlignment.Center
LootToggle.TextYAlignment = Enum.TextYAlignment.Center
LootToggle.Parent = LootSection
Instance.new("UICorner", LootToggle).CornerRadius = UDim.new(0, 8)

local LootCounter = Instance.new("TextLabel")
LootCounter.Size = UDim2.new(1, -20, 0, 24)
LootCounter.Position = UDim2.new(0, 10, 0, 80)
LootCounter.BackgroundTransparency = 1
LootCounter.Text = "Collected: 0/30"
LootCounter.TextColor3 = Color3.fromRGB(200, 200, 200)
LootCounter.Font = Enum.Font.Gotham
LootCounter.TextSize = 14
LootCounter.TextXAlignment = Enum.TextXAlignment.Left
LootCounter.TextYAlignment = Enum.TextYAlignment.Center
LootCounter.Parent = LootSection

local player = LocalPlayer
local isLooting = false
local collectedCount = 0
local hasCompleted = false
local LearnCraftDealerEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("LearnCraftDealerEvent")
local LockerEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("LockerEvent")

local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(char)
    character = char
    humanoidRootPart = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
end)

local function storeWeapon()
    local weapon = player.Backpack:FindFirstChild("Trench Sweeper")
    if not weapon then return end
    humanoid:EquipTool(weapon)
    task.wait(0.1)
    weapon = character:FindFirstChild("Trench Sweeper")
    local nearestLocker, nearestDist = nil, math.huge
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Locker" and obj:IsA("Model") then
            local lockerHrp = obj:FindFirstChild("HumanoidRootPart")
            if lockerHrp then
                local dist = (humanoidRootPart.Position - lockerHrp.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestLocker = obj
                end
            end
        end
    end
    if nearestLocker then
        LockerEvent:FireServer("LockerStore", weapon, nearestLocker)
    end
end

local function deliverBatch()
    humanoidRootPart.CFrame = CFrame.new(1092, 8, -95)
    camera.CameraType = Enum.CameraType.Custom
    task.wait(0.2)
    isLooting = false
    hasCompleted = true
    collectedCount = 0
    LootCounter.Text = "Complete! Reset to use again"
    LootToggle.Text = "Reset to use again!"
    LootToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    camera.CameraType = Enum.CameraType.Custom
end

local function lootLoop()
    while isLooting do
        local spawnsFolder = workspace:FindFirstChild("SpawnsLoot")
        if not spawnsFolder then task.wait() continue end
        for _, spawnFolder in ipairs(spawnsFolder:GetChildren()) do
            if not isLooting then break end
            local part = spawnFolder:FindFirstChild("Part")
            if not part then continue end
            local attachment = part:FindFirstChild("Attachment")
            if not attachment then continue end
            local prompt = attachment:FindFirstChild("ProximityPrompt")
            if not prompt then continue end
            if not prompt.Enabled then continue end
            humanoidRootPart.CFrame = CFrame.new(part.Position)
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = CFrame.new(part.Position + Vector3.new(0, 4, 0), part.Position)
            while isLooting and prompt.Enabled do
                prompt:InputHoldBegin()
                prompt:InputHoldEnd()
                task.wait()
            end
            if not isLooting then break end
            collectedCount = collectedCount + 1
            LootCounter.Text = "Collected: " .. collectedCount .. "/30"
            if collectedCount >= 30 then
                deliverBatch()
                return
            end
        end
        task.wait()
    end
    camera.CameraType = Enum.CameraType.Custom
end

LootToggle.MouseButton1Click:Connect(function()
    local text = LootToggle.Text
    if text == "Reset to use again!" then
        hasCompleted = false
        collectedCount = 0
        isLooting = false
        LootCounter.Text = "Collected: 0/30"
        LootToggle.Text = "START LOOTING"
        LootToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        return
    end
    if text == "START LOOTING" then
        if hasCompleted then return end
        isLooting = true
        LootToggle.Text = "STOP"
        LootToggle.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        task.spawn(lootLoop)
    elseif text == "STOP" then
        isLooting = false
        if not hasCompleted then
            LootToggle.Text = "START LOOTING"
            LootToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        end
        camera.CameraType = Enum.CameraType.Custom
    end
end)

local VanSection = Instance.new("Frame")
VanSection.Size = UDim2.new(1, 0, 0, 100)
VanSection.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
VanSection.BorderSizePixel = 0
VanSection.Parent = Scroll
Instance.new("UICorner", VanSection).CornerRadius = UDim.new(0, 8)

local VanHeader = Instance.new("TextLabel")
VanHeader.Size = UDim2.new(1, -10, 0, 25)
VanHeader.Position = UDim2.new(0, 5, 0, 5)
VanHeader.BackgroundTransparency = 1
VanHeader.Text = "🚐 Van Invis"
VanHeader.TextColor3 = Color3.new(1, 1, 1)
VanHeader.Font = Enum.Font.GothamBold
VanHeader.TextSize = 16
VanHeader.TextXAlignment = Enum.TextXAlignment.Left
VanHeader.TextYAlignment = Enum.TextYAlignment.Center
VanHeader.Parent = VanSection

local VanStatus = Instance.new("TextLabel")
VanStatus.Size = UDim2.new(1, -20, 0, 18)
VanStatus.Position = UDim2.new(0, 10, 0, 60)
VanStatus.BackgroundTransparency = 1
VanStatus.Text = "Ready"
VanStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
VanStatus.Font = Enum.Font.Gotham
VanStatus.TextSize = 12
VanStatus.TextXAlignment = Enum.TextXAlignment.Left
VanStatus.TextYAlignment = Enum.TextYAlignment.Center
VanStatus.Parent = VanSection

local VanButton = Instance.new("TextButton")
VanButton.Size = UDim2.new(1, -20, 0, 34)
VanButton.Position = UDim2.new(0, 10, 0, 30)
VanButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
VanButton.Text = "SPAWN VAN"
VanButton.TextColor3 = Color3.new(1, 1, 1)
VanButton.Font = Enum.Font.GothamBold
VanButton.TextSize = 16
VanButton.TextXAlignment = Enum.TextXAlignment.Center
VanButton.TextYAlignment = Enum.TextYAlignment.Center
VanButton.Parent = VanSection
Instance.new("UICorner", VanButton).CornerRadius = UDim.new(0, 8)

VanButton.MouseButton1Click:Connect(function()
    VanButton.Text = "Spawning..."
    VanButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
    VanStatus.Text = "Working..."
    task.spawn(function()
        local playerPos = humanoidRootPart and humanoidRootPart.Position or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position) or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.p) or Vector3.new(0,0,0)
        local vehicle = workspace.Vehicles:FindFirstChild(LocalPlayer.Name)
        if vehicle then
            local base = vehicle:FindFirstChild("Base")
            if base then
                for _, child in ipairs(base:GetChildren()) do
                    if child.Name == "Right" then
                        local attach = child:FindFirstChild("Attachment")
                        if attach then
                            local prompt = attach:FindFirstChild("ProximityPrompt")
                            if prompt then
                                prompt.HoldDuration = 0
                                fireproximityprompt(prompt)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
        local closestButton, closestDist = nil, math.huge
        local ignoreFolder = workspace:FindFirstChild("Ignore")
        if ignoreFolder then
            for _, obj in ipairs(ignoreFolder:GetChildren()) do
                if obj.Name == "VehicleSpawnButton" then
                    local pos = obj:IsA("BasePart") and obj.Position or (obj:IsA("Model") and obj:GetPivot().Position)
                    if pos then
                        local dist = (pos - playerPos).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closestButton = obj
                        end
                    end
                end
            end
        end
        if closestButton then
            local WeaponEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("WeaponEvent")
            WeaponEvent:FireServer("SpawnVehicle", "Van", closestButton, Color3.fromRGB(255, 255, 255))
            VanButton.Text = "SPAWNED!"
            VanButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            VanStatus.Text = "Van spawned!"
            task.wait(2)
            VanButton.Text = "SPAWN VAN"
            VanButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
            VanStatus.Text = "Ready"
        else
            VanButton.Text = "NO SPAWNER!"
            VanButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            VanStatus.Text = "No spawn point found"
            task.wait(2)
            VanButton.Text = "SPAWN VAN"
            VanButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
            VanStatus.Text = "Ready"
        end
    end)
end)

ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Scroll.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 20)
end)
