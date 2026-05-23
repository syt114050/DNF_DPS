/*
文件名:宠物合成.nut
路径:OfficialProject/宠物合成/宠物合成.nut
创建日期:2026-05-03
更新日期:2026-05-17
文件用途:使用宠物合成卷，将指定槽位宠物按配置概率合成为目标宠物
       支持: 多材料输入、多结果输出、失败保留材料、每日限制
*/

function _Dps_PetSynthesis_GetText_(Config, Key, DefaultText) {
    if (Config.rawin("提示文本") && Config["提示文本"].rawin(Key)) return Config["提示文本"][Key];
    return DefaultText;
}

function _Dps_PetSynthesis_GetRuleText_(Rule, Config, Key, DefaultText) {
    if (Rule.rawin("提示文本") && Rule["提示文本"].rawin(Key)) return Rule["提示文本"][Key];
    return _Dps_PetSynthesis_GetText_(Config, Key, DefaultText);
}

function _Dps_PetSynthesis_FindRule_(Rules, MaterialPetIds) {
    local PetCount = MaterialPetIds.len();
    foreach (Rule in Rules) {
        if (!Rule.rawin("材料宠物")) continue;
        local RuleMaterials = Rule["材料宠物"];
        if (RuleMaterials.len() != PetCount) continue;

        local RuleIds = [];
        foreach (Id in RuleMaterials) RuleIds.append(Id.tointeger());
        RuleIds.sort();

        local InputIds = clone MaterialPetIds;
        InputIds.sort();

        local Match = true;
        for (local i = 0; i < PetCount; i++) {
            if (RuleIds[i] != InputIds[i]) { Match = false; break; }
        }
        if (Match) return Rule;
    }
    return null;
}

function _Dps_PetSynthesis_GetSlots_(Rule) {
    local Slots = [];
    if (Rule.rawin("材料槽位")) {
        foreach (S in Rule["材料槽位"]) Slots.append(S.tointeger());
    } else {
        local Count = Rule["材料宠物"].len();
        for (local i = 0; i < Count; i++) Slots.append(i);
    }
    return Slots;
}

function _Dps_PetSynthesis_GetMaterialPets_(InvenObj, Slots) {
    local Pets = [];
    foreach (Slot in Slots) {
        local PetItem = InvenObj.GetSlot(Inven.INVENTORY_TYPE_CREATURE, Slot);
        if (!PetItem || PetItem.IsEmpty) return null;
        Pets.append(PetItem);
    }
    return Pets;
}

function _Dps_PetSynthesis_CheckItems_(SUser, Costs) {
    if (!Costs || Costs.len() == 0) return true;
    local InvenObj = SUser.GetInven();
    if (!InvenObj) return false;

    foreach (Cost in Costs) {
        local ItemId = Cost["物品ID"].tointeger();
        local NeedCount = Cost["数量"].tointeger();
        if (NeedCount <= 0) continue;
        if (InvenObj.GetItemCount(ItemId) < NeedCount) return false;
    }
    return true;
}

function _Dps_PetSynthesis_ConsumeItems_(SUser, Costs) {
    if (!Costs || Costs.len() == 0) return;
    local InvenObj = SUser.GetInven();

    foreach (Cost in Costs) {
        local ItemId = Cost["物品ID"].tointeger();
        local NeedCount = Cost["数量"].tointeger();
        if (NeedCount <= 0) continue;
        InvenObj.DeleteItem(ItemId, NeedCount);
    }
}

function _Dps_PetSynthesis_RollResult_(Results) {
    if (!Results || Results.len() == 0) return 0;

    local TotalRate = 0;
    foreach (R in Results) {
        local Rate = R.rawin("概率") ? R["概率"].tointeger() : 0;
        if (Rate < 0) Rate = 0;
        TotalRate += Rate;
    }
    if (TotalRate <= 0) return 0;

    local Roll = rand() % TotalRate;
    local Acc = 0;
    foreach (R in Results) {
        local Rate = R.rawin("概率") ? R["概率"].tointeger() : 0;
        if (Rate <= 0) continue;
        Acc += Rate;
        if (Roll < Acc) return R["宠物ID"].tointeger();
    }
    return 0;
}

