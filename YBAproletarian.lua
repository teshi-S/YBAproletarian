-- ============================================================================
-- YBA Farm Script - Version Optimisée
-- ============================================================================

-- ============================================================================
-- INITIALISATION ET VALIDATION
-- ============================================================================

if not getgenv().Config then
    warn("❌ Configuration non trouvée! Assurez-vous d'exécuter le script de configuration d'abord.")
    return
end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

-- Essayer de récupérer DataStoreService si disponible (pour la persistance)
local DataStoreService = pcall(function() return game:GetService("DataStoreService") end) and game:GetService("DataStoreService") or nil

-- Variables globales du joueur (cache pour performance)
local Player = Players.LocalPlayer
local Config = getgenv().Config

-- Cache pour éviter les appels répétés
local function GetConfig(key)
    return Config[key]
end

local function GetConfigValue(path)
    local current = Config
    for part in path:gmatch("[^%.]+") do
        current = current and current[part]
    end
    return current
end

-- ============================================================================
-- MODULE: DEBUG
-- ============================================================================

local Debug = {
    MaxItems = {
        ["Mysterious Arrow"] = 25,
        ["Rokakaka"] = 25,
        ["Pure Rokakaka"] = 25,
        ["Rib Cage of The Saint's Corpse"] = 10,
        ["Steel Ball"] = 10,
        ["Zeppelin's Headband"] = 10,
        ["Ancient Scroll"] = 10,
        ["Quinton's Glove"] = 10,
        ["Stone Mask"] = 10,
        ["Gold Coin"] = 45,
        ["Diamond"] = 30,
        ["Lucky Arrow"] = 1000,
        ["Lucky Stone Mask"] = 1000,
        ["Dio's Diary"] = 100,
        ["Yellow Candy"] = 100,
        ["Red Candy"] = 100,
        ["Blue Candy"] = 100,
        ["Green Candy"] = 100
    },
    
    Log = function(message, type)
        if not Config.Debug then return end
        local prefix = "[YBA Farm] "
        if type == "warn" then
            warn(prefix .. message)
        elseif type == "error" then
            error(prefix .. message)
        else
            print(prefix .. message)
        end
    end
}

-- ============================================================================
-- MODULE: PERSISTENT STORAGE
-- ============================================================================

