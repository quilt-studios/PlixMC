-- PlixCore is deliberately self-contained so a default PlixMC installation has
-- useful gameplay features without requiring a collection of third-party plugins.

local Players = {}
local Plots = {}
local Config = { ServerName = "PlixMC", Scoreboard = "[Money] | [Rank] | [deaths]" }
local ConsoleHistory = {}
local CrateRewards = {
	{ Name = "Diamonds", Item = 264, Amount = 3 },
	{ Name = "Iron", Item = 265, Amount = 12 },
	{ Name = "Golden apples", Item = 322, Amount = 2 },
}

local function Escape(a_Text)
	return tostring(a_Text or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&#39;")
end

local function Data(a_Player)
	local Name = a_Player:GetName()
	if (Players[Name] == nil) then
		Players[Name] = { Money = 100, Deaths = 0, Crates = 1 }
	end
	return Players[Name]
end

local function Rank(a_Player)
	return cRoot:Get():GetRankManager():GetPlayerRankName(a_Player:GetUUID()) or "Default"
end

local function ScoreText(a_Player)
	local DataForPlayer = Data(a_Player)
	return Config.Scoreboard:gsub("%[Money%]", tostring(DataForPlayer.Money)):gsub("%[Rank%]", Rank(a_Player)):gsub("%[deaths%]", tostring(DataForPlayer.Deaths))
end

local function PlotKey(a_Player)
	return a_Player:GetWorld():GetName() .. ":" .. math.floor(a_Player:GetPosX() / 16) .. ":" .. math.floor(a_Player:GetPosZ() / 16)
end

function HandleBalance(a_Split, a_Player)
	if (a_Player == nil) then return true end
	a_Player:SendMessageInfo("Balance: " .. Data(a_Player).Money .. " coins")
	return true
end

function HandlePay(a_Split, a_Player)
	if ((a_Player == nil) or (a_Split[2] == nil) or (tonumber(a_Split[3]) == nil)) then
		if (a_Player ~= nil) then a_Player:SendMessageFailure("Usage: /pay <player> <amount>") end
		return true
	end
	local Amount = math.floor(tonumber(a_Split[3]))
	if (Amount <= 0 or Data(a_Player).Money < Amount) then a_Player:SendMessageFailure("Insufficient funds."); return true end
	local Found = false
	cRoot:Get():ForEachPlayer(function(a_Target)
		if (string.lower(a_Target:GetName()) == string.lower(a_Split[2])) then
			Data(a_Player).Money = Data(a_Player).Money - Amount
			Data(a_Target).Money = Data(a_Target).Money + Amount
			a_Player:SendMessageSuccess("Paid " .. Amount .. " coins to " .. a_Target:GetName() .. ".")
			a_Target:SendMessageSuccess("You received " .. Amount .. " coins from " .. a_Player:GetName() .. ".")
			Found = true
		end
	end)
	if (not Found) then a_Player:SendMessageFailure("That player is not online.") end
	return true
end

function HandleCrate(a_Split, a_Player)
	if (a_Player == nil) then return true end
	local PlayerData = Data(a_Player)
	if (PlayerData.Crates < 1) then a_Player:SendMessageFailure("You do not have a crate key."); return true end
	local Reward = CrateRewards[math.random(#CrateRewards)]
	PlayerData.Crates = PlayerData.Crates - 1
	a_Player:GetInventory():AddItem(cItem(Reward.Item, Reward.Amount))
	a_Player:SendMessageSuccess("Crate opened: " .. Reward.Amount .. " " .. Reward.Name .. "!")
	return true
end

function HandlePlot(a_Split, a_Player)
	if (a_Player == nil) then return true end
	local Key = PlotKey(a_Player)
	if (a_Split[2] == "claim") then
		if (Plots[Key] ~= nil) then a_Player:SendMessageFailure("This plot is already owned by " .. Plots[Key] .. ".") else Plots[Key] = a_Player:GetName(); a_Player:SendMessageSuccess("Claimed this 16x16 plot.") end
	else
		a_Player:SendMessageInfo("Plot owner: " .. (Plots[Key] or "unclaimed") .. ". Use /plot claim to claim it.")
	end
	return true
end

function HandleServerNameSet(a_Split, a_Player)
	if ((a_Player == nil) or (a_Split[2] == nil)) then
		if (a_Player ~= nil) then a_Player:SendMessageFailure("Usage: /servernameset <name>") end
		return true
	end
	Config.ServerName = table.concat(a_Split, " ", 2)
	cRoot:Get():BroadcastChatSuccess("Server name set to " .. Config.ServerName)
	return true
end

function OnPlayerJoined(a_Player)
	Data(a_Player)
	a_Player:SendMessageSuccess("Welcome to " .. Config.ServerName .. "! " .. ScoreText(a_Player))
end

function OnKilled(a_Victim, a_TDI, a_DeathMessage)
	if (a_Victim:IsPlayer()) then Data(tolua.cast(a_Victim, "cPlayer")).Deaths = Data(tolua.cast(a_Victim, "cPlayer")).Deaths + 1 end
	return false
end

function OnPlayerMoving(a_Player, a_OldPosition, a_NewPosition, a_PreviousIsOnGround)
	-- Reject implausible horizontal movement unless the player is flying. This is a
	-- conservative check intended to catch packet speed hacks without false positives.
	local DeltaX, DeltaZ = a_NewPosition.x - a_OldPosition.x, a_NewPosition.z - a_OldPosition.z
	if ((DeltaX * DeltaX + DeltaZ * DeltaZ) > 144 and not a_Player:IsGameModeCreative()) then
		a_Player:SendMessageFailure("Movement rejected by PlixGuard.")
		return true
	end
	return false
end

function HandleDashboardRequest(a_Request)
	local Notice = ""
	if (a_Request.PostParams["scoreboard"] ~= nil) then Config.Scoreboard = a_Request.PostParams["scoreboard"]; Notice = "Scoreboard template saved." end
	if (a_Request.PostParams["serverName"] ~= nil) then Config.ServerName = a_Request.PostParams["serverName"]; Notice = "Server name saved." end
	if (a_Request.PostParams["command"] ~= nil and a_Request.PostParams["command"] ~= "") then
		local Command = a_Request.PostParams["command"]
		local Ok, Output = cPluginManager:Get():ExecuteConsoleCommand(Command)
		table.insert(ConsoleHistory, 1, "$ " .. Command .. "\n" .. (Output or (Ok and "Command queued." or "Command failed.")))
		while (#ConsoleHistory > 12) do table.remove(ConsoleHistory) end
		Notice = "Console command processed."
	end
	local Online = {}
	cRoot:Get():ForEachPlayer(function(a_Player) table.insert(Online, "<li><strong>" .. Escape(a_Player:GetName()) .. "</strong><span>" .. Escape(ScoreText(a_Player)) .. "</span></li>") end)
	if (#Online == 0) then table.insert(Online, "<li class='empty'>No players are currently online.</li>") end
	return [[<div class="plix-dashboard"><p class="notice">]] .. Escape(Notice) .. [[</p><section class="metric-grid"><article><span>Online players</span><strong>]] .. cRoot:Get():GetServer():GetNumPlayers() .. [[</strong></article><article><span>Loaded chunks</span><strong>]] .. cRoot:Get():GetTotalChunkCount() .. [[</strong></article><article><span>Memory</span><strong>]] .. string.format("%.1f MB", cRoot:GetPhysicalRAMUsage() / 1024) .. [[</strong></article></section><section class="dashboard-grid"><article class="card"><h2>Online players</h2><ul class="player-list">]] .. table.concat(Online) .. [[</ul></article><article class="card"><h2>Server settings</h2><form method="POST"><label>Server name<input name="serverName" value="]] .. Escape(Config.ServerName) .. [["></label><label>Scoreboard template <small>[Money], [Rank], [deaths]</small><input name="scoreboard" value="]] .. Escape(Config.Scoreboard) .. [["></label><button type="submit">Save dashboard settings</button></form></article><article class="card console"><h2>Console</h2><form method="POST"><input name="command" placeholder="say Hello from PlixMC" autocomplete="off"><button type="submit">Run command</button></form><pre>]] .. Escape(table.concat(ConsoleHistory, "\n\n")) .. [[</pre></article></section></div>]], "text/html"
end

function Initialize(a_Plugin)
	a_Plugin:SetName("PlixCore")
	a_Plugin:SetVersion(1)
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_JOINED, OnPlayerJoined)
	cPluginManager:AddHook(cPluginManager.HOOK_KILLED, OnKilled)
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_MOVING, OnPlayerMoving)
	a_Plugin:AddWebTab("Dashboard", HandleDashboardRequest, "dashboard")
	RegisterPluginInfoCommands()
	LOGINFO("PlixCore loaded: plots, economy, crates, PlixGuard and dashboard scoreboard.")
	return true
end
