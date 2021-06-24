if not erh_pecm then 
	dofile(ModPath .. 'lua/erh_pECM.lua')
end

if string.lower(RequiredScript) == "lib/managers/playermanager" then
	Hooks:PostHook(PlayerManager, "set_synced_deployable_equipment", "erh_PlayerManager_set_synced_deployable_equipment", function(self, peer, deployable, amount)
		if deployable == "ecm_jammer" or amount == 0 then
			ecm_rush_helper.peer_database[1][peer._id] = deployable
			ecm_rush_helper.peer_database[2][peer._id] = amount 
		end

		if game_state_machine and game_state_machine:current_state_name() == "ingame_standard" then
			local Lpeer = managers.network:session():local_peer():id()
			ecm_rush_helper.peer_database[3][Lpeer] = Global.player_manager.synced_grenades[Lpeer].grenade
			ecm_rush_helper.peer_database[4][Lpeer] = Application:digest_value(Global.player_manager.synced_grenades[Lpeer].amount, false) 
		end
	end)

elseif string.lower(RequiredScript) == "lib/network/handlers/unitnetworkhandler" then
	Hooks:PostHook(UnitNetworkHandler, "set_unit", "erh_UnitNetworkHandler_set_unit", function(self, unit, character_name, outfit_string, outfit_version, peer_id, team_id, visual_seed)
		if ecm_rush_helper:DebugEnabled() then
			log( "[DEBUG] set_unit " .. tostring(outfit_string) )
			local outfit = string.split(outfit_string, " ") or {}
			for i=1,#outfit do
				log('[DEBUG] - outfit ' .. i .. ': ' .. outfit[i])
			end
		end
		local outfit = string.split(outfit_string, " ") or {}
		if outfit[13] == "ecm_jammer" then
			ecm_rush_helper.peer_database[1][peer_id] = "ecm_jammer"
			ecm_rush_helper.peer_database[2][peer_id] = 1 
		end
	end)

elseif string.lower(RequiredScript) == "lib/units/equipment/ecm_jammer/ecmjammerbase" then
	local done = 0
	local counter = 0
	Hooks:PostHook(ECMJammerBase, "init", "erh_ECMJammerBase_init", function(self, unit)
		done = 0
		counter = counter + 1
	end)
-- host vers
	Hooks:PostHook(ECMJammerBase, "spawn", "erh_ECMJammerBase_spawn", function(pos, rot, battery_life_upgrade_lvl, owner, peer_id)
		if ecm_rush_helper.settings.ecm_placed_toggle then
			local peer_user = managers.network:session():peer(peer_id)
			if ecm_rush_helper.settings.reciever == 1 then
				ecm_rush_helper:build_recievers()
				managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.prefix .. ": " .. ecm_rush_helper.settings.ecm_placed .. " " ..peer_user._name)
				for _, reciever in pairs(ecm_rush_helper.recievers) do
					reciever:send("send_chat_message", 1, ecm_rush_helper.settings.prefix .. ": " .. ecm_rush_helper.settings.ecm_placed .. " " .. peer_user._name)
				end
			elseif ecm_rush_helper.settings.reciever == 2 then
				managers.chat:send_message(1, peer, ecm_rush_helper.settings.prefix .. ": " .. ecm_rush_helper.settings.ecm_placed .. " " .. peer_user._name)
			elseif ecm_rush_helper.settings.reciever == 3 then
				managers.chat:_receive_message(1, ecm_rush_helper.settings.prefix, ecm_rush_helper.settings.ecm_placed .. " " .. peer_user._name, tweak_data.chat_colors[peer_user._id])
			end
			if ecm_rush_helper:DebugEnabled() then
				log("DEBUG ECM host owner_id " .. peer_id)
				managers.mission._fading_debug_output:script().log(string.format("DEBUG ECM host owner_id " .. peer_id), Color.red)
			end
		end
	end)

