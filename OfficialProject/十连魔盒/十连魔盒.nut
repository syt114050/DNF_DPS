/*
文件名:十连魔盒.nut
路径:OfficialProject/十连魔盒/十连魔盒.nut
创建日期:2026-05-17
文件用途:使用指定魔盒道具，按权重随机获得奖励，支持保底、公告、背包满后邮件发送
*/

// 按权重从奖励池中随机选取一项
function _Dps_MagicBox_Roll_(Pool) {
    if (!Pool || Pool.len() == 0) return null;

    local TotalWeight = 0;
    foreach (Item in Pool) {
        local W = Item[1].tointeger();
        if (W < 0) W = 0;
        TotalWeight += W;
    }
    if (TotalWeight <= 0) return null;

    local Roll = rand() % TotalWeight;
    local Acc = 0;
    foreach (Item in Pool) {
        local W = Item[1].tointeger();
        if (W <= 0) continue;
        Acc += W;
        if (Roll < Acc) return Item;
    }
    return null;
}

// 从保底奖励列表中随机选一个（通常只有一个）
function _Dps_MagicBox_GetGuaranteedReward_(GuaranteedList) {
    if (!GuaranteedList || GuaranteedList.len() == 0) return null;
    return GuaranteedList[rand() % GuaranteedList.len()];
}

// 生成随机数量 [最小, 最大]
function _Dps_MagicBox_RollCount_(Reward) {
    local MinQty = Reward[2].tointeger();
    local MaxQty = Reward[3].tointeger();
    if (MinQty < 1) MinQty = 1;
    if (MaxQty < MinQty) MaxQty = MinQty;
    return MinQty + (rand() % (MaxQty - MinQty + 1));
}

// 读取保底计数
function _Dps_MagicBox_GetPity_(Cid, BoxItemId) {
    local Sql = "select count from taiwan_cain_2nd.daily_limit where charac_no=" + Cid
        + " and type=" + 210 + " and id=" + BoxItemId
        + " and date='2000-01-01';";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    local Result = SqlObj.Exec_Sql(Sql);
    local Count = 0;
    if (Result && Result.size() > 0) Count = Result[0][0].tointeger();
    MysqlPool.GetInstance().PutConnect(SqlObj);
    return Count;
}

// 保底计数+1
function _Dps_MagicBox_AddPity_(Cid, BoxItemId) {
    local Sql = "insert into taiwan_cain_2nd.daily_limit (charac_no, type, id, count, date) values ("
        + Cid + "," + 210 + "," + BoxItemId + ",1,'2000-01-01') on duplicate key update count=count+1;";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    SqlObj.Exec_Sql(Sql);
    MysqlPool.GetInstance().PutConnect(SqlObj);
}

// 重置保底计数
function _Dps_MagicBox_ResetPity_(Cid, BoxItemId) {
    local Sql = "update taiwan_cain_2nd.daily_limit set count=0 where charac_no=" + Cid
        + " and type=" + 210 + " and id=" + BoxItemId
        + " and date='2000-01-01';";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    SqlObj.Exec_Sql(Sql);
    MysqlPool.GetInstance().PutConnect(SqlObj);
}

// 检查背包空位
function _Dps_MagicBox_CheckSlot_(SUser, ItemId) {
    local InvenObj = SUser.GetInven();
    if (!InvenObj) return 0;
    local Type = Sq_CallFunc(S_Ptr("0x085018D2"), "int", ["pointer", "int"], InvenObj.C_Object, ItemId);
    return Sq_CallFunc(S_Ptr("0x08504F64"), "int", ["pointer", "int", "int"], InvenObj.C_Object, Type, 1);
}

// 发放奖励：优先背包，背包满则邮件
function _Dps_MagicBox_GiveReward_(SUser, ItemId, Count) {
    if (_Dps_MagicBox_CheckSlot_(SUser, ItemId) >= 1 && SUser.GiveItem(ItemId, Count)) {
        return;
    }
    SUser.ReqDBSendMultiMail("GM", "背包空间不足，已通过邮件发送", 0, [[ItemId, Count]]);
}

