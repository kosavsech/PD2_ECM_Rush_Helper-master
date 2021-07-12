_G.ecm_rush_helper = _G.ecm_rush_helper or {}
ecm_rush_helper._path = ModPath
ecm_rush_helper.data_path = SavePath .. 'ecm_rush_helper.txt'
ecm_rush_helper.settings = {
	reciever = 3, -- general menu
	message = 'seconds left', -- general menu
	full_end = "Last device", -- general menu
	ecm_toggle = true,-- ecm menu
	low_time = 5, -- ecm menu
	prefix = 'ECM', -- ecm menu
	ECM_queue_message = "'s ECM next", -- ecm menu
	ecm_placed_toggle = true,-- ecm menu
	ecm_placed = "placed by", -- ecm menu
	pecm_toggle = true,-- pecm menu
	plow_time = 2, -- pecm menu
	pprefix = 'Pocket ECM', -- pecm menu
	pECM_queue_message = "'s pECM next", -- pecm menu
	pECMs_amount_req = 1, -- pecm menu
	pECMs_players_req = 3, -- pecm menu
	pECM_collected = "Round next", -- pecm menu
	pecm_used_toggle = true,-- ecm menu
	pecm_used = "used by", -- pecm menu
}
ecm_rush_helper.peer_database = {
	{"", "", "", ""}, -- ecm each peer
	{"", "", "", ""}, -- ecm amount each peer
	{"", "", "", ""}, -- p ecm each peer
	{"", "", "", ""} -- p ecm amount each peer
}
ecm_rush_helper.modded_peers = {
	{nil, nil, nil, nil}, -- is modded
	{nil, nil, nil, nil} -- config
}
ecm_rush_helper.data = {
	next_pocket_peer = nil,
	next_ecm_peer = nil
}

function ecm_rush_helper:DebugEnabled()
	return false
end
--[[ if ecm_rush_helper:DebugEnabled() then
	log( "DEBUG  " ..  )
end ]]
function ecm_rush_helper:build_recievers()
	local main_peer_id
	if ecm_rush_helper.main_peer then
		main_peer_id = ecm_rush_helper.main_peer._id
		if ecm_rush_helper:DebugEnabled() then
			log("DEBUG main_peer._id " .. ecm_rush_helper.main_peer._id)
		end
	else
		ecm_rush_helper.main_peer = managers.network:session():local_peer()
		main_peer_id = ecm_rush_helper.main_peer._id
		if ecm_rush_helper:DebugEnabled() then
			log("DEBUG main_peer._id " .. ecm_rush_helper.main_peer._id)
		end
	end
	ecm_rush_helper.recievers = {}
	if managers.network:session():local_peer() == ecm_rush_helper.main_peer then -- we work bcuz we are main peer
		for i, peer in pairs(managers.network:session():all_peers()) do
			if not ecm_rush_helper.modded_peers[1][peer._id] and ecm_rush_helper.modded_peers[1][peer._id] ~= peer then 
				table.insert(ecm_rush_helper.recievers, peer)
				if ecm_rush_helper:DebugEnabled() then
					for i, peer in pairs(ecm_rush_helper.recievers) do
						log("DEBUG build_recievers recievers " .. i .. " " .. peer._name .. " id " .. peer._id)
					end
				end
			elseif ecm_rush_helper.modded_peers[peer._id] then
				-- nothing bcuz player is modded
				if ecm_rush_helper:DebugEnabled() then
					log("DEBUG build_recievers restricted " .. tostring(ecm_rush_helper.modded_peers[peer._id]) .. " " .. peer._name .. " id " .. peer._id)
				end
			end
		end
	elseif managers.network:session():peer(main_peer_id) == ecm_rush_helper.main_peer then
		-- nothing bcuz another player will send all info, only recieve for self
	elseif managers.network:session():peer(main_peer_id) ~= ecm_rush_helper.main_peer then
		LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "config" .. ecm_rush_helper.settings.reciever)
		LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "main_peer_is_dead")
	end
end

function ecm_rush_helper:has_ecm(peerid)
	if ecm_rush_helper.peer_database[1][peerid] == "ecm_jammer" and ecm_rush_helper.peer_database[2][peerid] ~= 0 and managers.network:session():peer(peerid):unit():base():upgrade_value("ecm_jammer", "affects_pagers") then
		return true
	end
	return false
end

function ecm_rush_helper:has_pockets(peerid)
	if ecm_rush_helper.peer_database[3][peerid] == "pocket_ecm_jammer" and ecm_rush_helper.peer_database[4][peerid] ~= 0 then
		return true
	end
	return false
end

