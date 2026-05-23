_SpecialItemBynangua <- {
    "Rarity4": {},
    "Rarity3": {},
    "Rarity2": {}
}

function _Dps_SSDL_nangua_Main_() {
	//进入副本
    Cb_History_DungeonEnter_Func.RindroSSEnterByNangua <- function(SUser, Data) {
        _SpecialItemBynangua.Rarity4.rawset(SUser.GetCID(), []);
        _SpecialItemBynangua.Rarity3.rawset(SUser.GetCID(), []);
        _SpecialItemBynangua.Rarity2.rawset(SUser.GetCID(), []);
    }

    //离开副本
    Cb_History_DungeonLeave_Func.RindroSSLeaveByNangua <- function(SUser, Data) {
		local Cofig = GlobalConfig.Get("史诗掉落奖励配置_南瓜.json");
        local PartyObj = SUser.GetParty();
        if (!PartyObj) return;
        local Bfobj = PartyObj.GetBattleField();
        local DgnObj = Bfobj.GetDgn();
        if (DgnObj) {
            local Dungeon_Name = DgnObj.GetName();
            
            // 处理史诗装备
            if (_SpecialItemBynangua.Rarity4.rawin(SUser.GetCID())) {
                local ItemObjS = _SpecialItemBynangua.Rarity4[SUser.GetCID()];
                if (ItemObjS != null && ItemObjS.len() > 0) {
                    local config = Cofig["奖励控制"]["多件SS对应奖励(史诗)"];
                    local key = ItemObjS.len().tostring();
                    if (config.rawin(key)) {
                        Nangua_SSMSG.SendTitle(SUser, Dungeon_Name, "中获得史诗装备");
                        foreach(ItemObj in ItemObjS) {
                            local item_id = ItemObj.GetIndex();
                            Nangua_SSMSG.ItemMsg(item_id, ItemObj);
                        }
                        Nangua_SSMSG.SendCntMsg(ItemObjS.len());
                        Nangua_SSMSG.SendMiddle();
                        ProcessRewards(SUser, config[key]);
                        Nangua_SSMSG.EndMsg();
                    }
                }
                _SpecialItemBynangua.Rarity4.rawset(SUser.GetCID(), []);
            }

            // 处理神器装备
            if (_SpecialItemBynangua.Rarity3.rawin(SUser.GetCID())) {
                local ItemObjS = _SpecialItemBynangua.Rarity3[SUser.GetCID()];
                if (ItemObjS != null && ItemObjS.len() > 0) {
                    local config = Cofig["奖励控制"]["多件神器对应奖励"];
                    local key = ItemObjS.len().tostring();
                    if (config.rawin(key)) {
                        Nangua_SSMSG.SendTitle(SUser, Dungeon_Name, "中获得神器装备");
                        foreach(ItemObj in ItemObjS) {
                            local item_id = ItemObj.GetIndex();
                            Nangua_SSMSG.ItemMsg(item_id, ItemObj);
                        }
                        Nangua_SSMSG.SendCntMsg(ItemObjS.len());
                        Nangua_SSMSG.SendMiddle();
                        ProcessRewards(SUser, config[key]);
                        Nangua_SSMSG.EndMsg();
                    }
                }
                _SpecialItemBynangua.Rarity3.rawset(SUser.GetCID(), []);
            }

            // 处理稀有装备
            if (_SpecialItemBynangua.Rarity2.rawin(SUser.GetCID())) {
                local ItemObjS = _SpecialItemBynangua.Rarity2[SUser.GetCID()];
                if (ItemObjS != null && ItemObjS.len() > 0) {
                    local config = Cofig["奖励控制"]["多件稀有对应奖励"];
                    local key = ItemObjS.len().tostring();
                    if (config.rawin(key)) {
                        Nangua_SSMSG.SendTitle(SUser, Dungeon_Name, "中获得稀有装备");
                        foreach(ItemObj in ItemObjS) {
                            local item_id = ItemObj.GetIndex();
                            Nangua_SSMSG.ItemMsg(item_id, ItemObj);
                        }
                        Nangua_SSMSG.SendCntMsg(ItemObjS.len());
                        Nangua_SSMSG.SendMiddle();
                        ProcessRewards(SUser, config[key]);
                        Nangua_SSMSG.EndMsg();
                    }
                }
                _SpecialItemBynangua.Rarity2.rawset(SUser.GetCID(), []);
            }
        }
    }

    Cb_UserHistoryLog_ItemAdd_Enter_Func.ItemAddByNangua <- function(args) {
		local Cofig = GlobalConfig.Get("史诗掉落奖励配置_南瓜.json");
        local SUser = User(NativePointer(args[0]).readPointer());
        local InvenObj = SUser.GetInven();
        local ItemObj = Item(args[4]);
        local type = args[5];
        local PartyObj = SUser.GetParty();
        if (!PartyObj) return;
        local Bfobj = PartyObj.GetBattleField();
        local DgnObj = Bfobj.GetDgn();
        if (!DgnObj) return;
        local Dungeon_Name = DgnObj.GetName();
        if (!ItemObj) return;
        local item_id = ItemObj.GetIndex();
        local ItemType = Sq_CallFunc(S_Ptr("0x085018D2"), "int", ["pointer", "int"], InvenObj.C_Object, item_id);
        local pvfitem = PvfItem.GetPvfItemById(item_id);

        // 史诗装备记录
        if (pvfitem.GetRarity() == 4 && type == 4 && ItemType == 1 && Cofig["奖励控制"]["多件史诗奖励控制开关"]) {
            if (!_SpecialItemBynangua.Rarity4.rawin(SUser.GetCID())) {
                _SpecialItemBynangua.Rarity4.rawset(SUser.GetCID(), []);
            }
            _SpecialItemBynangua.Rarity4[SUser.GetCID()].append(ItemObj);
        }
        // 神器装备记录
        else if (pvfitem.GetRarity() == 3 && type == 4 && ItemType == 1 && Cofig["奖励控制"]["多件神器奖励控制开关"]) {
            if (!_SpecialItemBynangua.Rarity3.rawin(SUser.GetCID())) {
                _SpecialItemBynangua.Rarity3.rawset(SUser.GetCID(), []);
            }
            _SpecialItemBynangua.Rarity3[SUser.GetCID()].append(ItemObj);
        }
        // 稀有装备记录
        else if (pvfitem.GetRarity() == 2 && type == 4 && ItemType == 1 && Cofig["奖励控制"]["多件稀有奖励控制开关"]) {
            if (!_SpecialItemBynangua.Rarity2.rawin(SUser.GetCID())) {
                _SpecialItemBynangua.Rarity2.rawset(SUser.GetCID(), []);
            }
            _SpecialItemBynangua.Rarity2[SUser.GetCID()].append(ItemObj);
        }

        // 指定道具奖励逻辑保持不变
        if (!Cofig["指定道具奖励控制"]["指定道具奖励控制开关"]) return;
        local Itemid = item_id.tostring();
        if (Cofig["指定道具奖励控制"]["指定道具对应奖励"].rawin(Itemid) && type == 4) {
            Nangua_SSMSG.SendTitle(SUser, Dungeon_Name, "中获得特定道具");
            Nangua_SSMSG.ItemMsg(item_id, ItemObj);
            Nangua_SSMSG.SendMiddle();
            ProcessRewards(SUser, Cofig["指定道具奖励控制"]["指定道具对应奖励"][Itemid]);
            Nangua_SSMSG.EndMsg();
        }
    }
	// 处理奖励逻辑
	function ProcessRewards(SUser, rewards) {
		local Cofig = GlobalConfig.Get("史诗掉落奖励配置_南瓜.json");
		local config = Cofig["信息播报"];
		local totalRewards = [];
		local rewardMessages = [];
		// 遍历奖励列表
		foreach(reward in rewards) {
			local itemId = reward[0];
			local itemCnt = reward[1];
			if (itemId == 0) {
				// 点券奖励
				local ceraMsgObj = AdMsg();
				ceraMsgObj.PutType(config["发送位置"]);
				if (config["发送位置"] != 14) {
					ceraMsgObj.PutString(" ");
				}
				ceraMsgObj.PutColorString("点券", config["内容颜色"]);
				ceraMsgObj.PutColorString("[" + itemCnt + "]", [255, 20, 0]);
				ceraMsgObj.Finalize();
				World.SendAll(ceraMsgObj.MakePack());
				ceraMsgObj.Delete();
				SUser.RechargeCera(itemCnt);
			} else {
				totalRewards.append([itemId, itemCnt]);
				local itemName = PvfItem.GetNameById(itemId);
				local color = Nangua_SSMSG.RarityColor(itemId);
				rewardMessages.append([itemName, itemCnt, color]);
			}
		}
		Nangua_SSMSG.api_CUser_Add_Item_list(SUser, totalRewards);
		// 发送奖励物品信息通知
		if (rewardMessages.len() > 0) {
			local rewardMsgObj = AdMsg();
			rewardMsgObj.PutType(config["发送位置"]);
			if (config["发送位置"] != 14) {
				rewardMsgObj.PutString(" ");
			}
			foreach(message in rewardMessages) {
				rewardMsgObj.PutColorString("[" + message[0] + "]", message[2]);
				rewardMsgObj.PutColorString("<" + message[1] + ">", [255, 20, 0]);
				rewardMsgObj.PutColorString("个", config["内容颜色"]);
			}
			rewardMsgObj.Finalize();
			World.SendAll(rewardMsgObj.MakePack());
			rewardMsgObj.Delete();
		}
	}
}

