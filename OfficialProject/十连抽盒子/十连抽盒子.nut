/*
文件名:十连抽盒子.nut
路径:OfficialProject/十连抽盒子/十连抽盒子.nut
创建日期:2026-05-18
文件用途:十连抽盒子——支持多种盒子类型，每种盒子独立配置奖励池/保底/追加奖励。消耗对应道具执行10次加权随机抽奖，支持幸运值保底、全服公告、背包满后邮件发送
*/

// 类型常量，用于 daily_limit 表中的 type 字段，区分不同抽奖系统
local PITY_TYPE = 211;

// 按权重从奖励池中随机选取一项，返回索引
function _Dps_Box10_Roll_(Pool) {
    if (!Pool || Pool.len() == 0) return -1;
    local TotalWeight = 0;
    foreach (Item in Pool) {
        local W = Item[1].tointeger();
        if (W < 0) W = 0;
        TotalWeight += W;
    }
    if (TotalWeight <= 0) return -1;
    local Roll = rand() % TotalWeight;
    local Acc = 0;
    for (local i = 0; i < Pool.len(); i++) {
        local W = Pool[i][1].tointeger();
        if (W <= 0) continue;
        Acc += W;
        if (Roll < Acc) return i;
    }
    return -1;
}

// 从奖励池中筛选出 is_super_reward == 1 的项，作为保底奖池
function _Dps_Box10_BuildSuperPool_(Pool) {
    local Super = [];
    foreach (Item in Pool) {
        if (Item.len() >= 6 && Item[4].tointeger() == 1) {
            Super.push([Item[0], Item[2], Item[3]]);
        }
    }
    return Super;
}

// 读取幸运值
function _Dps_Box10_GetPity_(CharacNo, BoxItemId) {
    local Sql = "select count from taiwan_cain_2nd.daily_limit where charac_no=" + CharacNo
        + " and type=" + PITY_TYPE + " and id=" + BoxItemId
        + " and date='2000-01-01';";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    local Result = SqlObj.Exec_Sql(Sql);
    local Count = 0;
    if (Result && Result.size() > 0) Count = Result[0][0].tointeger();
    MysqlPool.GetInstance().PutConnect(SqlObj);
    return Count;
}

// 幸运值+1
function _Dps_Box10_AddPity_(CharacNo, BoxItemId) {
    local Sql = "insert into taiwan_cain_2nd.daily_limit (charac_no, type, id, count, date) values ("
        + CharacNo + "," + PITY_TYPE + "," + BoxItemId + ",1,'2000-01-01') on duplicate key update count=count+1;";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    SqlObj.Exec_Sql(Sql);
    MysqlPool.GetInstance().PutConnect(SqlObj);
}

// 重置幸运值
function _Dps_Box10_ResetPity_(CharacNo, BoxItemId) {
    local Sql = "update taiwan_cain_2nd.daily_limit set count=0 where charac_no=" + CharacNo
        + " and type=" + PITY_TYPE + " and id=" + BoxItemId
        + " and date='2000-01-01';";
    local SqlObj = MysqlPool.GetInstance().GetConnect();
    SqlObj.Exec_Sql(Sql);
    MysqlPool.GetInstance().PutConnect(SqlObj);
}

// 检查背包空位
function _Dps_Box10_CheckSlot_(SUser, ItemId) {
    local InvenObj = SUser.GetInven();
    if (!InvenObj) return 0;
    local Type = Sq_CallFunc(S_Ptr("0x085018D2"), "int", ["pointer", "int"], InvenObj.C_Object, ItemId);
    return Sq_CallFunc(S_Ptr("0x08504F64"), "int", ["pointer", "int", "int"], InvenObj.C_Object, Type, 1);
}

// 发放单个奖励：优先背包，背包满则邮件
function _Dps_Box10_GiveReward_(SUser, ItemId, Count) {
    if (_Dps_Box10_CheckSlot_(SUser, ItemId) >= 1 && SUser.GiveItem(ItemId, Count)) {
        return;
    }
    SUser.ReqDBSendMultiMail("GM", "背包空间不足，已通过邮件发送", 0, [[ItemId, Count]]);
}

