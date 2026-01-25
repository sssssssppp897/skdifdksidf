-- Pre-calculates ALL static positions
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

-- Path caching
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
    LAUDRY_TOTAL_TIME = 2.5,
    STOVE_TOTAL_TIME = 0.1,
    ACTIVATION_DELAY = 0.01,
    LAUNDRY_TELEPORT_POS = Vector3.new(506, 130, -446)
}

-- Pre-calculate reusable Vector3s
local STOVE_CAM_OFFSET = Vector3.new(0, SETTINGS.STOVE_CAMERA_HEIGHT, 0)
local LAUNDRY_CAM_OFFSET = Vector3.new(0, SETTINGS.CAMERA_HEIGHT_ABOVE_PROMPT, 0)

local washingMachines = {}
local stoveData = { prompt = nil, teleportPos = nil, cameraPos = nil }
local originalCameraType = camera.CameraType
local isRunning = false
local currentLaundryIndex = 1

local task_wait = task.wait
local task_spawn = task.spawn
local math_abs = math.abs
local os_clock = os.clock
local CFrame_new = CFrame.new
local Vector3_new = Vector3.new

-- Minimal safeDestroy
local function safeDestroy(obj)
    if obj then pcall(obj.Destroy, obj) end
end

-- GUI creation
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
        humanoidRootPart.CFrame = CFrame_new(SETTINGS.LAUNDRY_TELEPORT_POS)
    end)

    return button
end

-- Optimized find functions
local function findFloor()
    local targetSize = Vector3_new(136.029, 0.849987, 217.418)
    local tolX, tolY, tolZ = 2, 0.1, 2

    for _, child in FLOOR_PATH:GetChildren() do
        if child:IsA("BasePart") then
            local size = child.Size
            if math_abs(size.X - targetSize.X) <= tolX and
               math_abs(size.Y - targetSize.Y) <= tolY and
               math_abs(size.Z - targetSize.Z) <= tolZ then
                return child
            end
        end
    end
end

local function findLaundry()
    local targetSize = Vector3_new(62.29999542236328, 0.15000000596046448, 34.79999923706055)
    local tolX, tolY, tolZ = 0.5, 0.01, 0.5

    for _, child in LAUNDRY_PATH:GetChildren() do
        if child:IsA("BasePart") then
            local size = child.Size
            if math_abs(size.X - targetSize.X) <= tolX and
               math_abs(size.Y - targetSize.Y) <= tolY and
               math_abs(size.Z - targetSize.Z) <= tolZ then
                return child
            end
        end
    end
end

-- Initialize and cache EVERYTHING
local function initialize()
    -- Single pcall for all risky ops
    pcall(function()
        -- Remove graffiti
        local graffiti = GRAFFITI_PATH:GetChildren()[3]:GetChildren()[25]
        if graffiti then graffiti:Destroy() end

        -- Remove laundry
        safeDestroy(findLaundry())

        -- Adjust floor
        local floor = findFloor()
        if floor then
            local pos = floor.Position
            floor.Position = Vector3_new(pos.X, SETTINGS.FLOOR_Y_TARGET, pos.Z)
        end

        -- Setup stove (positions cached!)
        local stoveModel = STOVE_PATH:GetChildren()[2]
        if stoveModel and stoveModel:FindFirstChild("MainPart") then
            local prompt = stoveModel.MainPart:FindFirstChild("ProximityPrompt")
            if prompt then
                stoveData.prompt = prompt
                prompt.HoldDuration = 0
                prompt.MaxActivationDistance = SETTINGS.STOVE_PROMPT_MAX_DIST
                
                local promptPos = prompt.Parent.Position
                stoveData.teleportPos = CFrame_new(promptPos)
                stoveData.cameraPos = CFrame_new(promptPos + STOVE_CAM_OFFSET, promptPos)
            end
        end
    end)

    -- Cache ALL washing machine data including pre-calculated CFrames
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
                        
                        count += 1
                        washingMachines[count] = {
                            prompt = prompt,
                            -- Pre-calculated CFrames - ZERO calculation during loop!
                            teleportCFrame = doorPos and CFrame_new(doorPos + SETTINGS.DOOR_OFFSET),
                            cameraCFrame = CFrame_new(promptPos + LAUNDRY_CAM_OFFSET, promptPos)
                        }
                    end
                end
            end
        end
    end
end

-- Optimized spam
local function continuousSpam(prompt, totalTime)
    local startTime = os_clock()
    local inputHoldBegin = prompt.InputHoldBegin
    local inputHoldEnd = prompt.InputHoldEnd
    
    while os_clock() - startTime < totalTime do
        if prompt.Enabled then
            inputHoldBegin(prompt)
            inputHoldEnd(prompt)
        end
        task_wait(SETTINGS.ACTIVATION_DELAY)
    end
end

-- Teleport functions now just assign pre-calculated CFrames
local function teleportToMachine(machine)
    if machine.teleportCFrame then
        humanoidRootPart.CFrame = machine.teleportCFrame
    end
    camera.CFrame = machine.cameraCFrame
end

local function processStove()
    local data = stoveData
    if not data.prompt then return end
    
    humanoidRootPart.CFrame = data.teleportPos
    task_wait(0.1)
    camera.CFrame = data.cameraPos
    task_wait(0.1)
    
    continuousSpam(data.prompt, SETTINGS.STOVE_TOTAL_TIME)
end

-- Main loop is pure action, zero calculations
local function mainLoop()
    if #washingMachines == 0 then return end
    
    camera.CameraType = Enum.CameraType.Scriptable
    
    while isRunning do
        -- Process 2 machines
        local idx = currentLaundryIndex
        for i = 1, 2 do
            local machine = washingMachines[idx]
            if machine then teleportToMachine(machine) end
            continuousSpam(machine.prompt, SETTINGS.LAUDRY_TOTAL_TIME)
            
            idx += 1
            if idx > #washingMachines then idx = 1 end
        end
        currentLaundryIndex = idx

        processStove()
        task_wait(0.1)
    end
    
    camera.CameraType = originalCameraType
end

-- Initialize and start
initialize()
if #washingMachines == 0 then warn("No washing machines found!") end

local button = createGUI()
button.MouseButton1Click:Connect(function()
    isRunning = not isRunning
    button.Text = isRunning and "Stop" or "Start"
    button.BackgroundColor3 = isRunning and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
    
    if isRunning then
        currentLaundryIndex = 1
        task_spawn(mainLoop)
    end

end)
