_G.erh_pecm = _G.erh_pecm or {}
erh_pecm.data = {
	pcounter = 0,
	msg_done = 0,
	_p_life = 6,
	next_pocket_peer = nil,
	next_ecm_peer = nil
}

function erh_pecm:has_pockets(peerid)
	if ecm_rush_helper.peer_database[3][peerid] == "pocket_ecm_jammer" and ecm_rush_helper.peer_database[4][peerid] ~= 0 then
		return true
	end
	return false
end

function erh_pecm:has_ecm(peerid)
	if ecm_rush_helper.peer_database[1][peerid] == "ecm_jammer" and ecm_rush_helper.peer_database[2][peerid] ~= 0 then
		return true
	end
	return false
end

function erh_pecm:less_than_next_peer(peerid)
	if not erh_pecm.data.next_pocket_peer then
		return false
	end
	if ecm_rush_helper.peer_database[4][peerid] < ecm_rush_helper.peer_database[4][erh_pecm.data.next_pocket_peer._id] then
		return true
	end
	return false
end

function erh_pecm:is_2_round(peerid)
	if peerid >= erh_pecm.data.next_pocket_peer._id then
		if ecm_rush_helper:DebugEnabled() then
			log("DEBUG is_2_round true")
		end
		return true
	end
	return false
end

function erh_pecm:get_next_after(peer_id, device)
	local function has_device(peer_id)
		return device == "pocket" and erh_pecm:has_pockets(peer_id) or erh_pecm:has_ecm(peer_id)
	end

	for i, peer in pairs(managers.network:session():all_peers()) do
		if peer_id < peer._id and has_device(peer._id) then
			if ecm_rush_helper:DebugEnabled() then
				log("DEBUG get_next_after < " ..  peer_id .. " is ".. peer._id)
			end
			return peer
		end
	end
	for i, peer in pairs(managers.network:session():all_peers()) do
		if peer_id > peer._id and has_device(peer._id) then
			if ecm_rush_helper:DebugEnabled() then
				log("DEBUG get_next_after > " ..  peer_id .. " is ".. peer._id)
			end
			return peer
		end
	end
	for i, peer in pairs(managers.network:session():all_peers()) do
		if peer_id == peer._id and has_device(peer._id) then
			if ecm_rush_helper:DebugEnabled() then
				log("DEBUG get_next_after == " ..  peer_id .. " is ".. peer._id)
			end
			return peer
		end
	end
	return nil
end

function erh_pecm:got_enough_pockets()
	local players_with_pecm = 0 
	for x, grenade in pairs(ecm_rush_helper.peer_database[3]) do
		if grenade == "pocket_ecm_jammer" and ecm_rush_helper.peer_database[4][x] >= ecm_rush_helper.settings.pECMs_amount_req then
			players_with_pecm = players_with_pecm + 1
		end
	end
	if players_with_pecm >= ecm_rush_helper.settings.pECMs_players_req then
		return true
	end
	return false
end

function erh_pecm:start_pECM_round_after_ECM(peer)
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

