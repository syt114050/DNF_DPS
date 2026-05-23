dungeon_cleared <- {};
dungeon_cache <- {};
dropped_items <- {};
function _Dps_send_dungeon_msg_Main_() {
    //进入副本加载完毕时
    Cb_Party_OnStartMapFinishLoading_Enter_Func.EnterStartMapByNangua <- function(args) {
        local Cofig = GlobalConfig.Get("副本播报配置_Nangua.json");
    	local PartyObj = Party(args[0]);

    	if(!PartyObj || !Cofig["副本播报开关(true开启,false关闭)"])
    		return
    	for (local i = 0; i < 4; ++i) {
    		local SUser = PartyObj.GetUser(i);
    		if (SUser) {
                if (Cofig["指定角色CID不播报"].find(SUser.GetCID()) != null && _clear_dgn_Bynangua.CParty_get_member_count(PartyObj.C_Object) < 2) {
                    return;
                }
    			if(SUser.GetCID() in dungeon_cache){
    				dungeon_cache.rawdelete(SUser.GetCID());
    			}
                if (SUser.GetCID() in dropped_items) {
                    dropped_items.rawdelete(SUser.GetCID());
                }
    			dungeon_cleared[SUser.GetCID()] <- false; // 进入副本时初始化标志为未通关

    			local Bfobj = PartyObj.GetBattleField();
    			local DgnObj = Bfobj.GetDgn();
    			local DgnID = DgnObj.GetId();
    			local Dungeon_Name = DgnObj.GetName();
    			local dungeon_type = NativePointer(Bfobj.C_Object).add(460).readU8(); // 0 为普通副本，1 为非常困难深渊，2 为困难深渊
    			local dungeon_diff = Sq_CallFunc(S_Ptr("0x080F981C"), "int", ["pointer"], Bfobj.C_Object); // 获取副本难度
    			local diff_name = Cofig["副本难度命名"][(dungeon_diff).tostring()]; // 获取副本难度名称
    			local dgntypeName = _clear_dgn_Bynangua.DungeonType[(dungeon_type).tostring()];

    			local DgnData = {
    				"entered": true,
    				"Dungeon_Name": Dungeon_Name,
    				"dgntypeName": dgntypeName,
    				"diff_name": diff_name,
    				"totalTime": 0,
    				"HellParty_time_recorded": false,
    				"last_HellParty_time": 0,
    				"is_HellParty_room": false
    			};
    			//以角色ID为键记录副本信息
    			dungeon_cache[SUser.GetCID()] <- DgnData;
    		}
    	}
    }

    //清理房间完毕时
    Cb_Battle_Field_onClearMap_Leave_Func.onClearMapByNangua <- function(args) {
        local Cofig = GlobalConfig.Get("副本播报配置_Nangua.json");
    	local retval = args.pop();
    	local CBattle_Field = args[0];
    	local PartyObj = Party(NativePointer(CBattle_Field).add(-2852).C_Object);
    	if(!PartyObj)
    		return
    	local DgnId =  NativePointer(args[0]).add(404).readInt();
    	if (!Cofig["副本播报开关(true开启,false关闭)"]) {
    		return;
    	}
    	if (retval == DgnId) {
    		for (local i = 0; i < 4; ++i) {
    			local SUser = PartyObj.GetUser(i);
    			if (SUser) {
    				if (dungeon_cache.rawin(SUser.GetCID()) && dungeon_cache[SUser.GetCID()].rawin("entered")) {
    					local time = Sq_CallFunc(S_Ptr("0x085B6768"), "int", ["pointer"], PartyObj.C_Object);
    					if (!dungeon_cache[SUser.GetCID()]["is_HellParty_room"]) {
    						dungeon_cache[SUser.GetCID()]["totalTime"] += time;
    					} else {
    						dungeon_cache[SUser.GetCID()]["is_HellParty_room"] = false;
    					}
    				}
    			}
    		}
    	}
    }

    //放弃副本或未通关副本时
    Cb_Party_giveup_game_Enter_Func.giveupByNangua <- function(args) {
        local Cofig = GlobalConfig.Get("副本播报配置_Nangua.json");
    	local PartyObj = Party(args[0]);
    	local killcount = Sq_CallFunc(S_Ptr("0x085BF456"), "int", ["pointer"], NativePointer(args[0]).add(812).C_Object);
        if (!PartyObj) return;
        if (!Cofig["副本播报开关(true开启,false关闭)"]) return;
    	local SUser = User(args[1]);
    	local Party_Master = PartyObj.GetMaster();
    	local MasterName = Party_Master.GetCharacName();
    	local formattedTime = "";
    	local DgnId =  NativePointer(args[0]).add(814 * 4).readInt();
    	local name = SUser.GetCharacName();

    	// 如果副本ID不在允许播报的数组内则跳出
    	if (Cofig["不需要播报的副本ID(实例中的ID为怪物攻城的副本ID尽量不要删)"].find(DgnId) != null) {
    		return;
    	}

    	if (SUser.GetCID() in dungeon_cache) {
    		local dungeonInfo = dungeon_cache[SUser.GetCID()];
    		local dgnTypeName = dungeonInfo["dgntypeName"];
    		local dungeonName = dungeonInfo["Dungeon_Name"];
    		local diffName = dungeonInfo["diff_name"];
    		local totalTime = 0;
    		if (dungeon_cache.rawin(SUser.GetCID()) && dungeon_cache[SUser.GetCID()].rawin("totalTime")) {
    			totalTime = dungeon_cache[SUser.GetCID()]["totalTime"];
    			formattedTime = _clear_dgn_Bynangua.formatMilliseconds(totalTime);
    		}
    		if (dungeon_cleared.rawin(SUser.GetCID()) && dungeon_cleared[SUser.GetCID()] == true) {
    			dungeon_cache.rawdelete(SUser.GetCID());
    			dungeon_cleared[SUser.GetCID()] <- false;
    		} else {
    			local nameColorSwitch = Cofig["人物名称随机颜色开关(true开启,false关闭)"];
    			local equipSwitch = Cofig["掉落装备名称播报开关(true开启,false关闭)"];
    			local sendPos = Cofig["发送信息位置"];
    			local cid = SUser.GetCID();
    			// 发送未通关信息
    			if (totalTime == 0) {
    				if (nameColorSwitch) {
    					local segs = [
    						["玩家[", [255, 255, 255]],
    						[name, _clear_dgn_Bynangua.randomBrightColor()],
    						["]在[" + dgnTypeName + dungeonName + "-" + diffName + "]中连一个地图都没通过,击杀怪物数量<", [255, 255, 255]],
    						[killcount.tostring(), [255, 255, 255]],
    						[">", [255, 255, 255]]
    					];
    					if (equipSwitch && (cid in dropped_items)) {
    						_clear_dgn_Bynangua.appendEquipSegments(segs, dropped_items[cid]);
    					}
    					_clear_dgn_Bynangua.sendColoredMsg(segs, sendPos);
    				} else {
    					World.SendNotiPacketMessage(format(Cofig["未通过一个小地图播报信息"], name, dgnTypeName, dungeonName, diffName, killcount), sendPos);
    				}
    			} else if (MasterName == SUser.GetCharacName()) {
    				if (nameColorSwitch) {
    					local segs = [
    						["很遗憾,玩家[", [255, 255, 255]],
    						[name, _clear_dgn_Bynangua.randomBrightColor()],
    						["]在[" + dgnTypeName + dungeonName + "-" + diffName + "]中被打的落荒而逃,用时: ", [255, 255, 255]],
    						[formattedTime, [255, 255, 255]],
    						[",击杀怪物数量<", [255, 255, 255]],
    						[killcount.tostring(), [255, 255, 255]],
    						[">", [255, 255, 255]]
    					];
    					if (equipSwitch && (cid in dropped_items)) {
    						_clear_dgn_Bynangua.appendEquipSegments(segs, dropped_items[cid]);
    					}
    					_clear_dgn_Bynangua.sendColoredMsg(segs, sendPos);
    				} else {
    					World.SendNotiPacketMessage(format(Cofig["放弃副本"], name, dgnTypeName, dungeonName, diffName, formattedTime, killcount), sendPos);
    				}
    			} else {
    				if (nameColorSwitch) {
    					local segs = [
    						["玩家[", [255, 255, 255]],
    						[name, _clear_dgn_Bynangua.randomBrightColor()],
    						["]在<", [255, 255, 255]],
    						[MasterName, _clear_dgn_Bynangua.randomBrightColor()],
    						[">的队伍中,提前退出了[" + dgnTypeName + dungeonName + "-" + diffName + "],用时: ", [255, 255, 255]],
    						[formattedTime, [255, 255, 255]],
    						[",击杀怪物数量<", [255, 255, 255]],
    						[killcount.tostring(), [255, 255, 255]],
    						[">", [255, 255, 255]]
    					];
    					if (equipSwitch && (cid in dropped_items)) {
    						_clear_dgn_Bynangua.appendEquipSegments(segs, dropped_items[cid]);
    					}
    					_clear_dgn_Bynangua.sendColoredMsg(segs, sendPos);
    				} else {
    					World.SendNotiPacketMessage(format(Cofig["在队伍中提前退出副本"], name, MasterName, dgnTypeName, dungeonName, diffName, formattedTime, killcount), sendPos);
    				}
    			}
    			if (cid in dropped_items) {
    				dropped_items.rawdelete(cid);
    			}
    			dungeon_cache.rawdelete(SUser.GetCID());
    		}
    	}
    }

	Cb_Field_KillHellPartyGroupMonsterCnt_Leave_Func.KillHellPartyGroupMonsterCntByNangua <- function(args){
		local Cofig = GlobalConfig.Get("副本播报配置_Nangua.json");
		local CBattle_Field = args[0];
		local PartyObj = Party(NativePointer(CBattle_Field).add(-2852).C_Object);
		if(!PartyObj)
			return
		if (!Cofig["副本播报开关(true开启,false关闭)"]) {
			return;
		}
		local time = Sq_CallFunc(S_Ptr("0x085B6768"), "int", ["pointer"], PartyObj.C_Object);
		local CBattle_Field_IsKilledAllHellGruoups = Sq_CallFunc(S_Ptr("0x085BF250"), "int", ["pointer"], CBattle_Field);
		for (local i = 0; i < 4; ++i) {
			local SUser = PartyObj.GetUser(i);
			if (SUser) {
				if (dungeon_cache.rawin(SUser.GetCID()) && dungeon_cache[SUser.GetCID()].rawin("entered")) {
					dungeon_cache[SUser.GetCID()]["is_HellParty_room"] = true;
					if (CBattle_Field_IsKilledAllHellGruoups == 1) {
						dungeon_cache[SUser.GetCID()]["HellParty_time_recorded"] <- true;
						dungeon_cache[SUser.GetCID()]["last_HellParty_time"] = time;
						dungeon_cache[SUser.GetCID()]["totalTime"] += time;
					}
				}
			}
		}
	}

    //通关副本时
            //拾取道具时记录掉落装备
        Cb_UserHistoryLog_ItemAdd_Enter_Func.DungeonBroadcastItemTrack <- function(args) {
            local Cofig = GlobalConfig.Get("副本播报配置_Nangua.json");
            if (!Cofig["掉落装备名称播报开关(true开启,false关闭)"])
                return;
            local SUser = User(NativePointer(args[0]).readPointer());
            local ItemObj = Item(args[4]);
            local type = args[5];
            if (!ItemObj || type != 4) return;
            local PartyObj = SUser.GetParty();
            if (!PartyObj) return;
            local Bfobj = PartyObj.GetBattleField();
            if (!Bfobj.GetDgn()) return;
            local item_id = ItemObj.GetIndex();
            local PvfItemObj = PvfItem.GetPvfItemById(item_id);
            if (!PvfItemObj) return;
            local rarity = PvfItemObj.GetRarity();
            if (rarity < Cofig["掉落装备最低品级(3神器,4史诗)"]) return;
            local cid = SUser.GetCID();
            if (!(cid in dropped_items)) {
                dropped_items[cid] <- [];
            }
            dropped_items[cid].append({
                id = item_id,
                name = PvfItem.GetNameById(item_id),
                rarity = rarity
            });
        }

Cb_CParty_SetBestClearTime_Enter_Func.ClearTimeByNangua <- function (args) {
        local Cofig = GlobalConfig.Get("副本播报配置_Nangua.json");
    	local PartyObj = Party(args[0]);
    	local killcount = Sq_CallFunc(S_Ptr("0x085BF456"), "int", ["pointer"], NativePointer(args[0]).add(812).C_Object);
    	if(!PartyObj || !Cofig["副本播报开关(true开启,false关闭)"])
    		return
    	local dungeon_diff = args[2];
    	local clearTime = args[3];
    	local Bfobj = PartyObj.GetBattleField();
    	local DgnObj = Bfobj.GetDgn();
    	local diff_name = Cofig["副本难度命名"][(dungeon_diff).tostring()];
    	if (DgnObj) {
    		local Dungeon_Name = DgnObj.GetName();
    		local MemberNames = [];
    		for (local i = 0; i < 4; ++i) {
    			local SUser = PartyObj.GetUser(i);
    			if (SUser) {
    				if (Cofig["指定角色CID不播报"].find(SUser.GetCID()) != null && _clear_dgn_Bynangua.CParty_get_member_count(PartyObj.C_Object) < 2) {
						return;
					}
    				local name = SUser.GetCharacName();
    				MemberNames.append(name);
    				dungeon_cleared[SUser.GetCID()] <- true;
    			}
    		}

    		local time = _clear_dgn_Bynangua.formatMilliseconds(clearTime);
    		_clear_dgn_Bynangua.sendClearBroadcast(Cofig, MemberNames, Dungeon_Name, diff_name, time, killcount, PartyObj);
    		for (local i = 0; i < 4; ++i) {
                local TUser = PartyObj.GetUser(i);
                if (TUser) {
                    local CID = TUser.GetCID();
                    if (CID) {
                        if (CID in dropped_items) {
                            dropped_items.rawdelete(CID);
                        }
                        dungeon_cache.rawdelete(CID);
                    }
                }
            }
    	}
    }
}