local PersistentStorage = {
    DataStore = nil,
    UserKey = nil,
    SaveInterval = 60, -- Par défaut: sauvegarder toutes les 60 secondes
    LastSave = 0,
    
    Init = function()
        -- Utiliser l'intervalle depuis la config si disponible
        if Config.PersistentStorage and Config.PersistentStorage.SaveInterval then
            PersistentStorage.SaveInterval = Config.PersistentStorage.SaveInterval
        end
        -- Créer une clé unique pour l'utilisateur
        local userId = Player.UserId
        PersistentStorage.UserKey = "YBAFarm_" .. tostring(userId)
        
        -- Essayer d'initialiser DataStore si disponible
        if DataStoreService then
            local success, result = pcall(function()
                PersistentStorage.DataStore = DataStoreService:GetDataStore("YBAFarmStats", userId)
            end)
            
            if success then
                Debug.Log("✓ DataStore initialisé (sauvegarde cloud)", "print")
            else
                Debug.Log("⚠ DataStore non disponible, utilisation du stockage local", "warn")
            end
        end
        
        -- Initialiser le stockage local dans getgenv si DataStore n'est pas disponible
        if not PersistentStorage.DataStore then
            if not getgenv().YBAFarmLocalStorage then
                getgenv().YBAFarmLocalStorage = {}
            end
            Debug.Log("✓ Stockage local initialisé (sauvegarde session)", "print")
        end
    end,
    
    Save = function(data)
        if PersistentStorage.DataStore then
            -- Sauvegarde via DataStore (persiste entre toutes les sessions)
            local success, err = pcall(function()
                PersistentStorage.DataStore:SetAsync(PersistentStorage.UserKey, data)
            end)
            
            if success then
                Debug.Log("✓ Données sauvegardées dans le cloud", "print")
                return true
            else
                Debug.Log("⚠ Erreur sauvegarde cloud: " .. tostring(err), "warn")
                -- Fallback sur stockage local
                getgenv().YBAFarmLocalStorage[PersistentStorage.UserKey] = data
                Debug.Log("✓ Données sauvegardées localement (fallback)", "print")
                return true
            end
        else
            -- Sauvegarde locale (persiste dans l'executor)
            getgenv().YBAFarmLocalStorage[PersistentStorage.UserKey] = data
            Debug.Log("✓ Données sauvegardées localement", "print")
            return true
        end
    end,
    
    Load = function()
        if PersistentStorage.DataStore then
            -- Chargement depuis DataStore
            local success, data = pcall(function()
                return PersistentStorage.DataStore:GetAsync(PersistentStorage.UserKey)
            end)
            
            if success and data then
                Debug.Log("✓ Données chargées depuis le cloud", "print")
                return data
            else
                -- Fallback sur stockage local
                local localData = getgenv().YBAFarmLocalStorage and getgenv().YBAFarmLocalStorage[PersistentStorage.UserKey]
                if localData then
                    Debug.Log("✓ Données chargées depuis le stockage local", "print")
                    return localData
                end
            end
        else
            -- Chargement depuis stockage local
            local localData = getgenv().YBAFarmLocalStorage and getgenv().YBAFarmLocalStorage[PersistentStorage.UserKey]
            if localData then
                Debug.Log("✓ Données chargées depuis le stockage local", "print")
                return localData
            end
        end
        
        Debug.Log("ℹ Aucune donnée sauvegardée trouvée, démarrage avec des statistiques vides", "print")
        return nil
    end,
    
    Export = function(data)
        -- Exporte les données en JSON (pour sauvegarde manuelle)
        if data then
            local json = HttpService:JSONEncode(data)
            Debug.Log("=== EXPORT DES DONNÉES ===", "print")
            print(json)
            Debug.Log("=== FIN EXPORT ===", "print")
            return json
        end
        return nil
    end,
    
    Import = function(json)
        -- Importe les données depuis JSON
        if json then
            local success, data = pcall(function()
                return HttpService:JSONDecode(json)
            end)
            
            if success and data then
                PersistentStorage.Save(data)
                Debug.Log("✓ Données importées avec succès", "print")
                return data
            else
                Debug.Log("⚠ Erreur lors de l'import des données", "error")
                return nil
            end
        end
        return nil
    end,
    
    AutoSave = function()
        local currentTime = os.time()
        if currentTime - PersistentStorage.LastSave >= PersistentStorage.SaveInterval then
            PersistentStorage.SaveStats()
            PersistentStorage.LastSave = currentTime
        end
    end
}

-- Initialiser le stockage persistant
PersistentStorage.Init()

-- ============================================================================
-- MODULE: STATISTICS
-- ============================================================================

local Statistics = {
    StartTime = os.time(),
    ItemsCollected = {},
    ItemsSold = {},
    TotalCollected = 0,
    TotalSold = 0,
    ServerHops = 0,
    LastSessionStart = os.time(),
    
    -- Charger les statistiques depuis le stockage persistant
    Load = function()
        local savedData = PersistentStorage.Load()
        
        if savedData then
            Statistics.ItemsCollected = savedData.ItemsCollected or {}
            Statistics.ItemsSold = savedData.ItemsSold or {}
            Statistics.TotalCollected = savedData.TotalCollected or 0
            Statistics.TotalSold = savedData.TotalSold or 0
            Statistics.ServerHops = savedData.ServerHops or 0
            Statistics.StartTime = savedData.StartTime or os.time()
            Statistics.LastSessionStart = savedData.LastSessionStart or os.time()
            
            Debug.Log("✓ Statistiques chargées: " .. Statistics.TotalCollected .. " items collectés, " .. Statistics.TotalSold .. " items vendus", "print")
            Debug.Log("✓ Temps total de farm: " .. Statistics.FormatTime(Statistics.GetRuntime()), "print")
            
            return true
        else
            Debug.Log("ℹ Nouvelle session - statistiques réinitialisées", "print")
            Statistics.StartTime = os.time()
            Statistics.LastSessionStart = os.time()
            return false
        end
    end,
    
    -- Sauvegarder les statistiques
    Save = function()
        local dataToSave = {
            ItemsCollected = Statistics.ItemsCollected,
            ItemsSold = Statistics.ItemsSold,
            TotalCollected = Statistics.TotalCollected,
            TotalSold = Statistics.TotalSold,
            ServerHops = Statistics.ServerHops,
            StartTime = Statistics.StartTime,
            LastSessionStart = Statistics.LastSessionStart,
            LastSaveTime = os.time(),
            Version = "1.0"
        }
        
        return PersistentStorage.Save(dataToSave)
    end,
    
    AddCollected = function(itemName)
        Statistics.TotalCollected = Statistics.TotalCollected + 1
        Statistics.ItemsCollected[itemName] = (Statistics.ItemsCollected[itemName] or 0) + 1
    end,
    
    AddSold = function(itemName)
        Statistics.TotalSold = Statistics.TotalSold + 1
        Statistics.ItemsSold[itemName] = (Statistics.ItemsSold[itemName] or 0) + 1
    end,
    
    GetRuntime = function()
        return os.time() - Statistics.StartTime
    end,
    
    GetSessionRuntime = function()
        return os.time() - Statistics.LastSessionStart
    end,
    
    FormatTime = function(seconds)
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        local secs = seconds % 60
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end,
    
    GetSummary = function()
        return {
            TotalCollected = Statistics.TotalCollected,
            TotalSold = Statistics.TotalSold,
            ServerHops = Statistics.ServerHops,
            TotalRuntime = Statistics.FormatTime(Statistics.GetRuntime()),
            SessionRuntime = Statistics.FormatTime(Statistics.GetSessionRuntime()),
            ItemsCollected = Statistics.ItemsCollected,
            ItemsSold = Statistics.ItemsSold
        }
    end
}

-- Fonction pour sauvegarder (accessible depuis PersistentStorage)
PersistentStorage.SaveStats = function()
    return Statistics.Save()
end

-- Charger les statistiques au démarrage
Statistics.Load()

-- ============================================================================
-- MODULE: WEBHOOK
-- ============================================================================

local Webhook = {
    RareItems = {
        ["Lucky Arrow"] = true,
        ["Lucky Stone Mask"] = true,
        ["Dio's Diary"] = true,
        ["Pure Rokakaka"] = true
    },
    
    IsRareItem = function(itemName)
        return Webhook.RareItems[itemName] == true
    end,
    
    ShouldPing = function(itemName, eventType)
        if not Config.Webhook or not Config.Webhook.Enabled then return false end
        local webhook = Config.Webhook
        
        if eventType == "collect" then
            return (webhook.PingOnRare and Webhook.IsRareItem(itemName)) or
                   (webhook.PingOnItem and webhook.PingItems and webhook.PingItems[itemName])
        elseif eventType == "sell" then
            return webhook.PingOnSell == true
        end
        return false
    end,
    
    GetItemColor = function(itemName)
        return Webhook.IsRareItem(itemName) and 16776960 or 65280
    end,
    
    Send = function(title, description, color, fields, ping)
        if not Config.Webhook or not Config.Webhook.Enabled then return end
        
        local webhookUrl = Config.Webhook.URL
        if not webhookUrl or webhookUrl == "" then
            Debug.Log("URL du webhook non configurée", "warn")
            return
        end
        
        local payload = {
            ["content"] = ping and "<@everyone>" or "",
            ["embeds"] = {{
                ["title"] = title,
                ["description"] = description,
                ["color"] = color or 3447003,
                ["fields"] = fields or {},
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                ["footer"] = {["text"] = "YBA Farm Bot"}
            }}
        }
        
        pcall(function()
            HttpService:PostAsync(webhookUrl, HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
        end)
    end,
    
    NotifyCollect = function(itemName)
        if not Config.Webhook or not Config.Webhook.ShowCollect then return end
        
        local shouldPing = Webhook.ShouldPing(itemName, "collect")
        local isRare = Webhook.IsRareItem(itemName)
        
        Webhook.Send(
            isRare and "🎉 Item Rare Collecté!" or "✅ Item Collecté",
            "**" .. itemName .. "** a été collecté avec succès!",
            Webhook.GetItemColor(itemName),
            {
                {["name"] = "📦 Total Collecté", ["value"] = tostring(Statistics.ItemsCollected[itemName] or 1), ["inline"] = true},
                {["name"] = "⏱️ Temps de farm", ["value"] = Statistics.FormatTime(Statistics.GetRuntime()), ["inline"] = true},
                {["name"] = "📊 Total Items", ["value"] = tostring(Statistics.TotalCollected), ["inline"] = true}
            },
            shouldPing
        )
    end,
    
    NotifySell = function(itemName, count)
        if not Config.Webhook or not Config.Webhook.ShowSell then return end
        
        Webhook.Send(
            "💰 Item Vendu",
            "**" .. itemName .. "** (x" .. (count or 1) .. ") a été vendu avec succès!",
            3066993,
            {
                {["name"] = "📦 Total Vendu", ["value"] = tostring(Statistics.ItemsSold[itemName] or 1), ["inline"] = true},
                {["name"] = "⏱️ Temps de farm", ["value"] = Statistics.FormatTime(Statistics.GetRuntime()), ["inline"] = true},
                {["name"] = "📊 Total Vendus", ["value"] = tostring(Statistics.TotalSold), ["inline"] = true}
            },
            Webhook.ShouldPing(itemName, "sell")
        )
    end,
    
    NotifyStats = function()
        if not Config.Webhook or not Config.Webhook.ShowStats then return end
        
        local topItems = {}
        for itemName, count in pairs(Statistics.ItemsCollected) do
            table.insert(topItems, {name = itemName, count = count})
        end
        table.sort(topItems, function(a, b) return a.count > b.count end)
        
        local top3Text = ""
        for i = 1, math.min(3, #topItems) do
            top3Text = top3Text .. string.format("%d. **%s** (x%d)\n", i, topItems[i].name, topItems[i].count)
        end
        
        local fields = {
            {["name"] = "📦 Items Collectés", ["value"] = tostring(Statistics.TotalCollected), ["inline"] = true},
            {["name"] = "💰 Items Vendus", ["value"] = tostring(Statistics.TotalSold), ["inline"] = true},
            {["name"] = "🌐 Changements de Serveur", ["value"] = tostring(Statistics.ServerHops), ["inline"] = true}
        }
        
        if #topItems > 0 then
            table.insert(fields, {["name"] = "🏆 Top 3 Items", ["value"] = top3Text, ["inline"] = false})
        end
        
        Webhook.Send(
            "📊 Statistiques de Farm",
            "Rapport de farm depuis **" .. Statistics.FormatTime(Statistics.GetRuntime()) .. "**",
            15844367,
            fields,
            false
        )
    end
}

-- ============================================================================
-- MODULE: NOTIFICATIONS
-- ============================================================================

local function NotifyItemCollect(itemName)
    if not Config.ItemNotifications or not Config.ItemNotifications.Enabled then return end
    
    local notifConfig = Config.ItemNotifications
    if not notifConfig.NotifyItems or not notifConfig.NotifyItems[itemName] then return end
    
    StarterGui:SetCore("SendNotification", {
        Title = "🎉 Item Important!",
        Text = itemName .. " collecté!",
        Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Duration = notifConfig.NotificationDuration or 5,
        Button1 = "OK"
    })
    
    if notifConfig.SoundNotification then
        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
            sound.Volume = 0.5
            sound.Parent = Workspace
            sound:Play()
            sound.Ended:Connect(function() sound:Destroy() end)
        end)
    end
    
    Debug.Log("🎉 ITEM IMPORTANT COLLECTÉ: " .. itemName, "print")
    
    if Config.Webhook and Config.Webhook.Enabled then
        Webhook.Send(
            "🎉 Item Important Collecté!",
            "**" .. itemName .. "** a été collecté avec succès!",
            Webhook.GetItemColor(itemName),
            {
                {["name"] = "📦 Total", ["value"] = tostring(Statistics.ItemsCollected[itemName] or 1), ["inline"] = true},
                {["name"] = "⏱️ Temps", ["value"] = Statistics.FormatTime(Statistics.GetRuntime()), ["inline"] = true}
            },
            true
        )
    end
end

-- ============================================================================
-- MODULE: UTILITAIRES
-- ============================================================================

local Utils = {
    GetCharacter = function()
        return Player.Character or Player.CharacterAdded:Wait()
    end,
    
    GetItems = function()
        local itemSpawns = Workspace:WaitForChild("Item_Spawns", 10)
        if not itemSpawns then return {} end
        local items = itemSpawns:WaitForChild("Items", 10)
        return items and items:GetChildren() or {}
    end,
    
    ShouldCollectItem = function(itemName)
        return not Config.Items or Config.Items[itemName] == true
    end,
    
    IsRealModel = function(model)
        if not model or not model:IsA("Model") then return false end
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency < 1 then
                return true
            end
        end
        return false
    end,
    
    GetItemName = function(instance)
        local prompt = instance:FindFirstChild("ProximityPrompt", true)
        return prompt and prompt.ObjectText or "Unknown Item"
    end
}

-- ============================================================================
-- MODULE: PROTECTION ET BYPASS
-- ============================================================================

local Protection = {
    Setup = function()
        if not Config.Protection then return end
        
        local prot = Config.Protection
        
        -- Anti-Kick
        if prot.AntiKick then
            Player.Idled:Connect(function()
                game:GetService("VirtualUser"):ClickButton2(Vector2.new())
            end)
            
            local OldKick = Player.Kick
            Player.Kick = function(self, reason)
                Debug.Log("Tentative de kick bloquée: " .. tostring(reason), "warn")
                return nil
            end
        end
        
        -- Anti-TP Detection
        local OldNamecallTP = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
            local Arguments = {...}
            local Method = getnamecallmethod()
            
            if Method == "InvokeServer" and Arguments[1] == "idklolbrah2de" then
                return "  ___XP DE KEY"
            end
            
            if prot.AntiTeleport and (Method == "FireServer" or Method == "InvokeServer") then
                if type(Arguments[1]) == "string" and 
                   (Arguments[1]:lower():find("teleport") or Arguments[1]:lower():find("tp")) then
                    Debug.Log("Tentative de vérification TP bloquée", "print")
                    return nil
                end
            end
            
            return OldNamecallTP(self, ...)
        end))
        
        -- Item Magnitude Bypass et Protection de vitesse
        if prot.AntiDistanceCheck then
            local OldIndexItem = hookmetamethod(game, "__index", newcclosure(function(self, Key)
                if not checkcaller() then
                    local callingScript = getcallingscript()
                    
                    if typeof(self) == "Vector3" and Key:lower() == "magnitude" then
                        if callingScript and (callingScript.Name == "ItemSpawn" or callingScript.Name:find("Item")) then
                            return 0
                        end
                    end
                    
                    if (typeof(self) == "HumanoidRootPart" or (self:IsA("BasePart") and Key == "Position")) then
                        if callingScript and callingScript.Name:find("Check") then
                            return Vector3.new(0, 0, 0)
                        end
                    end
                    
                    if self:IsA("Humanoid") and (Key == "WalkSpeed" or Key == "JumpPower") then
                        if callingScript and callingScript.Name:find("Check") then
                            return Key == "WalkSpeed" and 16 or 50
                        end
                    end
                end
                return OldIndexItem(self, Key)
            end))
        end
        
        -- Bypass vérification d'items
        if prot.AntiItemCheck then
            local OldNamecallCheck = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
                if not checkcaller() then
                    local Method = getnamecallmethod()
                    local Arguments = {...}
                    
                    if (Method == "FireServer" or Method == "InvokeServer") and type(Arguments[1]) == "string" then
                        if Arguments[1]:lower():find("check") or Arguments[1]:lower():find("verify") then
                            local callingScript = getcallingscript()
                            if callingScript and callingScript.Name:find("Item") then
                                Debug.Log("Vérification d'item bloquée", "print")
                                return nil
                            end
                        end
                    end
                end
                return OldNamecallCheck(self, ...)
            end))
        end
        
        -- Protection FunctionLibrary
        local FunctionLibrary = require(ReplicatedStorage:WaitForChild('Modules').FunctionLibrary)
        local OldPcall = FunctionLibrary.pcall
        FunctionLibrary.pcall = function(...)
            local f = select(1, ...)
            if type(f) == 'function' and #getupvalues(f) == 11 then
                return
            end
            return OldPcall(...)
        end
        
        Debug.Log("✓ Systèmes de protection initialisés", "print")
    end,
    
    ForceMovement = {
        Enabled = false,
        
        Force = function(character, position)
            if not Config.Protection or not Config.Protection.ForceMovement then return false end
            if not character or not character.PrimaryPart then return false end
            
            local humanoid = character:FindFirstChild("Humanoid")
            if not humanoid then return false end
            
            pcall(function()
                character:SetPrimaryPartCFrame(CFrame.new(position))
                if character.PrimaryPart then
                    character.PrimaryPart.CFrame = CFrame.new(position)
                end
                humanoid:MoveTo(position)
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    rootPart.CFrame = CFrame.new(position)
                end
            end)
            
            return true
        end
    }
}

