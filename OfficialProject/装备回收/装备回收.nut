// 回收装备的主函数
function RecycleItemFuncBynangua(SUser, ItemId) {
    local Config = GlobalConfig.Get("装备回收配置_Nangua.json");
    local RecycleCfg = Config["回收箱列表"][ItemId.tostring()];

    // 获取用户的背包对象，如果不存在则直接返回
    local InvenObj = SUser.GetInven();
    if (!InvenObj) {
        return;
    }

    local foundValidSlot = false;
    local index = 0;
    local allRewards = [];

    // 遍历装备栏指定范围的格子
    for (local i = RecycleCfg["回收位置"][0]; i <= RecycleCfg["回收位置"][1]; i++) {
        local ItemObj = InvenObj.GetSlot(1, i);

        // 如果该槽为空，跳过
        if (ItemObj.IsEmpty) {
            continue;
        }

        // 检查装备是否上锁，若上锁则跳过该装备
        local CheckItemLock = Sq_CallFunc(S_Ptr("0x8646942"), "int", ["pointer", "int", "int"], SUser.C_Object, 1, i);
        if (CheckItemLock) {
            continue;
        }

        local Item_Id = ItemObj.GetIndex();

        // 检查装备是否在排除列表中，如果在则跳过
        if ("指定装备ID不参与回收" in RecycleCfg && RecycleCfg["指定装备ID不参与回收"].len() > 0) {
            local isExcluded = false;
            foreach (excludeId in RecycleCfg["指定装备ID不参与回收"]) {
                if (excludeId == Item_Id) {
                    isExcluded = true;
                    break;
                }
            }
            if (isExcluded) {
                continue;
            }
        }

        local PvfItemObj = PvfItem.GetPvfItemById(Item_Id);
        local rarity = PvfItemObj.GetRarity();
        local level = PvfItemObj.GetUsableLevel();
        local Recycleitem_name = PvfItem.GetNameById(Item_Id);

        // 检查指定装备回收配置
        local found = false;
        foreach(item in RecycleCfg["指定装备回收"]) {
            if(item[0] == Item_Id) {
                local item_upgrade = ItemObj.GetUpgrade();
                if (item_upgrade > 0) {
                    Recycleitem_name = "+" + item_upgrade + Recycleitem_name;
                }

                // 兼容新旧格式：旧[装备ID, 奖励ID, 最小, 最大] 新[装备ID, [[奖励ID, 最小, 最大], ...]]
                local rewardList = [];
                if (item.len() == 2 && typeof item[1] == "array") {
                    rewardList = item[1];
                } else {
                    rewardList = [[item[1], item[2], item[3]]];
                }

                local totalRewards = [];
                foreach (reward in rewardList) {
                    local Rewarditem = reward[0];
                    local minCount = reward[1];
                    local maxCount = reward[2];
                    local count = MathClass.Rand(minCount, maxCount + 1);
                    if (Rewarditem == 0) {
                        SUser.RechargeCera(count);
                        _RecycleItem_nangua.sendRewardMessageForCera(SUser, Recycleitem_name, ItemObj, count, Item_Id);
                    } else {
                        local Rewarditem_name = PvfItem.GetNameById(Rewarditem);
                        local RewardItemObj = PvfItem.GetPvfItemById(Rewarditem);
                        local equ_type = NativePointer(RewardItemObj.C_Object).add(141 * 4).readU32();
                        if (equ_type > 0) {
                            count = 1;
                        }
                        totalRewards.append([Rewarditem, count]);
                        allRewards.append([Rewarditem, count]);
                        _RecycleItem_nangua.sendRewardMessageForItem(SUser, Recycleitem_name, ItemObj, Rewarditem_name, count, equ_type, Item_Id, Rewarditem);
                    }
                }
                if (totalRewards.len() > 0) {
                    _RecycleItem_nangua.api_CUser_Add_Item_list(SUser, totalRewards);
                }
                foundValidSlot = true;
                ItemObj.Delete();
                SUser.SendUpdateItemList(1, 0, i);
                index++;
                found = true;
                break;
            }
        }

        if(found) continue;

        // 检查品级回收配置
        if (Config["品级回收配置"]["开启品级以及装备等级的回收(true开启/false关闭)"]) {
            foreach(cfg in Config["品级回收配置"]["配置列表"]) {
                if (cfg[0] == rarity && cfg[1] == level) {
                    foundValidSlot = true;
                    // 兼容新旧格式：旧[道具ID, 最小, 最大] 新[[道具ID, 最小, 最大], ...]
                    local rewardList = [];
                    if (typeof cfg[2][0] == "array") {
                        rewardList = cfg[2];
                    } else {
                        rewardList = [cfg[2]];
                    }

                    local totalReward = [];
                    foreach (reward in rewardList) {
                        local count = MathClass.Rand(reward[1], reward[2] + 1);
                        if (reward[0] == 0) {
                            SUser.RechargeCera(count);
                            _RecycleItem_nangua.sendRewardMessageForCera(SUser, Recycleitem_name, ItemObj, count, Item_Id);
                        } else {
                            local Rewarditem_name = PvfItem.GetNameById(reward[0]);
                            local RewardItemObj = PvfItem.GetPvfItemById(reward[0]);
                            local equ_type = NativePointer(RewardItemObj.C_Object).add(141 * 4).readU32();
                            if (equ_type > 0) {
                                count = 1;
                            }
                            totalReward.append([reward[0], count]);
                            allRewards.append([reward[0], count]);
                            _RecycleItem_nangua.sendRewardMessageForItem(SUser, Recycleitem_name, ItemObj, Rewarditem_name, count, equ_type, Item_Id, reward[0]);
                        }
                    }
                    if (totalReward.len() > 0) {
                        _RecycleItem_nangua.api_CUser_Add_Item_list(SUser, totalReward);
                    }
                    ItemObj.Delete();
                    SUser.SendUpdateItemList(1, 0, i);
                    index++;
                }
            }
        }
    }

    // 发送结果消息
    if (foundValidSlot) {
        if (index > 0) {
            SUser.SendNotiPacketMessage("恭喜: " + index + " 件装备回收成功。", Config["信息播报发送位置"]);
            if (allRewards.len() > 0) {
                _RecycleItem_nangua.SendItemWindowNotification(SUser, allRewards);
            }
        }
        if(Config["回收成功是否返还回收券道具(true返还/false不返还)"]){
            SUser.GiveItem(ItemId, 1);
        }
    } else {
        _RecycleItem_nangua.RecycleError(SUser, Config["回收失败信息"], ItemId);
    }
}
class _RecycleItem_nangua {
    // 发送通知和返还道具
    function RecycleError(SUser, msg, ItemId) {
        local Config = GlobalConfig.Get("装备回收配置_Nangua.json");
        if(Config["信息提示窗口提示(true开启/false关闭)"]) {
            SUser.SendNotiBox(msg, 1);
        } else {
            SUser.SendNotiPacketMessage(msg, Config["信息播报发送位置"]);
        }
        SUser.GiveItem(ItemId, 1);
    }