// 发送全服公告
function _Dps_Box10_Broadcast_(SUser, ItemId, Count, BoxName, Config) {
    local BcPos = Config["公告配置"]["公告位置"].tointeger();
    local ItemName = PvfItem.GetNameById(ItemId);
    local WorldMsg = _Dps_Box10_GetText_(Config, "世界公告", "恭喜玩家：【{0}】运气爆棚！\n从{1}中获得了 [{2}] x{3}");
    WorldMsg = _Dps_Box10_Replace_(WorldMsg, "{0}", SUser.GetCharacName());
    WorldMsg = _Dps_Box10_Replace_(WorldMsg, "{1}", BoxName);
    WorldMsg = _Dps_Box10_Replace_(WorldMsg, "{2}", ItemName);
    WorldMsg = _Dps_Box10_Replace_(WorldMsg, "{3}", Count.tostring());

    local MsgObj = AdMsg();
    MsgObj.PutType(BcPos);
    MsgObj.PutString(WorldMsg);
    MsgObj.Finalize();
    World.SendAll(MsgObj.MakePack());
    MsgObj.Delete();
}

// 获取提示文本
function _Dps_Box10_GetText_(Config, Key, DefaultText) {
    if (Config.rawin("提示文本") && Config["提示文本"].rawin(Key))
        return Config["提示文本"][Key];
    return DefaultText;
}