// 发送全服公告
function _Dps_MagicBox_Broadcast_(SUser, ItemId, Count, Config) {
    local BcPos = Config["公告配置"]["公告位置"].tointeger();
    local ItemName = PvfItem.GetNameById(ItemId);

    local MsgObj = AdMsg();
    MsgObj.PutType(BcPos);
    MsgObj.PutColorString("玩家[", [255, 255, 0]);
    MsgObj.PutColorString(SUser.GetCharacName(), [255, 0, 0]);
    MsgObj.PutColorString("]", [255, 255, 0]);
    MsgObj.PutColorString("在十连魔盒中获得了", [255, 255, 0]);
    MsgObj.PutColorString("[" + ItemName + "]", [255, 0, 255]);
    MsgObj.PutColorString(" x" + Count, [255, 255, 0]);
    MsgObj.Finalize();
    World.SendAll(MsgObj.MakePack());
    MsgObj.Delete();
}

// 获取提示文本
function _Dps_MagicBox_GetText_(Config, Key, DefaultText) {
    if (Config.rawin("提示文本") && Config["提示文本"].rawin(Key))
        return Config["提示文本"][Key];
    return DefaultText;
}

// 字符串替换
function _Dps_MagicBox_Replace_(Str, From, To) {
    local Result = "";
    local Pos = 0;
    local Found = Str.find(From, Pos);
    while (Found != null) {
        Result += Str.slice(Pos, Found) + To;
        Pos = Found + From.len();
        Found = Str.find(From, Pos);
    }
    Result += Str.slice(Pos);
    return Result;
}

function _Dps_MagicBox_Logic_() {
    local Config = GlobalConfig.Get("十连魔盒配置.json");
    local BoxItemId = Config["魔盒道具ID"].tointeger();

    Cb_Use_Item_Sp_Func[BoxItemId] <- function(SUser, ItemId) {
        local CurrentConfig = GlobalConfig.Get("十连魔盒配置.json");
        local DrawCount = CurrentConfig["每次抽奖次数"].tointeger();
        local Pool = CurrentConfig["奖励池"];
        local GuaranteeConfig = CurrentConfig["保底设置"];
        local PityThreshold = GuaranteeConfig["保底次数"].tointeger();
        local GuaranteedRewards = GuaranteeConfig["保底奖励"];
        local Cid = SUser.GetCID();

        local PityCount = _Dps_MagicBox_GetPity_(Cid, BoxItemId);

        for (local i = 0; i < DrawCount; i++) {
            local Reward = null;
            local IsGuaranteed = false;

            // 检查保底
            if (PityThreshold > 0 && PityCount >= PityThreshold) {
                Reward = _Dps_MagicBox_GetGuaranteedReward_(GuaranteedRewards);
                IsGuaranteed = true;
                PityCount = 0;
                _Dps_MagicBox_ResetPity_(Cid, BoxItemId);
            } else {
                // 正常权重抽奖
                Reward = _Dps_MagicBox_Roll_(Pool);
                if (Reward) {
                    PityCount++;
                    _Dps_MagicBox_AddPity_(Cid, BoxItemId);
                }
            }

            if (!Reward) continue;

            local ItemId2 = Reward[0].tointeger();
            local Count = IsGuaranteed ? Reward[1].tointeger() : _Dps_MagicBox_RollCount_(Reward);
            if (Count <= 0) continue;

            // 发放奖励
            _Dps_MagicBox_GiveReward_(SUser, ItemId2, Count);

            // 公告
            local ShouldBroadcast = IsGuaranteed || Reward[4].tointeger() != 0;
            if (ShouldBroadcast) {
                _Dps_MagicBox_Broadcast_(SUser, ItemId2, Count, CurrentConfig);
            }

            // 发送个人提示
            local ItemName = PvfItem.GetNameById(ItemId2);
            local Msg = _Dps_MagicBox_GetText_(CurrentConfig, "获得物品", "你获得了 {0} x{1}");
            // simple placeholder replacement
            Msg = _Dps_MagicBox_Replace_(Msg, "{0}", ItemName);
            Msg = _Dps_MagicBox_Replace_(Msg, "{1}", Count.tostring());
            SUser.SendNotiPacketMessage(Msg, 8);

            if (IsGuaranteed) {
                local GuaranteeMsg = _Dps_MagicBox_GetText_(CurrentConfig, "保底触发", "恭喜触发保底奖励！");
                SUser.SendNotiPacketMessage(GuaranteeMsg, 8);
            }
        }
    }
}

function _Dps_MagicBox_Main_() {
    _Dps_MagicBox_Logic_();
}

function _Dps_MagicBox_Main_Reload_(OldConfig) {
    local OldBoxItemId = OldConfig["魔盒道具ID"].tointeger();
    if (Cb_Use_Item_Sp_Func.rawin(OldBoxItemId)) Cb_Use_Item_Sp_Func.rawdelete(OldBoxItemId);
    _Dps_MagicBox_Logic_();
}