class Nangua_SSMSG {
	function SendTitle(SUser, Dungeon_Name, msg) {
		local Cofig = GlobalConfig.Get("史诗掉落奖励配置_南瓜.json");
		local config = Cofig["信息播报"];
		local title = AdMsg();
		title.PutType(config["发送位置"]);
		if (config["发送位置"] != 14) {
			title.PutString(" ");
		}
		title.PutColorString(config["标题"][0], config["标题"][1]);
		title.PutColorString("恭喜玩家", config["内容颜色"]);
		title.PutColorString("[" + SUser.GetCharacName() + "]", [255, 20, 0]);
		title.PutColorString("在", config["内容颜色"]);
		title.PutColorString("[" + Dungeon_Name + "]", [255, 20, 0]);
		title.PutColorString("" + msg + "", config["内容颜色"]);
		title.Finalize();
		World.SendAll(title.MakePack());
		title.Delete();
	}

	function SendMiddle() {
		local Cofig = GlobalConfig.Get("史诗掉落奖励配置_南瓜.json");
		local config = Cofig["信息播报"];
		local MiddleMsgObj = AdMsg();
		MiddleMsgObj.PutType(config["发送位置"]);
		if (config["发送位置"] != 14) {
			MiddleMsgObj.PutString(" ");
		}
		MiddleMsgObj.PutColorString("特此奖励:", config["内容颜色"]);
		MiddleMsgObj.Finalize();
		World.SendAll(MiddleMsgObj.MakePack());
		MiddleMsgObj.Delete();
	}

