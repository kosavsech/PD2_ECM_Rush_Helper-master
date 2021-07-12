_G.erh_pecm = _G.erh_pecm or {}
erh_pecm.data = {
	pcounter = 0,
	msg_done = 0,
	_p_life = 6
}

function erh_pecm:less_than_next_peer(peerid)
	if not ecm_rush_helper.data.next_pocket_peer or ecm_rush_helper.data.next_pocket_peer._id == peerid then
		if ecm_rush_helper:DebugEnabled() then
			log("DEBUG not ecm_rush_helper.data.next_pocket_peer")
		end
		return false
	end
	if ecm_rush_helper:DebugEnabled() then
		log("DEBUG attempt to compare number with string " .. tostring(ecm_rush_helper.peer_database[4][peerid]) .. " " .. tostring(ecm_rush_helper.peer_database[4][ecm_rush_helper.data.next_pocket_peer._id]))
	end
	if ecm_rush_helper.peer_database[4][peerid] < ecm_rush_helper.peer_database[4][ecm_rush_helper.data.next_pocket_peer._id] then
		return true
	end
	return false
end

function erh_pecm:is_2_round(peerid)
	if peerid >= ecm_rush_helper.data.next_pocket_peer._id then
		if ecm_rush_helper:DebugEnabled() then
			log("DEBUG is_2_round true")
		end
		return true
	end
	return false
end

function erh_pecm:pocket_ecm_update(t, dt)
	if not ecm_rush_helper.settings.pecm_toggle then
		return
	end
	if erh_pecm.data._p_life > 0 and erh_pecm.data.pcounter > 0 then
		erh_pecm.data._p_life = erh_pecm.data._p_life - TimerManager:main():delta_time()
	end
	if erh_pecm.data.pcounter == 1 and erh_pecm.data._p_life < ecm_rush_helper.settings.plow_time and managers.chat and managers.network:session() then
		erh_pecm.data.pcounter = erh_pecm.data.pcounter - 1
		if erh_pecm.data.pcounter == 0 then
			-- Collecting info about PECMs
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
				ecm_rush_helper.data.next_pocket_peer = ecm_rush_helper:get_next_after(peer._id, "pocket") or nil
				ecm_rush_helper.data.next_ecm_peer = ecm_rush_helper:get_next_after(peer._id, "ecm") or nil
				if ecm_rush_helper.peer_database[3][peer._id] == "pocket_ecm_jammer" and erh_pecm:less_than_next_peer(peer._id) and ecm_rush_helper.data.next_pocket_peer and erh_pecm.data.msg_done ~= 1 or ecm_rush_helper:has_pockets(peer._id) and erh_pecm:is_2_round(peer._id) and ecm_rush_helper.data.next_pocket_peer and erh_pecm.data.msg_done ~= 1 then
					if ecm_rush_helper.settings.reciever == 1 then
						managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.pprefix .. ': ' .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. ecm_rush_helper.data.next_pocket_peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message)
						for _, reciever in pairs(ecm_rush_helper.recievers) do
							reciever:send("send_chat_message", 1, ecm_rush_helper.settings.pprefix .. ': ' .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. ecm_rush_helper.data.next_pocket_peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message)
						end
					elseif ecm_rush_helper.settings.reciever == 2 then
						managers.chat:send_message(1, ecm_rush_helper.data.next_pocket_peer, ecm_rush_helper.settings.pprefix .. ': ' .. ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. ecm_rush_helper.data.next_pocket_peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message)
					elseif ecm_rush_helper.settings.reciever == 3 then
						managers.chat:_receive_message(1, ecm_rush_helper.settings.pprefix, ecm_rush_helper.settings.plow_time .. " " .. ecm_rush_helper.settings.message .. ", " .. ecm_rush_helper.data.next_pocket_peer._name .. " " ..  ecm_rush_helper.settings.pECM_queue_message, tweak_data.chat_colors[ecm_rush_helper.data.next_pocket_peer._id])
					end
					erh_pecm.data.msg_done = 1
				elseif not ecm_rush_helper:has_pockets(peer._id) and not ecm_rush_helper.data.next_pocket_peer and ecm_rush_helper:has_ecm(peer._id) and ecm_rush_helper.settings.ecm_toggle and erh_pecm.data.msg_done ~= 1 then
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
				elseif not ecm_rush_helper:has_ecm(peer._id) and not ecm_rush_helper.data.next_ecm_peer and not ecm_rush_helper.data.next_pocket_peer and not ecm_rush_helper:has_pockets(peer._id) and erh_pecm.data.msg_done ~= 1 then
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

if string.lower(RequiredScript) == "lib/units/beings/player/playerinventory" then
	Hooks:PostHook(PlayerInventory, "_start_jammer_effect", "ECM_Rush_Helper_PlayerInventory__start_jammer_effect", function(self, end_time)
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
				log("DEBUG pocket peer_id " .. peer_user._id)
				managers.mission._fading_debug_output:script().log(string.format("DEBUG pocket peer_id " .. peer_user._id), Color.red)
			end
		end
	end)

elseif string.lower(RequiredScript) == "lib/managers/hudmanager" then
	Hooks:PostHook(HUDManager, "update", "update_erh", function(self, t, dt)
		erh_pecm:pocket_ecm_update(t, dt)
	end)
end