class _clear_dgn_Bynangua {
    DungeonType = {
        "0": "",
        "1": "非常困难级深渊-",
        "2": "困难级深渊-",
    };

    function randomBrightColor() {
        local r = 80 + (rand() % 176);
        local g = 80 + (rand() % 176);
        local b = 80 + (rand() % 176);
        return [r, g, b];
    }

    function RarityColor(item_id) {
        local PvfItemObj = PvfItem.GetPvfItemById(item_id);
        if (PvfItemObj == null) return [255, 255, 255];
        local rarity = PvfItemObj.GetRarity();
        local rarityColorMap = {
            "0": [255, 255, 255],
            "1": [104, 213, 237],
            "2": [179, 107, 255],
            "3": [255, 0, 255],
            "4": [255, 180, 0],
            "5": [255, 102, 102],
            "6": [255, 20, 147],
            "7": [255, 215, 0]
        };
        return rarityColorMap[(rarity).tostring()];
    }

    function join(array, delimiter) {
        local result = "";
        for (local i = 0; i < array.len(); ++i) {
            if (i > 0) {
                result += delimiter;
            }
            result += array[i];
        }
        return result;
    }
    function formatMilliseconds(ms) {
        local str = "";
        local minutes = ms / 60000;
        local seconds = (ms % 60000) / 1000;
        local milliseconds = (ms % 1000) / 10;
        if (minutes > 0) {
            str = minutes + "分" +
                (seconds < 10 ? "0" : "") + seconds + "秒" +
                (milliseconds < 10 ? "0" : "") + milliseconds;
        } else {
            str = seconds + "秒" +
                (milliseconds < 10 ? "0" : "") + milliseconds;
        }
        return str;
    }
	function CParty_get_member_count(C_Object) {
		return Sq_CallFunc(S_Ptr("0x0859A16A"), "int", ["pointer"], C_Object);
	}

