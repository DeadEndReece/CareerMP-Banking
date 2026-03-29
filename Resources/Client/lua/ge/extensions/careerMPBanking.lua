local M = {}

local paymentAllowed = false
local paymentTimer = 0
local paymentTimerThreshold = 2.125
local paymentID = 1

local receiveEnabled = true
local receivePreferenceSent = false
local paymentPatchApplied = false
local layoutRefreshRequested = false
local lastKnownNickname = ""

local defaultAppLayoutDirectory = "settings/ui_apps/originalLayouts/default/"
local missionAppLayoutDirectory = "settings/ui_apps/originalLayouts/mission/"
local userDefaultAppLayoutDirectory = "settings/ui_apps/layouts/default/"
local userMissionAppLayoutDirectory = "settings/ui_apps/layouts/mission/"

local defaultLayouts = {
	busRouteScenario = { filename = "busRouteScenario" },
	busStuntMinSpeed = { filename = "busStuntMinSpeed" },
	career = { filename = "career" },
	careerBigMap = { filename = "careerBigMap" },
	careerMission = { filename = "careerMission" },
	careerMissionEnd = { filename = "careerMissionEnd" },
	careerPause = { filename = "careerPause" },
	careerRefuel = { filename = "careerRefuel" },
	collectionEvent = { filename = "collectionEvent" },
	crawl = { filename = "crawl" },
	damageScenario = { filename = "damageScenario" },
	dderbyScenario = { filename = "dderbyScenario" },
	discover = { filename = "discover" },
	driftScenario = { filename = "driftScenario" },
	exploration = { filename = "exploration" },
	externalui = { filename = "externalUI" },
	freeroam = { filename = "freeroam" },
	garage = { filename = "garage" },
	garage_v2 = { filename = "garage_v2" },
	multiseatscenario = { filename = "multiseatscenario" },
	noncompeteScenario = { filename = "noncompeteScenario" },
	offroadScenario = { filename = "offroadScenario" },
	proceduralScenario = { filename = "proceduralScenario" },
	quickraceScenario = { filename = "quickraceScenario" },
	radial = { filename = "radial" },
	scenario = { filename = "scenario" },
	scenario_cinematic_start = { filename = "scenario_cinematic_start" },
	singleCheckpointScenario = { filename = "singleCheckpointScenario" },
	tasklist = { filename = "tasklist" },
	tasklistTall = { filename = "tasklistTall" },
	unicycle = { filename = "unicycle" }
}

local missionLayouts = {
	aRunForLifeMission = { filename = "aRunForLife" },
	basicMissionLayout = { filename = "basicMission" },
	crashTestMission = { filename = "crashTestMission" },
	crawlMission = { filename = "crawlMission" },
	dragMission = { filename = "dragMission" },
	driftMission = { filename = "driftMission" },
	driftNavigationMission = { filename = "driftNavigationMission" },
	evadeMission = { filename = "evadeMission" },
	garageToGarageMission = { filename = "garageToGarage" },
	rallyModeLoop = { filename = "rallyModeLoop" },
	rallyModeLoopStage = { filename = "rallyModeLoopStage" },
	rallyModeRecce = { filename = "rallyModeRecce" },
	rallyModeStage = { filename = "rallyModeStage" },
	scenarioMission = { filename = "scenarioMission" },
	timeTrialMission = { filename = "timeTrialMission" }
}

local defaultBankingApp = {
	appName = "careermpbanking",
	placement = {
		bottom = "",
		height = "550px",
		left = "0px",
		position = "absolute",
		right = "",
		top = "260px",
		width = "448px"
	}
}

local legacyDefaultBankingPlacements = {
	{
		bottom = "",
		height = "560px",
		left = "",
		position = "absolute",
		right = "0px",
		top = "240px",
		width = "auto"
	},
	{
		bottom = "",
		height = "550px",
		left = "",
		position = "absolute",
		right = "0px",
		top = "450px",
		width = "auto"
	},
	{
		bottom = "",
		height = "550px",
		left = "",
		position = "absolute",
		right = "0px",
		top = "500px",
		width = "auto"
	},
	{
		bottom = "",
		height = "550px",
		left = "",
		position = "absolute",
		right = "0px",
		top = "500px",
		width = "448px"
	}
}

local function toast(messageType, title, msg, timeout)
	guihooks.trigger('toastrMsg', {
		type = messageType,
		title = title,
		msg = msg,
		config = { timeOut = timeout or 2500 }
	})
