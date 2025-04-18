local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local VoiceChatService = game:GetService("VoiceChatService")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

-- Strings table for chat messages
local Strings = {
    ["Clear Chat"] = "\x08\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\x08",
    ["Swastika"] = "\x08\r\⬜⬜⬜⬜⬜⬜⬜\r⬜⬛⬜⬛⬛⬛⬜\r⬜⬛⬜⬛⬜⬜⬜\r⬜⬛⬛⬛⬛⬛⬜\r⬜⬜⬜⬛⬜⬛⬜\r⬜⬛⬛⬛⬜⬛⬜\r⬜⬜⬜⬜⬜⬜⬜",
}

-- Table to store ESP boxes, bone lines, and name labels
local espBoxes = {}
local espBones = {}
local nameLabels = {}

-- ESP control variables
local maxDistance = 500000 -- Default max distance in studs
local espEnabled = false -- ESP disabled at start
local keybind = Enum.KeyCode.Insert -- Default keybind to toggle GUI (Insert)
local isSelectingKeybind = false -- Flag to track if we're selecting a keybind

-- Speedhack control variables
local speedhackEnabled = false -- Speedhack disabled at start
local customSpeed = 60 -- Default speed
local isFlying = false -- From fly hack, to avoid conflicts

-- Fly hack variables
local flyhackEnabled = false -- Fly hack toggle (enables double-tap)
local DOUBLE_JUMP_TIME = 0.3 -- Time window for double-jump (seconds)
local SPEED_UP_KEY = Enum.KeyCode.Q -- Key to increase speed
local SPEED_DOWN_KEY = Enum.KeyCode.E -- Key to decrease speed
local FLY_SPEED = 200 -- Initial speed of flying
local MIN_FLY_SPEED = 10 -- Minimum speed
local MAX_FLY_SPEED = 1000 -- Max speed cap
local SPEED_INCREMENT = 10 -- Speed change per key press
local currentFlySpeed = FLY_SPEED
local lastJumpTime = 0
local jumpCount = 0
local stopFlyingFunc = nil

-- Timer for automatic ESP reset
local RESET_INTERVAL = 10 -- Reset every 10 seconds
local timeSinceLastReset = 0

-- Function to clear chat
local function clearChat(times)
    local r = 0
    repeat
        TextChatService.TextChannels.RBXGeneral:SendAsync(Strings["Clear Chat"])
        r = r + 1
        task.wait()
    until r == times
end

-- Function to send chat message
local function sendMessage(msg)
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        clearChat(2)
        TextChatService.TextChannels.RBXGeneral:SendAsync(msg)
    else
        StarterGui:SetCore("SendNotification", {
            Title = "Not Supported",
            Text = "This game has the legacy ROBLOX chat version. The script can only be used in the new version of the ROBLOX chat. Sorry :("
        })
    end
end

-- Function to determine if character is R6
local function isR6(character)
    return character:FindFirstChild("Torso") and not character:FindFirstChild("UpperTorso")
end

-- Function to check if a Drawing object is valid
local function isDrawingValid(drawing)
    local success, _ = pcall(function()
        return drawing.Visible ~= nil
    end)
    return success
end