function erh_pecm:pocket_ecm_update(t, dt)
	if ecm_rush_helper.settings.pecm_toggle then
		if erh_pecm.data._p_life > 0 and erh_pecm.data.pcounter > 0 then
			erh_pecm.data._p_life = erh_pecm.data._p_life - TimerManager:main():delta_time()
		end
		if erh_pecm.data.pcounter == 1 and erh_pecm.data._p_life < ecm_rush_helper.settings.plow_time and managers.chat and managers.network:session() then
			erh_pecm.data.pcounter = erh_pecm.data.pcounter - 1
			if erh_pecm.data.pcounter == 0 and ecm_rush_helper.settings.reciever ~= 4 then
				if game_state_machine and game_state_machine:current_state_name() == "ingame_standard" then
					for i, peer in pairs(managers.network:session():all_peers()) do
						if managers.network:session():peer(peer._id):unit() then
							ecm_rush_helper.peer_database[3][peer._id] = Global.player_manager.synced_grenades[peer._id].grenade
							ecm_rush_helper.peer_database[4][peer._id] = Application:digest_value(Global.player_manager.synced_grenades[peer._id].amount, false)
						end
					end
				end
				if ecm_rush_helper.settings.reciever == 1 then
					ecm_rush_helper:build_recievers()
				end
				for i, peer in pairs(managers.network:session():all_peers()) do
					erh_pecm.data.next_pocket_peer = erh_pecm:get_next_after(peer._id, "pocket")
					erh_pecm.data.next_ecm_peer = erh_pecm:get_next_after(peer._id, "ecm")
					if ecm_rush_helper.peer_database[3][peer._id] == "pocket_ecm_jammer" and erh_pecm:less_than_next_peer(peer._id) and erh_pecm.data.msg_done ~= 1 or erh_pecm:has_pockets(peer._id) and erh_pecm:is_2_round(peer._id) and erh_pecm.data.msg_done ~= 1 then
						if ecm_rush_helper.settings.reciever == 1 then
							managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.pprefix .. ': ' .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. erh_pecm.data.next_pocket_peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message)
							for _, reciever in pairs(ecm_rush_helper.recievers) do
								reciever:send("send_chat_message", 1, ecm_rush_helper.settings.pprefix .. ': ' .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. erh_pecm.data.next_pocket_peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message)
							end
						elseif ecm_rush_helper.settings.reciever == 2 then
							managers.chat:send_message(1, erh_pecm.data.next_pocket_peer, ecm_rush_helper.settings.pprefix .. ': ' .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. erh_pecm.data.next_pocket_peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message)
						elseif ecm_rush_helper.settings.reciever == 3 then
							managers.chat:_receive_message(1, ecm_rush_helper.settings.pprefix, ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. erh_pecm.data.next_pocket_peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message, tweak_data.chat_colors[erh_pecm.data.next_pocket_peer._id])
						end
						erh_pecm.data.msg_done = 1
					elseif not erh_pecm:has_pockets(peer._id) and not erh_pecm.data.next_pocket_peer and erh_pecm:has_ecm(peer._id) and ecm_rush_helper.settings.ecm_toggle and erh_pecm.data.msg_done ~= 1 then
						if ecm_rush_helper.settings.reciever == 1 then
							managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.pprefix .. ": " .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.ECM_queue_message)
							for _, reciever in pairs(ecm_rush_helper.recievers) do
								reciever:send("send_chat_message", 1, ecm_rush_helper.settings.pprefix .. ": " .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.ECM_queue_message)
							end
						elseif ecm_rush_helper.settings.reciever == 2 then
							managers.chat:send_message(1, peer, ecm_rush_helper.settings.pprefix .. ": " .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.ECM_queue_message)
						elseif ecm_rush_helper.settings.reciever == 3 then
							managers.chat:_receive_message(1, ecm_rush_helper.settings.pprefix, ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.ECM_queue_message, tweak_data.chat_colors[peer._id])
						end
						erh_pecm.data.msg_done = 1
					elseif not erh_pecm:has_ecm(peer._id) and not erh_pecm.data.next_ecm_peer and not erh_pecm.data.next_pocket_peer and not erh_pecm:has_pockets(peer._id) and erh_pecm.data.msg_done ~= 1 then
						if ecm_rush_helper.settings.reciever == 1 then
							managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.pprefix .. ": " .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. " " .. ecm_rush_helper.settings.full_end) 
							for _, reciever in pairs(ecm_rush_helper.recievers) do
								reciever:send("send_chat_message", 1, ecm_rush_helper.settings.pprefix .. ": " .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. " " .. ecm_rush_helper.settings.full_end) 
							end
						elseif ecm_rush_helper.settings.reciever == 2 then
							managers.chat:send_message(1, peer, ecm_rush_helper.settings.pprefix .. ": " .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. " " .. ecm_rush_helper.settings.full_end) 
						elseif ecm_rush_helper.settings.reciever == 3 then
							managers.chat:_receive_message(1, ecm_rush_helper.settings.pprefix, ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. " " .. ecm_rush_helper.settings.full_end, tweak_data.chat_colors[peer._id])
						end
						erh_pecm.data.msg_done = 1
					end
				end
			end
		end
	end
end

if string.lower(RequiredScript) == "lib/units/beings/player/playerinventory" then
	Hooks:PostHook(PlayerInventory, "_start_jammer_effect", "erh_PlayerInventory__start_jammer_effect", function(self, end_time)
		erh_pecm.data._p_life = 6
		erh_pecm.data.msg_done = 0
		erh_pecm.data.pcounter = erh_pecm.data.pcounter + 1
		if ecm_rush_helper.settings.pecm_used_toggle then
			local peer_user = managers.network:session():peer_by_unit(self._unit)
			if ecm_rush_helper.settings.reciever == 1 then
				ecm_rush_helper:build_recievers()
				managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.pprefix .. ": " .. ecm_rush_helper.settings.pecm_used.. " " .. peer_user._name)
				for _, reciever in pairs(ecm_rush_helper.recievers) do
					reciever:send("send_chat_message", 1, ecm_rush_helper.settings.pprefix .. ": " .. ecm_rush_helper.settings.pecm_used .. " " .. peer_user._name)
				end
			elseif ecm_rush_helper.settings.reciever == 2 then
				managers.chat:send_message(1, peer, ecm_rush_helper.settings.pprefix .. ": " .. ecm_rush_helper.settings.pecm_used .. " " .. peer_user._name)
			elseif ecm_rush_helper.settings.reciever == 3 then
				managers.chat:_receive_message(1, ecm_rush_helper.settings.pprefix, ecm_rush_helper.settings.pecm_used .. " " .. peer_user._name, tweak_data.chat_colors[peer_user._id])
			end
			if ecm_rush_helper:DebugEnabled() then
				log("DEBUG pocket peer_id " .. peer._id)
				managers.mission._fading_debug_output:script().log(string.format("DEBUG pocket peer_id " .. peer._id), Color.red)
			end
		end
	end)

elseif string.lower(RequiredScript) == "lib/managers/hudmanager" then
	Hooks:PostHook(HUDManager, "update", "update_erh", function(self, t, dt)
		erh_pecm:pocket_ecm_update(t, dt)
	end)
end