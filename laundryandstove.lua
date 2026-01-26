local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

local task_wait = task.wait
local math_abs = math.abs

local WHOLE_MAP = workspace.WholeMap
local LAUNDRY_PATH = WHOLE_MAP.Laundry.Model.Model.Model
local STOVE_PATH = workspace.Jobs.Stoves
local GRAFFITI_PATH = WHOLE_MAP.Extra_Graffitis_And_Dirt
local FLOOR_PATH = WHOLE_MAP.MAP_Floor.Model.Model.Model.Model.Model.Model.Model

local SETTINGS = {
    FLOOR_Y_TARGET = 122,
    PROMPT_MAX_DIST = 6.5,
    STOVE_PROMPT_MAX_DIST = 4,
    DOOR_OFFSET = Vector3.new(0, -5.5, 0),
    CAMERA_HEIGHT_ABOVE_PROMPT = 5,
    STOVE_CAMERA_HEIGHT = 2,
    LAUDRY_TOTAL_TIME = 2.5,
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
local MIDDLE_TELEPORT_POS = nil
local MIDDLE_CAMERA_POS = nil
local MIDDLE_CAMERA_LOOKAT = nil
local middlePlatform = nil
local originalCameraType = camera.CameraType
local isRunning = false
local currentLaundryIndex = 1

local cameraTargetCFrame = nil
local cameraConnection = nil
local lastCameraTarget = nil

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
        if humanoidRootPart and humanoidRootPart.Parent then
            humanoidRootPart.CFrame = CFrame.new(SETTINGS.LAUNDRY_TELEPORT_POS)
        end
    end)

    return button
end

local function findFloor()
    local targetSize = Vector3.new(136.029, 0.849987, 217.418)
    for i = 1, #FLOOR_PATH:GetChildren() do
        local child = FLOOR_PATH:GetChildren()[i]
        if child and child:IsA("BasePart") then
            local size = child.Size
            if math_abs(size.X - targetSize.X) <= 2 and
               math_abs(size.Y - targetSize.Y) <= 0.1 and
               math_abs(size.Z - targetSize.Z) <= 2 then
                return child
            end
        end
    end
    return nil
end

local function findLaundry()
    local targetSize = Vector3.new(62.3, 0.15, 34.8)
    for i = 1, #LAUNDRY_PATH:GetChildren() do
        local child = LAUNDRY_PATH:GetChildren()[i]
        if child and child:IsA("BasePart") then
            local size = child.Size
            if math_abs(size.X - targetSize.X) <= 0.5 and
               math_abs(size.Y - targetSize.Y) <= 0.01 and
               math_abs(size.Z - targetSize.Z) <= 0.5 then
                return child
            end
        end
    end
    return nil
end

local function startCameraUpdates()
    if cameraConnection then return end
    cameraConnection = RunService.RenderStepped:Connect(function()
        if cameraTargetCFrame and isRunning then
            if lastCameraTarget ~= cameraTargetCFrame then
                camera.CFrame = cameraTargetCFrame
                lastCameraTarget = cameraTargetCFrame
            end
        end
    end)
end

local function stopCameraUpdates()
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
    cameraTargetCFrame = nil
    lastCameraTarget = nil
end

local function initialize()
    local stovePos = nil

    local graffitiList = GRAFFITI_PATH:GetChildren()
    local graffiti = graffitiList[3]
    if graffiti then
        local gChildren = graffiti:GetChildren()
        local toRemove = gChildren[25]
        if toRemove then
            toRemove:Destroy()
        end
    end

    local laundry = findLaundry()
    if laundry then laundry:Destroy() end

    local floor = findFloor()
    if floor then
        local pos = floor.Position
        floor.Position = Vector3.new(pos.X, SETTINGS.FLOOR_Y_TARGET, pos.Z)
    end

    local stoveChildren = STOVE_PATH:GetChildren()
    local stoveModel = stoveChildren[1]
    if stoveModel and stoveModel:FindFirstChild("MainPart") then
        local prompt = stoveModel.MainPart:FindFirstChild("ProximityPrompt")
        if prompt then
            stoveData.prompt = prompt
            prompt.HoldDuration = 0
            prompt.MaxActivationDistance = SETTINGS.STOVE_PROMPT_MAX_DIST

            stovePos = prompt.Parent.Position
            stoveData.teleportPos = stovePos
            stoveData.teleportCFrame = CFrame.new(stovePos)
            stoveData.cameraPos = stovePos + STOVE_CAM_OFFSET
            stoveData.cameraCFrame = CFrame.new(stoveData.cameraPos, stovePos)
            stoveData.cameraLookAt = stovePos
        end
    end

    local wmChildren = LAUNDRY_PATH:GetChildren()
    local count = 0
    for i = 1, #wmChildren do
        local child = wmChildren[i]
        if child and child.Name == "WashingMachine" then
            local part = child:FindFirstChild("Part")
            if part then
                local attachment = part:FindFirstChild("Attachment")
                if attachment then
                    local prompt = attachment:FindFirstChild("ProximityPrompt")
                    if prompt then
                        prompt.MaxActivationDistance = SETTINGS.PROMPT_MAX_DIST
                        prompt.HoldDuration = 0

                        local door = child:FindFirstChild("Door")
                        local doorPos = door and door.CFrame and door.CFrame.Position
                        local promptPos = prompt.Parent.WorldPosition

                        if doorPos then
                            count = count + 1
                            local teleportPos = doorPos + SETTINGS.DOOR_OFFSET
                            local cameraPos = promptPos + LAUNDRY_CAM_OFFSET
                            washingMachines[count] = {
                                prompt = prompt,
                                teleportPos = teleportPos,
                                teleportCFrame = CFrame.new(teleportPos),
                                cameraPos = cameraPos,
                                cameraCFrame = CFrame.new(cameraPos, promptPos),
                                cameraLookAt = promptPos
                            }
                        end
                    end
                end
            end
        end
    end

    if stovePos and #washingMachines > 0 then
        local middlePos = Vector3.new(stovePos.X, stovePos.Y - SETTINGS.MIDDLE_PLATFORM_OFFSET, stovePos.Z)
        MIDDLE_TELEPORT_POS = middlePos
        MIDDLE_CAMERA_POS = middlePos + LAUNDRY_CAM_OFFSET
        MIDDLE_CAMERA_LOOKAT = middlePos

        local platform = Instance.new("Part")
        platform.Anchored = true
        platform.Size = Vector3.new(50, 6, 50)
        platform.Transparency = 1
        platform.CanCollide = true
        platform.CFrame = CFrame.new(middlePos.X, middlePos.Y - 3, middlePos.Z)
        platform.Parent = workspace
        middlePlatform = platform

        task_wait(0.05)
    end
