local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

-- Paths
local WHOLE_MAP = workspace.WholeMap
local LAUNDRY_PATH = WHOLE_MAP.Laundry.Model.Model.Model
local STOVE_PATH = workspace.Jobs.Stoves
local GRAFFITI_PATH = WHOLE_MAP.Extra_Graffitis_And_Dirt
local FLOOR_PATH = WHOLE_MAP.MAP_Floor.Model.Model.Model.Model.Model.Model.Model

local SETTINGS = {
    FLOOR_Y_TARGET = 122,
    PROMPT_MAX_DIST = 6.5,
    STOVE_PROMPT_MAX_DIST = 4,
    DOOR_OFFSET = Vector3.new(0, -6.5, 0),
    CAMERA_HEIGHT_ABOVE_PROMPT = 5,
    STOVE_CAMERA_HEIGHT = 2,
    LAUDRY_TOTAL_TIME = 2.7,
    STOVE_TOTAL_TIME = 0.01,
    ACTIVATION_DELAY = 0.01,
    LAUNDRY_TELEPORT_POS = Vector3.new(506, 130, -446),
    MIDDLE_STOP_WAIT = 0.1,     
    STOVE_PRE_CAMERA_WAIT = 0.1,   
    STOVE_PRE_SPAM_WAIT = 0.1,     
    MIDDLE_PLATFORM_OFFSET = 500
}

local STOVE_CAM_OFFSET = Vector3.new(0, SETTINGS.STOVE_CAMERA_HEIGHT, 0)
local LAUNDRY_CAM_OFFSET = Vector3.new(0, SETTINGS.CAMERA_HEIGHT_ABOVE_PROMPT, 0)

local washingMachines = {}
local stoveData = {}
local MIDDLE_TELEPORT_CFRAME = nil
local MIDDLE_CAMERA_CFRAME = nil
local middlePlatform = nil
local originalCameraType = camera.CameraType
local isRunning = false
local currentLaundryIndex = 1

-- GUI
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WashingMachineGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(120, 50)
    button.Position = UDim2.fromOffset(10, 10)
    button.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    button.Text = "Start"
    button.TextColor3 = Color3.fromRGB(0, 0, 0)
    button.TextSize = 18
    button.Font = Enum.Font.SourceSansBold
    button.Parent = screenGui

    local laundryButton = Instance.new("TextButton")
    laundryButton.Size = UDim2.fromOffset(120, 50)
    laundryButton.Position = UDim2.fromOffset(10, 70)
    laundryButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    laundryButton.Text = "Go to laundry"
    laundryButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    laundryButton.TextSize = 18
    laundryButton.Font = Enum.Font.SourceSansBold
    laundryButton.Parent = screenGui
    
    laundryButton.MouseButton1Click:Connect(function()
        humanoidRootPart.CFrame = CFrame.new(SETTINGS.LAUNDRY_TELEPORT_POS)
    end)

    return button
end

local function findFloor()
    local targetSize = Vector3.new(136.029, 0.849987, 217.418)
    for _, child in FLOOR_PATH:GetChildren() do
        if child:IsA("BasePart") then
            local size = child.Size
            if math.abs(size.X - targetSize.X) <= 2 and
               math.abs(size.Y - targetSize.Y) <= 0.1 and
               math.abs(size.Z - targetSize.Z) <= 2 then
                return child
            end
        end
    end
end

local function findLaundry()
    local targetSize = Vector3.new(62.3, 0.15, 34.8)
    for _, child in LAUNDRY_PATH:GetChildren() do
        if child:IsA("BasePart") then
            local size = child.Size
            if math.abs(size.X - targetSize.X) <= 0.5 and
               math.abs(size.Y - targetSize.Y) <= 0.01 and
               math.abs(size.Z - targetSize.Z) <= 0.5 then
                return child
            end
        end
    end
end