-- Function to create solid box ESP, bone ESP, and name label for a player
local function createESP(player)
    if player == Players.LocalPlayer then return end -- Skip local player
    
    local fillBox = Drawing.new("Square")
    fillBox.Thickness = 1
    fillBox.Filled = true
    fillBox.Color = Color3.fromRGB(0, 0, 0)
    fillBox.Transparency = 0.5
    fillBox.Visible = false
    
    local borderBox = Drawing.new("Square")
    borderBox.Thickness = 1
    borderBox.Filled = false
    borderBox.Color = Color3.fromRGB(255, 0, 0)
    borderBox.Transparency = 0
    borderBox.Visible = false
    
    local boneLines = {
        headToChest = Drawing.new("Line"),
        chestToStomach = Drawing.new("Line"),
        stomachToLeftLeg = Drawing.new("Line"),
        stomachToRightLeg = Drawing.new("Line"),
        chestToLeftShoulder = Drawing.new("Line"),
        chestToRightShoulder = Drawing.new("Line"),
        leftShoulderToHand = Drawing.new("Line"),
        rightShoulderToHand = Drawing.new("Line")
    }
    for _, line in pairs(boneLines) do
        line.Color = Color3.fromRGB(255, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        line.Visible = false
    end
    
    local nameLabel = Drawing.new("Text")
    nameLabel.Text = player.Name
    nameLabel.Size = 14
    nameLabel.Color = Color3.fromRGB(255, 255, 255)
    nameLabel.Outline = true
    nameLabel.Transparency = 0
    nameLabel.Visible = false
    
    espBoxes[player] = {fill = fillBox, border = borderBox}
    espBones[player] = boneLines
    nameLabels[player] = nameLabel
end

-- Function to update a bone line
local function updateLine(line, fromPos, toPos)
    if not line or not isDrawingValid(line) then return end
    local success, err = pcall(function()
        local screenPosA = Camera:WorldToViewportPoint(fromPos)
        local screenPosB = Camera:WorldToViewportPoint(toPos)
        if screenPosA.Z > 0 and screenPosB.Z > 0 then
            line.From = Vector2.new(screenPosA.X, screenPosA.Y)
            line.To = Vector2.new(screenPosB.X, screenPosB.Y)
            line.Visible = true
        else
            line.Visible = false
        end
    end)
    if not success then
        line.Visible = false
    end
end

-- Function to validate and clean up broken ESP elements
local function validateESP(player)
    local boxes = espBoxes[player]
    local boneLines = espBones[player]
    local nameLabel = nameLabels[player]
    
    local needsRecreation = false
    
    if boxes then
        if not isDrawingValid(boxes.fill) or not isDrawingValid(boxes.border) then
            needsRecreation = true
        end
    else
        needsRecreation = true
    end
    
    if boneLines then
        for _, line in pairs(boneLines) do
            if not isDrawingValid(line) then
                needsRecreation = true
                break
            end
        end
    else
        needsRecreation = true
    end
    
    if nameLabel and not isDrawingValid(nameLabel) then
        needsRecreation = true
    end
    
    if needsRecreation then
        cleanupESP(player)
        createESP(player)
    end
end

-- Function to apply CFrame-based speedhack
local function applyCFrameSpeedhack(deltaTime)
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or not speedhackEnabled or isFlying then return end
    
    local moveDirection = Vector3.new(0, 0, 0)
    
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDirection = moveDirection + Camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveDirection = moveDirection - Camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveDirection = moveDirection - Camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveDirection = moveDirection + Camera.CFrame.RightVector
    end
    
    if moveDirection.Magnitude > 0 then
        moveDirection = moveDirection.Unit
        local safeSpeed = math.clamp(customSpeed, 16, 1000000)
        local velocity = moveDirection * safeSpeed * deltaTime
        rootPart.CFrame = rootPart.CFrame + Vector3.new(velocity.X, 0, velocity.Z) -- Keep Y unchanged
    end
end

-- Function to enable flying for a player
local function enableFlying(player)
    local character = player.Character
    if not character then
        print("No character found")
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        print("Humanoid or RootPart missing")
        return
    end

    if character:FindFirstChild("FlyVelocity") then
        print("Flying already enabled, skipping...")
        return
    end

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Name = "FlyVelocity"
    bodyVelocity.Parent = rootPart

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.Name = "FlyGyro"
    bodyGyro.Parent = rootPart

    humanoid.PlatformStand = true
    isFlying = true
    print("Flying enabled")

    local function updateFlying()
        local camera = workspace.CurrentCamera
        local moveDirection = Vector3.new(0, 0, 0)

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit * currentFlySpeed
        end
        bodyVelocity.Velocity = moveDirection

        bodyGyro.CFrame = camera.CFrame
    end

    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not character or not humanoid or humanoid.Health <= 0 then
            connection:Disconnect()
            isFlying = false
            print("Flying stopped due to character death or disconnect")
            return
        end
        updateFlying()
    end)

    local function stopFlying()
        if bodyVelocity then bodyVelocity:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        if humanoid then humanoid.PlatformStand = false end
        if connection then connection:Disconnect() end
        isFlying = false
        stopFlyingFunc = nil
        player:SetAttribute("StopFlying", nil)
        print("Flying disabled")
    end

    return stopFlying
end

-- Function to stop flying
local function stopFlying(player)
    if stopFlyingFunc then
        stopFlyingFunc()
    end
end

