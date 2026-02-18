local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local EVENT_COUNTDOWN = 20
local TRIGGER_PART_NAME = "EventTriggerPart"
local GUI_NAME = "RandomEventGui"
local TRIGGER_ARM_DELAY = 3
local SPECIAL_EVENT_CHANCE_PERCENT = 5
local TSUNAMI_MAX_CLASS = 12
local TSUNAMI_SPAWN_DISTANCE = 400
local TSUNAMI_DESPAWN_SECONDS = 180
local TSUNAMI_SPAWN_CLEARANCE = 120
local HOMING_ORB_SOUND_ID = "rbxassetid://138158764499491"
local HOMING_ORB_DURATION = 60
local HOMING_ORB_MIN_COUNT = 5
local HOMING_ORB_MAX_COUNT = 15
local HOMING_ORB_MIN_SIZE = 20
local HOMING_ORB_MAX_SIZE = 100
local HOMING_ORB_MIN_SPEED = 10
local HOMING_ORB_MAX_SPEED = 100
local ACID_RAIN_DURATION = 40
local ACID_RAIN_DROPS_PER_SECOND = 3
local ACID_RAIN_CLOUD_DIAMETER = 3000
local ACID_RAIN_CLOUD_HEIGHT = 250
local ACID_PLAYER_TARGET_CHANCE = 0.7
local RAPID_FIRE_EVENT_THRESHOLD = 15
local DUEL_SONG_ID = "rbxassetid://98153645047180"
local CONFUSION_DURATION = 5
local PLATE_INTERMISSION_DURATION = 30
local PLATE_HEIGHT = 1000
local PLATE_SIZE = Vector3.new(30, 3, 30)
local PLATE_SPACING = 40
local PLATE_FALL_THRESHOLD = 100
local PLATE_FALL_FADE_TIME = 2.5
local PLATE_GLOBAL_SHIFT_CHANCE_PERCENT = 2.5
local PLATE_GLOBAL_SHIFT_DISTANCE = 30
local PLATE_SHRINK_AMOUNT = 10
local PLATE_HIGHLIGHT_DURATION = 2
local MEGA_PLATE_SCALE = 8
local SCATTERED_PLATE_HORIZONTAL_LIMIT = 200
local SCATTERED_PLATE_MIN_HEIGHT = 80
local SCATTERED_PLATE_MAX_HEIGHT = 200
local SCATTERED_NO_FALL_DURATION = 5
local BRIDGE_GAMEMODE_SPACING_MULTIPLIER = 3
local BRIDGE_GAMEMODE_BRIDGE_WIDTH = 12
local BRIDGE_GAMEMODE_BRIDGE_THICKNESS = 2
local PLATE_DEEP_SAFE_DEPTH = 151
local GAMEMODE_ROLL_STEPS = 12
local GAMEMODE_ROLL_INTERVAL = 0.2
local FIRE_TICK_DAMAGE = 2
local FIRE_TICK_INTERVAL = 1
local FIRE_TOTAL_DAMAGE = 40
local FIRE_TREE_BURN_DURATION = 8
local ORBITAL_MAX_SHOTS = 3
local ORBITAL_MIN_SHOTS = 1
local ORBITAL_HEIGHT = 100
local ORBITAL_MAX_RANGE = 100
local ORBITAL_BEAM_WIDTH = 30
local ORBITAL_BEAM_STEP = 3
local ORBITAL_BEAM_TICK = 0.05
local ORBITAL_SPHERE_SIZE = 40
local ORBITAL_SPHERE_SPEED = 260
local ORBITAL_SPHERE_EXPLOSION_SCALE = 2.25
local ORBITAL_SPHERE_EXPAND_TIME = 0.22
local ORBITAL_SPHERE_FADE_TIME = 0.4

local running = false
local triggerUsed = false
local ownerUserId = nil
local triggerArmedAt = os.clock() + TRIGGER_ARM_DELAY
local currentAnnouncement = ""
local forcedNextEvent = nil
local deadlyAcidEnabled = false
local restartScheduled = false
local lastEliminatedUserId = nil
local activeLifeLinks = {}
local activeConfusions = {}
local activeShadowOrbs = {}
local activeTsunamiModels = {}
local playersWithoutLegs = {}
local persistentOwnerUserId = nil
local fairModeEnabled = false
local acidTintedParts = {}
local usedLifeLinkPairs = {}
local roundParticipantUserIds = {}
local antiRegenLastHealthByUserId = {}
local antiRegenAllowIncreaseUntil = {}
local plateModeEnabled = false
local nextRoundPlateMode = true
local plateAssignments = {}
local plateFallState = {}
local plateOutUserIds = {}
local plateFolder = nil
local plateMonitorToken = 0
local plateParticipantsReady = false
local plateFallEliminatedUserIds = {}
local activePlateTrees = {}
local activeFireStatesByUserId = {}
local burningTreeTokens = {}
local activeBridgeGamemodeBridges = {}
local currentPlateGamemode = "plate"
local megaPlatePart = nil
local roundStartGraceUntil = 0
local scatteredNoFallUntil = 0
local roundWinEnabled = false
local autoRoundRestartPending = false
local eventCounter = 0
local rapidFireMode = false
local rapidFirePending = false
local twoPlayerMode = false
local lmsForcedUserIds = nil
local targetAliveOnly = false
local duelSound = nil
local duelHighlights = {}
local swordTemplate = nil
local swordTemplateBackup = nil
local defaultFogEnd = Lighting.FogEnd
local defaultFogColor = Lighting.FogColor
local defaultAmbient = Lighting.Ambient
local defaultOutdoorAmbient = Lighting.OutdoorAmbient

local startEvents
local runPlateModeRound
local evaluateWinCondition
local requestAutoRoundStart
local waitForPlateParticipantsReady
local isPlayerActiveInRound
local flingPlayer
local highlightPlate
local applyFireToPlayer
local rollAndSelectPlateGamemode
local getPlateEventTarget
local orbitalStrikeEvent

local function installClientScript(player, clientScriptTemplate)
	local playerScripts = player:WaitForChild("PlayerScripts", 10)
	if not playerScripts then
		return
	end

	local clientScript = clientScriptTemplate:Clone()
	clientScript.Parent = playerScripts
end

local function getHumanoid(player)
	if not player.Character then
		return nil
	end
	return player.Character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(character)
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
end

local function getTriggerPart()
	if script.Parent:IsA("BasePart") then
		return script.Parent
	end

	local existing = workspace:FindFirstChild(TRIGGER_PART_NAME)
	if existing and existing:IsA("BasePart") then
		return existing
	end

	local part = Instance.new("Part")
	part.Name = TRIGGER_PART_NAME
	part.Size = Vector3.new(8, 1, 8)
	part.Position = Vector3.new(0, 5, 0)
	part.Anchored = true
	part.CanCollide = true
	part.BrickColor = BrickColor.new("Really red")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = workspace

	return part
end

local triggerPart = getTriggerPart()
if triggerPart then
	swordTemplate = triggerPart:FindFirstChild("ClassicSword")
	if not swordTemplate then
		local descendants = triggerPart:GetDescendants()
		for _, d in ipairs(descendants) do
			if d.Name == "ClassicSword" and d:IsA("Tool") then
				swordTemplate = d
				break
			end
		end
	end
	if swordTemplate and swordTemplate:IsA("Tool") then
		swordTemplateBackup = swordTemplate:Clone()
		swordTemplateBackup.Parent = script
	end
end

triggerUsed = false
running = false
triggerPart.CanTouch = true
triggerArmedAt = os.clock() + TRIGGER_ARM_DELAY

local function ensureGui(player)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		playerGui = player:WaitForChild("PlayerGui", 3)
		if not playerGui then
			return nil
		end
	end

	local gui = playerGui:FindFirstChild(GUI_NAME)
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = GUI_NAME
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = playerGui
	end

	local label = gui:FindFirstChild("EventLabel")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "EventLabel"
		label.Size = UDim2.new(1, 0, 0, 90)
		label.Position = UDim2.new(0, 0, 0, 0)
		label.BackgroundColor3 = Color3.new(0, 0, 0)
		label.BorderSizePixel = 0
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.75
		label.Font = Enum.Font.SourceSansBold
		label.TextScaled = true
		label.TextWrapped = true
		label.Text = currentAnnouncement
		label.Parent = gui
	end

	label.Text = currentAnnouncement

	return label
end

local function removeAllGuis()
	for _, player in ipairs(Players:GetPlayers()) do
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			local gui = playerGui:FindFirstChild(GUI_NAME)
			if gui then
				gui:Destroy()
			end
		end
	end
end

local function updateAllLabels(text)
	currentAnnouncement = text
	for _, player in ipairs(Players:GetPlayers()) do
		local label = ensureGui(player)
		if label then
			label.Text = text
		end
	end
end

