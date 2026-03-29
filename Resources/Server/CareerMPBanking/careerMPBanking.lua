local sendLedger = {}
local receiveLedger = {}
local receiveEnabled = {}

local sessionTransactionMax = 100000
local sessionReceiveMax = 200000
local shortWindowMax = 1000 
local shortWindowSeconds = 30
local longWindowMax = 10000
local longWindowSeconds = 300

local function getOrCreate(ledger, playerId)
    if not ledger[playerId] then
        ledger[playerId] = {
            session_total = 0,
            short_transactions = {},
            long_transactions = {}
        }
    end
    return ledger[playerId]
end

local function getWindowTotal(transactions, now, windowSeconds)
    local windowTotal = 0
    local cutoff = now - windowSeconds
    local kept = {}

    for _, transaction in ipairs(transactions) do
        if transaction.timestamp > cutoff then
            table.insert(kept, transaction)
            windowTotal = windowTotal + transaction.amount
        end
    end

    for i = #transactions, 1, -1 do
        transactions[i] = nil
    end

    for _, transaction in ipairs(kept) do
        table.insert(transactions, transaction)
    end

    return windowTotal
end

local function attemptTransaction(senderId, receiverId, amount, now)
    local sender = getOrCreate(sendLedger, senderId)
    local receiver = getOrCreate(receiveLedger, receiverId)
    local shortTotal = getWindowTotal(sender.short_transactions, now, shortWindowSeconds)
    local longTotal = getWindowTotal(sender.long_transactions, now, longWindowSeconds)

    if sender.session_total + amount > sessionTransactionMax then
        return false
    end

    if shortTotal > 0 and shortTotal + amount > shortWindowMax then
        return false
    end

    if longTotal > 0 and longTotal + amount > longWindowMax then
        return false
    end

    if receiver.session_total + amount > sessionReceiveMax then
        return false
    end

    sender.session_total = sender.session_total + amount
    receiver.session_total = receiver.session_total + amount

    if amount <= shortWindowMax then
        table.insert(sender.short_transactions, { amount = amount, timestamp = now })
    end

    if amount <= longWindowMax then
        table.insert(sender.long_transactions, { amount = amount, timestamp = now })
    end

    return true
end

local function buildPaymentData(playerId, paymentData)
    local targetPlayerName = nil
    if paymentData.target_player_id then
        targetPlayerName = MP.GetPlayerName(paymentData.target_player_id)
    end

    paymentData.sender = MP.GetPlayerName(playerId)
    paymentData.target_player_name = targetPlayerName or paymentData.target_player_name or "Unknown"
    paymentData.tags = paymentData.tags or { "gameplay" }
    paymentData.label = paymentData.label or ("Paid player: " .. paymentData.target_player_name)
    return paymentData
end

function onInit()
    MP.RegisterEvent("careerMPBankingPayPlayer", "careerMPBankingPayPlayer")
    MP.RegisterEvent("careerMPBankingSetReceiveEnabled", "careerMPBankingSetReceiveEnabled")

    MP.RegisterEvent("onPlayerJoin", "onPlayerJoinHandler")
    MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnectHandler")

    print("[CareerMPBanking] ---------- CareerMP Banking Loaded!")
end

function careerMPBankingSetReceiveEnabled(playerId, data)
    local decoded = Util.JsonDecode(data) or {}
    receiveEnabled[playerId] = decoded.enabled ~= false
end

function careerMPBankingPayPlayer(playerId, data)
    local paymentData = Util.JsonDecode(data) or {}
    paymentData.target_player_id = tonumber(paymentData.target_player_id)
    paymentData.money = math.floor(math.abs(tonumber(paymentData.money) or 0))
    paymentData = buildPaymentData(playerId, paymentData)

    if paymentData.money <= 0 or not paymentData.target_player_id or paymentData.target_player_id == playerId then
        paymentData.reason = "invalid"
        MP.TriggerClientEventJson(playerId, "careerMPBankingRxBounce", paymentData)
        return
    end

    if not MP.IsPlayerConnected(paymentData.target_player_id) then
        paymentData.reason = "offline"
        MP.TriggerClientEventJson(playerId, "careerMPBankingRxBounce", paymentData)
        return
    end

    if receiveEnabled[paymentData.target_player_id] == false then
        paymentData.reason = "optout"
        MP.TriggerClientEventJson(playerId, "careerMPBankingRxOptOut", paymentData)
        return
    end

    if attemptTransaction(playerId, paymentData.target_player_id, paymentData.money, os.time()) then
        MP.TriggerClientEventJson(paymentData.target_player_id, "careerMPBankingRxPayment", paymentData)
        MP.TriggerClientEventJson(playerId, "careerMPBankingRxConfirmation", paymentData)
    else
        paymentData.reason = "ratelimited"
        MP.TriggerClientEventJson(playerId, "careerMPBankingRxBounce", paymentData)
    end
end

function onPlayerJoinHandler(playerId)
    receiveEnabled[playerId] = true
end

function onPlayerDisconnectHandler(playerId)
    receiveEnabled[playerId] = nil
    sendLedger[playerId] = nil
    receiveLedger[playerId] = nil
end