-- Function to update all ESP boxes, bones, and name labels
local function updateESP()
    if not espEnabled then
        for _, boxes in pairs(espBoxes) do
            if boxes.fill and isDrawingValid(boxes.fill) then boxes.fill.Visible = false end
            if boxes.border and isDrawingValid(boxes.border) then boxes.border.Visible = false end
        end
        for _, boneLines in pairs(espBones) do
            for _, line in pairs(boneLines) do
                if line and isDrawingValid(line) then line.Visible = false end
            end
        end
        for _, nameLabel in pairs(nameLabels) do
            if nameLabel and isDrawingValid(nameLabel) then nameLabel.Visible = false end
        end
        return
    end

    for player, boxes in pairs(espBoxes) do
        validateESP(player)
        
        local success, err = pcall(function()
            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local boneLines = espBones[player]
            local nameLabel = nameLabels[player]
            
            if not character or not rootPart then
                if boxes.fill and isDrawingValid(boxes.fill) then boxes.fill.Visible = false end
                if boxes.border and isDrawingValid(boxes.border) then boxes.border.Visible = false end
                for _, line in pairs(boneLines) do
                    if line and isDrawingValid(line) then line.Visible = false end
                end
                if nameLabel and isDrawingValid(nameLabel) then nameLabel.Visible = false end
                return
            end
            
            local boundingBoxSize
            local successBounding, errBounding = pcall(function()
                boundingBoxSize = character:GetExtentsSize()
            end)
            if not successBounding then
                if boxes.fill and isDrawingValid(boxes.fill) then boxes.fill.Visible = false end
                if boxes.border and isDrawingValid(boxes.border) then boxes.border.Visible = false end
                for _, line in pairs(boneLines) do
                    if line and isDrawingValid(line) then line.Visible = false end
                end
                if nameLabel and isDrawingValid(nameLabel) then nameLabel.Visible = false end
                return
            end
            
            local centerPos = rootPart.Position
            local screenPos, onScreen = Camera:WorldToViewportPoint(centerPos)
            
            if onScreen then
                local distance = (Camera.CFrame.Position - centerPos).Magnitude
                if distance > maxDistance then
                    if boxes.fill and isDrawingValid(boxes.fill) then boxes.fill.Visible = false end
                    if boxes.border and isDrawingValid(boxes.border) then boxes.border.Visible = false end
                    for _, line in pairs(boneLines) do
                        if line and isDrawingValid(line) then line.Visible = false end
                    end
                    if nameLabel and isDrawingValid(nameLabel) then nameLabel.Visible = false end
                    return
                end
                
                local scaleFactor = 1000 / (distance + 50)
                local boxWidth = math.clamp(boundingBoxSize.X * scaleFactor, 15, 80)
                local boxHeight = math.clamp(boundingBoxSize.Y * scaleFactor, 20, 120)
                local topLeft = Vector2.new(screenPos.X - boxWidth / 2, screenPos.Y - boxHeight / 2)
                local transparency = math.clamp(1 - (distance / 100), 0.4, 1)
                
                if boxes.fill and isDrawingValid(boxes.fill) then
                    boxes.fill.Size = Vector2.new(boxWidth, boxHeight)
                    boxes.fill.Position = topLeft
                    boxes.fill.Transparency = transparency * 0.5
                    boxes.fill.Visible = true
                end
                
                if boxes.border and isDrawingValid(boxes.border) then
                    boxes.border.Size = Vector2.new(boxWidth, boxHeight)
                    boxes.border.Position = topLeft
                    boxes.border.Transparency = transparency
                    boxes.border.Visible = true
                end
                
                if nameLabel and isDrawingValid(nameLabel) then
                    nameLabel.Position = Vector2.new(topLeft.X + boxWidth + 5, topLeft.Y - nameLabel.Size / 2)
                    nameLabel.Transparency = transparency
                    nameLabel.Visible = true
                end
                
                local head = character:FindFirstChild("Head")
                if head then
                    if isR6(character) then
                        local torso = character:FindFirstChild("Torso")
                        local leftLeg = character:FindFirstChild("Left Leg")
                        local rightLeg = character:FindFirstChild("Right Leg")
                        local leftArm = character:FindFirstChild("Left Arm")
                        local rightArm = character:FindFirstChild("Right Arm")
                        
                        if torso then
                            updateLine(boneLines.headToChest, head.Position, torso.Position)
                            if leftLeg then
                                updateLine(boneLines.stomachToLeftLeg, torso.Position, leftLeg.Position)
                            else
                                boneLines.stomachToLeftLeg.Visible = false
                            end
                            if rightLeg then
                                updateLine(boneLines.stomachToRightLeg, torso.Position, rightLeg.Position)
                            else
                                boneLines.stomachToRightLeg.Visible = false
                            end
                            if leftArm then
                                updateLine(boneLines.chestToLeftShoulder, torso.Position, leftArm.Position)
                                local leftArmCFrame = leftArm.CFrame
                                local leftHandPos = leftArmCFrame.Position - (leftArmCFrame.UpVector * (leftArm.Size.Y / 2))
                                updateLine(boneLines.leftShoulderToHand, leftArm.Position, leftHandPos)
                            else
                                boneLines.chestToLeftShoulder.Visible = false
                                boneLines.leftShoulderToHand.Visible = false
                            end
                            if rightArm then
                                updateLine(boneLines.chestToRightShoulder, torso.Position, rightArm.Position)
                                local rightArmCFrame = rightArm.CFrame
                                local rightHandPos = rightArmCFrame.Position - (rightArmCFrame.UpVector * (rightArm.Size.Y / 2))
                                updateLine(boneLines.rightShoulderToHand, rightArm.Position, rightHandPos)
                            else
                                boneLines.chestToRightShoulder.Visible = false
                                boneLines.rightShoulderToHand.Visible = false
                            end
                            boneLines.chestToStomach.Visible = false
                        else
                            for _, line in pairs(boneLines) do
                                if line and isDrawingValid(line) then line.Visible = false end
                            end
                        end
                    else
                        local upperTorso = character:FindFirstChild("UpperTorso")
                        local lowerTorso = character:FindFirstChild("LowerTorso")
                        local leftFoot = character:FindFirstChild("LeftFoot")
                        local rightFoot = character:FindFirstChild("RightFoot")
                        local leftUpperArm = character:FindFirstChild("LeftUpperArm")
                        local rightUpperArm = character:FindFirstChild("RightUpperArm")
                        local leftHand = character:FindFirstChild("LeftHand")
                        local rightHand = character:FindFirstChild("RightHand")
                        
                        if upperTorso and lowerTorso then
                            updateLine(boneLines.headToChest, head.Position, upperTorso.Position)
                            updateLine(boneLines.chestToStomach, upperTorso.Position, lowerTorso.Position)
                            if leftFoot then
                                updateLine(boneLines.stomachToLeftLeg, lowerTorso.Position, leftFoot.Position)
                            else
                                boneLines.stomachToLeftLeg.Visible = false
                            end
                            if rightFoot then
                                updateLine(boneLines.stomachToRightLeg, lowerTorso.Position, rightFoot.Position)
                            else
                                boneLines.stomachToRightLeg.Visible = false
                            end
                            if leftUpperArm then
                                updateLine(boneLines.chestToLeftShoulder, upperTorso.Position, leftUpperArm.Position)
                                if leftHand then
                                    updateLine(boneLines.leftShoulderToHand, leftUpperArm.Position, leftHand.Position)
                                else
                                    boneLines.leftShoulderToHand.Visible = false
                                end
                            else
                                boneLines.chestToLeftShoulder.Visible = false
                                boneLines.leftShoulderToHand.Visible = false
                            end
                            if rightUpperArm then
                                updateLine(boneLines.chestToRightShoulder, upperTorso.Position, rightUpperArm.Position)
                                if rightHand then
                                    updateLine(boneLines.rightShoulderToHand, rightUpperArm.Position, rightHand.Position)
                                else
                                    boneLines.rightShoulderToHand.Visible = false
                                end
                            else
                                boneLines.chestToRightShoulder.Visible = false
                                boneLines.rightShoulderToHand.Visible = false
                            end
                        else
                            for _, line in pairs(boneLines) do
                                if line and isDrawingValid(line) then line.Visible = false end
                            end
                        end
                    end
                else
                    for _, line in pairs(boneLines) do
                        if line and isDrawingValid(line) then line.Visible = false end
                    end
                end
            else
                if boxes.fill and isDrawingValid(boxes.fill) then boxes.fill.Visible = false end
                if boxes.border and isDrawingValid(boxes.border) then boxes.border.Visible = false end
                for _, line in pairs(boneLines) do
                    if line and isDrawingValid(line) then line.Visible = false end
                end
                if nameLabel and isDrawingValid(nameLabel) then nameLabel.Visible = false end
            end
        end)
        if not success then
            if boxes.fill and isDrawingValid(boxes.fill) then boxes.fill.Visible = false end
            if boxes.border and isDrawingValid(boxes.border) then boxes.border.Visible = false end
            for _, line in pairs(espBones[player] or {}) do
                if line and isDrawingValid(line) then line.Visible = false end
            end
            if nameLabels[player] and isDrawingValid(nameLabels[player]) then nameLabels[player].Visible = false end
            cleanupESP(player)
            createESP(player)
        end
    end