    // 发送点券奖励消息
    function sendRewardMessageForCera(SUser, Recycleitem_name, ItemObj, count, Item_Id) {
        local Config = GlobalConfig.Get("装备回收配置_Nangua.json");
        local AdMsgObj = AdMsg();
        AdMsgObj.PutType(Config["信息播报发送位置"]);
        AdMsgObj.PutString(" ");
        AdMsgObj.PutImoticon(Config["表情ID"]);
        AdMsgObj.PutString(Config["成功回收"]["标题"]);
        AdMsgObj.PutEquipment("[" + Recycleitem_name + "]", ItemObj, _RecycleItem_nangua.RarityColor(Item_Id));
        AdMsgObj.PutString(Config["成功回收"]["奖励提示"]);
        AdMsgObj.PutColorString("[" + count + "]", [255, 20, 0]);
        AdMsgObj.PutString("点券");
        AdMsgObj.Finalize();
        SUser.Send(AdMsgObj.MakePack());
        AdMsgObj.Delete();
    }

    // 发送道具奖励消息
    function sendRewardMessageForItem(SUser, Recycleitem_name, ItemObj, Rewarditem_name, count, equ_type, Item_Id, Rewarditem) {
        local Config = GlobalConfig.Get("装备回收配置_Nangua.json");
        local AdMsgObj = AdMsg();
        AdMsgObj.PutType(Config["信息播报发送位置"]);
        AdMsgObj.PutString(" ");
        AdMsgObj.PutImoticon(Config["表情ID"]);
        AdMsgObj.PutString(Config["成功回收"]["标题"]);
        AdMsgObj.PutEquipment("[" + Recycleitem_name + "]", ItemObj, _RecycleItem_nangua.RarityColor(Item_Id));
        AdMsgObj.PutString(Config["成功回收"]["奖励提示"]);
        if (equ_type > 0) {
            AdMsgObj.PutColorString("[" + Rewarditem_name + "]", _RecycleItem_nangua.RarityColor(Rewarditem));
        } else {
            AdMsgObj.PutColorString("[" + count + "]", [255, 20, 0]);
            AdMsgObj.PutString(Config["成功回收"]["单位"]);
            AdMsgObj.PutColorString("[" + Rewarditem_name + "]", _RecycleItem_nangua.RarityColor(Rewarditem));
        }
        AdMsgObj.Finalize();
        SUser.Send(AdMsgObj.MakePack());
        AdMsgObj.Delete();
    }
    function RarityColor(item_id) {
		local PvfItemObj = PvfItem.GetPvfItemById(item_id);
		if (PvfItemObj == null) {
			return;
		}
		local CItem_get_rarity = PvfItemObj.GetRarity(); // 装备品级
		return _RecycleItem_nangua.rarityColorMap[(CItem_get_rarity).tostring()];
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
	function api_CUser_Add_Item_list(SUser, item_list) {
		for (local i = 0; i < item_list.len(); i++) {
			local item_id = item_list[i][0]; // 道具代码
			local quantity = item_list[i][1]; // 道具数量
			local InvenObj = SUser.GetInven();

			// 获取道具对象
			local PvfItemObj = PvfItem.GetPvfItemById(item_id);
			// 获取道具类型
			local equ_type = NativePointer(PvfItemObj.C_Object).add(141 * 4).readU32();
			// 获取最大堆叠数量
			local maxStack = Sq_CallFunc(S_Ptr("0x0822C9FC"), "int", ["pointer"], PvfItemObj.C_Object);

			// 如果是装备，直接检查空格并处理
			if (equ_type > 0) {
				local cnt = _RecycleItem_nangua.checkInventorySlot(SUser, item_id);
				if (cnt == 1) {
					SUser.GiveItem(item_id, quantity);
				} else {
					local RewardItems = [];
					RewardItems.append([item_id, quantity]);
					local title = "GM";
					local Text = "由于背包空间不足，已通过邮件发送，请查收！";
					SUser.ReqDBSendMultiMail(title, Text, 0, RewardItems);
				}
				continue;
			}

			// 获取道具在背包中的槽位
			local slot = InvenObj.GetSlotById(item_id);
			if (slot != -1) {
				// 获取槽位中的道具对象
				local ItemObj = InvenObj.GetSlot(1, slot);
				// 获取当前堆叠数量
				local currentCount = Sq_CallFunc(S_Ptr("0x80F783A"), "int", ["pointer"], ItemObj.C_Object);

				// 如果当前堆叠未满，计算可以添加的数量
				if (currentCount < maxStack) {
					local canAdd = maxStack - currentCount;
					if (quantity <= canAdd) {
						// 如果奖励数量小于等于可添加数量，直接添加
						Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], ItemObj.C_Object, currentCount + quantity);
						// 刷新背包显示
						SUser.SendUpdateItemList(1, 0, slot);
					} else {
						// 如果奖励数量大于可添加数量
						// 先将当前堆叠设置为最大
						Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], ItemObj.C_Object, maxStack);
						SUser.SendUpdateItemList(1, 0, slot);
						// 将剩余数量通过邮件发送
						local remaining = quantity - canAdd;
						local RewardItems = [];
						RewardItems.append([item_id, remaining]);
						local title = "GM";
						local Text = "由于背包堆叠已满，部分道具已通过邮件发送，请查收！";
						SUser.ReqDBSendMultiMail(title, Text, 0, RewardItems);
					}
					continue;
				} else {
					local RewardItems = [];
					RewardItems.append([item_id, quantity]);
					local title = "GM";
					local Text = "由于背包堆叠已满，已通过邮件发送，请查收！";
					SUser.ReqDBSendMultiMail(title, Text, 0, RewardItems);
					continue;
				}
			}

			// 如果道具不在背包中，检查空格
			local cnt = _RecycleItem_nangua.checkInventorySlot(SUser, item_id);
			if (cnt == 1) {
				// 如果道具有空格，直接添加到背包
				SUser.GiveItem(item_id, quantity);
			} else {
				// 如果背包空间不足，通过邮件发送
				local RewardItems = [];
				RewardItems.append([item_id, quantity]);
				local title = "GM";
				local Text = "由于背包空间不足，已通过邮件发送，请查收！";
				SUser.ReqDBSendMultiMail(title, Text, 0, RewardItems);
			}
		}
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
}

//加载入口
function _Dps_RecycleItem_Main_() {
    _Dps_RecycleItem_Logic_();
}

//重载入口
function _Dps_RecycleItem_Main_Reload_(OldConfig) {
    if (OldConfig.rawin("回收箱列表")) {
        foreach (BoxIdStr, BoxData in OldConfig["回收箱列表"]) {
            local OldId = BoxIdStr.tointeger();
            if (Cb_Use_Item_Sp_Func.rawin(OldId)) Cb_Use_Item_Sp_Func.rawdelete(OldId);
        }
    } else if (OldConfig.rawin("回收配置") && OldConfig["回收配置"].rawin("回收箱道具ID")) {
        foreach (BoxId in OldConfig["回收配置"]["回收箱道具ID"]) {
            Cb_Use_Item_Sp_Func.rawdelete(BoxId.tointeger());
        }
    }
    _Dps_RecycleItem_Logic_();
}

function _Dps_RecycleItem_Logic_() {
    local Cofig = GlobalConfig.Get("装备回收配置_Nangua.json");
    foreach (BoxIdStr, BoxData in Cofig["回收箱列表"]) {
        Cb_Use_Item_Sp_Func[BoxIdStr.tointeger()] <- RecycleItemFuncBynangua;
    }
}