-- client vers
	Hooks:PostHook(ECMJammerBase, "sync_setup", "erh_ECMJammerBase_sync_setup", function(self, upgrade_lvl, peer_id)
		if ecm_rush_helper.settings.ecm_placed_toggle then
			local peer_user = managers.network:session():peer(peer_id)
			if ecm_rush_helper.settings.reciever == 1 then
				ecm_rush_helper:build_recievers()
				managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.prefix .. ": " .. ecm_rush_helper.settings.ecm_placed .. " " .. peer_user._name)
				for _, reciever in pairs(ecm_rush_helper.recievers) do
					reciever:send("send_chat_message", 1, ecm_rush_helper.settings.prefix .. ": " .. ecm_rush_helper.settings.ecm_placed .. " " .. peer_user._name)
				end
			elseif ecm_rush_helper.settings.reciever == 2 then
				managers.chat:send_message(1, peer, ecm_rush_helper.settings.prefix .. ": " .. ecm_rush_helper.settings.ecm_placed .. " " .. peer_user._name)
			elseif ecm_rush_helper.settings.reciever == 3 then
				managers.chat:_receive_message(1, ecm_rush_helper.settings.prefix, ecm_rush_helper.settings.ecm_placed .. " " .. peer_user._name, tweak_data.chat_colors[peer_user._id])
			end
			if ecm_rush_helper:DebugEnabled() then
				log("DEBUG ECM sync_setup client owner_id " .. peer_id)
				managers.mission._fading_debug_output:script().log(string.format("DEBUG ECM sync_setup client owner_id " .. peer_id), Color.blue)
			end
		end
	end)

	Hooks:PostHook(ECMJammerBase, "update", "erh_ECMJammerBase_update", function(self, unit, t, dt)
		if self:active() and not self.notified and self._battery_life and self._battery_life < ecm_rush_helper.settings.low_time and managers.chat and ecm_rush_helper.settings.ecm_toggle and managers.network:session() then
			self.notified = true
			counter = counter - 1
			if counter == 0 and ecm_rush_helper.settings.reciever ~= 4 then
				if ecm_rush_helper.settings.reciever == 1 then
					ecm_rush_helper:build_recievers()
				end
				for i, peer in pairs(managers.network:session():all_peers()) do
					erh_pecm.data.next_pocket_peer = erh_pecm:get_next_after(peer._id, "pocket")
					erh_pecm.data.next_ecm_peer = erh_pecm:get_next_after(peer._id, "ecm")
					if erh_pecm:got_enough_pockets() and erh_pecm:has_pockets(peer._id) and done ~= 1 then
						erh_pecm:start_pECM_round_after_ECM(peer)
						done = 1
					elseif erh_pecm:has_ecm(peer._id) and not erh_pecm:got_enough_pockets() and done ~= 1 then
						if ecm_rush_helper.settings.reciever == 1 then
							managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.prefix .. ': ' .. ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.ECM_queue_message)
							for _, reciever in pairs(ecm_rush_helper.recievers) do
								reciever:send("send_chat_message", 1, ecm_rush_helper.settings.prefix .. ': ' .. ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.ECM_queue_message)
							end
						elseif ecm_rush_helper.settings.reciever == 2 then
							managers.chat:send_message(1, peer, ecm_rush_helper.settings.prefix .. ': ' .. ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.ECM_queue_message)
						elseif ecm_rush_helper.settings.reciever == 3 then
							managers.chat:_receive_message(1, ecm_rush_helper.settings.prefix,  ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " ..  ecm_rush_helper.settings.ECM_queue_message, tweak_data.chat_colors[peer._id])
						end
						done = 1
					elseif not erh_pecm:has_ecm(peer._id) and erh_pecm:has_pockets(peer._id) and ecm_rush_helper.settings.pecm_toggle and not erh_pecm:got_enough_pockets() and done ~= 1 then
						if ecm_rush_helper.settings.reciever == 1 then
							managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.prefix ..": " .. ecm_rush_helper.settings.low_time .. " " ..ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.pECM_queue_message)
							for _, reciever in pairs(ecm_rush_helper.recievers) do
								reciever:send("send_chat_message", 1, ecm_rush_helper.settings.prefix ..": " .. ecm_rush_helper.settings.low_time .. " " ..ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.pECM_queue_message)
							end
						elseif ecm_rush_helper.settings.reciever == 2 then
							managers.chat:send_message(1, peer, ecm_rush_helper.settings.prefix ..": " .. ecm_rush_helper.settings.low_time .. " " ..ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.pECM_queue_message)
						elseif ecm_rush_helper.settings.reciever == 3 then	
							managers.chat:_receive_message(1, ecm_rush_helper.settings.prefix, ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. ", " .. peer._name .. " " .. ecm_rush_helper.settings.pECM_queue_message, tweak_data.chat_colors[peer._id])
						end
						done = 1
					elseif not erh_pecm:has_ecm(peer._id) and not erh_pecm.data.next_ecm_peer and not erh_pecm.data.next_pocket_peer and not erh_pecm:has_pockets(peer._id) and not erh_pecm:got_enough_pockets() and done ~= 1 then
						if ecm_rush_helper.settings.reciever == 1 then
							managers.chat:receive_message_by_peer(1, managers.network:session():local_peer(), ecm_rush_helper.settings.prefix ..": " .. ecm_rush_helper.settings.low_time .. " " ..ecm_rush_helper.settings.message .. " " .. ecm_rush_helper.settings.full_end)
							for _, reciever in pairs(ecm_rush_helper.recievers) do
								reciever:send("send_chat_message", 1, ecm_rush_helper.settings.prefix ..": " .. ecm_rush_helper.settings.low_time .. " " ..ecm_rush_helper.settings.message .. " " .. ecm_rush_helper.settings.full_end)
							end
						elseif ecm_rush_helper.settings.reciever == 2 then
							managers.chat:send_message(1, peer, ecm_rush_helper.settings.prefix ..": " .. ecm_rush_helper.settings.low_time .. " " ..ecm_rush_helper.settings.message .. " " .. ecm_rush_helper.settings.full_end)
						elseif ecm_rush_helper.settings.reciever == 3 then
							managers.chat:_receive_message(1, ecm_rush_helper.settings.prefix, ecm_rush_helper.settings.low_time .. " " .. ecm_rush_helper.settings.message .. " " .. ecm_rush_helper.settings.full_end, tweak_data.chat_colors[peer._id])
						end
						done = 1
					end
				end
			end
		end
	end)
end