end

-- Function to clean up all ESP elements for a player
local function cleanupESP(player)
    local success, err = pcall(function()
        if espBoxes[player] then
            if espBoxes[player].fill and isDrawingValid(espBoxes[player].fill) then espBoxes[player].fill:Remove() end
            if espBoxes[player].border and isDrawingValid(espBoxes[player].border) then espBoxes[player].border:Remove() end
            espBoxes[player] = nil
        end
        if espBones[player] then
            for _, line in pairs(espBones[player]) do
                if line and isDrawingValid(line) then line:Remove() end
            end
            espBones[player] = nil
        end
        if nameLabels[player] and isDrawingValid(nameLabels[player]) then
            nameLabels[player]:Remove()
            nameLabels[player] = nil
        end
    end)
    if not success then
        warn("Error cleaning up ESP for player " .. player.Name .. ": " .. err)
    end
end

-- Function to reset all ESP elements
local function resetESP()
    for player, _ in pairs(espBoxes) do
        cleanupESP(player)
    end
    espBoxes = {}
    espBones = {}
    nameLabels = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            createESP(player)
        end
    end
end

-- Create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPGui"
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 400, 0, 320)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = false
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 0
titleLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
titleLabel.Text = "PISS MENU v1.2"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
titleLabel.TextSize = 30
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Parent = mainFrame

local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, 0, 0, 30)
tabContainer.Position = UDim2.new(0, 0, 0, 30)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 5)
tabLayout.Parent = tabContainer

local playerTabButton = Instance.new("TextButton")
playerTabButton.Size = UDim2.new(0.31, 0, 0, 26)
playerTabButton.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
playerTabButton.BackgroundTransparency = 0.3
playerTabButton.Text = "PLAYER"
playerTabButton.TextColor3 = Color3.fromRGB(255, 255, 0)
playerTabButton.TextSize = 14
playerTabButton.Font = Enum.Font.SourceSansBold
playerTabButton.Parent = tabContainer

local chatVoiceTabButton = Instance.new("TextButton")
chatVoiceTabButton.Size = UDim2.new(0.31, 0, 0, 26)
chatVoiceTabButton.BackgroundColor3 = Color3.fromRGB(40, 40, 0)
chatVoiceTabButton.BackgroundTransparency = 0.3
chatVoiceTabButton.Text = "CHAT/VOICE"
chatVoiceTabButton.TextColor3 = Color3.fromRGB(255, 255, 0)
chatVoiceTabButton.TextSize = 14
chatVoiceTabButton.Font = Enum.Font.SourceSansBold
chatVoiceTabButton.Parent = tabContainer