function ecm_rush_helper:get_next_after(peer_id, device)
	local function has_device(peer_id)
		return device == "pocket" and ecm_rush_helper:has_pockets(peer_id) or ecm_rush_helper:has_ecm(peer_id)
	end

	for i, peer in pairs(managers.network:session():all_peers()) do
		if peer_id < peer._id and has_device(peer._id) then
			if ecm_rush_helper:DebugEnabled() then
				log("DEBUG get_next_after " ..  peer_id .. " < is ".. peer._id)
			end
			return peer
		end
	end
	for i, peer in pairs(managers.network:session():all_peers()) do
		if peer_id > peer._id and has_device(peer._id) then
			if ecm_rush_helper:DebugEnabled() then
				log("DEBUG get_next_after " ..  peer_id .. " > is ".. peer._id)
			end
			return peer
		end
	end
	for i, peer in pairs(managers.network:session():all_peers()) do
		if peer_id == peer._id and has_device(peer._id) then
			if ecm_rush_helper:DebugEnabled() then
				log("DEBUG get_next_after " ..  peer_id .. " == is ".. peer._id)
			end
			return peer
		end
	end
end

function ecm_rush_helper:got_enough_pockets()
	local players_with_pecm = 0 
	for peer_id, grenade in pairs(ecm_rush_helper.peer_database[3]) do
		if grenade == "pocket_ecm_jammer" and ecm_rush_helper.peer_database[4][peer_id] >= ecm_rush_helper.settings.pECMs_amount_req then
			players_with_pecm = players_with_pecm + 1
		end
	end
	if players_with_pecm >= ecm_rush_helper.settings.pECMs_players_req then
		return true
	end
	return false
end

function ecm_rush_helper:start_pECM_round_after_ECM(peer)
	if erh_pecm.data.msg_done ~= 1 then
		if ecm_rush_helper.settings.reciever == 1 then
			ecm_rush_helper:build_recievers()
			managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.prefix .. ': ' .. ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message)
			managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.pprefix .. ': ' .. ecm_rush_helper.settings.pECM_collected)
			for _, reciever in pairs(ecm_rush_helper.recievers) do
				managers.chat:send_message(1, reciever, ecm_rush_helper.settings.prefix .. ': ' .. ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message)
				managers.chat:send_message(1, reciever, ecm_rush_helper.settings.pprefix .. ': ' .. ecm_rush_helper.settings.pECM_collected)
			end
		elseif ecm_rush_helper.settings.reciever == 2 then
			managers.chat:send_message(1, peer, ecm_rush_helper.settings.prefix .. ': ' .. ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message)
			managers.chat:send_message(1, peer, ecm_rush_helper.settings.pprefix .. ': ' .. ecm_rush_helper.settings.pECM_collected)
		elseif ecm_rush_helper.settings.reciever == 3 then
			managers.chat:_receive_message(1, ecm_rush_helper.settings.prefix, ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message, tweak_data.chat_colors[peer._id])
			managers.chat:_receive_message(1, ecm_rush_helper.settings.pprefix, ecm_rush_helper.settings.pECM_collected, tweak_data.chat_colors[peer._id])
		end
		erh_pecm.data.msg_done = 1
	end
end

function ecm_rush_helper:load()
	local file = io.open(self.data_path,"r")
	if file then
		for k, v in pairs(json.decode(file:read('*all')) or {}) do
			self.settings[k] = v
		end
		file:close()
	end
end

function ecm_rush_helper:save()
	local file = io.open(self.data_path,"w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end


Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_ecm_rush_helper", function( loc )
	if file.DirectoryExists(ecm_rush_helper._path .. "loc/") then
		for _, filename in pairs(file.GetFiles(ecm_rush_helper._path .. "loc/")) do
			local str = filename:match('^(.*).json$')
			if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
				loc:load_localization_file(ecm_rush_helper._path .. "loc/" .. filename)
				break
			end
		end
	end
	loc:load_localization_file(ecm_rush_helper._path .. "loc/english.json", false)
end)