function _Dps_PetSynthesis_CheckDailyLimit_(SUser, Rule) {
    if (!Rule.rawin("每日限制")) return true;
    local MaxCount = Rule["每日限制"].tointeger();
    if (MaxCount <= 0) return true;

    local Cid = SUser.GetCID();
    local RuleId = Rule.rawin("id") ? Rule["id"] : 0;

    local Sql = "select count from taiwan_cain_2nd.daily_limit where charac_no=" + Cid
        + " and type=" + 200 + " and id=" + RuleId
        + " and date=CURDATE();";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    local Result = SqlObj.Exec_Sql(Sql);
    local CurrentCount = 0;
    if (Result && Result.size() > 0) CurrentCount = Result[0][0].tointeger();
    MysqlPool.GetInstance().PutConnect(SqlObj);

    return CurrentCount < MaxCount;
}

function _Dps_PetSynthesis_AddDailyCount_(SUser, Rule) {
    if (!Rule.rawin("每日限制")) return;
    local MaxCount = Rule["每日限制"].tointeger();
    if (MaxCount <= 0) return;

    local Cid = SUser.GetCID();
    local RuleId = Rule.rawin("id") ? Rule["id"] : 0;

    local Sql = "insert into taiwan_cain_2nd.daily_limit (charac_no, type, id, count, date) values ("
        + Cid + "," + 200 + "," + RuleId + ",1,CURDATE()) on duplicate key update count=count+1;";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    SqlObj.Exec_Sql(Sql);
    MysqlPool.GetInstance().PutConnect(SqlObj);
}

function _Dps_PetSynthesis_DeleteCreatureFromMgr_(InvenObj, ItemObj) {
    local CreatureMgrPtr = Sq_CallFunc(S_Ptr("0x080dd568"), "pointer", ["pointer"], InvenObj.C_Object);
    if (!CreatureMgrPtr) return;

    local CreatureUid = NativePointer(ItemObj.C_Object).add(7).readU32();
    if (CreatureUid == 0) return;

    Sq_CallFunc(S_Ptr("0x0833A854"), "int", ["pointer", "int"], CreatureMgrPtr, CreatureUid);
}

function _Dps_PetSynthesis_DeleteCreatureDb_(Cid, Slots) {
    local SlotList = "";
    for (local i = 0; i < Slots.len(); i++) {
        if (i > 0) SlotList += ",";
        SlotList += Slots[i];
    }
    local Sql = "delete from taiwan_cain_2nd.creature_items where charac_no=" + Cid + " and slot in (" + SlotList + ");";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    SqlObj.Exec_Sql(Sql);
    MysqlPool.GetInstance().PutConnect(SqlObj);
}

function _Dps_PetSynthesis_DeleteMaterialPets_(SUser, InvenObj, PetItems, Slots) {
    foreach (Item in PetItems) {
        _Dps_PetSynthesis_DeleteCreatureFromMgr_(InvenObj, Item);
        Item.Delete();
    }
    _Dps_PetSynthesis_DeleteCreatureDb_(SUser.GetCID(), Slots);
    SUser.SendItemSpace(7);
}

function _Dps_PetSynthesis_MatchAndValidate_(Rules, InvenObj) {
    foreach (Rule in Rules) {
        if (!Rule.rawin("材料宠物")) continue;

        local Slots = _Dps_PetSynthesis_GetSlots_(Rule);
        local Pets = _Dps_PetSynthesis_GetMaterialPets_(InvenObj, Slots);
        if (!Pets) continue;

        local MaterialIds = [];
        foreach (Pet in Pets) MaterialIds.append(Pet.GetIndex());

        if (_Dps_PetSynthesis_FindRule_([Rule], MaterialIds)) {
            return { Rule = Rule, Pets = Pets, Slots = Slots };
        }
    }
    return null;
}

