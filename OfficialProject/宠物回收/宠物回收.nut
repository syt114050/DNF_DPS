/*
文件名:宠物回收.nut
路径:OfficialProject/宠物回收/宠物回收.nut
创建日期:2026-05-16
文件用途:使用宠物回收卷，将宠物栏指定格子内的宠物按配置规则回收为奖励道具
*/

function _Dps_PetRecycle_GetText_(Config, Key, DefaultText) {
    if (Config.rawin("提示文本") && Config["提示文本"].rawin(Key)) return Config["提示文本"][Key];
    return DefaultText;
}

function _Dps_PetRecycle_IsExcluded_(ExcludeList, PetId) {
    foreach (exId in ExcludeList) {
        if (exId == PetId) return true;
    }
    return false;
}

function _Dps_PetRecycle_DeleteCreatureFromMgr_(InvenObj, ItemObj) {
    local CreatureMgrPtr = Sq_CallFunc(S_Ptr("0x080dd568"), "pointer", ["pointer"], InvenObj.C_Object);
    if (!CreatureMgrPtr) return;

    local CreatureUid = NativePointer(ItemObj.C_Object).add(7).readU32();
    if (CreatureUid == 0) return;

    Sq_CallFunc(S_Ptr("0x0833A854"), "int", ["pointer", "int"], CreatureMgrPtr, CreatureUid);
}

function _Dps_PetRecycle_DeleteCreatureDb_(Cid, Slot) {
    local Sql = "delete from taiwan_cain_2nd.creature_items where charac_no=" + Cid + " and slot=" + Slot + ";";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    SqlObj.Exec_Sql(Sql);
    MysqlPool.GetInstance().PutConnect(SqlObj);
}

function _Dps_PetRecycle_GiveReward_(SUser, RewardId, MinCount, MaxCount) {
    local Count = MathClass.Rand(MinCount, MaxCount + 1);
    if (Count <= 0) return;

    if (RewardId == 0) {
        SUser.RechargeCera(Count);
        return;
    }

    local PvfItemObj = PvfItem.GetPvfItemById(RewardId);
    if (!PvfItemObj) return;

    local EquType = NativePointer(PvfItemObj.C_Object).add(141 * 4).readU32();
    if (EquType > 0) Count = 1;

    local InvenObj = SUser.GetInven();
    if (!InvenObj) return;

    local Slot = InvenObj.GetSlotById(RewardId);
    if (Slot != -1) {
        local ItemObj = InvenObj.GetSlot(1, Slot);
        local MaxStack = Sq_CallFunc(S_Ptr("0x0822C9FC"), "int", ["pointer"], PvfItemObj.C_Object);
        local CurrentCount = Sq_CallFunc(S_Ptr("0x80F783A"), "int", ["pointer"], ItemObj.C_Object);
        if (CurrentCount < MaxStack) {
            local CanAdd = MaxStack - CurrentCount;
            if (Count <= CanAdd) {
                Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], ItemObj.C_Object, CurrentCount + Count);
                SUser.SendUpdateItemList(1, 0, Slot);
                return;
            } else {
                Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], ItemObj.C_Object, MaxStack);
                SUser.SendUpdateItemList(1, 0, Slot);
                local Remain = Count - CanAdd;
                local MailItems = [[RewardId, Remain]];
                SUser.ReqDBSendMultiMail("GM", "背包堆叠已满，部分道具已通过邮件发送", 0, MailItems);
                return;
            }
        }
    }

    local Cnt = _Dps_PetRecycle_CheckSlot_(SUser, RewardId);
    if (Cnt == 1) {
        SUser.GiveItem(RewardId, Count);
    } else {
        local MailItems = [[RewardId, Count]];
        SUser.ReqDBSendMultiMail("GM", "背包空间不足，已通过邮件发送", 0, MailItems);
    }
}

function _Dps_PetRecycle_CheckSlot_(SUser, ItemId) {
    local InvenObj = SUser.GetInven();
    local Type = Sq_CallFunc(S_Ptr("0x085018D2"), "int", ["pointer", "int"], InvenObj.C_Object, ItemId);
    return Sq_CallFunc(S_Ptr("0x08504F64"), "int", ["pointer", "int", "int"], InvenObj.C_Object, Type, 1);
}

