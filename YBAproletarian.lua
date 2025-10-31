-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Variables
local itemmodel = game.Workspace.Item_Spawns.Items.Model
local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local FunctionLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild('Modules').FunctionLibrary)

-- Anti-Crash Protection
local Old = FunctionLibrary.pcall
FunctionLibrary.pcall = function(...)
    local f = ...
    if type(f) == 'function' and #getupvalues(f) == 11 then
        return
    end
    return Old(...)
end

-- Anti-TP Detection
local OldNamecallTP
OldNamecallTP = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
    local Arguments = {...}
    local Method = getnamecallmethod()
    
    if Method == "InvokeServer" and Arguments[1] == "idklolbrah2de" then
        return "  ___XP DE KEY"
    end
    
    return OldNamecallTP(self, ...)
end))

-- Item Magnitude Bypass
local OldIndexItem
OldIndexItem = hookmetamethod(game, "__index", newcclosure(function(self, Key)
    if not checkcaller() and 
       typeof(self) == "Vector3" and 
       Key:lower() == "magnitude" and 
       getcallingscript().Name == "ItemSpawn" then
        return 0
    end
    return OldIndexItem(self, Key)
end))
local Old = FunctionLibrary.pcall

-- ESP Configuration
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ItemESP"
ESPFolder.Parent = game:GetService("CoreGui")

-- Anti-détection des faux modèles
local function isRealModel(model)
    if not model or not model:IsA("Model") then return false end
    local hasValidParts = false
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 1 then
            hasValidParts = true
            break
        end
    end
    return hasValidParts
end

-- Anti-détection
FunctionLibrary.pcall = function(...)
    local f = ...
    if type(f) == 'function' and #getupvalues(f) == 11 then
        return
    end
    return Old(...)
end

-- Hook pour la distance
local OldIndexItem
OldIndexItem = hookmetamethod(game, "__index", newcclosure(function(self, Key)
    if not checkcaller() and 
       typeof(self) == "Vector3" and 
       Key:lower() == "magnitude" and 
       getcallingscript().Name == "ItemSpawn" then
        return 0
    end
    return OldIndexItem(self, Key)
end))

-- ESP System avec nom d'item
local function createESP(part, itemName)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP"
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextScaled = true
    textLabel.Text = itemName or "ITEM"
    
    textLabel.Parent = billboard
    billboard.Parent = ESPFolder
    billboard.Adornee = part
    
    return billboard
end

local function updateESP()
    for _, esp in ipairs(ESPFolder:GetChildren()) do
        esp:Destroy()
    end
    
    for _, item in ipairs(itemmodel:GetChildren()) do
        if isRealModel(item) then
            local part = item:IsA("Model") and item.PrimaryPart or item
            if part then
                local itemName = getItemName(item)
                createESP(part, itemName)
            end
        end
    end
end

-- PressedPlay Initialization
game:GetService("Players").LocalPlayer.Character.RemoteEvent:FireServer("PressedPlay")

-- Fonctions utilitaires avec anti-détection
-- Fonction pour obtenir le nom de l'item
local function getItemName(instance)
    local prompt = instance:FindFirstChild("ProximityPrompt", true)
    if prompt then
        return prompt.ObjectText
    end
    return "Unknown Item"
end

-- Anti Ghost-Item et activation des prompts
local function activateProximityPrompts(instance)
    for _, prompt in ipairs(instance:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            -- Vérification anti ghost-item
            if prompt.MaxActivationDistance ~= 0 then
                pcall(function()
                    -- Augmente la distance d'activation
                    prompt.MaxActivationDistance = math.huge
                    -- Essaie d'activer plusieurs fois pour assurer la collecte
                    for i = 1, 3 do
                        fireproximityprompt(prompt)
                        task.wait(0.1)
                    end
                    -- Vérifie si l'item a bien un nom (pour confirmer que c'est un vrai item)
                    if prompt.ObjectText and prompt.ObjectText ~= "" then
                        print("Item collecté: " .. prompt.ObjectText)
                    end
                end)
            end
        end
    end
end

local lastTeleport = 0
local function teleportTo(position)
    -- Cooldown et anti-détection pour la téléportation
    if tick() - lastTeleport < 6 then return end
    
    local originalCFrame = Character.PrimaryPart.CFrame
    local targetCFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    
    -- Simulation de mouvement naturel
    for i = 0, 1, 0.1 do
        Character:SetPrimaryPartCFrame(originalCFrame:Lerp(targetCFrame, i))
        wait()
    end
    
    lastTeleport = tick()
    wait(0.1)