	function sendColoredMsg(segments, sendPos) {
		local msg = AdMsg();
		msg.PutType(sendPos);
		if (sendPos != 14) msg.PutString(" ");
		foreach (seg in segments) {
			msg.PutColorString(seg[0], seg[1]);
		}
		msg.Finalize();
		World.SendAll(msg.MakePack());
		msg.Delete();
	}

	function appendEquipSegments(segments, items) {
		if (items.len() == 0) return;
		segments.append([" 获得:", [255, 255, 255]]);
		for (local i = 0; i < items.len(); ++i) {
			if (i > 0) segments.append([",", [255, 255, 255]]);
			segments.append([items[i].name, RarityColor(items[i].id)]);
		}
	}

	function sendClearBroadcast(Cofig, MemberNames, Dungeon_Name, diff_name, time, killcount, PartyObj) {
		local nameColorSwitch = Cofig["人物名称随机颜色开关(true开启,false关闭)"];
		local equipSwitch = Cofig["掉落装备名称播报开关(true开启,false关闭)"];
		local sendPos = Cofig["发送信息位置"];

		if (!nameColorSwitch) {
			local joinedNames = join(MemberNames, ", ");
			World.SendNotiPacketMessage(format(Cofig["通关播报信息"], joinedNames, Dungeon_Name, diff_name, time, killcount), sendPos);
			return;
		}

		local segs = [["玩家[", [255, 255, 255]]];
		for (local j = 0; j < MemberNames.len(); ++j) {
			if (j > 0) segs.append([", ", [255, 255, 255]]);
			segs.append([MemberNames[j], randomBrightColor()]);
		}
		segs.append(["]通关[" + Dungeon_Name + " - " + diff_name + "]用时:[", [255, 255, 255]]);
		segs.append([time, [255, 255, 255]]);
		segs.append([" 击杀怪物数量<", [255, 255, 255]]);
		segs.append([killcount.tostring(), [255, 255, 255]]);
		segs.append([">", [255, 255, 255]]);

		if (equipSwitch) {
			local allItems = {};
			for (local j = 0; j < 4; ++j) {
				local pu = PartyObj.GetUser(j);
				if (pu) {
					local pcid = pu.GetCID();
					if (pcid in dropped_items) {
						foreach (item in dropped_items[pcid]) {
							allItems[item.id] <- item;
						}
					}
				}
			}
			local itemList = [];
			foreach (id, item in allItems) {
				itemList.append(item);
			}
			appendEquipSegments(segs, itemList);
		}

		sendColoredMsg(segs, sendPos);
	}
}