local settingsTabButton = Instance.new("TextButton")
settingsTabButton.Size = UDim2.new(0.31, 0, 0, 26)
settingsTabButton.BackgroundColor3 = Color3.fromRGB(40, 40, 0)
settingsTabButton.BackgroundTransparency = 0.3
settingsTabButton.Text = "SETTINGS"
settingsTabButton.TextColor3 = Color3.fromRGB(255, 255, 0)
settingsTabButton.TextSize = 14
settingsTabButton.Font = Enum.Font.SourceSansBold
settingsTabButton.Parent = tabContainer

local playerTabCorner = Instance.new("UICorner")
playerTabCorner.CornerRadius = UDim.new(0, 4)
playerTabCorner.Parent = playerTabButton

local chatVoiceTabCorner = Instance.new("UICorner")
chatVoiceTabCorner.CornerRadius = UDim.new(0, 4)
chatVoiceTabCorner.Parent = chatVoiceTabButton

local settingsTabCorner = Instance.new("UICorner")
settingsTabCorner.CornerRadius = UDim.new(0, 4)
settingsTabCorner.Parent = settingsTabButton

local playerFrame = Instance.new("Frame")
playerFrame.Size = UDim2.new(1, 0, 1, -60)
playerFrame.Position = UDim2.new(0, 0, 0, 60)
playerFrame.BackgroundTransparency = 1
playerFrame.Visible = true
playerFrame.Parent = mainFrame

local chatVoiceFrame = Instance.new("Frame")
chatVoiceFrame.Size = UDim2.new(1, 0, 1, -60)
chatVoiceFrame.Position = UDim2.new(0, 0, 0, 60)
chatVoiceFrame.BackgroundTransparency = 1
chatVoiceFrame.Visible = false
chatVoiceFrame.Parent = mainFrame

local settingsFrame = Instance.new("Frame")
settingsFrame.Size = UDim2.new(1, 0, 1, -60)
settingsFrame.Position = UDim2.new(0, 0, 0, 60)
settingsFrame.BackgroundTransparency = 1
settingsFrame.Visible = false
settingsFrame.Parent = mainFrame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 16, 0, 16)
toggleButton.Position = UDim2.new(0, 40, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
toggleButton.BackgroundTransparency = 0.3
toggleButton.Text = ""
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 0)
toggleButton.TextSize = 30
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = playerFrame

local toggleLabel = Instance.new("TextLabel")
toggleLabel.Size = UDim2.new(0, 150, 0, 20)
toggleLabel.Position = UDim2.new(0, 95, 0, 10)
toggleLabel.BackgroundTransparency = 1
toggleLabel.Text = "-ESP- {TOGGLE}"
toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
toggleLabel.TextSize = 12
toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
toggleLabel.Parent = playerFrame

local distanceLabel = Instance.new("TextLabel")
distanceLabel.Size = UDim2.new(0, 150, 0, 20)
distanceLabel.Position = UDim2.new(0, 95, 0, 40)
distanceLabel.BackgroundTransparency = 1
distanceLabel.Text = "- Distance"
distanceLabel.TextColor3 = Color3.fromRGB(150, 150, 0)
distanceLabel.TextSize = 8
distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
distanceLabel.Parent = playerFrame

local distanceBox = Instance.new("TextBox")
distanceBox.Size = UDim2.new(0, 80, 0, 25)
distanceBox.Position = UDim2.new(0, 5, 0, 40)
distanceBox.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
distanceBox.BackgroundTransparency = 0.3
distanceBox.TextColor3 = Color3.fromRGB(255, 255, 0)
distanceBox.Text = tostring(maxDistance)
distanceBox.TextSize = 12
distanceBox.Parent = playerFrame

local speedToggleButton = Instance.new("TextButton")
speedToggleButton.Size = UDim2.new(0, 16, 0, 16)
speedToggleButton.Position = UDim2.new(0, 40, 0, 100)
speedToggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
speedToggleButton.BackgroundTransparency = 0.3
speedToggleButton.Text = ""
speedToggleButton.TextColor3 = Color3.fromRGB(255, 255, 0)
speedToggleButton.TextSize = 30
speedToggleButton.Font = Enum.Font.SourceSansBold
speedToggleButton.Parent = playerFrame

local speedToggleLabel = Instance.new("TextLabel")
speedToggleLabel.Size = UDim2.new(0, 150, 0, 20)
speedToggleLabel.Position = UDim2.new(0, 95, 0, 100)
speedToggleLabel.BackgroundTransparency = 1
speedToggleLabel.Text = "-Speed Hack- {TOGGLE}"
speedToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
speedToggleLabel.TextSize = 12
speedToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
speedToggleLabel.Parent = playerFrame

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0, 150, 0, 20)
speedLabel.Position = UDim2.new(0, 95, 0, 130)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "- Speed"
speedLabel.TextColor3 = Color3.fromRGB(150, 150, 0)
speedLabel.TextSize = 8
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = playerFrame