-- Initialiser les protections
if Config.Protection then
    Protection.Setup()
    if Config.Protection.ForceMovement then
        Protection.ForceMovement.Enabled = true
        Debug.Log("Système de mouvement forcé activé", "print")
    end
end

-- ============================================================================
-- MODULE: TÉLÉPORTATION
-- ============================================================================

local Teleport = {
    LastTeleport = 0,
    Cooldown = Config.TeleportCooldown or 5, -- Cooldown configurable (par défaut 5 secondes)
    
    To = function(position)
        local character = Utils.GetCharacter()
        if not character or not character.PrimaryPart then return false end
        
        local currentTime = os.clock()
        if currentTime - Teleport.LastTeleport < Teleport.Cooldown then return false end
        
        local targetPos = position + Vector3.new(0, 3, 0)
        
        if Protection.ForceMovement.Enabled then
            Protection.ForceMovement.Force(character, targetPos)
        else
            pcall(function()
                character:SetPrimaryPartCFrame(CFrame.new(targetPos))
            end)
        end
        
        Teleport.LastTeleport = currentTime
        return true
    end
}

-- ============================================================================
-- MODULE: COLLECTE D'ITEMS
-- ============================================================================

local ItemCollector = {
    Collect = function(item, prompt)
        local targetPos = (item:IsA("Model") and item.PrimaryPart and item.PrimaryPart.Position) or
                          (item:IsA("BasePart") and item.Position)
        
        if not targetPos then return end
        
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "YBA Farm",
                Text = "Téléportation vers: " .. (prompt.ObjectText or "Item"),
                Duration = 3
            })
            
            Teleport.To(targetPos)
            
            prompt.MaxActivationDistance = math.huge
            fireproximityprompt(prompt)
            
            if prompt.ObjectText then
                local itemName = prompt.ObjectText
                print("Collecté: " .. itemName)
                
                Statistics.AddCollected(itemName)
                Webhook.NotifyCollect(itemName)
                NotifyItemCollect(itemName)
            end
        end)
    end,
    
    GetAvailableItems = function()
        local items = Utils.GetItems()
        local availableItems = {}
        
        for _, item in ipairs(items) do
            if Utils.IsRealModel(item) then
                local prompt = item:FindFirstChild("ProximityPrompt", true)
                if prompt and Utils.ShouldCollectItem(prompt.ObjectText) then
                    table.insert(availableItems, {item = item, prompt = prompt})
                end
            end
        end
        
        return availableItems
    end,
    
    CollectAll = function()
        local availableItems = ItemCollector.GetAvailableItems()
        
        if #availableItems == 0 then
            StarterGui:SetCore("SendNotification", {
                Title = "YBA Farm",
                Text = "Aucun item disponible" .. (Config.ServerHop and ", changement de serveur..." or ""),
                Duration = 3
            })
            
            if Config.ServerHop then
                task.wait(0.5)
                ServerHop.Execute()
            end
            return false
        end
        
        for _, data in ipairs(availableItems) do
            ItemCollector.Collect(data.item, data.prompt)
            task.wait(0.1)
        end
        
        return true
    end
}