end

local function getNickname()
	if MPConfig and MPConfig.getNickname then
		local nickname = MPConfig.getNickname()
		if nickname and nickname ~= "" then
			lastKnownNickname = nickname
		end
	end

	return lastKnownNickname
end

local function getMoneyBalance()
	if career_modules_playerAttributes and career_modules_playerAttributes.getAttribute then
		local moneyAttribute = career_modules_playerAttributes.getAttribute("money")
		if moneyAttribute and moneyAttribute.value then
			return moneyAttribute.value
		end
	end

	return 0
end

local function buildPlayersList()
	local playersList = {}
	if not MPVehicleGE or not MPVehicleGE.getPlayers then
		return playersList
	end

	local nickname = getNickname()
	for _, playerData in pairs(MPVehicleGE.getPlayers() or {}) do
		local playerId = playerData.playerID or playerData.id
		table.insert(playersList, {
			id = playerId,
			name = playerData.name,
			formatted_name = playerData.formatted_name or playerData.formattedName or playerData.name or ("Player " .. tostring(playerId)),
			isSelf = playerData.name == nickname
		})
	end

	table.sort(playersList, function(a, b)
		return tonumber(a.id or 0) < tonumber(b.id or 0)
	end)

	return playersList
end

local function loadReceiveEnabledSetting()
	local stored = settings.getValue("careerMPBankingReceiveEnabled")
	if stored == nil then
		receiveEnabled = true
		settings.setValue("careerMPBankingReceiveEnabled", receiveEnabled)
		return
	end

	receiveEnabled = stored ~= false
end

local function sendReceivePreference()
	if worldReadyState == 2 and TriggerServerEvent then
		TriggerServerEvent("careerMPBankingSetReceiveEnabled", jsonEncode({ enabled = receiveEnabled }))
		receivePreferenceSent = true
	end
end

local function buildUiState()
	return {
		balance = getMoneyBalance(),
		players = buildPlayersList(),
		receiveEnabled = receiveEnabled,
		paymentAllowed = paymentAllowed,
		nickname = getNickname()
	}
end

local function getUiState()
	return jsonEncode(buildUiState())
end

local function normalizeBool(value)
	if type(value) == "boolean" then
		return value
	end

	if type(value) == "number" then
		return value ~= 0
	end

	if type(value) == "string" then
		value = value:lower()
		return value == "true" or value == "1" or value == "yes" or value == "on"
	end

	return not not value
end

local function setReceiveEnabled(enabled)
	receiveEnabled = normalizeBool(enabled)
	settings.setValue("careerMPBankingReceiveEnabled", receiveEnabled)
	receivePreferenceSent = false
	sendReceivePreference()
	return receiveEnabled
end

local function findPlayerByName(playerName)
	for _, playerData in ipairs(buildPlayersList()) do
		if playerData.name == playerName then
			return playerData
		end
	end
end

local function payPlayer(playerName, amount)
	amount = math.floor(math.abs(tonumber(amount) or 0))

	if not paymentAllowed then
		toast("warning", "Transaction cooling down", "Please wait a moment before sending another payment.", 2000)
		return
	end

	if amount <= 0 then
		toast("error", "Invalid transaction!", "Please enter a valid amount to send.", 2200)
		return
	end

	if not playerName or playerName == "" then
		toast("error", "Invalid transaction!", "That player could not be found.", 2200)
		return
	end

	local nickname = getNickname()
	if playerName == nickname then
		toast("error", "Invalid transaction!", "You cannot pay yourself!", 2200)
		return
	end

	local selfMoney = getMoneyBalance()
	if selfMoney < amount then
		toast("error", "Invalid transaction!", "You do not have enough money to pay " .. playerName .. "!", 2200)
		return
	end

	local playerData = findPlayerByName(playerName)
	if not playerData or not playerData.id then
		toast("error", "Invalid transaction!", playerName .. " is no longer online.", 2200)
		return
	end

	paymentTimer = 0
	paymentAllowed = false

	TriggerServerEvent("careerMPBankingPayPlayer", jsonEncode({
		money = amount,
		tags = { "gameplay" },
		label = "Paid player: " .. playerData.name,
		target_player_id = playerData.id,
		target_player_name = playerData.name
	}))
end