local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(0, 80, 0, 25)
speedBox.Position = UDim2.new(0, 5, 0, 130)
speedBox.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
speedBox.BackgroundTransparency = 0.3
speedBox.TextColor3 = Color3.fromRGB(255, 255, 0)
speedBox.Text = tostring(customSpeed)
speedBox.TextSize = 12
speedBox.Parent = playerFrame

local flyToggleButton = Instance.new("TextButton")
flyToggleButton.Size = UDim2.new(0, 16, 0, 16)
flyToggleButton.Position = UDim2.new(0, 40, 0, 190)
flyToggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
flyToggleButton.BackgroundTransparency = 0.3
flyToggleButton.Text = ""
flyToggleButton.TextColor3 = Color3.fromRGB(255, 255, 0)
flyToggleButton.TextSize = 30
flyToggleButton.Font = Enum.Font.SourceSansBold
flyToggleButton.Parent = playerFrame

local flyToggleLabel = Instance.new("TextLabel")
flyToggleLabel.Size = UDim2.new(0, 150, 0, 20)
flyToggleLabel.Position = UDim2.new(0, 95, 0, 190)
flyToggleLabel.BackgroundTransparency = 1
flyToggleLabel.Text = "-Fly- {TOGGLE}"
flyToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
flyToggleLabel.TextSize = 12
flyToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
flyToggleLabel.Parent = playerFrame

local flySpeedLabel = Instance.new("TextLabel")
flySpeedLabel.Size = UDim2.new(0, 150, 0, 20)
flySpeedLabel.Position = UDim2.new(0, 95, 0, 220)
flySpeedLabel.BackgroundTransparency = 1
flySpeedLabel.Text = "- Speed"
flySpeedLabel.TextColor3 = Color3.fromRGB(150, 150, 0)
flySpeedLabel.TextSize = 8
flySpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
flySpeedLabel.Parent = playerFrame

local flySpeedBox = Instance.new("TextBox")
flySpeedBox.Size = UDim2.new(0, 80, 0, 25)
flySpeedBox.Position = UDim2.new(0, 5, 0, 220)
flySpeedBox.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
flySpeedBox.BackgroundTransparency = 0.3
flySpeedBox.TextColor3 = Color3.fromRGB(255, 255, 0)
flySpeedBox.Text = tostring(currentFlySpeed)
flySpeedBox.TextSize = 12
flySpeedBox.Parent = playerFrame

local unbanVoiceButton = Instance.new("TextButton")
unbanVoiceButton.Size = UDim2.new(0, 110, 0, 25)
unbanVoiceButton.Position = UDim2.new(0, 5, 0, 20)
unbanVoiceButton.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
unbanVoiceButton.BackgroundTransparency = 0.3
unbanVoiceButton.Text = "Unban Voice"
unbanVoiceButton.TextColor3 = Color3.fromRGB(255, 255, 0)
unbanVoiceButton.TextSize = 12
unbanVoiceButton.Font = Enum.Font.SourceSansBold
unbanVoiceButton.Parent = chatVoiceFrame

local loadBypassButton = Instance.new("TextButton")
loadBypassButton.Size = UDim2.new(0, 110, 0, 25)
loadBypassButton.Position = UDim2.new(0, 5, 0, 50)
loadBypassButton.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
loadBypassButton.BackgroundTransparency = 0.3
loadBypassButton.Text = "UserCreated Bypass"
loadBypassButton.TextColor3 = Color3.fromRGB(255, 255, 0)
loadBypassButton.TextSize = 12
loadBypassButton.Font = Enum.Font.SourceSansBold
loadBypassButton.Parent = chatVoiceFrame

local clearChatButton = Instance.new("TextButton")
clearChatButton.Size = UDim2.new(0, 110, 0, 25)
clearChatButton.Position = UDim2.new(0, 5, 0, 100)
clearChatButton.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
clearChatButton.BackgroundTransparency = 0.3
clearChatButton.Text = "Clear Chat"
clearChatButton.TextColor3 = Color3.fromRGB(255, 255, 0)
clearChatButton.TextSize = 12
clearChatButton.Font = Enum.Font.SourceSansBold
clearChatButton.Parent = chatVoiceFrame

local swastikaButton = Instance.new("TextButton")
swastikaButton.Size = UDim2.new(0, 110, 0, 25)
swastikaButton.Position = UDim2.new(0, 5, 0, 130)
swastikaButton.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
swastikaButton.BackgroundTransparency = 0.3
swastikaButton.Text = "Swastika"
swastikaButton.TextColor3 = Color3.fromRGB(255, 255, 0)
swastikaButton.TextSize = 12
swastikaButton.Font = Enum.Font.SourceSansBold
swastikaButton.Parent = chatVoiceFrame

local unbanVoiceCorner = Instance.new("UICorner")
unbanVoiceCorner.CornerRadius = UDim.new(0, 4)
unbanVoiceCorner.Parent = unbanVoiceButton