local function initialize()
    local stovePos = nil
    
    pcall(function()
        local graffiti = GRAFFITI_PATH:GetChildren()[3]:GetChildren()[25]
        if graffiti then graffiti:Destroy() end

        local laundry = findLaundry()
        if laundry then laundry:Destroy() end

        local floor = findFloor()
        if floor then
            local pos = floor.Position
            floor.Position = Vector3.new(pos.X, SETTINGS.FLOOR_Y_TARGET, pos.Z)
        end

        local stoveModel = STOVE_PATH:GetChildren()[1]
        if stoveModel and stoveModel:FindFirstChild("MainPart") then
            local prompt = stoveModel.MainPart:FindFirstChild("ProximityPrompt")
            if prompt then
                stoveData.prompt = prompt
                prompt.HoldDuration = 0
                prompt.MaxActivationDistance = SETTINGS.STOVE_PROMPT_MAX_DIST
                
                stovePos = prompt.Parent.Position
                stoveData.teleportPos = CFrame.new(stovePos)
                stoveData.cameraPos = CFrame.new(stovePos + STOVE_CAM_OFFSET, stovePos)
            end
        end
    end)

    local count = 0
    local wmChildren = LAUNDRY_PATH:GetChildren()
    
    for i = 1, #wmChildren do
        local child = wmChildren[i]
        if child.Name == "WashingMachine" then
            local part = child:FindFirstChild("Part")
            if part then
                local attachment = part:FindFirstChild("Attachment")
                if attachment then
                    local prompt = attachment:FindFirstChild("ProximityPrompt")
                    if prompt then
                        prompt.MaxActivationDistance = SETTINGS.PROMPT_MAX_DIST
                        prompt.HoldDuration = 0
                        
                        local door = child:FindFirstChild("Door")
                        local doorPos = door and door.CFrame.Position
                        local promptPos = prompt.Parent.WorldPosition
                        
                        if doorPos then
                            count += 1
                            washingMachines[count] = {
                                prompt = prompt,
                                teleportCFrame = CFrame.new(doorPos + SETTINGS.DOOR_OFFSET),
                                cameraCFrame = CFrame.new(promptPos + LAUNDRY_CAM_OFFSET, promptPos)
                            }
                        end
                    end
                end
            end
        end
    end

    if stovePos and #washingMachines > 0 then

        local middlePos = Vector3.new(stovePos.X, stovePos.Y - SETTINGS.MIDDLE_PLATFORM_OFFSET, stovePos.Z)
        MIDDLE_TELEPORT_CFRAME = CFrame.new(middlePos)
        MIDDLE_CAMERA_CFRAME = CFrame.new(middlePos + LAUNDRY_CAM_OFFSET, middlePos)
        
        local platform = Instance.new("Part")
        platform.Anchored = true
        platform.Size = Vector3.new(50, 6, 50)
        platform.Transparency = 1
        platform.CanCollide = true

        platform.CFrame = CFrame.new(middlePos.X, middlePos.Y - 3, middlePos.Z)
        platform.Parent = workspace
        middlePlatform = platform
        
        task.wait(0.05)
    end
end

local function continuousSpam(prompt, totalTime)
    local startTime = os.clock()
    local inputHoldBegin = prompt.InputHoldBegin
    local inputHoldEnd = prompt.InputHoldEnd
    
    while os.clock() - startTime < totalTime do
        if not isRunning then break end
        if prompt.Enabled then
            inputHoldBegin(prompt)
            inputHoldEnd(prompt)
        end
        task.wait(SETTINGS.ACTIVATION_DELAY)
    end
end


local function teleportToMachine(machine, useMiddle)
    if not machine.teleportCFrame then return end
    
    if useMiddle then

        humanoidRootPart.CFrame = MIDDLE_TELEPORT_CFRAME
        camera.CFrame = MIDDLE_CAMERA_CFRAME
        task.wait(SETTINGS.MIDDLE_STOP_WAIT)
    end
    

    humanoidRootPart.CFrame = machine.teleportCFrame
    camera.CFrame = machine.cameraCFrame
    

    task.wait(0.03)
end


local function processStove(useMiddle)
    if not stoveData.prompt then return end
    
    if useMiddle then
        -- To middle platform
        humanoidRootPart.CFrame = MIDDLE_TELEPORT_CFRAME
        camera.CFrame = MIDDLE_CAMERA_CFRAME
        task.wait(SETTINGS.MIDDLE_STOP_WAIT)
    end
    

    humanoidRootPart.CFrame = stoveData.teleportPos
    task.wait(SETTINGS.STOVE_PRE_CAMERA_WAIT) 
    camera.CFrame = stoveData.cameraPos
    task.wait(SETTINGS.STOVE_PRE_SPAM_WAIT)   
    
    continuousSpam(stoveData.prompt, SETTINGS.STOVE_TOTAL_TIME)
end

local function mainLoop()
    if #washingMachines == 0 then return end
    
    camera.CameraType = Enum.CameraType.Scriptable
    local lastWasStove = true
    
    while isRunning do
        local idx = currentLaundryIndex
        
        -- Process 2 machines
        for i = 1, 2 do
            if not isRunning then break end
            
            local machine = washingMachines[idx]
            if machine then
                teleportToMachine(machine, lastWasStove)
                lastWasStove = false
                if not isRunning then break end
                continuousSpam(machine.prompt, SETTINGS.LAUDRY_TOTAL_TIME)
            end
            
            idx += 1
            if idx > #washingMachines then idx = 1 end
        end
        
        currentLaundryIndex = idx

        if isRunning then
            processStove(true)
            lastWasStove = true
            task.wait(0.1) 
        end
    end
    
    camera.CameraType = originalCameraType
end

initialize()

local button = createGUI()
button.MouseButton1Click:Connect(function()
    isRunning = not isRunning
    button.Text = isRunning and "Stop" or "Start"
    button.BackgroundColor3 = isRunning and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
    
    if isRunning then
        currentLaundryIndex = 1
        task.spawn(mainLoop)
    end
end)
