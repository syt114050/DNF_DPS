/*
文件名:时装回收.nut
路径:OfficialProject/时装回收/时装回收.nut
创建日期:2026-05-18
文件用途:使用时装回收卷，将时装栏(INVENTORY_TYPE_AVARTAR=2)指定范围内的时装按配置规则回收为奖励道具。
         支持指定ID匹配和品级+等级匹配两种模式，命中重叠时优先指定ID。
*/

// ========== 辅助函数 ==========

function _Dps_FashionOnly_GetText_(Config, Key, DefaultText) {
    if (Config.rawin("提示文本") && Config["提示文本"].rawin(Key)) return Config["提示文本"][Key];
    return DefaultText;
}

function _Dps_FashionOnly_IsExcluded_(ExcludeList, EquipId) {
    foreach (exId in ExcludeList) {
        if (exId == EquipId) return true;
    }
    return false;
}

function _Dps_FashionOnly_DeleteDb_(Cid, SlotList) {
    if (SlotList.len() == 0) return;
    local SlotStr = "";
    for (local i = 0; i < SlotList.len(); i++) {
        if (i > 0) SlotStr += ",";
        // 时装栏客户端槽位 → DB槽位: dbSlot = clientSlot + 10
        SlotStr += (SlotList[i] + 10).tostring();
    }
    local Sql = "delete from taiwan_cain_2nd.user_items where charac_no=" + Cid + " and slot in (" + SlotStr + ");";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    SqlObj.Exec_Sql(Sql);
    MysqlPool.GetInstance().PutConnect(SqlObj);
}

// ========== 主处理函数 ==========

function _Dps_FashionOnly_Func_(SUser, ItemId) {
    local Config = GlobalConfig.Get("时装回收配置.json");
    local InvenObj = SUser.GetInven();
    if (!InvenObj) return;

    local Cid = SUser.GetCID();
    local RangeStart = Config["回收范围"][0];
    local RangeEnd   = Config["回收范围"][1];
    local ExcludeList = Config.rawin("指定装备ID不参与回收") ? Config["指定装备ID不参与回收"] : [];
    local foundValid = false;
    local index = 0;
    local allRewards = [];
    local deletedSlots = [];

    for (local i = RangeStart; i <= RangeEnd; i++) {
        local ItemObj = InvenObj.GetSlot(Inven.INVENTORY_TYPE_AVARTAR, i);
        if (!ItemObj || ItemObj.IsEmpty) continue;

        local EquipId = ItemObj.GetIndex();

        // 排除列表检查
        if (_Dps_FashionOnly_IsExcluded_(ExcludeList, EquipId)) continue;

        // 锁定检查
        local CheckItemLock = Sq_CallFunc(S_Ptr("0x8646942"), "int", ["pointer", "int", "int"], SUser.C_Object, 2, i);
        if (CheckItemLock) continue;

        local PvfItemObj = PvfItem.GetPvfItemById(EquipId);
        if (!PvfItemObj) continue;

        local EquipName = PvfItem.GetNameById(EquipId);

        // --- 指定装备ID回收 ---
        foreach (rule in Config["指定装备回收"]) {
            if (rule[0] == EquipId) {
                local RewardId  = rule[1];
                local MinCount  = rule[2];
                local MaxCount  = rule[3];
                local RewardName = PvfItem.GetNameById(RewardId);
                local RewardObj  = PvfItem.GetPvfItemById(RewardId);
                local totalRewards = [];

                local count = MathClass.Rand(MinCount, MaxCount + 1);

                if (RewardId == 0) {
                    SUser.RechargeCera(count);
                    _FashionOnlyRecycle_Helper.sendRewardMessageForCera(SUser, EquipName, ItemObj, count, EquipId);
                } else {
                    local equType = NativePointer(RewardObj.C_Object).add(141 * 4).readU32();
                    if (equType > 0) count = 1;
                    totalRewards.append([RewardId, count]);
                    allRewards.append([RewardId, count]);
                    _FashionOnlyRecycle_Helper.api_CUser_Add_Item_list(SUser, totalRewards);
                    _FashionOnlyRecycle_Helper.sendRewardMessageForItem(SUser, EquipName, ItemObj, RewardName, count, equType, EquipId, RewardId);
                }

                foundValid = true;
                ItemObj.Delete();
                deletedSlots.append(i);
                index++;
                break;
            }
        }
    }

    // --- 数据库清理 ---
    _Dps_FashionOnly_DeleteDb_(Cid, deletedSlots);

    // --- 结果通知 ---
    if (foundValid) {
        SUser.SendItemSpace(1);
        if (index > 0) {
            SUser.SendNotiPacketMessage("恭喜: " + index + " 件时装回收成功。", Config["信息播报发送位置"]);
            if (allRewards.len() > 0) {
                _FashionOnlyRecycle_Helper.SendItemWindowNotification(SUser, allRewards);
            }
        }
        if (Config.rawin("回收成功是否返还回收券道具") && Config["回收成功是否返还回收券道具"]) {
            SUser.GiveItem(ItemId, 1);
        }
    } else {
        _FashionOnlyRecycle_Helper.RecycleError(SUser, Config["回收失败信息"], ItemId);
    }
}