	function SendCntMsg(cnt) {
		local Cofig = GlobalConfig.Get("史诗掉落奖励配置_南瓜.json");
		local config = Cofig["信息播报"];
		local CntMsgObj = AdMsg();
		CntMsgObj.PutType(config["发送位置"]);
		if (config["发送位置"] != 14) {
			CntMsgObj.PutString(" ");
		}
		CntMsgObj.PutColorString("合计", config["内容颜色"]);
		CntMsgObj.PutColorString("[" + cnt + "]", [255, 20, 0]);
		CntMsgObj.PutColorString("件装备", config["内容颜色"]);
		CntMsgObj.Finalize();
		World.SendAll(CntMsgObj.MakePack());
		CntMsgObj.Delete();
	}

	function ItemMsg(item_id, ItemObj) {
		local Cofig = GlobalConfig.Get("史诗掉落奖励配置_南瓜.json");
		local config = Cofig["信息播报"];
		local MsgObj = AdMsg();
		MsgObj.PutType(config["发送位置"]);
		if (config["发送位置"] != 14) {
			MsgObj.PutString(" ");
		}
		MsgObj.PutEquipment("[" + PvfItem.GetNameById(item_id) + "]", ItemObj, Nangua_SSMSG.RarityColor(item_id));
		MsgObj.Finalize();
		World.SendAll(MsgObj.MakePack());
		MsgObj.Delete();
	}