-- ============================================================================
-- MODULE: VENTE D'ITEMS
-- ============================================================================

local ItemSeller = {
    Sell = function(itemName, itemToSell, character, backpack, remoteEvent)
        pcall(function()
            Debug.Log("Début du processus de vente pour " .. itemName, "print")
            
            local Tool = itemToSell:FindFirstChildOfClass("Tool")
            if Tool then Tool:Activate() end
            
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then humanoid:EquipTool(itemToSell) end
            
            character.RemoteEvent:FireServer("ToolHandler", itemToSell)
            task.wait(0.3)
            
            if itemToSell.Parent == character then
                remoteEvent:FireServer("EndDialogue", {
                    Dialogue = "Dialogue5",
                    NPC = "Merchant",
                    Option = "Option1"
                })
                
                task.wait(0.5)
                
                if not itemToSell or not itemToSell.Parent then
                    Debug.Log("✓ Vente réussie de " .. itemName, "print")
                    Statistics.AddSold(itemName)
                    Webhook.NotifySell(itemName, Statistics.ItemsSold[itemName] or 1)
                else
                    itemToSell.Parent = backpack
                    Debug.Log("⚠ Échec de la vente, item remis dans le backpack", "warn")
                end
            end
        end)
    end,
    
    CheckAndSell = function()
        if not Config.AutoSell or not Config.AutoSell.Enabled then return end
        
        local character = Utils.GetCharacter()
        if not character then return end
        
        local backpack = Player:WaitForChild("Backpack", 5)
        local remoteEvent = character:WaitForChild("RemoteEvent", 5)
        if not backpack or not remoteEvent then return end
        
        local maxItems = Config.MaxItems or Debug.MaxItems
        
        for itemName, maxCount in pairs(maxItems) do
            if not Config.SellItems or not Config.SellItems[itemName] then continue end
            
            local count = 0
            local itemToSell = nil
            
            for _, item in ipairs(backpack:GetChildren()) do
                if item.Name == itemName then
                    count = count + 1
                    if count == maxCount then
                        itemToSell = item
                        break
                    end
                end
            end
            
            if count == maxCount and itemToSell then
                Debug.Log(itemName .. " : Maximum atteint (" .. maxCount .. ") - Vente", "print")
                ItemSeller.Sell(itemName, itemToSell, character, backpack, remoteEvent)
                task.wait(1)
            end
        end
    end
}