// ========== 辅助类 ==========

class _FashionOnlyRecycle_Helper {

    function RecycleError(SUser, msg, ItemId) {
        local Config = GlobalConfig.Get("时装回收配置.json");
        if (Config.rawin("信息提示窗口提示(true开启/false关闭)") && Config["信息提示窗口提示(true开启/false关闭)"]) {
            SUser.SendNotiBox(msg, 1);
        } else {
            SUser.SendNotiPacketMessage(msg, Config["信息播报发送位置"]);
        }
        SUser.GiveItem(ItemId, 1);
    }

    function sendRewardMessageForCera(SUser, EquipName, ItemObj, count, EquipId) {
        local Config = GlobalConfig.Get("时装回收配置.json");
        local AdMsgObj = AdMsg();
        AdMsgObj.PutType(Config["信息播报发送位置"]);
        AdMsgObj.PutString(" ");
        AdMsgObj.PutImoticon(Config["表情ID"]);
        AdMsgObj.PutString(Config["成功回收"]["标题"]);
        AdMsgObj.PutEquipment("[" + EquipName + "]", ItemObj, _FashionOnlyRecycle_Helper.RarityColor(EquipId));
        AdMsgObj.PutString(Config["成功回收"]["奖励提示"]);
        AdMsgObj.PutColorString("[" + count + "]", [255, 20, 0]);
        AdMsgObj.PutString("点券");
        AdMsgObj.Finalize();
        SUser.Send(AdMsgObj.MakePack());
        AdMsgObj.Delete();
    }

    function sendRewardMessageForItem(SUser, EquipName, ItemObj, RewardName, count, equType, EquipId, RewardId) {
        local Config = GlobalConfig.Get("时装回收配置.json");
        local AdMsgObj = AdMsg();
        AdMsgObj.PutType(Config["信息播报发送位置"]);
        AdMsgObj.PutString(" ");
        AdMsgObj.PutImoticon(Config["表情ID"]);
        AdMsgObj.PutString(Config["成功回收"]["标题"]);
        AdMsgObj.PutEquipment("[" + EquipName + "]", ItemObj, _FashionOnlyRecycle_Helper.RarityColor(EquipId));
        AdMsgObj.PutString(Config["成功回收"]["奖励提示"]);
        if (equType > 0) {
            AdMsgObj.PutColorString("[" + RewardName + "]", _FashionOnlyRecycle_Helper.RarityColor(RewardId));
        } else {
            AdMsgObj.PutColorString("[" + count + "]", [255, 20, 0]);
            AdMsgObj.PutString(Config["成功回收"]["单位"]);
            AdMsgObj.PutColorString("[" + RewardName + "]", _FashionOnlyRecycle_Helper.RarityColor(RewardId));
        }
        AdMsgObj.Finalize();
        SUser.Send(AdMsgObj.MakePack());
        AdMsgObj.Delete();
    }

    function RarityColor(itemId) {
        local PvfItemObj = PvfItem.GetPvfItemById(itemId);
        if (PvfItemObj == null) return [255, 255, 255];
        local rarity = PvfItemObj.GetRarity();
        return _FashionOnlyRecycle_Helper.rarityColorMap[(rarity).tostring()];
    }

    rarityColorMap = {
        "0": [255, 255, 255],
        "1": [104, 213, 237],
        "2": [179, 107, 255],
        "3": [255, 0, 255],
        "4": [255, 180, 0],
        "5": [255, 102, 102],
        "6": [255, 20, 147],
        "7": [255, 215, 0]
    };