	function EndMsg() {
		local Cofig = GlobalConfig.Get("史诗掉落奖励配置_南瓜.json");
		local config = Cofig["信息播报"];
		local endMsgObj = AdMsg();
		endMsgObj.PutType(config["发送位置"]);
		if (config["发送位置"] != 14) {
			endMsgObj.PutString(" ");
		}
		endMsgObj.PutColorString(config["结尾"][0], config["结尾"][1]);
		endMsgObj.Finalize();
		World.SendAll(endMsgObj.MakePack());
		endMsgObj.Delete();
	}
	function api_CUser_Add_Item_list(SUser, item_list) {
		for (local i = 0; i < item_list.len(); i++) {
			local item_id = item_list[i][0]; // 道具代码
			local quantity = item_list[i][1]; // 道具数量
			local cnt = Nangua_SSMSG.checkInventorySlot(SUser, item_id);
			if (cnt == 1) {
				SUser.GiveItem(item_id, quantity); //使用窗口发送奖励
			} else {
				local RewardItems = [];
				RewardItems.append([item_id, quantity]);
				local title = "GM"
				local Text = "由于背包空间不足，已通过邮件发送，请查收！"
				//角色类 发送邮件函数  (标题, 正文, 金币, 道具列表[[3037,100],[3038,100]])
				SUser.ReqDBSendMultiMail(title, Text, 0, RewardItems)
			}
		}
		Nangua_SSMSG.SendItemWindowNotification(SUser, item_list);
	}
	function SendItemWindowNotification(SUser, item_list) {
		local Pack = Packet();
		Pack.Put_Header(1, 163); //协议
		Pack.Put_Byte(1); //默认1
		Pack.Put_Short(0); //槽位id 填入0即可
		Pack.Put_Int(0); //未知 0以上即可
		Pack.Put_Short(item_list.len()); //道具组数
		//写入道具代码和道具数量
		for (local i = 0; i < item_list.len(); i++) {
			Pack.Put_Int(item_list[i][0]); //道具代码
			Pack.Put_Int(item_list[i][1]); //道具数量 装备/时装时 任意均可
		}
		Pack.Finalize(true); //确定发包内容
		SUser.Send(Pack); //发包
		Pack.Delete(); //清空buff区
	}
	/**
	 * 根据道具类型背包空格数量
	 * @param {pointer} SUser - 用户
	 * @param {int} item_id - 需要查找的道具ID
	 * @returns {int} - 空格数量
	 */
	function checkInventorySlot(SUser, itemid) {
		local InvenObj = SUser.GetInven();
		local type = Sq_CallFunc(S_Ptr("0x085018D2"), "int", ["pointer", "int"], InvenObj.C_Object, itemid);
		local cnt = Sq_CallFunc(S_Ptr("0x08504F64"), "int", ["pointer", "int", "int"], InvenObj.C_Object, type, 1);

		return cnt;
	}
	function RarityColor(item_id) {
		local PvfItemObj = PvfItem.GetPvfItemById(item_id);
		if (PvfItemObj == null) {
			return;
		}
		local CItem_get_rarity = PvfItemObj.GetRarity(); // 装备品级
		return Nangua_SSMSG.rarityColorMap[(CItem_get_rarity).tostring()];
	}
	//品级对应的RGB
	rarityColorMap = {
		"0": [255, 255, 255], // 普通
		"1": [104, 213, 237], // 高级
		"2": [179, 107, 255], // 稀有
		"3": [255, 0, 255], // 神器
		"4": [255, 180, 0], // 史诗
		"5": [255, 102, 102], // 勇者
		"6": [255, 20, 147], // 深粉红色
		"7": [255, 215, 0] // 金色
	};
}