local function rxPayment(data)
	local paymentData = jsonDecode(data or "{}")
	local amount = tonumber(paymentData.money) or 0

	if career_modules_playerAttributes and career_modules_playerAttributes.addAttributes then
		career_modules_playerAttributes.addAttributes(
			{ money = amount },
			{ tags = paymentData.tags or { "gameplay" }, label = "Payment from player: " .. (paymentData.sender or "Unknown") }
		)
	end

	if career_saveSystem and career_saveSystem.saveCurrent then
		career_saveSystem.saveCurrent()
	end

	toast("info", "Transaction #" .. paymentID, (paymentData.sender or "Unknown") .. " paid you $" .. amount, 2600)
	paymentID = paymentID + 1
end

local function rxConfirmation(data)
	local paymentData = jsonDecode(data or "{}")
	local amount = tonumber(paymentData.money) or 0

	if career_modules_playerAttributes and career_modules_playerAttributes.addAttributes then
		career_modules_playerAttributes.addAttributes(
			{ money = -amount },
			{ tags = paymentData.tags or { "gameplay" }, label = paymentData.label or ("Paid player: " .. (paymentData.target_player_name or "Unknown")) }
		)
	end

	if career_saveSystem and career_saveSystem.saveCurrent then
		career_saveSystem.saveCurrent()
	end

	toast("info", "Transaction #" .. paymentID, "You paid " .. (paymentData.target_player_name or "Unknown") .. " $" .. amount, 2600)
	paymentID = paymentID + 1
end

local function rxBounce(data)
	local paymentData = jsonDecode(data or "{}")
	local amount = tonumber(paymentData.money) or 0
	local targetPlayerName = paymentData.target_player_name or "that player"
	local reason = paymentData.reason or "unknown"
	local msg = "Your payment of $" .. amount .. " to " .. targetPlayerName .. " was returned."

	if reason == "offline" then
		msg = targetPlayerName .. " is no longer online. Your payment of $" .. amount .. " was not sent."
	elseif reason == "ratelimited" then
		msg = "You are being ratelimited. Your payment of $" .. amount .. " to " .. targetPlayerName .. " was returned."
	elseif reason == "invalid" then
		msg = "The payment request was not valid, so nothing was sent."
	end

	toast("error", "Payment returned!", msg, 2600)
end

local function rxOptOut(data)
	local paymentData = jsonDecode(data or "{}")
	local amount = tonumber(paymentData.money) or 0
	local targetPlayerName = paymentData.target_player_name or "That player"
	local msg = targetPlayerName .. " has incoming payments disabled. Your payment of $" .. amount .. " was not sent."
	toast("error", "Payments disabled!", msg, 2600)
end

local function patchCareerMPPaymentFunction()
	local patchedThisPass = false

	if careerMPEnabler and careerMPEnabler.payPlayer ~= payPlayer then
		careerMPEnabler.payPlayer = payPlayer
		patchedThisPass = true
	end

	if extensions and extensions.careerMPEnabler and extensions.careerMPEnabler.payPlayer ~= payPlayer then
		extensions.careerMPEnabler.payPlayer = payPlayer
		patchedThisPass = true
	end

	if patchedThisPass then
		paymentPatchApplied = true
	end

	return paymentPatchApplied
end

local function placementsMatch(leftPlacement, rightPlacement)
	return jsonEncode(leftPlacement or {}) == jsonEncode(rightPlacement or {})
end

local function isLegacyDefaultPlacement(placement)
	for _, legacyPlacement in ipairs(legacyDefaultBankingPlacements) do
		if placementsMatch(placement, legacyPlacement) then
			return true
		end
	end

	return false
end

local function parsePlacementPixels(value)
	if type(value) == "number" then
		return value
	end

	if type(value) ~= "string" then
		return nil
	end

	return tonumber(value:match("^%s*(-?[%d%.]+)"))
end

local function normalizeBankingPlacement(placement)
	local normalizedPlacement = deepcopy(placement or {})
	local width = parsePlacementPixels(normalizedPlacement.width)
	local height = parsePlacementPixels(normalizedPlacement.height)

	-- Preserve real user resizes, but repair missing/legacy/collapsed tab-sized values.
	if not width or width < 200 then
		normalizedPlacement.width = defaultBankingApp.placement.width
	end

	if not height or height < 120 then
		normalizedPlacement.height = defaultBankingApp.placement.height
	end

	normalizedPlacement.position = normalizedPlacement.position or defaultBankingApp.placement.position
	return normalizedPlacement
end

