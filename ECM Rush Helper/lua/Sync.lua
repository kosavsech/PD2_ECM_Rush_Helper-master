local cfg_num, peer, main_peer
ecm_rush_helper.main_peer = nil
local function main_peer_choose()
	local candidates = {
		nil, nil, nil, nil
	}
	for i, peer in pairs(ecm_rush_helper.modded_peers[1]) do
		if peer ~= nil then
			if ecm_rush_helper.modded_peers[2][peer._id] == "1" then
				ecm_rush_helper.main_peer = peer
				break
			elseif ecm_rush_helper.modded_peers[2][peer._id] ~= "4" and ecm_rush_helper.modded_peers[2][peer._id] ~= nil then
				table.insert(candidates, peer._id, peer)
			end
		end
	end
	for i, peer in pairs(candidates) do
		if peer ~= nil then
			ecm_rush_helper.main_peer = peer
			break
		end
	end
	if ecm_rush_helper.main_peer == nil then
		ecm_rush_helper.main_peer = managers.network:session():local_peer()
	end
end

Hooks:Add("NetworkReceivedData", "NetworkReceivedData_ECM_Rush_Helper_Sync", function(sender, id, data)
	if id == "ECM_Rush_Helper_Sync" then
		if data:match ("config") then
			cfg_num = data:match("%d+")
			peer = managers.network:session():peer(sender)
			ecm_rush_helper.modded_peers[1][peer._id] = peer
			ecm_rush_helper.modded_peers[2][peer._id] = cfg_num
			DelayedCalls:Add( "DelayedCallsMainPeerStoredCheck", 0.2, function()
				if ecm_rush_helper.main_peer == nil then
					main_peer_choose()
					-- store lowest id between mod users(all cfg priority) and send it
					LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "main_peer_id_is_" .. ecm_rush_helper.main_peer._id)
				elseif ecm_rush_helper.main_peer ~= nil then
					LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "main_peer_id_is_" .. ecm_rush_helper.main_peer._id)
				end
			end )
		elseif data:match ("main_peer_id_is_") then
			main_peer_id = data:match("%d+")
			ecm_rush_helper.main_peer = managers.network:session():peer(main_peer_id)
		elseif data:match ("main_peer_is_dead") then
			ecm_rush_helper.main_peer = nil
			LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "config" .. ecm_rush_helper.settings.reciever)
			main_peer_choose()
		end

		if ecm_rush_helper:DebugEnabled() then
			for i, peer in pairs(ecm_rush_helper.modded_peers[1]) do
				log("DEBUG modded peer " .. i .. " " .. peer._name .. " config num is " .. ecm_rush_helper.modded_peers[2][i])
			end
		end	
	end
end)

if string.lower(RequiredScript) == "lib/network/base/clientnetworksession" then
	Hooks:PostHook(ClientNetworkSession, "on_peer_synched", "Sync_client", function(self, peer_id, ...)
		LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "config" .. ecm_rush_helper.settings.reciever)
		DelayedCalls:Add( "DelayedCallsMainPeerStoredCheckSync_client", 0.5, function()
			if ecm_rush_helper.main_peer == nil then
				main_peer_choose()
				-- store lowest id between mod users(all cfg priority) and send it
				LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "main_peer_id_is_" .. ecm_rush_helper.main_peer._id)
			elseif ecm_rush_helper.main_peer ~= nil then
				LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "main_peer_id_is_" .. ecm_rush_helper.main_peer._id)
			end
		end )
	end)
elseif string.lower(RequiredScript) == "lib/network/base/hostnetworksession" then
	Hooks:PostHook(HostNetworkSession, "on_peer_sync_complete", "Sync_host" , function(self, peer, peer_id)
		LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "config" .. ecm_rush_helper.settings.reciever)
		DelayedCalls:Add( "DelayedCallsMainPeerStoredCheckSync_host", 0.5, function()
			if ecm_rush_helper.main_peer == nil then
				main_peer_choose()
				-- store lowest id between mod users(all cfg priority) and send it
				LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "main_peer_id_is_" .. ecm_rush_helper.main_peer._id)
			elseif ecm_rush_helper.main_peer ~= nil then
				LuaNetworking:SendToPeers("ECM_Rush_Helper_Sync", "main_peer_id_is_" .. ecm_rush_helper.main_peer._id)
			end
		end )
	end)
end