Hooks:Add( "MenuManagerInitialize", "MenuManagerInitialize_ecm_rush_helper", function( menu_manager )
	MenuCallbackHandler.ERHChangedFocus = function(self, focus)
		if not focus then
			ecm_rush_helper:save()
		end
	end
--*							Main menu
	MenuCallbackHandler.callback_Helper_Mode = function(self, item)
		ecm_rush_helper.settings.reciever = item:value()
	end

	MenuCallbackHandler.callback_message_input = function(self, item)
		ecm_rush_helper.settings.message = item:value()
	end

	MenuCallbackHandler.callback_last_device_input = function(self, item)
		ecm_rush_helper.settings.full_end = item:value()
	end

--*							ECM menu
	MenuCallbackHandler.erh_ecm_switcher_callback = function(self, item)
		ecm_rush_helper.settings.ecm_toggle = Utils:ToggleItemToBoolean(item)
	end

	MenuCallbackHandler.callback_prefix_input = function(self, item)
		ecm_rush_helper.settings.prefix = item:value()
	end

	MenuCallbackHandler.callback_ecm_low_time = function(self, item)
		ecm_rush_helper.settings.low_time = item:value()
	end

	MenuCallbackHandler.callback_ECM_queue_message_input = function(self, item)
		ecm_rush_helper.settings.ECM_queue_message = item:value()
	end

	MenuCallbackHandler.ecm_placed_toggle_callback = function(self, item)
		ecm_rush_helper.settings.ecm_placed_toggle = Utils:ToggleItemToBoolean(item)
	end

	MenuCallbackHandler.callback_ecm_placed_input = function(self, item)
		ecm_rush_helper.settings.ecm_placed = item:value()
	end

--*							Pocket ECM menu
	MenuCallbackHandler.erh_pecm_switcher_callback = function(self, item)
		ecm_rush_helper.settings.pecm_toggle = Utils:ToggleItemToBoolean(item)
	end

	MenuCallbackHandler.callback_pprefix_input = function(self, item)
		ecm_rush_helper.settings.pprefix = item:value()
	end

	MenuCallbackHandler.callback_ecm_plow_time = function(self, item)
		ecm_rush_helper.settings.plow_time = item:value()
	end

	MenuCallbackHandler.callback_pECM_queue_message_input = function(self, item)
		ecm_rush_helper.settings.pECM_queue_message = item:value()
	end

	MenuCallbackHandler.callback_pECMs_players_w_pockets = function(self, item)
		ecm_rush_helper.settings.pECMs_players_req = item:value()
	end

	MenuCallbackHandler.callback_pECMs_pockets_w_pockets = function(self, item)
		ecm_rush_helper.settings.pECMs_amount_req = item:value()
	end

	MenuCallbackHandler.callback_pECM_collected_message_input = function(self, item)
		ecm_rush_helper.settings.pECM_collected = item:value()
	end

	MenuCallbackHandler.pecm_used_toggle_callback = function(self, item)
		ecm_rush_helper.settings.pecm_used_toggle = Utils:ToggleItemToBoolean(item)
	end

	MenuCallbackHandler.callback_pecm_used_input = function(self, item)
		ecm_rush_helper.settings.pecm_used = item:value()
	end

	MenuCallbackHandler.callback_erh_reset = function(self, item)
		MenuHelper:ResetItemsToDefaultValue(item, {["helper_mode"] = true}, 3)
		MenuHelper:ResetItemsToDefaultValue(item, {["message_input"] = true}, 'seconds left')
		MenuHelper:ResetItemsToDefaultValue(item, {["last_device_input"] = true}, "Last device")

		MenuHelper:ResetItemsToDefaultValue(item, {["erh_ecm_switcher"] = true}, true)
		MenuHelper:ResetItemsToDefaultValue(item, {["prefix_input"] = true}, 'ECM')
		MenuHelper:ResetItemsToDefaultValue(item, {["ecm_low_time"] = true}, 5)
		MenuHelper:ResetItemsToDefaultValue(item, {["ECM_queue_message_input"] = true}, "'s ECM next")
		MenuHelper:ResetItemsToDefaultValue(item, {["ecm_placed_switcher"] = true}, true)
		MenuHelper:ResetItemsToDefaultValue(item, {["ecm_placed_input"] = true}, "placed by")

		MenuHelper:ResetItemsToDefaultValue(item, {["erh_pecm_switcher"] = true}, true)
		MenuHelper:ResetItemsToDefaultValue(item, {["pprefix_input"] = true}, 'Pocket ECM')
		MenuHelper:ResetItemsToDefaultValue(item, {["ecm_plow_time"] = true}, 2)		
		MenuHelper:ResetItemsToDefaultValue(item, {["pECM_queue_message_input"] = true}, "'s pECM next")
		MenuHelper:ResetItemsToDefaultValue(item, {["pECMs_players_w_pockets"] = true}, 3)
		MenuHelper:ResetItemsToDefaultValue(item, {["pECMs_pockets"] = true}, 1)
		MenuHelper:ResetItemsToDefaultValue(item, {["pECM_collected_message_input"] = true}, "Round next")
		MenuHelper:ResetItemsToDefaultValue(item, {["pecm_used_switcher"] = true}, true)
		MenuHelper:ResetItemsToDefaultValue(item, {["pecm_used_input"] = true}, "used by")
	end
	
	ecm_rush_helper:load()

	MenuHelper:LoadFromJsonFile(ecm_rush_helper._path .. "menu/main.json", ecm_rush_helper, ecm_rush_helper.settings)
	MenuHelper:LoadFromJsonFile(ecm_rush_helper._path .. "menu/ecm.json", ecm_rush_helper, ecm_rush_helper.settings)
	MenuHelper:LoadFromJsonFile(ecm_rush_helper._path .. "menu/pecm.json", ecm_rush_helper, ecm_rush_helper.settings)
end )