// 字符串替换
function _Dps_Box10_Replace_(Str, From, To) {
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

function _Dps_Box10_Logic_() {
    local Config = GlobalConfig.Get("十连抽盒子配置.json");
    local BoxList = Config["盒子列表"];

    foreach (BoxIdStr, BoxData in BoxList) {
        local BoxItemId = BoxIdStr.tointeger();

        Cb_Use_Item_Sp_Func[BoxItemId] <- function(SUser, ItemId) {
            local CurrentConfig = GlobalConfig.Get("十连抽盒子配置.json");
            local BoxCfg = CurrentConfig["盒子列表"][ItemId.tostring()];
            local DrawCount = BoxCfg["每次抽奖次数"].tointeger();
            local PityThreshold = BoxCfg["保底触发次数"].tointeger();
            local Pool = BoxCfg["奖励池"];
            local FixedBonus = BoxCfg["固定追加奖励"];
            local CharacNo = SUser.GetCID();
            local CharacName = SUser.GetCharacName();
            local BoxName = PvfItem.GetNameById(ItemId);

            // 必得奖励：优先发放，剩余次数从奖池抽取
            local GuaranteedItem = BoxCfg.rawin("必得奖励") ? BoxCfg["必得奖励"] : null;
            local RandomDraws = DrawCount;
            if (GuaranteedItem && GuaranteedItem.len() >= 2) {
                local GItemId = GuaranteedItem[0].tointeger();
                local GCount = GuaranteedItem[1].tointeger();
                if (GItemId > 0 && GCount > 0) {
                    _Dps_Box10_GiveReward_(SUser, GItemId, GCount);
                    local GItemName = PvfItem.GetNameById(GItemId);
                    local GMsg = _Dps_Box10_GetText_(CurrentConfig, "获得物品", "你获得了 {0} x{1}");
                    GMsg = _Dps_Box10_Replace_(GMsg, "{0}", GItemName);
                    GMsg = _Dps_Box10_Replace_(GMsg, "{1}", GCount.tostring());
                    SUser.SendNotiPacketMessage(GMsg, 8);
                    RandomDraws = DrawCount - 1;
                }
            }

            // 构建保底奖池：奖励池中 is_super_reward == 1 的项
            local SuperPool = _Dps_Box10_BuildSuperPool_(Pool);
            local SuperItemId = SuperPool.len() > 0 ? SuperPool[0][0].tointeger() : 0;
            local SuperItemName = SuperItemId != 0 ? PvfItem.GetNameById(SuperItemId) : "";

            for (local i = 0; i < RandomDraws; i++) {
                // 读取当前幸运值
                local PityCount = _Dps_Box10_GetPity_(CharacNo, ItemId);

                // 发送幸运值提示
                local LuckMsg = _Dps_Box10_GetText_(CurrentConfig, "幸运值提示",
                    "当前角色：[ {0} ]\n目前[{1}]的幸运值为：{2}/{3}\n幸运值越高，获得稀有道具的概率越高\n累积{3}点幸运值后，必出【{4}】");
                LuckMsg = _Dps_Box10_Replace_(LuckMsg, "{0}", CharacName);
                LuckMsg = _Dps_Box10_Replace_(LuckMsg, "{1}", BoxName);
                LuckMsg = _Dps_Box10_Replace_(LuckMsg, "{2}", PityCount.tostring());
                LuckMsg = _Dps_Box10_Replace_(LuckMsg, "{3}", PityThreshold.tostring());
                LuckMsg = _Dps_Box10_Replace_(LuckMsg, "{4}", SuperItemName);
                SUser.SendNotiPacketMessage(LuckMsg, 8);

                local RewardItemId = 0;
                local RewardCount = 0;
                local IsBroadcast = 0;
                local IsGuaranteed = false;

                // 权重抽奖
                local Idx = _Dps_Box10_Roll_(Pool);
                if (Idx < 0) continue;

                // 检查是否命中稀有道具（is_super_reward == 1）
                if (Pool[Idx].len() >= 6 && Pool[Idx][4].tointeger() == 1) {
                    IsGuaranteed = true;
                    _Dps_Box10_ResetPity_(CharacNo, ItemId);
                    RewardItemId = Pool[Idx][0].tointeger();
                    RewardCount = Pool[Idx][2].tointeger();
                    IsBroadcast = Pool[Idx][3].tointeger();
                } else if (PityThreshold > 0 && PityCount >= PityThreshold - 1) {
                    // 幸运值已满，强行从保底奖池中随机
                    IsGuaranteed = true;
                    _Dps_Box10_ResetPity_(CharacNo, ItemId);
                    local SuperIdx = rand() % SuperPool.len();
                    RewardItemId = SuperPool[SuperIdx][0].tointeger();
                    RewardCount = SuperPool[SuperIdx][1].tointeger();
                    IsBroadcast = SuperPool[SuperIdx][2].tointeger();
                } else {
                    // 普通奖励
                    RewardItemId = Pool[Idx][0].tointeger();
                    RewardCount = Pool[Idx][2].tointeger();
                    IsBroadcast = Pool[Idx][3].tointeger();
                }

                if (RewardItemId <= 0 || RewardCount <= 0) continue;

                // 发放奖励
                _Dps_Box10_GiveReward_(SUser, RewardItemId, RewardCount);

                // 保底重置通知
                if (IsGuaranteed) {
                    local GuaranteeMsg = _Dps_Box10_GetText_(CurrentConfig, "保底触发", "恭喜获得稀有奖励！\n已重置当前角色幸运值");
                    SUser.SendNotiPacketMessage(GuaranteeMsg, 8);
                }

                // 个人获得提示
                local ItemName = PvfItem.GetNameById(RewardItemId);
                local Msg = _Dps_Box10_GetText_(CurrentConfig, "获得物品", "你获得了 {0} x{1}");
                Msg = _Dps_Box10_Replace_(Msg, "{0}", ItemName);
                Msg = _Dps_Box10_Replace_(Msg, "{1}", RewardCount.tostring());
                SUser.SendNotiPacketMessage(Msg, 8);

                // 全服公告
                if (IsBroadcast != 0) {
                    _Dps_Box10_Broadcast_(SUser, RewardItemId, RewardCount, BoxName, CurrentConfig);
                }
            }

            // 十连抽结束后，发放固定追加奖励
            foreach (Bonus in FixedBonus) {
                local BonusId = Bonus[0].tointeger();
                local BonusCount = Bonus[1].tointeger();
                if (BonusId > 0 && BonusCount > 0) {
                    _Dps_Box10_GiveReward_(SUser, BonusId, BonusCount);
                }
            }
        }
    }
}

function _Dps_Box10_Main_() {
    _Dps_Box10_Logic_();
}

function _Dps_Box10_Main_Reload_(OldConfig) {
    if (OldConfig.rawin("魔盒道具ID")) {
        local OldBoxItemId = OldConfig["魔盒道具ID"].tointeger();
        if (Cb_Use_Item_Sp_Func.rawin(OldBoxItemId)) Cb_Use_Item_Sp_Func.rawdelete(OldBoxItemId);
    } else if (OldConfig.rawin("盒子列表")) {
        foreach (BoxIdStr, BoxData in OldConfig["盒子列表"]) {
            local OldId = BoxIdStr.tointeger();
            if (Cb_Use_Item_Sp_Func.rawin(OldId)) Cb_Use_Item_Sp_Func.rawdelete(OldId);
        }
    }
    _Dps_Box10_Logic_();
}