function _Dps_PetSynthesis_Logic_() {
    local Config = GlobalConfig.Get("宠物合成配置.json");

    foreach (BoxId in Config["合成卷ID"]) {
        Cb_Use_Item_Sp_Func[BoxId] <- function(SUser, ItemId) {
        local CurrentConfig = GlobalConfig.Get("宠物合成配置.json");
        local InvenObj = SUser.GetInven();
        if (!InvenObj) return;

        local Match = _Dps_PetSynthesis_MatchAndValidate_(CurrentConfig["合成规则"], InvenObj);
        if (!Match) {
            SUser.SendNotiPacketMessage(_Dps_PetSynthesis_GetText_(CurrentConfig, "无匹配规则", "当前宠物无法合成"), 8);
            return;
        }

        // 检查每日限制
        if (!_Dps_PetSynthesis_CheckDailyLimit_(SUser, Match.Rule)) {
            SUser.SendNotiPacketMessage(_Dps_PetSynthesis_GetRuleText_(Match.Rule, CurrentConfig, "次数不足", "今日合成次数已达上限"), 8);
            return;
        }

        // 检查并扣除消耗物品
        local ItemCosts = Match.Rule.rawin("消耗物品") ? Match.Rule["消耗物品"] : null;
        if (!_Dps_PetSynthesis_CheckItems_(SUser, ItemCosts)) {
            SUser.SendNotiPacketMessage(_Dps_PetSynthesis_GetRuleText_(Match.Rule, CurrentConfig, "材料不足", "所需材料不足"), 8);
            return;
        }
        _Dps_PetSynthesis_ConsumeItems_(SUser, ItemCosts);
        _Dps_PetSynthesis_AddDailyCount_(SUser, Match.Rule);

        // 从结果池中随机选择
        local Results = Match.Rule.rawin("目标结果") ? Match.Rule["目标结果"] : [];
        local TargetPetId = _Dps_PetSynthesis_RollResult_(Results);
        local IsSuccess = TargetPetId > 0;

        // 处理材料宠物
        local KeepMaterials = Match.Rule.rawin("失败保留材料") && Match.Rule["失败保留材料"] && !IsSuccess;
        if (!KeepMaterials) {
            _Dps_PetSynthesis_DeleteMaterialPets_(SUser, InvenObj, Match.Pets, Match.Slots);
        }

        // 发放结果
        if (IsSuccess) {
            if (SUser.GiveItem(TargetPetId, 1)) {
                SUser.SendNotiPacketMessage(_Dps_PetSynthesis_GetRuleText_(Match.Rule, CurrentConfig, "合成成功", "宠物合成成功"), 8);
            } else {
                SUser.SendNotiPacketMessage(_Dps_PetSynthesis_GetRuleText_(Match.Rule, CurrentConfig, "背包已满", "宠物合成成功，但目标宠物发放失败，请检查背包空间"), 8);
            }
        } else {
            if (KeepMaterials) {
                SUser.SendNotiPacketMessage(_Dps_PetSynthesis_GetRuleText_(Match.Rule, CurrentConfig, "合成失败保留", "合成失败，材料宠物已保留"), 8);
            } else {
                SUser.SendNotiPacketMessage(_Dps_PetSynthesis_GetRuleText_(Match.Rule, CurrentConfig, "合成失败", "宠物合成失败，材料宠物已消耗"), 8);
            }
        }
    }
}
}

function _Dps_PetSynthesis_Main_() {
    _Dps_PetSynthesis_Logic_();
}

function _Dps_PetSynthesis_Main_Reload_(OldConfig) {
    foreach (BoxId in OldConfig["合成卷ID"]) {
        local OldId = BoxId.tointeger();
        if (Cb_Use_Item_Sp_Func.rawin(OldId)) Cb_Use_Item_Sp_Func.rawdelete(OldId);
    }
    _Dps_PetSynthesis_Logic_();
}