-- ============================================================================
-- MODULE: ESP
-- ============================================================================

local ESP = {
    Folder = Instance.new("Folder"),
    
    Init = function()
        ESP.Folder.Name = "ItemESP"
        ESP.Folder.Parent = CoreGui
    end,
    
    Create = function(part, itemName)
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP"
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.AlwaysOnTop = true
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.Adornee = part
        
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
        
        billboard.Parent = ESP.Folder
        return billboard
    end,
    
    Update = function()
        for _, esp in ipairs(ESP.Folder:GetChildren()) do
            esp:Destroy()
        end
        
        if not Config.ESP then return end
        
        local items = Utils.GetItems()
        for _, item in ipairs(items) do
            if Utils.IsRealModel(item) then
                local primaryPart = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
                if primaryPart then
                    local itemName = Utils.GetItemName(item)
                    ESP.Create(primaryPart, itemName)
                end
            end
        end
    end
}

ESP.Init()

-- Optimisation ESP (update toutes les 0.5 secondes au lieu de chaque frame)
local lastESPUpdate = 0
local ESPUpdateInterval = 0.5
RunService.Heartbeat:Connect(function()
    if not Config.ESP then
        for _, esp in ipairs(ESP.Folder:GetChildren()) do
            esp:Destroy()
        end
        return
    end
    
    local currentTime = os.clock()
    if currentTime - lastESPUpdate >= ESPUpdateInterval then
        pcall(ESP.Update)
        lastESPUpdate = currentTime
    end
end)