local loadBypassCorner = Instance.new("UICorner")
loadBypassCorner.CornerRadius = UDim.new(0, 4)
loadBypassCorner.Parent = loadBypassButton

local clearChatCorner = Instance.new("UICorner")
clearChatCorner.CornerRadius = UDim.new(0, 4)
clearChatCorner.Parent = clearChatButton

local swastikaCorner = Instance.new("UICorner")
swastikaCorner.CornerRadius = UDim.new(0, 4)
swastikaCorner.Parent = swastikaButton

local keybindLabel = Instance.new("TextLabel")
keybindLabel.Size = UDim2.new(0, 150, 0, 20)
keybindLabel.Position = UDim2.new(0, 125, 0, 10)
keybindLabel.BackgroundTransparency = 1
keybindLabel.Text = "Menu Bind {CLICK TO CHANGE}"
keybindLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
keybindLabel.TextSize = 12
keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
keybindLabel.Parent = settingsFrame

local keybindButton = Instance.new("TextButton")
keybindButton.Size = UDim2.new(0, 110, 0, 25)
keybindButton.Position = UDim2.new(0, 5, 0, 10)
keybindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 0)
keybindButton.BackgroundTransparency = 0.3
keybindButton.TextColor3 = Color3.fromRGB(255, 255, 0)
keybindButton.Text = keybind.Name
keybindButton.TextSize = 12
keybindButton.Parent = settingsFrame

local resizeHandle = Instance.new("TextButton")
resizeHandle.Size = UDim2.new(0, 15, 0, 15)
resizeHandle.Position = UDim2.new(1, -15, 1, -15)
resizeHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
resizeHandle.BackgroundTransparency = 0
resizeHandle.Text = "↘"
resizeHandle.TextColor3 = Color3.fromRGB(0, 0, 0)
resizeHandle.TextSize = 12
resizeHandle.Parent = mainFrame

local resizeCorner = Instance.new("UICorner")
resizeCorner.CornerRadius = UDim.new(0, 4)
resizeCorner.Parent = resizeHandle

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 4)
boxCorner.Parent = distanceBox

local speedBoxCorner = Instance.new("UICorner")
speedBoxCorner.CornerRadius = UDim.new(0, 4)
speedBoxCorner.Parent = speedBox

local flySpeedBoxCorner = Instance.new("UICorner")
flySpeedBoxCorner.CornerRadius = UDim.new(0, 4)
flySpeedBoxCorner.Parent = flySpeedBox

local keybindCorner = Instance.new("UICorner")
keybindCorner.CornerRadius = UDim.new(0, 4)
keybindCorner.Parent = keybindButton

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 4)
buttonCorner.Parent = toggleButton

local speedButtonCorner = Instance.new("UICorner")
speedButtonCorner.CornerRadius = UDim.new(0, 4)
speedButtonCorner.Parent = speedToggleButton

local flyButtonCorner = Instance.new("UICorner")
flyButtonCorner.CornerRadius = UDim.new(0, 4)
flyButtonCorner.Parent = flyToggleButton

local function switchTab(selectedFrame, selectedButton)
    playerFrame.Visible = (selectedFrame == playerFrame)
    chatVoiceFrame.Visible = (selectedFrame == chatVoiceFrame)
    settingsFrame.Visible = (selectedFrame == settingsFrame)
    
    playerTabButton.BackgroundColor3 = (selectedFrame == playerFrame) and Color3.fromRGB(60, 60, 0) or Color3.fromRGB(40, 40, 0)
    playerTabButton.BackgroundTransparency = 0.3
    chatVoiceTabButton.BackgroundColor3 = (selectedFrame == chatVoiceFrame) and Color3.fromRGB(60, 60, 0) or Color3.fromRGB(40, 40, 0)
    chatVoiceTabButton.BackgroundTransparency = 0.3
    settingsTabButton.BackgroundColor3 = (selectedFrame == settingsFrame) and Color3.fromRGB(60, 60, 0) or Color3.fromRGB(40, 40, 0)
    settingsTabButton.BackgroundTransparency = 0.3
end

playerTabButton.MouseButton1Click:Connect(function()
    switchTab(playerFrame, playerTabButton)
end)

chatVoiceTabButton.MouseButton1Click:Connect(function()
    switchTab(chatVoiceFrame, chatVoiceTabButton)
end)

settingsTabButton.MouseButton1Click:Connect(function()
    switchTab(settingsFrame, settingsTabButton)
end)

unbanVoiceButton.MouseButton1Click:Connect(function()
    local success, err = pcall(function()
        VoiceChatService:joinVoice()
    end)
    if not success then
        warn("Failed to join voice: " .. err)
    end
end)

loadBypassButton.MouseButton1Click:Connect(function()
    local success, err = pcall(function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/cheatplug/usercreated/refs/heads/main/main.lua'))()
    end)
    if not success then
        warn("Failed to load UserCreated Bypass: " .. err)
    end
end)

clearChatButton.MouseButton1Click:Connect(function()
    sendMessage(Strings["Clear Chat"])
end)