local function getRandomPlayer()
	local playerList = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerActiveInRound(player) then
			table.insert(playerList, player)
		end
	end
	if targetAliveOnly then
		local filtered = {}
		for _, player in ipairs(playerList) do
			local humanoid = getHumanoid(player)
			if humanoid and humanoid.Health > 0 then
				table.insert(filtered, player)
			end
		end
		playerList = filtered
	end

	if #playerList == 0 then
		return nil
	end

	return playerList[math.random(1, #playerList)]
end

local function getRandomOtherPlayer(excludedPlayer)
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerActiveInRound(player) and player ~= excludedPlayer then
			if targetAliveOnly then
				local humanoid = getHumanoid(player)
				if not (humanoid and humanoid.Health > 0) then
					continue
				end
			end
			table.insert(candidates, player)
		end
	end

	if #candidates == 0 then
		return nil
	end

	return candidates[math.random(1, #candidates)]
end

local function getMultiplierCount()
	local roll = math.random(1, 100)
	if targetAliveOnly then
		if roll <= 15 then
			return 2
		end
		return 1
	end
	if roll <= 20 then
		return 3
	end
	if roll <= 35 then
		return 2
	end
	return 1
end

local function formatPlayerNames(players)
	if #players == 0 then
		return "Nobody"
	end
	if #players == 1 then
		return players[1].Name
	end
	if #players == 2 then
		return players[1].Name .. " and " .. players[2].Name
	end
	local names = {}
	for i, player in ipairs(players) do
		names[i] = player.Name
	end
	return table.concat(names, ", ", 1, #names - 1) .. ", and " .. names[#names]
end

local function getRandomDistinctPlayers(count, options)
	options = options or {}
	local aliveOnly = options.aliveOnly
	if aliveOnly == nil then
		aliveOnly = targetAliveOnly
	end

	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local ok = isPlayerActiveInRound(player)
		if aliveOnly then
			local hum = getHumanoid(player)
			if not (hum and hum.Health > 0) then
				ok = false
			end
		end
		if ok and options.excludeUserIds and options.excludeUserIds[player.UserId] then
			ok = false
		end
		if ok and options.excludeLegless and playersWithoutLegs[player.UserId] then
			ok = false
		end
		if ok then
			table.insert(list, player)
		end
	end
	if #list == 0 then
		return {}
	end
	local n = math.min(count, #list)
	local result = {}
	for i = 1, n do
		local idx = math.random(1, #list)
		table.insert(result, list[idx])
		table.remove(list, idx)
	end
	return result
end

local function getLifeLinkPairKey(userIdA, userIdB)
	if userIdA < userIdB then
		return tostring(userIdA) .. ":" .. tostring(userIdB)
	end
	return tostring(userIdB) .. ":" .. tostring(userIdA)
end

local function resetAcidTintedParts()
	for part, originalColor in pairs(acidTintedParts) do
		if part and part.Parent then
			part.Color = originalColor
		end
	end
	acidTintedParts = {}
end

local function getPlayerByUserId(userId)
	if not userId then
		return nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end

	return nil
end

isPlayerActiveInRound = function(player)
	if not player then
		return false
	end
	if not running then
		return true
	end
	return roundParticipantUserIds[player.UserId] == true
end

local function rebuildRoundParticipants()
	roundParticipantUserIds = {}
	for _, player in ipairs(Players:GetPlayers()) do
		roundParticipantUserIds[player.UserId] = true
	end
end

local function resetAntiRegenTracking()
	antiRegenLastHealthByUserId = {}
	antiRegenAllowIncreaseUntil = {}
end

local function allowHealthIncrease(player, seconds)
	if not player then
		return
	end
	antiRegenAllowIncreaseUntil[player.UserId] = os.clock() + (seconds or 0.25)
end

local function attachAntiRegen(player, humanoid)
	if not player or not humanoid then
		return
	end

	antiRegenLastHealthByUserId[player.UserId] = humanoid.Health
	humanoid.HealthChanged:Connect(function(newHealth)
		local userId = player.UserId
		local previous = antiRegenLastHealthByUserId[userId] or newHealth
		local allowUntil = antiRegenAllowIncreaseUntil[userId] or 0

		if running and isPlayerActiveInRound(player) and newHealth > previous and os.clock() > allowUntil then
			humanoid.Health = previous
			antiRegenLastHealthByUserId[userId] = previous
			return
		end

		antiRegenLastHealthByUserId[userId] = newHealth
	end)
end

local function clearPlateTrees()
	for _, treeFolder in ipairs(activePlateTrees) do
		if treeFolder and treeFolder.Parent then
			treeFolder:Destroy()
		end
	end
	activePlateTrees = {}
	burningTreeTokens = {}
end

local function clearPlates()
	plateMonitorToken = plateMonitorToken + 1
	plateAssignments = {}
	plateFallState = {}
	plateOutUserIds = {}
	plateParticipantsReady = false
	plateFallEliminatedUserIds = {}
	activeFireStatesByUserId = {}
	activeBridgeGamemodeBridges = {}
	clearPlateTrees()
	megaPlatePart = nil
	if plateFolder and plateFolder.Parent then
		plateFolder:Destroy()
	end
	plateFolder = nil
end

local function removePlayerPlate(userId)
	local entry = plateAssignments[userId]
	if not entry then
		return
	end
	if currentPlateGamemode ~= "mega" and entry.plate and entry.plate.Parent then
		entry.plate:Destroy()
	end
	plateAssignments[userId] = nil
	plateFallState[userId] = nil
end

local function teleportPlayerToAssignedPlate(player)
	if not player or not plateModeEnabled or not running then
		return
	end
	if not roundParticipantUserIds[player.UserId] then
		return
	end
	local entry = plateAssignments[player.UserId]
	local plate = entry and entry.plate
	if not plate or not plate.Parent then
		return
	end
	local root = player.Character and getRootPart(player.Character)
	if root then
		root.CFrame = CFrame.new(plate.Position + Vector3.new(0, 16, 0))
	end
end

local function startPlateFadeForPlayer(player)
	if not player then
		return
	end
	if currentPlateGamemode == "mega" then
		return
	end
	local userId = player.UserId
	local entry = plateAssignments[userId]
	if not entry or not entry.plate or not entry.plate.Parent or plateFallState[userId] then
		return
	end

	local token = tostring(os.clock()) .. tostring(math.random())
	plateFallState[userId] = token
	local plate = entry.plate
	task.spawn(function()
		local started = os.clock()
		while plate.Parent and plateFallState[userId] == token do
			local alpha = math.clamp((os.clock() - started) / PLATE_FALL_FADE_TIME, 0, 1)
			plate.Transparency = alpha
			if alpha >= 1 then
				lastEliminatedUserId = userId
				local humanoid = getHumanoid(player)
				if humanoid then
					humanoid.Health = 0
				end
				removePlayerPlate(userId)
				evaluateWinCondition()
				return
			end
			RunService.Heartbeat:Wait()
		end
		if plate.Parent then
			plate.Transparency = 0
		end
	end)
end

local function eliminatePlatePlayer(player)
	if not player then
		return
	end
	if not running or not plateModeEnabled then
		return
	end
	if not roundParticipantUserIds[player.UserId] then
		return
	end
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if plateFallEliminatedUserIds[player.UserId] then
		return
	end

	plateFallEliminatedUserIds[player.UserId] = true
	roundParticipantUserIds[player.UserId] = nil
	plateOutUserIds[player.UserId] = true
	lastEliminatedUserId = player.UserId
	if currentPlateGamemode ~= "mega" then
		startPlateFadeForPlayer(player)
	end
	if player.Character then
		player.Character:Destroy()
	end
	task.delay(5, function()
		if player and player.Parent then
			player:LoadCharacter()
		end
	end)
	evaluateWinCondition()
end

local function cancelPlateFadeForPlayer(userId)
	local token = plateFallState[userId]
	if not token then
		return
	end
	plateFallState[userId] = nil
	local entry = plateAssignments[userId]
	if entry and entry.plate and entry.plate.Parent then
		entry.plate.Transparency = 0
	end
end

local function createPlatesForRoundPlayers()
	clearPlates()
	plateFolder = Instance.new("Folder")
	plateFolder.Name = "PlateModePlates"
	plateFolder.Parent = workspace

	local roundPlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if roundParticipantUserIds[player.UserId] then
			table.insert(roundPlayers, player)
		end
	end

	local origin = triggerPart and triggerPart.Position or Vector3.new(0, 0, 0)

	local function createPlate(name)
		local plate = Instance.new("Part")
		plate.Name = name
		plate.Anchored = true
		plate.CanCollide = true
		plate.Material = Enum.Material.SmoothPlastic
		plate.Color = Color3.fromRGB(110, 110, 110)
		plate.Size = PLATE_SIZE
		plate.Parent = plateFolder
		return plate
	end

	if currentPlateGamemode == "mega" then
		local mega = createPlate("MegaPlate")
		mega.Size = Vector3.new(PLATE_SIZE.X * MEGA_PLATE_SCALE, PLATE_SIZE.Y, PLATE_SIZE.Z * MEGA_PLATE_SCALE)
		mega.Position = Vector3.new(origin.X, PLATE_HEIGHT, origin.Z)
		megaPlatePart = mega

		for _, player in ipairs(roundPlayers) do
			plateAssignments[player.UserId] = { plate = mega }
			if player.Character then
				local root = getRootPart(player.Character)
				if root then
					root.CFrame = CFrame.new(mega.Position + Vector3.new(math.random(-20, 20), 16, math.random(-20, 20)))
				end
			end
		end
		return
	end

	local createdPlates = {}
	for index, player in ipairs(roundPlayers) do
		local plate = createPlate("PlayerPlate_" .. player.Name)
		if currentPlateGamemode == "scattered" then
			local randomX = origin.X + math.random(-SCATTERED_PLATE_HORIZONTAL_LIMIT, SCATTERED_PLATE_HORIZONTAL_LIMIT)
			local randomZ = origin.Z + math.random(-SCATTERED_PLATE_HORIZONTAL_LIMIT, SCATTERED_PLATE_HORIZONTAL_LIMIT)
			local randomY = math.random(SCATTERED_PLATE_MIN_HEIGHT, SCATTERED_PLATE_MAX_HEIGHT)
			plate.CFrame = CFrame.new(randomX, randomY, randomZ) * CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), math.rad(math.random(0, 360)))
		else
			local row = math.floor((index - 1) / 5)
			local col = (index - 1) % 5
			local spacing = currentPlateGamemode == "bridge" and (PLATE_SPACING * BRIDGE_GAMEMODE_SPACING_MULTIPLIER) or PLATE_SPACING
			plate.Position = Vector3.new(origin.X - row * spacing, PLATE_HEIGHT, origin.Z + col * spacing)
		end
		plateAssignments[player.UserId] = { plate = plate }
		table.insert(createdPlates, plate)

		if player.Character then
			local root = getRootPart(player.Character)
			if root then
				root.CFrame = CFrame.new(plate.Position + Vector3.new(0, 16, 0))
			end
		end
	end

	if currentPlateGamemode == "bridge" then
		local bridgeFolder = Instance.new("Folder")
		bridgeFolder.Name = "BridgeGamemodeBridges"
		bridgeFolder.Parent = plateFolder
		local cols = 5
		for i, plate in ipairs(createdPlates) do
			local row = math.floor((i - 1) / cols)
			local col = (i - 1) % cols
			local neighbors = { i + 1, i + cols }
			for _, ni in ipairs(neighbors) do
				local np = createdPlates[ni]
				if np and np.Parent then
					if ni == i + 1 and math.floor((ni - 1) / cols) ~= row then
						continue
					end
					local a = plate.Position + Vector3.new(0, plate.Size.Y * 0.5 + BRIDGE_GAMEMODE_BRIDGE_THICKNESS * 0.5 + 1, 0)
					local b = np.Position + Vector3.new(0, np.Size.Y * 0.5 + BRIDGE_GAMEMODE_BRIDGE_THICKNESS * 0.5 + 1, 0)
					local diff = b - a
					if diff.Magnitude > 2 then
						local bridge = Instance.new("Part")
						bridge.Name = "BridgeGamemodeBridge"
						bridge.Anchored = true
						bridge.CanCollide = true
						bridge.Material = Enum.Material.Metal
						bridge.Color = Color3.fromRGB(95, 95, 105)
						bridge.Size = Vector3.new(BRIDGE_GAMEMODE_BRIDGE_WIDTH, BRIDGE_GAMEMODE_BRIDGE_THICKNESS, diff.Magnitude)
						bridge.CFrame = CFrame.lookAt((a + b) * 0.5, b)
						bridge.Parent = bridgeFolder
						table.insert(activeBridgeGamemodeBridges, bridge)
					end
				end
			end
		end
	end
end

local function getPlateFallLimitY(plate)
	if not plate then
		return -math.huge
	end
	return plate.Position.Y - PLATE_FALL_THRESHOLD
end

local function monitorPlateFalls()
	plateMonitorToken = plateMonitorToken + 1
	local token = plateMonitorToken
	task.spawn(function()
		while running and plateModeEnabled and token == plateMonitorToken do
			for userId, entry in pairs(plateAssignments) do
				local player = getPlayerByUserId(userId)
				local humanoid = player and getHumanoid(player)
				local root = player and player.Character and getRootPart(player.Character)
				local plate = entry and entry.plate
				if not player or not plate or not plate.Parent then
					removePlayerPlate(userId)
				elseif humanoid and humanoid.Health > 0 and root then
					if currentPlateGamemode == "scattered" and os.clock() < scatteredNoFallUntil then
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
						local minFloatY = plate.Position.Y + 10
						if root.Position.Y < minFloatY then
							root.CFrame = CFrame.new(root.Position.X, minFloatY, root.Position.Z)
						end
					else
						local depthBelowPlate = plate.Position.Y - root.Position.Y
						if depthBelowPlate >= PLATE_FALL_THRESHOLD and depthBelowPlate < PLATE_DEEP_SAFE_DEPTH then
							eliminatePlatePlayer(player)
						end
					end
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local function handlePlayerElimination(player)
	if not player then
		return
	end
	if plateModeEnabled and running and roundParticipantUserIds[player.UserId] then
		roundParticipantUserIds[player.UserId] = nil
		if currentPlateGamemode ~= "mega" then
			startPlateFadeForPlayer(player)
		end
	end
end

local function isPlateModeCommand(message)
	local msg = string.lower((message or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if msg == "platemode" or msg == "/e platemode" or msg:match("^/e%s+platemode$") then
		return true
	end
	return false
end

local function isNormalModeCommand(message)
	local msg = string.lower((message or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if msg == "normalmode" or msg == "/e normalmode" or msg:match("^/e%s+normalmode$") then
		return true
	end
	return false
end

local function findPlayerByToken(token)
	if not token or token == "" then
		return nil
	end

	local lowerToken = string.lower(token)
	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == lowerToken or string.lower(player.DisplayName) == lowerToken then
			return player
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if string.sub(string.lower(player.Name), 1, #lowerToken) == lowerToken then
			return player
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if string.sub(string.lower(player.DisplayName), 1, #lowerToken) == lowerToken then
			return player
		end
	end

	return nil
end

local function isAcidProtectedPart(hitPart)
	if not hitPart or not hitPart:IsA("BasePart") then
		return false
	end

	if hitPart == triggerPart or hitPart:IsDescendantOf(triggerPart) then
		return true
	end

	local tool = hitPart:FindFirstAncestorOfClass("Tool")
	if tool and tool.Name == "ClassicSword" then
		return true
	end

	return false
end

local function createGreenExplosion(position)
	local ball = Instance.new("Part")
	ball.Name = "GreenExplosion"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanTouch = false
	ball.CanQuery = false
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(0, 255, 0)
	ball.Size = Vector3.new(6, 6, 6)
	ball.CFrame = CFrame.new(position)
	ball.Parent = workspace

	task.spawn(function()
		for i = 1, 10 do
			if not ball.Parent then
				return
			end
			ball.Size = ball.Size + Vector3.new(4, 4, 4)
			ball.Transparency = i / 10
			task.wait(0.03)
		end
		if ball.Parent then
			ball:Destroy()
		end
	end)
end

local function countdown(message)
	local countdownDuration = (rapidFireMode or rapidFirePending or twoPlayerMode) and 5 or EVENT_COUNTDOWN
	local endTime = os.clock() + countdownDuration
	local lastShown = nil

	while running do
		local remaining = math.ceil(endTime - os.clock())
		if remaining <= 0 then
			break
		end

		if remaining ~= lastShown then
			lastShown = remaining
			updateAllLabels(message .. " " .. remaining)
		end

		RunService.Heartbeat:Wait()
	end

	return running
end

local function clearConfusionForUserId(userId)
	local state = activeConfusions[userId]
	if not state then
		return
	end
	activeConfusions[userId] = nil

	if state.deathConnection then
		state.deathConnection:Disconnect()
	end

	if state.humanoid and state.humanoid.Parent and state.humanoid.Health > 0 then
		state.humanoid.WalkSpeed = state.walkSpeed
		state.humanoid.JumpPower = state.jumpPower
		state.humanoid.AutoRotate = state.autoRotate
	end
end

local function clearConfusions()
	for userId, _ in pairs(activeConfusions) do
		clearConfusionForUserId(userId)
	end
end

local function applyConfusion(target)
	if not target then
		return false
	end

	local humanoid = getHumanoid(target)
	local rootPart = getRootPart(target.Character)
	if not humanoid or not rootPart then
		return false
	end

	clearConfusionForUserId(target.UserId)

	local token = tostring(os.clock()) .. ":" .. tostring(math.random())
	activeConfusions[target.UserId] = {
		token = token,
		humanoid = humanoid,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		autoRotate = humanoid.AutoRotate,
	}

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false

	activeConfusions[target.UserId].deathConnection = humanoid.Died:Connect(function()
		clearConfusionForUserId(target.UserId)
	end)

	task.spawn(function()
		local endTime = os.clock() + CONFUSION_DURATION
		while running and os.clock() < endTime do
			local state = activeConfusions[target.UserId]
			if not state or state.token ~= token then
				return
			end
			if humanoid.Health <= 0 then
				clearConfusionForUserId(target.UserId)
				return
			end

			local currentRoot = getRootPart(target.Character)
			if currentRoot then
				currentRoot.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
			end
			RunService.Heartbeat:Wait()
		end

		clearConfusionForUserId(target.UserId)
	end)

	return true
end

local function killRandomPlayer()
	local targets = getRandomDistinctPlayers(getMultiplierCount(), {})
	if #targets == 0 then
		updateAllLabels("No players available.")
		return
	end
	if fairModeEnabled and getGlobalAlivePlayerCount() < 10 then
		updateAllLabels("Fairmode: kill event needs at least 10 alive players.")
		return
	end
	local msg = #targets == 1 and "Someone is going to die!" or (tostring(#targets) .. " people are going to die!")
	updateAllLabels(msg)
	if not countdown(msg) then return end
	for _, target in ipairs(targets) do
		local humanoid = getHumanoid(target)
		if humanoid then humanoid.Health = 0 end
	end
	updateAllLabels(formatPlayerNames(targets) .. " will die now!")
end

local function flingRandomPlayer()
	local targets = getRandomDistinctPlayers(getMultiplierCount(), {})
	if #targets == 0 then updateAllLabels("No players available.") return end
	local msg = #targets == 1 and "Someone will be flinged!" or (tostring(#targets) .. " people will be flinged!")
	updateAllLabels(msg)
	if not countdown(msg) then return end
	for _, target in ipairs(targets) do
		flingPlayer(target)
	end
	updateAllLabels(formatPlayerNames(targets) .. " got flinged!")
end

flingPlayer = function(target)
	if not target then
		return
	end

	local rootPart = getRootPart(target.Character)
	if rootPart then
		local flingVelocity = Vector3.new(math.random(-150, 150), math.random(180, 260), math.random(-150, 150))
		rootPart.AssemblyLinearVelocity = flingVelocity
		pcall(function()
			rootPart:ApplyImpulse(flingVelocity * rootPart.AssemblyMass)
		end)

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		bodyVelocity.Velocity = flingVelocity
		bodyVelocity.Parent = rootPart
		task.delay(0.2, function()
			if bodyVelocity then
				bodyVelocity:Destroy()
			end
		end)
	end
end

local function boostRandomPlayerHealth()
	local targets = getRandomDistinctPlayers(getMultiplierCount(), {})
	if #targets == 0 then updateAllLabels("No players available.") return end
	local msg = #targets == 1 and "Someone will get 300 hp!" or (tostring(#targets) .. " people will get 300 hp!")
	updateAllLabels(msg)
	if not countdown(msg) then return end
	for _, target in ipairs(targets) do
		local humanoid = getHumanoid(target)
		if humanoid then
			allowHealthIncrease(target, 0.5)
			humanoid.MaxHealth = 300
			humanoid.Health = 300
		end
	end
	updateAllLabels(formatPlayerNames(targets) .. " got 300 HP!")
end

local function teleportPlayerToPlayer()
	updateAllLabels("Someone is going to teleported to someone")
	if not countdown("Someone is going to teleported to someone") then
		return
	end

	local mover = getRandomPlayer()
	if not mover then
		updateAllLabels("No players available.")
		return
	end

	local destination = getRandomOtherPlayer(mover)
	if not destination then
		updateAllLabels("Not enough players for teleport event.")
		return
	end

	local moverRoot = getRootPart(mover.Character)
	local destinationRoot = getRootPart(destination.Character)
	if moverRoot and destinationRoot then
		moverRoot.CFrame = destinationRoot.CFrame * CFrame.new(2, 0, 0)
	end

	updateAllLabels(mover.Name .. " was teleported to " .. destination.Name .. "!")
end

local function turnIntoAnotherPlayer()
	updateAllLabels("Someone is going to be turned into another player!")
	if not countdown("Someone is going to be turned into another player!") then
		return
	end

	local target = getRandomPlayer()
	if not target then
		updateAllLabels("No players available.")
		return
	end

	local source = getRandomOtherPlayer(target)
	if not source then
		updateAllLabels("Not enough players for avatar change event.")
		return
	end

	local targetHumanoid = getHumanoid(target)
	if targetHumanoid then
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(source.UserId)
		end)
		if ok and description then
			targetHumanoid:ApplyDescription(description)
		end
	end

	updateAllLabels(target.Name .. " has turned into " .. source.Name .. "!")
end

local function increasePlayerSize()
	local targets = getRandomDistinctPlayers(getMultiplierCount(), {})
	if #targets == 0 then updateAllLabels("No players available.") return end
	local msg = #targets == 1 and "Someone will get bigger!" or (tostring(#targets) .. " people will get bigger!")
	updateAllLabels(msg)
	if not countdown(msg) then return end
	for _, target in ipairs(targets) do
		local humanoid = getHumanoid(target)
		if humanoid and target.Character then
			local scaledByModel = pcall(function()
				local currentScale = target.Character:GetScale()
				target.Character:ScaleTo(currentScale * 1.5)
			end)
			if not scaledByModel then
				for _, valueName in ipairs({"BodyDepthScale","BodyHeightScale","BodyWidthScale","HeadScale"}) do
					local scaleValue = humanoid:FindFirstChild(valueName)
					if scaleValue and scaleValue:IsA("NumberValue") then scaleValue.Value = scaleValue.Value * 1.5 end
				end
			end
		end
	end
	updateAllLabels(formatPlayerNames(targets) .. " size has been increased by 50%")
end

local function strikeLightningOnPlayer(target)
	if not target then
		return
	end

	local rootPart = getRootPart(target.Character)
	if not rootPart then
		return
	end

	local bolt = Instance.new("Part")
	bolt.Name = "LightningBolt"
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanTouch = false
	bolt.CanQuery = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(255, 255, 150)
	bolt.Size = Vector3.new(2, 60, 2)
	bolt.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 25, 0))
	bolt.Parent = workspace

	task.delay(0.2, function()
		if bolt and bolt.Parent then
			bolt:Destroy()
		end
	end)

	local humanoid = getHumanoid(target)
	if humanoid then
		humanoid:TakeDamage(math.random(20, 100))
	end
end

local function lightningStrikeEvent()
	local targets = getRandomDistinctPlayers(getMultiplierCount(), {})
	if #targets == 0 then updateAllLabels("No players available.") return end
	local msg = #targets == 1 and "Someone will be struck by lighting!" or (tostring(#targets) .. " people will be struck by lighting!")
	updateAllLabels(msg)
	if not countdown(msg) then return end
	for _, target in ipairs(targets) do strikeLightningOnPlayer(target) end
	updateAllLabels(formatPlayerNames(targets) .. " got striked!")
end

local function shrinkRandomPlayer()
	local targets = getRandomDistinctPlayers(getMultiplierCount(), {})
	if #targets == 0 then updateAllLabels("No players available.") return end
	local msg = #targets == 1 and "A player will become 50% smaller!" or (tostring(#targets) .. " players will become 50% smaller!")
	updateAllLabels(msg)
	if not countdown(msg) then return end
	for _, target in ipairs(targets) do
		local humanoid = getHumanoid(target)
		if humanoid and target.Character then
			local scaledByModel = pcall(function()
				local currentScale = target.Character:GetScale()
				target.Character:ScaleTo(currentScale * 0.5)
			end)
			if not scaledByModel then
				for _, valueName in ipairs({"BodyDepthScale","BodyHeightScale","BodyWidthScale","HeadScale"}) do
					local scaleValue = humanoid:FindFirstChild(valueName)
					if scaleValue and scaleValue:IsA("NumberValue") then scaleValue.Value = scaleValue.Value * 0.5 end
				end
			end
		end
	end
	updateAllLabels(formatPlayerNames(targets) .. " got smaller!")
end

local function confusionEvent(forcedTargetUserId)
	local targets = forcedTargetUserId and ({ getPlayerByUserId(forcedTargetUserId) }) or getRandomDistinctPlayers(getMultiplierCount(), {})
	local clean = {}
	for _, t in ipairs(targets) do if t then table.insert(clean, t) end end
	targets = clean
	if #targets == 0 then updateAllLabels("No players available.") return end
	local msg = #targets == 1 and "Someone is going to be confused!" or (tostring(#targets) .. " people are going to be confused!")
	updateAllLabels(msg)
	if not countdown(msg) then return end
	local affected = {}
	for _, target in ipairs(targets) do if applyConfusion(target) then table.insert(affected, target) end end
	if #affected == 0 then updateAllLabels("Confusion failed (target not ready).") return end
	updateAllLabels(formatPlayerNames(affected) .. " got confused!")
end

local function clearShadowOrbs()
	for _, orb in ipairs(activeShadowOrbs) do
		if orb and orb.Parent then
			orb:Destroy()
		end
	end
	activeShadowOrbs = {}
end

local function clearTsunamis()
	for model, _ in pairs(activeTsunamiModels) do
		if model and model.Parent then
			model:Destroy()
		end
	end
	activeTsunamiModels = {}
end

local function spawnShadowOrbForTarget(target)
	if not target then
		return
	end

	local root = getRootPart(target.Character)
	if not root then
		return
	end

	local orb = Instance.new("Part")
	orb.Name = "ShadowOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(5, 5, 5)
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(0, 0, 0)
	orb.CanCollide = false
	orb.Anchored = true
	orb.Parent = workspace
	orb.Position = root.Position + Vector3.new(math.random(-20, 20), 8, math.random(-20, 20))
	table.insert(activeShadowOrbs, orb)

	task.spawn(function()
		local endTime = os.clock() + 40
		while running and orb.Parent and os.clock() < endTime do
			local hum = getHumanoid(target)
			local rr = getRootPart(target.Character)
			if not hum or hum.Health <= 0 or not rr then
				break
			end
			local dir = rr.Position - orb.Position
			if dir.Magnitude > 0 then
				orb.Position = orb.Position + dir.Unit * 15 * RunService.Heartbeat:Wait()
			else
				RunService.Heartbeat:Wait()
			end
			if (rr.Position - orb.Position).Magnitude <= 4.5 then
				lastEliminatedUserId = target.UserId
				if target.Character then
					target.Character:Destroy()
				end
				task.delay(4, function()
					if target and target.Parent then
						target:LoadCharacter()
					end
				end)
				evaluateWinCondition()
				break
			end
		end
		if orb.Parent then orb:Destroy() end
	end)
end

local function shadowOrbEvent(forcedTargetUserId)
	local targetCount = forcedTargetUserId and 1 or getMultiplierCount()
	local targets = forcedTargetUserId and { getPlayerByUserId(forcedTargetUserId) } or getRandomDistinctPlayers(targetCount, {})
	if #targets == 0 or not targets[1] then
		updateAllLabels("No players available.")
		return
	end

	if #targets == 1 then
		updateAllLabels("A shadow orb will chase someone!")
		if not countdown("A shadow orb will chase someone!") then return end
	else
		updateAllLabels(tostring(#targets) .. " players are going to be chased by shadow orbs!")
		if not countdown(tostring(#targets) .. " players are going to be chased by shadow orbs!") then return end
	end

	updateAllLabels(formatPlayerNames(targets) .. " " .. (#targets == 1 and "is" or "are") .. " being chased by the shadow orb!")
	for _, target in ipairs(targets) do
		spawnShadowOrbForTarget(target)
	end
end

local function globalShadowOrbEvent()
	updateAllLabels("All players are being chased by a shadow orb!")
	if not countdown("All players are being chased by a shadow orb!") then
		return
	end

	updateAllLabels("Avoid your shadow orb!")
	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerActiveInRound(player) then
			spawnShadowOrbForTarget(player)
		end
	end
end

local function rollTsunamiClass()
	local weights = { 20, 15, 12, 10, 8, 7, 6, 5, 4, 3, 2, 1 }
	local total = 0
	for i = 1, TSUNAMI_MAX_CLASS do
		total = total + (weights[i] or 1)
	end
	local roll = math.random() * total
	local acc = 0
	for i = 1, TSUNAMI_MAX_CLASS do
		acc = acc + (weights[i] or 1)
		if roll <= acc then
			return i
		end
	end
	return 1
end

local function getTreeFolderFromPartForTsunami(part)
	local node = part
	while node do
		if node:IsA("Folder") and node.Name == "PlateTree" then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function isPlatePartForTsunami(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if megaPlatePart and part == megaPlatePart then
		return true
	end
	for _, entry in pairs(plateAssignments) do
		if entry and entry.plate == part then
			return true
		end
	end
	return false
end

local function shouldDestroyForTsunamiClass(part, class)
	if not part or not part.Parent or not part:IsA("BasePart") then
		return false
	end

	if part.Position.Y <= -100 then
		return false
	end

	if part == triggerPart or part:IsDescendantOf(triggerPart) then
		return false
	end

	if isPlatePartForTsunami(part) then
		return false
	end

	if getTreeFolderFromPartForTsunami(part) then
		return false
	end

	local characterModel = part:FindFirstAncestorOfClass("Model")
	if characterModel and characterModel:FindFirstChildOfClass("Humanoid") then
		return false
	end

	for tsunamiModel, _ in pairs(activeTsunamiModels) do
		if tsunamiModel and part:IsDescendantOf(tsunamiModel) then
			return false
		end
	end

	return true
end

local function destroyPartForTsunami(part)
	if not part or not part.Parent then
		return
	end

	local model = part:FindFirstAncestorOfClass("Model")
	if model and not model:FindFirstChildOfClass("Humanoid") and model.Name ~= "TsunamiWaveModel" then
		pcall(function()
			model:Destroy()
		end)
		return
	end

	pcall(function()
		part:Destroy()
	end)
end

local function getTsunamiCenter()
	local sum = Vector3.new(0, 0, 0)
	local count = 0
	for _, entry in pairs(plateAssignments) do
		if entry and entry.plate and entry.plate.Parent then
			sum = sum + entry.plate.Position
			count = count + 1
		end
	end
	if count > 0 then
		return sum / count
	end
	return triggerPart and triggerPart.Position or Vector3.new(0, PLATE_HEIGHT, 0)
end

local function getRandomPlatePartForTsunami()
	local unique = {}
	local plates = {}
	for _, entry in pairs(plateAssignments) do
		local plate = entry and entry.plate
		if plate and plate.Parent and not unique[plate] then
			unique[plate] = true
			table.insert(plates, plate)
		end
	end
	if #plates == 0 then
		return nil, plates
	end
	return plates[math.random(1, #plates)], plates
end

local function isTsunamiSpawnBlocked(spawnPos, plates)
	for _, plate in ipairs(plates or {}) do
		if plate and plate.Parent then
			local offset = plate.Position - spawnPos
			if math.abs(offset.Y) <= 40 and Vector3.new(offset.X, 0, offset.Z).Magnitude < TSUNAMI_SPAWN_CLEARANCE then
				return true
			end
		end
	end
	return false
end

local function findTsunamiTemplateModel()
	if triggerPart then
		for _, d in ipairs(triggerPart:GetDescendants()) do
			if d:IsA("Model") and d.Name == "Tsunami" then
				return d
			end
		end
	end
	for _, d in ipairs(script:GetDescendants()) do
		if d:IsA("Model") and d.Name == "Tsunami" then
			return d
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == "Tsunami" then
			return d
		end
	end
	return nil
end


local function rotationBetweenUnitVectors(fromDir, toDir)
	local fromU = fromDir.Unit
	local toU = toDir.Unit
	local dot = math.clamp(fromU:Dot(toU), -1, 1)
	if dot >= 0.9999 then
		return CFrame.new()
	end
	if dot <= -0.9999 then
		local axis = fromU:Cross(Vector3.new(0, 1, 0))
		if axis.Magnitude < 0.001 then
			axis = fromU:Cross(Vector3.new(1, 0, 0))
		end
		return CFrame.fromAxisAngle(axis.Unit, math.pi)
	end
	local axis = fromU:Cross(toU)
	if axis.Magnitude < 0.001 then
		return CFrame.new()
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

local function createTsunamiWaveModel(class, spawnCFrame, desiredDir)
	local template = findTsunamiTemplateModel()
	if not template then
		return nil, nil
	end

	local model = template:Clone()
	model.Name = "TsunamiWaveModel"
	model.Parent = workspace

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end

	local scaleFactor = 0.3 + ((class - 1) * 0.1)
	pcall(function()
		model:ScaleTo(scaleFactor)
	end)

	local _, size = model:GetBoundingBox()
	local alignedPos = spawnCFrame.Position + Vector3.new(0, (size.Y * 0.5) - 3, 0)
	local desired = (desiredDir and desiredDir.Magnitude > 0.01) and (-desiredDir.Unit) or (-spawnCFrame.LookVector)

	local currentPivot = model:GetPivot()
	local pivotRot = currentPivot - currentPivot.Position
	model:PivotTo(CFrame.new(alignedPos) * pivotRot)

	local facer = model:FindFirstChild("facer", true)
	if facer and facer:IsA("BasePart") then
		local currentLook = facer.CFrame.LookVector
		local rotDelta = rotationBetweenUnitVectors(currentLook, desired)
		local pivotAfterMove = model:GetPivot()
		local pivotAfterMoveRot = pivotAfterMove - pivotAfterMove.Position
		model:PivotTo(CFrame.new(alignedPos) * rotDelta * pivotAfterMoveRot)
	else
		model:PivotTo(CFrame.lookAt(alignedPos, alignedPos + desired))
	end

	return model, facer
end

local function tsunamiEvent(forcedClass)
	local class = tonumber(forcedClass)
	if class then
		class = math.clamp(math.floor(class), 1, TSUNAMI_MAX_CLASS)
	else
		class = rollTsunamiClass()
	end

	local warnMsg = "A tsunami class " .. class .. " is coming prepare!"
	updateAllLabels(warnMsg)
	if not countdown(warnMsg) then
		return
	end

	local center = getTsunamiCenter()
	local targetPlate, plates = getRandomPlatePartForTsunami()
	local targetPos = (targetPlate and targetPlate.Position) or center
	local rawDir = (center - targetPos)
	rawDir = Vector3.new(rawDir.X, 0, rawDir.Z)
	if rawDir.Magnitude < 0.5 then
		local angle = math.random() * math.pi * 2
		rawDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	local dir = rawDir.Unit
	local waveY = targetPos.Y + ((targetPlate and targetPlate.Size.Y * 0.5) or 1) + 2
	local spawnDistance = TSUNAMI_SPAWN_DISTANCE
	local spawnPos = Vector3.new(targetPos.X, waveY, targetPos.Z) - dir * spawnDistance
	local attempts = 0
	while attempts < 8 and isTsunamiSpawnBlocked(spawnPos, plates) do
		spawnDistance = spawnDistance + 150
		spawnPos = Vector3.new(targetPos.X, waveY, targetPos.Z) - dir * spawnDistance
		attempts = attempts + 1
	end
	local spawnCFrame = CFrame.lookAt(spawnPos, spawnPos + dir)

	local waveModel, waveFacer = createTsunamiWaveModel(class, spawnCFrame, dir)
	if not waveModel then
		updateAllLabels("Tsunami model named 'Tsunami' not found.")
		return
	end
	activeTsunamiModels[waveModel] = true

	local moveDir = dir

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { waveModel, triggerPart }

	local damagedOnce = {}
	local speed = 120 + (class * 8)
	local damageAmount = (class >= 10 and math.huge) or (class >= 7 and 80) or (class >= 4 and 30) or 0

	task.spawn(function()
		local expireAt = os.clock() + TSUNAMI_DESPAWN_SECONDS
		while running and waveModel.Parent and os.clock() < expireAt do
			local dt = RunService.Heartbeat:Wait()
			local step = moveDir * speed * dt
			if waveModel and waveModel.Parent then
				local beforePivot = waveModel:GetPivot()
				local targetPivot = beforePivot + step
				local movedByPivot = false
				pcall(function()
					waveModel:PivotTo(targetPivot)
					movedByPivot = true
				end)
				local afterPivot = waveModel:GetPivot()
				if (not movedByPivot) or (afterPivot.Position - beforePivot.Position).Magnitude < 0.01 then
					pcall(function()
						waveModel:TranslateBy(step)
					end)
				end
			end
			local waveCFrame, waveSize = waveModel:GetBoundingBox()
			local touching = workspace:GetPartBoundsInBox(waveCFrame, waveSize, overlapParams)
			for _, part in ipairs(touching) do
				if part and part:IsA("BasePart") then
					local model = part:FindFirstAncestorOfClass("Model")
					local hum = model and model:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						local root = getRootPart(model)
						if root then
							local pushPower = 45 + class * 12
							local liftPower = 4 + class
							root.AssemblyLinearVelocity = Vector3.new(moveDir.X * pushPower, math.max(root.AssemblyLinearVelocity.Y, liftPower), moveDir.Z * pushPower)
						end
						if damageAmount > 0 and not damagedOnce[hum] then
							damagedOnce[hum] = true
							if damageAmount == math.huge then
								hum.Health = 0
							else
								hum:TakeDamage(damageAmount)
							end
						end
					elseif shouldDestroyForTsunamiClass(part, class) then
						destroyPartForTsunami(part)
					end
				end
			end
		end

		if waveModel and waveModel.Parent then
			waveModel:Destroy()
		end
		activeTsunamiModels[waveModel] = nil
		if running then
			updateAllLabels("Tsunami class " .. class .. " has passed!")
		end
	end)

	updateAllLabels("Tsunami class " .. class .. " is active!")
end

local function loseLegsEvent(forcedTargetUserId)
	local targetCount = forcedTargetUserId and 1 or getMultiplierCount()
	local targets
	if forcedTargetUserId then
		local p = getPlayerByUserId(forcedTargetUserId)
		targets = p and { p } or {}
	else
		targets = getRandomDistinctPlayers(targetCount, { aliveOnly = false, excludeLegless = true })
	end
	if #targets == 0 then
		updateAllLabels("Everyone already lost their legs or no players available.")
		return
	end

	if #targets == 1 then
		updateAllLabels("Someone is going to lose their legs!")
		if not countdown("Someone is going to lose their legs!") then return end
	else
		updateAllLabels(tostring(#targets) .. " people are going to lose their legs!")
		if not countdown(tostring(#targets) .. " people are going to lose their legs!") then return end
	end

	for _, target in ipairs(targets) do
		if not playersWithoutLegs[target.UserId] and target.Character then
			playersWithoutLegs[target.UserId] = true
			for _, limbName in ipairs({"Left Leg", "Right Leg", "LeftLowerLeg", "RightLowerLeg", "LeftUpperLeg", "RightUpperLeg"}) do
				local limb = target.Character:FindFirstChild(limbName)
				if limb and limb:IsA("BasePart") then
					limb:Destroy()
				end
			end
		end
	end

	updateAllLabels(formatPlayerNames(targets) .. " lost their legs!")
end

local function clearLifeLinks()
	for _, link in ipairs(activeLifeLinks) do
		link.active = false
		if link.beamPart and link.beamPart.Parent then
			link.beamPart:Destroy()
		end
	end
	activeLifeLinks = {}
end

local function getAlivePlayers()
	local alive = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if not isPlayerActiveInRound(player) then
			continue
		end
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.Health > 0 then
			table.insert(alive, player)
		end
	end
	return alive
end

local function getGlobalAlivePlayerCount()
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.Health > 0 then
			count = count + 1
		end
	end
	return count
end

local function getRoundParticipantCount()
	local count = 0
	for _, isActive in pairs(roundParticipantUserIds) do
		if isActive then
			count = count + 1
		end
	end
	return count
end

local function clearDuelEffects()
	for _, h in ipairs(duelHighlights) do
		if h and h.Parent then
			h:Destroy()
		end
	end
	duelHighlights = {}

	if duelSound then
		pcall(function()
			duelSound:Stop()
		end)
		duelSound:Destroy()
		duelSound = nil
	end
end

local function setRapidFireMode(enabled)
	rapidFireMode = enabled
	rapidFirePending = false
	if enabled then
		Lighting.FogEnd = 1000
		Lighting.FogColor = Color3.fromRGB(255, 0, 0)
		Lighting.Ambient = Color3.fromRGB(255, 0, 0)
		Lighting.OutdoorAmbient = Color3.fromRGB(120, 0, 0)
	else
		Lighting.FogEnd = defaultFogEnd
		Lighting.FogColor = defaultFogColor
		Lighting.Ambient = defaultAmbient
		Lighting.OutdoorAmbient = defaultOutdoorAmbient
	end
end

local function requestRapidFireMode()
	rapidFirePending = true
end

local function setTwoPlayerMode(enabled)
	if twoPlayerMode == enabled then
		return
	end
	twoPlayerMode = enabled

	clearDuelEffects()

	if not enabled then
		return
	end

	local alive = getAlivePlayers()
	for _, player in ipairs(alive) do
		if player.Character then
			local h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(255, 50, 50)
			h.OutlineColor = Color3.fromRGB(255, 255, 255)
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = player.Character
			table.insert(duelHighlights, h)
		end
	end

	duelSound = Instance.new("Sound")
	duelSound.SoundId = DUEL_SONG_ID
	duelSound.Volume = 3
	duelSound.Looped = true
	duelSound.Parent = SoundService
	pcall(function()
		duelSound:Play()
	end)
end

local function scheduleGameRestart(winnerPlayer)
	if restartScheduled then
		return
	end
	restartScheduled = true
	running = false
	clearLifeLinks()
	clearPlates()
	resetAcidTintedParts()
	clearShadowOrbs()
	clearTsunamis()
	clearConfusions()
	clearDuelEffects()
	setRapidFireMode(false)

	local winnerName = winnerPlayer and winnerPlayer.Name or "Nobody"
	updateAllLabels("Game over " .. winnerName .. " won!")
	task.wait(2)
	for i = PLATE_INTERMISSION_DURATION, 1, -1 do
		updateAllLabels("Events starting again in " .. i .. " seconds take a break")
		task.wait(1)
	end

	triggerUsed = false
	ownerUserId = persistentOwnerUserId
	forcedNextEvent = nil
	deadlyAcidEnabled = false
	targetAliveOnly = false
	lastEliminatedUserId = nil
	lmsForcedUserIds = nil
	eventCounter = 0
	rapidFirePending = false
	twoPlayerMode = false
	playersWithoutLegs = {}
	usedLifeLinkPairs = {}
	roundParticipantUserIds = {}
	resetAntiRegenTracking()
	currentAnnouncement = ""
	triggerPart.CanTouch = true
	triggerArmedAt = os.clock() + TRIGGER_ARM_DELAY
	restartScheduled = false

	local autoStarter = getPlayerByUserId(persistentOwnerUserId) or getRandomPlayer()
	if autoStarter then
		triggerUsed = true
		triggerPart.CanTouch = false
		plateModeEnabled = nextRoundPlateMode
		if plateModeEnabled then
			task.spawn(runPlateModeRound, autoStarter)
		else
			task.spawn(startEvents, autoStarter)
		end
	else
		requestAutoRoundStart(1)
	end
end

evaluateWinCondition = function()
	if not running or restartScheduled then
		return
	end
	if plateModeEnabled and os.clock() < roundStartGraceUntil then
		return
	end
	if not roundWinEnabled then
		setTwoPlayerMode(false)
		return
	end

	local alivePlayers = getAlivePlayers()
	if #alivePlayers == 2 then
		setTwoPlayerMode(true)
		requestRapidFireMode()
	else
		setTwoPlayerMode(false)
		if eventCounter < RAPID_FIRE_EVENT_THRESHOLD then
			setRapidFireMode(false)
		end
	end

	if #alivePlayers <= 1 then
		local winner = alivePlayers[1]
		if not winner and lastEliminatedUserId then
			winner = getPlayerByUserId(lastEliminatedUserId)
		end
		task.spawn(scheduleGameRestart, winner)
	end
end

local function activateLmsForce()
	if not running or restartScheduled then
		return false
	end

	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(candidates, player)
	end

	if #candidates < 2 then
		return false
	end

	local firstIndex = math.random(1, #candidates)
	local first = candidates[firstIndex]
	table.remove(candidates, firstIndex)
	local second = candidates[math.random(1, #candidates)]

	lmsForcedUserIds = {
		[first.UserId] = true,
		[second.UserId] = true,
	}

	requestRapidFireMode()
	setRapidFireMode(true)
	setTwoPlayerMode(true)
	updateAllLabels("LMS force active: " .. first.Name .. " vs " .. second.Name)
	return true
end

local function createLifeLink(playerA, playerB)
	if not playerA or not playerB then
		return
	end

	local beam = Instance.new("Part")
	beam.Name = "LifeLinkBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(0, 255, 0)
	beam.Size = Vector3.new(1, 1, 1)
	beam.Parent = workspace

	local link = {
		playerAUserId = playerA.UserId,
		playerBUserId = playerB.UserId,
		beamPart = beam,
		active = true,
	}
	table.insert(activeLifeLinks, link)

	task.spawn(function()
		while running and link.active and beam.Parent do
			local pA = getPlayerByUserId(link.playerAUserId)
			local pB = getPlayerByUserId(link.playerBUserId)
			local rootA = pA and getRootPart(pA.Character)
			local rootB = pB and getRootPart(pB.Character)
			if not pA or not pB or not rootA or not rootB then
				break
			end

			local diff = rootB.Position - rootA.Position
			local distance = diff.Magnitude
			if distance < 0.1 then
				distance = 0.1
			end

			beam.Size = Vector3.new(1.2, 1.2, distance)
			beam.CFrame = CFrame.new(rootA.Position, rootB.Position) * CFrame.new(0, 0, -distance * 0.5)
			RunService.Heartbeat:Wait()
		end

		if beam.Parent then
			beam:Destroy()
		end
		link.active = false
	end)

	local function onDeath(diedPlayer, otherUserId)
		if not link.active then
			return
		end
		link.active = false

		local otherPlayer = getPlayerByUserId(otherUserId)
		if otherPlayer then
			local otherRoot = getRootPart(otherPlayer.Character)
			if otherRoot then
				createGreenExplosion(otherRoot.Position)
			end
			if fairModeEnabled and #getAlivePlayers() <= 3 then
				local alive = getAlivePlayers()
				if #alive >= 2 then
					lmsForcedUserIds = {
						[alive[1].UserId] = true,
						[alive[2].UserId] = true,
					}
					requestRapidFireMode()
					setRapidFireMode(true)
					setTwoPlayerMode(true)
					updateAllLabels("LMS force active: " .. alive[1].Name .. " vs " .. alive[2].Name)
				end
			else
				local otherHumanoid = getHumanoid(otherPlayer)
				if otherHumanoid then
					otherHumanoid.Health = 0
					if otherHumanoid.Health > 0 then
						otherHumanoid:TakeDamage(1e9)
					end
				end
			end
		end

		if link.beamPart and link.beamPart.Parent then
			link.beamPart:Destroy()
		end
	end

	for _, spec in ipairs({
		{ from = playerA, toUserId = playerB.UserId },
		{ from = playerB, toUserId = playerA.UserId },
		}) do
		local humanoid = getHumanoid(spec.from)
		if humanoid then
			humanoid.Died:Connect(function()
				onDeath(spec.from, spec.toUserId)
			end)
		end
	end
end

local function lifeLinkEvent()
	if twoPlayerMode then
		updateAllLabels("Life link cannot be chosen with only 2 players left.")
		return
	end
	if fairModeEnabled and #getAlivePlayers() < 3 then
		updateAllLabels("Life link needs at least 3 players in fairmode.")
		return
	end

	updateAllLabels("Someone will be life linked with someone!")
	if not countdown("Someone will be life linked with someone!") then
		return
	end

	local candidates = getRandomDistinctPlayers(99, {})
	if #candidates < 2 then
		updateAllLabels("Not enough players for life link event.")
		return
	end

	local chosenA, chosenB
	for i = 1, #candidates do
		for j = i + 1, #candidates do
			local a = candidates[i]
			local b = candidates[j]
			local key = getLifeLinkPairKey(a.UserId, b.UserId)
			if not usedLifeLinkPairs[key] then
				chosenA, chosenB = a, b
				usedLifeLinkPairs[key] = true
				break
			end
		end
		if chosenA then break end
	end

	if not chosenA then
		updateAllLabels("No new life link pairs available.")
		return
	end

	createLifeLink(chosenA, chosenB)
	updateAllLabels(chosenA.Name .. " is life linked with " .. chosenB.Name)
end

local function giveSwordEvent()
	if not swordTemplate then
		if swordTemplateBackup then swordTemplate = swordTemplateBackup else updateAllLabels("ClassicSword not found.") return end
	end
	local targets = getRandomDistinctPlayers(getMultiplierCount(), { aliveOnly = false })
	if #targets == 0 then updateAllLabels("No players available.") return end
	local msg = #targets == 1 and "A player will be given a sword!" or (tostring(#targets) .. " players will be given swords!")
	updateAllLabels(msg)
	if not countdown(msg) then return end
	local granted = {}
	for _, target in ipairs(targets) do
		local backpack = target:FindFirstChildOfClass("Backpack")
		if backpack then
			local clonedSword = swordTemplate:Clone()
			clonedSword.Parent = backpack
			table.insert(granted, target)
		end
	end
	if #granted == 0 then updateAllLabels("Target backpack not found.") return end
	updateAllLabels(formatPlayerNames(granted) .. " got the sword!")
end

local function plateRiseEvent()
	if not plateModeEnabled then
		return
	end

	local target, plate, displayName = getPlateEventTarget()
	if not plate then
		updateAllLabels("No players available.")
		return
	end

	updateAllLabels("Someones plate will go 20 studs higher!")
	if not countdown("Someones plate will go 20 studs higher!") then
		return
	end

	highlightPlate(plate)
	plate.Position = plate.Position + Vector3.new(0, 20, 0)
	if currentPlateGamemode == "mega" then
		for _, p in ipairs(Players:GetPlayers()) do
			if roundParticipantUserIds[p.UserId] then
				teleportPlayerToAssignedPlate(p)
			end
		end
	else
		teleportPlayerToAssignedPlate(target)
	end
	updateAllLabels(displayName .. " got raised!")
end

local function getPlateEventCandidates()
	local candidates = {}
	for userId, entry in pairs(plateAssignments) do
		if roundParticipantUserIds[userId] and entry and entry.plate and entry.plate.Parent then
			local player = getPlayerByUserId(userId)
			local humanoid = player and getHumanoid(player)
			if player and humanoid and humanoid.Health > 0 then
				table.insert(candidates, player)
			end
		end
	end
	return candidates
end

highlightPlate = function(plate)
	if not plate or not plate.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "PlateEventHighlight"
	h.Adornee = plate
	h.FillColor = Color3.fromRGB(0, 120, 255)
	h.OutlineColor = Color3.fromRGB(180, 220, 255)
	h.FillTransparency = 0.35
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = workspace
	task.delay(PLATE_HIGHLIGHT_DURATION, function()
		if h and h.Parent then
			h:Destroy()
		end
	end)
end

local function randomPointOnPlateTop(plate)
	local halfX = math.max(1, plate.Size.X * 0.5 - 2)
	local halfZ = math.max(1, plate.Size.Z * 0.5 - 2)
	return plate.Position + Vector3.new(math.random() * 2 * halfX - halfX, plate.Size.Y * 0.5, math.random() * 2 * halfZ - halfZ)
end

local function spawnTreeOnPlate(plate)
	if not plate or not plate.Parent then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PlateTree"
	folder.Parent = workspace

	local basePos = randomPointOnPlateTop(plate)
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(101, 67, 33)
	trunk.Size = Vector3.new(3, 16, 3)
	trunk.CFrame = CFrame.new(basePos + Vector3.new(0, 8, 0))
	trunk.Parent = folder

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Shape = Enum.PartType.Ball
	leaves.Anchored = true
	leaves.CanCollide = false
	leaves.Material = Enum.Material.Grass
	leaves.Color = Color3.fromRGB(50, 170, 60)
	leaves.Size = Vector3.new(14, 14, 14)
	leaves.CFrame = trunk.CFrame + Vector3.new(0, 12, 0)
	leaves.Parent = folder
	table.insert(activePlateTrees, folder)
end



local function getTreeFolderFromPart(part)
	local node = part
	while node do
		if node:IsA("Folder") and node.Name == "PlateTree" then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function igniteTree(treeFolder)
	if not treeFolder or not treeFolder.Parent then
		return
	end
	if burningTreeTokens[treeFolder] then
		return
	end
	local token = tostring(os.clock()) .. tostring(math.random())
	burningTreeTokens[treeFolder] = token
	task.spawn(function()
		local start = os.clock()
		while running and treeFolder.Parent and burningTreeTokens[treeFolder] == token and os.clock() - start < FIRE_TREE_BURN_DURATION do
			local alpha = math.clamp((os.clock() - start) / FIRE_TREE_BURN_DURATION, 0, 1)
			for _, d in ipairs(treeFolder:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Transparency = alpha
				end
			end
			task.wait(0.2)
		end
		burningTreeTokens[treeFolder] = nil
		if treeFolder and treeFolder.Parent then
			treeFolder:Destroy()
		end
	end)
end

applyFireToPlayer = function(targetPlayer)
	if not targetPlayer then
		return false
	end
	if activeFireStatesByUserId[targetPlayer.UserId] then
		return false
	end
	local humanoid = getHumanoid(targetPlayer)
	local root = targetPlayer.Character and getRootPart(targetPlayer.Character)
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end

	local token = tostring(os.clock()) .. ":" .. tostring(math.random())
	local fireFx = Instance.new("Fire")
	fireFx.Name = "BurningEffect"
	fireFx.Size = 8
	fireFx.Heat = 10
	fireFx.Color = Color3.fromRGB(255, 120, 30)
	fireFx.SecondaryColor = Color3.fromRGB(255, 50, 10)
	fireFx.Parent = root

	local state = { token = token, fx = fireFx, touchConnection = nil }
	activeFireStatesByUserId[targetPlayer.UserId] = state

	state.touchConnection = root.Touched:Connect(function(hit)
		local current = activeFireStatesByUserId[targetPlayer.UserId]
		if not current or current.token ~= token then
			return
		end
		local treeFolder = getTreeFolderFromPart(hit)
		if treeFolder then
			igniteTree(treeFolder)
		end
		local otherCharacter = hit and hit.Parent
		if not otherCharacter then
			return
		end
		local otherPlayer = Players:GetPlayerFromCharacter(otherCharacter)
		if otherPlayer and otherPlayer ~= targetPlayer then
			applyFireToPlayer(otherPlayer)
		end
	end)

	task.spawn(function()
		local ticks = math.floor(FIRE_TOTAL_DAMAGE / FIRE_TICK_DAMAGE)
		for _ = 1, ticks do
			if not running then break end
			local current = activeFireStatesByUserId[targetPlayer.UserId]
			if not current or current.token ~= token then break end
			local h = getHumanoid(targetPlayer)
			if not h or h.Health <= 0 then break end
			h:TakeDamage(FIRE_TICK_DAMAGE)
			task.wait(FIRE_TICK_INTERVAL)
		end
		local current = activeFireStatesByUserId[targetPlayer.UserId]
		if current and current.token == token then
			if current.touchConnection then current.touchConnection:Disconnect() end
			if current.fx and current.fx.Parent then current.fx:Destroy() end
			activeFireStatesByUserId[targetPlayer.UserId] = nil
		end
	end)
	return true
end

local function fireEvent(forcedTargetUserId)
	local msg = "Someone will be set on fire!"
	updateAllLabels(msg)
	if not countdown(msg) then return end
	local target = forcedTargetUserId and getPlayerByUserId(forcedTargetUserId) or getRandomPlayer()
	if not target then
		updateAllLabels("No players available.")
		return
	end
	if applyFireToPlayer(target) then
		updateAllLabels(target.Name .. " is on fire!")
	else
		updateAllLabels("Fire failed (target unavailable).")
	end
end

local function isPlatePart(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if megaPlatePart and part == megaPlatePart then
		return true
	end
	for _, entry in pairs(plateAssignments) do
		if entry and entry.plate == part then
			return true
		end
	end
	return false
end

local function getPlateZoneCenter()
	local sum = Vector3.new(0, 0, 0)
	local count = 0
	for _, entry in pairs(plateAssignments) do
		if entry and entry.plate and entry.plate.Parent then
			sum = sum + entry.plate.Position
			count = count + 1
		end
	end
	if count > 0 then
		return sum / count
	end
	return triggerPart and triggerPart.Position or Vector3.new(0, PLATE_HEIGHT, 0)
end

local function getOrbitalTargetPosition()
	if currentPlateGamemode == "mega" then
		local players = getRandomDistinctPlayers(99, { aliveOnly = true })
		if #players == 0 then
			return nil, nil
		end
		local p = players[math.random(1, #players)]
		local root = getRootPart(p.Character)
		return (root and root.Position or nil), nil
	end

	local candidates = {}
	for _, entry in pairs(plateAssignments) do
		local plate = entry and entry.plate
		if plate and plate.Parent then
			table.insert(candidates, plate)
		end
	end
	if #candidates == 0 then
		return nil, nil
	end
	local plate = candidates[math.random(1, #candidates)]
	return plate.Position, plate
end

local function createOrbitalStrikeModel(spawnCFrame)
	local model = Instance.new("Model")
	model.Name = "OrbitalStrike_Runtime"

	local function makePart(name, size, material, color, localCFrame, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Material = material
		part.Color = color
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		if shape then
			part.Shape = shape
		end
		part.CFrame = spawnCFrame * localCFrame
		part.Parent = model
		return part
	end

	local coreBody = makePart(
		"Body",
		Vector3.new(8, 8, 16),
		Enum.Material.Metal,
		Color3.fromRGB(52, 56, 68),
		CFrame.new(0, 0, 0),
		nil
	)

	makePart(
		"NoseCone",
		Vector3.new(7, 7, 4),
		Enum.Material.Metal,
		Color3.fromRGB(95, 100, 120),
		CFrame.new(0, 0, -10),
		nil
	)

	makePart(
		"Engine",
		Vector3.new(6.5, 6.5, 4),
		Enum.Material.Metal,
		Color3.fromRGB(38, 42, 50),
		CFrame.new(0, 0, 10),
		nil
	)

	local dish = makePart(
		"Dish",
		Vector3.new(5.5, 5.5, 2),
		Enum.Material.Metal,
		Color3.fromRGB(170, 175, 190),
		CFrame.new(0, 2.2, -3.5) * CFrame.Angles(math.rad(20), 0, 0),
		Enum.PartType.Ball
	)
	dish.Size = Vector3.new(5.5, 2, 5.5)

	makePart(
		"DishNeck",
		Vector3.new(1.2, 2.2, 1.2),
		Enum.Material.Metal,
		Color3.fromRGB(120, 125, 145),
		CFrame.new(0, 1, -3.5),
		nil
	)

	local crystal = makePart(
		"Crystal",
		Vector3.new(2.8, 2.8, 2.8),
		Enum.Material.Neon,
		Color3.fromRGB(80, 200, 255),
		CFrame.new(0, -1.1, -8),
		Enum.PartType.Ball
	)

	local beamStart = makePart(
		"Beamstart",
		Vector3.new(1.6, 1.6, 1.6),
		Enum.Material.Neon,
		Color3.fromRGB(255, 255, 255),
		CFrame.new(0, -1.1, -11.2),
		Enum.PartType.Ball
	)

	local panelSize = Vector3.new(16, 0.7, 8)
	makePart(
		"PanelLeft",
		panelSize,
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(35, 90, 160),
		CFrame.new(-12, 0, 0),
		nil
	)
	makePart(
		"PanelRight",
		panelSize,
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(35, 90, 160),
		CFrame.new(12, 0, 0),
		nil
	)

	local panelFrameColor = Color3.fromRGB(30, 35, 45)
	makePart("PanelLeftFrame", Vector3.new(16.3, 0.25, 8.3), Enum.Material.Metal, panelFrameColor, CFrame.new(-12, 0.5, 0), nil)
	makePart("PanelRightFrame", Vector3.new(16.3, 0.25, 8.3), Enum.Material.Metal, panelFrameColor, CFrame.new(12, 0.5, 0), nil)

	local thruster = makePart(
		"ThrusterGlow",
		Vector3.new(2.4, 2.4, 4),
		Enum.Material.Neon,
		Color3.fromRGB(255, 120, 35),
		CFrame.new(0, 0, 13),
		nil
	)
	local thrusterLight = Instance.new("PointLight")
	thrusterLight.Color = Color3.fromRGB(255, 140, 50)
	thrusterLight.Brightness = 3
	thrusterLight.Range = 16
	thrusterLight.Parent = thruster

	makePart("AntennaMast", Vector3.new(0.7, 5, 0.7), Enum.Material.Metal, Color3.fromRGB(150, 155, 170), CFrame.new(0, 3.5, 1), nil)
	makePart("AntennaHead", Vector3.new(2.2, 2.2, 2.2), Enum.Material.Metal, Color3.fromRGB(180, 185, 198), CFrame.new(0, 6.1, 1), Enum.PartType.Ball)
	makePart("RadiatorLeft", Vector3.new(2.5, 5.5, 0.5), Enum.Material.Metal, Color3.fromRGB(90, 95, 110), CFrame.new(-5.5, 0, 2.5), nil)
	makePart("RadiatorRight", Vector3.new(2.5, 5.5, 0.5), Enum.Material.Metal, Color3.fromRGB(90, 95, 110), CFrame.new(5.5, 0, 2.5), nil)

	model.PrimaryPart = coreBody
	local orbitRing = makePart(
		"AimRing",
		Vector3.new(0.6, 18, 18),
		Enum.Material.Metal,
		Color3.fromRGB(120, 45, 45),
		CFrame.new(0, -1.1, -11.2) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.PartType.Cylinder
	)
	orbitRing.Transparency = 0.25

	crystal:SetAttribute("OrbitalVisual", true)
	beamStart:SetAttribute("OrbitalVisual", true)
	model.Parent = workspace
	return model
end

local function prepareOrbitalModel(strike)
	if not strike then
		return nil, nil, nil
	end
	local beamStart = strike:FindFirstChild("Beamstart", true)
	local crystal = strike:FindFirstChild("Crystal", true)
	if not (beamStart and beamStart:IsA("BasePart")) then
		return nil, nil, nil
	end
	local base = beamStart
	if not (base and base:IsA("BasePart")) then
		return nil, nil, nil
	end

	local crystalPart = (crystal and crystal:IsA("BasePart")) and crystal or base
	for _, d in ipairs(strike:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end

	return base, crystalPart, nil
end

local function triggerOrbitalSphereExplosion(position, hitTargetPlate)
	local explosion = Instance.new("Part")
	explosion.Name = "OrbitalSphereExplosion"
	explosion.Shape = Enum.PartType.Ball
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.CanTouch = false
	explosion.CanQuery = false
	explosion.Material = Enum.Material.Neon
	explosion.Color = hitTargetPlate and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 120, 80)
	explosion.Size = Vector3.new(ORBITAL_SPHERE_SIZE, ORBITAL_SPHERE_SIZE, ORBITAL_SPHERE_SIZE)
	explosion.CFrame = CFrame.new(position)
	explosion.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 110)
	light.Brightness = 10
	light.Range = ORBITAL_SPHERE_SIZE * 7
	light.Parent = explosion

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { explosion, triggerPart }

	local function affectInsideExplosion()
		for _, part in ipairs(workspace:GetPartBoundsInBox(explosion.CFrame, explosion.Size, overlapParams)) do
			if part and part:IsA("BasePart") then
				local char = part:FindFirstAncestorOfClass("Model")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum.Health = 0
				elseif not isPlatePart(part) and part.Position.Y > -100 and part ~= triggerPart and not part:IsDescendantOf(triggerPart) then
					local treeFolder = getTreeFolderFromPart(part)
					if treeFolder then
						treeFolder:Destroy()
					else
						pcall(function() part:Destroy() end)
					end
				end
			end
		end
	end

	local startTime = os.clock()
	while explosion.Parent do
		local alpha = math.clamp((os.clock() - startTime) / ORBITAL_SPHERE_EXPAND_TIME, 0, 1)
		local scale = 1 + ((ORBITAL_SPHERE_EXPLOSION_SCALE - 1) * alpha)
		explosion.Size = Vector3.new(ORBITAL_SPHERE_SIZE * scale, ORBITAL_SPHERE_SIZE * scale, ORBITAL_SPHERE_SIZE * scale)
		affectInsideExplosion()
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end

	local fadeStart = os.clock()
	while explosion.Parent do
		local alpha = math.clamp((os.clock() - fadeStart) / ORBITAL_SPHERE_FADE_TIME, 0, 1)
		explosion.Transparency = alpha
		affectInsideExplosion()
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end

	if explosion.Parent then
		explosion:Destroy()
	end
end

local function runOrbitalBeam(strikeModel, beamStartPart, targetPos, targetPlate)
	if not strikeModel or not strikeModel.Parent or not beamStartPart or not beamStartPart.Parent then
		return
	end

	local origin = beamStartPart.Position
	local dir = (targetPos - origin)
	if dir.Magnitude <= 0.1 then
		dir = Vector3.new(0, -1, 0)
	else
		dir = dir.Unit
	end

	local sphere = Instance.new("Part")
	sphere.Name = "OrbitalStrikeSphere"
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = Color3.fromRGB(255, 80, 60)
	sphere.Size = Vector3.new(ORBITAL_SPHERE_SIZE, ORBITAL_SPHERE_SIZE, ORBITAL_SPHERE_SIZE)
	sphere.CFrame = CFrame.new(origin)
	sphere.Parent = workspace

	local sphereLight = Instance.new("PointLight")
	sphereLight.Color = Color3.fromRGB(255, 100, 70)
	sphereLight.Brightness = 8
	sphereLight.Range = ORBITAL_SPHERE_SIZE * 5
	sphereLight.Parent = sphere

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { strikeModel, sphere, triggerPart }

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { strikeModel, sphere, triggerPart }

	local function processSphereContacts()
		for _, part in ipairs(workspace:GetPartBoundsInBox(sphere.CFrame, sphere.Size, overlapParams)) do
			if part and part:IsA("BasePart") then
				local char = part:FindFirstAncestorOfClass("Model")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum.Health = 0
					return true, false
				end
				if isPlatePart(part) then
					local isTarget = targetPlate and (part == targetPlate) or false
					return true, isTarget
				end
				if part.Position.Y > -100 and part ~= triggerPart and not part:IsDescendantOf(triggerPart) then
					local treeFolder = getTreeFolderFromPart(part)
					if treeFolder then
						treeFolder:Destroy()
					else
						pcall(function() part:Destroy() end)
					end
				end
			end
		end
		return false, false
	end

	local cursor = origin
	local travelled = 0
	local maxRange = math.max(ORBITAL_MAX_RANGE, (targetPos - origin).Magnitude + (ORBITAL_SPHERE_SIZE * 0.5) + 10)
	local maxEndPoint = origin + dir * maxRange
	local hitTargetPlate = false
	local explosionPos = nil

	while sphere.Parent and travelled < maxRange do
		local dt = RunService.Heartbeat:Wait()
		local step = math.min(ORBITAL_SPHERE_SPEED * dt, maxRange - travelled)
		if step <= 0 then
			break
		end

		local ray = workspace:Raycast(cursor, dir * step, rayParams)
		local nextPoint = cursor + dir * step
		if ray then
			local hit = ray.Instance
			local hitModel = hit and hit:FindFirstAncestorOfClass("Model")
			local hitHum = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
			if hitHum and hitHum.Health > 0 then
				hitHum.Health = 0
				explosionPos = ray.Position
				break
			end
			if hit and hit:IsA("BasePart") and isPlatePart(hit) then
				hitTargetPlate = targetPlate and (hit == targetPlate) or false
				explosionPos = ray.Position
				break
			end
			if hit and hit:IsA("BasePart") and hit.Position.Y > -100 and hit ~= triggerPart and not hit:IsDescendantOf(triggerPart) then
				local treeFolder = getTreeFolderFromPart(hit)
				if treeFolder then
					treeFolder:Destroy()
				else
					local hitChar = hit:FindFirstAncestorOfClass("Model")
					if not (hitChar and hitChar:FindFirstChildOfClass("Humanoid")) then
						pcall(function() hit:Destroy() end)
					end
				end
			end
			nextPoint = ray.Position + dir * 0.35
		end

		cursor = nextPoint
		sphere.CFrame = CFrame.new(cursor)
		travelled = (cursor - origin).Magnitude

		if cursor.Y <= -100 then
			explosionPos = cursor
			break
		end

		local shouldDetonate, targetHit = processSphereContacts()
		if shouldDetonate then
			hitTargetPlate = targetHit
			explosionPos = cursor
			break
		end
	end

	if not explosionPos then
		explosionPos = (travelled >= maxRange) and maxEndPoint or cursor
	end

	if sphere and sphere.Parent then
		sphere:Destroy()
	end

	triggerOrbitalSphereExplosion(explosionPos, hitTargetPlate)
	return hitTargetPlate
end

orbitalStrikeEvent = function(forcedShots)
	if not plateModeEnabled then
		updateAllLabels("Orbital strike only appears in plate modes.")
		return
	end
	local shots = forcedShots
	if not shots then
		shots = math.random(ORBITAL_MIN_SHOTS, ORBITAL_MAX_SHOTS)
	end
	shots = math.clamp(tonumber(shots) or 1, ORBITAL_MIN_SHOTS, ORBITAL_MAX_SHOTS)

	updateAllLabels("An orbital strike is coming get ready!")
	if not countdown("An orbital strike is coming get ready!") then
		return
	end

	local zoneCenter = getPlateZoneCenter()
	local pivot = CFrame.new(zoneCenter + Vector3.new(0, ORBITAL_HEIGHT, 0))
	local strike = createOrbitalStrikeModel(pivot)
	pcall(function() strike:PivotTo(pivot) end)

	local beamStartPart, crystalPart, strikeHolder = prepareOrbitalModel(strike)
	if not beamStartPart or not crystalPart then
		strike:Destroy()
		return
	end

	for i = 1, shots do
		if not running or not strike.Parent then break end
		local targetPos, targetPlate = getOrbitalTargetPosition()
		if not targetPos then break end

		local currentPivot = strike:GetPivot()
		local desiredPos = currentPivot.Position
		local aimedPivot = CFrame.new(desiredPos, targetPos)
		for step = 1, 10 do
			local alpha = step / 10
			local lerpedPivot = currentPivot:Lerp(aimedPivot, alpha)
			pcall(function() strike:PivotTo(lerpedPivot) end)
			if strikeHolder and strikeHolder.Parent then
				strikeHolder.CFrame = CFrame.new(lerpedPivot.Position)
			end
			for _, d in ipairs(strike:GetDescendants()) do
				if d:IsA("BasePart") then
					d.AssemblyLinearVelocity = Vector3.zero
					d.AssemblyAngularVelocity = Vector3.zero
				end
			end
			RunService.Heartbeat:Wait()
		end

		local originalColor = crystalPart.Color
		crystalPart.Color = Color3.fromRGB(255, 0, 0)
		local shakeUntil = os.clock() + 0.7
		while running and os.clock() < shakeUntil do
			local offset = Vector3.new((math.random()-0.5)*0.6, (math.random()-0.5)*0.6, (math.random()-0.5)*0.6)
			pcall(function() strike:PivotTo(CFrame.new(aimedPivot.Position + offset, targetPos)) end)
			RunService.Heartbeat:Wait()
		end
		pcall(function() strike:PivotTo(aimedPivot) end)
		if strikeHolder and strikeHolder.Parent then
			strikeHolder.CFrame = CFrame.new(aimedPivot.Position)
		end

		runOrbitalBeam(strike, beamStartPart, targetPos, targetPlate)
		if not crystalPart.Parent then break end
		crystalPart.Color = Color3.fromRGB(0, 170, 255)
		task.wait(0.6)
		crystalPart.Color = originalColor
	end

	if strike and strike.Parent then strike:Destroy() end
	if strikeHolder and strikeHolder.Parent then strikeHolder:Destroy() end
end

local function plateTreeEvent()
	if not plateModeEnabled then
		return
	end
	local _, plate, displayName = getPlateEventTarget()
	if not plate then
		updateAllLabels("No players available.")
		return
	end
	updateAllLabels("Someone will grow a tree!")
	if not countdown("Someone will grow a tree!") then
		return
	end
	highlightPlate(plate)
	spawnTreeOnPlate(plate)
	updateAllLabels(displayName .. " got a tree!")
end

local function plateShrinkEvent()
	if not plateModeEnabled then
		return
	end
	local target, plate, displayName = getPlateEventTarget()
	if not plate then
		updateAllLabels("No players available.")
		return
	end
	updateAllLabels("Someones plate will shrink by 10 studs")
	if not countdown("Someones plate will shrink by 10 studs") then
		return
	end
	highlightPlate(plate)
	plate.Size = Vector3.new(math.max(10, plate.Size.X - PLATE_SHRINK_AMOUNT), plate.Size.Y, math.max(10, plate.Size.Z - PLATE_SHRINK_AMOUNT))
	if currentPlateGamemode == "mega" then
		for _, p in ipairs(Players:GetPlayers()) do
			if roundParticipantUserIds[p.UserId] then
				teleportPlayerToAssignedPlate(p)
			end
		end
	else
		teleportPlayerToAssignedPlate(target)
	end
	updateAllLabels(displayName .. " shrunk!")
end

local function plateGlobalShiftEvent()
	if not plateModeEnabled then
		return
	end
	local any = false
	for _, entry in pairs(plateAssignments) do
		if entry and entry.plate and entry.plate.Parent then
			any = true
			break
		end
	end
	if not any then
		updateAllLabels("No plates available.")
		return
	end
	updateAllLabels("All plates will move in different directions!")
	if not countdown("All plates will move in different directions!") then
		return
	end
	local dirs = {
		Vector3.new(PLATE_GLOBAL_SHIFT_DISTANCE, 0, 0),
		Vector3.new(-PLATE_GLOBAL_SHIFT_DISTANCE, 0, 0),
		Vector3.new(0, PLATE_GLOBAL_SHIFT_DISTANCE, 0),
		Vector3.new(0, -PLATE_GLOBAL_SHIFT_DISTANCE, 0),
	}
	for userId, entry in pairs(plateAssignments) do
		local plate = entry and entry.plate
		if plate and plate.Parent then
			highlightPlate(plate)
			local oldCanCollide = plate.CanCollide
			plate.CanCollide = false
			plate.Position = plate.Position + dirs[math.random(1, #dirs)]
			plate.CanCollide = oldCanCollide
			local p = getPlayerByUserId(userId)
			if p then
				teleportPlayerToAssignedPlate(p)
			end
		end
	end
	updateAllLabels("All plates shifted!")
end

local function spawnAcidDrop(parent, cloudPart, acidHitCounts)
	local drop = Instance.new("Part")
	drop.Name = "AcidDrop"
	drop.Anchored = true
	drop.CanCollide = false
	drop.CanTouch = false
	drop.CanQuery = false
	drop.Material = Enum.Material.Neon
	drop.Color = Color3.fromRGB(80, 255, 80)
	drop.Size = Vector3.new(1.5, 10, 1.5)

	local half = ACID_RAIN_CLOUD_DIAMETER * 0.5
	local startX, startZ, startY
	if math.random() < ACID_PLAYER_TARGET_CHANCE then
		local targetPlayer = getRandomPlayer()
		local targetRoot = targetPlayer and getRootPart(targetPlayer.Character)
		if targetRoot then
			startX = targetRoot.Position.X
			startZ = targetRoot.Position.Z
			startY = targetRoot.Position.Y + 200
		else
			startX = cloudPart.Position.X + math.random(-half, half)
			startZ = cloudPart.Position.Z + math.random(-half, half)
		end
	else
		startX = cloudPart.Position.X + math.random(-half, half)
		startZ = cloudPart.Position.Z + math.random(-half, half)
	end

	startY = startY or (cloudPart.Position.Y - ACID_RAIN_CLOUD_HEIGHT + 200)
	drop.Position = Vector3.new(startX, startY, startZ)
	drop.Parent = parent

	local speed = 260
	local direction = Vector3.new(0, -1, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { parent, cloudPart }
	local humanoidHitCounts = {}

	task.spawn(function()
		while running and drop.Parent do
			local dt = RunService.Heartbeat:Wait()
			local move = direction * speed * dt
			local origin = drop.Position
			local rayResult = workspace:Raycast(origin, move, rayParams)

			if rayResult then
				local hitPart = rayResult.Instance
				local hitCharacter = hitPart and hitPart:FindFirstAncestorOfClass("Model")
				local hitHumanoid = hitCharacter and hitCharacter:FindFirstChildOfClass("Humanoid")
				if hitHumanoid and hitHumanoid.Health > 0 then
					hitHumanoid:TakeDamage(50)
					local hHits = (humanoidHitCounts[hitHumanoid] or 0) + 1
					humanoidHitCounts[hitHumanoid] = hHits
					if hHits >= 3 then
						hitHumanoid.Health = 0
					end
					drop:Destroy()
					return
				end

				if hitPart and hitPart:IsA("BasePart") and hitPart ~= cloudPart and not isAcidProtectedPart(hitPart) then
					if not acidTintedParts[hitPart] then
						acidTintedParts[hitPart] = hitPart.Color
					end
					hitPart.Color = Color3.fromRGB(40, 220, 40)
					local hits = (acidHitCounts[hitPart] or 0) + 1
					acidHitCounts[hitPart] = hits

					if hits >= 3 and deadlyAcidEnabled and hitPart.Parent then
						hitPart:Destroy()
					end

					if hits < 3 then
						drop:Destroy()
						return
					end

					drop.Position = rayResult.Position + direction * 8
				else
					drop:Destroy()
					return
				end
			else
				drop.Position = origin + move
			end

			if drop.Position.Y < -500 then
				drop:Destroy()
				return
			end
		end

		if drop.Parent then
			drop:Destroy()
		end
	end)
end

local function runAcidRainAt(anchorPosition)
	local eventFolder = Instance.new("Folder")
	eventFolder.Name = "AcidRainEvent"
	eventFolder.Parent = workspace

	local cloud = Instance.new("Part")
	cloud.Name = "AcidRainCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanTouch = false
	cloud.CanQuery = false
	cloud.Material = Enum.Material.SmoothPlastic
	cloud.Color = Color3.fromRGB(10, 70, 20)
	cloud.Transparency = 0.2
	cloud.Size = Vector3.new(ACID_RAIN_CLOUD_DIAMETER, 20, ACID_RAIN_CLOUD_DIAMETER)
	cloud.Position = anchorPosition + Vector3.new(0, ACID_RAIN_CLOUD_HEIGHT, 0)
	cloud.Parent = eventFolder

	local acidHitCounts = {}
	local endTime = os.clock() + ACID_RAIN_DURATION

	while running and os.clock() < endTime do
		for _ = 1, ACID_RAIN_DROPS_PER_SECOND do
			spawnAcidDrop(eventFolder, cloud, acidHitCounts)
		end
		task.wait(1)
	end

	eventFolder:Destroy()
end

local function acidRainEvent(forcedTargetUserId)
	updateAllLabels("Acid rain is coming! get ready")
	if not countdown("Acid rain is coming! get ready") then
		return
	end

	local target = forcedTargetUserId and getPlayerByUserId(forcedTargetUserId) or getRandomPlayer()
	if not target then
		target = getRandomPlayer()
	end

	if not target then
		updateAllLabels("No players available.")
		return
	end

	local root = getRootPart(target.Character)
	local anchorPosition = root and root.Position or Vector3.new(0, 50, 0)
	updateAllLabels("Acid rain is starting above " .. target.Name .. "!")

	task.spawn(runAcidRainAt, anchorPosition)
end

local function runHomingOrbsInstance(orbCount, orbSize, orbSpeed)
	local orbFolder = Instance.new("Folder")
	orbFolder.Name = "SpecialEvent_HomingOrbs"
	orbFolder.Parent = workspace

	local eventSound = Instance.new("Sound")
	eventSound.SoundId = HOMING_ORB_SOUND_ID
	eventSound.Looped = true
	eventSound.Volume = 1
	eventSound.Parent = SoundService
	pcall(function()
		eventSound:Play()
	end)

	local orbs = {}
	local focusPlayer = getRandomPlayer()
	local focusRoot = focusPlayer and getRootPart(focusPlayer.Character)
	for i = 1, orbCount do
		local orb = Instance.new("Part")
		orb.Name = "HomingOrb"
		orb.Shape = Enum.PartType.Ball
		orb.Material = Enum.Material.Neon
		orb.Color = Color3.fromRGB(255, 0, 0)
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanTouch = false
		orb.CanQuery = false
		orb.CastShadow = false
		orb.Size = Vector3.new(orbSize, orbSize, orbSize)

		if focusRoot then
			local angle = math.random() * math.pi * 2
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 200
			offset = offset + Vector3.new(0, math.random(10, 50), 0)
			orb.Position = focusRoot.Position + offset
		else
			orb.Position = Vector3.new(math.random(-120, 120), math.random(12, 80), math.random(-120, 120))
		end

		orb.Parent = orbFolder
		table.insert(orbs, orb)
	end

	local lastDamageTick = 0
	local radius = orbSize * 0.5
	local endTime = os.clock() + HOMING_ORB_DURATION

	while running and os.clock() < endTime do
		local dt = RunService.Heartbeat:Wait()

		for _, orb in ipairs(orbs) do
			if orb and orb.Parent then
				local nearestRoot = nil
				local nearestDistance = math.huge
				for _, player in ipairs(Players:GetPlayers()) do
					if not isPlayerActiveInRound(player) then
						continue
					end
					local humanoid = getHumanoid(player)
					local root = getRootPart(player.Character)
					if humanoid and humanoid.Health > 0 and root then
						local distance = (root.Position - orb.Position).Magnitude
						if distance < nearestDistance then
							nearestDistance = distance
							nearestRoot = root
						end
					end
				end

				if nearestRoot then
					local direction = nearestRoot.Position - orb.Position
					if direction.Magnitude > 0 then
						orb.Position = orb.Position + direction.Unit * orbSpeed * dt
					end
				end
			end
		end

		if os.clock() - lastDamageTick >= 1 then
			for _, player in ipairs(Players:GetPlayers()) do
				if not isPlayerActiveInRound(player) then
					continue
				end
				local humanoid = getHumanoid(player)
				local root = getRootPart(player.Character)
				if humanoid and humanoid.Health > 0 and root then
					for _, orb in ipairs(orbs) do
						if orb and orb.Parent and (root.Position - orb.Position).Magnitude <= radius then
							humanoid:TakeDamage(20)
							break
						end
					end
				end
			end
			lastDamageTick = os.clock()
		end
	end

	pcall(function()
		eventSound:Stop()
	end)
	eventSound:Destroy()
	orbFolder:Destroy()
end

local function specialEventHomingOrbs()
	updateAllLabels("Homing orbs are incoming!")
	if not countdown("Homing orbs are incoming!") then
		return
	end

	local orbCount = math.random(HOMING_ORB_MIN_COUNT, HOMING_ORB_MAX_COUNT)
	local orbSize = math.random(HOMING_ORB_MIN_SIZE, HOMING_ORB_MAX_SIZE)
	local orbSpeed = math.random(HOMING_ORB_MIN_SPEED, HOMING_ORB_MAX_SPEED)
	updateAllLabels("Homing orbs are incoming!")

	task.spawn(runHomingOrbsInstance, orbCount, orbSize, orbSpeed)
end

local function runForcedEvent(forcedEvent)
	if not forcedEvent then
		return false
	end

	if forcedEvent.kind == "homingorbs" then
		specialEventHomingOrbs()
		return true
	end

	if forcedEvent.kind == "os" then
		orbitalStrikeEvent(forcedEvent.amount)
		return true
	end

	if forcedEvent.kind == "acid" then
		acidRainEvent(forcedEvent.targetUserId)
		return true
	end

	if forcedEvent.kind == "fire" then
		fireEvent(forcedEvent.targetUserId)
		return true
	end

	if forcedEvent.kind == "confusion" then
		confusionEvent(forcedEvent.targetUserId)
		return true
	end

	if forcedEvent.kind == "shadow" then
		shadowOrbEvent(forcedEvent.targetUserId)
		return true
	end

	if forcedEvent.kind == "globalshadow" then
		globalShadowOrbEvent()
		return true
	end

	if forcedEvent.kind == "tsunami" then
		tsunamiEvent(forcedEvent.class)
		return true
	end

	if forcedEvent.kind == "leg" then
		loseLegsEvent(forcedEvent.targetUserId)
		return true
	end

	if forcedEvent.kind == "kill" then
		if fairModeEnabled and getGlobalAlivePlayerCount() < 10 then
			updateAllLabels("Fairmode: kill event needs at least 10 alive players.")
			return true
		end
		updateAllLabels("Someone is going to die!")
		if not countdown("Someone is going to die!") then
			return true
		end

		local target = getPlayerByUserId(forcedEvent.targetUserId)
		if not target then
			updateAllLabels("Forced target is no longer in game.")
			return true
		end

		updateAllLabels(target.Name .. " will die now!")
		local humanoid = getHumanoid(target)
		if humanoid then
			humanoid.Health = 0
		end
		return true
	end

	if forcedEvent.kind == "fling" then
		updateAllLabels("Someone will be flinged!")
		if not countdown("Someone will be flinged!") then
			return true
		end

		local target = getPlayerByUserId(forcedEvent.targetUserId)
		if not target then
			updateAllLabels("Forced target is no longer in game.")
			return true
		end

		updateAllLabels(target.Name .. " got flinged!")
		flingPlayer(target)
		return true
	end

	if forcedEvent.kind == "char" then
		updateAllLabels("Someone is going to be turned into another player!")
		if not countdown("Someone is going to be turned into another player!") then
			return true
		end

		local target = getPlayerByUserId(forcedEvent.targetUserId)
		local source = getPlayerByUserId(forcedEvent.sourceUserId)
		if not target or not source then
			updateAllLabels("Forced target/source is no longer in game.")
			return true
		end

		local targetHumanoid = getHumanoid(target)
		if targetHumanoid then
			local ok, description = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(source.UserId)
			end)
			if ok and description then
				targetHumanoid:ApplyDescription(description)
			end
		end

		updateAllLabels(target.Name .. " has turned into " .. source.Name .. "!")
		return true
	end

	if forcedEvent.kind == "lightning" then
		updateAllLabels("Someone will be struck by lighting!")
		if not countdown("Someone will be struck by lighting!") then
			return true
		end

		local target = getPlayerByUserId(forcedEvent.targetUserId)
		if not target then
			updateAllLabels("Forced target is no longer in game.")
			return true
		end

		strikeLightningOnPlayer(target)
		updateAllLabels(target.Name .. " got striked!")
		return true
	end

	return false
end

local normalEventFunctions = {
	killRandomPlayer,
	flingRandomPlayer,
	boostRandomPlayerHealth,
	teleportPlayerToPlayer,
	turnIntoAnotherPlayer,
	increasePlayerSize,
	lightningStrikeEvent,
	shrinkRandomPlayer,
	lifeLinkEvent,
	giveSwordEvent,
	acidRainEvent,
	shadowOrbEvent,
	loseLegsEvent,
	confusionEvent,
	fireEvent,
}

local plateModeEventFunctions = {
	killRandomPlayer,
	flingRandomPlayer,
	boostRandomPlayerHealth,
	teleportPlayerToPlayer,
	turnIntoAnotherPlayer,
	increasePlayerSize,
	lightningStrikeEvent,
	shrinkRandomPlayer,
	lifeLinkEvent,
	giveSwordEvent,
	acidRainEvent,
	shadowOrbEvent,
	loseLegsEvent,
	confusionEvent,
	plateRiseEvent,
	plateTreeEvent,
	plateShrinkEvent,
	orbitalStrikeEvent,
	fireEvent,
}

local specialEventFunctions = {
	specialEventHomingOrbs,
	globalShadowOrbEvent,
	tsunamiEvent,
}

local function wipeSystem(requestingPlayer)
	if not requestingPlayer or requestingPlayer.UserId ~= ownerUserId then
		return
	end
	running = false
	triggerUsed = false
	ownerUserId = nil
	forcedNextEvent = nil
	deadlyAcidEnabled = false
	lmsForcedUserIds = nil
	targetAliveOnly = false
	usedLifeLinkPairs = {}
	clearLifeLinks()
	resetAcidTintedParts()
	clearShadowOrbs()
	clearTsunamis()
	clearConfusions()
	clearDuelEffects()
	setRapidFireMode(false)
	currentAnnouncement = ""
	triggerPart.CanTouch = true
	triggerArmedAt = os.clock() + TRIGGER_ARM_DELAY
	restartScheduled = false
	lastEliminatedUserId = nil
	eventCounter = 0
	rapidFirePending = false
	twoPlayerMode = false
	playersWithoutLegs = {}
	usedLifeLinkPairs = {}
	roundParticipantUserIds = {}
	fairModeEnabled = false
	plateModeEnabled = false
	nextRoundPlateMode = true
	clearPlates()
	resetAntiRegenTracking()
	resetAcidTintedParts()
	removeAllGuis()
end

local function isRemoveCommand(message)
	local msg = string.lower((message or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if msg == "remove" then
		return true
	end
	if msg == "/e remove" then
		return true
	end
	if msg:match("^/e%s+remove$") then
		return true
	end
	return false
end

local function isDeadlyAcidCommand(message)
	local msg = string.lower((message or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if msg == "deadlyacid" then
		return true
	end
	if msg == "/e deadlyacid" then
		return true
	end
	if msg:match("^/e%s+deadlyacid$") then
		return true
	end
	return false
end

local function isFairModeCommand(message)
	local msg = string.lower((message or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if msg == "fairmode" then
		return true
	end
	if msg == "/e fairmode" then
		return true
	end
	if msg:match("^/e%s+fairmode$") then
		return true
	end
	return false
end

local function isLmsForceCommand(message)
	local msg = string.lower((message or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if msg == "lmsforce" then
		return true
	end
	if msg == "/e lmsforce" then
		return true
	end
	if msg:match("^/e%s+lmsforce$") then
		return true
	end
	return false
end

local function getTargetModeCommand(message)
	local msg = string.lower((message or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if msg == "alive" or msg == "/e alive" or msg:match("^/e%s+alive$") then
		return "alive"
	end
	if msg == "all" or msg == "/e all" or msg:match("^/e%s+all$") then
		return "all"
	end
	return nil
end

local function parseForceEventCommand(message)
	local msg = string.lower((message or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if msg == "" then
		return nil
	end

	local tokens = {}
	for token in string.gmatch(msg, "%S+") do
		table.insert(tokens, token)
	end

	if #tokens == 0 then
		return nil
	end

	if tokens[1] == "/e" then
		table.remove(tokens, 1)
	end

	local startIndex = nil
	if tokens[1] == "forceevent" or tokens[1] == "forcevent" then
		startIndex = 2
	elseif tokens[1] == "force" and tokens[2] == "event" then
		startIndex = 3
	end

	if not startIndex then
		return nil
	end

	local kind = tokens[startIndex]
	if kind == "homingorbs" then
		return { kind = "homingorbs" }
	end

	if kind == "tsunami" then
		local classToken = tokens[startIndex + 1]
		if not classToken or classToken == "" then
			return { kind = "tsunami" }
		end
		local class = tonumber(classToken)
		if not class then
			return { error = "Forceevent tsunami class must be a number (1-12)." }
		end
		class = math.clamp(math.floor(class), 1, TSUNAMI_MAX_CLASS)
		return { kind = "tsunami", class = class }
	end

	if kind == "os" then
		local amountToken = tokens[startIndex + 1]
		if not amountToken or amountToken == "" then
			return { kind = "os" }
		end
		local amount = tonumber(amountToken)
		if not amount then
			return { error = "Forceevent os amount must be a number (1-3)." }
		end
		amount = math.clamp(math.floor(amount), ORBITAL_MIN_SHOTS, ORBITAL_MAX_SHOTS)
		return { kind = "os", amount = amount }
	end

	if kind == "shadow" or kind == "sorb" then
		local targetToken = tokens[startIndex + 1]
		if not targetToken then
			return { kind = "shadow" }
		end
		local target = findPlayerByToken(targetToken)
		if not target then
			return { error = "Forceevent target not found." }
		end
		return { kind = "shadow", targetUserId = target.UserId }
	end

	if kind == "globalshadow" then
		return { kind = "globalshadow" }
	end

	if kind == "leg" then
		local targetToken = tokens[startIndex + 1]
		if not targetToken then
			return { kind = "leg" }
		end
		local target = findPlayerByToken(targetToken)
		if not target then
			return { error = "Forceevent target not found." }
		end
		return { kind = "leg", targetUserId = target.UserId }
	end

	if kind == "confusion" then
		local targetToken = tokens[startIndex + 1]
		if not targetToken then
			return { kind = "confusion" }
		end
		local target = findPlayerByToken(targetToken)
		if not target then
			return { error = "Forceevent target not found." }
		end
		return {
			kind = "confusion",
			targetUserId = target.UserId,
		}
	end

	if kind == "acid" then
		local targetToken = tokens[startIndex + 1]
		if not targetToken then
			return { kind = "acid" }
		end

		local target = findPlayerByToken(targetToken)
		if not target then
			return { error = "Forceevent target not found." }
		end

		return {
			kind = "acid",
			targetUserId = target.UserId,
		}
	end

	if kind == "fire" then
		local targetToken = tokens[startIndex + 1]
		if not targetToken then
			return { kind = "fire" }
		end
		local target = findPlayerByToken(targetToken)
		if not target then
			return { error = "Forceevent target not found." }
		end
		return {
			kind = "fire",
			targetUserId = target.UserId,
		}
	end

	if kind == "lightning" then
		local target = findPlayerByToken(tokens[startIndex + 1] or "")
		if not target then
			return { error = "Forceevent target not found." }
		end

		return {
			kind = "lightning",
			targetUserId = target.UserId,
		}
	end

	if kind == "kill" or kind == "fling" then
		local target = findPlayerByToken(tokens[startIndex + 1] or "")
		if not target then
			return { error = "Forceevent target not found." }
		end

		return {
			kind = kind,
			targetUserId = target.UserId,
		}
	end

	if kind == "char" then
		local target = findPlayerByToken(tokens[startIndex + 1] or "")
		local source = findPlayerByToken(tokens[startIndex + 2] or "")
		if not target or not source then
			return { error = "Forceevent char needs two valid players." }
		end

		return {
			kind = "char",
			targetUserId = target.UserId,
			sourceUserId = source.UserId,
		}
	end

	return { error = "Invalid forceevent type." }
end

waitForPlateParticipantsReady = function(timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 15)
	while os.clock() < deadline do
		local allReady = true
		for userId, isActive in pairs(roundParticipantUserIds) do
			if isActive then
				local player = getPlayerByUserId(userId)
				local humanoid = player and getHumanoid(player)
				local root = player and player.Character and getRootPart(player.Character)
				if not player or not humanoid or humanoid.Health <= 0 or not root then
					allReady = false
					break
				end
				teleportPlayerToAssignedPlate(player)
			end
		end
		if allReady then
			return true
		end
		task.wait(0.2)
	end
	return false
end


getPlateEventTarget = function()
	if currentPlateGamemode == "mega" then
		if megaPlatePart and megaPlatePart.Parent then
			local anyPlayer = getRandomPlayer()
			return anyPlayer, megaPlatePart, "Mega plate"
		end
		return nil, nil, "Mega plate"
	end

	local candidates = getPlateEventCandidates()
	if #candidates == 0 then
		return nil, nil, nil
	end
	local target = candidates[math.random(1, #candidates)]
	local assignment = plateAssignments[target.UserId]
	local plate = assignment and assignment.plate
	if not plate or not plate.Parent then
		return nil, nil, nil
	end
	return target, plate, target.Name
end

rollAndSelectPlateGamemode = function()
	local modes = { "plate", "mega", "scattered", "bridge" }
	local modeNames = {
		plate = "Plate mode",
		mega = "Mega plate mode",
		scattered = "Scattered mode",
		bridge = "Bridge mode",
	}
	for i = 1, GAMEMODE_ROLL_STEPS do
		local shown = modes[(i % #modes) + 1]
		updateAllLabels("Gamemode: " .. (modeNames[shown] or shown))
		task.wait(GAMEMODE_ROLL_INTERVAL)
	end
	currentPlateGamemode = modes[math.random(1, #modes)]
	updateAllLabels("Gamemode selected: " .. (modeNames[currentPlateGamemode] or currentPlateGamemode))
	task.wait(1)
end

runPlateModeRound = function(starter)
	if not starter then
		return
	end
	if running then
		running = false
		task.wait(0.1)
	end

	plateModeEnabled = true
	nextRoundPlateMode = true
	targetAliveOnly = true
	ownerUserId = starter.UserId
	persistentOwnerUserId = starter.UserId
	forcedNextEvent = nil
	lmsForcedUserIds = nil
	clearLifeLinks()
	clearPlates()
	clearShadowOrbs()
	clearTsunamis()
	clearConfusions()
	clearDuelEffects()
	resetAcidTintedParts()
	setRapidFireMode(false)
	plateOutUserIds = {}
	plateParticipantsReady = false
	plateFallEliminatedUserIds = {}

	rebuildRoundParticipants()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			player:LoadCharacter()
		end
	end

	if running or not plateModeEnabled then
		return
	end

	rebuildRoundParticipants()
	for _, player in ipairs(Players:GetPlayers()) do
		if roundParticipantUserIds[player.UserId] and player.Character then
			player:LoadCharacter()
		end
	end

	rollAndSelectPlateGamemode()
	createPlatesForRoundPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if roundParticipantUserIds[player.UserId] then
			teleportPlayerToAssignedPlate(player)
		end
	end
	fairModeEnabled = true
	waitForPlateParticipantsReady(15)
	plateParticipantsReady = true
	task.wait(0.5)
	if not plateModeEnabled or running then
		return
	end
	startEvents(starter)
end

local function hookPlayer(player)
	if plateModeEnabled and running then
		roundParticipantUserIds[player.UserId] = nil
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		ensureGui(player)
		teleportPlayerToAssignedPlate(player)
		local humanoid = getHumanoid(player)
		if humanoid then
			attachAntiRegen(player, humanoid)
			if plateModeEnabled and running and not isPlayerActiveInRound(player) and not plateOutUserIds[player.UserId] then
				humanoid.Health = 0
			end
			humanoid.Died:Connect(function()
				lastEliminatedUserId = player.UserId
				handlePlayerElimination(player)
				evaluateWinCondition()
			end)
		end
	end)

	player.Chatted:Connect(function(message)
		if isRemoveCommand(message) then
			wipeSystem(player)
			return
		end

		if isDeadlyAcidCommand(message) then
			if player.UserId == ownerUserId then
				deadlyAcidEnabled = true
				updateAllLabels("Deadly acid enabled!")
			end
			return
		end

		if isPlateModeCommand(message) then
			if ownerUserId and player.UserId ~= ownerUserId then
				return
			end
			ownerUserId = player.UserId
			persistentOwnerUserId = player.UserId
			nextRoundPlateMode = true
			if running then
				running = false
			end
			task.spawn(runPlateModeRound, player)
			return
		end

		if isNormalModeCommand(message) then
			if player.UserId == ownerUserId then
				nextRoundPlateMode = false
				updateAllLabels("Normal mode queued for next round.")
			end
			return
		end

		if isFairModeCommand(message) then
			if player.UserId == ownerUserId then
				fairModeEnabled = not fairModeEnabled
				updateAllLabels("Fairmode " .. (fairModeEnabled and "enabled." or "disabled."))
			end
			return
		end

		if isLmsForceCommand(message) then
			if player.UserId == ownerUserId then
				if not activateLmsForce() then
					updateAllLabels("LMS force failed (need at least 2 players and running game).")
				end
			end
			return
		end

		local targetMode = getTargetModeCommand(message)
		if targetMode then
			if player.UserId == ownerUserId then
				if plateModeEnabled then
					targetAliveOnly = true
					updateAllLabels("Alive mode is always enabled in platemode.")
				elseif targetMode == "alive" then
					targetAliveOnly = true
					updateAllLabels("Alive mode enabled.")
				else
					targetAliveOnly = false
					updateAllLabels("All mode enabled.")
				end
			end
			return
		end

		local forced = parseForceEventCommand(message)
		if forced then
			if player.UserId ~= ownerUserId then
				return
			end

			if forced.error then
				updateAllLabels(forced.error)
				return
			end

			forcedNextEvent = forced
			updateAllLabels("Forceevent queued: " .. forced.kind)
		end
	end)

	ensureGui(player)
	if player.Character then
		teleportPlayerToAssignedPlate(player)
		local humanoid = getHumanoid(player)
		if humanoid then
			attachAntiRegen(player, humanoid)
			if plateModeEnabled and running and not isPlayerActiveInRound(player) and not plateOutUserIds[player.UserId] then
				humanoid.Health = 0
			end
			humanoid.Died:Connect(function()
				lastEliminatedUserId = player.UserId
				handlePlayerElimination(player)
				evaluateWinCondition()
			end)
		end
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end
Players.PlayerAdded:Connect(hookPlayer)

requestAutoRoundStart = function(delaySeconds)
	if autoRoundRestartPending then
		return
	end
	autoRoundRestartPending = true
	task.delay(delaySeconds or 1, function()
		autoRoundRestartPending = false
		if running or restartScheduled then
			return
		end
		local starter = getPlayerByUserId(ownerUserId or persistentOwnerUserId) or getRandomPlayer()
		if not starter then
			triggerUsed = false
			triggerPart.CanTouch = true
			return
		end
		triggerUsed = true
		triggerPart.CanTouch = false
		if nextRoundPlateMode then
			task.spawn(runPlateModeRound, starter)
		else
			task.spawn(startEvents, starter)
		end
	end)
end

startEvents = function(toucher)
	if running then
		return
	end

	running = true
	roundStartGraceUntil = plateModeEnabled and (os.clock() + 10) or 0
	scatteredNoFallUntil = (plateModeEnabled and currentPlateGamemode == "scattered") and (os.clock() + SCATTERED_NO_FALL_DURATION) or 0
	if plateModeEnabled then
		monitorPlateFalls()
	end
	ownerUserId = toucher.UserId
	if not plateModeEnabled then
		plateParticipantsReady = false
		rebuildRoundParticipants()
	end
	roundWinEnabled = getRoundParticipantCount() >= 2
	resetAntiRegenTracking()
	persistentOwnerUserId = toucher.UserId
	eventCounter = 0
	rapidFireMode = false
	rapidFirePending = false
	twoPlayerMode = false
	lastEliminatedUserId = nil
	lmsForcedUserIds = nil
	targetAliveOnly = plateModeEnabled
	usedLifeLinkPairs = {}
	clearLifeLinks()
	resetAcidTintedParts()
	clearShadowOrbs()
	clearTsunamis()
	clearConfusions()
	clearDuelEffects()
	setRapidFireMode(false)

	if plateModeEnabled then
		if not plateParticipantsReady then
			plateParticipantsReady = true
		end
	elseif getRoundParticipantCount() == 0 then
		rebuildRoundParticipants()
	end

	evaluateWinCondition()

	while running do
		evaluateWinCondition()
		if not running then
			break
		end

		local ok, err = true, nil
		local aliveCount = #getAlivePlayers()
		if not rapidFireMode and (eventCounter >= RAPID_FIRE_EVENT_THRESHOLD or aliveCount <= 2) then
			requestRapidFireMode()
		end

		if rapidFirePending and not rapidFireMode then
			setRapidFireMode(true)
		end

		if forcedNextEvent then
			local forcedEvent = forcedNextEvent
			forcedNextEvent = nil
			ok, err = pcall(runForcedEvent, forcedEvent)
		elseif plateModeEnabled and fairModeEnabled and math.random() <= (PLATE_GLOBAL_SHIFT_CHANCE_PERCENT / 100) then
			ok, err = pcall(plateGlobalShiftEvent)
		else
			local useSpecialEvent = #specialEventFunctions > 0 and math.random(1, 100) <= SPECIAL_EVENT_CHANCE_PERCENT
			local basePool = plateModeEnabled and plateModeEventFunctions or normalEventFunctions
			local eventPool = useSpecialEvent and specialEventFunctions or basePool

			if not useSpecialEvent then
				local filtered = {}
				for _, eventFn in ipairs(eventPool) do
					if (not twoPlayerMode or eventFn ~= lifeLinkEvent) and (eventFn ~= loseLegsEvent or #getRandomDistinctPlayers(1, { excludeLegless = true }) > 0) then
						table.insert(filtered, eventFn)
					end
				end
				if #filtered > 0 then
					eventPool = filtered
				end
			end
			if #eventPool == 0 then
				updateAllLabels("No valid events available.")
				task.wait(1)
			else
				local randomEvent = eventPool[math.random(1, #eventPool)]
				ok, err = pcall(randomEvent)
			end
		end

		eventCounter = eventCounter + 1
		evaluateWinCondition()

		if not ok then
			warn("[RandomTouchEvents] Event failed:", err)
		end
		if not running then
			break
		end
		task.wait(rapidFireMode and 5 or 4)
	end
end

triggerPart.Touched:Connect(function(hit)
	local okTouch, touchErr = pcall(function()
		if triggerUsed then
			return
		end

		local character = hit and hit.Parent
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		if os.clock() < triggerArmedAt then
			return
		end

		triggerUsed = true
		triggerPart.CanTouch = false
		ownerUserId = player.UserId
		persistentOwnerUserId = player.UserId
		task.spawn(function()
			local ok, err
			if nextRoundPlateMode then
				ok, err = pcall(runPlateModeRound, player)
			else
				ok, err = pcall(startEvents, player)
			end
			if not ok then
				warn("[RandomTouchEvents] Startup failed:", err)
				running = false
				triggerUsed = false
				triggerPart.CanTouch = true
				requestAutoRoundStart(1)
			end
		end)
	end)
	if not okTouch then
		warn("[RandomTouchEvents] Touch handler failed:", touchErr)
		triggerUsed = false
		triggerPart.CanTouch = true
	end
end)