-- ============================================================================
-- MODULE: SERVER HOP
-- ============================================================================

local ServerHop = {
    Execute = function()
        local placeId = game.PlaceId
        
        local function getServer()
            local servers = {}
            local serverIds = {}
            local currentTime = os.time()
            
            local success, req = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
                ))
            end)
            
            if not success or not req or not req.data then
                Debug.Log("Erreur lors de la récupération des serveurs", "warn")
                return nil
            end
            
            local serverPrefs = Config.ServerPreferences or {}
            local maxPlayers = serverPrefs.MaxPlayers or 6
            local minAge = serverPrefs.MinAge or 600
            
            for _, server in ipairs(req.data) do
                if server.id ~= game.JobId and not serverIds[server.id] then
                    local meetsPreferences = server.playing < maxPlayers and
                                           (currentTime - server.playing * 60) >= minAge
                    local hasSpace = server.playing < server.maxPlayers
                    
                    if meetsPreferences or hasSpace then
                        table.insert(servers, server.id)
                        serverIds[server.id] = true
                    end
                end
            end
            
            return #servers > 0 and servers[math.random(1, #servers)]
        end
        
        local serverId = getServer()
        if serverId then
            Statistics.ServerHops = Statistics.ServerHops + 1
            TeleportService:TeleportToPlaceInstance(placeId, serverId)
        end
    end
}

