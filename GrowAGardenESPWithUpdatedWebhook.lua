-- Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local collectionService = game:GetService("CollectionService")
local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")

-- Wait for game to load
if not game:IsLoaded() then
    print("Waiting for game to load...")
    local success, err = pcall(function()
        game.Loaded:Wait()
    end)
    if not success then
        warn("Failed to wait for game to load: " .. tostring(err))
    end
end
print("Game loaded, proceeding with script initialization...")

-- Main script logic wrapped in pcall
local success, scriptError = pcall(function()
    -- Check for LocalPlayer
    local localPlayer = players.LocalPlayer
    if not localPlayer then
        error("LocalPlayer not found. Script cannot run.")
    end
    print("LocalPlayer found:", localPlayer.Name)

    -- Wait for PlayerGui with timeout
    local playerGui
    local guiWaitSuccess, guiWaitErr = pcall(function()
        playerGui = localPlayer:WaitForChild("PlayerGui", 15)
    end)
    if not guiWaitSuccess or not playerGui then
        error("PlayerGui not found after 15 seconds: " .. tostring(guiWaitErr))
    end
    print("PlayerGui found, setting up GUI...")

    -- Variables
    local espCache = {}
    local activeEggs = {}
    local espEnabled = true
    local isGuiMinimized = false
    local eggModels, eggPets

    -- Attempt to get pet egg data with enhanced error handling
    local hatchFunction
    local petDataSuccess, petDataErr = pcall(function()
        local gameEvents = replicatedStorage:FindFirstChild("GameEvents")
        if not gameEvents then
            error("GameEvents not found in ReplicatedStorage")
        end
        local petEggService = gameEvents:FindFirstChild("PetEggService")
        if not petEggService then
            error("PetEggService not found in GameEvents")
        end
        local connections = getconnections(petEggService.OnClientEvent)
        if not connections or #connections == 0 then
            error("No connections found for PetEggService.OnClientEvent")
        end
        hatchFunction = getupvalue(getupvalue(connections[1].Function, 1), 2)
        eggModels = getupvalue(hatchFunction, 1)
        eggPets = getupvalue(hatchFunction, 2)
    end)
    if not petDataSuccess then
        warn("Failed to retrieve pet egg data: " .. tostring(petDataErr))
        eggPets = nil
        eggModels = nil
        ShowError("Failed to load pet egg data. Some features may not work.")
    else
        print("Pet egg data retrieved successfully")
    end

    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggESPGui"
    screenGui.Parent = playerGui
    screenGui.IgnoreGuiInset = true

    -- Create main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 350) -- Reduced height due to fewer elements
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.Parent = screenGui

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 12)
    uiCorner.Parent = mainFrame

    local uiGradient = Instance.new("UIGradient")
    uiGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 45, 45)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30))
    })
    uiGradient.Rotation = 45
    uiGradient.Parent = mainFrame

    -- Minimized icon
    local minimizedIcon = Instance.new("ImageButton")
    minimizedIcon.Size = UDim2.new(0, 60, 0, 60)
    minimizedIcon.Position = UDim2.new(0, 100, 0.5, -25)
    minimizedIcon.BackgroundColor3 = Color3.fromRGB(60, 80, 110)
    minimizedIcon.Image = "rbxassetid://188697674"
    minimizedIcon.Visible = false
    minimizedIcon.Parent = screenGui

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 30)
    iconCorner.Parent = minimizedIcon

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = minimizedIcon

    minimizedIcon.MouseEnter:Connect(function()
        uiScale.Scale = 1.2
        minimizedIcon.BackgroundColor3 = Color3.fromRGB(80, 100, 130)
        ShowNotification("Hovering over minimized GUI")
    end)
    minimizedIcon.MouseLeave:Connect(function()
        uiScale.Scale = 1
        minimizedIcon.BackgroundColor3 = Color3.fromRGB(60, 80, 110)
    end)

    -- Make frame draggable
    local dragging, dragStart, startPos
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Title label
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.7, 0, 0, 40)
    titleLabel.Position = UDim2.new(0.05, 0, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Grow a Garden ESP"
    titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 22
    titleLabel.Parent = mainFrame

    -- Minimize button
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Size = UDim2.new(0, 30, 0, 30)
    minimizeButton.Position = UDim2.new(0.85, 0, 0, 15)
    minimizeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    minimizeButton.Text = "-"
    minimizeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    minimizeButton.Font = Enum.Font.GothamBold
    minimizeButton.TextSize = 18
    minimizeButton.Parent = mainFrame

    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 8)
    minimizeCorner.Parent = minimizeButton

    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(0.93, -10, 0, 15)
    closeButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 18
    closeButton.Parent = mainFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton

    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 30)
    statusLabel.Position = UDim2.new(0.05, 0, 0.1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Eggs: 0 | Pet Data: Unknown"
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 16
    statusLabel.Parent = mainFrame

    -- ESP toggle button
    local espToggleButton = Instance.new("TextButton")
    espToggleButton.Size = UDim2.new(0.9, 0, 0, 40)
    espToggleButton.Position = UDim2.new(0.05, 0, 0.2, 0)
    espToggleButton.BackgroundColor3 = espEnabled and Color3.fromRGB(60, 80, 110) or Color3.fromRGB(60, 60, 60)
    espToggleButton.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
    espToggleButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    espToggleButton.Font = Enum.Font.GothamBold
    espToggleButton.TextSize = 16
    espToggleButton.ZIndex = 1
    espToggleButton.Parent = mainFrame

    local espToggleCorner = Instance.new("UICorner")
    espToggleCorner.CornerRadius = UDim.new(0, 8)
    espToggleCorner.Parent = espToggleButton

    -- Error label
    local errorLabel = Instance.new("TextLabel")
    errorLabel.Size = UDim2.new(0.9, 0, 0, 30)
    errorLabel.Position = UDim2.new(0.05, 0, 0.3, 0)
    errorLabel.BackgroundTransparency = 1
    errorLabel.Text = ""
    errorLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    errorLabel.Font = Enum.Font.GothamBold
    errorLabel.TextSize = 16
    errorLabel.ZIndex = 1
    errorLabel.Parent = mainFrame

    -- Egg list header
    local eggListHeader = Instance.new("TextLabel")
    eggListHeader.Size = UDim2.new(0.9, 0, 0, 30)
    eggListHeader.Position = UDim2.new(0.05, 0, 0.38, 0)
    eggListHeader.BackgroundTransparency = 1
    eggListHeader.Text = "My Eggs"
    eggListHeader.TextColor3 = Color3.fromRGB(220, 220, 220)
    eggListHeader.Font = Enum.Font.GothamBold
    eggListHeader.TextSize = 18
    eggListHeader.ZIndex = 1
    eggListHeader.Parent = mainFrame

    -- Egg list scrolling frame
    local eggListFrame = Instance.new("ScrollingFrame")
    eggListFrame.Size = UDim2.new(0.9, 0, 0, 150)
    eggListFrame.Position = UDim2.new(0.05, 0, 0.46, 0)
    eggListFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    eggListFrame.BackgroundTransparency = 0.5
    eggListFrame.ScrollBarThickness = 6
    eggListFrame.ZIndex = 1
    eggListFrame.Parent = mainFrame

    local eggListCorner = Instance.new("UICorner")
    eggListCorner.CornerRadius = UDim.new(0, 8)
    eggListCorner.Parent = eggListFrame

    local uiListLayout = Instance.new("UIListLayout")
    uiListLayout.Padding = UDim.new(0, 5)
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Parent = eggListFrame

    -- Notification frame
    local notificationFrame = Instance.new("Frame")
    notificationFrame.Size = UDim2.new(0, 250, 0, 50)
    notificationFrame.Position = UDim2.new(1, -260, 0, 10)
    notificationFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    notificationFrame.BackgroundTransparency = 0.3
    notificationFrame.Visible = false
    notificationFrame.ZIndex = 5
    notificationFrame.Parent = screenGui

    local notificationCorner = Instance.new("UICorner")
    notificationCorner.CornerRadius = UDim.new(0, 8)
    notificationCorner.Parent = notificationFrame

    local notificationLabel = Instance.new("TextLabel")
    notificationLabel.Size = UDim2.new(0.9, 0, 0.8, 0)
    notificationLabel.Position = UDim2.new(0.05, 0, 0.1, 0)
    notificationLabel.BackgroundTransparency = 1
    notificationLabel.Text = ""
    notificationLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    notificationLabel.Font = Enum.Font.Gotham
    notificationLabel.TextSize = 14
    notificationLabel.TextWrapped = true
    notificationLabel.ZIndex = 6
    notificationLabel.Parent = notificationFrame

    -- Function to show notifications
    function ShowNotification(message)
        if notificationLabel then
            notificationLabel.Text = message
            notificationFrame.Visible = true
            spawn(function()
                wait(5)
                notificationFrame.Visible = false
            end)
        else
            print("Notification: " .. message)
        end
    end

    -- Function to show errors
    function ShowError(message)
        if errorLabel then
            errorLabel.Text = "Error: " .. message
            print("Error:", message)
            spawn(function()
                wait(5)
                errorLabel.Text = ""
            end)
        else
            warn("Error: " .. message)
        end
    end

    -- Function to update status
    local function UpdateStatus()
        local eggCount = 0
        for _ in pairs(activeEggs) do eggCount = eggCount + 1 end
        local petDataStatus = eggPets and "Loaded" or "Not Loaded"
        statusLabel.Text = string.format("Eggs: %d | Pet Data: %s", eggCount, petDataStatus)
    end

    -- Function to update egg list
    local function UpdateEggList()
        for _, child in pairs(eggListFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        local index = 0
        for objectId, object in pairs(activeEggs) do
            local eggName = object:GetAttribute("EggName") or "Unknown Egg"
            local petName = eggPets and eggPets[objectId] or "?"
            local entry = Instance.new("TextButton")
            entry.Size = UDim2.new(1, -10, 0, 30)
            entry.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            entry.Text = string.format("%s | %s", eggName, petName)
            entry.TextColor3 = Color3.fromRGB(220, 220, 220)
            entry.Font = Enum.Font.Gotham
            entry.TextSize = 14
            entry.LayoutOrder = index
            entry.ZIndex = 1
            entry.Parent = eggListFrame
            local entryCorner = Instance.new("UICorner")
            entryCorner.CornerRadius = UDim.new(0, 6)
            entryCorner.Parent = entry
            entry.MouseButton1Click:Connect(function()
                local eggPart = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
                if eggPart and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    localPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 5, 0))
                    ShowNotification("Teleported to " .. eggName)
                else
                    ShowError("Cannot teleport to egg")
                end
            end)
            index = index + 1
        end
        eggListFrame.CanvasSize = UDim2.new(0, 0, 0, index * 35)
    end

    -- Function to calculate offset to prevent overlapping
    local function CalculateOffset(object)
        local baseOffset = 2.5
        local offsetIncrement = 1.5
        local nearbyEggs = 0
        local eggPart = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
        if not eggPart then return baseOffset end
        local eggPos = eggPart.Position
        for _, otherEgg in pairs(activeEggs) do
            if otherEgg ~= object then
                local otherPart = otherEgg.PrimaryPart or otherEgg:FindFirstChildWhichIsA("BasePart")
                if otherPart then
                    local distance = (eggPos - otherPart.Position).Magnitude
                    if distance < 5 then
                        nearbyEggs = nearbyEggs + 1
                    end
                end
            end
        end
        return baseOffset + (nearbyEggs * offsetIncrement)
    end

    -- Function to get object from ID
    local function getObjectFromId(objectId)
        if not eggModels then return nil end
        for eggModel in eggModels do
            if eggModel:GetAttribute("OBJECT_UUID") == objectId then
                return eggModel
            end
        end
        print("No egg model found for UUID:", objectId)
        return nil
    end

    -- Function to create ESP GUI
    local function CreateEspGui(object, text, yOffset)
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "PetEggESP"
        billboard.Adornee = object:FindFirstChildWhichIsA("BasePart") or object.PrimaryPart or object
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, yOffset, 0)
        billboard.AlwaysOnTop = true
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextStrokeTransparency = 0
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.Parent = billboard
        billboard.Parent = object
        return billboard
    end

    -- Function to update ESP
    local function UpdateEsp(objectId, petName)
        local object = getObjectFromId(objectId)
        if not object or not espCache[objectId] then return end
        local eggName = object:GetAttribute("EggName") or "Unknown Egg"
        local labelGui = espCache[objectId]
        if labelGui and labelGui:FindFirstChildOfClass("TextLabel") then
            labelGui.TextLabel.Text = string.format("%s | %s", eggName, petName or "?")
            labelGui.StudsOffset = Vector3.new(0, CalculateOffset(object), 0)
            UpdateEggList()
        end
    end

    -- Function to add ESP
    local function AddEsp(object)
        if not espEnabled then return end
        if object:GetAttribute("OWNER") ~= localPlayer.Name then
            print("Skipping egg not owned by player:", object.Name, "Owner:", object:GetAttribute("OWNER"))
            return
        end
        local objectId = object:GetAttribute("OBJECT_UUID")
        if not objectId then
            print("Skipping egg without OBJECT_UUID:", object.Name, "Path:", object:GetFullName())
            return
        end
        local eggName = object:GetAttribute("EggName") or "Unknown Egg"
        local petName = eggPets and eggPets[objectId] or "?"
        if not eggPets then
            print("eggPets is nil for egg:", object.Name, objectId)
        end
        if espCache[objectId] then
            espCache[objectId]:Destroy()
        end
        local yOffset = CalculateOffset(object)
        local esp = CreateEspGui(object, string.format("%s | %s", eggName, petName), yOffset)
        espCache[objectId] = esp
        activeEggs[objectId] = object
        print("Added ESP for egg:", eggName, "Pet:", petName, "ID:", objectId, "Offset:", yOffset)
        UpdateEggList()
    end

    -- Function to remove ESP
    local function RemoveEsp(object)
        if object:GetAttribute("OWNER") ~= localPlayer.Name then return end
        local objectId = object:GetAttribute("OBJECT_UUID")
        if espCache[objectId] then
            espCache[objectId]:Destroy()
            espCache[objectId] = nil
            activeEggs[objectId] = nil
            print("Removed ESP for egg:", object.Name, "ID:", objectId)
            for _, otherEgg in pairs(activeEggs) do
                UpdateEsp(otherEgg:GetAttribute("OBJECT_UUID"), eggPets and eggPets[otherEgg:GetAttribute("OBJECT_UUID")] or "?")
            end
            UpdateEggList()
        end
    end

    -- Minimize button click
    minimizeButton.MouseButton1Click:Connect(function()
        isGuiMinimized = not isGuiMinimized
        mainFrame.Visible = not isGuiMinimized
        minimizedIcon.Visible = isGuiMinimized
        minimizeButton.Text = isGuiMinimized and "+" or "-"
    end)

    -- Minimized icon click
    minimizedIcon.MouseButton1Click:Connect(function()
        isGuiMinimized = false
        mainFrame.Visible = true
        minimizedIcon.Visible = false
        minimizeButton.Text = "-"
        ShowNotification("GUI reopened")
    end)

    -- Close button click
    closeButton.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        minimizedIcon.Visible = true
    end)

    -- Keybind to reopen GUI
    userInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.E and not mainFrame.Visible then
            mainFrame.Visible = true
            minimizedIcon.Visible = false
            isGuiMinimized = false
            minimizeButton.Text = "-"
            ShowNotification("GUI reopened")
        end
    end)

    -- ESP toggle button click
    espToggleButton.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        espToggleButton.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
        espToggleButton.BackgroundColor3 = espEnabled and Color3.fromRGB(60, 80, 110) or Color3.fromRGB(60, 60, 60)
        if not espEnabled then
            for objectId, esp in pairs(espCache) do
                esp:Destroy()
                espCache[objectId] = nil
                activeEggs[objectId] = nil
            end
        else
            for _, object in pairs(collectionService:GetTagged("PetEggServer")) do
                task.spawn(AddEsp, object)
            end
        end
        UpdateEggList()
    end)

    -- Hover effects for buttons
    local function addHoverEffect(button, tooltipText)
        local tooltip = Instance.new("TextLabel")
        tooltip.Size = UDim2.new(0, 100, 0, 20)
        tooltip.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        tooltip.TextColor3 = Color3.fromRGB(220, 220, 220)
        tooltip.Text = tooltipText
        tooltip.TextSize = 12
        tooltip.Visible = false
        tooltip.ZIndex = 5
        tooltip.Parent = mainFrame
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = button == minimizeButton and Color3.fromRGB(80, 80, 80) or
                button == closeButton and Color3.fromRGB(120, 70, 70) or
                (espEnabled and Color3.fromRGB(80, 100, 130) or Color3.fromRGB(80, 80, 80))
            tooltip.Position = UDim2.new(0, button.Position.X.Offset, 0, button.Position.Y.Offset - 25)
            tooltip.Visible = true
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = button == minimizeButton and Color3.fromRGB(60, 60, 60) or
                button == closeButton and Color3.fromRGB(100, 50, 50) or
                (espEnabled and Color3.fromRGB(60, 80, 110) or Color3.fromRGB(60, 60, 60))
            tooltip.Visible = false
        end)
    end
    addHoverEffect(espToggleButton, "Toggle ESP labels")
    addHoverEffect(minimizeButton, "Minimize/maximize GUI")
    addHoverEffect(closeButton, "Close GUI (Press E to reopen)")

    -- Debug eggs
    local function DebugEggs()
        print("Debugging player-owned eggs:")
        for _, object in pairs(collectionService:GetTagged("PetEggServer")) do
            if object:GetAttribute("OWNER") == localPlayer.Name then
                local objectId = object:GetAttribute("OBJECT_UUID") or "nil"
                local eggName = object:GetAttribute("EggName") or "Unknown Egg"
                local petName = eggPets and eggPets[objectId] or "Unknown"
                local hasEsp = espCache[objectId] and "Yes" or "No"
                print(string.format("Egg: %s, ID: %s, EggName: %s, Pet: %s, ESP: %s, Path: %s",
                    object.Name, objectId, eggName, petName, hasEsp, object:GetFullName()))
            end
        end
    end

    -- Initialize ESP and debug
    for _, object in pairs(collectionService:GetTagged("PetEggServer")) do
        task.spawn(AddEsp, object)
    end
    DebugEggs()

    -- Listen for egg additions/removals
    collectionService:GetInstanceAddedSignal("PetEggServer"):Connect(function(object)
        AddEsp(object)
        DebugEggs()
    end)
    collectionService:GetInstanceRemovedSignal("PetEggServer"):Connect(RemoveEsp)

    -- Hook egg hatch event with enhanced error handling
    local old
    if eggPets then
        local gameEvents = replicatedStorage:FindFirstChild("GameEvents")
        if gameEvents and gameEvents:FindFirstChild("EggReadyToHatch_RE") then
            local hookSuccess, hookErr = pcall(function()
                local connections = getconnections(gameEvents.EggReadyToHatch_RE.OnClientEvent)
                if not connections or #connections == 0 then
                    error("No connections found for EggReadyToHatch_RE.OnClientEvent")
                end
                old = hookfunction(connections[1].Function, newcclosure(function(objectId, petName)
                    UpdateEsp(objectId, petName)
                    return old(objectId, petName)
                end))
            end)
            if not hookSuccess then
                warn("Failed to hook EggReadyToHatch_RE: " .. tostring(hookErr))
                ShowError("Failed to hook egg hatch event. ESP updates may not work.")
            end
        else
            warn("EggReadyToHatch_RE not found in GameEvents. Skipping hook.")
        end
    else
        print("eggPets is nil, skipping EggReadyToHatch_RE hook.")
    end

    -- Update initial UI state
    UpdateStatus()
    UpdateEggList()

    -- Confirm script loaded
    print("Grow a Garden ESP script loaded successfully at " .. os.date("%I:%M %p IST, %A, %B %d, %Y"))
end)

-- Handle script loading errors
if not success then
    local errorMessage = "Script failed to load: " .. tostring(scriptError)
    warn(errorMessage)
    local fallbackGui = Instance.new("ScreenGui")
    fallbackGui.Name = "ErrorGui"
    fallbackGui.Parent = players.LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("StarterGui")
    local errorFrame = Instance.new("Frame")
    errorFrame.Size = UDim2.new(0, 300, 0, 100)
    errorFrame.Position = UDim2.new(0.5, -150, 0.5, -50)
    errorFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    errorFrame.Parent = fallbackGui
    local errorText = Instance.new("TextLabel")
    errorText.Size = UDim2.new(0.9, 0, 0.8, 0)
    errorText.Position = UDim2.new(0.05, 0, 0.1, 0)
    errorText.BackgroundTransparency = 1
    errorText.Text = errorMessage
    errorText.TextColor3 = Color3.fromRGB(255, 255, 255)
    errorText.TextSize = 14
    errorText.TextWrapped = true
    errorText.Parent = errorFrame
        end