swastikaButton.MouseButton1Click:Connect(function()
    sendMessage(Strings["Swastika"])
end)

local dragging = false
local mouseOffset = Vector2.new()

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        local mousePos = UserInputService:GetMouseLocation()
        local framePos = Vector2.new(mainFrame.AbsolutePosition.X, mainFrame.AbsolutePosition.Y)
        mouseOffset = framePos - mousePos
    end
end)

mainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local resizing = false
local initialMousePos = Vector2.new()
local initialFrameSize = UDim2.new()

resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true
        initialMousePos = UserInputService:GetMouseLocation()
        initialFrameSize = mainFrame.Size
    end
end)

resizeHandle.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = false
    end
end)

RunService.RenderStepped:Connect(function(deltaTime)
    if dragging then
        local mousePos = UserInputService:GetMouseLocation()
        local newPos = mousePos + mouseOffset
        mainFrame.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
    end
    
    if resizing then
        local mousePos = UserInputService:GetMouseLocation()
        local delta = mousePos - initialMousePos
        local newWidth = math.max(150, initialFrameSize.X.Offset + delta.X)
        local newHeight = math.max(150, initialFrameSize.Y.Offset + delta.Y)
        mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
    end

    updateESP()
    applyCFrameSpeedhack(deltaTime)

    timeSinceLastReset = timeSinceLastReset + deltaTime
    if timeSinceLastReset >= RESET_INTERVAL then
        resetESP()
        timeSinceLastReset = 0
    end
end)

toggleButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    toggleButton.Text = espEnabled and "✓" or ""
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 0)
end)

speedToggleButton.MouseButton1Click:Connect(function()
    speedhackEnabled = not speedhackEnabled
    speedToggleButton.Text = speedhackEnabled and "✓" or ""
    speedToggleButton.TextColor3 = Color3.fromRGB(255, 255, 0)
end)

flyToggleButton.MouseButton1Click:Connect(function()
    flyhackEnabled = not flyhackEnabled
    flyToggleButton.Text = flyhackEnabled and "✓" or ""
    flyToggleButton.TextColor3 = Color3.fromRGB(255, 255, 0)
    if not flyhackEnabled then
        stopFlying(Players.LocalPlayer)
    end
end)

distanceBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local input = tonumber(distanceBox.Text)
        if input and input >= 0 then
            maxDistance = input
        else
            distanceBox.Text = tostring(maxDistance)
        end
    end
end)

speedBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local input = tonumber(speedBox.Text)
        if input and input >= 16 and input <= 1000000 then
            customSpeed = input
        else
            speedBox.Text = tostring(customSpeed)
        end
    end
end)

flySpeedBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local input = tonumber(flySpeedBox.Text)
        if input and input >= MIN_FLY_SPEED and input <= MAX_FLY_SPEED then
            currentFlySpeed = input
        else
            flySpeedBox.Text = tostring(currentFlySpeed)
        end
    end
end)

keybindButton.MouseButton1Click:Connect(function()
    isSelectingKeybind = true
    keybindButton.Text = "Select a key"
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if isSelectingKeybind and not gameProcessedEvent and input.UserInputType == Enum.UserInputType.Keyboard then
        keybind = input.KeyCode
        keybindButton.Text = keybind.Name
        isSelectingKeybind = false
    elseif input.KeyCode == keybind and not gameProcessedEvent then
        mainFrame.Visible = not mainFrame.Visible
    elseif gameProcessedEvent then
        return
    end

    local player = Players.LocalPlayer
    if not player.Character then return end

    if input.KeyCode == Enum.KeyCode.Space and flyhackEnabled then
        local currentTime = tick()
        if currentTime - lastJumpTime <= DOUBLE_JUMP_TIME then
            jumpCount = jumpCount + 1
            if jumpCount >= 2 then
                if isFlying then
                    stopFlying(player)
                else
                    stopFlyingFunc = enableFlying(player)
                    if stopFlyingFunc then
                        player:SetAttribute("StopFlying", stopFlyingFunc)
                    end
                end
                jumpCount = 0
            end
        else
            jumpCount = 1
        end
        lastJumpTime = currentTime
    elseif input.KeyCode == SPEED_UP_KEY then
        currentFlySpeed = math.min(currentFlySpeed + SPEED_INCREMENT, MAX_FLY_SPEED)
        flySpeedBox.Text = tostring(currentFlySpeed)
        print("Fly Speed: " .. currentFlySpeed)
    elseif input.KeyCode == SPEED_DOWN_KEY then
        currentFlySpeed = math.max(currentFlySpeed - SPEED_INCREMENT, MIN_FLY_SPEED)
        flySpeedBox.Text = tostring(currentFlySpeed)
        print("Fly Speed: " .. currentFlySpeed)
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        createESP(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    cleanupESP(player)
end)

Players.LocalPlayer.CharacterAdded:Connect(function(character)
    stopFlying(Players.LocalPlayer)
end)

for _, player in pairs(Players:GetPlayers()) do
    if player.Character then
        createESP(player)
    end
end