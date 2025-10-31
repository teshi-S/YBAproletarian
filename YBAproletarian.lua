-- Configuration intégrée
-- Vérifier si la configuration existe déjà
if not getgenv().Config then
    warn("La configuration n'a pas été chargée. Assurez-vous d'exécuter le script de configuration d'abord.")
    return
end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Variables
local itemmodel = game:GetService("Workspace"):WaitForChild("Item_Spawns"):WaitForChild("Items"):GetChildren()
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
    
    for _, item in ipairs(itemmodel) do
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
-- Fonction pour obtenir et définir le nom de l'item
local function getItemName(instance)
    local prompt = instance:FindFirstChild("ProximityPrompt", true)
    if prompt and prompt.ObjectText then
        -- Renomme automatiquement le modèle parent avec le nom de l'item
        pcall(function()
            local model = prompt:FindFirstAncestorWhichIsA("Model")
            if model then
                model.Name = prompt.ObjectText
            end
        end)
        return prompt.ObjectText
    end
    return "Unknown Item"
end

-- Fonction pour mettre à jour les noms des modèles
local function updateModelNames()
    for _, item in ipairs(itemmodel) do
        if item:IsA("Model") then
            local prompt = item:FindFirstChild("ProximityPrompt", true)
            if prompt and prompt.ObjectText then
                pcall(function()
                    item.Name = prompt.ObjectText
                end)
            end
        end
    end
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
    -- Cooldown de 5 secondes
    if tick() - lastTeleport < 5 then return end
    
    -- Téléportation directe
    Character:SetPrimaryPartCFrame(CFrame.new(position + Vector3.new(0, 3, 0)))
    
    lastTeleport = tick()
    task.wait(5) -- Attendre 5 secondes avant la prochaine téléportation
end

-- Vérifier si un item doit être collecté
local function shouldCollectItem(itemName)
    if not getgenv().Config or not getgenv().Config.Items then return true end
    return getgenv().Config.Items[itemName] == true
end

-- Fonction pour vérifier s'il reste des items désirés
local function hasDesiredItems()
    for _, item in ipairs(itemmodel) do
        local prompt = item:FindFirstChild("ProximityPrompt", true)
        if prompt and prompt.ObjectText and shouldCollectItem(prompt.ObjectText) then
            return true
        end
    end
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "YBA Farm",
        Text = "Aucun item désiré trouvé, changement de serveur...",
        Duration = 5
    })
    return false
end

-- Fonction principale de collecte avec vérifications
local function collectItems()
    -- Rafraîchir la liste des items
    itemmodel = game:GetService("Workspace"):WaitForChild("Item_Spawns"):WaitForChild("Items"):GetChildren()
    
    for _, item in ipairs(itemmodel) do
        if isRealModel(item) then
            local prompt = item:FindFirstChild("ProximityPrompt", true)
            if prompt and shouldCollectItem(prompt.ObjectText) then
                local targetPos = item:IsA("Model") and item.PrimaryPart and item.PrimaryPart.Position or 
                                 (item:IsA("BasePart") and item.Position)
                
                if targetPos then
                    -- Téléportation et collecte avec délai
                    pcall(function()
                        -- Notification avant téléportation
                        game:GetService("StarterGui"):SetCore("SendNotification", {
                            Title = "YBA Farm",
                            Text = "Téléportation vers: " .. (prompt.ObjectText or "Item"),
                            Duration = 3
                        })
                        
                        -- Téléportation avec cooldown
                        teleportTo(targetPos)
                        
                        -- Collecte
                        prompt.MaxActivationDistance = math.huge
                        fireproximityprompt(prompt)
                        
                        if prompt.ObjectText then
                            print("Collecté: " .. prompt.ObjectText)
                        end
                    end)
                end
            end
        end
    end
    
    -- Après avoir collecté tous les items, changer de serveur
    if getgenv().Config.ServerHop then
        task.wait(0.5) -- Petit délai avant le changement de serveur
        hopServer()
    end
end

-- Mise à jour de l'ESP si activé
RunService.RenderStepped:Connect(function()
    if getgenv().Config.ESP then
        pcall(updateESP)
    else
        for _, esp in ipairs(ESPFolder:GetChildren()) do
            esp:Destroy()
        end
    end
end)

-- Initialisation du jeu
Character.RemoteEvent:FireServer("PressedPlay")
-- Fonction de changement de serveur
local function hopServer()
    local placeId = game.PlaceId
    
    -- Récupération des serveurs disponibles
    local function getServer()
        local servers = {}
        local currentTime = os.time()
        local req = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
        
        -- Filtrer les serveurs selon les préférences
        for _, server in ipairs(req.data) do
            if server.playing < (getgenv().Config.ServerPreferences.MaxPlayers or 6) and
               server.id ~= game.JobId and
               (currentTime - server.playing * 60) >= (getgenv().Config.ServerPreferences.MinAge or 600) then
                table.insert(servers, server.id)
            end
        end
        
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
            task.wait(0.1) -- Délai minimal
            if getgenv().Config.ServerHop then
                hopServer()
                task.wait(1)
            end
        end)
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