-- ============================================================================
-- MODULE: STATISTIQUES PÉRIODIQUES
-- ============================================================================

local PeriodicStats = {
    LastUpdate = 0,
    
    Check = function()
        if not Config.Webhook or not Config.Webhook.Enabled or not Config.Webhook.ShowStats then return end
        
        local currentTime = os.time()
        local interval = Config.Webhook.StatsInterval or 300
        
        if currentTime - PeriodicStats.LastUpdate >= interval then
            Webhook.NotifyStats()
            PeriodicStats.LastUpdate = currentTime
        end
    end
}

-- ============================================================================
-- INITIALISATION DU JEU
-- ============================================================================

pcall(function()
    local character = Utils.GetCharacter()
    if character and character:FindFirstChild("RemoteEvent") then
        character.RemoteEvent:FireServer("PressedPlay")
    end
end)

Player.CharacterAdded:Connect(function(character)
    task.wait(1)
    pcall(function()
        if character and character:FindFirstChild("RemoteEvent") then
            character.RemoteEvent:FireServer("PressedPlay")
        end
    end)
end)

-- ============================================================================
-- BOUCLE PRINCIPALE
-- ============================================================================

spawn(function()
    while true do
        pcall(function()
            Debug.Log("Début du cycle de farm", "print")
            
            ItemCollector.CollectAll()
            
            if Config.AutoSell and Config.AutoSell.Enabled then
                Debug.Log("Vérification des items à vendre...", "print")
                ItemSeller.CheckAndSell()
            end
            
            PeriodicStats.Check()
            
            -- Sauvegarde automatique périodique
            if Config.PersistentStorage and Config.PersistentStorage.AutoSave then
                PersistentStorage.AutoSave()
            end
            
            task.wait(0.1)
            
            if Config.ServerHop then
                Debug.Log("Changement de serveur...", "print")
                ServerHop.Execute()
                task.wait(1)
            end
        end)
        
        if Config.Debug then
            Debug.Log("Cycle terminé", "print")
        end
    end
end)