end

local function continuousSpam(prompt, totalTime)
    if totalTime <= 0 or SETTINGS.ACTIVATION_DELAY <= 0 then return end

    local iterations = math.ceil(totalTime / SETTINGS.ACTIVATION_DELAY)
    local inputHoldBegin = prompt and prompt.InputHoldBegin
    local inputHoldEnd = prompt and prompt.InputHoldEnd

    for _ = 1, iterations do
        if not isRunning then break end

        if prompt and prompt.Parent and prompt.Enabled and inputHoldBegin and inputHoldEnd then
            inputHoldBegin(prompt)
            inputHoldEnd(prompt)
        else
            break
        end
        task_wait(SETTINGS.ACTIVATION_DELAY)
    end
end

local function teleportToMachine(machine, useMiddle)
    if not machine or not machine.teleportCFrame then return end

    if not (humanoidRootPart and humanoidRootPart.Parent) then
        character = player.Character
        if character then
            humanoidRootPart = character:WaitForChild("HumanoidRootPart", 2)
        end
        if not humanoidRootPart then return end
    end

    if useMiddle and MIDDLE_TELEPORT_POS then
        humanoidRootPart.CFrame = CFrame.new(MIDDLE_TELEPORT_POS)
        cameraTargetCFrame = CFrame.new(MIDDLE_CAMERA_POS, MIDDLE_CAMERA_LOOKAT)
        task_wait(SETTINGS.MIDDLE_STOP_WAIT)
    end

    humanoidRootPart.CFrame = machine.teleportCFrame
    cameraTargetCFrame = machine.cameraCFrame

    task_wait(0.03)
end

local function processStove(useMiddle)
    if not stoveData.prompt or not stoveData.teleportCFrame or not stoveData.cameraCFrame then return end
    if not (humanoidRootPart and humanoidRootPart.Parent) then return end

    if useMiddle and MIDDLE_TELEPORT_POS then
        humanoidRootPart.CFrame = CFrame.new(MIDDLE_TELEPORT_POS)
        cameraTargetCFrame = CFrame.new(MIDDLE_CAMERA_POS, MIDDLE_CAMERA_LOOKAT)
        task_wait(SETTINGS.MIDDLE_STOP_WAIT)
    end

    humanoidRootPart.CFrame = stoveData.teleportCFrame
    task_wait(SETTINGS.STOVE_PRE_CAMERA_WAIT)
    cameraTargetCFrame = stoveData.cameraCFrame
    task_wait(SETTINGS.STOVE_PRE_SPAM_WAIT)

    continuousSpam(stoveData.prompt, SETTINGS.STOVE_TOTAL_TIME)
end

local function mainLoop()
    local machineCount = #washingMachines
    if machineCount == 0 then return end

    camera.CameraType = Enum.CameraType.Scriptable
    startCameraUpdates()
    local lastWasStove = true
    local idx = currentLaundryIndex

    while isRunning do
        for _ = 1, 2 do
            if not isRunning then break end

            local machine = washingMachines[idx]
            if machine then
                teleportToMachine(machine, lastWasStove)
                lastWasStove = false
                if not isRunning then break end
                continuousSpam(machine.prompt, SETTINGS.LAUDRY_TOTAL_TIME)
            end

            idx = idx + 1
            if idx > machineCount then idx = 1 end
        end

        currentLaundryIndex = idx

        if isRunning then
            processStove(true)
            lastWasStove = true
            task_wait(0.1)
        end
    end

    stopCameraUpdates()
    camera.CameraType = originalCameraType
end

player.CharacterRemoving:Connect(function()
    isRunning = false
    stopCameraUpdates()
    if camera then
        camera.CameraType = originalCameraType
    end
    if middlePlatform and middlePlatform.Parent then
        middlePlatform:Destroy()
        middlePlatform = nil
    end
end)

initialize()

local button = createGUI()
button.MouseButton1Click:Connect(function()
    isRunning = not isRunning
    button.Text = isRunning and "Stop" or "Start"
    button.BackgroundColor3 = isRunning and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)

    if isRunning then
        currentLaundryIndex = 1
        task.spawn(mainLoop)
    else
        stopCameraUpdates()
        camera.CameraType = originalCameraType
        if middlePlatform and middlePlatform.Parent then
            middlePlatform:Destroy()
            middlePlatform = nil
        end
    end
end)