local function ensureApp(layout, appData)
	layout.apps = layout.apps or {}

	local firstIndex = nil
	local removed = false
	for i = #layout.apps, 1, -1 do
		local app = layout.apps[i]
		if app.appName == appData.appName then
			if not firstIndex then
				firstIndex = i
			else
				table.remove(layout.apps, i)
				removed = true
			end
		end
	end

	if not firstIndex then
		table.insert(layout.apps, deepcopy(appData))
		return true
	end

	local existingApp = layout.apps[firstIndex]
	local shouldUpdatePlacement = not existingApp.placement or isLegacyDefaultPlacement(existingApp.placement)
	local desiredPlacement = shouldUpdatePlacement and deepcopy(appData.placement) or normalizeBankingPlacement(existingApp.placement)
	if not placementsMatch(existingApp.placement, desiredPlacement) then
		layout.apps[firstIndex].placement = desiredPlacement
		return true
	end

	return removed
end

local function loadLayout(customDir, defaultDir, filename)
	local custom = jsonReadFile(customDir .. filename .. ".uilayout.json")
	if custom then
		return deepcopy(custom), customDir
	end

	local default = jsonReadFile(defaultDir .. filename .. ".uilayout.json")
	if default then
		return deepcopy(default), customDir
	end
end

local function getBankingAppData()
	local mpLayout = jsonReadFile(userDefaultAppLayoutDirectory .. "careermp.uilayout.json")
	if mpLayout and mpLayout.apps then
		for _, appData in ipairs(mpLayout.apps) do
			if appData.appName == defaultBankingApp.appName then
				if appData.placement and not isLegacyDefaultPlacement(appData.placement) then
					local customAppData = deepcopy(appData)
					customAppData.placement = normalizeBankingPlacement(customAppData.placement)
					return customAppData
				end
				break
			end
		end
	end

	return defaultBankingApp
end

local function checkUIApps(state)
	if not state or not state.appLayout then
		return
	end

	local layoutInfo = defaultLayouts[state.appLayout] or missionLayouts[state.appLayout]
	if not layoutInfo then
		return
	end

	local customDir = defaultLayouts[state.appLayout] and userDefaultAppLayoutDirectory or userMissionAppLayoutDirectory
	local defaultDir = defaultLayouts[state.appLayout] and defaultAppLayoutDirectory or missionAppLayoutDirectory
	local layout, saveDir = loadLayout(customDir, defaultDir, layoutInfo.filename)
	if not layout then
		return
	end

	if ensureApp(layout, getBankingAppData()) then
		jsonWriteFile(saveDir .. layoutInfo.filename .. ".uilayout.json", layout, 1)
		layoutRefreshRequested = true
	end
end

local function onGameStateUpdate(state)
	checkUIApps(state)
end

local function onWorldReadyState(state)
	if state == 2 then
		getNickname()
		paymentAllowed = true
		paymentTimer = paymentTimerThreshold + 0.1
		if not receivePreferenceSent then
			sendReceivePreference()
		end
	end
end

local function onUpdate(dtReal, dtSim, dtRaw)
	paymentTimer = paymentTimer + dtReal
	if paymentTimer > paymentTimerThreshold then
		paymentAllowed = true
	end

	if not paymentPatchApplied then
		patchCareerMPPaymentFunction()
	end

	if not receivePreferenceSent and worldReadyState == 2 then
		sendReceivePreference()
	end

	if layoutRefreshRequested and ui_apps and ui_apps.requestUIAppsData then
		ui_apps.requestUIAppsData()
		layoutRefreshRequested = false
	end
end

local function onExtensionLoaded()
	loadReceiveEnabledSetting()

	AddEventHandler("careerMPBankingRxPayment", rxPayment)
	AddEventHandler("careerMPBankingRxConfirmation", rxConfirmation)
	AddEventHandler("careerMPBankingRxBounce", rxBounce)
	AddEventHandler("careerMPBankingRxOptOut", rxOptOut)

	patchCareerMPPaymentFunction()
	log('W', 'careerMPBanking', 'CareerMP Banking LOADED!')
end

local function onExtensionUnloaded()
	log('W', 'careerMPBanking', 'CareerMP Banking UNLOADED!')
end

M.getUiState = getUiState
M.setReceiveEnabled = setReceiveEnabled
M.payPlayer = payPlayer

M.onGameStateUpdate = onGameStateUpdate
M.onWorldReadyState = onWorldReadyState
M.onUpdate = onUpdate

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

M.onInit = function()
	setExtensionUnloadMode(M, 'manual')
end

return M
