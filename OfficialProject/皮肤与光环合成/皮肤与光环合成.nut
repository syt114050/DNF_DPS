/*
文件名:皮肤与光环合成.nut
路径:OfficialProject/皮肤与光环合成/皮肤与光环合成.nut
创建日期:2026-05-03
文件用途:使用皮肤光环合成卷，将时装栏前两格皮肤或光环按配置概率合成为目标
*/

function _Dps_SkinAuraSynthesis_GetText_(Config, Key, DefaultText) {
    if (Config.rawin("提示文本") && Config["提示文本"].rawin(Key)) return Config["提示文本"][Key];
    return DefaultText;
}

function _Dps_SkinAuraSynthesis_FindRule_(Rules, Id1, Id2) {
    foreach (Rule in Rules) {
        if (!Rule.rawin("材料1") || !Rule.rawin("材料2") || !Rule.rawin("目标")) continue;

        local Material1 = Rule["材料1"].tointeger();
        local Material2 = Rule["材料2"].tointeger();
        if ((Material1 == Id1 && Material2 == Id2) || (Material1 == Id2 && Material2 == Id1)) {
            return Rule;
        }
    }
    return null;
}

function _Dps_SkinAuraSynthesis_DeleteDb_(Cid, Slot1, Slot2) {
    local DbSlot1 = Slot1 + 10;
    local DbSlot2 = Slot2 + 10;
    local Sql = "delete from taiwan_cain_2nd.user_items where charac_no=" + Cid + " and slot in (" + DbSlot1 + "," + DbSlot2 + ");";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    SqlObj.Exec_Sql(Sql);
    MysqlPool.GetInstance().PutConnect(SqlObj);
}

function _Dps_SkinAuraSynthesis_DeleteMaterials_(SUser, InvenObj, ItemObj1, ItemObj2) {
    ItemObj1.Delete();
    ItemObj2.Delete();
    _Dps_SkinAuraSynthesis_DeleteDb_(SUser.GetCID(), 0, 1);
    SUser.SendItemSpace(1);
}

function _Dps_SkinAuraSynthesis_Logic_() {
    local Config = GlobalConfig.Get("皮肤与光环合成配置.json");
    local SynthesisItemId = Config["皮肤光环合成卷ID"].tointeger();

    Cb_Use_Item_Sp_Func[SynthesisItemId] <- function(SUser, ItemId) {
        local CurrentConfig = GlobalConfig.Get("皮肤与光环合成配置.json");
        local InvenObj = SUser.GetInven();
        if (!InvenObj) return;

        local Item1 = InvenObj.GetSlot(Inven.INVENTORY_TYPE_AVARTAR, 0);
        local Item2 = InvenObj.GetSlot(Inven.INVENTORY_TYPE_AVARTAR, 1);
        if (!Item1 || !Item2 || Item1.IsEmpty || Item2.IsEmpty) {
            SUser.GiveItem(ItemId, 1);
            SUser.SendNotiPacketMessage(_Dps_SkinAuraSynthesis_GetText_(CurrentConfig, "缺少材料", "请将两个需要合成的皮肤或光环放在时装栏前两格"), 8);
            return;
        }

        local Id1 = Item1.GetIndex();
        local Id2 = Item2.GetIndex();
        local Rule = _Dps_SkinAuraSynthesis_FindRule_(CurrentConfig["合成规则"], Id1, Id2);
        if (!Rule) {
            SUser.GiveItem(ItemId, 1);
            SUser.SendNotiPacketMessage(_Dps_SkinAuraSynthesis_GetText_(CurrentConfig, "无匹配规则", "当前两个皮肤/光环无法合成"), 8);
            return;
        }

        local TargetId = Rule["目标"].tointeger();
        local Rate = Rule.rawin("概率") ? Rule["概率"].tointeger() : 100;
        if (Rate < 0) Rate = 0;
        if (Rate > 100) Rate = 100;

        local IsSuccess = (rand() % 100) < Rate;
        _Dps_SkinAuraSynthesis_DeleteMaterials_(SUser, InvenObj, Item1, Item2);

        if (IsSuccess) {
            if (SUser.GiveItem(TargetId, 1)) {
                SUser.SendNotiPacketMessage(_Dps_SkinAuraSynthesis_GetText_(CurrentConfig, "合成成功", "皮肤/光环合成成功"), 8);
            } else {
                SUser.SendNotiPacketMessage(_Dps_SkinAuraSynthesis_GetText_(CurrentConfig, "背包已满", "合成成功，但目标皮肤/光环发放失败，请检查背包空间"), 8);
            }
        } else {
            SUser.SendNotiPacketMessage(_Dps_SkinAuraSynthesis_GetText_(CurrentConfig, "合成失败", "皮肤/光环合成失败，材料已消耗"), 8);
        }
    }
}

function _Dps_SkinAuraSynthesis_Main_() {
    _Dps_SkinAuraSynthesis_Logic_();
}

function _Dps_SkinAuraSynthesis_Main_Reload_(OldConfig) {
    local OldSynthesisItemId = OldConfig["皮肤光环合成卷ID"].tointeger();
    if (Cb_Use_Item_Sp_Func.rawin(OldSynthesisItemId)) Cb_Use_Item_Sp_Func.rawdelete(OldSynthesisItemId);

    _Dps_SkinAuraSynthesis_Logic_();
}
