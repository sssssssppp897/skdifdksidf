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
    LAUNDRY_TOTAL_TIME = 2.5,
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
local stoveData = nil
local MIDDLE_TELEPORT_POS, MIDDLE_CAMERA_POS, MIDDLE_CAMERA_LOOKAT, middlePlatform
local originalCameraType = camera.CameraType
local isRunning = false
local currentLaundryIndex = 1

local cameraTargetCFrame = nil
local cameraConnection

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

local function findBySize(container, targetSize, tol)
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("BasePart") then
            local s = child.Size
            if math_abs(s.X - targetSize.X) <= (tol.X or 0)
            and math_abs(s.Y - targetSize.Y) <= (tol.Y or 0)
            and math_abs(s.Z - targetSize.Z) <= (tol.Z or 0) then
                return child
            end
        end
    end
end

local function startCameraUpdates()
    if cameraConnection then return end
    local last = nil
    cameraConnection = RunService.RenderStepped:Connect(function()
        if cameraTargetCFrame then
            if last ~= cameraTargetCFrame then
                camera.CFrame = cameraTargetCFrame
                last = cameraTargetCFrame
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
end

local function initialize()
    local g = GRAFFITI_PATH:GetChildren()[3]
    if g then
        local toRemove = g:GetChildren()[25]
        if toRemove then toRemove:Destroy() end
    end

    local laundryPart = findBySize(LAUNDRY_PATH, Vector3.new(62.3, 0.15, 34.8), {X=0.5, Y=0.01, Z=0.5})
    if laundryPart then
        laundryPart:Destroy()
    end

    local floor = findBySize(FLOOR_PATH, Vector3.new(136.029, 0.849987, 217.418), {X=2, Y=0.1, Z=2})
    if floor then
        local p = floor.Position
        floor.Position = Vector3.new(p.X, SETTINGS.FLOOR_Y_TARGET, p.Z)
    end

    local stoveModel = STOVE_PATH:GetChildren()[1]
    if stoveModel and stoveModel:FindFirstChild("MainPart") then
        local prompt = stoveModel.MainPart:FindFirstChild("ProximityPrompt")
        if prompt then
            prompt.HoldDuration = 0
            prompt.MaxActivationDistance = SETTINGS.STOVE_PROMPT_MAX_DIST
            local pos = prompt.Parent.Position
            stoveData = {
                prompt = prompt,
                teleportCFrame = CFrame.new(pos),
                cameraCFrame = CFrame.new(pos + STOVE_CAM_OFFSET, pos),
                cameraLookAt = pos
            }
        end
    end

    for _, child in ipairs(LAUNDRY_PATH:GetChildren()) do
        if child.Name == "WashingMachine" then
            local part = child:FindFirstChild("Part")
            local door = child:FindFirstChild("Door")
            if part and door then
                local attach = part:FindFirstChild("Attachment")
                local prompt = attach and attach:FindFirstChild("ProximityPrompt")
                if prompt then
                    prompt.MaxActivationDistance = SETTINGS.PROMPT_MAX_DIST
                    prompt.HoldDuration = 0
                    local doorPos = door.CFrame.Position
                    local promptPos = prompt.Parent.WorldPosition
                    local teleportPos = doorPos + SETTINGS.DOOR_OFFSET
                    table.insert(washingMachines, {
                        prompt = prompt,
                        teleportCFrame = CFrame.new(teleportPos),
                        cameraCFrame = CFrame.new(promptPos + LAUNDRY_CAM_OFFSET, promptPos),
                    })
                end
            end
        end
    end

    if stoveData and #washingMachines > 0 then
        local sPos = stoveData.teleportCFrame.Position
        local middlePos = Vector3.new(sPos.X, sPos.Y - SETTINGS.MIDDLE_PLATFORM_OFFSET, sPos.Z)
        MIDDLE_TELEPORT_POS = middlePos
        MIDDLE_CAMERA_POS = middlePos + LAUNDRY_CAM_OFFSET
        MIDDLE_CAMERA_LOOKAT = middlePos

        middlePlatform = Instance.new("Part")
        middlePlatform.Anchored = true
        middlePlatform.Size = Vector3.new(50, 6, 50)
        middlePlatform.Transparency = 1
        middlePlatform.CanCollide = true
        middlePlatform.CFrame = CFrame.new(middlePos.X, middlePos.Y - 3, middlePos.Z)
        middlePlatform.Parent = workspace
    end
end

local function continuousSpam(prompt, totalTime)
    if totalTime <= 0 then return end
    local iterations = math.ceil(totalTime / SETTINGS.ACTIVATION_DELAY)
    local begin = prompt.InputHoldBegin
    local finish = prompt.InputHoldEnd
    for i = 1, iterations do
        if not isRunning then break end
        if begin and finish then
            begin(prompt)
            finish(prompt)
        else
            break
        end
        task_wait(SETTINGS.ACTIVATION_DELAY)
    end
end

local function teleportToMachine(machine, useMiddle)
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
    if not stoveData then return end
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
                continuousSpam(machine.prompt, SETTINGS.LAUNDRY_TOTAL_TIME)
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

local function stopAll()
    isRunning = false
    stopCameraUpdates()
    camera.CameraType = originalCameraType
    if middlePlatform and middlePlatform.Parent then
        middlePlatform:Destroy()
        middlePlatform = nil
    end
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
    else
        stopAll()
    end
end)