function _Dps_PetRecycle_SendResultMsg_(SUser, Config, Index) {
    local AdMsgObj = AdMsg();
    AdMsgObj.PutType(Config["信息播报发送位置"]);
    AdMsgObj.PutString(" ");
    AdMsgObj.PutImoticon(Config["表情ID"]);
    AdMsgObj.PutString(_Dps_PetRecycle_GetText_(Config, "回收成功", "宠物回收成功"));
    AdMsgObj.PutString("，共回收 ");
    AdMsgObj.PutColorString("[" + Index + "]", [255, 180, 0]);
    AdMsgObj.PutString(" 只宠物");
    AdMsgObj.Finalize();
    SUser.Send(AdMsgObj.MakePack());
    AdMsgObj.Delete();
}

function _Dps_PetRecycle_Func_(SUser, ItemId) {
    local Config = GlobalConfig.Get("宠物回收配置.json");
    local InvenObj = SUser.GetInven();
    if (!InvenObj) return;

    local Cid = SUser.GetCID();
    local RangeStart = Config["回收范围"][0];
    local RangeEnd = Config["回收范围"][1];
    local ExcludeList = Config.rawin("排除宠物ID") ? Config["排除宠物ID"] : [];
    local FoundValid = false;
    local Index = 0;

    for (local i = RangeStart; i <= RangeEnd; i++) {
        local ItemObj = InvenObj.GetSlot(Inven.INVENTORY_TYPE_CREATURE, i);
        if (!ItemObj || ItemObj.IsEmpty) continue;

        local PetId = ItemObj.GetIndex();

        if (_Dps_PetRecycle_IsExcluded_(ExcludeList, PetId)) continue;

        local FoundRule = false;
        local RewardId = 0;
        local MinCount = 0;
        local MaxCount = 0;
        foreach (Rule in Config["回收规则"]) {
            if (Rule[0] == PetId) {
                RewardId = Rule[1];
                MinCount = Rule[2];
                MaxCount = Rule[3];
                FoundRule = true;
                break;
            }
        }
        if (!FoundRule) continue;

        _Dps_PetRecycle_DeleteCreatureFromMgr_(InvenObj, ItemObj);
        ItemObj.Delete();
        _Dps_PetRecycle_DeleteCreatureDb_(Cid, i);
        _Dps_PetRecycle_GiveReward_(SUser, RewardId, MinCount, MaxCount);

        FoundValid = true;
        Index++;
    }

    if (FoundValid) {
        SUser.SendItemSpace(7);
        _Dps_PetRecycle_SendResultMsg_(SUser, Config, Index);
        if (Config.rawin("回收成功是否返还回收券") && Config["回收成功是否返还回收券"]) {
            SUser.GiveItem(ItemId, 1);
        }
    } else {
        if (Config.rawin("回收成功是否返还回收券") && Config["回收成功是否返还回收券"]) {
            SUser.GiveItem(ItemId, 1);
        }
        SUser.SendNotiPacketMessage(_Dps_PetRecycle_GetText_(Config, "没有宠物", "宠物栏中没有可回收的宠物"), Config["信息播报发送位置"]);
    }
}

function _Dps_PetRecycle_Logic_() {
    local Config = GlobalConfig.Get("宠物回收配置.json");
    foreach (BoxId in Config["宠物回收卷ID"]) {
        Cb_Use_Item_Sp_Func[BoxId] <- _Dps_PetRecycle_Func_;
    }
}

function _Dps_PetRecycle_Main_() {
    _Dps_PetRecycle_Logic_();
}

function _Dps_PetRecycle_Main_Reload_(OldConfig) {
    foreach (BoxId in OldConfig["宠物回收卷ID"]) {
        local OldId = BoxId.tointeger();
        if (Cb_Use_Item_Sp_Func.rawin(OldId)) Cb_Use_Item_Sp_Func.rawdelete(OldId);
    }
    _Dps_PetRecycle_Logic_();
}