end

-- Fonction principale de collecte avec vérifications
local function collectItems()
    for _, item in ipairs(itemmodel:GetChildren()) do
        if isRealModel(item) then
            local targetPos = item:IsA("Model") and item.PrimaryPart and item.PrimaryPart.Position or 
                             (item:IsA("BasePart") and item.Position)
            
            if targetPos then
                -- Anti-détection pour la collecte
                local success = pcall(function()
                    -- Téléportation vers l'item
                    teleportTo(targetPos)
                    
                    -- Essaie de trouver le ProximityPrompt
                    local prompt = item:FindFirstChild("ProximityPrompt", true)
                    if prompt and prompt.MaxActivationDistance ~= 0 then
                        -- Collecte l'item
                        activateProximityPrompts(item)
                        
                        -- Vérifie si l'item a été collecté
                        wait(0.5) -- Attend un peu pour la collecte
                        if not prompt or not prompt.Parent then
                            print("Item collecté avec succès!")
                        end
                    end
                end)
                
                if not success then
                    wait(1)  -- Attendre en cas d'échec
                    continue
                end
                
                wait(6)  -- Cooldown entre chaque modèle
            end
        end
    end
end

-- Mise à jour de l'ESP
RunService.RenderStepped:Connect(function()
    pcall(updateESP)
end)

-- Initialisation du jeu
Character.RemoteEvent:FireServer("PressedPlay")
-- Fonction de changement de serveur
local function hopServer()
    local placeId = game.PlaceId
    
    -- Récupération des serveurs disponibles
    local function getServer()
        local servers = {}
        local req = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
        
        for _, server in ipairs(req.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                table.insert(servers, server.id)
            end
        end
        
        return #servers > 0 and servers[math.random(1, #servers)]
    end
    
    local serverId = getServer()
    if serverId then
        TeleportService:TeleportToPlaceInstance(placeId, serverId)
    end
end

-- Protection supplémentaire
local OldNamecallTP
OldNamecallTP = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local Arguments = {...}
    local Method = getnamecallmethod()
    
    if Method == "InvokeServer" and Arguments[1] == "idklolbrah2de" then
        return "  ___XP DE KEY"
    end
    
    return OldNamecallTP(self, ...)
end))

-- Boucle principale d'exécution
spawn(function()
    while true do
        pcall(function()
            collectItems()
            wait(1)
            hopServer()
            wait(5)
        end)
        wait(1)
    end
end) 

local OldNamecallTP;
OldNamecallTP = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
    local Arguments = {...}
    local Method =  getnamecallmethod()
 
    if Method == "InvokeServer" and Arguments[1] == "idklolbrah2de" then
        return "  ___XP DE KEY"
    end
 
    return OldNamecallTP(self, ...)
end))

-- Fonction pour téléporter vers tous les enfants de itemmodel
local function teleportToAllChildren()
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    
    for _, child in ipairs(itemmodel:GetChildren()) do
        if child:IsA("BasePart") or (child:IsA("Model") and child.PrimaryPart) then
            local targetPos = child:IsA("Model") and child.PrimaryPart.Position or child.Position
            character:MoveTo(targetPos + Vector3.new(0, 3, 0))
            
            -- Activer les ProximityPrompts s'ils existent
            for _, prompt in ipairs(child:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then
                    fireproximityprompt(prompt)
                end
            end
            
            wait(0.5) -- Attendre entre chaque téléportation
        end
    end
end

-- Fonction pour changer de serveur
local function hopServer()
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local placeId = game.PlaceId
    
    local servers = {}
    local req = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100"))
    
    for _, server in ipairs(req.data) do
        if server.playing < server.maxPlayers and server.id ~= game.JobId then
            table.insert(servers, server.id)
        end
    end
    
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(placeId, servers[math.random(1, #servers)])
    end
end

-- Boucle principale
while true do
    teleportToAllChildren() -- Téléporter et collecter
    wait(1) -- Attendre que tout soit collecté
    hopServer() -- Changer de serveur
    wait(5) -- Attendre avant de recommencer dans le nouveau serveur
end