-- ============================================================================
-- SAUVEGARDE AVANT DE QUITTER
-- ============================================================================

-- Sauvegarder quand le joueur quitte le jeu
game:BindToClose(function()
    if Config.PersistentStorage and Config.PersistentStorage.AutoSave then
        Debug.Log("💾 Sauvegarde finale avant de quitter...", "print")
        Statistics.Save()
        wait(2) -- Attendre que la sauvegarde se termine
    end
end)

-- Sauvegarder quand le joueur quitte le serveur
Player.PlayerRemoving:Connect(function()
    if Config.PersistentStorage and Config.PersistentStorage.AutoSave then
        Debug.Log("💾 Sauvegarde avant de quitter le serveur...", "print")
        Statistics.Save()
    end
end)

-- Commandes pour sauvegarder/charger manuellement (accessible via la console)
spawn(function()
    -- Créer des fonctions globales pour les commandes
    getgenv().YBA_Save = function()
        if Statistics.Save() then
            print("✓ Statistiques sauvegardées avec succès!")
        else
            print("❌ Erreur lors de la sauvegarde")
        end
    end
    
    getgenv().YBA_Load = function()
        if Statistics.Load() then
            print("✓ Statistiques chargées avec succès!")
            local summary = Statistics.GetSummary()
            print("📊 Résumé:")
            print("  • Items collectés: " .. summary.TotalCollected)
            print("  • Items vendus: " .. summary.TotalSold)
            print("  • Changements de serveur: " .. summary.ServerHops)
            print("  • Temps total: " .. summary.TotalRuntime)
        else
            print("ℹ Aucune sauvegarde trouvée")
        end
    end
    
    getgenv().YBA_Export = function()
        local json = PersistentStorage.Export(Statistics.GetSummary())
        if json then
            print("✓ Données exportées (copiez le JSON ci-dessus)")
        end
    end
    
    getgenv().YBA_Stats = function()
        local summary = Statistics.GetSummary()
        print("=== STATISTIQUES YBA FARM ===")
        print("📦 Total collecté: " .. summary.TotalCollected)
        print("💰 Total vendu: " .. summary.TotalSold)
        print("🌐 Changements de serveur: " .. summary.ServerHops)
        print("⏱️ Temps total: " .. summary.TotalRuntime)
        print("⏱️ Temps session: " .. summary.SessionRuntime)
        print("============================")
    end
end)

Debug.Log("✓ Script initialisé avec succès", "print")
Debug.Log("💾 Système de stockage persistant activé", "print")
Debug.Log("📝 Commandes disponibles: YBA_Save(), YBA_Load(), YBA_Export(), YBA_Stats()", "print")