    function api_CUser_Add_Item_list(SUser, item_list) {
        for (local i = 0; i < item_list.len(); i++) {
            local itemId = item_list[i][0];
            local quantity = item_list[i][1];
            local InvenObj = SUser.GetInven();
            if (!InvenObj) continue;

            local PvfItemObj = PvfItem.GetPvfItemById(itemId);
            if (!PvfItemObj) continue;

            local equType = NativePointer(PvfItemObj.C_Object).add(141 * 4).readU32();
            local maxStack = Sq_CallFunc(S_Ptr("0x0822C9FC"), "int", ["pointer"], PvfItemObj.C_Object);

            if (equType > 0) {
                local cnt = checkInventorySlot(SUser, itemId);
                if (cnt == 1) {
                    SUser.GiveItem(itemId, quantity);
                } else {
                    local mailItems = [[itemId, quantity]];
                    SUser.ReqDBSendMultiMail("GM", "背包空间不足，已通过邮件发送", 0, mailItems);
                }
                continue;
            }

            local slot = InvenObj.GetSlotById(itemId);
            if (slot != -1) {
                local ItemObj = InvenObj.GetSlot(1, slot);
                local currentCount = Sq_CallFunc(S_Ptr("0x80F783A"), "int", ["pointer"], ItemObj.C_Object);
                if (currentCount < maxStack) {
                    local canAdd = maxStack - currentCount;
                    if (quantity <= canAdd) {
                        Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], ItemObj.C_Object, currentCount + quantity);
                        SUser.SendUpdateItemList(1, 0, slot);
                    } else {
                        Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], ItemObj.C_Object, maxStack);
                        SUser.SendUpdateItemList(1, 0, slot);
                        local remaining = quantity - canAdd;
                        local mailItems = [[itemId, remaining]];
                        SUser.ReqDBSendMultiMail("GM", "背包堆叠已满，部分道具已通过邮件发送", 0, mailItems);
                    }
                    continue;
                }
            }

            local cnt = checkInventorySlot(SUser, itemId);
            if (cnt == 1) {
                SUser.GiveItem(itemId, quantity);
            } else {
                local mailItems = [[itemId, quantity]];
                SUser.ReqDBSendMultiMail("GM", "背包空间不足，已通过邮件发送", 0, mailItems);
            }
        }
    }

    function SendItemWindowNotification(SUser, item_list) {
        local Pack = Packet();
        Pack.Put_Header(1, 163);
        Pack.Put_Byte(1);
        Pack.Put_Short(0);
        Pack.Put_Int(0);
        Pack.Put_Short(item_list.len());
        for (local i = 0; i < item_list.len(); i++) {
            Pack.Put_Int(item_list[i][0]);
            Pack.Put_Int(item_list[i][1]);
        }
        Pack.Finalize(true);
        SUser.Send(Pack);
        Pack.Delete();
    }

    function checkInventorySlot(SUser, itemId) {
        local InvenObj = SUser.GetInven();
        if (!InvenObj) return 0;
        local type = Sq_CallFunc(S_Ptr("0x085018D2"), "int", ["pointer", "int"], InvenObj.C_Object, itemId);
        return Sq_CallFunc(S_Ptr("0x08504F64"), "int", ["pointer", "int", "int"], InvenObj.C_Object, type, 1);
    }
}

// ========== 加载/重载入口 ==========

function _Dps_FashionOnly_Logic_() {
    local Config = GlobalConfig.Get("时装回收配置.json");
    foreach (BoxId in Config["时装回收卷ID"]) {
        Cb_Use_Item_Sp_Func[BoxId] <- _Dps_FashionOnly_Func_;
    }
}

function _Dps_FashionOnly_Main_() {
    _Dps_FashionOnly_Logic_();
}

function _Dps_FashionOnly_Main_Reload_(OldConfig) {
    foreach (BoxId in OldConfig["时装回收卷ID"]) {
        local OldId = BoxId.tointeger();
        if (Cb_Use_Item_Sp_Func.rawin(OldId)) Cb_Use_Item_Sp_Func.rawdelete(OldId);
    }
    _Dps_FashionOnly_Logic_();
}
